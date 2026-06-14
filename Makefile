# cnpg-on-kind — Makefile
# Production-shaped PostgreSQL on Kubernetes via the CloudNativePG operator, on kind.
#
# Pinned versions live here so the whole demo is reproducible.
# verify against cloudnative-pg.io docs for your installed operator version.

# ---- Pinned versions -------------------------------------------------------
CLUSTER_NAME      ?= cnpg-on-kind
NAMESPACE         ?= cnpg-demo
MON_NAMESPACE     ?= monitoring

# CNPG operator release manifest (pin a real, recent release tag).
# Browse releases: https://github.com/cloudnative-pg/cloudnative-pg/releases
CNPG_VERSION      ?= 1.24.1
CNPG_MANIFEST     ?= https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.1.yaml

# kube-prometheus-stack chart (Prometheus + Grafana)
KPS_CHART_VERSION ?= 65.1.1

# ---- Meta ------------------------------------------------------------------
.DEFAULT_GOAL := help
.PHONY: help up down cluster operator db backup restore failover observe clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up: cluster operator db backup ## Bring up the full stack (cluster -> operator -> db -> backup)
	@echo "[ok] stack is up. Run 'make observe' to add Prometheus/Grafana."

down: clean ## Alias for clean (tear everything down)

# ---- Phases ----------------------------------------------------------------
cluster: ## Create the kind cluster
	@echo "[step] creating kind cluster '$(CLUSTER_NAME)' ..."
	kind create cluster --name $(CLUSTER_NAME) --config kind/kind-cluster.yaml
	@echo "[ok] cluster ready"

operator: ## Install the CloudNativePG operator (pinned release)
	@echo "[step] installing CNPG operator $(CNPG_VERSION) ..."
	kubectl apply --server-side -f $(CNPG_MANIFEST)
	@echo "[step] waiting for operator to be ready ..."
	kubectl -n cnpg-system rollout status deployment/cnpg-controller-manager --timeout=180s
	@echo "[ok] operator ready"

db: ## Apply namespace + Cluster + pooler
	@echo "[step] applying namespace, Cluster, and pooler ..."
	kubectl apply -f postgres/namespace.yaml
	kubectl apply -f postgres/cluster.yaml
	kubectl apply -f postgres/pooler.yaml
	@echo "[step] waiting for the cluster to be ready (this can take a few minutes) ..."
	kubectl -n $(NAMESPACE) wait --for=condition=Ready cluster/cnpg-demo --timeout=300s || true
	@echo "[ok] database applied"

backup: ## Deploy MinIO + apply backup config + scheduled backup
	@echo "[step] deploying MinIO ..."
	kubectl apply -f backup/minio.yaml
	kubectl -n $(NAMESPACE) rollout status deployment/minio --timeout=180s || true
	@echo "[step] applying backup object-store config + scheduled backup ..."
	kubectl apply -f backup/object-store.yaml
	kubectl apply -f backup/scheduled-backup.yaml
	@echo "[ok] backup configured"

restore: ## Restore to a NEW cluster via PITR (see restore/recovery-cluster.yaml)
	@echo "[step] creating recovery cluster from object store ..."
	kubectl apply -f restore/recovery-cluster.yaml
	@echo "[ok] recovery cluster applied — watch with: kubectl -n $(NAMESPACE) get cluster"

failover: ## Run the scripted failover demo
	./scripts/failover-demo.sh

observe: ## Install kube-prometheus-stack + CNPG alerts
	@echo "[step] installing kube-prometheus-stack $(KPS_CHART_VERSION) ..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--version $(KPS_CHART_VERSION) \
		--namespace $(MON_NAMESPACE) --create-namespace \
		--set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
		--set grafana.adminPassword=admin
	@echo "[step] applying CNPG PrometheusRule alerts ..."
	kubectl apply -f observability/prometheusrule.yaml
	@echo "[ok] observability installed. Grafana login: admin / admin (change it!)"

clean: ## Delete the kind cluster and all local state
	@echo "[step] deleting kind cluster '$(CLUSTER_NAME)' ..."
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "[ok] torn down"
