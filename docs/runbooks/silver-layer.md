# Silver layer

This runbook describes the Stage 10 generic Silver layer for Open Lakehouse Lab.

## Scope

Stage 10 builds generic Silver models from the canonical staging contract created in Stage 09.

The Silver layer is intentionally source-agnostic. Public APIs and future adapters should write into the Raw contract and flow through staging before reaching these Silver models.

## Input model

Silver models read from:

```text
dbt/models/staging/stg_raw_source_events.sql
```

Expected staging columns:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
observed_at
metric_name
metric_value
location_name
```

## Silver models

### `silver_source_events`

Deduplicated source-event table.

Rules:

- one row per `record_hash`;
- latest record wins by `loaded_at desc, observed_at desc`;
- preserves `raw_payload` for audit and replay;
- remains generic across source adapters.

### `silver_metric_observations`

Analytical observation table for numeric metrics.

Rules:

- one row per stable `observation_id`;
- requires `metric_name`, `metric_value` and `observed_at`;
- keeps `record_hash` for traceability back to the source event.

### `silver_dataset_freshness`

Dataset-level freshness and volume table.

Metrics:

- latest observed timestamp;
- latest loaded timestamp;
- first and latest ingestion date;
- total records;
- unique record hashes.

## Run locally

From the repository root, run the Stage 13 MinIO/Polaris path:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
make dbt-run-staging
make dbt-run-silver
make dbt-test-silver
```

General validation:

```bash
make lint-dbt
make dbt-parse
make dbt-compile
make dbt-test
make ci-pr
```

## Design decisions

- Silver is generic first; source-specific models are deferred until real source adapters exist.
- Deduplication uses `record_hash`, which is the stable technical key from the Raw/Staging contract.
- Stage 13 publishes Silver as Iceberg tables through the custom
  `iceberg_table` materialization.

## Known limitations

- Stage 10 does not consume public APIs directly.
- Stage 10 does not require source adapter runtime images.
- Stage 10 did not validate tables inside Polaris as physical Iceberg snapshots;
  Stage 13 adds that backbone.
