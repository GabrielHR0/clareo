++
K8ssandra + Prometheus/Grafana (manifests & helper)

This folder contains a sample CassandraDatacenter CR (for k8ssandra/cass-operator) and example values.

Goal: allow you to install K8ssandra (operator + Cassandra datacenter) and kube-prometheus-stack (Prometheus + Grafana) on k3s and demonstrate a scale-out by editing the CassandraDatacenter CR (size: 3 -> 4).

High level steps (after running the helper script):

1. Install prometheus/grafana: helm chart `kube-prometheus-stack`.
2. Install k8ssandra (helm) which brings cass-operator and related components.
3. Apply the CassandraDatacenter CR in this folder: `kubectl apply -f cassandradc.yaml`.
4. Scale by patching: `kubectl -n k8ssandra patch cassandradatacenters.datastax.com dc1 --type merge -p '{"spec":{"size":4}}'`.
5. Monitor the pods and streaming via `kubectl get pods -n k8ssandra -w` and `kubectl exec -n k8ssandra -it dc1-sts-0 -- nodetool status` (pod name pattern depends on operator installation).

Important notes:
- The scripts provided here (../scripts/install_k8ssandra.sh) assume you have `helm`, `kubectl` and k3s running on the same host. If you run a remote cluster, push images to a registry or run the equivalent commands against the remote cluster.
- StorageClass: the sample CR uses `local-path` as storageClassName which k3s provides by default. For production use a proper distributed storage class.
- Test this flow before the presentation.
