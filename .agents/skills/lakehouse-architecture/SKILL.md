---
name: lakehouse-architecture
description: Use this skill for architecture changes involving Raw, Silver, Gold, MinIO, Apache Iceberg, Apache Polaris, DuckDB, dbt, or the overall Open Lakehouse Lab design.
---

# Lakehouse Architecture Skill

## Architecture principles

Open Lakehouse Lab uses a local, open source lakehouse architecture:

```text
Public APIs -> Raw -> Silver Iceberg -> Gold Iceberg -> Metadata and Observability
```

Core components:

- MinIO for object storage.
- Apache Polaris for Iceberg REST Catalog.
- Apache Iceberg for Silver and Gold table format.
- DuckDB for local SQL execution.
- dbt-duckdb for Raw -> Silver -> Gold transformations.
- Airflow with KubernetesPodOperator for orchestration.

## Design rules

- Raw stores original API payloads.
- Silver stores normalized, typed and deduplicated Iceberg tables.
- Gold stores curated marts and operational metrics as Iceberg tables.
- Prefer full-refresh idempotent behavior in the MVP.
- Avoid `MERGE INTO`, `ALTER TABLE`, `UPDATE` and `DELETE` on Iceberg tables in the MVP.
- Keep storage paths deterministic and documented.
- Make architecture decisions explicit through ADRs.

## Review checklist

Before approving architecture changes, verify:

- the change preserves local reproducibility;
- no paid cloud dependency was added;
- table ownership by layer is clear;
- metadata and observability impacts are documented;
- operational limitations are documented.

## Documentation expectation

For relevant decisions, add or update an ADR in `docs/adr/`.
