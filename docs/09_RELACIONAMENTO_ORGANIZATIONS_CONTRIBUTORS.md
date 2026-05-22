# Relacionamento entre `organizations` e `contributors` no Cassandra

**Data**: 22 de maio de 2026  
**Contexto**: modelagem do vínculo entre contribuidor e organização em Cassandra para o CRUD do Clareo

---

## Objetivo do relacionamento

A aplicação precisa permitir que um contribuidor:

- encontre uma organização
- se associe a ela
- marque uma organização como favorita ou vinculada
- consulte os vínculos por organização ou por contribuidor

Como o banco usado é Cassandra, esse relacionamento não foi implementado com join tradicional. Em vez disso, foi modelado com **duas tabelas espelhadas** para suportar as consultas mais importantes de forma rápida e previsível.

---

## Por que não usar join em Cassandra

Em bancos relacionais, o vínculo entre duas entidades normalmente seria feito com:

- chave estrangeira
- tabela associativa
- join na leitura

No Cassandra, essa abordagem não é a ideal porque:

1. **Cassandra não foi desenhado para join**
   - não existe join nativo como em SQL tradicional
   - cada query deve ser pensada a partir da forma como os dados serão lidos

2. **A leitura precisa ser rápida e direcionada**
   - Cassandra funciona melhor quando a consulta usa a partition key
   - joins exigiriam agrupar dados de múltiplas partições

3. **A modelagem é orientada à consulta**
   - primeiro definimos como queremos ler
   - depois desenhamos a tabela para essa leitura

Por isso, o relacionamento foi desenhado como **denormalização controlada**.

---

## Modelagem adotada

Foram criadas duas tabelas de relacionamento:

- `memberships_by_organization`
- `memberships_by_contributor`

Elas representam o mesmo vínculo, mas organizadas por perspectivas diferentes.

### Tabela por organização

Arquivo: [db/cassandra/migrations/03_create_memberships.cql](../db/cassandra/migrations/03_create_memberships.cql)

```sql
CREATE TABLE IF NOT EXISTS clareo.memberships_by_organization (
    organization_id UUID,
    contributor_id UUID,
    membership_id UUID,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((organization_id), contributor_id)
);
```

### Tabela por contribuidor

```sql
CREATE TABLE IF NOT EXISTS clareo.memberships_by_contributor (
    contributor_id UUID,
    organization_id UUID,
    membership_id UUID,
    status TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    PRIMARY KEY ((contributor_id), organization_id)
);
```

---

## O que cada tabela resolve

### `memberships_by_organization`

Serve para responder perguntas como:

- quais contribuintes estão ligados a esta organização?
- quem favoritou esta organização?
- quantos vínculos existem para esta organização?

Aqui a **partition key** é `organization_id`.

Isso significa que:

- todos os vínculos daquela organização ficam agrupados no mesmo shard lógico
- a leitura por organização é rápida
- não há necessidade de varrer o cluster inteiro

### `memberships_by_contributor`

Serve para responder perguntas como:

- em quais organizações este contribuidor está vinculado?
- quais organizações ele favoritou?
- qual é o histórico de vínculos dele?

Aqui a **partition key** é `contributor_id`.

Isso permite consultar diretamente a partir do contribuidor sem fazer scan nem join.

---

## Conceitos do Cassandra aplicados aqui

### 1. Partition key

A `partition key` define em qual partição os dados ficam armazenados.

No nosso caso:

- `memberships_by_organization` usa `organization_id`
- `memberships_by_contributor` usa `contributor_id`

Isso é o coração da modelagem.

A ideia é que cada consulta importante tenha uma tabela desenhada especificamente para ela.

### 2. Denormalização

Em Cassandra, duplicar informação de forma controlada é normal.

Aqui o mesmo vínculo é salvo em duas tabelas porque isso facilita leituras diferentes.

Em banco relacional isso seria considerado duplicação excessiva.
Em Cassandra isso é uma prática esperada quando ela melhora a consulta.

### 3. Dual write

Para manter as duas visões consistentes, a criação do vínculo grava nas duas tabelas:

- primeiro em `memberships_by_organization`
- depois em `memberships_by_contributor`

Isso é um exemplo de **dual write**.

Como Cassandra não faz join e o sistema é distribuído, a aplicação precisa ser responsável por manter as visões sincronizadas.

### 4. Consistency level `QUORUM`

As gravações e leituras do repositório usam `consistency: :quorum`.

Isso significa:

- para escrever, o Cassandra confirma com a maioria das réplicas
- para ler, o Cassandra consulta a maioria e retorna o resultado mais confiável

Com RF=3:

- `QUORUM` = 2
- a operação é confirmada quando 2 de 3 réplicas concordam

