#!/usr/bin/env bash
#
# failover-demo.sh — the money shot.
# Find the current primary, delete its pod, and watch the CNPG operator promote
# the replica and bring the cluster back to a healthy state.
#
# Run it:   ./scripts/failover-demo.sh
# (chmod +x scripts/failover-demo.sh  if it isn't executable yet)
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
CLUSTER="${CLUSTER:-cnpg-demo}"

echo "[step] reading current primary of cluster '${CLUSTER}' ..."
OLD_PRIMARY="$(kubectl -n "${NAMESPACE}" get cluster "${CLUSTER}" \
  -o jsonpath='{.status.currentPrimary}')"

if [ -z "${OLD_PRIMARY}" ]; then
  echo "[error] could not determine current primary — is the cluster ready?" >&2
  exit 1
fi
echo "[info] current primary: ${OLD_PRIMARY}"

echo "[step] deleting primary pod '${OLD_PRIMARY}' to simulate a node/pod failure ..."
kubectl -n "${NAMESPACE}" delete pod "${OLD_PRIMARY}" --wait=false

echo "[step] watching for promotion (Ctrl-C to stop watching) ..."
echo "       expect STATUS to move through 'Failing over' back to healthy,"
echo "       and PRIMARY to change to the former replica."

# Poll the cluster until the primary changes and the cluster is healthy again.
DEADLINE=$(( $(date +%s) + 180 ))
NEW_PRIMARY="${OLD_PRIMARY}"
while [ "$(date +%s)" -lt "${DEADLINE}" ]; do
  NEW_PRIMARY="$(kubectl -n "${NAMESPACE}" get cluster "${CLUSTER}" \
    -o jsonpath='{.status.currentPrimary}' 2>/dev/null || true)"
  READY="$(kubectl -n "${NAMESPACE}" get cluster "${CLUSTER}" \
    -o jsonpath='{.status.readyInstances}' 2>/dev/null || true)"
  echo "    primary=${NEW_PRIMARY:-?}  readyInstances=${READY:-?}"
  if [ -n "${NEW_PRIMARY}" ] && [ "${NEW_PRIMARY}" != "${OLD_PRIMARY}" ] \
     && [ "${READY:-0}" = "2" ]; then
    break
  fi
  sleep 5
done

echo
kubectl -n "${NAMESPACE}" get cluster "${CLUSTER}"
echo

if [ -n "${NEW_PRIMARY}" ] && [ "${NEW_PRIMARY}" != "${OLD_PRIMARY}" ]; then
  echo "[ok] failover complete. new primary: ${NEW_PRIMARY} (was ${OLD_PRIMARY})"
else
  echo "[warn] primary did not change within the deadline — inspect with:" >&2
  echo "       kubectl -n ${NAMESPACE} describe cluster ${CLUSTER}" >&2
  exit 1
fi

echo
echo "[hint] watch the old primary rejoin as a replica and lag recover:"
echo "       kubectl -n ${NAMESPACE} get pods -w"
echo "       (or watch the cnpg_pg_replication_lag metric in Grafana)"
