# Open Lakehouse Lab - Project Plan

## Visao geral

O **Open Lakehouse Lab** e um projeto de estudo 100% open source para demonstrar uma arquitetura lakehouse moderna executada localmente, sem dependencia de servicos cloud pagos.

A proposta e criar um laboratorio compartilhavel para estudar engenharia de dados moderna com Kubernetes, Airflow, MinIO, Apache Iceberg, Apache Polaris, DuckDB, dbt, Prometheus e Grafana.

## Objetivos

- Construir uma arquitetura lakehouse local e open source.
- Usar `kind` como cluster Kubernetes local.
- Usar Airflow para orquestracao.
- Executar tarefas em pods via `KubernetesPodOperator`.
- Usar MinIO como object storage compativel com S3.
- Usar Apache Iceberg como formato das tabelas Silver e Gold.
- Usar Apache Polaris como Iceberg REST Catalog.
- Usar DuckDB como engine SQL local.
- Usar dbt-duckdb para transformar Raw em Silver e Silver em Gold.
- Consumir APIs publicas com atualizacao diaria ou superior.
- Usar Prometheus para coleta de metricas operacionais.
- Usar Grafana para paineis de observabilidade da infraestrutura e dos pipelines.
- Documentar a arquitetura, os contratos de dados, os runbooks e as decisoes tecnicas.

## Stack principal

| Camada | Tecnologia |
|---|---|
| Kubernetes local | kind |
| Orquestracao | Apache Airflow |
| Execucao | KubernetesPodOperator |
| Object storage | MinIO |
| Table format | Apache Iceberg |
| Catalogo Iceberg | Apache Polaris |
| Engine SQL | DuckDB |
| Transformacao | dbt-duckdb |
| Ingestao | Python |
| Metricas | Prometheus |
| Observabilidade operacional | Grafana |
| Estado do Kubernetes | kube-state-metrics |
| Metricas dos nos | Node Exporter |
| Metricas do Airflow | StatsD Exporter |
| Documentacao | Markdown |

## Arquitetura

```text
Public APIs
  -> Airflow DAG
  -> KubernetesPodOperator
  -> Python Extractor Pods
  -> MinIO Raw Zone
  -> dbt-duckdb Pod
  -> DuckDB Iceberg Extension
  -> Apache Polaris REST Catalog
  -> Silver Iceberg Tables
  -> dbt-duckdb Pod
  -> Gold Iceberg Tables
  -> Metadata Collection
  -> Prometheus Metrics
  -> Grafana Operational Panels
  -> Documentation Artifacts
```

## Camadas do lakehouse

### Raw

A Raw armazena os dados brutos exatamente como vieram das APIs publicas.

Exemplo:

```text
s3://lakehouse/raw/source=open_meteo/ingestion_date=YYYY-MM-DD/data.json
s3://lakehouse/raw/source=usgs/ingestion_date=YYYY-MM-DD/data.json
s3://lakehouse/raw/source=bcb/ingestion_date=YYYY-MM-DD/data.json
```

### Silver

A Silver sera criada com dbt + DuckDB lendo a Raw e escrevendo tabelas Apache Iceberg via Polaris.

Tabelas iniciais:

```text
silver.weather_hourly
silver.earthquake_events
silver.macro_indicators
silver.pipeline_runs
silver.data_quality_results
```

Responsabilidades:

- flatten de JSON;
- cast de tipos;
- normalizacao de timestamps;
- padronizacao de nomes;
- deduplicacao;
- validacoes basicas;
- publicacao como Iceberg.

### Gold

A Gold tambem sera criada com dbt + DuckDB, a partir da Silver Iceberg.

Tabelas iniciais:

```text
gold.environment_city_daily
gold.earthquake_summary_daily
gold.macro_indicators_daily
gold.pipeline_health_daily
```

Responsabilidades:

- agregacoes analiticas;
- metricas consolidadas para consumo por consultas;
- modelos finais de estudo;
- testes dbt;
- suporte a exploracao tecnica via DuckDB, Polaris e metadados Iceberg.

