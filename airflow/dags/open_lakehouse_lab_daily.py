"""Main Open Lakehouse Lab DAG for dbt workloads in Kubernetes pods."""

# ruff: noqa: I001

from __future__ import annotations

import pendulum

try:
    from airflow.sdk import DAG, TaskGroup
except ImportError:  # pragma: no cover - Airflow 2 compatibility.
    from airflow import DAG
    from airflow.utils.task_group import TaskGroup
try:
    from airflow.providers.standard.operators.empty import EmptyOperator
except ImportError:  # pragma: no cover - Airflow 2 compatibility.
    from airflow.operators.empty import EmptyOperator
from kubernetes.client import models as k8s

from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

NAMESPACE = "data-platform"
DBT_IMAGE = "open-lakehouse-lab-dbt-duckdb-polaris:local"
DBT_SERVICE_ACCOUNT = "airflow-worker"
DBT_TARGET_PVC = "dbt-workload-target"

DBT_ENV = {
    "AWS_REGION": "us-east-1",
    "DBT_DUCKDB_EXTENSION_DIRECTORY": "target/duckdb_extensions",
    "DBT_DUCKDB_PATH": "target/open_lakehouse_lab.duckdb",
    "DBT_POLARIS_CATALOG_NAME": "lakehouse",
    "DBT_POLARIS_ENDPOINT": "http://polaris.data-platform.svc.cluster.local:8181",
    "DBT_POLARIS_WAREHOUSE": "s3://lakehouse/warehouse",
    "DBT_PROFILES_DIR": "/app/dbt",
    "DBT_S3_ENDPOINT": "minio.data-platform.svc.cluster.local:9000",
    "DBT_TARGET": "dev",
}

DBT_LABELS = {
    "app.kubernetes.io/name": "dbt-duckdb",
    "app.kubernetes.io/component": "dbt-workload",
    "app.kubernetes.io/part-of": "open-lakehouse-lab",
    "open-lakehouse-lab/stage": "12",
}

DBT_TARGET_VOLUME = k8s.V1Volume(
    name="dbt-target",
    persistent_volume_claim=k8s.V1PersistentVolumeClaimVolumeSource(
        claim_name=DBT_TARGET_PVC,
    ),
)
DBT_TARGET_VOLUME_MOUNT = k8s.V1VolumeMount(
    name="dbt-target",
    mount_path="/app/dbt/target",
)
DBT_SECRET_ENV = k8s.V1EnvFromSource(
    secret_ref=k8s.V1SecretEnvSource(
        name="polaris-local-credentials",
        optional=True,
    ),
)
DBT_POD_SECURITY_CONTEXT = k8s.V1PodSecurityContext(
    fs_group=1000,
    run_as_group=1000,
    run_as_user=1000,
)


def dbt_pod_task(task_id: str, pod_name: str, dbt_command: str) -> KubernetesPodOperator:
    """Create a dbt task that runs inside an ephemeral Kubernetes pod."""
    return KubernetesPodOperator(
        task_id=task_id,
        name=pod_name,
        namespace=NAMESPACE,
        image=DBT_IMAGE,
        image_pull_policy="Never",
        cmds=["/bin/sh", "-ec"],
        arguments=[f"echo 'Running: {dbt_command}' && {dbt_command}"],
        env_vars=DBT_ENV,
        env_from=[DBT_SECRET_ENV],
        labels=DBT_LABELS,
        volumes=[DBT_TARGET_VOLUME],
        volume_mounts=[DBT_TARGET_VOLUME_MOUNT],
        service_account_name=DBT_SERVICE_ACCOUNT,
        security_context=DBT_POD_SECURITY_CONTEXT,
        in_cluster=True,
        get_logs=True,
        is_delete_operator_pod=True,
        do_xcom_push=False,
    )


with DAG(
    dag_id="open_lakehouse_lab_daily",
    description="Run Open Lakehouse Lab dbt workloads in Kubernetes pods.",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["open-lakehouse-lab", "stage-12", "dbt", "kubernetes"],
) as dag:
    start = EmptyOperator(task_id="start")
    end = EmptyOperator(task_id="end")

    with TaskGroup(group_id="dbt_workloads") as dbt_workloads:
        dbt_seed = dbt_pod_task(
            task_id="dbt_seed",
            pod_name="dbt-seed",
            dbt_command="dbt deps && dbt seed --profiles-dir .",
        )
        dbt_run_foundation_staging_silver = dbt_pod_task(
            task_id="dbt_run_foundation_staging_silver",
            pod_name="dbt-run-foundation-staging-silver",
            dbt_command="dbt run --select raw_sources staging silver --profiles-dir .",
        )
        dbt_test_silver = dbt_pod_task(
            task_id="dbt_test_silver",
            pod_name="dbt-test-silver",
            dbt_command="dbt test --select silver --profiles-dir .",
        )
        dbt_run_intermediate_gold = dbt_pod_task(
            task_id="dbt_run_intermediate_gold",
            pod_name="dbt-run-intermediate-gold",
            dbt_command="dbt run --select intermediate marts --profiles-dir .",
        )
        dbt_test_gold = dbt_pod_task(
            task_id="dbt_test_gold",
            pod_name="dbt-test-gold",
            dbt_command="dbt test --select marts --profiles-dir .",
        )

        (
            dbt_seed
            >> dbt_run_foundation_staging_silver
            >> dbt_test_silver
            >> dbt_run_intermediate_gold
            >> dbt_test_gold
        )

    start >> dbt_workloads >> end
