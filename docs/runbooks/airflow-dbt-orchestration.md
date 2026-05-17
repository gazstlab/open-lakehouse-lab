# Orquestracao dbt com Airflow

## Objetivo

A etapa 12 adiciona a DAG principal `open_lakehouse_lab_daily`. A DAG executa
comandos dbt em pods Kubernetes efemeros dentro do cluster kind local, usando a
mesma imagem `dbt + duckdb` construida pelo projeto.

Esta etapa mantem intencionalmente a execucao dbt fora do scheduler do Airflow.
O Airflow apenas orquestra pods e transmite logs. O ambiente de execucao dbt, adapter DuckDB,
extensoes DuckDB e arquivos do projeto vivem na imagem dbt.

## DAG atual

```text
start
  -> dbt_workloads.dbt_publish_raw_fixture
  -> dbt_workloads.dbt_run_foundation_staging_silver
  -> dbt_workloads.dbt_test_silver
  -> dbt_workloads.dbt_run_intermediate_gold
  -> dbt_workloads.dbt_test_gold
  -> end
```

A DAG usa `KubernetesPodOperator` para cada task dbt. Cada pod usa:

```text
image: open-lakehouse-lab-dbt-duckdb-polaris:local
namespace: data-platform
service account: airflow-worker
imagePullPolicy: Never
```

`astronomer-cosmos[dbt-duckdb]` continua instalado na imagem Airflow. A
implementacao atual usa tasks explicitas de pod porque esta etapa precisa de um
caminho de orquestracao pequeno, revisavel e com a stack de dependencias dbt
isolada na imagem dbt. Um refinamento posterior pode substituir as tasks
explicitas pelo modo de execucao Kubernetes do Cosmos quando o grafo de modelos
dbt e a materializacao Iceberg estiverem estaveis o suficiente para aproveitar
renderizacao de tasks por modelo.

## Estado de execucao do DuckDB

O profile dbt local escreve o estado DuckDB em:

```text
/app/dbt/target/open_lakehouse_lab.duckdb
```

Como cada task dbt roda em um pod efemero diferente, a DAG monta um PVC pequeno
em `/app/dbt/target`:

```text
dbt-workload-target
```

Esse PVC e apenas estado de desenvolvimento local. Ele existe para artefatos
dbt, views locais e estado temporario do DuckDB. Ele nao e a fonte da verdade. A
A etapa 13 armazena Raw Parquet e dados de tabelas Iceberg no MinIO, com Silver e
Gold registrados no Polaris.

## Pre-requisitos

Instale as ferramentas locais:

```bash
kind version
kubectl version --client
docker version
helm version
```

Crie o cluster kind e o namespace:

```bash
make cluster-create
make kubectl-context
```

Suba MinIO:

```bash
make deploy-minio
```

Suba Polaris:

```bash
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"

make deploy-polaris
make polaris-health
```

Construa e carregue a imagem dbt no kind:

```bash
make build-dbt-image
make load-dbt-image
```

Opcionalmente publique a fixture Raw Parquet deterministica antes de subir o
Airflow:

```bash
make publish-raw-fixture-parquet
```

Construa, carregue e suba o Airflow:

```bash
make build-airflow-image
make load-airflow-image
make deploy-airflow
make airflow-status
```

## Disparar a DAG

Dispare pela CLI:

```bash
make trigger-airflow-dbt
```

Ou dispare pela UI do Airflow:

```bash
make port-forward-airflow
```

Abra:

```text
http://localhost:8080
```

Credenciais:

```text
usuario: admin
senha: admin
```

Dispare:

```text
open_lakehouse_lab_daily
```

## Validar execucao dos pods

Enquanto a DAG estiver rodando:

```bash
make airflow-dbt-pods
```

Voce tambem pode inspecionar os pods diretamente:

```bash
kubectl -n data-platform get pods \
  -l app.kubernetes.io/component=dbt-workload
```

Comportamento esperado:

- um pod dbt roda por task;
- logs aparecem nos logs da task na UI do Airflow;
- pods sao removidos apos a conclusao da task com sucesso;
- o PVC `dbt-workload-target` permanece para a proxima task e futuras DAG runs.

## Validar interfaces locais

UI do Airflow:

```bash
make port-forward-airflow
```

```text
http://localhost:8080
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

Endpoint de readiness do Polaris:

```bash
make port-forward-polaris
```

```text
http://localhost:8182/q/health/ready
```

## Validar com SQL

O caminho completo escreve Raw Parquet e dados Iceberg no MinIO. Para inspecao a
partir do host, mantenha os port-forwards de MinIO e Polaris rodando e use o
runbook da etapa 13:

```bash
make port-forward-minio
make port-forward-polaris
```

Veja:

```text
docs/runbooks/dbt-minio-polaris-backbone.md
```

Se voce mantiver DuckDB CLI, DuckDB UI ou uma extensao do VS Code conectada ao
mesmo arquivo, o dbt pode falhar com erro de lock do DuckDB. Feche a outra
conexao antes de rodar comandos dbt.

## Limpeza

Remova Airflow e o PVC do workload dbt:

```bash
make delete-airflow
```

Remova o cluster local completo:

```bash
make cluster-delete
```

## Limitacoes

- Esta etapa orquestra a cadeia dbt atual; ela nao adiciona tasks de ingestao de
  adapters de fontes publicas.
- A publicacao da fixture Raw e um atalho deterministico para estudo. O comando
  e logado pelo pod dbt antes da execucao.
- A implementacao atual mantem tasks explicitas com `KubernetesPodOperator`. Isso
  e compativel com o requisito do projeto de rodar workloads em pods e deixa
  espaco para adotar renderizacao de tasks Kubernetes via Cosmos quando o grafo
  de modelos amadurecer.