## Fontes publicas iniciais

### Open-Meteo

Dados de clima, temperatura, vento, chuva e previsao.

### USGS Earthquakes

Dados de terremotos, magnitude, profundidade, latitude, longitude e horario do evento.

### Banco Central do Brasil - SGS

Series temporais economicas e financeiras publicas.

## dbt + DuckDB + Polaris

O projeto usara o caminho mais avancado:

```text
dbt-duckdb
  -> DuckDB Iceberg Extension
  -> Apache Polaris REST Catalog
  -> Silver e Gold Iceberg Tables
```

O dbt sera responsavel por toda a modelagem estruturada:

```text
raw_sources
  -> staging
  -> silver
  -> intermediate
  -> marts
```

Na primeira versao, sera usada uma estrategia de full refresh idempotente. O MVP deve evitar `MERGE INTO`, `ALTER TABLE`, `UPDATE` e `DELETE` em tabelas Iceberg.

## Estrutura sugerida

```text
open-lakehouse-lab/
├── airflow/dags/
├── ingestion/
├── dbt/
│   ├── models/raw_sources/
│   ├── models/staging/
│   ├── models/silver/
│   ├── models/intermediate/
│   ├── models/marts/
│   └── macros/
├── docker/
├── k8s/
│   ├── kind/
│   ├── minio/
│   ├── polaris/
│   ├── airflow/
│   ├── monitoring/
│   └── rbac/
├── metadata/
├── docs/
└── Makefile
```

## DAG principal

Nome sugerido:

```text
open_lakehouse_lab_daily
```

Fluxo:

```text
start
  -> extract_open_meteo
  -> extract_usgs
  -> extract_bcb
  -> dbt_run_staging_silver
  -> dbt_test_silver
  -> dbt_run_intermediate_gold
  -> dbt_test_gold
  -> collect_iceberg_metadata
  -> update_data_catalog
  -> publish_pipeline_metrics
  -> end
```

## Observabilidade e catalogacao

Metadados a serem coletados:

- status de execucao por fonte;
- duracao das tasks;
- registros ingeridos;
- registros rejeitados;
- freshness por dataset;
- snapshots Iceberg;
- qualidade por camada;
- catalogo de dados;
- schemas das tabelas;
- localizacao fisica das tabelas no MinIO;
- historico de execucoes da DAG.

Artefatos sugeridos:

```text
metadata/pipeline-runs/
metadata/data-quality-results/
metadata/data-catalog/
metadata/iceberg-snapshots/
metadata/source-freshness/
```

## Observabilidade com Prometheus e Grafana

O projeto deve incluir uma stack de observabilidade operacional para monitorar a infraestrutura local e os pipelines.

Componentes:

- Prometheus;
- Grafana;
- kube-state-metrics;
- Node Exporter;
- StatsD Exporter;
- ServiceMonitors, quando aplicavel.

Instalacao recomendada:

```text
kube-prometheus-stack via Helm
```

Metricas do Kubernetes:

- pods em execucao;
- pods com falha;
- restarts de containers;
- uso de CPU;
- uso de memoria;
- uso por namespace;
- status dos deployments e statefulsets.

Metricas do Airflow:

- DAG runs;
- task duration;
- task failures;
- scheduler heartbeat;
- numero de tasks em sucesso, falha e retry.

Metricas dos pipelines:

- registros ingeridos por fonte;
- registros rejeitados;
- duracao por etapa;
- freshness por dataset;
- status da ultima execucao;
- quantidade de snapshots Iceberg gerados.

Metricas do MinIO e Polaris:

- disponibilidade dos servicos;
- uso de storage;
- quantidade de objetos;
- latencia ou erros, quando expostos;
- saude do catalogo Polaris.

Estrutura sugerida:

```text
k8s/monitoring/
├── values.yaml
├── servicemonitors/
├── prometheus-rules/
└── grafana-panels/
```

Comandos sugeridos no Makefile:

```text
deploy-monitoring
port-forward-prometheus
port-forward-grafana
```

