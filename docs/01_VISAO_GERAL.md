# Clareo - Sistema de Doações Recorrentes com Fintech

## Visão Geral do Projeto

Clareo é uma plataforma de doações recorrentes para instituições religiosas e sem fins lucrativos, com uma fintech integrada que gerencia carteiras, crédito e aplicação dinâmica de recursos.

### Problemas a Resolver
1. **Doações Recorrentes**: Permitir que contribuidores façam doações periódicas (diárias, semanais, mensais) sem fricção
2. **Gestão de Carteira**: Instituições precisam visualizar e gerenciar seus fundos em tempo real
3. **Escalabilidade**: Sistema deve suportar milhares de transações simultâneas
4. **Conformidade ACID**: Mesmo com banco distribuído, operações financeiras devem ser garantidas
5. **Rentabilidade**: Dinheiro parado deve gerar retorno (floating)

---

## Escopo da Solução

### MVP (Phase 1)
- Cadastro de organizações
- Configuração de planos de doação recorrente
- Sistema de contribuintes
- Carteira básica com saldo
- Transações de depósito
- Dashboard de visibilidade

### Phase 2
- Sistema de crédito (antecipação de rendimentos)
- Aplicação automática em ativos de baixa volatilidade
- Relatórios financeiros
- Webhook para integrações

### Phase 3
- Investimentos diversificados
- Programa de fidelização
- Mobile app
- Compliance e KYC

---

## Stack Tecnológico

- **Backend**: Ruby on Rails (7.0+)
- **Banco de Dados Primário**: Cassandra (distribuído)
- **Cache/Sessão**: Redis
- **Event Streaming**: Apache Kafka
- **Fila de Processamento**: Sidekiq
- **API**: REST + GraphQL
- **Autenticação**: JWT + OAuth2
- **Container**: Docker + Kubernetes
- **Monitoramento**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)

---

## Desafios Técnicos Principais

### 1. ACID em Banco Distribuído
- **Problema**: Cassandra é Eventually Consistent (não ACID nativo)
- **Solução**: 
  - Usar transaction-like patterns em Rails
  - Implementar saga pattern para operações distribuídas
  - Ledger imutável para auditoria
  - Locks distribuídos (Redis ou similar)

### 2. Consistência de Saldo
- Usar Lightweight Transactions (LWT) em Cassandra
- Versioning de saldo com timestamps
- Event sourcing para reconstrução de estado

### 3. Escalabilidade de Transações
- Sharding por organization_id
- Partition keys estratégicas
- Connection pooling

### 4. Integridade Financeira
- Double-entry bookkeeping
- Auditoria imutável
- Reconciliação periódica

---

## Próximos Passos
1. Definir modelo de dados (schemas)
2. Arquitetura de serviços
3. Padrões de consistência distribuída
4. Strategy de event streaming (Kafka topics)
5. Estrutura de Rails
