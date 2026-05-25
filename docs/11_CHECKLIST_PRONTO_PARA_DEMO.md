# Checklist Pronto para Demo (MVP Cassandra + API)

**Data**: 25 de maio de 2026  
**Objetivo**: validar ambiente, subir aplicação e demonstrar fluxo principal com segurança.

---

## 1) Pré-check rápido

- [ ] Estou na raiz do projeto.
- [ ] Ruby e Bundler disponíveis.
- [ ] Docker ativo.
- [ ] Variáveis do `.env` preenchidas.

Comandos:

```bash
pwd
ruby -v
bundle -v
docker -v
cat .env
```

---

## 2) Dependências da aplicação

- [ ] Gems instaladas sem erro.

```bash
bundle install
```

---

## 3) Subir Cassandra distribuído

- [ ] Cluster Cassandra de 3 nós está ativo.
- [ ] Nós em status `UN`.

```bash
docker compose -f docker-compose.cluster.yml up -d
docker exec cassandra1 nodetool status
```

Se houver conflito de bootstrap/token em ambiente de teste local:

```bash
docker compose -f docker-compose.cluster.yml down -v
docker compose -f docker-compose.cluster.yml up -d
```

---

## 4) Aplicar schema Cassandra

- [ ] Keyspace criado.
- [ ] Migrations aplicadas com sucesso.

```bash
bin/rails cassandra:migrate
```

Validação:

```bash
docker exec -it cassandra1 cqlsh -k clareo -e "DESCRIBE TABLES;"
```

---

## 5) Subir API Rails

- [ ] Servidor Rails sobe sem erro.

```bash
bin/rails s
```

Se falhar, diagnosticar rapidamente:

```bash
bin/rails s --trace
```

---

## 6) Health checks

- [ ] Health Rails responde.
- [ ] Health Cassandra via API responde `status: ok`.

```bash
curl -s http://localhost:3000/up
curl -s http://localhost:3000/health/cassandra
```

---

## 7) Validar endpoints principais (MVP atual)

### 7.1 Organizations

- [ ] Criar organization.

```bash
curl -s -X POST http://localhost:3000/organizations \
  -H "Content-Type: application/json" \
  -d '{"organization":{"name":"Org Demo","cnpj":"12345678000195","status":"active"}}'
```

### 7.2 Contributors

- [ ] Criar contributor.

```bash
curl -s -X POST http://localhost:3000/contributors \
  -H "Content-Type: application/json" \
  -d '{"contributor":{"name":"Contrib Demo","email":"demo@example.com","cpf":"12345678901","status":"active"}}'
```

### 7.3 Memberships (vínculo)

- [ ] Criar membership entre organization e contributor.

```bash
curl -s -X POST http://localhost:3000/memberships \
  -H "Content-Type: application/json" \
  -d '{"membership":{"organization_id":"<ORG_UUID>","contributor_id":"<CONTRIBUTOR_UUID>","status":"active"}}'
```

### 7.4 Wallet

- [ ] Consultar wallet por owner.

```bash
curl -s http://localhost:3000/owners/organization/<OWNER_UUID>/wallet
```

### 7.5 Transactions

- [ ] Criar transação por owner com idempotência.

```bash
curl -s -X POST http://localhost:3000/owners/organization/<OWNER_UUID>/transactions \
  -H "Content-Type: application/json" \
  -d '{"transaction":{"amount_cents":1000,"currency":"BRL","transaction_type":"credit","idempotency_key":"demo-key-001"}}'
```

- [ ] Repetir mesma requisição com a mesma `idempotency_key` e confirmar que não duplica.

---

## 8) Rodar testes chave do estado atual

- [ ] Request specs principais passando.

```bash
bundle exec rspec spec/requests/organization_spec.rb spec/requests/contributors_spec.rb spec/requests/memberships_spec.rb
```

- [ ] (Opcional) Rodar suíte completa de requests.

```bash
bundle exec rspec spec/requests
```

---

## 9) Script de demo para apresentação

- [ ] Mostrar cluster distribuído (`nodetool status`).
- [ ] Mostrar migrations aplicadas (`DESCRIBE TABLES`).
- [ ] Mostrar health API + Cassandra.
- [ ] Criar organization.
- [ ] Criar contributor.
- [ ] Criar membership.
- [ ] Criar transação com `idempotency_key`.
- [ ] Repetir request e mostrar comportamento idempotente.

---

## 10) Critério de “pronto para demo”

Marque como pronto somente se:

- [ ] Cluster com 3 nós `UN`.
- [ ] API sobe sem erro.
- [ ] Health Cassandra via API = ok.
- [ ] CRUD básico (organization/contributor/membership) funcionando.
- [ ] Criação de transação por owner funcionando.
- [ ] Idempotência validada com retry.
- [ ] Request specs principais verdes.

---

## 11) Problemas conhecidos e ação imediata

### `curl .../health/cassandra` retorna erro de conexão

- Verifique se o Rails está de pé.
- Verifique host/porta no `.env`.
- Verifique se Cassandra está acessível no host configurado.

### Erro de UUID no Cassandra (bind)

- Garantir que os repositories normalizam UUID para `Cassandra::Uuid`.
- Referência: `docs/08_UUID_BINDING_CASSANDRA.md`.

### `rails s` falha na inicialização

- Rodar com trace e checar a primeira exceção real:

```bash
bin/rails s --trace
```

---

## 12) Ordem recomendada (resumo de execução)

```bash
bundle install
docker compose -f docker-compose.cluster.yml up -d
bin/rails cassandra:migrate
bin/rails s
```

Em outro terminal:

```bash
curl -s http://localhost:3000/health/cassandra
bundle exec rspec spec/requests/organization_spec.rb spec/requests/contributors_spec.rb spec/requests/memberships_spec.rb
```

---

*Última atualização: 25 de maio de 2026*
