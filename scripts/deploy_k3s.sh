#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="clareo:latest"
NAMESPACE="default"

echo "================================================"
echo "  Clareo - Deploy completo para k3s"
echo "================================================"
echo ""

echo "1/8: Verificando k3s"
if ! command -v k3s >/dev/null 2>&1; then
  echo "k3s não encontrado. Instale com:"
  echo "  curl -sfL https://get.k3s.io | sh -"
  exit 1
fi

echo "2/8: Garantindo que CoreDNS, metrics-server e local-path-provisioner estão rodando"
kubectl scale deployment coredns -n kube-system --replicas=1 2>/dev/null || true
kubectl scale deployment metrics-server -n kube-system --replicas=1 2>/dev/null || true
kubectl scale deployment local-path-provisioner -n kube-system --replicas=1 2>/dev/null || true

echo "3/8: Build da imagem Rails ${IMAGE_NAME}"
docker build -t ${IMAGE_NAME} .

echo "4/8: Importando imagem no containerd do k3s"
TMP_TAR=/tmp/clareo_image.tar
docker save -o ${TMP_TAR} ${IMAGE_NAME}
sudo k3s ctr images import ${TMP_TAR}
rm -f ${TMP_TAR}

echo "5/8: Criando secrets necessários"
# Secret para autenticação Cassandra (Bitnami Helm usa admin/senha_secreta_cassandra)
kubectl create secret generic cassandra-auth \
  --from-literal=password=senha_secreta_cassandra \
  --dry-run=client -o yaml | kubectl apply -f -

echo "6/8: Criando SECRET_KEY_BASE para Rails"
kubectl create secret generic rails-secret \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --dry-run=client -o yaml | kubectl apply -f -

echo "7/8: Aplicando manifests Kubernetes"
kubectl apply -f k8s/redis-deployment.yml
kubectl apply -f k8s/rails-deployment.yml
kubectl apply -f k8s/nginx-deployment.yml
kubectl apply -f k8s/cassandra-autoscaler.yaml

echo "8/8: Aguardando pods ficarem prontos"
echo "  Cassandra (via Bitnami Helm) pode levar até 2 minutos..."
kubectl wait --for=condition=ready pod -l app=rails --timeout=120s 2>/dev/null || true

echo "9/9: Deploy concluído!"
echo ""
echo "================================================"
echo "  Status do cluster"
echo "================================================"
kubectl get pods -o wide
echo ""
echo "HPA (Rails):"
kubectl get hpa rails-hpa -o wide
echo ""
echo "Autoscaler (Cassandra):"
kubectl logs -l app=cassandra-autoscaler --tail=3 2>/dev/null || echo "  aguardando..."
echo ""
echo "================================================"
echo "  Acessar a aplicação:"
echo "    kubectl port-forward svc/rails 3000:3000"
echo "    http://localhost:3000"
echo ""
echo "  Acessar Grafana:"
echo "    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "    http://localhost:3000  (admin/admin)"
echo ""
echo "  Monitorar autoscaling:"
echo "    kubectl get hpa rails-hpa -w"
echo "    kubectl logs -l app=cassandra-autoscaler --tail=5"
echo ""
echo "  Gerar carga de teste:"
echo "    kubectl exec cassandra-0 -- sh -c 'for i in \$(seq 1 5); do dd if=/dev/zero of=/tmp/s\$i bs=1M count=200 & done; wait'"
echo "================================================"
