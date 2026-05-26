# Clareo — Deploy Kubernetes (k3s)

Stack: Rails 8 + Cassandra 4.1 + Redis + Nginx + Prometheus/Grafana
Autoscaling: Rails via HPA nativo + Cassandra via custom autoscaler

## Pré-requisitos

- Linux (testado em Arch Linux)
- Docker
- curl (para instalar k3s)
- Pelo menos 4 GB de RAM livre na máquina

## 1. Instalar k3s

```bash
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
```

Verificar instalação:
```bash
kubectl get nodes
kubectl get pods -n kube-system
```

Se CoreDNS ou metrics-server não estiverem rodando (0/0), escalar manualmente:
```bash
kubectl scale deployment coredns -n kube-system --replicas=1
kubectl scale deployment metrics-server -n kube-system --replicas=1
kubectl scale deployment local-path-provisioner -n kube-system --replicas=1
```

## 2. Build e import da imagem Rails

```bash
docker build -t clareo:latest .
docker save clareo:latest | sudo k3s ctr images import -
```

Para outras máquinas publicar em registry:
```bash
docker tag clareo:latest seuuser/clareo:latest
docker push seuuser/clareo:latest
# Editar k8s/rails-deployment.yml: image: seuuser/clareo:latest
```

## 3. Deploy dos manifests

> **Ordem importa:** Cassandra primeiro (StatefulSet demora), depois os demais.

```bash
kubectl apply -f k8s/cassandra-statefulset.yml   # StatefulSet + Service + PDB
kubectl apply -f k8s/redis-deployment.yml         # Redis
kubectl apply -f k8s/rails-deployment.yml         # Rails (Deployment + Service + HPA)
kubectl apply -f k8s/nginx-deployment.yml         # Nginx (opcional)
kubectl apply -f k8s/cassandra-autoscaler.yaml    # Custom autoscaler do Cassandra

# SECRET_KEY_BASE (obrigatório para Rails em produção)
kubectl create secret generic rails-secret \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64)
```

## 4. Verificar deploy

```bash
kubectl get pods -o wide
kubectl get hpa rails-hpa
kubectl top pods
```

Saída esperada:
```
NAME                    READY   STATUS    RESTARTS   AGE
cassandra-0             1/1     Running   0          1m
cassandra-1             1/1     Running   0          1m
rails-xxx-xxx           1/1     Running   0          1m
rails-xxx-xxx           1/1     Running   0          1m
rails-xxx-xxx           1/1     Running   0          1m
redis-xxx-xxx           1/1     Running   0          1m
nginx-lb-xxx-xxx        1/1     Running   0          1m
cassandra-autoscaler-xxx 1/1    Running   0          1m
```

## 5. Acessar aplicação

```bash
# Rails direto
kubectl port-forward svc/rails 3000:3000
# Abrir http://localhost:3000

# Via Nginx (porta 80)
kubectl port-forward svc/nginx-lb 8080:80
# Abrir http://localhost:8080
```

## 6. Prometheus e Grafana

```bash
# Instalar (uma vez)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace --wait

# Acessar
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Credenciais Grafana: admin / admin (alterar no primeiro login)
```

## 7. Arquitetura

```
                    ┌──────────┐
                    │  Nginx   │  (LoadBalancer :80)
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │  Rails   │  (Deployment, 3 pods, HPA)
                    │  :3000   │
                    └┬───┬────┘
                     │   │
              ┌──────┘   └────────┐
              │                    │
         ┌────▼─────┐       ┌─────▼──────┐
         │ Redis    │       │  Cassandra  │
         │ :6379    │       │  :9042      │
         └──────────┘       │  StatefulSet│
                            │  2 pods     │
                            └──────┬──────┘
                                   │
                           ┌───────▼────────┐
                           │ Custom         │
                           │ Autoscaler     │
                           │ (scale: 2..5)  │
                           └────────────────┘
```

## 8. Autoscaling

### Rails — HPA (HorizontalPodAutoscaler)

Recurso nativo do Kubernetes no arquivo `k8s/rails-deployment.yml`.

- **Métrica:** CPU média dos pods
- **Threshold:** 50% da `requests.cpu` (200m = 200 millicores)
- **Faixa:** 1 a 10 réplicas
- **Funcionamento:** O metrics-server coleta uso de CPU a cada 15s. O HPA calcula a média e altera `spec.replicas` do Deployment.

Monitorar:
```bash
kubectl get hpa rails-hpa -w
```

