**Kafka Init & Entrypoint**

Objetivo: explicar como o init de tópicos Kafka funciona, onde está o entrypoint e os comandos úteis para desenvolvimento.

Resumo rápido

- `bin/docker-entrypoint`: script de entrada do container `rails` que aguarda o broker Kafka e executa `rake kafka:create_topics` com retries (best-effort).
-- `docker-compose.dev.yml`: cria um serviço `kafka` (imagem all-in-one ZK+Kafka para dev), define `KAFKA_BROKERS=kafka:9092` para o serviço `rails` e usa o `bin/docker-entrypoint` como entrypoint.
- `lib/tasks/kafka.rake`: tarefa `rake kafka:create_topics` que cria os tópicos necessários.

Como funciona

1. Ao iniciar o container `rails`, o `bin/docker-entrypoint` roda antes do `bin/rails`.
2. A criação de tópicos Kafka é realizada por um serviço init dedicado `kafka-init` no `docker-compose.dev.yml`.
3. O `kafka-init` espera o broker Kafka por até 120s; se o broker estiver disponível, ele executa `bundle exec rake kafka:create_topics` e falha se não conseguir alcançá-lo (útil para garantir tópicos em CI/dev ao iniciar).
4. O `bin/docker-entrypoint` foi mantido para tarefas de preflight (bundle install etc.), mas **não** cria mais tópicos automaticamente — isso evita condições de corrida entre serviços.

Arquivos principais

- `bin/docker-entrypoint` — entrypoint usado pelo serviço `rails`.
- `docker-compose.dev.yml` — compose dev com `zookeeper` e `kafka` e `KAFKA_BROKERS` para `rails`.
- `lib/tasks/kafka.rake` — tarefa que cria os tópicos: `donations.created`, `transactions.posted`, `wallets.balance_changed`, `credit.line_used`, `credit.repayment`, entre outros.
- `app/workers/credit_repayment_worker.rb` — worker que aplica doações pendentes às linhas de crédito (usa `CreditService`).

Variáveis de ambiente importantes

- `KAFKA_BROKERS`: lista CSV de brokers. Default no compose dev: `kafka:9092`.

Comandos úteis

Subir o ambiente de desenvolvimento (background):

```bash
docker compose -f docker-compose.dev.yml up -d
```

Ver logs do rails (procure mensagens de init Kafka):

```bash
docker compose -f docker-compose.dev.yml logs -f rails
```

Forçar criação de tópicos manualmente (quando o compose já estiver rodando):

```bash
docker compose -f docker-compose.dev.yml exec rails bundle exec rake kafka:create_topics
```

Testar o entrypoint manualmente dentro do container (sintaxe e execução breve):

```bash
docker compose -f docker-compose.dev.yml exec rails bash -lc 'bash -n /rails/bin/docker-entrypoint && /rails/bin/docker-entrypoint echo hi'
```

Rodar a suíte de testes (local):

```bash
docker compose -f docker-compose.dev.yml exec rails bundle exec rspec
```

Notas operacionais e recomendações

- O entrypoint é "best-effort" — ele não falhará o container caso Kafka esteja indisponível. Se desejar comportamento bloqueante (falhar se Kafka não estiver pronto), altere `bin/docker-entrypoint` para sair com erro quando não encontrar o broker.
- Para ambientes mais determinísticos (CI), prefira uma tarefa separada/Job de inicialização que seja executada após os serviços estarem prontos, ou um init-container que crie tópicos e falhe se não conseguir.
- Se o cluster Kafka exigir autenticação ou TLS, atualize `bin/docker-entrypoint` para checar conectividade adequada e a tarefa `lib/tasks/kafka.rake` para passar configurações necessárias ao `Kafka.new`.

Checklist rápido

- [x] `bin/docker-entrypoint` criado/atualizado
- [x] `docker-compose.dev.yml` configurado com serviço `kafka` (imagem dev com ZK+Kafka)
- [x] `lib/tasks/kafka.rake` disponível para criar tópicos
- [x] Worker `CreditRepaymentWorker` implementado e compatível com init

Próximos passos sugeridos

- Tornar criação de tópicos bloqueante no CI ou criar um init-container separado.
- Adicionar testes unitários para `CreditRepaymentWorker` (mocks para repositórios e `CreditService`).
