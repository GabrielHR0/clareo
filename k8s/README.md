# k8s/ — Manifests Kubernetes

Manifests prontos para deploy no k3s.

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `cassandra-statefulset.yml` | StatefulSet (2 pods) + Headless Service + PodDisruptionBudget |
| `rails-deployment.yml` | Deployment (3 pods) + Service + HPA (CPU 50%, 1..10) |
| `redis-deployment.yml` | Redis Deployment + Service |
| `nginx-deployment.yml` | Nginx Deployment (1 pod) + Service LoadBalancer + ConfigMap |
| `cassandra-autoscaler.yaml` | Custom autoscaler para Cassandra (RBAC + Deployment) |

## Ordem de apply

```bash
kubectl apply -f k8s/cassandra-statefulset.yml
kubectl apply -f k8s/redis-deployment.yml
kubectl apply -f k8s/rails-deployment.yml
kubectl apply -f k8s/nginx-deployment.yml
kubectl apply -f k8s/cassandra-autoscaler.yaml
kubectl create secret generic rails-secret \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64)
```

## Pré-requisitos no cluster

- metrics-server instalado (k3s inclui, escalar se 0/0)
- CoreDNS rodando
- local-path-provisioner rodando (para PVCs)
- Imagem clareo:latest importada no containerd do k3s

## Autoscaling

### Rails (HPA nativo)

Escala entre 1 e 10 pods baseado em CPU média > 50% do `requests.cpu`.

### Cassandra (custom)

Deployment `cassandra-autoscaler` que executa script:
- Consulta `kubectl top pod` a cada 30s
- Escala StatefulSet entre 2 e 5 pods
- Scale-up se CPU média > 60% do request
- Scale-down se CPU média < 30%
