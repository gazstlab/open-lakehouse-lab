# open-lakehouse-lab

Open Lakehouse Lab is a 100% open source study project for modern data lakehouse engineering.

## Project structure

The Stage 01 layout separates the local lakehouse into explicit implementation areas:

```text
airflow/              Astro CLI Airflow project scaffold.
airflow/dags/         Airflow DAG definitions.
ingestion/common/     Shared ingestion utilities.
ingestion/open_meteo/ Open-Meteo extractor code.
ingestion/usgs/       USGS earthquake extractor code.
ingestion/bcb/        Banco Central do Brasil SGS extractor code.
dbt/                  dbt Core project initialized with dbt init.
dbt/models/           Raw source, staging, Silver, intermediate and marts models.
docker/               Local runtime Dockerfiles.
k8s/                  kind, MinIO, Polaris, Airflow, monitoring and RBAC manifests.
metadata/             Pipeline, quality, catalog, Iceberg and freshness artifacts.
docs/adr/             Architecture decision records.
docs/runbooks/        Operational runbooks.
docs/architecture/    Architecture documentation.
```

The Airflow scaffold is managed with Astro CLI. The Airflow runtime requirements include Astronomer Cosmos with the dbt DuckDB extra so later stages can orchestrate dbt models from Airflow without hand-wiring each model as a custom task.

## Local Kubernetes cluster

Stage 02 provisions a local kind cluster and the base `data-platform` namespace.
See `docs/runbooks/local-kind-cluster.md` for prerequisites, lifecycle commands
and validation steps.

## Local Object Storage

Stage 03 deploys MinIO in the local Kubernetes cluster and initializes the
`lakehouse` bucket. See `docs/runbooks/minio-object-storage.md` for deployment,
port-forward and path conventions.

## Local Iceberg REST Catalog

Stage 04 deploys Apache Polaris as the local Iceberg REST Catalog and bootstraps
the `lakehouse` catalog backed by the MinIO warehouse path.
See `docs/runbooks/polaris-rest-catalog.md` for credentials, deployment,
health checks and endpoint conventions.

## Local Airflow Orchestration

Stage 05 deploys Airflow with the Apache Airflow Helm chart and validates
`KubernetesPodOperator` pod launching in the local `data-platform` namespace.
See `docs/runbooks/airflow-kubernetes-pod-operator.md` for image build, deploy,
UI access and smoke DAG validation steps.

## Development quality checks

Install development dependencies:

```bash
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
```

Install Git hooks:

```bash
pre-commit install --install-hooks
pre-commit install --hook-type pre-push
```

Run the same checks used by GitHub Actions:

```bash
make ci-pr
```

Run the pre-push check manually:

```bash
make pre-push
```

The initial quality gate includes:

- Python lint with Ruff;
- Python tests with pytest, when `tests/` exists;
- YAML lint with yamllint;
- dbt/SQL checks with SQLFluff, when `dbt/` exists;
- dbt parse and compile, when `dbt/` exists;
- Kubernetes manifest validation with kubeconform, when `k8s/` exists;
- Dockerfile lint with Hadolint, when Dockerfiles exist;
- security checks with Bandit and optional Trivy;
- documentation structure check.
