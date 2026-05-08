---
name: dbt-duckdb-iceberg
description: Use this skill for dbt, DuckDB, Polaris, Iceberg materializations, SQL models, tests, and Raw to Silver to Gold transformations.
---

# dbt DuckDB Iceberg Skill

## Scope

Use this skill when working under:

```text
dbt/
ingestion/
metadata/
```

or when changing SQL transformation behavior.

## Model layering

Expected dbt layout:

```text
models/raw_sources/
models/staging/
models/silver/
models/intermediate/
models/marts/
```

Layer responsibilities:

- `raw_sources`: external source declarations for Raw data in MinIO.
- `staging`: JSON flattening, casts, naming and timestamp normalization.
- `silver`: typed, deduplicated Iceberg tables.
- `intermediate`: reusable analytical transformations.
- `marts`: Gold Iceberg tables.

## Iceberg constraints

For the MVP:

- Prefer full-refresh idempotent materializations.
- Avoid `MERGE INTO`.
- Avoid `ALTER TABLE`.
- Avoid `UPDATE` and `DELETE` on Iceberg tables.
- Use Polaris REST Catalog as the catalog target.

## Validation

Run or document:

```bash
make lint-dbt
make dbt-parse
make dbt-compile
```

When tests are available:

```bash
make dbt-test
```

## SQL conventions

- Prefer readable CTEs.
- Use explicit casts.
- Use stable natural keys for deduplication.
- Add `not_null`, `unique`, `accepted_values` or custom dbt tests for important columns.
- Keep table names layer-prefixed, such as `silver_weather_hourly` and `gold_macro_indicators_daily`.

## Do not

- Do not hard-code real credentials.
- Do not use private datasets.
- Do not introduce non-open-source dbt adapters.
