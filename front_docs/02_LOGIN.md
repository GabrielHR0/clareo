# Tela de Login / Onboarding

**Rota:** `/login`
**Público:** Sim (sem autenticação)
**Objetivo:** Permitir que a organização acesse o sistema. Se já tem API Key, faz login. Se não tem, cria uma conta e recebe a chave.

---

## Fluxo da Tela

```
[Usuário chega no /login]
        │
        ├── [Já tem API Key?] ──> Formulário de login (1 campo)
        │                              └── Digita a API Key
        │                                    └── GET /dashboard (valida key)
        │
        └── [Não tem conta?] ──> Formulário de cadastro
                                     ├── Nome da organização (obrigatório)
                                     ├── Email de contato (opcional)
                                     └── CNPJ (opcional)
                                           └── POST /api/v1/organizations
                                                 └── Recebe API Key (mostrar 1 vez!)
```

---

## Endpoints Utilizados

### POST `/api/v1/organizations` — Criar organização
**Header:** `X-API-Key` não é necessário (mas se estiver presente, é ignorado para criação)

**Request Body:**
```json
{
  "organization": {
    "name": "Instituto Vida",
    "contact_email": "contato@vidar.org",
    "cnpj": "12.345.678/0001-90"
  }
}
```

**Response (201 Created):**
```json
{
  "organization_id": "a1b2c3d4-...",
  "name": "Instituto Vida",
  "api_key": "g5x2k9q7m3r8v1p4t6w0..."  ← MOSTRAR APENAS UMA VEZ
}
```

**⚠️ Importante:** Exibir a `api_key` em destaque (caixa de aviso) e instruir o usuário a salvá-la. Oferecer botão "Copiar chave". Só prosseguir após confirmar que salvou.

---

### POST `/api/v1/organizations` — Dados para criar organização (via formulário)

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `name` | string | Sim | Nome da organização |
| `contact_email` | string | Não | Email para contato |
| `cnpj` | string | Não | CNPJ (com ou sem pontuação) |
| `external_id` | string | Não | ID externo (se aplicável) |
| `webhook_url` | string | Não | URL para webhooks |
| `status` | string | Não | Status inicial (default: "active") |

---

## Formulário de Login

### Campo: API Key
| Propriedade | Detalhe |
|-------------|---------|
| **Label** | Chave de Acesso (API Key) |
| **Tipo** | `password` (texto mascarado) |
| **Placeholder** | Cole sua API Key aqui |
| **Validação** | Não vazio, mínimo 20 caracteres |
| **Ação** | Salva no `localStorage` e redireciona para `/dashboard` |

**Como validar a chave:** Tentar carregar o dashboard (`GET /organizations/:id/dashboard`). Se der 401, a chave é inválida.

---

## Fluxo "Esqueci minha chave"

Como a API Key é mostrada apenas uma vez na criação, implementar um fluxo de **regeneração**:

1. Usuário clica em "Perdi minha chave"
2. Precisa ter acesso admin (ou validar por email — a implementar)
3. **Endpoint:** `POST /api/v1/organizations/:id/regenerate_key` (não existe ainda — pendente no backend)

---

## Exemplo de Estados da Tela

### Estado: Sem chave (primeiro acesso)
```
┌─────────────────────────────────────────┐
│  ┌────────────────────────────────────┐  │
│  │         LOGO CLAREO               │  │
│  └────────────────────────────────────┘  │
│                                           │
│  ┌──────────────────────────────────────┐ │
│  │  Já tenho uma chave de acesso       │ │
│  │  [________________________] [Entrar]│ │
│  └──────────────────────────────────────┘ │
│                                           │
│  ┌──────────────────────────────────────┐ │
│  │  Sou nova organização               │ │
│  │  Nome: [________________________]   │ │
│  │  Email: [________________________]  │ │
│  │  CNPJ:  [________________________]  │ │
│  │  [Criar conta]                     │ │
│  └──────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Estado: API Key gerada (mostrar uma vez)
```
┌─────────────────────────────────────────┐
│  ✅ Conta criada com sucesso!           │
│                                           │
│  ⚠️  Guarde esta chave em local seguro.  │
│      Ela não será mostrada novamente.    │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │ Sua API Key:                       │  │
│  │ g5x2k9q7m3r8v1p4t6w0...           │  │
│  │ [Copiar chave]                     │  │
│  └─────────────────────────────────────┘  │
│                                           │
│  [Ir para o Dashboard]                    │
└─────────────────────────────────────────┘
```

---

## Dados Salvos no Frontend

```typescript
// localStorage
{
  "api_key": "g5x2k9q7m3r8v1p4t6w0...",
  "organization_id": "a1b2c3d4-...",
  "organization_name": "Instituto Vida"
}
```
