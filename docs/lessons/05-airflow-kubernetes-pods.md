# Licao 05 - Airflow e pods Kubernetes

## Objetivo

Estudar como Airflow orquestra workloads em pods efemeros no cluster kind.

## Atalho

```bash
make deploy-airflow
```

Para estudar o atalho:

```bash
make explain-deploy-airflow
```

## Comandos Manuais

```bash
helm repo add apache-airflow https://airflow.apache.org --force-update
helm repo update apache-airflow
kubectl apply -f k8s/airflow/pod-launcher-rbac.yaml
kubectl apply -f k8s/airflow/dbt-workload-pvc.yaml
helm upgrade --install airflow apache-airflow/airflow \
  --version 1.20.0 \
  --namespace data-platform \
  --values k8s/airflow/values.yaml
kubectl -n data-platform rollout status deployment/airflow-api-server --timeout=300s
kubectl -n data-platform rollout status deployment/airflow-scheduler --timeout=300s
```

## O Que Acontece

- Helm instala Airflow no namespace `data-platform`.
- RBAC permite que o scheduler crie pods de workload.
- O PVC `dbt-workload-target` preserva o diretorio `target` entre pods dbt.
- As DAGs em `airflow/dags/` ficam disponiveis na UI.

## Inspecao

```bash
make airflow-status
kubectl -n data-platform get pods
```

Abra a UI:

```bash
make port-forward-airflow
```

Use `http://localhost:8080` com `admin / admin`.

## DAGs de Estudo

A etapa 14 inclui DAGs didaticas:

- `lab_kubernetes_pod_operator`;
- `lab_params_and_retries`.

Elas existem para explorar Airflow sem alterar a DAG principal
`open_lakehouse_lab_daily`.

Dispare pelo CLI:

```bash
kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags trigger lab_kubernetes_pod_operator

kubectl -n data-platform exec deployment/airflow-scheduler -- \
  airflow dags trigger lab_params_and_retries
```

## Customizacao

Edite ou crie DAGs `airflow/dags/lab_*.py` para estudar parametros, retries,
schedules e operadores. Mantenha `open_lakehouse_lab_daily.py` como caminho
padrao estavel.
