# dbt MinIO Polaris backbone

This runbook describes the Stage 13 backbone:

```text
MinIO Raw Parquet
  -> dbt + DuckDB processing
  -> Silver and Gold Iceberg tables
  -> Polaris REST Catalog
  -> Airflow KubernetesPodOperator dbt pods
```

DuckDB is the SQL engine. It is not the final storage layer. Persistent data
lives in MinIO, and Iceberg table registration lives in Polaris.

## What changed

Stage 13 makes the default path use MinIO and Polaris:

- `generic_raw_contract` reads Raw Parquet files from MinIO with
  `read_parquet`.
- `publish_raw_fixture_parquet` writes a deterministic Raw fixture to MinIO.
- Silver models use the custom `iceberg_table` materialization.
- Gold marts are created from intermediate dbt models and also use
  `iceberg_table`.
- Airflow publishes the Raw fixture first, then runs the dbt Silver and Gold
  chain in Kubernetes pods.

The local seed file remains only as a study fallback.

## Runtime variables

Inside the kind cluster, dbt uses:

```text
DBT_S3_ENDPOINT=minio.data-platform.svc.cluster.local:9000
DBT_POLARIS_ENDPOINT=http://polaris.data-platform.svc.cluster.local:8181/api/catalog
DBT_POLARIS_CATALOG_NAME=lakehouse
DBT_POLARIS_WAREHOUSE=lakehouse
DBT_ENABLE_POLARIS_ATTACH=true
DBT_RAW_FIXTURE_ROOT=s3://lakehouse/raw
DBT_RAW_SOURCE_EVENTS_PATH=s3://lakehouse/raw/source=*/dataset=*/ingestion_date=*/*.parquet
```

`DBT_POLARIS_WAREHOUSE` is the Polaris catalog/warehouse name used by DuckDB's
Iceberg REST attach. The physical storage location is configured when the
Polaris catalog is bootstrapped:

```text
s3://lakehouse/warehouse
```

## Files to change for your own pipeline

To add a new Raw Parquet dataset:

1. Write files under the canonical Raw layout:

   ```text
   s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
   ```

2. Keep the minimum technical columns:

   ```text
   loaded_at
   record_hash
   raw_payload
   ```

   `source`, `dataset` and `ingestion_date` can come from Hive partitions.

3. Add stable source fields as Parquet columns when possible.

4. Update these dbt files:

   ```text
   dbt/models/raw_sources/generic_raw_contract.sql
   dbt/models/staging/stg_raw_source_events.sql
   dbt/models/silver/*.sql
   dbt/models/intermediate/*.sql
   dbt/models/marts/*.sql
   ```

5. Add or update tests in the matching `schema.yml` files.

6. If the path changes, set:

   ```bash
   export DBT_RAW_SOURCE_EVENTS_PATH="s3://lakehouse/raw/source=my_source/dataset=my_dataset/ingestion_date=*/*.parquet"
   ```

## Full local validation

Create the local cluster and platform services:

```bash
make cluster-create
make deploy-minio

export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"

make deploy-polaris
make polaris-health
```

Build and load the dbt image, then publish the Raw fixture inside the cluster:

```bash
make build-dbt-image
make load-dbt-image
make publish-raw-fixture-parquet
```

Build, load and deploy Airflow:

```bash
make build-airflow-image
make load-airflow-image
make deploy-airflow
make airflow-status
```

Trigger the dbt pipeline:

```bash
make trigger-airflow-dbt
```

Check the DAG run:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily

kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow tasks states-for-dag-run open_lakehouse_lab_daily "<run_id>"
```

Replace `<run_id>` with the run id returned by `list-runs`.

## Interfaces to access

Airflow UI:

```bash
make port-forward-airflow
```

```text
http://localhost:8080
username: admin
password: admin
```

MinIO Console:

```bash
make port-forward-minio
```

```text
http://localhost:9001
username: minioadmin
password: minioadmin123
```

Expected MinIO paths:

```text
lakehouse/raw/source=fixture/dataset=weather_sample/ingestion_date=2026-05-10/
lakehouse/raw/source=fixture/dataset=earthquake_sample/ingestion_date=2026-05-10/
lakehouse/raw/source=fixture/dataset=macro_indicator_sample/ingestion_date=2026-05-10/
lakehouse/warehouse/
```

Polaris has no project UI in this stage. Use the health endpoint:

```bash
make port-forward-polaris
```

```text
http://localhost:8182/q/health/ready
```

## SQL inspection

The most reliable full-path validation runs in the cluster through Airflow.
For host-side exploration, keep the MinIO and Polaris port-forwards running and
use the local dbt CLI:

```bash
export AWS_ACCESS_KEY_ID="minioadmin"
export AWS_SECRET_ACCESS_KEY="minioadmin123"
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export DBT_S3_ENDPOINT="localhost:9000"
export DBT_POLARIS_ENDPOINT="http://localhost:8181/api/catalog"
export DBT_POLARIS_CATALOG_NAME="lakehouse"
export DBT_POLARIS_WAREHOUSE="lakehouse"
export DBT_ENABLE_POLARIS_ATTACH="true"

make dbt-publish-raw-fixture
make dbt-run-foundation
make dbt-run-staging
make dbt-run-silver
make dbt-run-gold
make dbt-test-silver
make dbt-test-gold
```

Then use DuckDB CLI for ad hoc inspection:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

Example queries:

```sql
load httpfs;
load iceberg;

create or replace secret polaris_secret (
  type iceberg,
  client_id 'root',
  client_secret 'local-polaris-secret',
  oauth2_server_uri 'http://localhost:8181/api/catalog/v1/oauth/tokens',
  oauth2_scope 'PRINCIPAL_ROLE:ALL'
);

attach if not exists 'lakehouse' as lakehouse (
  type iceberg,
  endpoint 'http://localhost:8181/api/catalog',
  secret polaris_secret,
  access_delegation_mode 'vended_credentials'
);

show all tables;
select * from lakehouse.main_silver.silver_source_events;
select * from lakehouse.main_marts.gold_pipeline_health_daily;
select * from iceberg_snapshots(lakehouse.main_silver.silver_source_events);
```

Close DuckDB CLI, DuckDB UI or VS Code DuckDB connections before running dbt
again. DuckDB allows only one writer to the same database file.

## Quality checks

Run before opening or updating the PR:

```bash
make ci-pr
```

## Known limitations

- The fixture is deterministic and small; real source adapters remain separate.
- The MVP uses full-refresh table replacement and avoids `MERGE`, `UPDATE`,
  `DELETE` and `ALTER TABLE`.
- Polaris persistence is still the local in-memory Stage 04 setup.
- Host-side Iceberg writes depend on port-forwarded local endpoints; the
  cluster path is the reference validation path for this stage.
