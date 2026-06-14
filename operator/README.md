# Installing the CloudNativePG operator

The `Makefile` does this for you (`make operator`), but here's what it runs and why.

## Install the pinned operator release

CNPG ships a single self-contained install manifest per release. Install it with
**server-side apply** — the manifest contains large CRDs that can exceed the
client-side apply annotation size limit.

```bash
# Pin a real, recent release. Browse: https://github.com/cloudnative-pg/cloudnative-pg/releases
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.1.yaml
```

> verify against cloudnative-pg.io docs for your installed operator version — the
> exact manifest URL and version are pinned in the `Makefile` (`CNPG_VERSION`,
> `CNPG_MANIFEST`). CNPG releases move quickly; check the releases page and bump both.

This installs the operator into the `cnpg-system` namespace along with the
`Cluster`, `Pooler`, `Backup`, `ScheduledBackup`, and related CRDs.

## Wait for it to be ready

```bash
kubectl -n cnpg-system rollout status deployment/cnpg-controller-manager --timeout=180s
```

## Metrics enablement

CNPG exposes Prometheus metrics **per instance** on each Postgres pod (port
`9187`, path `/metrics`). You turn scraping on at the `Cluster` level:

```yaml
spec:
  monitoring:
    enablePodMonitor: true   # operator creates a PodMonitor for the cluster
```

That is already set in `postgres/cluster.yaml`. For Prometheus to *discover* the
generated `PodMonitor`, your Prometheus instance must select it — see
`observability/README.md` for the release-label detail.

The metrics you'll alert on (`cnpg_pg_replication_lag`, `cnpg_backends_total`)
come from these per-instance exporters. You can also add custom queries via a
`monitoring.customQueriesConfigMap` if you need app-specific metrics.
