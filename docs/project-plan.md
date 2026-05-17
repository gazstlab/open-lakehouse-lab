# Open Lakehouse Lab - Plano do Projeto

## Visão geral

O **Open Lakehouse Lab** é um projeto de estudo 100% open source para demonstrar uma arquitetura lakehouse moderna executada localmente, sem dependência de serviços cloud pagos.

A proposta é criar um laboratório compartilhável para estudar engenharia de dados moderna com Kubernetes, Airflow, MinIO, Apache Iceberg, Apache Polaris, DuckDB, dbt, Prometheus e Grafana.

## Objetivos

- Construir uma arquitetura lakehouse local e open source.
- Usar `kind` como cluster Kubernetes local.
- Usar Airflow para orquestração.
- Executar tarefas em pods via `KubernetesPodOperator`.
- Usar MinIO como armazenamento de objetos compatível com S3.
- Usar Apache Iceberg como formato das tabelas Silver e Gold.
- Usar Apache Polaris como Iceberg REST Catalog.
- Usar DuckDB como engine SQL local.
- Usar dbt-duckdb para transformar Raw em Silver e Silver em Gold.
- Definir a fundação dbt + DuckDB + Polaris antes das fontes concretas.
- Consumir APIs públicas com atualizacao diaria ou superior como adapters plugáveis.
- Usar Prometheus para coleta de métricas operacionais.
- Usar Grafana para painéis de observabilidade da infraestrutura e dos pipelines.
- Documentar a arquitetura, os contratos de dados, os runbooks e as decisões técnicas.

## Stack principal

| Camada | Tecnologia |
|---|---|
| Kubernetes local | kind |
| Orquestração | Apache Airflow |
| Execução | KubernetesPodOperator |
| Object storage | MinIO |
| Table format | Apache Iceberg |
| Catálogo Iceberg | Apache Polaris |
| Engine SQL | DuckDB |
| Transformação | dbt-duckdb |
| Contrato Raw | Parquet canônico com caminhos e schemas genéricos consumidos pelo dbt |
| Ingestao | Adapters de fonte Python plugáveis |
| Métricas | Prometheus |
| Observabilidade operacional | Grafana |
| Estado do Kubernetes | kube-state-metrics |
| Métricas dos nós | Node Exporter |
| Métricas do Airflow | StatsD Exporter |
| Documentação | Markdown |

## Arquitetura

```text
Adapters de fonte
  -> API HTTP, arquivo local, fixture, armazenamento de objetos ou futuras fontes batch/stream
  -> Airflow DAG
  -> KubernetesPodOperator
  -> Source Adapter Pods
  -> MinIO Raw Zone contract em Parquet canônico
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

A Raw armazena uma versão canônica e tabular dos dados brutos em Parquet, sem
acoplar o core lakehouse a um tipo específico de origem.

O contrato Raw deve ser definido antes dos adapters concretos. Assim, o dbt pode
compilar e validar a fundação lakehouse com fixtures locais, enquanto APIs
públicas entram depois como uma implementação de fonte.

Formato canônico atual:

```text
s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
```

Colunas técnicas mínimas:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
```

`raw_payload` preserva o conteúdo original quando isso for útil para auditoria,
reprocessamento ou estudo. Campos conhecidos e estáveis da fonte devem ser
gravados como colunas do Parquet sempre que possível. Formatos como CSV e JSON
podem ser adicionados posteriormente por adapters ou macros de leitura DuckDB,
mas não fazem parte do contrato canônico inicial.

### Silver

A Silver será criada com dbt + DuckDB lendo a Raw e escrevendo tabelas Apache Iceberg via Polaris.

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
- deduplicação;
- validacoes basicas;
- publicação como Iceberg.

### Gold

A Gold também será criada com dbt + DuckDB, a partir da Silver Iceberg.

Tabelas iniciais:

```text
gold.environment_city_daily
gold.earthquake_summary_daily
gold.macro_indicators_daily
gold.pipeline_health_daily
```

Responsabilidades:

- agregacoes analiticas;
- métricas consolidadas para consumo por consultas;
- modelos finais de estudo;
- testes dbt;
- suporte a exploração técnica via DuckDB, Polaris e metadados Iceberg.

## Adaptadores de fonte

