#!/usr/bin/env bash
set -euo pipefail

# Script para deploy no DOKS (DigitalOcean Kubernetes Service)
# Pré-requisitos: doctl, kubectl, helm configurados para o cluster DOKS

CLUSTER_NAME="cluster-bd2"
NAMESPACE="default"
IMAGE_NAME="clareo:latest"

echo "================================================"
echo "  Clareo - Deploy para DOKS (DigitalOcean K8s)"
echo "================================================"
echo ""

echo "1/10: Verificando cluster DOKS"
if ! doctl kubernetes cluster get ${CLUSTER_NAME} >/dev/null 2>&1; then
  echo "Cluster ${CLUSTER_NAME} não encontrado. Crie com:"
  echo "  doctl kubernetes cluster create ${CLUSTER_NAME} --region nyc3 --version 1.30 --node-pool 'name=worker;size=s-2vcpu-4gb;count=3'"
  exit 1
fi

echo "  Configurando kubectl para o cluster..."
doctl kubernetes cluster kubeconfig save ${CLUSTER_NAME}

echo "2/10: Verificando StorageClass do DigitalOcean"
kubectl get storageclass do-block-storage || {
  echo "StorageClass 'do-block-storage' não encontrada. Instalando CSI driver..."
  kubectl apply -f https://raw.githubusercontent.com/digitalocean/csi-driver/master/deploy/kubernetes/releases/csi-driver-v1.11.0.yaml
  sleep 10
}

echo "3/10: Adicionando repos Helm necessários"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "4/10: Instalando Cassandra via Bitnami Helm Chart"
helm upgrade --install meu-cassandra bitnami/cassandra \
  --namespace ${NAMESPACE} \
  --create-namespace \
  -f k8s/cassandra-bitnami-values.yaml \
  --wait --timeout 10m

echo "5/10: Instalando Redis (Bitnami)"
helm upgrade --install redis bitnami/redis \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set persistence.enabled=true \
  --set persistence.storageClass=do-block-storage \
  --set persistence.size=5Gi \
  --wait --timeout 5m

echo "6/10: Instalando Prometheus + Grafana (monitoring)"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait --timeout 5m

echo "7/10: Build da imagem Rails ${IMAGE_NAME}"
docker build -t ${IMAGE_NAME} .

echo "8/10: Push da imagem para registry (ajuste conforme seu registry)"
# Exemplo para Docker Hub:
# docker tag ${IMAGE_NAME} seu-usuario/${IMAGE_NAME}
# docker push seu-usuario/${IMAGE_NAME}
# Exemplo para DigitalOcean Container Registry:
# doctl registry login
# docker tag ${IMAGE_NAME} registry.digitalocean.com/seu-registry/${IMAGE_NAME}
# docker push registry.digitalocean.com/seu-registry/${IMAGE_NAME}
echo "  ATENÇÃO: Configure o push para seu container registry!"
echo "  Ex: docker tag ${IMAGE_NAME} registry.digitalocean.com/meu-registry/${IMAGE_NAME}"
echo "      docker push registry.digitalocean.com/meu-registry/${IMAGE_NAME}"

echo "9/10: Criando secrets necessários"
kubectl create secret generic cassandra-auth \
  --from-literal=password=senha_secreta_cassandra \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic rails-secret \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --dry-run=client -o yaml | kubectl apply -f -

echo "10/10: Aplicando manifests da aplicação Rails"
kubectl apply -f k8s/rails-deployment.yml
kubectl apply -f k8s/nginx-deployment.yml
kubectl apply -f k8s/cassandra-autoscaler.yaml

echo ""
echo "================================================"
echo "  Aguardando pods ficarem prontos..."
echo "================================================"
kubectl wait --for=condition=ready pod -l app=rails --timeout=180s 2>/dev/null || true

echo ""
echo "================================================"
echo "  Deploy concluído!"
echo "================================================"
kubectl get pods -o wide
echo ""
echo "Para acessar a aplicação:"
echo "  kubectl port-forward svc/rails 3000:3000"
echo "  http://localhost:3000"
echo ""
echo "Para acessar Grafana:"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  http://localhost:3000 (admin / ver senha com: kubectl get secret -n monitoring prometheus-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
echo ""
echo "Para ver logs do Cassandra:"
echo "  kubectl logs -l app.kubernetes.io/name=cassandra -c cassandra --tail=50"
echo ""
echo "Para escalar Cassandra (após verificar recursos):"
echo "  helm upgrade meu-cassandra bitnami/cassandra -f k8s/cassandra-bitnami-values.yaml --set numNodes=4"