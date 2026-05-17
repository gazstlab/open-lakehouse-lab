# Guia de customizacao do usuario

Este guia explica como usar o Open Lakehouse Lab para criar um pipeline proprio
sem perder o caminho padrao como referencia.

## O que e plataforma, exemplo e experimento

Plataforma:

- kind, Kubernetes, MinIO, Polaris, Airflow, dbt e DuckDB;
- manifests em `k8s/`;
- imagens em `docker/` e `airflow/Dockerfile`;
- comandos do `Makefile`.

Exemplo padrao:

- fixture Raw em Parquet;
- modelos dbt em `dbt/models/`;
- DAG `airflow/dags/open_lakehouse_lab_daily.py`.

Experimentos do usuario:

- novos arquivos Raw em MinIO;
- novos modelos dbt;
- DAGs didaticas ou DAGs proprias em `airflow/dags/lab_*.py`;
- ajustes de schedule, parametros e retries.

## Adicionar Dados Raw

O contrato canonico inicial da Raw e Parquet:

```text
s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
```

Colunas tecnicas minimas:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
```

Campos conhecidos da fonte podem ser gravados como colunas adicionais no
Parquet. O `raw_payload` preserva o registro original quando isso for util para
auditoria ou reprocessamento.

Para estudar sem criar um adapter, publique a fixture:

```bash
make publish-raw-fixture-parquet
```

Para ver os arquivos no MinIO:

```bash
make port-forward-minio
```

Abra `http://localhost:9001`, entre com `minioadmin / minioadmin123` e navegue
para:

```text
lakehouse/raw/source=*/dataset=*/ingestion_date=*/*.parquet
```

Tambem e possivel listar por pod:

```bash
kubectl -n data-platform run minio-list --rm -i --restart=Never \
  --image=minio/mc:RELEASE.2025-04-16T18-13-26Z \
  -- sh -c 'mc alias set local http://minio:9000 minioadmin minioadmin123 && mc find local/lakehouse/raw'
```

## Criar Modelos dbt

Use o fluxo:

```text
raw_sources -> staging -> silver -> intermediate -> marts
```

Arquivos principais:

| Objetivo | Arquivos |
|---|---|
| Ler Raw Parquet | `dbt/models/raw_sources/generic_raw_contract.sql` |
| Documentar Raw | `dbt/models/raw_sources/schema.yml` |
| Normalizar nomes e tipos | `dbt/models/staging/*.sql` |
| Criar tabelas Iceberg Silver | `dbt/models/silver/*.sql` |
| Criar modelos intermediarios | `dbt/models/intermediate/*.sql` |
| Criar tabelas Gold | `dbt/models/marts/*.sql` |
| Configurar caminhos e catalogo | `dbt/dbt_project.yml` e `dbt/profiles.yml` |

Para um novo dataset, o caminho mais simples e:

1. gravar Parquet na Raw seguindo o caminho canonico;
2. criar ou ajustar um modelo em `dbt/models/staging/`;
3. criar um modelo Silver em `dbt/models/silver/`;
4. criar marts em `dbt/models/marts/` se precisar de tabelas finais;
5. documentar colunas e testes nos arquivos `schema.yml`;
6. validar com `make dbt-parse`, `make dbt-compile` e testes dbt.

Quando o novo modelo estiver dentro das pastas ja selecionadas pela DAG
principal, normalmente nao e necessario editar Airflow. A DAG executa:

```text
dbt run --select raw_sources staging silver
dbt test --select silver
dbt run --select intermediate marts
dbt test --select marts
```

## Quando Editar Airflow

Nao edite `airflow/dags/open_lakehouse_lab_daily.py` quando:

- voce apenas adicionou modelos dbt nas pastas existentes;
- voce alterou testes ou documentacao dbt;
- voce mudou uma transformacao SQL que continua no fluxo Raw -> Silver -> Gold.

Edite a DAG principal ou crie uma DAG propria quando:

- precisar de uma nova task antes do dbt, como um adapter de fonte;
- quiser alterar schedule, retries ou limites de concorrencia;
- precisar passar parametros para uma execucao;
- quiser dividir o pipeline em grupos ou DAGs menores;
- quiser estudar operadores do Airflow sem afetar o exemplo padrao.

Para experimentos, prefira criar DAGs `airflow/dags/lab_*.py`. A etapa 14 inclui
exemplos pequenos que podem ser ativados e disparados pela UI do Airflow.

## Parametros Importantes

dbt e DuckDB:

| Variavel | Uso |
|---|---|
| `DBT_DUCKDB_PATH` | arquivo DuckDB local ou no pod |
| `DBT_S3_ENDPOINT` | endpoint MinIO para DuckDB `httpfs` |
| `DBT_RAW_SOURCE_EVENTS_PATH` | glob Parquet lido pela Raw |
| `DBT_ENABLE_POLARIS_ATTACH` | habilita attach do catalogo Polaris |
| `DBT_POLARIS_ENDPOINT` | endpoint REST Catalog |
| `DBT_POLARIS_CATALOG_NAME` | nome do catalogo Iceberg |
| `DBT_POLARIS_WAREHOUSE` | warehouse/caminho do catalogo |

Airflow:

| Arquivo | Uso |
|---|---|
| `airflow/dags/open_lakehouse_lab_daily.py` | DAG principal do exemplo |
| `airflow/dags/lab_*.py` | DAGs didaticas e experimentos |
| `k8s/airflow/values.yaml` | valores Helm do Airflow |
| `k8s/airflow/pod-launcher-rbac.yaml` | permissao para criar pods |
| `k8s/airflow/dbt-workload-pvc.yaml` | PVC usado pelo target dbt dos pods |

## Ciclo de Desenvolvimento Local

Suba a plataforma:

```bash
make cluster-create
make deploy-minio
make build-dbt-image
make load-dbt-image
make deploy-polaris
make publish-raw-fixture-parquet
make build-airflow-image
make load-airflow-image
make deploy-airflow
```

Valide dbt localmente:

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

Valide pela orquestracao:

```bash
make trigger-airflow-dbt
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily
```

Rode a qualidade antes de abrir PR:

```bash
make ci-pr
```

## Limites Atuais

- A Raw canonica inicial considera Parquet.
- CSV e JSON podem ser estudados depois com adapters ou macros DuckDB, mas nao
  fazem parte do caminho padrao desta etapa.
- O projeto e um laboratorio local, nao uma plataforma de producao.
- Credenciais padrao sao apenas para desenvolvimento local.