Testar com carga:
```bash
kubectl run loader --image=williamyeh/hey --restart=Never -it --rm -- \
  -n 10000 -c 50 http://rails:3000/
```

### Cassandra — Autoscaler customizado

Arquivo: `k8s/cassandra-autoscaler.yaml`

- **Por que custom?** Cassandra é StatefulSet, o HPA nativo não se aplica.
- **Como funciona:** Um Deployment com ServiceAccount e permissões RBAC roda um script que:
  1. A cada 30s consulta `kubectl top pod` (metrics-server)
  2. Soma CPU de todos os pods Cassandra
  3. Divide pela soma dos `requests.cpu`
  4. Se > 60% → escala +1 (até 5)
  5. Se < 30% por ciclo → escala -1 (mínimo 2)

Parâmetros ajustáveis no script (`command` do Deployment):
```bash
MIN_REPLICAS=2
MAX_REPLICAS=5
SCALE_UP_THRESHOLD=60
SCALE_DOWN_THRESHOLD=30
CHECK_INTERVAL=30
```

Monitorar:
```bash
kubectl logs -l app=cassandra-autoscaler --tail=5
```

Testar com carga (gera CPU via I/O de disco):
```bash
kubectl exec cassandra-0 -- sh -c \
  'for i in $(seq 1 5); do dd if=/dev/zero of=/tmp/s$i bs=1M count=200 & done; wait'
```

## 9. Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| Pods CrashLoopBackOff | CoreDNS não rodando | `kubectl scale deployment coredns -n kube-system --replicas=1` |
| HPA mostra `<unknown>` | metrics-server com 0 pods | `kubectl scale deployment metrics-server -n kube-system --replicas=1` |
| ImagePullBackOff | Imagem não importada no containerd | `docker save clareo:latest \| sudo k3s ctr images import -` |
| Cassandra OOMKilled | Pouca memória no node | Reduzir `resources.limits.memory` no StatefulSet |
| Cassandra "seed provider lists no seeds" | DNS não funciona | Verificar CoreDNS, aguardar pods Ready |
| Cassandra-1 não sobe | PVC corrompido ou conflito | `kubectl delete pvc cassandra-data-cassandra-1` (limpa dados) |

## 10. Comandos úteis

```bash
# Logs
kubectl logs -l app=rails -c rails --tail=100
kubectl logs -l app=cassandra --tail=20

# Shell dentro do pod
kubectl exec -it cassandra-0 -- sh
kubectl exec -it $(kubectl get pod -l app=rails -o jsonpath='{.items[0].metadata.name}') -- sh

# Cassandra nodetool
kubectl exec cassandra-0 -- nodetool status

# Escalar manualmente
kubectl scale statefulset cassandra --replicas=3
kubectl scale deployment rails --replicas=5

# Port-forward múltiplo
kubectl port-forward svc/rails 3000:3000 &  # Rails
kubectl port-forward svc/nginx-lb 8080:80 &  # Nginx
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &  # Grafana
```

## 11. Reset completo

Se quiser limpar tudo e recomeçar:

```bash
kubectl delete -f k8s/cassandra-statefulset.yml
kubectl delete -f k8s/rails-deployment.yml
kubectl delete -f k8s/redis-deployment.yml
kubectl delete -f k8s/nginx-deployment.yml
kubectl delete -f k8s/cassandra-autoscaler.yaml
kubectl delete secret rails-secret
kubectl delete pvc -l app=cassandra  # Remove dados persistentes
```

## Arquivos do repositório

```
k8s/
├── cassandra-statefulset.yml    # Cassandra StatefulSet + Service + PDB
├── rails-deployment.yml         # Rails Deployment + Service + HPA
├── redis-deployment.yml         # Redis Deployment + Service
├── nginx-deployment.yml         # Nginx Deployment + Service + ConfigMap
└── cassandra-autoscaler.yaml    # Custom autoscaler (RBAC + Deployment)

scripts/
├── deploy_k3s.sh               # Script auxiliar de deploy
└── install_k8ssandra.sh         # Instalação k8ssandra (referência)

k8ssandra/                       # Experimentos com K8ssandra operator
├── cassandradc.yaml
├── README.md
└── prometheus-grafana-notes.md

docs/
└── 07_SETUP_CASSANDRA_DISTRIBUIDO.md

docker-compose.yml               # Versão local para desenvolvimento
docker-compose.cluster.yml       # Versão multi-serviço
```

Para desenvolvimento local (sem k3s):
```bash
docker compose up -d
```
