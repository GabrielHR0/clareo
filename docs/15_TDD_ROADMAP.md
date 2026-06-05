# Roteiro TDD — Implementação com Ciclos Vermelho-Verde-Azul

## Estratégia

Cada funcionalidade segue o ciclo:
1. **🔴 Vermelho:** Escrever o spec que falha
2. **🟢 Verde:** Implementar o mínimo para passar
3. **🔵 Azul:** Refatorar e garantir que specs existentes continuam passando

---

## Ciclo 0 — Corrigir Bugs Existentes (antes de qualquer feature nova)

### 0.1 RecurringDonationsRepository
```bash
# 🔴 Spec
bundle exec rspec spec/repositories/recurring_donations_repository_spec.rb
# → NameError: uninitialized constant CassandraCluster
```
**Correção:** Trocar `CassandraCluster.instance` por `CassandraClient.session_without_keyspace`

### 0.2 ContributorsController#show e #index
```ruby
# 🔴 Spec
RSpec.describe ContributorsController do
  describe "GET index" do
    it "returns all contributors" do
      create(:contributor, name: "Alice")
      create(:contributor, name: "Bob")
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "GET show" do
    it "returns the contributor" do
      contr = create(:contributor)
      get :show, params: { id: contr[:contributor_id] }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["name"]).to eq(contr[:name])
    end
  end
end
```
**Correção:** Implementar `index` e `show` nos controllers usando os repositórios.

### 0.3 OrganizationsController#index
```ruby
# Similar ao contributors#index
```
**Correção:** Implementar listagem via `OrganizationsRepository.all`

### 0.4 Campaign ID type mismatch
**Correção:** Alterar migration 12 para usar `text` em vez de `uuid` para `campaign_id`, ou mudar migration 05 para usar `uuid`. Decisão: usar `text` em ambos (campanhas podem ter IDs externos).

---

## Ciclo 1 — Campanhas de Doação

### 1.1 Repository + Migration
```bash
# 🔴 Spec
bundle exec rspec spec/repositories/campaigns_repository_spec.rb
```

Arquivos a criar:
- `db/cassandra/migrations/14_create_campaigns.cql`
- `app/repositories/campaigns_repository.rb`
- `spec/repositories/campaigns_repository_spec.rb`

### 1.2 Controller + Rotas
```bash
# 🔴 Spec
bundle exec rspec spec/requests/campaigns_spec.rb
```

Arquivos a criar:
- `app/controllers/campaigns_controller.rb`
- `spec/requests/campaigns_spec.rb`
- Atualizar `config/routes.rb`

### 1.3 Service
```bash
# 🔴 Spec
bundle exec rspec spec/services/campaign_service_spec.rb
```

Arquivos a criar:
- `app/services/campaign_service.rb`
- `spec/services/campaign_service_spec.rb`

---

## Ciclo 2 — Doação Avulsa (Checkout)

### 2.1 Checkout Service
```bash
# 🔴 Spec
bundle exec rspec spec/services/checkout_service_spec.rb
```

```ruby
# spec/services/checkout_service_spec.rb
RSpec.describe CheckoutService do
  describe ".process" do
    let(:org) { create(:organization) }
    let(:campaign) { create(:campaign, organization_id: org[:organization_id]) }
    let(:valid_params) do
      {
        campaign_id: campaign[:campaign_id],
        contributor: { name: "João", email: "joao@test.com" },
        amount_cents: 5000,
        payment: { method: "card", card_token: "tok_valid" },
        idempotency_key: "ext_001"
      }
    end

    it "creates contributor if not exists" do
      result = CheckoutService.process(valid_params)
      expect(result[:status]).to eq(:ok)
      expect(result[:contributor][:email]).to eq("joao@test.com")
    end

    it "reuses existing contributor by email" do
      existing = create(:contributor, email: "joao@test.com")
      result = CheckoutService.process(valid_params)
      expect(result[:contributor][:contributor_id]).to eq(existing[:contributor_id])
    end

    it "credits the organization wallet" do
      expect {
        CheckoutService.process(valid_params)
      }.to change { wallet_balance(org[:organization_id]) }.by(5000)
    end

    it "associates transaction with campaign" do
      result = CheckoutService.process(valid_params)
      tx = result[:transaction]
      expect(tx[:campaign_id]).to eq(campaign[:campaign_id].to_s)
    end

    it "rejects invalid card token" do
      invalid_params = valid_params.merge(payment: { method: "card", card_token: "tok_invalid" })
      result = CheckoutService.process(invalid_params)
      expect(result[:status]).to eq(:payment_failed)
    end

    it "handles idempotency" do
      first = CheckoutService.process(valid_params)
      second = CheckoutService.process(valid_params)
      expect(second[:status]).to eq(:already_processed)
      expect(second[:transaction_id]).to eq(first[:transaction_id])
    end
  end
end
```

### 2.2 Checkout Controller
```bash
# 🔴 Spec
bundle exec rspec spec/requests/checkout_spec.rb
```

### 2.3 Atualizar ProcessTransactionService
Garantir que transações com `campaign_id` text funcionem (mudar tipo nas migrations).

---

## Ciclo 3 — Doação Recorrente

### 3.1 Fix RecurringDonationsRepository primeiro
```bash
# 🟢 Já corrigido no Ciclo 0
```

