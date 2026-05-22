# Problema e solução: UUID no Cassandra com Rails

**Data**: 22 de maio de 2026  
**Contexto**: CRUD de Organizations, Contributors e Memberships usando Cassandra Driver no Rails

---

## Resumo

Ao criar os endpoints de CRUD, os testes de request começaram a retornar **500 Internal Server Error** após a troca de `SecureRandom.uuid` por IDs simples em string.

A causa não era o Cassandra em si, mas sim o **tipo do valor enviado no bind do prepared statement**. O driver do Cassandra neste projeto esperava um valor compatível com o tipo `uuid`, e não uma string Ruby pura.

A correção foi normalizar os IDs para `Cassandra::Uuid` antes de enviá-los ao driver.

---

## Sintoma observado

Os specs de request passaram a falhar com erro 500 em ações de criação:

- `POST /contributors`
- `POST /memberships`
- em alguns momentos, também o fluxo de `organizations`

O teste mostrava resposta interna do controller, mas sem erro visível de negócio. O erro real aparecia no log do Ruby/Cassandra driver.

---

## Causa raiz

O Cassandra driver valida o tipo dos argumentos passados para prepared statements.

A tabela foi definida com campos do tipo:

- `organization_id UUID`
- `contributor_id UUID`
- `membership_id UUID`

Quando o código passou a gerar IDs com `SecureRandom.uuid`, o valor era uma **String Ruby**:

```ruby
"d1c4f8b1-3e6a-4c3d-a8d6-9f8df0b4f911"
```

Mesmo sendo visualmente um UUID válido, o driver do Cassandra não tratou isso como um valor UUID bindável no contexto do prepared statement. O resultado foi um erro do tipo:

- `ArgumentError: argument for "organization_id" must be uuid`

---

## Por que isso acontece no Cassandra

O Cassandra trabalha fortemente com tipos explícitos de coluna. Quando você usa prepared statements, o driver faz validação do tipo informado antes de enviar a query.

Ou seja:

- a coluna é `UUID`
- o bind precisa receber um objeto que o driver reconheça como `uuid`
- uma string com formato de UUID pode não ser suficiente em todos os cenários do driver

Isso é diferente de bancos mais flexíveis, onde uma string pode ser convertida implicitamente.

---

## Solução aplicada

Foi criada uma normalização de UUID nos repositórios.

Em vez de passar strings cruas, os IDs agora são convertidos para `Cassandra::Uuid`:

- `app/repositories/organizations_repository.rb`
- `app/repositories/contributors_repository.rb`
- `app/repositories/memberships_repository.rb`

A ideia é sempre garantir que o valor enviado ao Cassandra tenha o tipo esperado pelo driver.

### Exemplo da correção

```ruby
def normalize_uuid(value)
  return value if value.is_a?(Cassandra::Uuid)
  Cassandra::Uuid.new(value || SecureRandom.uuid)
end
```

Depois disso, o ID usado no insert passa a ser um objeto que o driver aceita corretamente.

---

## Resultado

Após a correção:

- `POST /organizations` voltou a funcionar
- `POST /contributors` voltou a funcionar
- `POST /memberships` voltou a funcionar
- os request specs ficaram verdes novamente

Validação executada:

```bash
bundle exec rspec spec/requests/contributors_spec.rb spec/requests/memberships_spec.rb spec/requests/organization_spec.rb
```

Resultado:

- `3 examples, 0 failures`

---

## Lição técnica

No Cassandra, não basta o valor “parecer” correto. O **tipo real que o driver recebe** importa.

Para campos UUID, especialmente com prepared statements, o mais seguro é:

1. gerar o ID na aplicação
2. normalizar para o tipo aceito pelo driver
3. bindar a query com esse tipo já convertido

---

## Decisão tomada no projeto

Foi mantida a geração dos IDs na aplicação, mas com normalização para `Cassandra::Uuid` no repositório.

Isso traz alguns benefícios:

- evita dependência de helper específico do driver em todo o código de negócio
- mantém o controle de geração no Ruby
- garante compatibilidade com o Cassandra driver
- reduz chance de erro em test e runtime

---

## Arquivos envolvidos

- [app/repositories/organizations_repository.rb](../app/repositories/organizations_repository.rb)
- [app/repositories/contributors_repository.rb](../app/repositories/contributors_repository.rb)
- [app/repositories/memberships_repository.rb](../app/repositories/memberships_repository.rb)
- [spec/requests/organization_spec.rb](../spec/requests/organization_spec.rb)
- [spec/requests/contributors_spec.rb](../spec/requests/contributors_spec.rb)
- [spec/requests/memberships_spec.rb](../spec/requests/memberships_spec.rb)

---

## Observação sobre o health check

O `curl -s http://localhost:3000/health/cassandra` retornar falha de conexão não está ligado diretamente a esse problema de UUID. Isso é outro ponto: indica que o servidor Rails não estava acessível naquele momento ou não estava em execução.

Esse comportamento é separado do bug de bind do UUID no Cassandra.

---

## Conclusão

O problema foi causado por **incompatibilidade de tipo entre o valor gerado em Ruby e o tipo esperado pelo Cassandra driver no prepared statement**.

A solução foi converter os IDs para `Cassandra::Uuid` antes do bind, garantindo compatibilidade com as colunas `UUID` e eliminando os 500 nos endpoints de criação.
