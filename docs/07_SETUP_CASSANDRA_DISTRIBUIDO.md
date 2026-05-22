# Documentação: Setup Cassandra Distribuído - Clareo

**Data**: 22 de maio de 2026  
**Status**: MVP de cluster distribuído com 3 nós funcionando  
**Objetivo**: Demonstrar ao professor um banco NoSQL distribuído em produção

---

## Sumário Executivo

Configuramos um **cluster Cassandra distribuído local com 3 nós**, rodando em Docker, integrado com a aplicação Rails via driver Cassandra nativo. O sistema simula uma **replicação de dados em tempo real com RF (Replication Factor) 3**, garantindo que cada dado seja copiado para 3 nós diferentes e disponível mesmo se 1-2 nós caírem.

**O que foi feito:**
- 3 nós Cassandra em Docker Compose
- Keyspace `clareo` com replicação `NetworkTopologyStrategy` RF=3
- Tabela `organizations` shardada por `organization_id`
- Client Rails que conecta ao cluster e executa queries com consistência `QUORUM`
- Rake task automatizada para bootstrap do schema
- Health check de Cassandra

---

## Fundamentos: Como Cassandra Funciona (Necessário Entender)

### 1. Cassandra é um Banco NoSQL Distribuído

Diferente do SQL tradicional (PostgreSQL, MySQL):
- **Sem ACID nativo**: Cassandra é "Eventually Consistent" por padrão.
- **Horizontalmente escalável**: Agregar mais nós melhora throughput, não apenas storage.
- **Sem ponto único de falha**: Qualquer nó pode receber requisições.
- **Sem schema centralizado**: Schema é propagado via Gossip Protocol.

### 2. Partition Key (Sharding)

Em Cassandra, você escolhe a `PARTITION KEY` que define em qual nó o dado vai ficar:

```sql
CREATE TABLE organizations (
  organization_id UUID PRIMARY KEY,  -- Partition key: define nó
  name TEXT,
  ...
)
```

- `organization_id` é a **partition key**.
- Cassandra faz `hash(organization_id) % num_nodes` para determinar em qual nó colocar o dado.
- Todos os dados de uma `organization_id` ficarão no **mesmo nó** (ou em réplicas dele).

**Motivo dessa escolha:**
- Queries por `organization_id` são super rápidas (1 nó).
- Evita scatter-gather entre todos os nós.
- Perfeito para multi-tenant (cada organização isolada em shards).

### 3. Replication e Replication Factor (RF)

O `Replication Factor` define quantas **cópias** cada dado tem:

**RF=3 significa:**
- Cada dado é copiado em **3 nós diferentes**.
- Se 1 nó cair, você ainda tem 2 cópias.
- Se 2 nós caem, você ainda tem 1 cópia disponível.
- Perda total só com **todos os 3 nós fora**.

Como Cassandra escolhe quais nós?
1. Nó primário: `hash(organization_id) % 3` (por exemplo, node-1).
2. Nó réplica 1: próximo nó no anel (node-2).
3. Nó réplica 2: próximo nó no anel (node-3).

**Visualização:**

```
Token Ring (3 nós, RF=3):

Node 1                         Node 2
├─ Dados com hash 0-100       ├─ Dados com hash 100-200
├─ Réplica de (200-300)       ├─ Réplica de (300-0)
└─ Réplica de (300-0)         └─ Réplica de (0-100)

                Node 3
                ├─ Dados com hash 300-0
                ├─ Réplica de (100-200)
                └─ Réplica de (200-300)
```

Resultado: **cada dado existe em 3 lugares simultaneamente**.

### 4. Consistency Levels (Read/Write)

Você controla quantos nós precisam **confirmar** uma operação:

```ruby
# Nosso repositório usa QUORUM:
CassandraClient.session.execute(query, consistency: :quorum)
```

**QUORUM significa:** escrever/ler em `ceil(RF / 2) + 1` nós.  
Com RF=3: QUORUM = 2 nós.

- **Write QUORUM**: insira em 2 de 3 nós antes de retornar "sucesso".
- **Read QUORUM**: leia de 2 de 3 nós, compare timestamps, retorne mais recente.

