# Troubleshooting guiado

Use este guia quando o caminho padrao falhar. A primeira regra e sempre
inspecionar o recurso que acabou de ser criado antes de avancar.

## Cluster kind ja existe

Sintoma:

```text
ERROR: failed to create cluster: node(s) already exist
```

Verifique:

```bash
kind get clusters
kubectl config current-context
```

Recupere:

```bash
make cluster-status
```

Se quiser recomecar do zero:

```bash
make cluster-delete
make cluster-create
```

## Docker nao esta rodando

Sintoma:

```text
Cannot connect to the Docker daemon
```

Verifique:

```bash
docker ps
```

Recupere:

1. abra o Docker Desktop ou inicie o daemon local;
2. rode novamente o comando que falhou;
3. valide com `make cluster-status`.

## UI do MinIO nao abre

Sintoma:

```text
localhost:9001 does not load
```

Verifique:

```bash
make minio-status
```

Recupere:

```bash
make port-forward-minio
```

Abra `http://localhost:9001` em outra aba. Se a porta estiver ocupada, encerre o
processo antigo de port-forward e rode o comando novamente.

## Job da fixture Raw expira por timeout

Sintoma:

```text
timed out waiting for the condition on jobs/dbt-publish-raw-fixture
```

Verifique:

```bash
kubectl -n data-platform get pods -l job-name=dbt-publish-raw-fixture
kubectl -n data-platform logs job/dbt-publish-raw-fixture
kubectl -n data-platform describe job dbt-publish-raw-fixture
```

Causas provaveis:

- a imagem dbt nao foi carregada no kind;
- MinIO ou Polaris ainda nao esta pronto;
- credenciais locais nao batem com o secret esperado;
- alguma extensao DuckDB tentou escrever em um filesystem somente leitura.

Recupere:

```bash
make build-dbt-image
make load-dbt-image
make minio-status
make polaris-health
make publish-raw-fixture-parquet
```

## Health do Polaris esta indisponivel

Sintoma:

```text
curl: (22) The requested URL returned error
```

Verifique:

```bash
make polaris-status
kubectl -n data-platform logs deployment/polaris
kubectl -n data-platform logs job/polaris-bootstrap-catalog
```

Recupere:

```bash
make deploy-polaris
make polaris-health
```

O erro HTTP `409` no job de bootstrap pode ser aceitavel quando o catalogo
`lakehouse` ja existe.

## UI do Airflow retorna erro de CSRF

Sintoma:

```text
Bad Request - The CSRF session token is missing.
```

Verifique:

```bash
make airflow-status
```

Recupere:

1. pare o `make port-forward-airflow`;
2. limpe cookies/sessao de `localhost:8080` ou use janela anonima;
3. rode `make port-forward-airflow`;
4. acesse `http://localhost:8080` novamente.

## Execucao da DAG do Airflow falhou

Verifique as DAG runs:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily
```

Verifique os estados das tasks:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow tasks states-for-dag-run open_lakehouse_lab_daily "<run_id>"
```

Verifique os pods de workload dbt:

```bash
make airflow-dbt-pods
kubectl -n data-platform get pods -l app.kubernetes.io/component=dbt-workload
```

Recuperacoes comuns:

```bash
make build-dbt-image
make load-dbt-image
make deploy-airflow
make trigger-airflow-dbt
```

## Banco DuckDB esta bloqueado

Sintoma:

```text
Could not set lock on file dbt/target/open_lakehouse_lab.duckdb
```

Causa:

Outro processo DuckDB CLI, DuckDB UI ou dbt esta usando o mesmo arquivo.

Recupere:

1. feche a aba DuckDB CLI/UI que esta usando o banco;
2. rode novamente o comando dbt;
3. se precisar inspecionar enquanto o dbt roda, abra uma copia do arquivo.

## Schema DuckDB nao existe

Sintoma:

```text
Catalog or schema does not exist
```

Verifique:

```sql
show schemas;
```

Use o `database_name` e o `schema_name` retornados pelo DuckDB. Se o arquivo foi
anexado como `lab`, consulte com:

```sql
select * from lab.main_raw_sources.generic_raw_contract limit 10;
```

Se o arquivo foi aberto diretamente, isso normalmente basta:

```sql
select * from main_raw_sources.generic_raw_contract limit 10;
```