### 3.2 SubscriptionChargeService Spec
```bash
# 🔴 Spec
bundle exec rspec spec/services/subscription_charge_service_spec.rb
```

```ruby
RSpec.describe SubscriptionChargeService do
  it "debits contributor wallet when has funds" do
    contributor = create(:contributor, initial_balance: 10000)
    recurring = create(:recurring, contributor_id: contributor[:contributor_id], amount_cents: 3000)

    result = SubscriptionChargeService.new.process(recurring)
    expect(result[:status]).to eq(:ok)

    wallet = WalletsRepository.find(contributor[:contributor_id], "contributor")
    expect(wallet[:available_cents]).to eq(7000)
  end

  it "falls back to card charge when wallet insufficient" do
    contributor = create(:contributor, initial_balance: 0)
    recurring = create(:recurring, contributor_id: contributor[:contributor_id], amount_cents: 3000)

    expect(PaymentGateway).to receive(:charge_card).and_return({ success: true, reference: "ref_123" })
    result = SubscriptionChargeService.new.process(recurring)
    expect(result[:status]).to eq(:ok)
  end
end
```

### 3.3 Recurring Donations Controller
```bash
# 🔴 Spec
bundle exec rspec spec/requests/recurring_donations_spec.rb
```

### 3.4 Schedule Worker
Atualizar `config/sidekiq.yml`:
```yaml
:schedule:
  recurring_charge:
    cron: "0 8 * * *"  # 8h todos os dias
    class: RecurringChargeWorker
```

---

## Ciclo 4 — Transparência (API Pública)

### 4.1 Public Controller
```bash
# 🔴 Spec
bundle exec rspec spec/requests/public_api_spec.rb
```

```ruby
RSpec.describe "Public API" do
  it "returns organization summary without auth" do
    org = create(:organization, name: "Instituição Teste")
    create(:transaction, owner_id: org[:organization_id], amount_cents: 10000, transaction_type: "credit")

    get "/api/v1/public/organizations/#{org[:organization_id]}"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["organization"]["name"]).to eq("Instituição Teste")
    expect(body["metrics"]["total_raised_cents"]).to eq(10000)
  end

  it "does not expose sensitive fields" do
    org = create(:organization, webhook_url: "https://secret.com/hook")
    get "/api/v1/public/organizations/#{org[:organization_id]}"
    body = JSON.parse(response.body)
    expect(body["organization"]).not_to have_key("webhook_url")
    expect(body["organization"]).not_to have_key("api_key_hash")
  end

  it "returns 404 for unknown organization" do
    get "/api/v1/public/organizations/00000000-0000-0000-0000-000000000000"
    expect(response).to have_http_status(:not_found)
  end
end
```

### 4.2 Allocation Programs
```bash
# 🔴 Spec
bundle exec rspec spec/requests/allocation_programs_spec.rb
```

### 4.3 Dashboard JSON
```bash
# 🔴 Spec
bundle exec rspec spec/requests/dashboard_spec.rb
```

---

## Ciclo 5 — Notificações

### 5.1 Mailers
```bash
# 🔴 Spec
bundle exec rspec spec/mailers/donation_mailer_spec.rb
```

### 5.2 Webhooks
```bash
# 🔴 Spec
bundle exec rspec spec/services/webhook_service_spec.rb
```

---

## Ciclo 6 — Autenticação

### 6.1 JWT Auth
```bash
# 🔴 Spec
bundle exec rspec spec/requests/auth_spec.rb
```

### 6.2 API Key Middleware
```bash
# 🔴 Spec
bundle exec rspec spec/requests/api_key_auth_spec.rb
```

---

## Ciclo 7 — Frontend Mínimo (SPA)

Criar diretório `frontend/` com HTML/JS puro ou Stimulus:

```bash
frontend/
├── public-checkout.html     # Página pública de doação
├── org-dashboard.html       # Painel da organização
├── contributor-portal.html  # Portal do contribuidor
└── transparency.html        # Página de transparência
```

Testar via Cypress ou Playwright (fora do escopo atual).

---

## Como Executar os Testes

```bash
# Dentro do container Rails
docker exec clareo-rails-1 bash -c "cd /rails && bundle exec rspec"

# Spec específico
docker exec clareo-rails-1 bash -c "cd /rails && bundle exec rspec spec/requests/checkout_spec.rb"

# Com formatação
docker exec clareo-rails-1 bash -c "cd /rails && bundle exec rspec --format documentation"

# Rodar migrations antes dos testes
docker exec clareo-rails-1 bash -c "cd /rails && bin/rails cassandra:migrate && bundle exec rspec"
```

---

## Ordem de Prioridade

| Prioridade | Ciclo | Funcionalidade | Esforço |
|-----------|-------|----------------|---------|
| 🔴 P0 | 0 | Corrigir bugs existentes | 1 dia |
| 🔴 P0 | 1 | Campanhas de doação | 2 dias |
| 🔴 P0 | 2 | Checkout avulso | 3 dias |
| 🔴 P0 | 3 | Doação recorrente | 3 dias |
| 🟡 P1 | 4 | Transparência pública | 2 dias |
| 🟡 P1 | 5 | Notificações + Webhooks | 2 dias |
| 🟢 P2 | 6 | Autenticação | 3 dias |
| 🟢 P2 | 7 | Frontend mínimo | 5 dias |

**Total estimado:** ~21 dias úteis (4 semanas) para MVP completo com TDD.
