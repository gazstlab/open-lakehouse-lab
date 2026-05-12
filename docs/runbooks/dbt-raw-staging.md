# dbt Raw sources and staging

This runbook describes the Stage 09 Raw source and staging foundation.

## Scope

Stage 09 makes dbt read a generic Raw contract and build an initial staging
model without depending on public APIs, Airflow ingestion DAGs or external
network calls.

The current canonical Raw format is Parquet. Local validation still uses a dbt
seed fixture because this stage does not implement source adapters or MinIO
writes yet.

## Canonical Raw layout

Future adapters should write Raw records to MinIO using this path convention:

```text
s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
```

Required technical columns:

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
- `dataset`: logical dataset produced by the source adapter.
- `ingestion_date`: Raw partition date.
- `loaded_at`: timestamp when the record was loaded into Raw.
- `record_hash`: stable technical key for deduplication and traceability.
- `raw_payload`: original payload preserved when useful for audit or replay.

Known, stable source fields should be expanded into Parquet columns when
possible. Other formats such as CSV and JSON can be added later through source
adapters or DuckDB read macros, but they are not part of the current canonical
contract.

## Local fixture

The seed `dbt/seeds/raw_source_events.csv` simulates canonical Raw Parquet rows
with controlled sample fields:

```text
observed_at
metric_name
metric_value
location_name
```

This lets dbt validate casts, source declarations and staging tests before real
adapters exist.

## dbt models

Stage 09 introduces:

```text
dbt/models/raw_sources/sources.yml
dbt/models/raw_sources/generic_raw_contract.sql
dbt/models/staging/stg_raw_source_events.sql
dbt/models/staging/schema.yml
```

Naming convention:

- Raw contract models stay under `models/raw_sources/`.
- Staging models use the `stg_` prefix.
- Staging models should normalize types and names, but should not create Silver
  business tables.

## Validate locally

From the repository root:

```bash
make dbt-seed
make dbt-run-foundation
make dbt-run-staging
make dbt-test
make dbt-parse
make dbt-compile
```

Full PR validation:

```bash
make ci-pr
```

## Known limitations

- This stage does not write Parquet files to MinIO.
- This stage does not implement Python source adapters.
- This stage does not consume Open-Meteo, USGS or BCB.
- This stage does not create Silver or Gold Iceberg tables.
