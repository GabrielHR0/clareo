# Análise de Lacunas — Sistema Completo de Doações + Administração Financeira + Transparência

## Status Atual (MVP Funcional)

### ✅ O que já funciona
- Organizações com wallet
- Contribuidores com wallet
- Membership (vínculo contribuidor → organização)
- Transações financeiras: crédito, débito, transferência (com idempotência)
- Linhas de crédito (saque e repagamento)
- Métodos de pagamento (cartão)
- Ledger contábil (partidas dobradas)
- Eventos de auditoria imutáveis
- Health checks (/up, /health/cassandra)
- Documentação Swagger/OpenAPI
- Fake BaaS Gateway para desenvolvimento

---

## 🔴 Lacunas Críticas

### 1. Autenticação e Autorização
| Item | Status | Prioridade |
|------|--------|-----------|
| Cadastro de usuários (login/senha) | ❌ Não existe | 🔴 Crítica |
| JWT / OAuth2 | ❌ Não existe | 🔴 Crítica |
| API Key para organizações | Campo `api_key_hash` existe mas não é usado | 🟡 Média |
| Roles (admin, org_admin, contributor) | ❌ Não existe | 🔴 Crítica |
| Segregação por organização (multitenancy) | ❌ Não existe | 🔴 Crítica |

### 2. Planos de Doação / Campanhas
| Item | Status | Prioridade |
|------|--------|-----------|
| CRUD de campanhas de doação | ❌ Não existe | 🔴 Crítica |
| Metas de arrecadação com progresso | ❌ Não existe | 🟡 Média |
| Doação avulsa (checkout) | ❌ Não existe | 🔴 Crítica |
| Doação recorrente (assinatura) | Repositório existe mas com bug (`CassandraCluster`) | 🔴 Crítica |
| Página pública de doação | ❌ Não existe (API-only) | 🔴 Crítica |
| QR Code PIX / boleto | ❌ Não existe | 🟡 Média |
| Confirmação por email | ❌ Não existe | 🟡 Média |

### 3. Transparência e Prestação de Contas
| Item | Status | Prioridade |
|------|--------|-----------|
| Extrato público da organização | ❌ Não existe | 🔴 Crítica |
| Alocação de recursos (programas/projetos) | ❌ Não existe | 🔴 Crítica |
| Relatório gerencial mensal | ❌ Não existe | 🟡 Média |
| Recibo de doação para IR | ❌ Não existe | 🟡 Média |
| Dashboard público de transparência | ❌ Não existe | 🔴 Crítica |
| Comprovante de transferência para instituição | ❌ Não existe | 🟡 Média |

### 4. Notificações e Webhooks
| Item | Status | Prioridade |
|------|--------|-----------|
| Mailer de confirmação de doação | Layout existe, mailer não | 🔴 Crítica |
| Webhook para organizações (doação recebida) | Campo `webhook_url` existe, envio não | 🔴 Crítica |
| Notificação de falha de pagamento | ❌ Não existe | 🟡 Média |
| Resumo periódico de doações | ❌ Não existe | 🟡 Média |

### 5. Portais Web
| Item | Status | Prioridade |
|------|--------|-----------|
| Frontend de checkout de doação | ❌ Não existe (API-only) | 🔴 Crítica |
| Painel da organização (saldo, extrato) | ❌ Não existe | 🔴 Crítica |
| Portal do contribuidor (histórico) | ❌ Não existe | 🟡 Média |
| Admin panel | ❌ Não existe | 🟡 Média |

### 6. Integração Financeira Real
| Item | Status | Prioridade |
|------|--------|-----------|
| Gateway de pagamento real (Stripe/Pagar.me) | ❌ Fake apenas | 🔴 Crítica |
| Conciliação bancária | ❌ Não existe | 🟡 Média |
| Geração de arquivo CNAB (boletos) | ❌ Não existe | 🟡 Baixa |
| Suporte a PIX | ❌ Não existe | 🟡 Média |

### 7. Qualidade e Testes
| Item | Status | Prioridade |
|------|--------|-----------|
| Spec do `RecurringDonationsRepository` | ❌ Não existe | 🔴 Crítica |
| Spec do `SubscriptionChargeService` | ❌ Não existe | 🔴 Crítica |
| Spec de autenticação/autorização | ❌ Não existe | 🔴 Crítica |
| Cobertura de controllers (show/index) | Parcial (alguns retornam empty) | 🟡 Média |
| Testes de concorrência já existem | ✅ `transactions_concurrency_spec.rb` | — |
| Testes de idempotência já existem | ✅ `gateway_centralization_spec.rb` | — |

### 8. Bugs Conhecidos
| Bug | Arquivo | Status |
|-----|---------|--------|
| `CassandraCluster.instance` não definido | `recurring_donations_repository.rb` | 🔴 Não corrigido |
| `contributors#index` retorna `[]` sempre | `contributors_controller.rb` | 🟡 Não corrigido |
| `contributors#show` é um método vazio (204) | `contributors_controller.rb` | 🟡 Não corrigido |
| `organizations#index` retorna `[]` sempre | `organizations_controller.rb` | 🟡 Não corrigido |
| `campaign_id` como `uuid` vs `text` inconsistente | `migrations/05` vs `migrations/12` | 🟡 Não corrigido |

---

## Resumo por Camada

```
                     FRONTEND (❌)
                         |
                   API LAYER (⚠️ parcial)
     ┌─────────────────┼─────────────────┐
     |                 |                  |
  Auth/Users     Doações/Planos    Transparência
    (❌)             (❌)              (❌)
     |                 |                  |
     └─────────────────┼─────────────────┘
                       |
              SERVICE LAYER (✅ core)
          ProcessTransactionService
          CreditService, SubscriptionChargeService
                       |
              REPOSITORY LAYER (⚠️ bugs)
          Memberships: ✅ | Recurring: ❌ bug
                       |
              CASSANDRA CLUSTER (⚠️ 2/3 nós)
                       |
              FAKE BAAS GATEWAY (✅)
```