Adapters de fonte são uma camada plugavel acima do contrato Raw.

Tipos de fonte previstos:

- API HTTP;
- arquivo local;
- fixture determinística para testes;
- armazenamento de objetos;
- futuras fontes batch ou stream.

As fontes públicas iniciais continuam fazendo parte do MVP, mas não devem ser
pre-requisito para criar a fundação dbt + DuckDB + Polaris.

## Fontes públicas iniciais

### Open-Meteo

Dados de clima, temperatura, vento, chuva e previsão.

### USGS Terremotos

Dados de terremotos, magnitude, profundidade, latitude, longitude e horário do evento.

### Banco Central do Brasil - SGS

Séries temporais econômicas e financeiras públicas.

## dbt + DuckDB + Polaris

O projeto usara o caminho mais avancado como fundação lakehouse desacoplada de
ingestão:

```text
dbt-duckdb
  -> DuckDB Iceberg Extension
  -> Apache Polaris REST Catalog
  -> Silver e Gold Iceberg Tables
```

O dbt será responsavel por toda a modelagem estruturada:

```text
raw_sources
  -> staging
  -> silver
  -> intermediate
  -> marts
```

`raw_sources` deve representar o contrato Raw genérico em Parquet, não uma lista
fixa de APIs. As primeiras validacoes técnicas devem funcionar com fixture local
para que `dbt parse` e `dbt compile` não dependam de extractors Python, Airflow
DAGs de ingestão ou disponibilidade externa de APIs.

Na primeira versão, será usada uma estratégia de full refresh idempotente. O MVP deve evitar `MERGE INTO`, `ALTER TABLE`, `UPDATE` e `DELETE` em tabelas Iceberg.

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
  -> source_adapter_tasks
  -> dbt_run_staging_silver
  -> dbt_test_silver
  -> dbt_run_intermediate_gold
  -> dbt_test_gold
  -> collect_iceberg_metadata
  -> update_data_catalog
  -> publish_pipeline_metrics
  -> end
