# Coluna dorsal dbt MinIO Polaris

Este runbook descreve a coluna dorsal da etapa 13:

```text
MinIO Raw Parquet
  -> processamento dbt + DuckDB
  -> tabelas Iceberg Silver e Gold
  -> Polaris REST Catalog
  -> pods dbt via KubernetesPodOperator no Airflow
```

DuckDB e a engine SQL. Ele nao e a camada final de storage. Dados persistentes
ficam no MinIO, e o registro das tabelas Iceberg fica no Polaris.

## O que mudou

A etapa 13 faz o caminho padrao usar MinIO e Polaris:

- `generic_raw_contract` le arquivos Raw Parquet do MinIO com
  `read_parquet`.
- `publish_raw_fixture_parquet` escreve uma fixture Raw deterministica no MinIO.
- modelos Silver usam a materializacao customizada `iceberg_table`.
- marts Gold sao criados a partir de modelos dbt intermediate e tambem usam
  `iceberg_table`.
- Airflow publica a fixture Raw primeiro e depois executa a cadeia dbt Silver e
  Gold em pods Kubernetes.

O arquivo de seed local permanece apenas como fallback de estudo.

## Variaveis de ambiente de execucao

Dentro do cluster kind, dbt usa:

```text
DBT_S3_ENDPOINT=minio.data-platform.svc.cluster.local:9000
DBT_POLARIS_ENDPOINT=http://polaris.data-platform.svc.cluster.local:8181/api/catalog
DBT_POLARIS_CATALOG_NAME=lakehouse
DBT_POLARIS_WAREHOUSE=lakehouse
DBT_ENABLE_POLARIS_ATTACH=true
DBT_RAW_FIXTURE_ROOT=s3://lakehouse/raw
DBT_RAW_SOURCE_EVENTS_PATH=s3://lakehouse/raw/source=*/dataset=*/ingestion_date=*/*.parquet
```

`DBT_POLARIS_WAREHOUSE` e o nome de catalogo/warehouse Polaris usado pelo attach
Iceberg REST do DuckDB. A localizacao fisica de storage e configurada quando o
catalogo Polaris e inicializado:

```text
s3://lakehouse/warehouse
```

## Arquivos para alterar no seu proprio pipeline

Para adicionar um novo dataset Raw Parquet:

1. Escreva arquivos no layout canonico da Raw:

   ```text
   s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
   ```

2. Mantenha as colunas tecnicas minimas:

   ```text
   loaded_at
   record_hash
   raw_payload
   ```

   `source`, `dataset` e `ingestion_date` podem vir das particoes Hive.

3. Adicione campos estaveis da fonte como colunas Parquet quando possivel.

4. Atualize estes arquivos dbt:

   ```text
   dbt/models/raw_sources/generic_raw_contract.sql
   dbt/models/staging/stg_raw_source_events.sql
   dbt/models/silver/*.sql
   dbt/models/intermediate/*.sql
   dbt/models/marts/*.sql
   ```

5. Adicione ou atualize testes nos arquivos `schema.yml` correspondentes.

6. Se o path mudar, configure:

   ```bash
   export DBT_RAW_SOURCE_EVENTS_PATH="s3://lakehouse/raw/source=my_source/dataset=my_dataset/ingestion_date=*/*.parquet"
   ```

## Validacao local completa

Crie o cluster local e os servicos da plataforma:

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

Construa e carregue a imagem dbt, depois publique a fixture Raw dentro do
cluster:

```bash
make build-dbt-image
make load-dbt-image
make publish-raw-fixture-parquet
```

Construa, carregue e suba o Airflow:

```bash
make build-airflow-image
make load-airflow-image
make deploy-airflow
make airflow-status
```

Dispare o pipeline dbt:

```bash
make trigger-airflow-dbt
```

Verifique a DAG run:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily

kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow tasks states-for-dag-run open_lakehouse_lab_daily "<run_id>"
```

Substitua `<run_id>` pelo run id retornado por `list-runs`.

## Interfaces para acessar

UI do Airflow:

```bash
make port-forward-airflow
```

```text
http://localhost:8080
usuario: admin
senha: admin
```

Console MinIO:

```bash
make port-forward-minio
```

```text
http://localhost:9001
usuario: minioadmin
senha: minioadmin123
```

Paths esperados no MinIO:

```text
lakehouse/raw/source=fixture/dataset=weather_sample/ingestion_date=2026-05-10/
lakehouse/raw/source=fixture/dataset=earthquake_sample/ingestion_date=2026-05-10/
lakehouse/raw/source=fixture/dataset=macro_indicator_sample/ingestion_date=2026-05-10/
lakehouse/warehouse/
```

Polaris nao tem UI de projeto nesta etapa. Use o endpoint de saude:

```bash
make port-forward-polaris
```

```text
http://localhost:8182/q/health/ready
```

## Inspecao SQL

A validacao mais confiavel do caminho completo roda no cluster pelo Airflow.
Para exploracao a partir do host, mantenha os port-forwards de MinIO e Polaris
rodando e use a CLI dbt local:

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

Depois use a CLI DuckDB para inspecao ad hoc:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

Consultas de exemplo:

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

Feche DuckDB CLI, DuckDB UI ou conexoes DuckDB do VS Code antes de rodar dbt
novamente. DuckDB permite apenas um processo de escrita no mesmo arquivo de banco.

## Verificacoes de qualidade

Rode antes de abrir ou atualizar o PR:

```bash
make ci-pr
```

## Limitacoes conhecidas

- A fixture e deterministica e pequena; adapters reais de fonte permanecem separados.
- O MVP usa substituicao de tabelas em full-refresh e evita `MERGE`, `UPDATE`,
  `DELETE` e `ALTER TABLE`.
  `DELETE` e `ALTER TABLE`.
- A persistencia do Polaris ainda e a configuracao local em memoria da etapa 04.
- Escritas Iceberg a partir do host dependem de endpoints locais via
  port-forward; o caminho no cluster e a validacao de referencia desta etapa.
