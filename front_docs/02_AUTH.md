# Autenticação — Fluxo de Login e Cadastro

O sistema agora usa **JWT (Bearer token)** para autenticação de usuários. A API Key ainda existe para integrações programáticas (sistemas externos).

## Fluxo Completo

```
1. Usuário acessa /login
   ├── Já tem conta? → Login (email + senha) → recebe JWT
   └── Não tem? → Cadastro (nome, email, senha) → recebe JWT

2. Usuário logado pode:
   ├── Criar organização → POST /api/v1/organizations (autenticado com JWT)
   ├── Gerenciar campanhas, despesas, etc.
   └── Acessar /auth/me para ver dados do usuário
```

## Endpoints

### POST `/api/v1/auth/register` — Cadastro
**Público:** Sim

**Request:**
```json
{
  "email": "joao@email.com",
  "password": "minhaSenha123",
  "name": "João Silva"
}
```

**Response (201):**
```json
{
  "user": {
    "user_id": "4c118bfb-f04a-494e-b767-7da34ac483fa",
    "email": "joao@email.com",
    "name": "João Silva"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### POST `/api/v1/auth/login` — Login
**Público:** Sim

**Request:**
```json
{
  "email": "joao@email.com",
  "password": "minhaSenha123"
}
```

**Response (200):**
```json
{
  "user": {
    "user_id": "4c118bfb-f04a-494e-b767-7da34ac483fa",
    "email": "joao@email.com",
    "name": "João Silva"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### GET `/api/v1/auth/me` — Dados do usuário logado
**Header:** `Authorization: Bearer <token>`

**Response (200):**
```json
{
  "user": {
    "user_id": "4c118bfb-f04a-494e-b767-7da34ac483fa",
    "email": "joao@email.com",
    "name": "João Silva"
  }
}
```

---

## Telas

### Tela de Login

```
┌─────────────────────────────────────────┐
│              LOGO CLAREO               │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  Entrar                             ││
│  │                                     ││
│  │  Email                              ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  Senha                              ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  [Entrar]                          ││
│  │                                     ││
│  │  Não tem conta? [Cadastre-se]      ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Tela de Cadastro

```
┌─────────────────────────────────────────┐
│              LOGO CLAREO               │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  Criar Conta                        ││
│  │                                     ││
│  │  Nome Completo *                   ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  Email *                           ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  Senha *                           ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  Confirmar Senha *                 ││
│  │  [_____________________________]   ││
│  │                                     ││
│  │  [Criar Conta]                     ││
│  │                                     ││
│  │  Já tem conta? [Fazer Login]       ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Dados Salvos no Frontend
```typescript
// localStorage
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "user_id": "4c118bfb-...",
    "email": "joao@email.com",
    "name": "João Silva"
  }
}
```

### Interceptor de API
Toda requisição autenticada envia:
```
Authorization: Bearer <token>
```

---

## Regras de Autenticação no Backend

| Critério | Comportamento |
|----------|--------------|
| Header `Authorization: Bearer <token>` | Autentica como **usuário** (`@current_user`) |
| Header `X-API-Key: <key>` | Autentica como **organização** (`@current_organization`) |
| Nenhum header | 401 "Authentication required" |
| Token inválido/expirado | 401 "Invalid or expired token" |
| API Key inválida | 401 "Invalid API key" |

**Rotas públicas** (pulam auth):
- `/up`, `/health/*`, `/api-docs/*`
- `/public/*` (checkout, accountability)
- `/auth/register`, `/auth/login`
- `Rails.env.test?` (todo o ambiente de teste)
