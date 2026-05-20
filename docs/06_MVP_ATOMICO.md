# MVP até quarta-feira

Objetivo: entregar um MVP funcional de doações recorrentes com foco em cadastro de organizações, contribuições recorrentes e carteira básica.

## Escopo do MVP

1. Cadastro e listagem de organizações.
2. Cadastro de contribuidores.
3. Criação de planos de doação recorrente.
4. Vinculação contribuinte + plano + organização.
5. Carteira básica da organização.
6. Registro de transação de doação.
7. Evento Kafka para doação processada.
8. Endpoint simples para consultar status.

## Fora do MVP

- Crédito.
- Floating / aplicação financeira.
- Dashboard avançado.
- Webhooks externos.
- Mobile app.
- Compliance avançado.

## Regras de trabalho

- Duas pessoas.
- Cada task deve caber em uma sessão curta.
- Uma task deve gerar um artefato verificável.
- Se uma task depender da outra, o output deve ser explícito.
- Priorizar entrega funcional antes de refino.

## Divisão por pessoa

### Pessoa A - Backend e dados

1. Criar estrutura Rails mínima.
2. Criar conexão com Cassandra.
3. Criar model Organization.
4. Criar model Contributor.
5. Criar model DonationPlan.
6. Criar model RecurringDonation.
7. Criar model Wallet.
8. Criar model Transaction.
9. Criar serviço de processamento de doação.
10. Criar publicação de evento no Kafka.

### Pessoa B - Produto, API e validação

1. Definir payloads das APIs.
2. Criar endpoints de organizações.
3. Criar endpoints de contribuidores.
4. Criar endpoints de planos recorrentes.
5. Criar endpoint de disparo manual de doação.
6. Criar resposta padrão de sucesso/erro.
7. Criar validações de entrada.
8. Criar testes de contrato.
9. Criar testes de fluxo do MVP.
10. Validar o comportamento final com um checklist.

## Tasks atômicas

### Pessoa A

- [ ] A1. Criar projeto Rails mínimo com as gems base.
- [ ] A2. Subir Cassandra local e validar conexão.
- [ ] A3. Criar tabela/model Organization.
- [ ] A4. Criar endpoint de criação de organização.
- [ ] A5. Criar tabela/model Contributor.
- [ ] A6. Criar endpoint de criação de contribuinte.
- [ ] A7. Criar tabela/model DonationPlan.
- [ ] A8. Criar endpoint de criação de plano recorrente.
- [ ] A9. Criar tabela/model RecurringDonation.
- [ ] A10. Criar serviço que agenda a doação.
- [ ] A11. Criar tabela/model Wallet.
- [ ] A12. Criar lógica de saldo da wallet.
- [ ] A13. Criar tabela/model Transaction.
- [ ] A14. Registrar transação de doação.
- [ ] A15. Publicar evento Kafka de doação concluída.

### Pessoa B

- [ ] B1. Definir contrato JSON do cadastro de organização.
- [ ] B2. Definir contrato JSON do cadastro de contribuinte.
- [ ] B3. Definir contrato JSON do plano recorrente.
- [ ] B4. Definir contrato JSON da execução manual de doação.
- [ ] B5. Criar validação de campos obrigatórios.
- [ ] B6. Criar validação de valores monetários.
- [ ] B7. Criar resposta padrão de erro da API.
- [ ] B8. Criar teste de contrato para organizações.
- [ ] B9. Criar teste de contrato para doação recorrente.
- [ ] B10. Criar teste de fluxo do MVP.
- [ ] B11. Criar checklist de aceite do MVP.
- [ ] B12. Revisar logs e mensagens de erro.

## Ordem recomendada

### Dia 1
- Pessoa A: A1, A2, A3, A4
- Pessoa B: B1, B5, B7, B8

### Dia 2
- Pessoa A: A5, A6, A7, A8
- Pessoa B: B2, B3, B6, B9

### Dia 3
- Pessoa A: A9, A10, A11, A12
- Pessoa B: B4, B10, B11, B12

### Dia 4
- Pessoa A: A13, A14, A15
- Pessoa B: validar tudo junto e fechar pendências

## Critério de pronto do MVP

- Organização criada com sucesso.
- Contribuinte criado com sucesso.
- Plano recorrente criado com sucesso.
- Doação executada e registrada.
- Wallet atualizada.
- Evento publicado no Kafka.
- Testes mínimos passando.
- Fluxo validado de ponta a ponta.

