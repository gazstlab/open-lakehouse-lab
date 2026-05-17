"""DAG didatica com uma task minima usando KubernetesPodOperator."""

# ruff: noqa: I001

from __future__ import annotations

import pendulum

try:
    from airflow.sdk import DAG
except ImportError:  # pragma: no cover - Airflow 2 compatibility.
    from airflow import DAG

from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator


with DAG(
    dag_id="lab_kubernetes_pod_operator",
    description="Estuda como o Airflow cria um pod efemero no Kubernetes.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule=None,
    catchup=False,
    tags=["open-lakehouse-lab", "stage-14", "learning", "kubernetes"],
) as dag:
    KubernetesPodOperator(
        task_id="print_pod_context",
        name="lab-kubernetes-pod-operator",
        namespace="data-platform",
        image="busybox:1.37.0",
        cmds=["/bin/sh", "-ec"],
        arguments=[
            "echo '[goal] executar um comando curto em um pod Kubernetes'; "
            "echo '[why] Airflow deve criar workloads fora do scheduler'; "
            "echo '[inspect] kubectl -n data-platform get pods'; "
            "echo \"pod_name=$HOSTNAME\""
        ],
        labels={
            "app.kubernetes.io/name": "airflow",
            "app.kubernetes.io/component": "lab-kubernetes-pod-operator",
            "app.kubernetes.io/part-of": "open-lakehouse-lab",
            "open-lakehouse-lab/stage": "14",
        },
        service_account_name="airflow-worker",
        in_cluster=True,
        get_logs=True,
        is_delete_operator_pod=True,
        do_xcom_push=False,
    )
