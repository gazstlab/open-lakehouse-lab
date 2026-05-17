"""Imprime explicacoes didaticas para atalhos do Open Lakehouse Lab."""

from __future__ import annotations

import argparse
from collections.abc import Iterable
from dataclasses import dataclass


@dataclass(frozen=True)
class LabStep:
    goal: str
    why: str
    run: tuple[str, ...]
    inspect: tuple[str, ...]
    next_step: str


STEPS: dict[str, LabStep] = {
    "cluster-create": LabStep(
        goal="Criar o cluster Kubernetes local com kind e o namespace data-platform.",
        why=(
            "O laboratório executa MinIO, Polaris, Airflow e workloads dbt como "
            "recursos Kubernetes locais, então todos os próximos passos dependem "
            "desse cluster."
        ),
        run=(
            "kind create cluster --name open-lakehouse-lab --config k8s/kind/kind-config.yaml",
            "kubectl apply -f k8s/namespaces/data-platform.yaml",
        ),
        inspect=(
            "kubectl get nodes",
            "kubectl get namespace data-platform",
            "kubectl cluster-info --context kind-open-lakehouse-lab",
        ),
        next_step="Suba o MinIO com make deploy-minio.",
    ),
    "deploy-minio": LabStep(
        goal="Subir o MinIO e criar o bucket local lakehouse.",
        why=(
            "MinIO é o armazenamento de objetos local compatível com S3. Os arquivos Raw "
            "em Parquet e os dados do warehouse Iceberg ficam no bucket lakehouse."
        ),
        run=(
            "kubectl apply -f k8s/minio/secret.yaml",
            "kubectl apply -f k8s/minio/deployment.yaml",
            "kubectl apply -f k8s/minio/service.yaml",
            "kubectl apply -f k8s/minio/job-create-bucket.yaml",
        ),
        inspect=(
            "make minio-status",
            "make port-forward-minio",
            "abra http://localhost:9001 e entre com minioadmin / minioadmin123",
        ),
        next_step="Construa e carregue a imagem dbt, depois suba o Polaris.",
    ),
    "build-dbt-image": LabStep(
        goal="Construir a imagem dbt + DuckDB usada pelos workloads Kubernetes.",
        why=(
            "Airflow e jobs de fixture executam dbt em pods efêmeros, então o "
            "kind precisa de uma imagem local com dbt, dbt-duckdb e extensões "
            "DuckDB necessárias."
        ),
        run=(
            "docker build -f docker/dbt-duckdb-polaris.Dockerfile "
            "-t open-lakehouse-lab-dbt-duckdb-polaris:local .",
        ),
        inspect=("docker images open-lakehouse-lab-dbt-duckdb-polaris:local",),
        next_step="Carregue a imagem no kind com make load-dbt-image.",
    ),
    "load-dbt-image": LabStep(
        goal="Carregar a imagem dbt local no node do kind.",
        why=(
            "O kind usa seu próprio ambiente de execução de containers. Carregar a imagem "
            "permite usar imagePullPolicy=Never sem depender de registry."
        ),
        run=(
            "kind load docker-image open-lakehouse-lab-dbt-duckdb-polaris:local "
            "--name open-lakehouse-lab",
        ),
        inspect=("docker exec open-lakehouse-lab-control-plane crictl images | grep dbt",),
        next_step="Suba o Polaris com make deploy-polaris.",
    ),
    "deploy-polaris": LabStep(
        goal="Subir Apache Polaris e inicializar o catálogo Iceberg lakehouse.",
        why=(
            "Polaris é o Iceberg REST Catalog. dbt + DuckDB usa esse catálogo "
            "para publicar tabelas Iceberg Silver e Gold apoiadas no MinIO."
        ),
        run=(
            "export POLARIS_ROOT_CLIENT_ID=root",
            "export POLARIS_ROOT_CLIENT_SECRET=local-polaris-secret",
            "export POLARIS_MINIO_ACCESS_KEY=minioadmin",
            "export POLARIS_MINIO_SECRET_KEY=minioadmin123",
            "kubectl apply -f k8s/polaris/deployment.yaml",
            "kubectl apply -f k8s/polaris/service.yaml",
            "kubectl apply -f k8s/polaris/catalog-bootstrap-job.yaml",
        ),
        inspect=(
            "make polaris-status",
            "make polaris-health",
            "make port-forward-polaris",
        ),
        next_step="Publique a fixture Raw e depois suba o Airflow.",
    ),
    "publish-raw-fixture-parquet": LabStep(
        goal="Publicar arquivos Raw Parquet deterministicos no MinIO.",
        why=(
            "A fixture entrega ao dbt um dataset Raw estavel antes dos adapters "
            "reais existirem, mantendo a coluna dorsal testavel sem APIs externas."
        ),
        run=(
            "kubectl apply -f k8s/dbt/publish-raw-fixture-job.yaml",
            "dbt run-operation publish_raw_fixture_parquet --profiles-dir .",
        ),
        inspect=(
            "kubectl -n data-platform logs job/dbt-publish-raw-fixture",
            "kubectl -n data-platform run minio-list --rm -i --restart=Never "
            "--image=minio/mc:RELEASE.2025-04-16T18-13-26Z -- sh -c "
            "'mc alias set local http://minio:9000 minioadmin minioadmin123 "
            "&& mc find local/lakehouse/raw'",
        ),
        next_step="Rode dbt localmente ou dispare a DAG dbt pelo Airflow.",
    ),
    "deploy-airflow": LabStep(
        goal="Subir Airflow no Kubernetes com permissão para criar pods de workload.",
        why=(
            "Airflow e a camada de orquestracao. Ele agenda o pipeline dbt de "
            "exemplo e permite estudar o comportamento do KubernetesPodOperator."
        ),
        run=(
            "helm repo add apache-airflow https://airflow.apache.org --force-update",
            "kubectl apply -f k8s/airflow/pod-launcher-rbac.yaml",
            "kubectl apply -f k8s/airflow/dbt-workload-pvc.yaml",
            "helm upgrade --install airflow apache-airflow/airflow "
            "--namespace data-platform --values k8s/airflow/values.yaml",
        ),
        inspect=(
            "make airflow-status",
            "make port-forward-airflow",
            "abra http://localhost:8080 e entre com admin / admin",
        ),
        next_step="Dispare open_lakehouse_lab_daily com make trigger-airflow-dbt.",
    ),
    "trigger-airflow-dbt": LabStep(
        goal="Disparar o pipeline dbt padrão ponta a ponta pelo Airflow.",
        why=(
            "Isso valida a coluna dorsal: Airflow cria pods dbt, dbt le Raw "
            "Parquet no MinIO, DuckDB transforma dados e Polaris cataloga "
            "tabelas Iceberg."
        ),
        run=(
            "kubectl -n data-platform exec deployment/airflow-scheduler -- "
            "airflow dags trigger open_lakehouse_lab_daily",
        ),
        inspect=(
            "kubectl -n data-platform exec deployment/airflow-scheduler -- "
            "airflow dags list-runs open_lakehouse_lab_daily",
            "kubectl -n data-platform get pods -l app.kubernetes.io/component=dbt-workload",
            "kubectl -n data-platform logs job/dbt-publish-raw-fixture",
        ),
        next_step="Inspecione os resultados em Airflow, MinIO, Polaris e DuckDB.",
    ),
    "example": LabStep(
        goal="Executar os exemplos de referência do laboratório local completo.",
        why=(
            "Esse é o jeito direto de provar que o exemplo padrão funciona "
            "antes de estudar ou customizar camadas individuais."
        ),
        run=(
            "make cluster-create",
            "make deploy-minio",
            "make build-dbt-image",
            "make load-dbt-image",
            "make deploy-polaris",
            "make publish-raw-fixture-parquet",
            "make build-airflow-image",
            "make load-airflow-image",
            "make deploy-airflow",
            "make trigger-airflow-dbt",
        ),
        inspect=(
            "make minio-status",
            "make polaris-health",
            "make airflow-status",
            "make airflow-dbt-pods",
        ),
        next_step="Abra docs/learning-path.md e repita cada lição manualmente.",
    ),
    "lab-learning-path": LabStep(
        goal="Seguir a trilha de aprendizado guiada, uma camada por vez.",
        why=(
            "A trilha mostra a mesma arquitetura em formato de licoes, com "
            "comandos manuais, atalhos equivalentes, validação e troubleshooting."
        ),
        run=(
            "docs/lessons/01-local-kubernetes-kind.md",
            "docs/lessons/02-minio-raw-storage.md",
            "docs/lessons/03-polaris-iceberg-catalog.md",
            "docs/lessons/04-dbt-duckdb-transformations.md",
            "docs/lessons/05-airflow-kubernetes-pods.md",
            "docs/lessons/06-end-to-end-pipeline.md",
        ),
        inspect=(
            "make explain-cluster",
            "make explain-deploy-minio",
            "make explain-deploy-polaris",
            "make explain-deploy-airflow",
            "make explain-dbt-orchestration",
        ),
        next_step="Use docs/user-customization-guide.md para criar seu próprio pipeline.",
    ),
}


def print_lines(label: str, lines: Iterable[str]) -> None:
    for line in lines:
        print(f"[{label}] {line}")


def print_step(name: str) -> None:
    step = STEPS[name]
    print(f"[goal] {step.goal}")
    print(f"[why] {step.why}")
    print_lines("run", step.run)
    print_lines("inspect", step.inspect)
    print(f"[next] {step.next_step}")


def print_index() -> None:
    for name in sorted(STEPS):
        print(name)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Explica atalhos do Open Lakehouse Lab com logs didaticos."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    explain = subparsers.add_parser("explain", help="imprime a explicacao de um passo")
    explain.add_argument("step", choices=sorted(STEPS))

    subparsers.add_parser("list", help="lista os passos disponiveis")
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.command == "explain":
        print_step(args.step)
        return

    if args.command == "list":
        print_index()


if __name__ == "__main__":
    main()
