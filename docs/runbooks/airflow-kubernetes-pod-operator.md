# Airflow with KubernetesPodOperator

## Goal

Stage 05 deploys Apache Airflow in the local kind cluster and validates that the
Airflow scheduler can launch ephemeral pods in the `data-platform` namespace
with `KubernetesPodOperator`.

This stage uses:

- the Astro CLI project scaffold in `airflow/`;
- the official Apache Airflow Helm chart;
- a local Airflow image loaded into kind;
- a least-privilege RoleBinding for the scheduler pod launcher permissions.

## Prerequisites

Install the local tooling:

```bash
kind version
kubectl version --client
docker version
helm version
```

Create the local cluster:

```bash
make cluster-create
```

Airflow does not require MinIO or Polaris for this smoke test, but those services
can be deployed before Airflow when validating the full local platform.

## Build and load the Airflow image

Build the Astro Runtime image with the project DAGs and Python requirements:

```bash
make build-airflow-image
```

Load the image into the kind cluster:

```bash
make load-airflow-image
```

The Helm values use:

```text
open-lakehouse-lab-airflow:local
```

with `pullPolicy: Never`, so the image must exist inside the kind node before
the Airflow pods are created.

## Deploy Airflow

Deploy Airflow with the Apache Airflow Helm chart:

```bash
make deploy-airflow
```

Check the local deployment:

```bash
make airflow-status
```

Expected result:

- the API server pod is running;
- the scheduler pod is running;
- the PostgreSQL pod created by the chart is running;
- the `airflow-api-server` service exists.

## Access the Airflow UI

Forward the API server service:

```bash
make port-forward-airflow
```

Open:

```text
http://localhost:8080
```

Local credentials:

```text
username: admin
password: admin
```

## Run the smoke DAG

Trigger the DAG from another terminal:

```bash
make trigger-airflow-hello
```

You can also trigger `hello_kubernetes_pod` from the Airflow UI.

The DAG has one task:

```text
hello_from_ephemeral_pod
```

The task launches a `busybox:1.37.0` pod in the `data-platform` namespace,
streams the pod logs into Airflow and deletes the pod after completion.

## Validate the ephemeral pod behavior

While the task is running:

```bash
kubectl -n data-platform get pods \
  -l app.kubernetes.io/component=kubernetes-pod-operator-smoke
```

After the task succeeds, the query should return no running pod because the DAG
sets `is_delete_operator_pod=True`.

Task logs should include:

```text
hello from KubernetesPodOperator
```

## Cleanup

Remove Airflow:

```bash
make delete-airflow
```

Remove the full local cluster:

```bash
make cluster-delete
```

## Notes

- The chart version is pinned in the Makefile through `AIRFLOW_CHART_VERSION`.
- This stage validates Airflow pod launching only.
- Raw extractors, dbt orchestration and Cosmos DAGs are later-stage scope.
