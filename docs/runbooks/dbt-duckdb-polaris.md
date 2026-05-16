# dbt + DuckDB + Polaris foundation

This runbook describes the Stage 08 dbt foundation for Open Lakehouse Lab.

## Scope

Stage 08 configures a dbt project that uses DuckDB as the local SQL engine and Apache Polaris as the future Iceberg REST Catalog target.

The goal is to make the lakehouse transformation foundation independent from ingestion. Source adapters can be implemented later as long as they write data following the Raw contract.

This stage validates project structure, configuration and compilation. It intentionally does not require public API extractors or live public network calls.

## Raw contract

The generic Raw contract uses these minimum technical columns:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
```

Responsibilities:

- `source`: logical source adapter name.
- `dataset`: dataset produced by the source adapter.
- `ingestion_date`: date partition associated with the Raw landing event.
- `loaded_at`: timestamp when the event was loaded.
- `record_hash`: stable technical key for the Raw record.
- `raw_payload`: original payload preserved when useful for audit or replay.

The current canonical Raw format is Parquet. Stage 13 writes and reads the
fixture through MinIO; the local seed remains only as a study fallback.

## Files

Main files introduced or updated by this stage:

```text
dbt/dbt_project.yml
dbt/profiles.yml
dbt/macros/attach_polaris.sql
dbt/macros/materializations/iceberg_table.sql
dbt/seeds/raw_source_events.csv
dbt/models/raw_sources/generic_raw_contract.sql
dbt/models/raw_sources/schema.yml
dbt/models/raw_sources/sources.yml
docker/dbt-duckdb-polaris.Dockerfile
```

## Local environment

Default local settings assume MinIO and Polaris are available from the host
through port-forwarding:

```bash
export DBT_S3_ENDPOINT="localhost:9000"
export DBT_POLARIS_ENDPOINT="http://localhost:8181/api/catalog"
export DBT_POLARIS_CATALOG_NAME="lakehouse"
export DBT_POLARIS_WAREHOUSE="lakehouse"
export AWS_REGION="us-east-1"
```

For a local educational setup, MinIO credentials can be provided through environment variables:

```bash
export AWS_ACCESS_KEY_ID="<local-minio-access-key>"
export AWS_SECRET_ACCESS_KEY="<local-minio-secret-key>"
```

Do not commit real credentials.

## Validate dbt project

From the repository root:

```bash
make dbt-parse
make dbt-compile
```

To publish the Raw fixture to MinIO and build the Raw contract model:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
```

## Build the dbt runtime image

```bash
make build-dbt-image
```

Load it into kind:

```bash
make load-dbt-image
```

## Polaris macro

The macro `attach_polaris_catalog` is intentionally isolated. It can be reused
by future stages from:

- `dbt run-operation`;
- dbt hooks;
- custom Iceberg materializations;
- Airflow tasks running dbt in Kubernetes.

DuckDB expects the Polaris REST Catalog endpoint, including `/api/catalog`, and
the Polaris catalog name as the warehouse value.

## Iceberg materialization

The initial `iceberg_table` materialization is deliberately conservative:

- full-refresh oriented;
- no `MERGE INTO`;
- no `UPDATE`;
- no `DELETE`;
- no `ALTER TABLE`.

This keeps the MVP easy to reason about. Later stages can evolve this once
table health, metadata collection and compaction strategies exist.

## Known limitations

- Stage 08 validates the dbt foundation and Raw contract, but does not require
  public APIs.
- Concrete source adapters are implemented later.
- Stage 13 completes the MinIO + Polaris execution path. See
  `docs/runbooks/dbt-minio-polaris-backbone.md`.
- Running against a live Polaris catalog requires Stage 04 services to be available.
