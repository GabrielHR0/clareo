# Tela de Login / Onboarding

**Rota:** `/login` e `/register`
**Público:** Sim (sem autenticação)

> **⚠️ Atenção:** O fluxo de autenticação mudou. Agora é necessário criar um **usuário** (email + senha) primeiro, e depois criar uma **organização** vinculada a esse usuário. A API Key ainda existe, mas é usada apenas para integrações programáticas externas.

---

## Fluxo Novo

```
/login                    /register                        /organizations/new
  │                          │                                │
  ├── Email + Senha          ├── Nome                        ├── Nome da Org
  └── Entrar                 ├── Email                       ├── CNPJ (opcional)
                             ├── Senha                       └── Criar (vincula ao
                             └── Criar Conta                     usuário logado)
                                   │
                                   └── (logado automaticamente)
                                         └── Redireciona para /onboarding
                                               └── "Crie sua primeira organização"
```

## Endpoints Relacionados

### POST `/api/v1/organizations` — Criar organização (agora com JWT)
**Header:** `Authorization: Bearer <token>`

**Request:**
```json
{
  "organization": {
    "name": "Instituto Vida",
    "contact_email": "contato@vidar.org",
    "cnpj": "12.345.678/0001-90",
    "owner_user_id": "4c118bfb-..."  ← UUID do usuário logado
  }
}
```

**Response (201):**
```json
{
  "organization": {
    "organization_id": "a1b2c3d4-...",
    "name": "Instituto Vida"
  },
  "api_key": "g5x2k9q7m3r8v1p4t6w0...",
  "wallet": { ... }
}
```

---

## Tela de Onboarding (após cadastro)

Após o cadastro, se o usuário não tiver nenhuma organização, mostrar:

```
┌─────────────────────────────────────────────┐
│  🎉 Bem-vindo, João!                       │
│                                             │
│  Você ainda não tem nenhuma organização.   │
│                                             │
│  Crie sua primeira organização para         │
│  começar a gerenciar campanhas e doações.   │
│                                             │
│  [Criar Organização]                       │
└─────────────────────────────────────────────┘
```

---

## Dados no Frontend

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

// Interceptor: todas as requisições autenticadas enviam:
// Authorization: Bearer <token>

// Para criar organização:
const createOrg = async (data) => {
  const res = await fetch('/api/v1/organizations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ organization: data })
  });
  return res.json();
};
```

---

## Resumo dos Métodos de Autenticação

| Método | Header | Quem usa | Quando usar |
|--------|--------|----------|-------------|
| JWT | `Authorization: Bearer <token>` | Usuários do frontend | Login web, mobile |
| API Key | `X-API-Key: <key>` | Sistemas externos | Integrações, webhooks |
