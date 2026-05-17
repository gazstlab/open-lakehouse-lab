# open-lakehouse-lab

Open Lakehouse Lab é um projeto de estudo 100% open source para engenharia de
dados lakehouse moderna, com foco na comunidade brasileira.

## Exemplos

Use os Exemplos para subir o caminho padrão do laboratório em um ambiente local.
O comando imprime o objetivo, o motivo, os comandos executados e as inspeções
recomendadas para cada etapa.

```bash
make example
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

Documentação principal:

- `docs/site/index.html`: página estática para abrir diretamente no navegador;
- `docs/learning-path.md`: trilha guiada, Exemplos, Trilha de Aprendizado e interfaces;
- `docs/user-customization-guide.md`: como criar pipelines próprios;
- `docs/troubleshooting/guided-troubleshooting.md`: erros comuns e recuperação;
- `docs/lessons/`: lições incrementais do cluster ao pipeline ponta a ponta.

Os atalhos também podem ser explicados sem alterar o ambiente:

```bash
make explain-cluster
make explain-deploy-minio
make explain-deploy-polaris
make explain-deploy-airflow
make explain-dbt-orchestration
```

Para navegar pela documentação como uma página única, abra diretamente:

```text
docs/site/index.html
```

## Estrutura do Projeto

A organização da etapa 01 separa o lakehouse local em áreas explícitas de
implementação:

```text
airflow/              Scaffold Airflow criado com Astro CLI.
airflow/dags/         Definições de DAGs do Airflow.
ingestion/common/     Utilitários compartilhados de ingestão.
ingestion/open_meteo/ Código do extractor Open-Meteo.
ingestion/usgs/       Código do extractor de terremotos USGS.
ingestion/bcb/        Código do extractor Banco Central do Brasil SGS.
dbt/                  Projeto dbt Core inicializado com dbt init.
dbt/models/           Modelos Raw source, staging, Silver, intermediate e marts.
docker/               Dockerfiles dos ambientes de execução locais.
k8s/                  Manifests kind, MinIO, Polaris, Airflow, monitoramento e RBAC.
metadata/             Artefatos de pipeline, qualidade, catálogo, Iceberg e freshness.
docs/adr/             Registros de decisões de arquitetura.
docs/runbooks/        Runbooks operacionais.
docs/architecture/    Documentação de arquitetura.
docs/lessons/         Lições guiadas.
docs/troubleshooting/ Documentação de troubleshooting.
```

O scaffold do Airflow é gerenciado com Astro CLI. As dependências do ambiente de
execução Airflow incluem Astronomer Cosmos com o extra dbt DuckDB para que etapas
posteriores possam orquestrar modelos dbt a partir do Airflow sem ligar cada
modelo manualmente como uma task customizada.

## Ordem de Implementação

A fundação lakehouse é implementada antes dos adapters concretos de fonte. A
ordem arquitetural atual é:

```text
MinIO -> Polaris -> Airflow -> dbt + DuckDB + Polaris -> Raw contract
  -> adapters genéricos de fonte -> adapters de APIs públicas -> Silver -> Gold
```

Isso mantém o core lakehouse independente de Open-Meteo, USGS, Banco Central ou
qualquer outra fonte específica. Adapters de fonte escrevem em um contrato Raw
genérico consumido pelo dbt, e a fundação dbt deve compilar com fixtures locais
antes de exigir ingestão real.

## Cluster Kubernetes Local

A etapa 02 provisiona um cluster kind local e o namespace base `data-platform`.
Veja `docs/runbooks/local-kind-cluster.md` para pré-requisitos, comandos de
ciclo de vida e passos de validação.

## Armazenamento de Objetos Local

A etapa 03 sobe MinIO no cluster Kubernetes local e inicializa o bucket
`lakehouse`. Veja `docs/runbooks/minio-object-storage.md` para deploy,
port-forward e convenções de path.

## Catálogo REST Iceberg Local

A etapa 04 sobe Apache Polaris como Iceberg REST Catalog local e inicializa o
catálogo `lakehouse` apoiado no path de warehouse do MinIO. Veja
`docs/runbooks/polaris-rest-catalog.md` para credenciais, deploy, checks de saúde
e convenções de endpoint.

## Orquestração Local com Airflow

A etapa 05 sobe Airflow com o Helm chart do Apache Airflow e valida a criação de
pods via `KubernetesPodOperator` no namespace local `data-platform`. Veja
`docs/runbooks/airflow-kubernetes-pod-operator.md` para build de imagem, deploy,
acesso a UI e validação da DAG de teste de smoke.

A etapa 12 adiciona a DAG principal `open_lakehouse_lab_daily`. Ela executa
workloads dbt em pods Kubernetes efêmeros usando a imagem local `dbt + duckdb` e
mantém o estado do target DuckDB em um PVC local pequeno. Veja
`docs/runbooks/airflow-dbt-orchestration.md` para o fluxo de teste local.

A etapa 14 adiciona DAGs didáticas chamadas `airflow/dags/lab_*.py` para que
usuários explorem funcionalidades do Airflow, como `KubernetesPodOperator`,
params e retries, sem alterar a DAG estável de exemplo.

## Fundação dbt + DuckDB

A etapa 08 configura dbt com DuckDB e prepara pontos de integração com Apache
Polaris e Apache Iceberg sem depender de ingestão de APIs públicas. Veja
`docs/runbooks/dbt-duckdb-polaris.md` para contrato Raw genérico, comandos dbt,
ambiente de execução Docker e limitações conhecidas.

## Camada Silver

A etapa 10 cria modelos dbt Silver genéricos a partir do contrato canônico de
staging. A camada Silver atualmente fornece eventos de fonte deduplicados,
observações de métricas e métricas de freshness por dataset sem depender de
adapters de APIs públicas. Veja `docs/runbooks/silver-layer.md` para execução e
validação.

A etapa 13 conecta a coluna dorsal dbt/DuckDB ao MinIO e Polaris para que o
caminho de exemplo leia Raw Parquet e publique tabelas Iceberg localmente. A
etapa 14 explica esse caminho com documentação guiada e atalhos explicáveis.

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

API de saúde do Polaris:

```bash
make port-forward-polaris
curl -fsS http://localhost:8182/q/health/ready
```

dbt é usado pela CLI e pelos logs do Airflow. DuckDB pode ser aberto com:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

## Verificações de Qualidade para Desenvolvimento

Instale as dependências de desenvolvimento:

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
- validação de manifests Kubernetes com kubeconform, quando `k8s/` existir;
- lint de Dockerfile com Hadolint, quando Dockerfiles existirem;
- checks de segurança com Bandit e Trivy opcional;
- check de estrutura da documentação.
