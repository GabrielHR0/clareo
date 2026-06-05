# Plano de Fluxo de Doações

## Visão Geral do Fluxo

```
Contribuidor                     Plataforma                      Organização
    |                                |                                |
    |--- 1. Escolhe campanha ------->|                                |
    |--- 2. Valor + recorrência ---->|                                |
    |--- 3. Escolhe pagamento ------>|                                |
    |                                |--- 4. Processa pagamento ----->|
    |<-- 5. Confirmação ------------|                                |
    |                                |--- 6. Credita wallet --------->|
    |                                |--- 7. Notifica (email/webhook)-|
    |<-- 8. Recibo -----------------|                                |
```

---

## Fase 1 — API de Doações (backend primeiro)

### 1.1 Campanhas de Doação

**Modelo de dados** (nova migration `14_create_campaigns.cql`):

```cql
CREATE TABLE IF NOT EXISTS clareo.campaigns (
    organization_id uuid,
    campaign_id uuid,
    name text,
    description text,
    goal_cents bigint,
    raised_cents bigint,
    status text,                 -- draft | active | completed | cancelled
    starts_at timestamp,
    ends_at timestamp,
    metadata map<text, text>,
    created_at timestamp,
    updated_at timestamp,
    PRIMARY KEY ((organization_id), campaign_id)
);
```

**Endpoints:**
| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/v1/organizations/:org_id/campaigns` | Criar campanha |
| GET | `/api/v1/organizations/:org_id/campaigns` | Listar campanhas |
| GET | `/api/v1/organizations/:org_id/campaigns/:id` | Detalhe da campanha |
| PATCH | `/api/v1/organizations/:org_id/campaigns/:id` | Atualizar campanha |
| DELETE | `/api/v1/organizations/:org_id/campaigns/:id` | Cancelar campanha |

**TDD Specs:**
- Criação de campanha com dados válidos → 201 + campos corretos
- Criação com `goal_cents` negativo → 422
- Listagem por organização → 200 + array
- Atualização de status draft → active → 200
- Cancelamento de campanha → 200 + status `cancelled`
- Tentativa de deletar campanha ativa → 422

### 1.2 Doação Avulsa (Checkout)

**Endpoint:**
| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/vi/public/checkout` | Processar doação sem autenticação |

**Payload:**
```json
{
  "checkout": {
    "campaign_id": "uuid",
    "contributor": {
      "name": "João",
      "email": "joao@email.com",
      "document": "123.456.789-00"
    },
    "amount_cents": 5000,
    "currency": "BRL",
    "payment": {
      "method": "card",          // card | pix | boleto
      "card_token": "tok_xxx",   // se card
      "installments": 1
    },
    "idempotency_key": "ext_123"
  }
}
```

**Fluxo:**
1. Cria ou encontra contribuidor (por email)
2. Cria membership se não existir
3. Processa pagamento via gateway
4. Se cartão: `authorize` + `capture` imediato
5. Se PIX: gera QR Code, aguarda confirmação
6. Se boleto: gera boleto, aguarda confirmação
7. Credita wallet da organização (via `ProcessTransactionService`)
8. Associa ao `campaign_id` para tracking
9. Retorna confirmação + recibo

**TDD Specs:**
- Checkout com cartão válido → 201 + wallet creditada
- Checkout com idempotency_key repetida → 200 `already_processed`
- Checkout com cartão inválido → 422
- Checkout com campaign_id inexistente → 404
- Contribuidor existente é reusado (mesmo email)

### 1.3 Doação Recorrente (Assinatura)

**Endpoint:**
| Método | Rota | Ação |
|--------|------|------|
| POST | `/api/v1/contributors/:id/recurring` | Criar assinatura |
| GET | `/api/v1/contributors/:id/recurring` | Listar assinaturas |
| PATCH | `/api/v1/recurring/:id` | Alterar valor |
| DELETE | `/api/v1/recurring/:id` | Cancelar assinatura |

**Corrigir `RecurringDonationsRepository` primeiro:**
```ruby
# Bug atual:
def initialize(session = CassandraCluster.instance)
# Correção:
def initialize(session = CassandraClient.session_without_keyspace)
```

**TDD Specs:**
- Criar assinatura → 201 + `next_charge_date` calculado
- Listar assinaturas do contribuidor → 200
- Cancelar assinatura → 200 + status `cancelled`
- Worker processa assinatura vencida → wallet debitada + `next_charge_date` avançado
- Worker com saldo insuficiente → tenta cartão (fallback)

---

## Fase 2 — Notificações

### 2.1 Mailers

Criar mailers:
- `DonationMailer#receipt(contributor, transaction)` — Recibo de doação
- `DonationMailer#recurring_confirmation(contributor, recurring)` — Confirmação de assinatura
- `DonationMailer#payment_failed(contributor, recurring)` — Falha no pagamento
- `OrganizationMailer#donation_received(org, transaction)` — Notificação de doação recebida

**TDD Specs:**
- Verificar que email é enfileirado após checkout bem-sucedido
- Verificar conteúdo do email (valor, campanha, data)
- Verificar que email NÃO é enviado em caso de erro

### 2.2 Webhooks

Criar serviço de webhook:
```ruby
class WebhookService
  def self.deliver(organization_id, event_type, payload)
    org = OrganizationsRepository.find(organization_id)
    url = org[:webhook_url]
    return unless url.present?
    # POST para url com payload assinado (HMAC-SHA256)
  end
end
```

Eventos a disparar:
- `donation.created` — nova doação recebida
- `donation.recurring.processed` — cobrança recorrente processada
- `withdrawal.completed` — saque realizado
- `transaction.failed` — transação falhou

**TDD Specs:**
- Webhook entregue com HMAC válido
- Webhook não quebra se URL inválida
- Retry 3x em caso de falha HTTP
- Timeout de 5s

---

## Fase 3 — Autenticação

### 3.1 API Key para organizações

```ruby
class ApiKeyService
  def self.generate(organization_id)
    key = SecureRandom.hex(32)
    hash = BCrypt::Password.create(key)
    OrganizationsRepository.update(organization_id, api_key_hash: hash)
    key  # retorna plain text apenas uma vez
  end

  def self.authenticate(organization_id, key)
    org = OrganizationsRepository.find(organization_id)
    return false unless org[:api_key_hash]
    BCrypt::Password.new(org[:api_key_hash]) == key
  end
end
```

### 3.2 JWT para contribuidores e admins

Usar `gem "jwt"` com tokens de acesso + refresh:
- `POST /api/v1/auth/register` — Registrar contribuidor
- `POST /api/v1/auth/login` — Login (email + senha)
- `POST /api/v1/auth/refresh` — Renovar token
- `POST /api/v1/auth/logout` — Invalidar token

---

## Fase 4 — Frontend Mínimo

### 4.1 Página Pública de Doação (SPA leve)

HTML + JS vanilla ou StimulusReflex:
- Formulário: valor, recorrência, dados do doador
- Seleção de campanha
- Método de pagamento (card/PIX/boleto)
- Confirmação

### 4.2 Dashboard da Organização
- Saldo atual + extrato
- Total arrecadado no mês
- Doações recentes
- QR Code PIX estático

### 4.3 Portal do Contribuidor
- Histórico de doações
- Assinaturas ativas
- Recibos para download
- Dados fiscais