**Garantia:** Se você escreve em QUORUM e lê em QUORUM, você sempre vê o seu próprio write (strong read-after-write consistency).

---

## Nossa Configuração Específica

### Arquivo: `docker-compose.cluster.yml`

```yaml
cassandra1:  # Seed node
  CASSANDRA_CLUSTER_NAME=clareo
  CASSANDRA_DC=datacenter1
  ports: 9042:9042

cassandra2:
  CASSANDRA_SEEDS=cassandra1  # Descobre cluster via seed
  CASSANDRA_DC=datacenter1
  ports: 9043:9042

cassandra3:
  CASSANDRA_SEEDS=cassandra1
  CASSANDRA_DC=datacenter1
  ports: 9044:9042
```

**Decisões:**

1. **Seed node (cassandra1)**
   - Todos os nós usam `cassandra1` como bootstrap contact point.
   - cassandra1 usa `CASSANDRA_SEEDS=cassandra1` (aponta para si mesmo).
   - cassandra2/cassandra3 usam `CASSANDRA_SEEDS=cassandra1` (apontam para cassandra1).

2. **Cluster name: `clareo`**
   - Todos os nós devem ter o mesmo nome.
   - Cassandra rejeita nós com cluster names diferentes.

3. **Datacenter: `datacenter1`**
   - Simula uma região geográfica (ex: us-east-1).
   - Em produção, haveria vários datacenters em diferentes regiões.
   - Nosso replication strategy usa `NetworkTopologyStrategy` com `datacenter1: 3`.

4. **Network de Docker**
   - Containers se veem por hostname (`cassandra1`, `cassandra2`, `cassandra3`).
   - Ports 9042, 9043, 9044 são o CQL (aplicação conecta aqui).
   - Ports 7000/7001 são gossip/internos (nodes se comunicam).

### Arquivo: `lib/cassandra_client.rb`

```ruby
module CassandraClient
  session                    # Conecta com keyspace
  session_without_keyspace   # Conecta sem keyspace (para bootstrap)
  ensure_keyspace!           # Cria keyspace se não existir
  wait_for_keyspace!         # Espera schema propagar nos 3 nós
end
```

**Decisões:**

1. **Múltiplas sessions**
   - `session`: para queries normais. Precisa de keyspace existente.
   - `session_without_keyspace`: para criar keyspace e tabelas (bootstrap).
   - Evita deadlock onde Rails tenta conectar com keyspace que não existe.

2. **Load balancing com DC awareness**
   ```ruby
   DCAwareRoundRobin.new("datacenter1")
   ```
   - Prioriza nós no mesmo DC.
   - Reduz latência de rede.
   - Em produção com múltiplos DCs, seria essencial.

3. **Contact points: `127.0.0.1`**
   - Rails roda **fora** do Docker Compose.
   - Ports 9042, 9043, 9044 mapeados para localhost.
   - Cliente descobre cluster automaticamente via gossip.

### Arquivo: `db/cassandra/migrations/01_create_organizations.cql`

```sql
CREATE TABLE clareo.organizations (
  organization_id UUID PRIMARY KEY,
  name TEXT,
  cnpj TEXT,
  status TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  ...
);

CREATE INDEX inx_cnpj ON clareo.organizations (cnpj);
```

**Decisões:**

1. **Partition Key: `organization_id` (UUID)**
   - Cada organização fica isolada em um shard.
   - Queries por `WHERE organization_id = ?` vão direto no nó certo.
   - Multi-tenant seguro e escalável.

2. **Sem clustering key**
   - Dados de uma org não precisam ser ordenados.
   - Tabela é flat: 1 row por organization_id.
   - (Futuro: `recurring_donations` usará clustering order by date).

3. **Índices secundários: `inx_cnpj`, `inx_status`**
   - Permitem buscas por `WHERE cnpj = ?` (sem partition key direto).
   - Cassandra duplica dados nos índices.
   - Performance: O(num_nodes) em vez de O(1), mas funciona.

4. **TTL opcional (futuro)**
   - Poderia adicionar `WITH default_time_to_live = ...` para dados que expiram.

### Arquivo: `lib/tasks/cassandra.rake`

