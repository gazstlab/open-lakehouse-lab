# open-lakehouse-lab

Open Lakehouse Lab e um projeto de estudo 100% open source para engenharia de
dados lakehouse moderna, com foco na comunidade brasileira.

## Caminho Rapido

Use o Caminho Rapido para subir o caminho padrao do laboratorio em um ambiente local.
O comando imprime o objetivo, o motivo, os comandos executados e as inspecoes
recomendadas para cada etapa.

```bash
make lab-fast-path
```

Esse caminho cria o cluster kind, sobe MinIO, Polaris e Airflow, publica uma
fixture Raw em Parquet, dispara a DAG principal e valida a coluna dorsal:

```text
MinIO Raw Parquet -> dbt + DuckDB -> Polaris/Iceberg -> pods Kubernetes no Airflow
```

## Trilha de Aprendizado

Use a Trilha de Aprendizado para estudar cada camada passo a passo antes de
customizar o pipeline.

```bash
make lab-learning-path
```

Documentacao principal:

- `docs/site/index.html`: pagina estatica para abrir diretamente no navegador;
- `docs/learning-path.md`: trilha guiada, Caminho Rapido, Trilha de Aprendizado e interfaces;
- `docs/user-customization-guide.md`: como criar pipelines proprios;
- `docs/troubleshooting/guided-troubleshooting.md`: erros comuns e recuperacao;
- `docs/lessons/`: licoes incrementais do cluster ao pipeline ponta a ponta.

Os atalhos tambem podem ser explicados sem alterar o ambiente:

```bash
make explain-cluster
make explain-deploy-minio
make explain-deploy-polaris
make explain-deploy-airflow
make explain-dbt-orchestration
```

Para navegar pela documentacao como uma pagina unica, abra diretamente:

```text
docs/site/index.html
```

## Estrutura do Projeto

A organizacao da etapa 01 separa o lakehouse local em areas explicitas de
implementacao:

```text
airflow/              Scaffold Airflow criado com Astro CLI.
airflow/dags/         Definicoes de DAGs do Airflow.
ingestion/common/     Utilitarios compartilhados de ingestao.
ingestion/open_meteo/ Codigo do extractor Open-Meteo.
ingestion/usgs/       Codigo do extractor de terremotos USGS.
ingestion/bcb/        Codigo do extractor Banco Central do Brasil SGS.
dbt/                  Projeto dbt Core inicializado com dbt init.
dbt/models/           Modelos Raw source, staging, Silver, intermediate e marts.
docker/               Dockerfiles dos ambientes de execucao locais.
k8s/                  Manifests kind, MinIO, Polaris, Airflow, monitoramento e RBAC.
metadata/             Artefatos de pipeline, qualidade, catalogo, Iceberg e freshness.
docs/adr/             Registros de decisoes de arquitetura.
docs/runbooks/        Runbooks operacionais.
docs/architecture/    Documentacao de arquitetura.
docs/lessons/         Licoes guiadas.
docs/troubleshooting/ Documentacao de troubleshooting.
```

O scaffold do Airflow e gerenciado com Astro CLI. As dependencias do ambiente de
execucao Airflow incluem Astronomer Cosmos com o extra dbt DuckDB para que etapas
posteriores possam orquestrar modelos dbt a partir do Airflow sem ligar cada
modelo manualmente como uma task customizada.

## Ordem de Implementacao

A fundacao lakehouse e implementada antes dos adapters concretos de fonte. A
ordem arquitetural atual e:

```text
MinIO -> Polaris -> Airflow -> dbt + DuckDB + Polaris -> Raw contract
  -> adapters genericos de fonte -> adapters de APIs publicas -> Silver -> Gold
```

Isso mantem o core lakehouse independente de Open-Meteo, USGS, Banco Central ou
qualquer outra fonte especifica. Adapters de fonte escrevem em um contrato Raw
generico consumido pelo dbt, e a fundacao dbt deve compilar com fixtures locais
antes de exigir ingestao real.

## Cluster Kubernetes Local

