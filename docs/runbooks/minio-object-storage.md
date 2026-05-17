# Armazenamento de objetos MinIO

Este runbook descreve o deploy do MinIO da etapa 03 para o lakehouse local.

## Pre-requisitos

- Cluster kind local da etapa 02 criado com `make cluster-create`.
- `kubectl` configurado para o contexto `kind-open-lakehouse-lab`.

## Subir MinIO

A partir da raiz do repositorio:

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

Credenciais locais do laboratorio:

- Usuario: `minioadmin`
- Senha: `minioadmin123`

Essas credenciais sao apenas para desenvolvimento local neste laboratorio
educacional. Nao reutilize fora do cluster kind local.

## Caminhos do lakehouse

O bucket `lakehouse` e inicializado com estes prefixos base:

```text
s3://lakehouse/raw/
s3://lakehouse/warehouse/
s3://lakehouse/metadata/
```

Responsabilidades dos caminhos:

- `raw/`: payloads originais de APIs publicas.
- `warehouse/`: dados futuros do warehouse de tabelas Iceberg.
- `metadata/`: artefatos de pipeline, catalogo, freshness e qualidade.

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
tabelas Iceberg, integracao dbt e workloads Airflow entram em stages
posteriores.