```

## Observabilidade e catalogação

Metadados a serem coletados:

- status de execução por fonte;
- duracao das tasks;
- registros ingeridos;
- registros rejeitados;
- freshness por dataset;
- snapshots Iceberg;
- qualidade por camada;
- catálogo de dados;
- schemas das tabelas;
- localização física das tabelas no MinIO;
- historico de execuções da DAG.

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
- ServiceMonitors, quando aplicável.

Instalacao recomendada:

```text
kube-prometheus-stack via Helm
```

Métricas do Kubernetes:

- pods em execução;
- pods com falha;
- restarts de containers;
- uso de CPU;
- uso de memória;
- uso por namespace;
- status dos deployments e statefulsets.

Métricas do Airflow:

- DAG runs;
- task duration;
- task failures;
- scheduler heartbeat;
- número de tasks em sucesso, falha e retry.

Métricas dos pipelines:

- registros ingeridos por fonte;
- registros rejeitados;
- duracao por etapa;
- freshness por dataset;
- status da última execução;
- quantidade de snapshots Iceberg gerados.

Métricas do MinIO e Polaris:

- disponibilidade dos serviços;
- uso de storage;
- quantidade de objetos;
- latencia ou erros, quando expostos;
- saúde do catálogo Polaris.

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

## Documentação obrigatoria

### Trilha de aprendizado

```text
learning-path.md
user-customization-guide.md
lessons/01-local-kubernetes-kind.md
lessons/02-minio-raw-storage.md
lessons/03-polaris-iceberg-catalog.md
lessons/04-dbt-duckdb-transformations.md
lessons/05-airflow-kubernetes-pods.md
lessons/06-end-to-end-pipeline.md
troubleshooting/guided-troubleshooting.md
```

O projeto deve manter dois modos de uso:

- Caminho Rápido: atalhos `make` executam o caminho padrão rapidamente.
- Trilha de Aprendizado: as mesmas etapas são explicadas como lições reproduziveis.

Atalhos importantes devem imprimir objetivo, motivo, comandos executados,
inspeções recomendadas e próximo passo.

### Registros de decisão de arquitetura

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

### Runbooks operacionais

```text
reprocess-a-date.md
investigate-dag-failure.md
airflow-dbt-orchestration.md
rebuild-silver-layer.md
rebuild-gold-layer.md
inspect-iceberg-snapshots.md
reset-local-environment.md
validate-data-quality.md
investigate-prometheus-target-down.md
investigate-airflow-metric-failure.md
```

## Fases de implementação

### Fase 1 - Fundação

- Criar cluster kind.
- Criar namespace `data-platform`.
- Subir MinIO.
- Subir Polaris.
- Subir Airflow.
- Configurar RBAC.
- Validar DAG hello-world com `KubernetesPodOperator`.

### Fase 2 - dbt + DuckDB + Polaris

- Criar projeto dbt.
- Configurar DuckDB com `httpfs`, `iceberg` e suporte nativo a Parquet.
- Criar macro para anexar Polaris.
- Criar materialização customizada `iceberg_table`.
- Criar contrato Raw genérico em Parquet consumido pelo dbt.
- Criar fixture local mínima para validação sem ingestão.

### Fase 3 - Raw plugavel

- Criar ambiente de execução genérico de adapters de fonte.
- Criar abstracoes comuns para adapters de fonte.
- Criar adapter de fixture/arquivo local para testes sem rede externa.
- Gravar dados brutos no MinIO seguindo o contrato Raw canônico em Parquet.
- Registrar metadados de ingestão.

### Fase 4 - Fontes públicas

- Implementar adapters Open-Meteo, USGS e Banco Central SGS.
- Criar tasks Airflow para cada adapter.
- Garantir que testes rápidos usem fixtures e não dependam de APIs reais.

### Fase 5 - Silver Iceberg

- Criar staging models.
- Criar modelos Silver.
- Aplicar deduplicação.
- Aplicar testes dbt.
- Publicar Silver como Iceberg.

### Fase 6 - Gold Iceberg

- Criar modelos intermediate.
- Criar marts Gold.
- Aplicar testes dbt.
- Publicar Gold como Iceberg.

### Fase 7 - Orquestração dbt no Airflow

- Criar DAG principal `open_lakehouse_lab_daily`.
- Executar comandos dbt em pods efêmeros via `KubernetesPodOperator`.
- Usar a imagem local `dbt + duckdb` carregada no kind.
- Validar logs, remoção dos pods e acionamento pela Airflow UI.
- Manter a orquestração desacoplada dos adapters concretos de ingestão.

### Fase 8 - Plataforma de estudo guiado

- Criar Caminho Rápido para executar o exemplo padrão.
- Criar Trilha de Aprendizado com lições incrementais.
- Tornar atalhos `make` explicativos.
- Documentar comandos manuais equivalentes.
- Documentar como customizar dados Raw, modelos dbt e DAGs Airflow.
- Criar DAGs didáticas para explorar Airflow sem alterar a DAG principal.

### Fase 9 - Observabilidade e catalogação

- Coletar metadados de execução.
- Coletar snapshots Iceberg.
- Gerar data catalog.
- Registrar freshness por fonte.
- Registrar resultados de qualidade.
- Documentar exemplos de consultas técnicas.

### Fase 10 - Prometheus e Grafana

- Instalar kube-prometheus-stack.
- Configurar Prometheus.
- Configurar Grafana.
- Configurar kube-state-metrics.
- Configurar Node Exporter.
- Configurar StatsD Exporter para métricas do Airflow.
- Criar painéis operacionais para Kubernetes, Airflow, MinIO, Polaris e pipelines.
- Criar regras de alerta para falhas criticas.

### Fase 11 - Documentação

- Completar README.
- Criar ADRs.
- Criar runbooks.
- Criar contratos de dados.
- Adicionar diagramas de arquitetura.
- Documentar limitações e próximos passos.

## Limitações conhecidas

- O projeto é um laboratório local, não uma plataforma de produção.
- O MVP usara full refresh, não merge incremental.
- Mudancas de schema serão tratadas por recriacao controlada da tabela.
- MinIO será usado como armazenamento de objetos local para estudo.
- Prometheus e Grafana serão usados para observabilidade operacional local.

## Evolucoes futuras

- Adicionar GDELT.
- Adicionar manutenção e compactação Iceberg.
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

A arquitetura foi pensada para ser executada localmente, sem custo cloud, e servir como base educacional para evolução futura para stacks em nuvem.
