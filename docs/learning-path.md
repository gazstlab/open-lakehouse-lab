# Trilha de aprendizado guiada

Open Lakehouse Lab tem dois modos de uso complementares.

## Exemplos

Use os Exemplos quando quiser subir o exemplo padrão rapidamente e validar
se a coluna dorsal do laboratório funciona.

```bash
make example
```

Esse alvo executa, em ordem:

1. cria o cluster kind e o namespace `data-platform`;
2. sobe MinIO e cria o bucket `lakehouse`;
3. constrói e carrega a imagem `dbt + DuckDB + Polaris` no kind;
4. sobe Polaris e cria o catálogo Iceberg `lakehouse`;
5. publica fixtures Raw em Parquet no MinIO;
6. constrói e carrega a imagem local do Airflow;
7. sobe Airflow via Helm;
8. dispara a DAG `open_lakehouse_lab_daily`.

Cada etapa imprime logs no formato:

```text
[goal] objetivo do passo
[why] motivo arquitetural
[run] comandos executados ou equivalentes
[inspect] comandos para inspecionar o resultado
[next] próximo passo recomendado
```

Os Exemplos usam credenciais locais padrão para Polaris e MinIO:

```text
POLARIS_ROOT_CLIENT_ID=root
POLARIS_ROOT_CLIENT_SECRET=local-polaris-secret
POLARIS_MINIO_ACCESS_KEY=minioadmin
POLARIS_MINIO_SECRET_KEY=minioadmin123
```

Esses valores são apenas para desenvolvimento local. Você pode sobrescreve-los
no shell antes de executar `make deploy-polaris`.

## Trilha de Aprendizado

Use a Trilha de Aprendizado quando quiser entender e reproduzir manualmente o
que cada atalho faz.

```bash
make lab-learning-path
```

O comando lista a trilha oficial. Siga os arquivos em ordem:

| Lição | Tema |
|---|---|
| `docs/lessons/01-local-kubernetes-kind.md` | Cluster kind local |
| `docs/lessons/02-minio-raw-storage.md` | MinIO e Raw Parquet |
| `docs/lessons/03-polaris-iceberg-catalog.md` | Polaris e catálogo Iceberg |
| `docs/lessons/04-dbt-duckdb-transformations.md` | dbt + DuckDB |
| `docs/lessons/05-airflow-kubernetes-pods.md` | Airflow e pods Kubernetes |
| `docs/lessons/06-end-to-end-pipeline.md` | Pipeline ponta a ponta |

Cada lição mostra:

- o atalho `make` equivalente;
- os comandos manuais principais;
- como validar pelo terminal;
- quais telas podem ser abertas;
- quais arquivos editar para experimentar.

## Comandos de Explicacao

Os comandos `explain-*` não alteram o ambiente. Eles mostram o objetivo, a razao
e os comandos relacionados a uma etapa.

```bash
make explain-cluster
make explain-deploy-minio
make explain-deploy-polaris
make explain-deploy-airflow
make explain-dbt-orchestration
make explain-publish-raw-fixture
```

Use esses comandos antes de executar uma etapa manualmente.

## Interfaces Acessiveis

Depois que os serviços estiverem implantados, abra as interfaces com
port-forward.

MinIO:

```bash
make port-forward-minio
```

Abra `http://localhost:9001` e use:

```text
usuário: minioadmin
senha: minioadmin123
```

Airflow:

```bash
make port-forward-airflow
```

Abra `http://localhost:8080` e use:

```text
usuário: admin
senha: admin
```

Polaris não tem uma interface web usada pelo laboratório nesta etapa. Valide a
API de saúde:

```bash
make port-forward-polaris
curl -fsS http://localhost:8182/q/health/ready
```

dbt também não tem UI neste projeto. Ele é explorado pela CLI, pelos logs do
Airflow e pelas tabelas consultadas via DuckDB.

## Validação Rapida

Com o cluster de pe, valide os componentes principais:

```bash
make cluster-status
make minio-status
make polaris-health
make airflow-status
```

Depois de publicar a fixture Raw:

```bash
kubectl -n data-platform logs job/dbt-publish-raw-fixture
kubectl -n data-platform run minio-list --rm -i --restart=Never \
  --image=minio/mc:RELEASE.2025-04-16T18-13-26Z \
  -- sh -c 'mc alias set local http://minio:9000 minioadmin minioadmin123 && mc find local/lakehouse/raw'
```

Depois de disparar a DAG principal:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags list-runs open_lakehouse_lab_daily

kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow tasks states-for-dag-run open_lakehouse_lab_daily "<run_id>"
```

Substitua `<run_id>` pelo valor retornado em `list-runs`.

## Consulta SQL Local

O DuckDB é usado como engine de transformação. Para explorar o banco local criado
por dbt:

```bash
duckdb dbt/target/open_lakehouse_lab.duckdb
```

Dentro do DuckDB:

```sql
show schemas;
select * from main_raw_sources.generic_raw_contract limit 10;
select * from main_staging.stg_raw_source_events limit 10;
```

Se você anexar o arquivo com outro nome de catálogo, consulte primeiro
`show schemas;` e use o `database_name.schema_name` retornado pelo DuckDB, como
`lab.main_raw_sources.generic_raw_contract`.

## Personalizacao

Depois de entender o exemplo padrão, use
`docs/user-customization-guide.md` para criar seu próprio pipeline. A regra
principal é:

- dados entram na Raw em Parquet no MinIO;
- dbt modela Raw, staging, Silver, intermediate e marts;
- Airflow orquestra pods e agenda a execução;
- DuckDB executa SQL;
- Polaris cataloga tabelas Iceberg Silver e Gold.
