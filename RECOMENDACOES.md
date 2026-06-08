# Recomendações Pendentes

## Auth / Login
- [ ] Frontend: implementar fluxo de login com JWT (Bearer token) — atualmente o backend já suporta `POST /auth/login` e `POST /auth/register`
- [ ] Frontend: armazenar token JWT e enviar no header `Authorization: Bearer <token>` em todas as requisições autenticadas
- [ ] Tratar renovação/exiração do token (24h expiry)

## Organização
- [ ] Vincular organização ao usuário logado (`owner_user_id`) no momento da criação
- [ ] Listar organizações do usuário logado
- [ ] Permitir que o usuário selecione/chave de organização ativa

## Doação Direta
- [ ] Consumir endpoint `POST /api/v1/public/donate/:organization_id` no frontend
- [ ] Integrar formulário de doação direta (sem campanha) na página pública de cada instituição

## Dashboard
- [ ] Consumir endpoint `GET /api/v1/dashboard/metrics` (agregados da organização)
- [ ] Exibir gráficos de métricas (arrecadação total, doadores, campanhas ativas, etc.)

## Filtros
- [ ] Revisar filtros quebrados de campanhas e despesas (alguns filtros podem estar enviando parâmetros incorretos)

## Paginação
- [ ] Ajustar frontend para usar o parâmetro `limit` (o backend já aceita 1–500, default 100) em listas de campanhas e despesas

## Pagamento
- [ ] Revisar integração do gateway de pagamento (checkout público) — certificar que os parâmetros corretos são enviados

## Conta/Perfil do Usuário
- [ ] Implementar página de perfil do usuário logado
- [ ] Exibir/editar dados da conta (email, nome)
- [ ] Gerenciar senha

## Wallet
- [ ] Exibir saldo e transações da wallet do usuário
- [ ] Tela de extrato / histórico de transações

## Membros
- [ ] CRUD de membros da organização
- [ ] Convidar, listar, remover membros

## Public Checkout
- [ ] Garantir que a página pública de checkout funcione corretamente sem autenticação
- [ ] Validar redirecionamento pós-pagamento

## Traduções / i18n
- [ ] Pendências de labels e mensagens em português vs inglês no frontend

## Testes
- [ ] Testes de frontend (componentes, integração) — verificar setup atual
- [ ] Garantir que o fluxo de login → organização → dashboard funciona ponta a ponta

## Swagger / Docs
- [ ] Atualizar docs da API no frontend (se aplicável)
- [ ] Sincronizar schemas e exemplos com o backend atualizado
