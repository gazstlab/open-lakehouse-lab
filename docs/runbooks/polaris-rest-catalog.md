# Apache Polaris REST Catalog

This runbook describes the Stage 04 Apache Polaris deployment for the local Open Lakehouse Lab environment.

## Scope

Stage 04 deploys Apache Polaris as the local Iceberg REST Catalog and configures a `lakehouse` catalog backed by the MinIO warehouse path:

```text
s3://lakehouse/warehouse
```

The first implementation uses Polaris in-memory persistence because this stage is focused on local catalog availability and integration with MinIO. A durable metadata backend, such as Postgres, can be introduced in a later stage if needed.

## Prerequisites

- Stage 02 local kind cluster created with `make cluster-create`.
- Stage 03 MinIO deployed with `make deploy-minio`.
- The `lakehouse` bucket exists in MinIO.
- `kubectl` is configured for the `kind-open-lakehouse-lab` context.

## Local credentials

Do not commit real credentials.

The deployment command creates the Kubernetes secret dynamically from environment variables:

```bash
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"
```

These values are only examples for the local educational lab. Use different values if the local MinIO deployment was customized.

A template is available at:

```text
k8s/polaris/secret.example.yaml
```

## Deploy Polaris

From the repository root:

```bash
make deploy-polaris
```

The command:

1. Creates the `polaris-local-credentials` secret from environment variables.
2. Deploys the Polaris pod.
3. Exposes the catalog and management APIs through a ClusterIP service.
4. Waits for the deployment rollout.
5. Runs the bootstrap job that creates the `lakehouse` catalog.

## Check status

```bash
make polaris-status
make polaris-health
kubectl -n data-platform logs job/polaris-bootstrap-catalog
```

Expected internal endpoints:

```text
Catalog API:    http://polaris.data-platform.svc.cluster.local:8181/api/catalog
Management API: http://polaris.data-platform.svc.cluster.local:8181
Health check:   http://polaris.data-platform.svc.cluster.local:8182/q/health/ready
```

## Access Polaris locally

Start a local port-forward:

```bash
make port-forward-polaris
```

Local endpoints:

```text
Catalog API:    http://localhost:8181/api/catalog
Management API: http://localhost:8181
Health check:   http://localhost:8182/q/health/ready
```

## Catalog configuration

The bootstrap job creates the catalog:

```text
lakehouse
```

Warehouse location:

```text
s3://lakehouse/warehouse
```

MinIO endpoint inside the cluster:

```text
http://minio.data-platform.svc.cluster.local:9000
```

The future dbt + DuckDB stage should use the internal catalog endpoint when running inside Kubernetes:

```text
http://polaris.data-platform.svc.cluster.local:8181/api/catalog
```

When running from the host machine through port-forward, use:

```text
http://localhost:8181/api/catalog
```

## Delete Polaris

```bash
make delete-polaris
```

This removes:

- bootstrap job;
- service;
- deployment;
- local credentials secret.

It does not delete MinIO or the `lakehouse` bucket.

## Validation checklist

- [ ] `make deploy-polaris` completes successfully.
- [ ] `make polaris-status` shows the Polaris pod and service.
- [ ] `make polaris-health` returns a healthy response.
- [ ] `kubectl -n data-platform logs job/polaris-bootstrap-catalog` confirms catalog bootstrap.
- [ ] `make port-forward-polaris` exposes ports `8181` and `8182` locally.

## Known limitations

- The MVP uses in-memory Polaris persistence.
- The local bootstrap job is intentionally simple and optimized for education, not production.
- Durable catalog metadata storage is intentionally deferred to a future stage.
- This stage does not create Iceberg tables; that is handled by later dbt + DuckDB stages.
