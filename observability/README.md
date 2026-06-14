# Observability: Prometheus + Grafana for CNPG

`make observe` installs the kube-prometheus-stack Helm chart (Prometheus +
Grafana + the Prometheus Operator) and applies the CNPG alert rules.

## Install (minimal)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --version 65.1.1 \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

> Pin the chart version (`--version`). verify the latest on
> https://github.com/prometheus-community/helm-charts.

## How PodMonitor discovery works (the gotcha)

CNPG (via `monitoring.enablePodMonitor: true`) creates a `PodMonitor` in your
database namespace. But Prometheus only scrapes monitors it is *configured to
select*. The Prometheus Operator deployed by kube-prometheus-stack defaults to
selecting only monitors that carry the chart's **release label**, e.g.:

```yaml
metadata:
  labels:
    release: kube-prometheus-stack
```

Two ways to make discovery work:

1. **Loosen the selector (used above):** set
   `prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false` so
   Prometheus selects PodMonitors in all namespaces regardless of label. Easiest
   for a demo.
2. **Label the PodMonitor:** add `release: kube-prometheus-stack` to the
   PodMonitor the operator generates (via the Cluster's
   `monitoring.podMonitorMetricRelabelings`/labels, or a kustomize patch). More
   surgical; preferred in shared clusters.

Confirm scraping:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# open http://localhost:9090/targets and look for the cnpg-demo PodMonitor
```

## Access Grafana

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  (admin / admin — change it)
```

Then import the CNPG dashboard — see `grafana-cnpg-dashboard.note.md`.
