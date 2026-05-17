window.OPEN_LAKEHOUSE_DOCS = {
  overview: {
    title: "Visão geral do projeto",
    category: "Introducao",
    summary:
      "Resumo do Open Lakehouse Lab, seus objetivos e a ordem de implementação da plataforma local.",
    tags: ["lakehouse", "estudo", "open source"],
    sections: [
      {
        title: "Objetivo",
        body:
          "O Open Lakehouse Lab é um laboratório 100% open source para estudar engenharia de dados moderna localmente, sem custos de cloud. O projeto usa kind, Kubernetes, Airflow, MinIO, Apache Iceberg, Apache Polaris, DuckDB, dbt, Prometheus e Grafana.",
      },
      {
        title: "Caminho padrão",
        body:
          "A coluna dorsal atual valida Raw Parquet no MinIO, transformações com dbt + DuckDB, tabelas Iceberg via Polaris e orquestração por Airflow usando pods Kubernetes.",
      },
      {
        title: "Como estudar",
        body:
          "Comece pelo Caminho Rápido para validar o ambiente. Depois siga a Trilha de Aprendizado para reproduzir cada etapa manualmente e entender o que acontece por baixo dos atalhos.",
      },
    ],
    commands: ["make lab-fast-path", "make lab-learning-path", "make explain-dbt-orchestration"],
  },
  "project-plan": {
    title: "Plano do projeto",
    category: "Arquitetura",
    summary:
      "Plano de evolução do laboratório, fases da arquitetura e responsabilidades das camadas Raw, Silver e Gold.",
    tags: ["planejamento", "arquitetura", "fases"],
    sections: [
      {
        title: "Arquitetura alvo",
        body:
          "Adapters de fonte escrevem dados na Raw. dbt + DuckDB lê esses dados, transforma para Silver e Gold, publica tabelas Iceberg e registra metadados no Polaris. Airflow orquestra a execução em pods no kind.",
      },
      {
        title: "Ordem de implementação",
        body:
          "A fundação local vem antes das fontes concretas: kind, MinIO, Polaris, Airflow, dbt + DuckDB, contrato Raw, adapters, Silver, Gold, observabilidade e documentação final.",
      },
      {
        title: "Limites do MVP",
        body:
          "O MVP evita MERGE, UPDATE, DELETE e ALTER TABLE em Iceberg. O comportamento inicial prefere full-refresh idempotente para facilitar estudo e revisão.",
      },
    ],
    commands: ["make cluster-create", "make deploy-minio", "make deploy-polaris"],
  },
  "learning-path": {
    title: "Trilha de aprendizado",
    category: "Estudo guiado",
    summary:
      "Guia para seguir o laboratório em modo rápido ou por lições incrementais.",
    tags: ["trilha", "lições", "atalhos"],
    sections: [
      {
        title: "Caminho Rápido",
        body:
          "Use o Caminho Rápido para subir o exemplo completo e provar que a coluna dorsal está funcional.",
      },
      {
        title: "Trilha de Aprendizado",
        body:
          "Use a trilha para entender cluster, storage, catálogo, dbt, Airflow e pipeline ponta a ponta separadamente.",
      },
      {
        title: "Comandos de explicacao",
        body:
          "Os alvos explain-* mostram objetivo, motivo, comandos, inspeções e próximo passo sem alterar o ambiente.",
      },
    ],
    commands: [
      "make lab-fast-path",
      "make lab-learning-path",
      "make explain-cluster",
      "make explain-deploy-minio",
      "make explain-dbt-orchestration",
    ],
  },
  customization: {
    title: "Guia de customização",
    category: "Pipelines próprios",
    summary:
      "Como adicionar dados Raw, criar modelos dbt e decidir quando alterar DAGs do Airflow.",
    tags: ["customização", "raw", "dbt", "airflow"],
    sections: [
      {
        title: "Dados Raw",
        body:
          "Grave Parquet no caminho s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet. Mantenha colunas técnicas como source, dataset, ingestion_date, loaded_at, record_hash e raw_payload.",
      },
      {
        title: "Modelos dbt",
        body:
          "Crie modelos em raw_sources, staging, silver, intermediate e marts. Documente colunas e testes nos schema.yml correspondentes.",
      },
      {
        title: "Airflow",
        body:
          "Não edite a DAG principal apenas para adicionar modelos dbt nas pastas existentes. Edite ou crie DAGs quando precisar de novas tasks, schedule, parâmetros ou experimentos.",
      },
    ],
    commands: ["make dbt-parse", "make dbt-compile", "make trigger-airflow-dbt"],
  },
  troubleshooting: {
    title: "Troubleshooting guiado",
    category: "Diagnóstico",
    summary:
      "Erros comuns do laboratório local e comandos para diagnosticar e recuperar o ambiente.",
    tags: ["debug", "local", "kubernetes"],
    sections: [
      {
        title: "Cluster kind já existe",
        body:
          "Verifique clusters existentes com kind get clusters e valide o contexto atual antes de recriar o ambiente.",
      },
      {
        title: "Fixture Raw com timeout",
        body:
          "Inspecione pods, logs e describe do job dbt-publish-raw-fixture. Confirme que a imagem dbt foi carregada no kind e que MinIO e Polaris estão saudáveis.",
      },
      {
        title: "DuckDB bloqueado",
        body:
          "Feche DuckDB CLI, DuckDB UI ou extensões conectadas ao mesmo arquivo antes de rodar dbt. DuckDB permite apenas um processo de escrita por arquivo.",
      },
    ],
    commands: [
      "kubectl -n data-platform logs job/dbt-publish-raw-fixture",
      "make polaris-health",
      "make airflow-status",
    ],
  },
  "lesson-kind": {
    title: "Lição 01 - Kubernetes local com kind",
    category: "Lição",
    summary: "Cria o cluster Kubernetes local e o namespace base do laboratório.",
    tags: ["kind", "kubernetes"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como criar um cluster kind, aplicar o namespace data-platform e validar conectividade com kubectl.",
      },
      {
        title: "Quando alterar",
        body:
          "Edite k8s/kind/kind-config.yaml apenas para estudar portas, versão da imagem do node ou mounts locais.",
      },
    ],
    commands: ["make cluster-create", "make kubectl-context", "make cluster-status"],
  },
  "lesson-minio": {
    title: "Lição 02 - Storage Raw com MinIO",
    category: "Lição",
    summary: "Sobe MinIO, cria o bucket lakehouse e recebe arquivos Raw Parquet.",
    tags: ["minio", "raw", "parquet"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como MinIO simula S3 localmente, como o bucket lakehouse é criado e onde os arquivos Raw ficam armazenados.",
      },
      {
        title: "Path Raw",
        body:
          "O contrato canônico usa s3://lakehouse/raw/source=<source>/dataset=<dataset>/ingestion_date=YYYY-MM-DD/*.parquet.",
      },
    ],
    commands: ["make deploy-minio", "make minio-status", "make publish-raw-fixture-parquet"],
  },
  "lesson-polaris": {
    title: "Lição 03 - Catálogo Iceberg com Polaris",
    category: "Lição",
    summary: "Sobe Polaris como catálogo REST Iceberg apontando para o MinIO.",
    tags: ["polaris", "iceberg", "catálogo"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como o catálogo lakehouse é criado e como Polaris conecta tabelas Iceberg ao armazenamento no MinIO.",
      },
      {
        title: "Validação",
        body:
          "Use polaris-status, polaris-health e os logs do job polaris-bootstrap-catalog para confirmar o bootstrap.",
      },
    ],
    commands: ["make deploy-polaris", "make polaris-status", "make polaris-health"],
  },
  "lesson-dbt": {
    title: "Lição 04 - Transformações com dbt e DuckDB",
    category: "Lição",
    summary: "Compila, executa e testa modelos dbt usando DuckDB como engine SQL.",
    tags: ["dbt", "duckdb", "sql"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como dbt lê Raw Parquet, cria staging, publica Silver e Gold como Iceberg e permite inspeção local pelo DuckDB.",
      },
      {
        title: "Fluxo de modelos",
        body:
          "O fluxo atual é raw_sources -> staging -> silver -> intermediate -> marts.",
      },
    ],
    commands: ["make dbt-parse", "make dbt-compile", "make dbt-run-silver", "make dbt-test-gold"],
  },
  "lesson-airflow": {
    title: "Lição 05 - Airflow e pods Kubernetes",
    category: "Lição",
    summary: "Explora Airflow, KubernetesPodOperator, params e retries.",
    tags: ["airflow", "kubernetes", "dag"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como o Airflow cria pods efêmeros para workloads e como usar DAGs didáticas sem mexer na DAG principal.",
      },
      {
        title: "DAGs de estudo",
        body:
          "lab_kubernetes_pod_operator mostra criação de pods. lab_params_and_retries mostra params, templates e retries.",
      },
    ],
    commands: ["make deploy-airflow", "make airflow-status", "make trigger-airflow-hello"],
  },
  "lesson-e2e": {
    title: "Lição 06 - Pipeline ponta a ponta",
    category: "Lição",
    summary:
      "Executa o caminho completo: MinIO, Polaris, dbt, DuckDB, Iceberg e Airflow.",
    tags: ["pipeline", "ponta a ponta"],
    sections: [
      {
        title: "O que você aprende",
        body:
          "Como validar a plataforma inteira e depois acessar MinIO, Airflow, Polaris e DuckDB para inspecionar resultados.",
      },
      {
        title: "Depois do exemplo",
        body:
          "Adicione novos Parquet na Raw, crie modelos dbt e use Airflow para orquestrar novas etapas quando necessário.",
      },
    ],
    commands: ["make lab-fast-path", "make trigger-airflow-dbt", "make airflow-status"],
  },
  "runbook-kind": {
    title: "Runbook - Cluster kind local",
    category: "Runbook",
    summary: "Comandos de ciclo de vida do cluster local.",
    tags: ["kind", "cluster"],
    sections: [
      { title: "Criar", body: "Use make cluster-create para criar o cluster e aplicar o namespace base." },
      { title: "Remover", body: "Use make cluster-delete para remover o cluster inteiro." },
    ],
    commands: ["make cluster-create", "make cluster-status", "make cluster-delete"],
  },
  "runbook-minio": {
    title: "Runbook - Armazenamento MinIO",
    category: "Runbook",
    summary: "Deploy, status, acesso local e paths do bucket lakehouse.",
    tags: ["minio", "storage"],
    sections: [
      { title: "Deploy", body: "make deploy-minio aplica Secret, Deployment, Service e job de criação do bucket." },
      { title: "Acesso", body: "Use make port-forward-minio e abra http://localhost:9001." },
    ],
    commands: ["make deploy-minio", "make minio-status", "make port-forward-minio"],
  },
  "runbook-polaris": {
    title: "Runbook - Catálogo Polaris",
    category: "Runbook",
    summary: "Deploy, credenciais locais, catálogo lakehouse e endpoints Polaris.",
    tags: ["polaris", "catálogo"],
    sections: [
      { title: "Deploy", body: "make deploy-polaris cria secret local, sobe Polaris e executa bootstrap do catálogo." },
      { title: "Saúde", body: "make polaris-health valida o endpoint de readiness do servico." },
    ],
    commands: ["make deploy-polaris", "make polaris-status", "make polaris-health"],
  },
  "runbook-airflow-kpo": {
    title: "Runbook - Airflow com KubernetesPodOperator",
    category: "Runbook",
    summary: "Build da imagem Airflow, deploy pelo Helm e DAG de smoke test.",
    tags: ["airflow", "kubernetespodoperator"],
    sections: [
      { title: "Imagem", body: "Construa e carregue a imagem local antes de subir o chart." },
      { title: "Smoke test", body: "A DAG hello_kubernetes_pod valida criação e remoção de pod efemero." },
    ],
    commands: ["make build-airflow-image", "make load-airflow-image", "make deploy-airflow"],
  },
  "runbook-dbt-foundation": {
    title: "Runbook - Fundação dbt + DuckDB + Polaris",
    category: "Runbook",
    summary: "Projeto dbt, contrato Raw, macro Polaris e materialização Iceberg.",
    tags: ["dbt", "duckdb", "polaris"],
    sections: [
      { title: "Contrato Raw", body: "Define colunas técnicas mínimas e formato canônico em Parquet." },
      { title: "Materialização", body: "A materialização iceberg_table é conservadora e orientada a full-refresh." },
    ],
    commands: ["make dbt-parse", "make dbt-compile", "make build-dbt-image"],
  },
  "runbook-raw-staging": {
    title: "Runbook - Fontes Raw e staging",
    category: "Runbook",
    summary: "Como dbt lê o contrato Raw e cria o staging inicial.",
    tags: ["raw", "staging"],
    sections: [
      { title: "Fixture", body: "publish_raw_fixture_parquet cria dados determinísticos para validar casts e testes." },
      { title: "Staging", body: "stg_raw_source_events normaliza nomes, tipos e campos estruturados." },
    ],
    commands: ["make dbt-publish-raw-fixture", "make dbt-run-foundation", "make dbt-run-staging"],
  },
  "runbook-silver": {
    title: "Runbook - Camada Silver",
    category: "Runbook",
    summary: "Modelos Silver genéricos para eventos, métricas e freshness.",
    tags: ["silver", "dbt"],
    sections: [
      { title: "Modelos", body: "silver_source_events, silver_metric_observations e silver_dataset_freshness." },
      { title: "Decisão", body: "Silver é genérica primeiro; modelos específicos ficam para adapters reais." },
    ],
    commands: ["make dbt-run-silver", "make dbt-test-silver"],
  },
  "runbook-backbone": {
    title: "Runbook - Coluna dorsal dbt MinIO Polaris",
    category: "Runbook",
    summary: "Caminho completo de Raw Parquet, Iceberg, Polaris e Airflow.",
    tags: ["backbone", "iceberg", "airflow"],
    sections: [
      { title: "Caminho completo", body: "Airflow publica Raw, roda dbt Silver/Gold e registra tabelas Iceberg no Polaris." },
      { title: "Inspeção", body: "Use MinIO para objetos, Airflow para DAGs e DuckDB para consultas SQL." },
    ],
    commands: ["make publish-raw-fixture-parquet", "make trigger-airflow-dbt"],
  },
  "runbook-airflow-dbt": {
    title: "Runbook - Orquestração dbt com Airflow",
    category: "Runbook",
    summary: "DAG principal open_lakehouse_lab_daily e execução dbt em pods.",
    tags: ["airflow", "dbt", "pods"],
    sections: [
      { title: "DAG atual", body: "start -> dbt_workloads -> end, com tasks para fixture, run e tests." },
      { title: "Estado DuckDB", body: "O PVC dbt-workload-target preserva artifacts e estado temporário entre pods." },
    ],
    commands: ["make trigger-airflow-dbt", "make airflow-dbt-pods"],
  },
};