```ruby
task cassandra:migrate do
  # 1. Criar keyspace via session_without_keyspace
  CassandraClient.ensure_keyspace!
  CassandraClient.wait_for_keyspace!  # Espera propagar nos 3 nós
  
  # 2. Aplicar migrations via session_without_keyspace
  # (Evita race condition: keyspace cria, mas Rails tenta conectar antes dele estar pronto)
end
```

**Decisões:**

1. **Bootstrap em duas fases:**
   - `CREATE KEYSPACE` (via session sem keyspace).
   - Espera 15 segundos até keyspace aparecer em `system_schema.keyspaces`.
   - Depois `CREATE TABLE` (via session_without_keyspace).

2. **Por que esperar?**
   - Cassandra distribuído propaga schema via Gossip.
   - Node 1 cria, node 1 propaga para node 2 e 3.
   - Se Rails tenta conectar com keyspace antes dele estar em node 2 ou 3, falha.
   - Wait-loop garante que todos os 3 nós têm o schema.

3. **Idempotent: `CREATE ... IF NOT EXISTS`**
   - Pode rodar task múltiplas vezes sem erro.
   - Perfeito para redeploy/CI.

### Arquivo: `app/repositories/organizations_repository.rb`

```ruby
def create(attrs)
  id = attrs[:organization_id] || Cassandra::Uuid::Generator.new.now
  CassandraClient.session.execute(@insert, 
    arguments: [...],
    consistency: :quorum  # ← Escreve em 2 de 3 nós
  )
end

def find(id)
  CassandraClient.session.execute(@get,
    arguments: [id],
    consistency: :quorum  # ← Lê de 2 de 3 nós (compara timestamps)
  )
end
```

**Decisões:**

1. **Prepared statements (`@insert`, `@get`)**
   - Cassandra precisa compilar queries.
   - Prepared statements são cached no driver.
   - Reduz overhead, melhora security (evita SQL injection).

2. **QUORUM para leitura e escrita**
   - Garante strong consistency (read-after-write).
   - Tradeoff: latência vs consistência.
   - Alternativa `LOCAL_QUORUM` prioriza local DC (mais rápido).

3. **UUID como ID**
   - `Cassandra::Uuid::Generator.new.now` gera UUIDs v1 (time-based).
   - Sem depender de sequence/serial.
   - Distribuído: cada nó gera IDs únicos sem sincronização central.

---

## O Que Estamos Simulando

### 1. Cluster Cassandra Real em Produção

Nosso setup de 3 nós **simula**:
- **Replicação geográfica**: 3 nós em 3 "regiões" (na verdade, 3 containers).
- **Fault tolerance**: Se um nó cair, dados sobrevivem nos outros 2.
- **Distributed consensus**: Quorum writes garantem durabilidade.
- **Eventual consistency**: Réplicas podem ter delay, mas convergem.

### 2. High Availability (HA)

Com RF=3 e QUORUM:
- **Escrever mesmo com 1 nó fora**: precisamos de 2 de 3 nós. Com 3 nós: OK com até 1 fora.
- **Ler mesmo com 1 nó fora**: precisamos de 2 de 3 nós. Com 3 nós: OK com até 1 fora.
- **Zero downtime**: Cassandra não tem master; qualquer nó pode servir requests.

### 3. Multi-Tenant Sharding

Com partition key `organization_id`:
- Cada organização (NGO, instituição religiosa) tem seu "shard" isolado.
- Dados de ORG A nunca se misturam com ORG B.
- Escalabilidade linear: 100 orgs com 100 nós = cada org em ~1 nó.
- Sem contenção: writes em ORG A não afetam ORG B.

### 4. Schemas Distribuídos (Migrations)

Nossa Rake task simula:
- **Infrastructure-as-Code**: migrations em arquivos CQL.
- **Idempotency**: rodar 2x não dá erro.
- **Schema propagation**: espera todos os nós terem as tabelas.
- **Zero downtime deploy**: aplicação online enquanto migrations rodam.

---

## Como Verificar / Demonstrar ao Professor

### 1. Verificar Cluster Saudável

```bash
docker exec cassandra1 nodetool status
```

