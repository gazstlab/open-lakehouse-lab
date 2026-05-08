# MinIO object storage

This runbook describes the Stage 03 MinIO deployment for the local lakehouse.

## Prerequisites

- Stage 02 local kind cluster created with `make cluster-create`.
- `kubectl` configured for the `kind-open-lakehouse-lab` context.

## Deploy MinIO

From the repository root:

```bash
make deploy-minio
```

The command deploys MinIO in the `data-platform` namespace and runs a bootstrap
job that creates the `lakehouse` bucket.

## Check status

```bash
make minio-status
kubectl -n data-platform logs job/minio-create-bucket
```

## Access MinIO locally

Start a local port-forward:

```bash
make port-forward-minio
```

Local endpoints:

- S3 API: `http://localhost:9000`
- Console: `http://localhost:9001`

Local lab credentials:

- User: `minioadmin`
- Password: `minioadmin123`

These credentials are only for local development inside this educational lab.
Do not reuse them outside the local kind cluster.

## Lakehouse paths

The `lakehouse` bucket is initialized with these base prefixes:

```text
s3://lakehouse/raw/
s3://lakehouse/warehouse/
s3://lakehouse/metadata/
```

Path responsibilities:

- `raw/`: original public API payloads.
- `warehouse/`: future Iceberg table warehouse data.
- `metadata/`: pipeline, catalog, freshness and quality artifacts.

## Delete MinIO

```bash
make delete-minio
```

To remove the whole local cluster:

```bash
make cluster-delete
```

## Scope

Stage 03 only deploys local object storage and initializes the base bucket.
Polaris, Iceberg tables, dbt integration and Airflow workloads are introduced in
later stages.
