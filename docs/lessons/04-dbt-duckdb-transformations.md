# Lição 04 - Transformações com dbt e DuckDB

## Objetivo

Entender como dbt usa DuckDB para ler Raw Parquet, transformar dados e publicar
tabelas Iceberg Silver e Gold.

## Atalhos

```bash
make dbt-parse
make dbt-compile
make dbt-run-foundation
make dbt-run-staging
make dbt-run-silver
make dbt-test-silver
make dbt-run-gold
make dbt-test-gold
```

Para publicar dados Raw de teste:

```bash
make explain-publish-raw-fixture
make publish-raw-fixture-parquet
```

## Comandos Manuais

```bash
cd dbt
dbt deps
dbt parse --profiles-dir .
dbt compile --profiles-dir .
dbt run --select raw_sources --profiles-dir .
dbt run --select staging --profiles-dir .
DBT_ENABLE_POLARIS_ATTACH=true DBT_THREADS=1 dbt run --no-populate-cache --select silver --profiles-dir .
DBT_ENABLE_POLARIS_ATTACH=true DBT_THREADS=1 dbt test --no-populate-cache --select silver --profiles-dir .
DBT_ENABLE_POLARIS_ATTACH=true DBT_THREADS=1 dbt run --no-populate-cache --select intermediate marts --profiles-dir .
DBT_ENABLE_POLARIS_ATTACH=true DBT_THREADS=1 dbt test --no-populate-cache --select marts --profiles-dir .
```

## O Que Acontece

- `raw_sources` lê arquivos Parquet com `read_parquet`.
- `staging` normaliza nomes, tipos e campos estruturados.
- `silver` publica tabelas Iceberg limpas.
- `intermediate` prepara agregacoes reutilizaveis.
- `marts` publica tabelas Gold para análise.

## Inspeção com DuckDB

Abra o arquivo local:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

No prompt DuckDB:

```sql
show schemas;
select * from main_raw_sources.generic_raw_contract limit 10;
select * from main_staging.stg_raw_source_events limit 10;
```

Se você anexar o arquivo a partir de outro banco, qualifique com o nome do
catálogo retornado por `show schemas`, por exemplo:

```sql
select * from lab.main_raw_sources.generic_raw_contract limit 10;
```

## Customização

Crie novos modelos nas pastas `dbt/models/staging`, `dbt/models/silver`,
`dbt/models/intermediate` e `dbt/models/marts`. Documente colunas e testes nos
respectivos `schema.yml`.
