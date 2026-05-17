# Apache Polaris Catalogo REST

Este runbook descreve o deploy do Apache Polaris da etapa 04 para o ambiente
local do Open Lakehouse Lab.

## Escopo

A etapa 04 sobe Apache Polaris como Iceberg REST Catalog local e configura o
catalogo `lakehouse` apoiado no path de warehouse do MinIO:

```text
s3://lakehouse/warehouse
```

A primeira implementacao usa persistencia em memoria do Polaris porque esta
etapa foca em disponibilidade local do catalogo e integracao com MinIO. Um
backend duravel de metadados, como Postgres, pode ser introduzido em uma etapa
posterior se necessario.

## Pre-requisitos

- Cluster kind local da etapa 02 criado com `make cluster-create`.
- MinIO da etapa 03 implantado com `make deploy-minio`.
- Bucket `lakehouse` existente no MinIO.
- `kubectl` configurado para o contexto `kind-open-lakehouse-lab`.

## Credenciais locais

Nao commite credenciais reais.

O comando de deploy cria o secret Kubernetes dinamicamente a partir de variaveis
de ambiente:

```bash
export POLARIS_ROOT_CLIENT_ID="root"
export POLARIS_ROOT_CLIENT_SECRET="local-polaris-secret"
export POLARIS_MINIO_ACCESS_KEY="minioadmin"
export POLARIS_MINIO_SECRET_KEY="minioadmin123"
```

Esses valores sao apenas exemplos para o laboratorio educacional local. Use
valores diferentes se o deploy local do MinIO foi customizado.

Um template esta disponivel em:

```text
k8s/polaris/secret.example.yaml
```

## Subir Polaris

A partir da raiz do repositorio:

```bash
make deploy-polaris
```

O comando:

1. cria o secret `polaris-local-credentials` a partir das variaveis de ambiente;
2. sobe o pod do Polaris;
3. expoe as APIs de catalogo e gerenciamento por um service ClusterIP;
4. aguarda o rollout do deployment;
5. executa o job de bootstrap que cria o catalogo `lakehouse`.

## Verificar status

```bash
make polaris-status
make polaris-health
kubectl -n data-platform logs job/polaris-bootstrap-catalog
```

Endpoints internos esperados:

```text
API de catalogo:      http://polaris.data-platform.svc.cluster.local:8181/api/catalog
API de gerenciamento: http://polaris.data-platform.svc.cluster.local:8181
Check de saude:       http://polaris.data-platform.svc.cluster.local:8182/q/health/ready
```

## Acessar Polaris localmente

Inicie um port-forward local:

```bash
make port-forward-polaris
```

Endpoints locais:

```text
API de catalogo:      http://localhost:8181/api/catalog
API de gerenciamento: http://localhost:8181
Check de saude:       http://localhost:8182/q/health/ready
```

## Configuracao do catalogo

O job de bootstrap cria o catalogo:

```text
lakehouse
```

Localizacao do warehouse:

```text
s3://lakehouse/warehouse
```

Endpoint do MinIO dentro do cluster:

```text
http://minio.data-platform.svc.cluster.local:9000
```

A futura etapa dbt + DuckDB deve usar o endpoint interno do catalogo ao rodar
dentro do Kubernetes:

```text
http://polaris.data-platform.svc.cluster.local:8181/api/catalog
```

Ao rodar a partir da maquina host por port-forward, use:

```text
http://localhost:8181/api/catalog
```

## Remover Polaris

```bash
make delete-polaris
```

Isso remove:

- job de bootstrap;
- service;
- deployment;
- secret de credenciais locais.

Isso nao remove o MinIO nem o bucket `lakehouse`.

## Checklist de validacao

- [ ] `make deploy-polaris` conclui com sucesso.
- [ ] `make polaris-status` mostra o pod e o service do Polaris.
- [ ] `make polaris-health` retorna uma resposta saudavel.
- [ ] `kubectl -n data-platform logs job/polaris-bootstrap-catalog` confirma o bootstrap do catalogo.
- [ ] `make port-forward-polaris` expoe as portas `8181` e `8182` localmente.

## Limitacoes conhecidas

- O MVP usa persistencia em memoria do Polaris.
- O job local de bootstrap e intencionalmente simples e otimizado para estudo, nao para producao.
- O armazenamento duravel de metadados do catalogo fica intencionalmente para uma etapa futura.
- Esta etapa nao cria tabelas Iceberg; isso e responsabilidade das etapas dbt + DuckDB posteriores.
