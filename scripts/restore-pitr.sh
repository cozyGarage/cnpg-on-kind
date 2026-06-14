#!/usr/bin/env bash
#
# restore-pitr.sh — restore to a NEW cluster from the object-store backup.
# This never touches the live cluster: it bootstraps cnpg-demo-restore from MinIO.
#
# Run it:   ./scripts/restore-pitr.sh
# (chmod +x scripts/restore-pitr.sh  if it isn't executable yet)
#
# To recover to a specific point in time, edit restore/recovery-cluster.yaml and
# uncomment/set spec.bootstrap.recovery.recoveryTarget.targetTime first.
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
RESTORE_CLUSTER="${RESTORE_CLUSTER:-cnpg-demo-restore}"
MANIFEST="${MANIFEST:-restore/recovery-cluster.yaml}"

# Resolve the manifest relative to the repo root so the script works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_PATH="${REPO_ROOT}/${MANIFEST}"

if [ ! -f "${MANIFEST_PATH}" ]; then
  echo "[error] manifest not found: ${MANIFEST_PATH}" >&2
  exit 1
fi

echo "[step] creating recovery cluster '${RESTORE_CLUSTER}' from object store ..."
echo "[info] using manifest: ${MANIFEST_PATH}"
kubectl apply -f "${MANIFEST_PATH}"

echo "[step] waiting for the recovery cluster to become ready (up to 6 min) ..."
echo "       CNPG fetches the base backup + replays WAL — this takes a while."
DEADLINE=$(( $(date +%s) + 360 ))
while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
  READY="$(kubectl -n "${NAMESPACE}" get cluster "${RESTORE_CLUSTER}" \
    -o jsonpath='{.status.readyInstances}' 2>/dev/null || true)"
  PHASE="$(kubectl -n "${NAMESPACE}" get cluster "${RESTORE_CLUSTER}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  echo "    phase='${PHASE:-?}'  readyInstances=${READY:-0}"
  if [ "${READY:-0}" -ge 1 ] 2>/dev/null; then
    echo "[ok] recovery cluster '${RESTORE_CLUSTER}' is ready."
    break
  fi
  sleep 10
done

echo
kubectl -n "${NAMESPACE}" get cluster "${RESTORE_CLUSTER}" || true
echo
echo "[hint] verify the restored data, e.g.:"
echo "       kubectl -n ${NAMESPACE} exec -it ${RESTORE_CLUSTER}-1 -- psql -d app -c '\\dt'"
echo "[hint] when done, drop the recovery cluster:"
echo "       kubectl -n ${NAMESPACE} delete cluster ${RESTORE_CLUSTER}"