**Output esperado:**
```
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens  Owns (effective)  Host ID
UN  172.18.0.2  94.12 KiB  16      33.3%            bd693727-...
UN  172.18.0.3  90.55 KiB  16      33.3%            c8d84f95-...
UN  172.18.0.4  91.23 KiB  16      33.3%            e42f0a18-...
```

- `UN` = Up/Normal (boa saúde).
- `33.3%` cada = tokens distribuídos uniformemente.

### 2. Verificar Replicação

```bash
# Inserir em node 1
docker exec -it cassandra1 cqlsh -k clareo -e "
  INSERT INTO organizations (organization_id, name) 
  VALUES (uuid(), 'Test Org');
"

# Ler de node 2 (verifica replicação)
docker exec -it cassandra2 cqlsh -k clareo -e "
  SELECT * FROM organizations LIMIT 1;
"

# Ler de node 3 (verifica replicação)
docker exec -it cassandra3 cqlsh -k clareo -e "
  SELECT * FROM organizations LIMIT 1;
"
```

Se o mesmo dado aparecer nos 3 nós, replicação está funcionando.

### 3. Verificar Quorum Consistency

Via Rails:

```bash
curl -X POST http://localhost:3000/organizations \
  -H 'Content-Type: application/json' \
  -d '{"organization":{"name":"Demo Org","cnpj":"123"}}'
```

Este POST:
1. Rails chama `OrganizationsRepository.create`.
2. Repository executa INSERT com `consistency: :quorum`.
3. Cassandra confirma quando 2 de 3 nós tiverem escrito.
4. Resposta retorna ao cliente.

Depois:

```bash
curl http://localhost:3000/organizations/<id>
```

Este GET:
1. Rails chama `OrganizationsRepository.find`.
2. Repository executa SELECT com `consistency: :quorum`.
3. Cassandra lê de 2 de 3 nós, compara timestamps, retorna mais recente.
4. Resposta é **garantida** ser a escrita anterior (ou mais recente).

### 4. Demonstrar Tolerância a Falhas

Parar um nó:

```bash
docker stop cassandra2
```

Tentar ler/escrever:

```bash
# Ainda funciona (2 de 3 nós estão up)
curl -X POST http://localhost:3000/organizations ...
```

Parar outro nó:

```bash
docker stop cassandra3
```

Agora você só tem 1 nó. QUORUM precisa de 2:

```bash
# Falha
curl -X POST http://localhost:3000/organizations ...
# Error: "Not enough replicas available for quorum"
```

Restart:

```bash
docker start cassandra2 cassandra3
```

Cluster se auto-recupera via Gossip (sync dos dados).

### 5. Verificar Schema Distribuído

```bash
# Em node 1
docker exec -it cassandra1 cqlsh -k clareo -e "DESCRIBE TABLES;"

# Em node 2
docker exec -it cassandra2 cqlsh -k clareo -e "DESCRIBE TABLES;"

# Em node 3
docker exec -it cassandra3 cqlsh -k clareo -e "DESCRIBE TABLES;"
```

Todos mostram a mesma tabela (schema replicado).

---

## Motivos das Decisões Técnicas

### 1. Por que 3 nós?

- **Menor quantidade para HA real**: 1 ou 2 nós não garantem fault tolerance.
- **QUORUM = 2**: Com 3 nós, perder 1 é tolerável.
- **Demonstração visual**: Consegue mostrar 3 instâncias distintas.
- **Não é overhead**: Docker é leve, fácil rodar 3 containers localmente.

### 2. Por que NetworkTopologyStrategy?

```sql
WITH replication = {'class':'NetworkTopologyStrategy','datacenter1':3}
```

- **Preparação para multi-DC**: Estrutura correta para múltiplos datacenters.
- **Alternativa SimpleStrategy**: `{'class':'SimpleStrategy','replication_factor':3}` é mais simples, mas só funciona com 1 DC.
- **Real: production usa NetworkTopologyStrategy**.

### 3. Por que RF=3?

- **Tolerância**: Perde até 2 nós, continua funcionando com QUORUM (2).
- **Trade-off**: copia dados 3x, usa mais storage, mas garante HA.
- **Production típica**: RF=3 (ou mais em datacenters muito grandes).

### 4. Por que Partition Key = `organization_id`?

