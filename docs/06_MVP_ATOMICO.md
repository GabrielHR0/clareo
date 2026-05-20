# MVP até quarta-feira (foco: Cassandra distribuído)

Objetivo: deixar o banco Cassandra distribuído **pronto para a aplicação** e entregar o fluxo mínimo de doação recorrente persistindo no Cassandra.

## Escopo do MVP (até quarta)

1. Cluster Cassandra local com 3 nós funcionando.
2. Keyspace e tabelas do MVP criadas.
3. Estratégia de partição e consistência definida e aplicada.
4. App Rails conectando e escrevendo/lendo dados no Cassandra.
5. Fluxo mínimo: organização + contribuinte + plano + recorrência + transação + wallet.
6. Checklist técnico de validação do banco distribuído.

## Fora do MVP

- Crédito.
- Floating.
- Dashboard avançado.
- Compliance completo.
- Otimizações de produção.

## Princípio de atomicidade

- Cada task deve ter 1 resultado verificável.
- Task não deve depender de "metade" da task de outra pessoa.
- Dependências explícitas por ID.

## Frentes de trabalho (sem conflito)

### Pessoa A - Infra e Data Plane Cassandra
Responsável por cluster, schema, consistência, scripts e validação de banco distribuído.

### Pessoa B - Integração App com Cassandra
Responsável por conexão no Rails, repositórios de acesso, endpoints mínimos e testes de integração.

## Tasks atômicas (com dependências)

### Pessoa A (Cassandra)

- [ ] A1. Subir cluster Cassandra com 3 nós no Docker Compose.  
  **Saída:** `docker ps` com os 3 nós ativos.

- [ ] A2. Validar health dos 3 nós (`nodetool status`).  
  **Depende de:** A1  
  **Saída:** status `UN` nos 3 nós.

- [ ] A3. Criar keyspace `clareo` com RF=3.  
  **Depende de:** A2  
  **Saída:** `DESCRIBE KEYSPACE clareo`.

- [ ] A4. Criar tabela `organizations` com partition key correta.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.organizations`.

- [ ] A5. Criar tabela `contributors`.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.contributors`.

- [ ] A6. Criar tabela `donation_plans`.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.donation_plans`.

- [ ] A7. Criar tabela `recurring_donations`.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.recurring_donations`.

- [ ] A8. Criar tabela `wallets`.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.wallets`.

- [ ] A9. Criar tabela `transactions`.  
  **Depende de:** A3  
  **Saída:** `DESCRIBE TABLE clareo.transactions`.

- [ ] A10. Definir e documentar consistency levels do MVP (read/write).  
  **Depende de:** A3  
  **Saída:** seção no doc com regras (`QUORUM`, `LOCAL_QUORUM`, etc.).

- [ ] A11. Criar script seed mínimo para dados de teste no Cassandra.  
  **Depende de:** A4, A5, A6, A7, A8, A9  
  **Saída:** script executando inserts básicos.

- [ ] A12. Criar script de smoke test do banco distribuído (insert/read em 3 nós).  
  **Depende de:** A10, A11  
  **Saída:** relatório simples de sucesso/falha.

### Pessoa B (Rails + integração)

- [ ] B1. Definir contrato JSON dos 5 recursos do MVP (`organization`, `contributor`, `donation_plan`, `recurring_donation`, `transaction`).  
  **Saída:** arquivo de contratos.

- [ ] B2. Configurar cliente Cassandra no Rails (env + initializer).  
  **Saída:** conexão iniciando com a app.

- [ ] B3. Criar `healthcheck` de Cassandra na API (`/health/cassandra`).  
  **Depende de:** B2  
  **Saída:** endpoint respondendo OK quando conecta.

- [ ] B4. Criar repositório Cassandra para `organizations` (write/read).  
  **Depende de:** B2, A4  
  **Saída:** método create/get funcionando.

- [ ] B5. Criar endpoint mínimo de organização usando repositório Cassandra.  
  **Depende de:** B4, B1  
  **Saída:** POST/GET organização funcionando.

- [ ] B6. Criar repositório Cassandra para `contributors`.  
  **Depende de:** B2, A5  
  **Saída:** create/get contributor funcionando.

- [ ] B7. Criar endpoint mínimo de contributor.  
  **Depende de:** B6, B1  
  **Saída:** POST contributor funcionando.

- [ ] B8. Criar repositório Cassandra para `donation_plans` e `recurring_donations`.  
  **Depende de:** B2, A6, A7  
  **Saída:** create/get para plano e recorrência.

- [ ] B9. Criar endpoint mínimo para plano e recorrência.  
  **Depende de:** B8, B1  
  **Saída:** POST plano e POST recorrência funcionando.

- [ ] B10. Criar repositório para `wallets` e `transactions` com operação básica de doação.  
  **Depende de:** B2, A8, A9, A10  
  **Saída:** método `process_donation` (transação + atualização de wallet).

- [ ] B11. Criar endpoint manual de processar doação.  
  **Depende de:** B10, B1  
  **Saída:** POST `/donations/process` funcionando.

- [ ] B12. Criar teste de integração ponta a ponta do fluxo mínimo no Cassandra.  
  **Depende de:** B5, B7, B9, B11, A12  
  **Saída:** teste verde com evidência.

## Planejamento por dia (até quarta)

### Dia 1
- Pessoa A: A1, A2, A3, A4, A5  
- Pessoa B: B1, B2, B3

### Dia 2
- Pessoa A: A6, A7, A8, A9, A10  
- Pessoa B: B4, B5, B6, B7

### Dia 3
- Pessoa A: A11, A12  
- Pessoa B: B8, B9, B10

### Quarta
- Pessoa B: B11, B12  
- Ambos: fechamento com checklist final e correções rápidas

## Checklist de pronto (banco distribuído)

- [ ] 3 nós Cassandra em `UN`.
- [ ] Keyspace `clareo` com RF=3 criado.
- [ ] Tabelas do MVP criadas.
- [ ] Leitura/escrita no Cassandra pela app funcionando.
- [ ] Fluxo mínimo da doação passando.
- [ ] Smoke test de distribuição executado.
- [ ] Teste de integração de ponta a ponta verde.

