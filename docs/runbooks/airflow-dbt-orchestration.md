# Orquestração dbt com Airflow

## Objetivo

A etapa 12 adiciona a DAG principal `open_lakehouse_lab_daily`. A DAG executa
comandos dbt em pods Kubernetes efêmeros dentro do cluster kind local, usando a
mesma imagem `dbt + duckdb` construída pelo projeto.

Esta etapa mantém intencionalmente a execução dbt fora do scheduler do Airflow.
O Airflow apenas orquestra pods e transmite logs. O ambiente de execução dbt, adapter DuckDB,
extensões DuckDB e arquivos do projeto vivem na imagem dbt.

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
implementação atual usa tasks explícitas de pod porque esta etapa precisa de um
caminho de orquestração pequeno, revisável e com a stack de dependências dbt
isolada na imagem dbt. Um refinamento posterior pode substituir as tasks
explícitas pelo modo de execução Kubernetes do Cosmos quando o grafo de modelos
dbt e a materialização Iceberg estiverem estáveis o suficiente para aproveitar
renderizacao de tasks por modelo.

## Estado de execução do DuckDB

O profile dbt local escreve o estado DuckDB em:

```text
/app/dbt/target/open_lakehouse_lab.duckdb
```

Como cada task dbt roda em um pod efemero diferente, a DAG monta um PVC pequeno
em `/app/dbt/target`:

```text
dbt-workload-target
```

Esse PVC é apenas estado de desenvolvimento local. Ele existe para artefatos
dbt, views locais e estado temporário do DuckDB. Ele não é a fonte da verdade. A
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

Opcionalmente publique a fixture Raw Parquet determinística antes de subir o
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
usuário: admin
senha: admin
```

Dispare:

```text
open_lakehouse_lab_daily
```

## Validar execução dos pods

Enquanto a DAG estiver rodando:

```bash
make airflow-dbt-pods
```

Você também pode inspecionar os pods diretamente:

```bash
kubectl -n data-platform get pods \
  -l app.kubernetes.io/component=dbt-workload
```

Comportamento esperado:

- um pod dbt roda por task;
- logs aparecem nos logs da task na UI do Airflow;
- pods são removidos após a conclusão da task com sucesso;
- o PVC `dbt-workload-target` permanece para a próxima task e futuras DAG runs.

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
usuário: minioadmin
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

O caminho completo escreve Raw Parquet e dados Iceberg no MinIO. Para inspeção a
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

Se você mantiver DuckDB CLI, DuckDB UI ou uma extensao do VS Code conectada ao
mesmo arquivo, o dbt pode falhar com erro de lock do DuckDB. Feche a outra
conexão antes de rodar comandos dbt.

## Limpeza

Remova Airflow e o PVC do workload dbt:

```bash
make delete-airflow
```

Remova o cluster local completo:

```bash
make cluster-delete
```

## Limitações

- Esta etapa orquestra a cadeia dbt atual; ela não adiciona tasks de ingestão de
  adapters de fontes públicas.
- A publicação da fixture Raw é um atalho deterministico para estudo. O comando
  é logado pelo pod dbt antes da execução.
- A implementação atual mantém tasks explícitas com `KubernetesPodOperator`. Isso
  é compatível com o requisito do projeto de rodar workloads em pods e deixa
  espaço para adotar renderizacao de tasks Kubernetes via Cosmos quando o grafo
  de modelos amadurecer.
