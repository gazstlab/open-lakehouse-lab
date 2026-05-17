"""DAG de teste de smoke da etapa 05 para criacao de pods com KubernetesPodOperator."""

# ruff: noqa: I001

from __future__ import annotations

import pendulum

try:
    from airflow.sdk import DAG
except ImportError:  # pragma: no cover - Airflow 2 compatibility.
    from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

with DAG(
    dag_id="hello_kubernetes_pod",
    description="Valida que o Airflow consegue criar e remover um pod efemero.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["open-lakehouse-lab", "stage-05", "smoke"],
) as dag:
    KubernetesPodOperator(
        task_id="hello_from_ephemeral_pod",
        name="hello-kubernetes-pod",
        namespace="data-platform",
        image="busybox:1.37.0",
        cmds=["/bin/sh", "-c"],
        arguments=[
            "echo 'hello from KubernetesPodOperator'; "
            "echo \"namespace=${POD_NAMESPACE}\"; "
            "echo \"pod=${POD_NAME}\""
        ],
        env_vars={
            "POD_NAMESPACE": "data-platform",
            "POD_NAME": "hello-kubernetes-pod",
        },
        labels={
            "app.kubernetes.io/name": "airflow",
            "app.kubernetes.io/component": "kubernetes-pod-operator-smoke",
            "app.kubernetes.io/part-of": "open-lakehouse-lab",
            "open-lakehouse-lab/stage": "05",
        },
        service_account_name="airflow-worker",
        in_cluster=True,
        get_logs=True,
        is_delete_operator_pod=True,
        do_xcom_push=False,
    )
