# Airflow dbt orchestration

## Goal

Stage 12 adds the main `open_lakehouse_lab_daily` DAG. The DAG runs dbt
commands in ephemeral Kubernetes pods inside the local kind cluster, using the
same `dbt + duckdb` image built by the project.

This stage intentionally keeps dbt execution outside of the Airflow scheduler.
Airflow only orchestrates pods and streams logs. The dbt runtime, DuckDB
adapter, DuckDB extensions and project files live in the dbt image.

## Current DAG

```text
start
  -> dbt_workloads.dbt_publish_raw_fixture
  -> dbt_workloads.dbt_run_foundation_staging_silver
  -> dbt_workloads.dbt_test_silver
  -> dbt_workloads.dbt_run_intermediate_gold
  -> dbt_workloads.dbt_test_gold
  -> end
```

The DAG uses `KubernetesPodOperator` for each dbt task. Each pod uses:

```text
image: open-lakehouse-lab-dbt-duckdb-polaris:local
namespace: data-platform
service account: airflow-worker
imagePullPolicy: Never
```

`astronomer-cosmos[dbt-duckdb]` remains installed in the Airflow image. The
current implementation uses explicit pod tasks because this stage needs a small,
reviewable orchestration path and must keep the dbt dependency stack isolated in
the dbt image. A later refinement can replace the explicit tasks with Cosmos
Kubernetes execution mode once the dbt model graph and Iceberg materialization
are stable enough to benefit from model-level task rendering.

## DuckDB execution state

The local dbt profile writes DuckDB state to:

```text
/app/dbt/target/open_lakehouse_lab.duckdb
```

Because every dbt task runs in a different ephemeral pod, the DAG mounts a small
PVC at `/app/dbt/target`:

```text
dbt-workload-target
```

This PVC is local development state only. It exists for dbt artifacts, local
views and temporary DuckDB state. It is not the source of truth. Stage 13 stores
Raw Parquet and Iceberg table data in MinIO, with Silver and Gold registered in
Polaris.

## Prerequisites

Install the local tools:

```bash
kind version
kubectl version --client
docker version
helm version
```

Create the kind cluster and namespace:

```bash
make cluster-create
make kubectl-context
```

Deploy MinIO:

```bash
make deploy-minio
```

Deploy Polaris:

```bash
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"

make deploy-polaris
make polaris-health
```

Build and load the dbt image into kind:

```bash
make build-dbt-image
make load-dbt-image
```

Optionally publish the deterministic Raw Parquet fixture before deploying
Airflow:

```bash
make publish-raw-fixture-parquet
```

Build, load and deploy Airflow:

```bash
make build-airflow-image
make load-airflow-image
make deploy-airflow
make airflow-status
```

## Trigger the DAG

Trigger from the CLI:

```bash
make trigger-airflow-dbt
```

Or trigger from the Airflow UI:

```bash
make port-forward-airflow
```

Open:

```text
http://localhost:8080
```

Credentials:

```text
username: admin
password: admin
```

Trigger:

```text
open_lakehouse_lab_daily
```

## Validate pod execution

While the DAG is running:

```bash
make airflow-dbt-pods
```

You can also inspect the pods directly:

```bash
kubectl -n data-platform get pods \
  -l app.kubernetes.io/component=dbt-workload
```

Expected behavior:

- one dbt pod runs per task;
- logs appear in the Airflow UI task logs;
- pods are deleted after successful task completion;
- the `dbt-workload-target` PVC remains for the next task and future DAG runs.

## Validate local interfaces

Airflow UI:

```bash
make port-forward-airflow
```

```text
http://localhost:8080
```

MinIO Console:

```bash
make port-forward-minio
```

```text
http://localhost:9001
username: minioadmin
password: minioadmin123
```

Polaris readiness endpoint:

```bash
make port-forward-polaris
```

```text
http://localhost:8182/q/health/ready
```

## Validate with SQL

The full path writes Raw Parquet and Iceberg data to MinIO. For host-side
inspection, keep MinIO and Polaris port-forwards running and use the Stage 13
runbook:

```bash
make port-forward-minio
make port-forward-polaris
```

See:

```text
docs/runbooks/dbt-minio-polaris-backbone.md
```

If you keep DuckDB CLI, DuckDB UI or a VS Code extension connected to the same
file, dbt may fail with a DuckDB lock error. Close the other connection before
running dbt commands.

## Cleanup

Remove Airflow and the dbt workload PVC:

```bash
make delete-airflow
```

Remove the full local cluster:

```bash
make cluster-delete
```

## Limitations

- This stage orchestrates the current dbt chain; it does not add public source
  adapter ingestion tasks.
- The Raw fixture publication is a deterministic shortcut for study. The
  command is logged by the dbt pod before execution.
- The current implementation keeps explicit `KubernetesPodOperator` tasks. This
  is compatible with the project requirement to run workloads in pods and leaves
  room to adopt Cosmos Kubernetes task rendering after the model graph matures.
