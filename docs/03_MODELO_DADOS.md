# Modelo de Dados - Clareo

## Keyspace e Tabelas Cassandra

### Keyspace Principal
```cassandra
CREATE KEYSPACE clareo WITH replication = {'class': 'NetworkTopologyStrategy', 
  'us-east': 3, 'us-west': 3};
```

---

## Tabelas por Domínio

### 1. ORGANIZATIONS

```cassandra
CREATE TABLE clareo.organizations (
  organization_id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  cnpj TEXT UNIQUE,
  status TEXT, -- 'active', 'suspended', 'inactive'
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  metadata MAP<TEXT, TEXT>,
  contact_email TEXT,
  webhook_url TEXT,
  api_key_hash TEXT,
  
  INDEX idx_cnpj ON clareo.organizations (cnpj),
  INDEX idx_status ON clareo.organizations (status)
);

-- Secondary index para busca por CNPJ
CREATE INDEX idx_org_cnpj ON clareo.organizations (cnpj);
```

### 2. DONATION_PLANS

```cassandra
CREATE TABLE clareo.donation_plans (
  plan_id UUID,
  organization_id UUID,
  frequency TEXT, -- 'daily', 'weekly', 'monthly', 'yearly'
  name TEXT,
  description TEXT,
  status TEXT, -- 'active', 'archived'
  created_at TIMESTAMP,
  
  PRIMARY KEY (organization_id, plan_id)
) WITH CLUSTERING ORDER BY (plan_id DESC);
```

### 3. CONTRIBUTORS

```cassandra
CREATE TABLE clareo.contributors (
  contributor_id UUID,
  organization_id UUID,
  email TEXT,
  name TEXT,
  phone TEXT,
  cpf TEXT,
  status TEXT, -- 'active', 'inactive', 'blocked'
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  
  PRIMARY KEY (organization_id, contributor_id)
) WITH CLUSTERING ORDER BY (contributor_id DESC);

CREATE INDEX idx_contributor_email ON clareo.contributors (email);
```

### 4. WALLETS (Saldo por Organização)

```cassandra
CREATE TABLE clareo.wallets (
  organization_id UUID PRIMARY KEY,
  balance_cents BIGINT, -- em centavos
  available_cents BIGINT, -- disponível (sem locks)
  locked_cents BIGINT, -- em operações
  version BIGINT, -- versionamento para otimistic locking
  last_updated TIMESTAMP,
  currency TEXT DEFAULT 'BRL'
);
```

### 5. TRANSACTIONS (Ledger de Transações)

```cassandra
CREATE TABLE clareo.transactions (
  transaction_id UUID,
  organization_id UUID,
  created_at TIMESTAMP,
  transaction_type TEXT, -- 'donation', 'withdrawal', 'credit', 'floating_return'
  amount_cents BIGINT,
  status TEXT, -- 'pending', 'completed', 'failed', 'reversed'
  description TEXT,
  contributor_id UUID,
  plan_id UUID,
  metadata MAP<TEXT, TEXT>,
  idempotency_key TEXT,
  
  PRIMARY KEY ((organization_id), created_at, transaction_id)
) WITH CLUSTERING ORDER BY (created_at DESC)
  AND default_time_to_live = 7776000; -- 90 dias

CREATE INDEX idx_transaction_idempotency ON clareo.transactions (idempotency_key);
CREATE INDEX idx_transaction_status ON clareo.transactions (status);
CREATE INDEX idx_transaction_contributor ON clareo.transactions (contributor_id);
```

### 6. LEDGER (Auditoria Imutável - Double Entry)

```cassandra
CREATE TABLE clareo.ledger_entries (
  ledger_id UUID,
  organization_id UUID,
  created_at TIMESTAMP,
  transaction_id UUID,
  account_type TEXT, -- 'wallet', 'floating', 'credit_line', 'fees'
  debit_cents BIGINT,
  credit_cents BIGINT,
  balance_after_cents BIGINT,
  description TEXT,
  
  PRIMARY KEY ((organization_id), created_at, ledger_id)
) WITH CLUSTERING ORDER BY (created_at DESC)
  AND default_time_to_live = 31536000; -- 1 ano
```

