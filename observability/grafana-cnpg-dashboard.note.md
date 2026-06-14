# Grafana dashboard for CloudNativePG

CNPG maintains an official Grafana dashboard. Import it rather than building
one from scratch.

## Option A — import from the CNPG repo (recommended, pinned)

The CNPG project ships the dashboard JSON in its monitoring repo:

- Repo: https://github.com/cloudnative-pg/grafana-dashboards
- File: `charts/cluster/grafana-dashboard.json` (or `dashboards/cluster.json` —
  the path moves between versions; check the repo for your operator version).

Import in Grafana:

1. Dashboards -> New -> Import.
2. Upload the JSON, or paste its contents.
3. Select your Prometheus data source.

## Option B — import by Grafana.com dashboard ID

The community-published CNPG dashboard is available on grafana.com:

- Dashboard ID: **20417** ("CloudNativePG"), or search grafana.com for
  "CloudNativePG".
- Grafana -> Import -> enter the ID -> Load -> pick the Prometheus data source.

> verify the dashboard ID/source against the current CNPG docs — community
> dashboard IDs occasionally change. The panels expect the CNPG metric names
> (cnpg_pg_replication_lag, cnpg_backends_total, cnpg_collector_*, etc.), so
> they only populate once the PodMonitor is being scraped (see README.md).

## What to watch first

- **Replication lag** per replica (ties to the `CNPGReplicationLagHigh` alert).
- **Backends / connections** vs `max_connections` (ties to
  `CNPGConnectionSaturation`).
- **WAL archiving** success/failure — a failing archiver silently breaks PITR.
- **Last successful backup** age — your real RPO indicator.
