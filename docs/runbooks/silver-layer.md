# Camada Silver

Este runbook descreve a camada Silver generica da etapa 10 para o Open Lakehouse Lab.

## Escopo

A etapa 10 cria modelos Silver genericos a partir do contrato canonico de
staging criado na etapa 09.

A camada Silver e intencionalmente agnostica de fonte. APIs publicas e adapters
futuros devem escrever no contrato Raw e passar por staging antes de chegar a
esses modelos Silver.

## Modelo de entrada

Os modelos Silver leem de:

```text
dbt/models/staging/stg_raw_source_events.sql
```

Colunas esperadas de staging:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
observed_at
metric_name
metric_value
location_name
```

## Modelos Silver

### `silver_source_events`

Tabela de eventos de fonte deduplicados.

Regras:

- uma linha por `record_hash`;
- o registro mais recente vence por `loaded_at desc, observed_at desc`;
- preserva `raw_payload` para auditoria e replay;
- permanece generica entre adapters de fonte.

### `silver_metric_observations`

Tabela analitica de observacoes numericas.

Regras:

- uma linha por `observation_id` estavel;
- exige `metric_name`, `metric_value` e `observed_at`;
- mantem `record_hash` para rastreabilidade ate o evento de origem.

### `silver_dataset_freshness`

Tabela de freshness e volume por dataset.

Metricas:

- ultimo timestamp observado;
- ultimo timestamp carregado;
- primeira e ultima data de ingestao;
- total de registros;
- hashes de registros unicos.

## Rodar localmente

A partir da raiz do repositorio, rode o caminho MinIO/Polaris da etapa 13:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
make dbt-run-staging
make dbt-run-silver
make dbt-test-silver
```

Validacao geral:

```bash
make lint-dbt
make dbt-parse
make dbt-compile
make dbt-test
make ci-pr
```

## Decisoes de design

- Silver e generica primeiro; modelos especificos de fonte ficam para quando
  adapters reais existirem.
- A deduplicacao usa `record_hash`, que e a chave tecnica estavel do contrato
  Raw/Staging.
- A etapa 13 publica Silver como tabelas Iceberg pela materializacao customizada
  `iceberg_table`.

## Limitacoes conhecidas

- A etapa 10 nao consome APIs publicas diretamente.
- A etapa 10 nao exige imagens de execucao de adapters de fonte.
- A etapa 10 nao validou tabelas dentro do Polaris como snapshots Iceberg
  fisicos; a etapa 13 adiciona essa coluna dorsal.
