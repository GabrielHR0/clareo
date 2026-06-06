# Visão Geral — Frontend Clareo

## Stack Sugerida
- **Framework:** React + TypeScript (Vite)
- **Estado global:** React Query (TanStack Query) para cache e sincronização com API
- **Roteamento:** React Router v6
- **UI:** Tailwind CSS + componentes customizados
- **Autenticação:** JWT Bearer token armazenado no `localStorage`, enviado via header `Authorization: Bearer <token>`
- **Upload de arquivos:** Multipart form via fetch direto

## Autenticação

### JWT (Usuários do Frontend)
Toda rota autenticada via frontend envia:
```
Authorization: Bearer <token>
```
O token JWT é obtido via `POST /api/v1/auth/register` ou `POST /api/v1/auth/login`.
Válido por 24h. Armazenar no `localStorage`.

### API Key (Integrações Externas)
Sistemas externos ainda podem usar:
```
X-API-Key: <api_key>
```
A API Key é gerada ao criar a organização e exibida **uma única vez**.

### Rotas Públicas (sem autenticação)
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/public/checkout`
- `GET /api/v1/public/campaigns/:campaign_id/accountability`
- `/health/*`, `/up`, `/api-docs/*`

---

## Fluxo de Uso

```
1. GET /register → Cadastro (nome, email, senha)
2. POST /auth/register → Recebe JWT + user data
3. Redireciona para /onboarding
4. GET /organizations/new → Criar primeira organização
5. POST /organizations → Vincula ao usuário logado
6. Redireciona para /dashboard
```

---

## Lista de Telas

### 1. Auth — Login / Cadastro
**Rotas:** `/login`, `/register`
**Público:** Sim
**Descrição:** Login com email+senha ou cadastro de novo usuário. Após cadastro, recebe JWT e é redirecionado para onboarding.

### 2. Onboarding
**Rota:** `/onboarding`
**Público:** Não (requer JWT)
**Descrição:** Tela mostrada após o cadastro, quando o usuário ainda não tem nenhuma organização. Convida a criar a primeira organização.

### 3. Dashboard
**Rota:** `/dashboard`
**Público:** Não (autenticado)
**Descrição:** Visão geral da organização com métricas financeiras, campanhas ativas, transações recentes. É o ponto de partida após o login.

### 4. Campanhas
**Rotas:**
- Listagem: `/campaigns`
- Criar: `/campaigns/new`
- Detalhe: `/campaigns/:id`
**Público:** Não
**Descrição:** CRUD completo de campanhas de arrecadação. Cada campanha tem meta, progresso, despesas associadas e extrato de transações.

### 5. Despesas
**Rotas:**
- Listagem: `/campaigns/:campaignId/expenses`
- Criar: `/campaigns/:campaignId/expenses/new`
- Detalhe: `/campaigns/:campaignId/expenses/:id`
- Editar: `/campaigns/:campaignId/expenses/:id/edit`
**Público:** Não
**Descrição:** Gestão de despesas de cada campanha. Suporta upload de anexos (notas fiscais, comprovantes) e download.

### 6. Contribuintes
**Rotas:**
- Listagem: `/contributors`
- Detalhe: `/contributors/:id`
**Público:** Não
**Descrição:** Lista de contribuintes da organização com vínculos (memberships) e doações recorrentes.

### 7. Doações Recorrentes
**Rota:** `/contributors/:contributorId/recurring`
**Público:** Não
**Descrição:** Gerencia assinaturas/de assinaturas de cada contribuinte. Permite cancelar doações recorrentes.

### 8. Carteira e Transações
**Rotas:**
- Carteira: `/wallet`
- Transações: `/transactions`
- Detalhe da transação: `/transactions/:id`
**Público:** Não
**Descrição:** Extrato financeiro completo. Saldo atual, transações de crédito/débito, transferências. Suporta filtro por campanha, tipo, período.

### 9. Linhas de Crédito
**Rotas:**
- Listagem: `/credit-lines`
- Criar: `/credit-lines/new`
- Detalhe: `/credit-lines/:id`
**Público:** Não
**Descrição:** Gestão de linhas de crédito da organização. Permite contratar, visualizar limite disponível e sacar valores.

### 10. Métodos de Pagamento
**Rota:** `/payment-methods`
**Público:** Não
**Descrição:** Gerencia cartões e formas de pagamento vinculadas à organização ou contribuintes.

### 11. Membros (Memberships)
**Rota:** `/memberships`
**Público:** Não
**Descrição:** Gerencia vínculos entre contribuintes e organização. Cada membership tem um papel (admin, user).

### 12. Configurações da Organização
**Rota:** `/settings`
**Público:** Não
**Descrição:** Editar dados da organização (nome, email, webhook URL, CNPJ). Gerenciar API Key.

---

## Telas Públicas (Sem Autenticação)

### 13. Checkout / Doação
**Rota:** `/public/donate/:campaignId`
**Público:** Sim
**Descrição:** Página pública de doação. O doador informa nome, email, valor e método de pagamento. A doação é processada via endpoint público.

### 14. Prestação de Contas
**Rota:** `/public/accountability/:campaignId`
**Público:** Sim
**Descrição:** Página pública de transparência. Mostra quanto foi arrecadado, quanto foi gasto, saldo restante e lista de despesas com anexos. Qualquer pessoa pode acessar sem login.

---

## Mapa de Navegação (Autenticado)

```
/register
  └── /login
        └── /onboarding (criar primeira organização)
              └── /dashboard (home)
                    ├── /campaigns
                    │     ├── /campaigns/new
                    │     └── /campaigns/:id
                    │           ├── (expenses tab)
                    │           │     ├── /campaigns/:id/expenses
                    │           │     ├── /campaigns/:id/expenses/new
                    │           │     └── /campaigns/:id/expenses/:expenseId
                    │           └── (transactions tab)
                    ├── /contributors
                    │     └── /contributors/:id
                    │           └── /contributors/:id/recurring
                    ├── /transactions
                    │     └── /transactions/:id
                    ├── /wallet
                    ├── /credit-lines
                    │     └── /credit-lines/new
                    ├── /payment-methods
                    ├── /memberships
                    └── /settings
```

## Mapa de Navegação (Público)

```
/public/donate/:campaignId
/public/accountability/:campaignId
```
