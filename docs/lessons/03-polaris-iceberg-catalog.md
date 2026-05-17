# Licao 03 - Catalogo Iceberg com Polaris

## Objetivo

Subir Apache Polaris como REST Catalog Iceberg apontando para o warehouse no MinIO.

## Atalho

```bash
make deploy-polaris
```

Para estudar o atalho:

```bash
make explain-deploy-polaris
```

## Comandos Manuais

O Makefile define credenciais locais padrao, mas voce pode exportar explicitamente:

```bash
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"
```

Depois aplique os recursos:

```bash
kubectl -n data-platform create secret generic polaris-local-credentials \
  --from-literal=POLARIS_ROOT_CLIENT_ID="${POLARIS_ROOT_CLIENT_ID}" \
  --from-literal=POLARIS_ROOT_CLIENT_SECRET="${POLARIS_ROOT_CLIENT_SECRET}" \
  --from-literal=AWS_ACCESS_KEY_ID="${POLARIS_MINIO_ACCESS_KEY}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${POLARIS_MINIO_SECRET_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f k8s/polaris/deployment.yaml
kubectl apply -f k8s/polaris/service.yaml
kubectl -n data-platform rollout status deployment/polaris --timeout=240s
kubectl -n data-platform delete job polaris-bootstrap-catalog --ignore-not-found
kubectl apply -f k8s/polaris/catalog-bootstrap-job.yaml
kubectl -n data-platform wait --for=condition=complete job/polaris-bootstrap-catalog --timeout=240s
```

## O Que Acontece

- Polaris sobe como catalogo REST para tabelas Apache Iceberg.
- O job de bootstrap cria o catalogo `lakehouse`.
- O warehouse do catalogo aponta para o armazenamento local em MinIO.

## Inspecao

```bash
make polaris-status
make polaris-health
kubectl -n data-platform logs job/polaris-bootstrap-catalog
```

Para testar a API localmente:

```bash
make port-forward-polaris
curl -fsS http://localhost:8182/q/health/ready
```

## Customizacao

Os arquivos principais sao:

- `k8s/polaris/deployment.yaml`;
- `k8s/polaris/service.yaml`;
- `k8s/polaris/catalog-bootstrap-job.yaml`;
- `dbt/dbt_project.yml`;
- `dbt/profiles.yml`.

Altere catalogo, endpoint ou warehouse somente quando estiver estudando a
integracao dbt/DuckDB/Polaris.
