# Open Lakehouse Lab - Project Plan

## Visao geral

O **Open Lakehouse Lab** e um projeto de estudo 100% open source para demonstrar uma arquitetura lakehouse moderna executada localmente, sem dependencia de servicos cloud pagos.

A proposta e criar um laboratorio compartilhavel para estudar engenharia de dados moderna com Kubernetes, Airflow, MinIO, Apache Iceberg, Apache Polaris, DuckDB e dbt.

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
- Criar dashboards visuais para demonstracao educacional.

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
| Dashboard | Next.js |

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
  -> Dashboard Publisher
  -> Next.js Dashboard
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
- metricas para dashboards;
- modelos finais de consumo;
- testes dbt;
- exposicao para o site.

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
├── apps/website/
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
  -> export_dashboard_json
  -> collect_iceberg_metadata
  -> end
```

## Dashboards educacionais

Paginas sugeridas:

```text
Home
Architecture
Lakehouse Layers
Iceberg Catalog Explorer
Snapshot Timeline
Pipeline Monitor
Data Catalog
Climate Dashboard
Earthquake Dashboard
Macro Indicators Dashboard
dbt Lineage
Technical Decisions
```

## Observabilidade

Metadados a serem coletados:

- status de execucao por fonte;
- duracao das tasks;
- registros ingeridos;
- registros rejeitados;
- freshness por dataset;
- snapshots Iceberg;
- qualidade por camada;
- catalogo de dados.

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
010-educational-dashboard-experience.md
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

### Fase 6 - Dashboard

- Criar site Next.js.
- Criar Architecture Explorer.
- Criar Iceberg Catalog Explorer.
- Criar Snapshot Timeline.
- Criar dashboards de clima, terremotos e indicadores macro.

### Fase 7 - Documentacao

- Completar README.
- Criar ADRs.
- Criar runbooks.
- Criar contratos de dados.
- Adicionar screenshots e diagramas.

## Limitacoes conhecidas

- O projeto e um laboratorio local, nao uma plataforma de producao.
- O MVP usara full refresh, nao merge incremental.
- Mudancas de schema serao tratadas por recriacao controlada da tabela.
- MinIO sera usado como object storage local para estudo.

## Evolucoes futuras

- Adicionar GDELT.
- Adicionar manutencao e compactacao Iceberg.
- Adicionar time travel visual.
- Adicionar Spark como engine complementar.
- Adicionar Trino para consulta multi-engine.
- Adicionar OpenLineage ou Marquez.
- Adicionar Prometheus e Grafana.

## Mensagem central

O **Open Lakehouse Lab** demonstra como estudar e construir uma arquitetura lakehouse moderna, 100% open source, usando:

```text
Kubernetes + Airflow + MinIO + Apache Iceberg + Polaris + DuckDB + dbt
```

A arquitetura foi pensada para ser executada localmente, sem custo cloud, e servir como base educacional para evolucao futura para stacks em nuvem.