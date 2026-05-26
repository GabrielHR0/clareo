#!/usr/bin/env bash
set -euo pipefail

# Helper to install kube-prometheus-stack and k8ssandra via Helm into k3s.
# This script only adds manifests/Helm installs; it DOES NOT alter application manifests.

NAMESPACE_PROM="monitoring"
NAMESPACE_K8S="k8ssandra"

echo "1/6: Add Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add k8ssandra https://helm.k8ssandra.io
helm repo update

echo "2/6: Install kube-prometheus-stack (Prometheus + Grafana)"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace ${NAMESPACE_PROM} --create-namespace --wait

echo "3/6: Install k8ssandra (operator)"
helm upgrade --install k8ssandra k8ssandra/k8ssandra --namespace ${NAMESPACE_K8S} --create-namespace --wait

echo "4/6: Apply CassandraDatacenter CR (dc1)"
kubectl apply -f k8ssandra/cassandradc.yaml -n ${NAMESPACE_K8S} || true

echo "5/6: Wait for pods (this may take several minutes)"
kubectl get pods -n ${NAMESPACE_K8S} -w --timeout=600s || true

echo "6/6: Done. Prometheus/Grafana installed in namespace ${NAMESPACE_PROM}. Cassandra DC applied in ${NAMESPACE_K8S}."

echo "To scale CassandraDatacenter: kubectl -n ${NAMESPACE_K8S} patch cassandradatacenters.cassandra.datastax.com dc1 --type merge -p '{\"spec\":{\"size\":4}}'"
