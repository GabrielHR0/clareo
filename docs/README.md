# 🚀 Clareo - Sistema de Doações com Fintech

Plataforma escalável de doações recorrentes para instituições religiosas e sem fins lucrativos, com uma fintech integrada.

## 📋 Documentação

### 1️⃣ Fundamentals
- **[01_VISAO_GERAL.md](./01_VISAO_GERAL.md)** - Visão geral do projeto, problemas a resolver, escopo do MVP
- **[02_ARQUITETURA.md](./02_ARQUITETURA.md)** - Arquitetura de sistema, camadas, padrões de consistência

### 2️⃣ Infraestrutura Técnica
- **[03_MODELO_DADOS.md](./03_MODELO_DADOS.md)** - Schemas Cassandra, tabelas, índices, estratégia de partição
- **[04_PLANO_EXECUCAO.md](./04_PLANO_EXECUCAO.md)** - Fases do projeto, timeline, riscos e mitigações
- **[05_KAFKA_STRATEGY.md](./05_KAFKA_STRATEGY.md)** - Event streaming, tópicos, consumer groups, garantias
- Task de tópicos Kafka: `bundle exec rake kafka:create_topics`
- **[06_MVP_ATOMICO.md](./06_MVP_ATOMICO.md)** - Tasks atômicas do MVP divididas para duas pessoas

## 📚 Conceitos-Chave

### ACID em Banco Distribuído
```
Cassandra é Eventually Consistent, mas implementamos:
├─ Lightweight Transactions (LWT)
├─ Idempotency keys (deduplicação)
├─ Versioning de saldo
├─ Saga pattern (transações complexas)
└─ Ledger imutável (auditoria)
```

### Event Streaming com Kafka
```
Tópicos principais:
├─ donations.created
├─ transactions.posted
├─ wallets.balance_changed
├─ floating.interest_applied
├─ audit.events
└─ credit.line_used

Consumers:
├─ Webhook service
├─ Analytics service
├─ Notifications service
├─ Reconciliation service
└─ Audit logger
```

## 🔧 Troubleshooting

### Testes falhando
```bash
# Setup databases
rails db:create db:test:load
bundle exec rake cassandra:setup RAILS_ENV=test
bundle exec rake kafka:create_topics RAILS_ENV=test

# Rodar testes
bundle exec rspec
```

### Cassandra connection error
```bash
# Verificar se está rodando
docker-compose ps cassandra

# Reiniciar
docker-compose restart cassandra

# Check status
cqlsh -e "SELECT now() FROM system.local;"
```

### Docker (dev + cluster)
- Suba primeiro o `cassandra1` para virar seed.
- Depois suba o cluster:
```bash
docker compose -f docker-compose.cluster.yml up -d
```
- No dev, o Rails usa o Cassandra do cluster via `host.docker.internal`:
```bash
docker compose -f docker-compose.dev.yml up -d
```
- Se o cluster ficar inconsistente, recrie limpo:
```bash
docker compose -f docker-compose.cluster.yml down -v
docker compose -f docker-compose.cluster.yml up -d
```

---

## 📞 Contato & Comunidade

- 📧 Email: dev@clareo.dev
- 💬 Slack: [Link do workspace]
- 📖 Docs: https://docs.clareo.dev
- 🐛 Issues: https://github.com/seu-org/clareo/issues

---

## 📄 Licença

MIT License - veja LICENSE.md

---

## 🙏 Contribuindo

1. Fork o repositório
2. Crie uma branch (`git checkout -b feature/amazing-feature`)
3. Commit suas mudanças (`git commit -m 'Add amazing feature'`)
4. Push para a branch (`git push origin feature/amazing-feature`)
5. Abra um Pull Request

---

**Desenvolvido com ❤️ para o ecossistema de doações recorrentes**

*Última atualização: 2026-05-19*
