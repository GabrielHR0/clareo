# Clareo

Stack: Rails 8 + Cassandra 4.1 + Redis + Nginx + Prometheus/Grafana
Autoscaling: Rails via HPA nativo + Cassandra via custom autoscaler

---

## Deploy no k3s

```bash
# Script completo (build + import + apply)
./scripts/deploy_k3s.sh

# Ou manualmente, passo a passo
kubectl apply -f k8s/cassandra-statefulset.yml
kubectl apply -f k8s/redis-deployment.yml
kubectl apply -f k8s/rails-deployment.yml
kubectl apply -f k8s/nginx-deployment.yml
kubectl apply -f k8s/cassandra-autoscaler.yaml
```

## Documentação completa

→ [INSTRUCTIONS.md](INSTRUCTIONS.md)

## Desenvolvimento local (sem k3s)

```bash
docker compose up -d
```

## Arquitetura

| Serviço | Tipo | Réplicas base | Autoscaling |
|---------|------|---------------|-------------|
| Rails | Deployment | 3 | HPA (CPU > 50%, 1..10) |
| Cassandra | StatefulSet | 2 | Custom (CPU > 60%, 2..5) |
| Redis | Deployment | 1 | - |
| Nginx | Deployment (LoadBalancer) | 1 | - |

## Pré-requisitos

- k3s (`curl -sfL https://get.k3s.io | sh -`)
- Docker
- Git
