#!/usr/bin/env bash
#
# backup-now.sh — trigger an on-demand CNPG base backup and wait for it.
#
# Run it:   ./scripts/backup-now.sh
# (chmod +x scripts/backup-now.sh  if it isn't executable yet)
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
CLUSTER="${CLUSTER:-cnpg-demo}"
BACKUP_NAME="${BACKUP_NAME:-ondemand-$(date +%Y%m%d-%H%M%S)}"

echo "[step] creating on-demand Backup '${BACKUP_NAME}' for cluster '${CLUSTER}' ..."

# Create a CNPG Backup CR. method: barmanObjectStore matches object-store.yaml.
# verify Backup fields against cloudnative-pg.io docs for your operator version.
kubectl apply -f - <<YAML
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: ${BACKUP_NAME}
  namespace: ${NAMESPACE}
spec:
  cluster:
    name: ${CLUSTER}
  method: barmanObjectStore
YAML

echo "[step] waiting for backup to complete (up to 5 min) ..."
DEADLINE=$(( $(date +%s) + 300 ))
PHASE=""
while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
  PHASE="$(kubectl -n "${NAMESPACE}" get backup "${BACKUP_NAME}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  echo "    phase=${PHASE:-pending}"
  case "${PHASE}" in
    completed) echo "[ok] backup completed: ${BACKUP_NAME}"; exit 0 ;;
    failed)    echo "[error] backup failed — inspect:" >&2
               echo "        kubectl -n ${NAMESPACE} describe backup ${BACKUP_NAME}" >&2
               exit 1 ;;
  esac
  sleep 10
done

echo "[warn] backup did not finish within the deadline; current phase: ${PHASE:-unknown}" >&2
echo "       kubectl -n ${NAMESPACE} get backup ${BACKUP_NAME} -o yaml" >&2
exit 1
