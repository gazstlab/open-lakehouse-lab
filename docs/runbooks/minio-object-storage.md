# Armazenamento de objetos MinIO

Este runbook descreve o deploy do MinIO da etapa 03 para o lakehouse local.

## Pre-requisitos

- Cluster kind local da etapa 02 criado com `make cluster-create`.
- `kubectl` configurado para o contexto `kind-open-lakehouse-lab`.

## Subir MinIO

A partir da raiz do repositório:

```bash
make deploy-minio
```

O comando sobe MinIO no namespace `data-platform` e executa um job de bootstrap
que cria o bucket `lakehouse`.

## Verificar status

```bash
make minio-status
kubectl -n data-platform logs job/minio-create-bucket
```

## Acessar MinIO localmente

Inicie um port-forward local:

```bash
make port-forward-minio
```

Endpoints locais:

- S3 API: `http://localhost:9000`
- Console: `http://localhost:9001`

Credenciais locais do laboratório:

- Usuário: `minioadmin`
- Senha: `minioadmin123`

Essas credenciais são apenas para desenvolvimento local neste laboratório
educacional. Não reutilize fora do cluster kind local.

## Caminhos do lakehouse

O bucket `lakehouse` é inicializado com estes prefixos base:

```text
s3://lakehouse/raw/
s3://lakehouse/warehouse/
s3://lakehouse/metadata/
```

Responsabilidades dos caminhos:

- `raw/`: payloads originais de APIs públicas.
- `warehouse/`: dados futuros do warehouse de tabelas Iceberg.
- `metadata/`: artefatos de pipeline, catálogo, freshness e qualidade.

## Remover MinIO

```bash
make delete-minio
```

Para remover o cluster local inteiro:

```bash
make cluster-delete
```

## Escopo

A etapa 03 apenas sobe armazenamento de objetos local e inicializa o bucket base. Polaris,
tabelas Iceberg, integração dbt e workloads Airflow entram em stages
posteriores.