### 7. RECURRING_DONATIONS (Configurações)

```cassandra
CREATE TABLE clareo.recurring_donations (
  recurring_id UUID,
  organization_id UUID,
  contributor_id UUID,
  plan_id UUID,
  amount_cents BIGINT,
  status TEXT, -- 'active', 'paused', 'cancelled'
  start_date DATE,
  end_date DATE,
  next_charge_date DATE,
  last_charge_date DATE,
  created_at TIMESTAMP,
  
  PRIMARY KEY ((organization_id), contributor_id, recurring_id)
) WITH CLUSTERING ORDER BY (contributor_id DESC);

CREATE INDEX idx_recurring_next_charge ON clareo.recurring_donations (next_charge_date);
```

### 8. FLOATING_ACCOUNTS (Aplicação de Dinheiro)

```cassandra
CREATE TABLE clareo.floating_accounts (
  floating_id UUID PRIMARY KEY,
  organization_id UUID,
  applied_amount_cents BIGINT,
  annual_rate DECIMAL,
  start_date TIMESTAMP,
  maturity_date TIMESTAMP,
  status TEXT, -- 'active', 'matured', 'withdrawn'
  interest_earned_cents BIGINT,
  
  INDEX idx_floating_org ON clareo.floating_accounts (organization_id)
);
```

### 9. CREDIT_LINES (Sistema de Crédito)

```cassandra
CREATE TABLE clareo.credit_lines (
  credit_id UUID PRIMARY KEY,
  organization_id UUID,
  limit_cents BIGINT,
  used_cents BIGINT,
  available_cents BIGINT,
  annual_rate DECIMAL,
  status TEXT, -- 'active', 'suspended', 'closed'
  created_at TIMESTAMP,
  
  INDEX idx_credit_org ON clareo.credit_lines (organization_id)
);
```

---

## Estratégia de Partição e Distribuição

### Partition Key Strategy
- **Primary Partition**: `organization_id` → Garante dados da mesma org no mesmo nó
- **Clustering**: Ordenado por timestamp DESC para queries eficientes

### Replication
- Replication Factor: 3 (mínimo)
- Consistency Level:
  - Write: QUORUM (2 de 3 confirmam)
  - Read: QUORUM (2 de 3 validam)
  - Transações críticas: ALL

---

## Indexes

### Índices Necessários
1. **CNPJ** (organizations) - Busca por identificação legal
2. **Email** (contributors, users) - Autenticação
3. **Idempotency Key** (transactions) - Deduplicação
4. **Status** - Filtros por estado
5. **Next Charge Date** - Processamento de recorrências

---

## Desafios de Consistência Resolvidos

### Problema 1: Atualização de Saldo
```
Transação: Adicionar $100 ao saldo
├─ Leitura atual: $1000
├─ Calcular novo: $1100
├─ Usar LWT (Lightweight Transaction):
│  "UPDATE wallets SET balance = 1100, version = v+1 
│   WHERE organization_id = X IF version = v"
├─ Se falhar → retry com novo version
└─ Sucesso → registrar em ledger
```

### Problema 2: Deduplicação
Usar `idempotency_key` para evitar processamento duplo:
- Request chega com idempotency_key único
- Verificar se já foi processado em Redis
- Se sim → retornar resposta anterior
- Se não → processar e cachear resultado

### Problema 3: Locks Distribuídos
Para operações complexas (múltiplas alterações):
```
1. Adquirir lock em Redis: "org_lock:{organization_id}"
2. TTL: 30 segundos (evitar deadlock)
3. Processar atomicamente
4. Liberar lock
```