## Documentacao obrigatoria

### ADRs

```text
001-open-source-stack.md
002-local-kubernetes-with-kind.md
003-minio-as-object-storage.md
004-apache-polaris-rest-catalog.md
005-apache-iceberg-table-format.md
006-duckdb-as-local-sql-engine.md
007-dbt-duckdb-for-raw-to-gold.md
008-custom-dbt-iceberg-materialization.md
009-full-refresh-strategy.md
010-operational-observability-with-prometheus-grafana.md
```

### Runbooks

```text
reprocess-a-date.md
investigate-dag-failure.md
rebuild-silver-layer.md
rebuild-gold-layer.md
inspect-iceberg-snapshots.md
reset-local-environment.md
validate-data-quality.md
investigate-prometheus-target-down.md
investigate-airflow-metric-failure.md
```

## Fases de implementacao

### Fase 1 - Fundacao

- Criar cluster kind.
- Criar namespace `data-platform`.
- Subir MinIO.
- Subir Polaris.
- Subir Airflow.
- Configurar RBAC.
- Validar DAG hello-world com `KubernetesPodOperator`.

### Fase 2 - Raw

- Criar extratores Python.
- Gravar dados brutos no MinIO.
- Registrar metadados de ingestao.

### Fase 3 - dbt + DuckDB + Polaris

- Criar projeto dbt.
- Configurar DuckDB com `httpfs`, `parquet` e `iceberg`.
- Criar macro para anexar Polaris.
- Criar materializacao customizada `iceberg_table`.

### Fase 4 - Silver Iceberg

- Criar staging models.
- Criar modelos Silver.
- Aplicar deduplicacao.
- Aplicar testes dbt.
- Publicar Silver como Iceberg.

### Fase 5 - Gold Iceberg

- Criar modelos intermediate.
- Criar marts Gold.
- Aplicar testes dbt.
- Publicar Gold como Iceberg.

### Fase 6 - Observabilidade e catalogacao

- Coletar metadados de execucao.
- Coletar snapshots Iceberg.
- Gerar data catalog.
- Registrar freshness por fonte.
- Registrar resultados de qualidade.
- Documentar exemplos de consultas tecnicas.

### Fase 7 - Prometheus e Grafana

- Instalar kube-prometheus-stack.
- Configurar Prometheus.
- Configurar Grafana.
- Configurar kube-state-metrics.
- Configurar Node Exporter.
- Configurar StatsD Exporter para metricas do Airflow.
- Criar paineis operacionais para Kubernetes, Airflow, MinIO, Polaris e pipelines.
- Criar regras de alerta para falhas criticas.

### Fase 8 - Documentacao

- Completar README.
- Criar ADRs.
- Criar runbooks.
- Criar contratos de dados.
- Adicionar diagramas de arquitetura.
- Documentar limitacoes e proximos passos.

## Limitacoes conhecidas

- O projeto e um laboratorio local, nao uma plataforma de producao.
- O MVP usara full refresh, nao merge incremental.
- Mudancas de schema serao tratadas por recriacao controlada da tabela.
- MinIO sera usado como object storage local para estudo.
- Prometheus e Grafana serao usados para observabilidade operacional local.

## Evolucoes futuras

- Adicionar GDELT.
- Adicionar manutencao e compactacao Iceberg.
- Adicionar exemplos de time travel.
- Adicionar Spark como engine complementar.
- Adicionar Trino para consulta multi-engine.
- Adicionar OpenLineage ou Marquez.
- Expandir Prometheus e Grafana com alertas e SLOs.

## Mensagem central

O **Open Lakehouse Lab** demonstra como estudar e construir uma arquitetura lakehouse moderna, 100% open source, usando:

```text
Kubernetes + Airflow + MinIO + Apache Iceberg + Polaris + DuckDB + dbt + Prometheus + Grafana
```

A arquitetura foi pensada para ser executada localmente, sem custo cloud, e servir como base educacional para evolucao futura para stacks em nuvem.
