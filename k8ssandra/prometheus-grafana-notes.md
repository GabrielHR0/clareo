++
Prometheus & Grafana notes

- kube-prometheus-stack is installed by scripts/install_k8ssandra.sh into namespace `monitoring`.
- Grafana default credentials: admin/prom-operator (change on first login).
- To access Grafana locally (port-forward):
  - kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
  - kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

- Recommended dashboards to import for Cassandra:
  - K8ssandra / cass-operator exposes metrics via JMX exporter. Look for dashboards: "Cassandra Overview", "Cassandra Node", "Cassandra JVM".
