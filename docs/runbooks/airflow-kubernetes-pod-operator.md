# Airflow com KubernetesPodOperator

## Objetivo

A etapa 05 sobe Apache Airflow no cluster kind local e valida que o scheduler do
Airflow consegue criar pods efemeros no namespace `data-platform` com
`KubernetesPodOperator`.

Esta etapa usa:

- o scaffold de projeto Astro CLI em `airflow/`;
- o Helm chart oficial do Apache Airflow;
- uma imagem local do Airflow carregada no kind;
- um RoleBinding de menor privilegio para permissoes de criacao de pods pelo scheduler.

## Pre-requisitos

Instale as ferramentas locais:

```bash
kind version
kubectl version --client
docker version
helm version
```

Crie o cluster local:

```bash
make cluster-create
```

Airflow nao exige MinIO nem Polaris para este teste de smoke, mas esses servicos
podem ser implantados antes do Airflow ao validar a plataforma local completa.

## Construir e carregar a imagem Airflow

Construa a imagem Astro Runtime com as DAGs do projeto e requisitos Python:

```bash
make build-airflow-image
```

Carregue a imagem no cluster kind:

```bash
make load-airflow-image
```

Os valores Helm usam:

```text
open-lakehouse-lab-airflow:local
```

com `pullPolicy: Never`, entao a imagem precisa existir dentro do node kind
antes da criacao dos pods do Airflow.

## Subir Airflow

Suba Airflow com o Helm chart do Apache Airflow:

```bash
make deploy-airflow
```

Verifique o deploy local:

```bash
make airflow-status
```

Resultado esperado:

- o pod do API server esta rodando;
- o pod do scheduler esta rodando;
- o pod PostgreSQL criado pelo chart esta rodando;
- o service `airflow-api-server` existe.

## Acessar a UI do Airflow

Encaminhe a porta do service do API server:

```bash
make port-forward-airflow
```

Abra:

```text
http://localhost:8080
```

Credenciais locais:

```text
usuario: admin
senha: admin
```

## Rodar a DAG de teste de smoke

Dispare a DAG a partir de outro terminal:

```bash
make trigger-airflow-hello
```

Voce tambem pode disparar `hello_kubernetes_pod` pela UI do Airflow.

A DAG tem uma task:

```text
hello_from_ephemeral_pod
```

A task cria um pod `busybox:1.37.0` no namespace `data-platform`, envia os logs
do pod para o Airflow e remove o pod depois da conclusao.

## Validar o comportamento do pod efemero

Enquanto a task estiver rodando:

```bash
kubectl -n data-platform get pods \
  -l app.kubernetes.io/component=kubernetes-pod-operator-smoke
```

Depois que a task concluir com sucesso, a consulta nao deve retornar pod em
execucao porque a DAG define `is_delete_operator_pod=True`.

Os logs da task devem incluir:

```text
hello from KubernetesPodOperator
```

## Limpeza

Remova o Airflow:

```bash
make delete-airflow
```

Remova o cluster local completo:

```bash
make cluster-delete
```

## Notas

- A versao do chart e fixada no Makefile por `AIRFLOW_CHART_VERSION`.
- A etapa 05 valida apenas a criacao de pods pelo Airflow.
- A etapa 12 adiciona a DAG `open_lakehouse_lab_daily` para workloads dbt
  rodando em pods Kubernetes. Veja `docs/runbooks/airflow-dbt-orchestration.md`.