A etapa 02 provisiona um cluster kind local e o namespace base `data-platform`.
Veja `docs/runbooks/local-kind-cluster.md` para pre-requisitos, comandos de
ciclo de vida e passos de validacao.

## Armazenamento de Objetos Local

A etapa 03 sobe MinIO no cluster Kubernetes local e inicializa o bucket
`lakehouse`. Veja `docs/runbooks/minio-object-storage.md` para deploy,
port-forward e convencoes de path.

## Catalogo REST Iceberg Local

A etapa 04 sobe Apache Polaris como Iceberg REST Catalog local e inicializa o
catalogo `lakehouse` apoiado no path de warehouse do MinIO. Veja
`docs/runbooks/polaris-rest-catalog.md` para credenciais, deploy, checks de saude
e convencoes de endpoint.

## Orquestracao Local com Airflow

A etapa 05 sobe Airflow com o Helm chart do Apache Airflow e valida a criacao de
pods via `KubernetesPodOperator` no namespace local `data-platform`. Veja
`docs/runbooks/airflow-kubernetes-pod-operator.md` para build de imagem, deploy,
acesso a UI e validacao da DAG de teste de smoke.

A etapa 12 adiciona a DAG principal `open_lakehouse_lab_daily`. Ela executa
workloads dbt em pods Kubernetes efemeros usando a imagem local `dbt + duckdb` e
mantem o estado do target DuckDB em um PVC local pequeno. Veja
`docs/runbooks/airflow-dbt-orchestration.md` para o fluxo de teste local.

A etapa 14 adiciona DAGs didaticas chamadas `airflow/dags/lab_*.py` para que
usuarios explorem funcionalidades do Airflow, como `KubernetesPodOperator`,
params e retries, sem alterar a DAG estavel de exemplo.

## Fundacao dbt + DuckDB

A etapa 08 configura dbt com DuckDB e prepara pontos de integracao com Apache
Polaris e Apache Iceberg sem depender de ingestao de APIs publicas. Veja
`docs/runbooks/dbt-duckdb-polaris.md` para contrato Raw generico, comandos dbt,
ambiente de execucao Docker e limitacoes conhecidas.

## Camada Silver

A etapa 10 cria modelos dbt Silver genericos a partir do contrato canonico de
staging. A camada Silver atualmente fornece eventos de fonte deduplicados,
observacoes de metricas e metricas de freshness por dataset sem depender de
adapters de APIs publicas. Veja `docs/runbooks/silver-layer.md` para execucao e
validacao.

A etapa 13 conecta a coluna dorsal dbt/DuckDB ao MinIO e Polaris para que o
caminho de exemplo leia Raw Parquet e publique tabelas Iceberg localmente. A
etapa 14 explica esse caminho com documentacao guiada e atalhos explicaveis.

## Interfaces Locais

MinIO:

```bash
make port-forward-minio
```

Abra `http://localhost:9001` com `minioadmin / minioadmin123`.

Airflow:

```bash
make port-forward-airflow
```

Abra `http://localhost:8080` com `admin / admin`.

API de saude do Polaris:

```bash
make port-forward-polaris
curl -fsS http://localhost:8182/q/health/ready
```

dbt e usado pela CLI e pelos logs do Airflow. DuckDB pode ser aberto com:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

## Verificacoes de Qualidade para Desenvolvimento

Instale as dependencias de desenvolvimento:

```bash
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
```

Instale os hooks do Git:

```bash
pre-commit install --install-hooks
pre-commit install --hook-type pre-push
```

Rode os mesmos checks usados pelo GitHub Actions:

```bash
make ci-pr
```

Rode o check de pre-push manualmente:

```bash
make pre-push
```

O gate inicial de qualidade inclui:

- lint Python com Ruff;
- testes Python com pytest, quando `tests/` existir;
- lint YAML com yamllint;
- checks dbt/SQL com SQLFluff, quando `dbt/` existir;
- parse e compile do dbt, quando `dbt/` existir;
- validacao de manifests Kubernetes com kubeconform, quando `k8s/` existir;
- lint de Dockerfile com Hadolint, quando Dockerfiles existirem;
- checks de seguranca com Bandit e Trivy opcional;
- check de estrutura da documentacao.
