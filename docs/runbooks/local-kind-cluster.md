# Local kind cluster

This runbook describes the Stage 02 local Kubernetes cluster bootstrap.

## Prerequisites

- Docker installed and running.
- `kind` installed and available in `PATH`.
- `kubectl` installed and available in `PATH`.

## Create the cluster

From the repository root:

```bash
make cluster-create
```

The command creates a kind cluster named `open-lakehouse-lab` from
`k8s/kind/kind-config.yaml` and applies the base `data-platform` namespace.

## Select the kubectl context

```bash
make kubectl-context
```

## Validate connectivity

```bash
make cluster-status
kubectl get nodes
kubectl get namespace data-platform
```

## Delete the cluster

```bash
make cluster-delete
```

## Scope

Stage 02 only provisions the local Kubernetes cluster and base namespace.
Storage, catalog, Airflow, monitoring and workload manifests are introduced in
later stages.
