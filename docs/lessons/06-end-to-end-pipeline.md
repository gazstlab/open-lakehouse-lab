# Lição 06 - Pipeline ponta a ponta

## Objetivo

Executar o caminho completo do laboratório: Raw Parquet no MinIO, dbt + DuckDB,
Iceberg via Polaris e orquestração pelo Airflow.

## Exemplos

```bash
make example
```

Esse comando é ideal para uma primeira validação em um ambiente limpo.

## Caminho Passo a Passo

```bash
make cluster-create
make deploy-minio
make build-dbt-image
make load-dbt-image
make deploy-polaris
make polaris-health
make publish-raw-fixture-parquet
make build-airflow-image
make load-airflow-image
make deploy-airflow
make trigger-airflow-dbt
```

## Inspeção

Kubernetes:

```bash
make cluster-status
kubectl -n data-platform get pods
```

MinIO:

```bash
make port-forward-minio
```

Abra `http://localhost:9001` e confira `lakehouse/raw`.

Polaris:

```bash
make polaris-health
```

Airflow:

```bash
make port-forward-airflow
```

Abra `http://localhost:8080`, confira a DAG `open_lakehouse_lab_daily` e veja os
logs das tasks.

CLI Airflow:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily
```

DuckDB:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

```sql
show schemas;
select count(*) from main_raw_sources.generic_raw_contract;
select count(*) from main_staging.stg_raw_source_events;
```

## Customização

Depois que o exemplo funcionar:

1. adicione novos Parquet na Raw;
2. crie modelos dbt de staging e Silver;
3. crie marts quando precisar de tabelas finais;
4. rode `make dbt-compile` e testes dbt;
5. use Airflow apenas para orquestrar novas etapas ou mudar agenda.