Isso aumenta a segurança do vínculo, especialmente em um cluster distribuído.

---

## Como o vínculo foi implementado no projeto

### Repositório

Arquivo: [app/repositories/memberships_repository.rb](../app/repositories/memberships_repository.rb)

O repositório grava e lê os vínculos.

#### Criação

Ao criar um vínculo:

- gera um `membership_id`
- normaliza `organization_id` e `contributor_id`
- grava na tabela por organização
- grava na tabela por contribuidor

Isso garante que as duas perspectivas existam ao mesmo tempo.

#### Leitura

O repositório expõe:

- `for_organization(organization_id)`
- `for_contributor(contributor_id)`

Ou seja:

- uma consulta para a visão da organização
- outra para a visão do contribuidor

### Controller

Arquivo: [app/controllers/memberships_controller.rb](../app/controllers/memberships_controller.rb)

O controller expõe endpoints simples para:

- criar vínculo
- listar vínculos por organização ou contribuidor

Isso é útil para o MVP porque mostra claramente a forma como Cassandra exige modelagem orientada à leitura.

---

## O que esse vínculo representa funcionalmente

A nomenclatura escolhida foi `membership` porque ela é genérica e serve para vários contextos:

- favorito
- associação
- inscrição
- vínculo ativo
- participação

Assim o mesmo modelo pode ser reutilizado sem amarrar a regra de negócio a um nome específico.

Por exemplo:

- se amanhã o contribuidor apenas “favoritar” a organização, o vínculo continua válido
- se depois ele “se associar oficialmente”, o mesmo vínculo pode mudar de status

O campo `status` permite representar isso sem mudar o schema.

---

## Por que essa abordagem foi escolhida

### 1. É a forma correta de modelar em Cassandra

Cassandra não deve ser usado como se fosse um banco relacional.

A estratégia correta é:

- identificar as consultas
- criar tabelas para cada consulta
- aceitar a duplicação quando ela simplifica a leitura

### 2. Evita consultas caras

Sem essa modelagem, seria necessário:

- fazer scan
- cruzar dados na aplicação
- manter lógica pesada de montagem de relacionamento

Com as tabelas espelhadas, cada leitura vira uma query direta por partition key.

### 3. Funciona bem com crescimento

Se o sistema crescer para milhares de organizações e contribuintes:

- os dados continuam distribuídos
- cada consulta continua previsível
- o cluster pode escalar horizontalmente

### 4. Serve para qualquer contexto futuro

O nome `membership` deixa o modelo aberto para várias interpretações de negócio:

- relacionamento ativo
- interesse
- assinatura
- favoritismo
- aliança

Isso é bom para um MVP porque evita refatoração desnecessária depois.

---

## Como demonstrar isso ao professor

Você pode explicar o fluxo assim:

1. O contribuidor se cadastra.
2. A organização já existe.
3. Quando o contribuidor se relaciona com a organização, a aplicação grava o vínculo em duas tabelas.
4. Uma tabela responde por organização.
5. Outra tabela responde por contribuidor.
6. O Cassandra retorna os dados com boa performance porque a consulta bate diretamente na partition key.

Se quiser mostrar em execução:

- criar um contribuidor
- criar um membership
- consultar por organização
- consultar por contribuidor

---

## Exemplo de leitura no Cassandra

### Vínculos de uma organização

```sql
SELECT * FROM clareo.memberships_by_organization
WHERE organization_id = ?;
```

### Vínculos de um contribuidor

```sql
SELECT * FROM clareo.memberships_by_contributor
WHERE contributor_id = ?;
```

Essas duas consultas cobrem os dois lados do relacionamento sem join.

---

## Relação com o modelo de dados geral

Esse relacionamento se apoia nas tabelas principais já criadas:

- [db/cassandra/migrations/01_create_organizations.cql](../db/cassandra/migrations/01_create_organizations.cql)
- [db/cassandra/migrations/02_create_contributors.cql](../db/cassandra/migrations/02_create_contributors.cql)

A estrutura fica assim:

- `organizations` guarda a entidade principal
- `contributors` guarda a pessoa/contribuidor
- `memberships_*` guarda o vínculo entre os dois

---

## Conclusão

O relacionamento entre `organizations` e `contributors` foi modelado de forma nativa para Cassandra, usando:

- denormalização controlada
- duas tabelas espelhadas
- partition keys orientadas à consulta
- `QUORUM` para consistência
- `membership` como nome genérico e reutilizável

Essa modelagem é mais adequada ao Cassandra do que tentar reproduzir um relacionamento relacional clássico.

Ela é simples, performática e preparada para crescer.

---

*Última atualização: 22 de maio de 2026*
