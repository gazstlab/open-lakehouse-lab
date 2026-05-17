# Fontes Raw e staging no dbt

Este runbook descreve a fundacao de fonte Raw e staging da etapa 09.

## Escopo

A etapa 09 faz o dbt ler um contrato Raw generico e criar um modelo inicial de
staging sem depender de APIs publicas, DAGs de ingestao no Airflow ou chamadas
externas de rede.

O formato Raw canonico atual e Parquet. A etapa 13 faz o caminho padrao de
validacao publicar e ler uma fixture Raw Parquet deterministica no MinIO. A
fixture de seed do dbt permanece apenas como fallback local de estudo.

## Layout Raw canonico

Adapters futuros devem escrever registros Raw no MinIO usando esta convencao de
path:

```text
s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet
```

Colunas tecnicas obrigatorias:

```text
source
dataset
ingestion_date
loaded_at
record_hash
raw_payload
```

Responsabilidades:

- `source`: nome logico do adapter de fonte.
- `dataset`: dataset logico produzido pelo adapter de fonte.
- `ingestion_date`: data da particao Raw.
- `loaded_at`: timestamp em que o registro foi carregado na Raw.
- `record_hash`: chave tecnica estavel para deduplicacao e rastreabilidade.
- `raw_payload`: payload original preservado quando for util para auditoria ou replay.

Campos conhecidos e estaveis da fonte devem ser expandidos em colunas Parquet
quando possivel. Outros formatos, como CSV e JSON, podem ser adicionados depois
por adapters de fonte ou macros de leitura DuckDB, mas nao fazem parte do
contrato canonico atual.

## Fixture Raw

A macro `publish_raw_fixture_parquet` escreve arquivos Raw Parquet
deterministicos com campos de exemplo controlados:

```text
observed_at
metric_name
metric_value
location_name
```

Isso permite que o dbt valide casts e testes de staging antes dos adapters reais
existirem.

## Modelos dbt

A etapa 09 introduz:

```text
dbt/models/raw_sources/sources.yml
dbt/models/raw_sources/generic_raw_contract.sql
dbt/models/staging/stg_raw_source_events.sql
dbt/models/staging/schema.yml
```

Convencao de nomes:

- modelos de contrato Raw ficam em `models/raw_sources/`;
- modelos de staging usam o prefixo `stg_`;
- modelos de staging devem normalizar tipos e nomes, mas nao criar tabelas de
  negocio Silver.

## Validar localmente

A partir da raiz do repositorio:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
make dbt-run-staging
make dbt-test
make dbt-parse
make dbt-compile
```

Validacao completa de PR:

```bash
make ci-pr
```

## Limitacoes conhecidas

- Adapters de fontes publicas ainda sao implementados depois.
- Esta etapa nao implementa adapters Python de fonte.
- Esta etapa nao consome Open-Meteo, USGS nem BCB.
- Tabelas Iceberg Silver e Gold sao cobertas pela coluna dorsal da etapa 13.
