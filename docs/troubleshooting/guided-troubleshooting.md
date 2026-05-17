# Troubleshooting guiado

Use este guia quando o caminho padrão falhar. A primeira regra é sempre
inspecionar o recurso que acabou de ser criado antes de avancar.

## Cluster kind já existe

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

Se quiser recomeçar do zero:

```bash
make cluster-delete
make cluster-create
```

## Docker não está rodando

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

## UI do MinIO não abre

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

- a imagem dbt não foi carregada no kind;
- MinIO ou Polaris ainda não está pronto;
- credenciais locais não batem com o secret esperado;
- alguma extensao DuckDB tentou escrever em um filesystem somente leitura.

Recupere:

```bash
make build-dbt-image
make load-dbt-image
make minio-status
make polaris-health
make publish-raw-fixture-parquet
```

## Health do Polaris está indisponível

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

O erro HTTP `409` no job de bootstrap pode ser aceitável quando o catálogo
`lakehouse` já existe.

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
2. limpe cookies/sessão de `localhost:8080` ou use janela anônima;
3. rode `make port-forward-airflow`;
4. acesse `http://localhost:8080` novamente.

## Execução da DAG do Airflow falhou

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

## Banco DuckDB está bloqueado

Sintoma:

```text
Could not set lock on file dbt/target/open_lakehouse_lab.duckdb
```

Causa:

Outro processo DuckDB CLI, DuckDB UI ou dbt está usando o mesmo arquivo.

Recupere:

1. feche a aba DuckDB CLI/UI que está usando o banco;
2. rode novamente o comando dbt;
3. se precisar inspecionar enquanto o dbt roda, abra uma copia do arquivo.

## Schema DuckDB não existe

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