- **Multi-tenant**: cada org isolada em shards.
- **Escalabilidade**: 1000 orgs = distribuem em 3 nós sem contenção.
- **Query padrão**: APIs sempre filtram por `organization_id` (autorização).
- **Alternativa**: Partition key composta (ex: `(organization_id, date)`) seria mais complexa.

### 5. Por que QUORUM?

- **Strong consistency**: read-after-write garantido.
- **Trade-off**: latência (precisa de 2 nós em vez de 1), mas dados corretos.
- **Alternativa LOCAL_QUORUM**: mais rápido (1 DC), menos seguro contra falhas de DC.

### 6. Por que Prepared Statements?

- **Performance**: compiladas uma vez, reutilizadas.
- **Security**: evita CQL injection.
- **Driver feature**: Cassandra driver é otimizado para prepared statements.

### 7. Por que Rake task com seed e wait?

- **Problema**: Cassandra propaga schema via Gossip. Não é instantâneo.
- **Solução**: Wait-loop garante que todos os 3 nós têm o schema antes de usar.
- **Alternativa**: `nodetool describecluster` + polling. Nossa abordagem é mais simples.

---

## Próximos Passos Propostos

### MVP (Próxima semana)

1. **Contributors CRUD**
   - Mesmo padrão de `organizations`.
   - Partition key: `(organization_id, contributor_id)`.
   - Permite achar todos os contributors de uma org sem scatter-gather.

2. **Donation Plans & Recurring Donations**
   - Tabelas com clustering keys por `next_charge_date`.
   - Background job processa doações recorrentes.

3. **Wallets & Transactions**
   - Ledger com lightweight transactions (LWT) para consistência.
   - Double-entry bookkeeping.

### Phase 2 (Après MVP pronto)

1. **Kafka integration** (outra pessoa cuida)
   - Event stream de transações.
   - Desacoplamento de serviços.

2. **Credit & Floating**
   - Saga pattern para transações distribuídas.
   - Compensating transactions em caso de rollback.

3. **Monitoramento**
   - Prometheus metrics de Cassandra.
   - Grafana dashboards.
   - Alertas de replicação lag.

---

## Referências Rápidas

### Comandos Úteis

```bash
# Cluster status
docker exec cassandra1 nodetool status
docker exec cassandra1 nodetool ring

# Schema
docker exec -it cassandra1 cqlsh -k clareo -e "DESCRIBE KEYSPACE clareo;"
docker exec -it cassandra1 cqlsh -k clareo -e "DESCRIBE TABLE organizations;"

# Logs
docker logs -f cassandra1

# Query manual
docker exec -it cassandra1 cqlsh -k clareo
cqlsh> SELECT * FROM organizations LIMIT 5;

# Migration
bin/rails cassandra:migrate

# Health check
curl http://localhost:3000/health/cassandra
```

### Variáveis de Ambiente (`.env`)

```
CASSANDRA_CONTACT_POINTS=127.0.0.1
CASSANDRA_PORT=9042
CASSANDRA_KEYSPACE=clareo
CASSANDRA_DC=datacenter1
```

### Arquivos Importantes

- `docker-compose.cluster.yml` - Cluster de 3 nós
- `lib/cassandra_client.rb` - Client e bootstrap logic
- `lib/tasks/cassandra.rake` - Migration task
- `db/cassandra/migrations/` - Schemas CQL
- `app/repositories/organizations_repository.rb` - Data access layer

---

## Conclusão

Temos um **Cassandra distribuído totalmente funcional** que:

✅ Demonstra replicação real (3 nós, cada dado em 3 lugares)  
✅ Garante HA (continua com até 1 nó fora)  
✅ Implementa QUORUM (strong consistency)  
✅ Suporta multi-tenant (partition key `organization_id`)  
✅ Integra com Rails nativo (driver Cassandra)  
✅ Automatiza schema bootstrap (Rake task)  
✅ Pronto para demonstrar ao professor

Este é o fundamento para escalar doações recorrentes para **milhões de organizações sem hotspots**, **garantindo que dinheiro não se perca** (ACID patterns), e **preparando para Kafka para event sourcing**.

---

*Última atualização: 22 de maio de 2026*
