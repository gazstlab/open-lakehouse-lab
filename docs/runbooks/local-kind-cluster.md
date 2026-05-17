# Cluster kind local

Este runbook descreve o bootstrap do cluster Kubernetes local da etapa 02.

## Pre-requisitos

- Docker instalado e rodando.
- `kind` instalado e disponivel no `PATH`.
- `kubectl` instalado e disponivel no `PATH`.

## Criar o cluster

A partir da raiz do repositorio:

```bash
make cluster-create
```

O comando cria um cluster kind chamado `open-lakehouse-lab` a partir de
`k8s/kind/kind-config.yaml` e aplica o namespace base `data-platform`.

## Selecionar o contexto do kubectl

```bash
make kubectl-context
```

## Validar conectividade

```bash
make cluster-status
kubectl get nodes
kubectl get namespace data-platform
```

## Remover o cluster

```bash
make cluster-delete
```

## Escopo

A etapa 02 provisiona apenas o cluster Kubernetes local e o namespace base.
Storage, catalogo, Airflow, monitoramento e manifests de workload entram em
stages posteriores.
