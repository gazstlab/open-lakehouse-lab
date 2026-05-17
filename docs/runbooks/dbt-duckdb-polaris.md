# Fundação dbt + DuckDB + Polaris

Este runbook descreve a fundação dbt da etapa 08 para o Open Lakehouse Lab.

## Escopo

A etapa 08 configura um projeto dbt que usa DuckDB como engine SQL local e
Apache Polaris como alvo futuro de Iceberg REST Catalog.

O objetivo é tornar a fundação de transformação lakehouse independente da
ingestão. Adapters de fonte podem ser implementados depois, desde que escrevam
dados seguindo o contrato Raw.

Esta etapa valida estrutura do projeto, configuração e compilação. Ela
intencionalmente não exige extractors de APIs públicas nem chamadas externas em
tempo real.

## Contrato Raw

O contrato Raw genérico usa estas colunas técnicas mínimas:

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
- `dataset`: dataset produzido pelo adapter de fonte.
- `ingestion_date`: particao de data associada ao evento landing da Raw.
- `loaded_at`: timestamp em que o evento foi carregado.
- `record_hash`: chave técnica estável do registro Raw.
- `raw_payload`: payload original preservado quando for útil para auditoria ou replay.

O formato Raw canônico atual é Parquet. A etapa 13 escreve e lê a fixture pelo
MinIO; o seed local permanece apenas como fallback de estudo.

## Arquivos

Arquivos principais criados ou atualizados por esta etapa:

```text
dbt/dbt_project.yml
dbt/profiles.yml
dbt/macros/attach_polaris.sql
dbt/macros/materializations/iceberg_table.sql
dbt/seeds/raw_source_events.csv
dbt/models/raw_sources/generic_raw_contract.sql
dbt/models/raw_sources/schema.yml
dbt/models/raw_sources/sources.yml
docker/dbt-duckdb-polaris.Dockerfile
```

## Ambiente local

As configurações locais padrão assumem que MinIO e Polaris estão disponíveis a
partir do host por port-forward:

```bash
export DBT_S3_ENDPOINT="localhost:9000"
export DBT_POLARIS_ENDPOINT="http://localhost:8181/api/catalog"
export DBT_POLARIS_CATALOG_NAME="lakehouse"
export DBT_POLARIS_WAREHOUSE="lakehouse"
export AWS_REGION="us-east-1"
```

Para uma configuração educacional local, as credenciais do MinIO podem ser fornecidas
por variáveis de ambiente:

```bash
export AWS_ACCESS_KEY_ID="<local-minio-access-key>"
export AWS_SECRET_ACCESS_KEY="<local-minio-secret-key>"
```

Não commite credenciais reais.

## Validar o projeto dbt

A partir da raiz do repositório:

```bash
make dbt-parse
make dbt-compile
```

Para publicar a fixture Raw no MinIO e construir o modelo de contrato Raw:

```bash
make dbt-publish-raw-fixture
make dbt-run-foundation
```

## Construir a imagem de execução do dbt

```bash
make build-dbt-image
```

Carregue a imagem no kind:

```bash
make load-dbt-image
```

## Macro Polaris

A macro `attach_polaris_catalog` é intencionalmente isolada. Ela pode ser
reutilizada por stages futuras a partir de:

- `dbt run-operation`;
- hooks dbt;
- materializacoes Iceberg customizadas;
- tasks Airflow executando dbt no Kubernetes.

DuckDB espera o endpoint do Polaris REST Catalog, incluindo `/api/catalog`, e o
nome do catálogo Polaris como valor de warehouse.

## Materialização Iceberg

A materialização inicial `iceberg_table` é deliberadamente conservadora:

- orientada a full-refresh;
- sem `MERGE INTO`;
- sem `UPDATE`;
- sem `DELETE`;
- sem `ALTER TABLE`.

Isso mantém o MVP facil de entender. Stages posteriores podem evoluir esse
comportamento quando existirem saúde de tabelas, coleta de metadados e estratégias
de compactação.

## Limitações conhecidas

- A etapa 08 valida a fundação dbt e o contrato Raw, mas não exige APIs
  públicas.
- Adapters concretos de fonte são implementados depois.
- A etapa 13 completa o caminho de execução MinIO + Polaris. Veja
  `docs/runbooks/dbt-minio-polaris-backbone.md`.
- Rodar contra um catálogo Polaris ativo exige que os serviços da etapa 04
  estejam disponíveis.
