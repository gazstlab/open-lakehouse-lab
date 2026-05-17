# Lição 01 - Kubernetes local com kind

## Objetivo

Criar o cluster Kubernetes local que recebe todos os serviços do laboratório.

## Atalho

```bash
make cluster-create
```

Para ver o que o atalho faz antes de executar:

```bash
make explain-cluster
```

## Comandos Manuais

```bash
kind create cluster --name open-lakehouse-lab --config k8s/kind/kind-config.yaml
kubectl apply -f k8s/namespaces/data-platform.yaml
```

## O Que Acontece

- `kind` cria um cluster Kubernetes dentro do Docker local.
- `k8s/kind/kind-config.yaml` define a configuração do cluster.
- `data-platform` é o namespace usado por MinIO, Polaris, Airflow e workloads dbt.

## Inspeção

```bash
kubectl get nodes
kubectl get namespace data-platform
kubectl cluster-info --context kind-open-lakehouse-lab
```

## Customização

Edite `k8s/kind/kind-config.yaml` somente quando quiser estudar configurações do
cluster local, como portas expostas, versão da imagem do node ou mounts.

## Limpeza

```bash
make cluster-delete
```
