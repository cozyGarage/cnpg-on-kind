# Secrets handling

**No plaintext application secrets live in this repo.** That's a deliberate,
non-negotiable rule for anything touching a payments/ledger database.

The one Secret you *will* see in git — `minio-creds` in `backup/minio.yaml` —
holds intentionally well-known, demo-only MinIO credentials (`minioadmin`).
It is not a real secret and exists only so the laptop demo is one command. Do
not copy that pattern for real buckets.

## Why no secrets in git

- Git history is forever: a leaked credential is leaked in every clone and fork.
- Repos get made public, forked, or backed up to places you don't control.
- Rotation is impossible if the secret's source of truth is a commit.

## The app database credentials are created imperatively

For the demo, create the `app` role's Secret directly in the cluster (it never
touches git):

```bash
kubectl -n cnpg-demo create secret generic cnpg-demo-app-user \
  --from-literal=username=app \
  --from-literal=password="$(openssl rand -base64 24)" \
  --type=kubernetes.io/basic-auth
```

Then point the Cluster at it by uncommenting `bootstrap.initdb.secret` in
`postgres/cluster.yaml`:

```yaml
bootstrap:
  initdb:
    database: app
    owner: app
    secret:
      name: cnpg-demo-app-user
```

(If you omit it, CNPG auto-generates a Secret for the owner role.)

## How you'd do it for real

Pick one and commit only *encrypted* or *referencing* manifests:

### Sealed Secrets (Bitnami)
Encrypt with the cluster's public key; the `SealedSecret` is safe to commit and
only the in-cluster controller can decrypt it.

```bash
kubectl create secret generic cnpg-demo-app-user \
  --from-literal=password="$(openssl rand -base64 24)" \
  --dry-run=client -o yaml \
| kubeseal --format yaml > sealed-secret.yaml   # safe to commit
```

### External Secrets Operator
Keep the real value in a managed store (AWS Secrets Manager, GCP Secret Manager,
Vault). Commit only an `ExternalSecret` that *references* the remote key; ESO
syncs it into a Kubernetes Secret. Best for rotation and audit.

### Plain `kubectl create secret`
Fine for a demo or break-glass; not auditable or reproducible, so not for
production GitOps.

> `.gitignore` blocks `*.pem`, `.env`, `*.key`, and `secret.yaml` /
> `*.local.yaml` so a stray real secret can't be committed by accident. Commit
> only `SealedSecret`/`ExternalSecret` manifests.
