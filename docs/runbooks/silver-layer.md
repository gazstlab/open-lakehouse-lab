# Camada Silver

Este runbook descreve a camada Silver genérica da etapa 10 para o Open Lakehouse Lab.

## Escopo

A etapa 10 cria modelos Silver genéricos a partir do contrato canônico de
staging criado na etapa 09.

A camada Silver é intencionalmente agnóstica de fonte. APIs públicas e adapters
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
- permanece genérica entre adapters de fonte.

### `silver_metric_observations`

Tabela analitica de observações numericas.

Regras:

- uma linha por `observation_id` estável;
- exige `metric_name`, `metric_value` e `observed_at`;
- mantém `record_hash` para rastreabilidade até o evento de origem.

### `silver_dataset_freshness`

Tabela de freshness e volume por dataset.

Métricas:

- último timestamp observado;
- último timestamp carregado;
- primeira e última data de ingestão;
- total de registros;
- hashes de registros unicos.

## Rodar localmente

A partir da raiz do repositório, rode o caminho MinIO/Polaris da etapa 13:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
make dbt-run-staging
make dbt-run-silver
make dbt-test-silver
```

Validação geral:

```bash
make lint-dbt
make dbt-parse
make dbt-compile
make dbt-test
make ci-pr
```

## Decisões de design

- Silver é genérica primeiro; modelos específicos de fonte ficam para quando
  adapters reais existirem.
- A deduplicação usa `record_hash`, que é a chave técnica estável do contrato
  Raw/Staging.
- A etapa 13 publica Silver como tabelas Iceberg pela materialização customizada
  `iceberg_table`.

## Limitações conhecidas

- A etapa 10 não consome APIs públicas diretamente.
- A etapa 10 não exige imagens de execução de adapters de fonte.
- A etapa 10 não validou tabelas dentro do Polaris como snapshots Iceberg
  fisicos; a etapa 13 adiciona essa coluna dorsal.
