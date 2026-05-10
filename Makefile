.PHONY: help install-dev check-requirements cluster-create cluster-delete kubectl-context cluster-status deploy-minio delete-minio minio-status port-forward-minio deploy-polaris delete-polaris polaris-status polaris-health port-forward-polaris build-airflow-image load-airflow-image deploy-airflow delete-airflow airflow-status port-forward-airflow trigger-airflow-hello lint-python test-python lint-yaml lint-dbt dbt-parse dbt-compile dbt-test validate-k8s lint-docker security-scan docs-check docker-build ci-pr pre-push

PYTHON_DIRS := ingestion airflow transformations tests scripts
EXISTING_PYTHON_DIRS := $(wildcard $(PYTHON_DIRS))
K8S_DIR := k8s
KIND_CONFIG := $(K8S_DIR)/kind/kind-config.yaml
K8S_NAMESPACE_MANIFEST := $(K8S_DIR)/namespaces/data-platform.yaml
MINIO_DIR := $(K8S_DIR)/minio
MINIO_NAMESPACE ?= data-platform
MINIO_SERVICE ?= minio
POLARIS_DIR := $(K8S_DIR)/polaris
POLARIS_NAMESPACE ?= data-platform
POLARIS_SERVICE ?= polaris
AIRFLOW_DIR := airflow
AIRFLOW_K8S_DIR := $(K8S_DIR)/airflow
AIRFLOW_NAMESPACE ?= data-platform
AIRFLOW_RELEASE ?= airflow
AIRFLOW_IMAGE_REPOSITORY ?= open-lakehouse-lab-airflow
AIRFLOW_IMAGE_TAG ?= local
AIRFLOW_IMAGE := $(AIRFLOW_IMAGE_REPOSITORY):$(AIRFLOW_IMAGE_TAG)
AIRFLOW_CHART_REPO_NAME ?= apache-airflow
AIRFLOW_CHART_REPO_URL ?= https://airflow.apache.org
AIRFLOW_CHART ?= $(AIRFLOW_CHART_REPO_NAME)/airflow
AIRFLOW_CHART_VERSION ?= 1.20.0
AIRFLOW_VALUES := $(AIRFLOW_K8S_DIR)/values.yaml
AIRFLOW_API_SERVICE ?= $(AIRFLOW_RELEASE)-api-server
K8S_MANIFEST_DIRS := $(wildcard $(K8S_DIR)/namespaces $(K8S_DIR)/minio $(K8S_DIR)/polaris $(K8S_DIR)/airflow $(K8S_DIR)/monitoring $(K8S_DIR)/rbac)
K8S_MANIFEST_FILES := $(shell find $(K8S_MANIFEST_DIRS) -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "values.yaml" 2>/dev/null)
KIND_CLUSTER_NAME ?= open-lakehouse-lab
KUBECTL_CONTEXT ?= kind-$(KIND_CLUSTER_NAME)
DOCKER_DIR := docker
DOCKERFILES := $(wildcard $(DOCKER_DIR)/*Dockerfile $(AIRFLOW_DIR)/Dockerfile)
DBT_DIR := dbt
DOCS_DIR := docs
PYTHON ?= python3

help:
	@echo "Open Lakehouse Lab commands"
	@echo "  make cluster-create | deploy-minio | deploy-polaris | deploy-airflow"
	@echo "  make minio-status | polaris-status | polaris-health | airflow-status"
	@echo "  make port-forward-minio | port-forward-polaris | port-forward-airflow"
	@echo "  make ci-pr | pre-push"

install-dev:
	$(PYTHON) -m pip install --upgrade pip
	pip install -r requirements-dev.txt

check-requirements:
	$(PYTHON) scripts/check_requirements_sync.py

cluster-create:
	kind create cluster --name $(KIND_CLUSTER_NAME) --config $(KIND_CONFIG)
	kubectl apply -f $(K8S_NAMESPACE_MANIFEST)

cluster-delete:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

kubectl-context:
	kubectl config use-context $(KUBECTL_CONTEXT)

cluster-status:
	kubectl --context $(KUBECTL_CONTEXT) get nodes
	kubectl --context $(KUBECTL_CONTEXT) get namespace data-platform

deploy-minio:
	kubectl apply -f $(MINIO_DIR)/secret.yaml
	kubectl apply -f $(MINIO_DIR)/deployment.yaml
	kubectl apply -f $(MINIO_DIR)/service.yaml
	kubectl -n $(MINIO_NAMESPACE) rollout status deployment/minio --timeout=180s
	kubectl -n $(MINIO_NAMESPACE) delete job minio-create-bucket --ignore-not-found
	kubectl apply -f $(MINIO_DIR)/job-create-bucket.yaml
	kubectl -n $(MINIO_NAMESPACE) wait --for=condition=complete job/minio-create-bucket --timeout=180s

delete-minio:
	kubectl delete -f $(MINIO_DIR)/job-create-bucket.yaml --ignore-not-found
	kubectl delete -f $(MINIO_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(MINIO_DIR)/deployment.yaml --ignore-not-found
	kubectl delete -f $(MINIO_DIR)/secret.yaml --ignore-not-found

minio-status:
	kubectl -n $(MINIO_NAMESPACE) get pods -l app.kubernetes.io/name=minio
	kubectl -n $(MINIO_NAMESPACE) get service $(MINIO_SERVICE)
	kubectl -n $(MINIO_NAMESPACE) get job minio-create-bucket

port-forward-minio:
	kubectl -n $(MINIO_NAMESPACE) port-forward svc/$(MINIO_SERVICE) 9000:9000 9001:9001

deploy-polaris:
	@test -n "$${POLARIS_ROOT_CLIENT_ID}" || (echo "POLARIS_ROOT_CLIENT_ID is required" && exit 1)
	@test -n "$${POLARIS_ROOT_CLIENT_SECRET}" || (echo "POLARIS_ROOT_CLIENT_SECRET is required" && exit 1)
	@test -n "$${POLARIS_MINIO_ACCESS_KEY}" || (echo "POLARIS_MINIO_ACCESS_KEY is required" && exit 1)
	@test -n "$${POLARIS_MINIO_SECRET_KEY}" || (echo "POLARIS_MINIO_SECRET_KEY is required" && exit 1)
	kubectl -n $(POLARIS_NAMESPACE) create secret generic polaris-local-credentials \
		--from-literal=POLARIS_ROOT_CLIENT_ID="$${POLARIS_ROOT_CLIENT_ID}" \
		--from-literal=POLARIS_ROOT_CLIENT_SECRET="$${POLARIS_ROOT_CLIENT_SECRET}" \
		--from-literal=AWS_ACCESS_KEY_ID="$${POLARIS_MINIO_ACCESS_KEY}" \
		--from-literal=AWS_SECRET_ACCESS_KEY="$${POLARIS_MINIO_SECRET_KEY}" \
		--dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f $(POLARIS_DIR)/deployment.yaml
	kubectl apply -f $(POLARIS_DIR)/service.yaml
	kubectl -n $(POLARIS_NAMESPACE) rollout status deployment/polaris --timeout=240s
	kubectl -n $(POLARIS_NAMESPACE) delete job polaris-bootstrap-catalog --ignore-not-found
	kubectl apply -f $(POLARIS_DIR)/catalog-bootstrap-job.yaml
	kubectl -n $(POLARIS_NAMESPACE) wait --for=condition=complete job/polaris-bootstrap-catalog --timeout=240s

delete-polaris:
	kubectl delete -f $(POLARIS_DIR)/catalog-bootstrap-job.yaml --ignore-not-found
	kubectl delete -f $(POLARIS_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(POLARIS_DIR)/deployment.yaml --ignore-not-found
	kubectl -n $(POLARIS_NAMESPACE) delete secret polaris-local-credentials --ignore-not-found

polaris-status:
	kubectl -n $(POLARIS_NAMESPACE) get pods -l app.kubernetes.io/name=polaris
	kubectl -n $(POLARIS_NAMESPACE) get service $(POLARIS_SERVICE)
	kubectl -n $(POLARIS_NAMESPACE) get job polaris-bootstrap-catalog

polaris-health:
	kubectl -n $(POLARIS_NAMESPACE) run polaris-health-check --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- curl -fsS http://$(POLARIS_SERVICE).$(POLARIS_NAMESPACE).svc.cluster.local:8182/q/health/ready

port-forward-polaris:
	kubectl -n $(POLARIS_NAMESPACE) port-forward svc/$(POLARIS_SERVICE) 8181:8181 8182:8182

build-airflow-image:
	docker build -t $(AIRFLOW_IMAGE) $(AIRFLOW_DIR)

load-airflow-image:
	kind load docker-image $(AIRFLOW_IMAGE) --name $(KIND_CLUSTER_NAME)

deploy-airflow:
	helm repo add $(AIRFLOW_CHART_REPO_NAME) $(AIRFLOW_CHART_REPO_URL) --force-update
	helm repo update $(AIRFLOW_CHART_REPO_NAME)
	kubectl apply -f $(AIRFLOW_K8S_DIR)/pod-launcher-rbac.yaml
	helm upgrade --install $(AIRFLOW_RELEASE) $(AIRFLOW_CHART) \
		--version $(AIRFLOW_CHART_VERSION) \
		--namespace $(AIRFLOW_NAMESPACE) \
		--values $(AIRFLOW_VALUES)
	kubectl -n $(AIRFLOW_NAMESPACE) rollout status deployment/$(AIRFLOW_RELEASE)-api-server --timeout=300s
	kubectl -n $(AIRFLOW_NAMESPACE) rollout status deployment/$(AIRFLOW_RELEASE)-scheduler --timeout=300s

delete-airflow:
	helm uninstall $(AIRFLOW_RELEASE) --namespace $(AIRFLOW_NAMESPACE) --ignore-not-found
	kubectl delete -f $(AIRFLOW_K8S_DIR)/pod-launcher-rbac.yaml --ignore-not-found

airflow-status:
	kubectl -n $(AIRFLOW_NAMESPACE) get pods -l release=$(AIRFLOW_RELEASE)
	kubectl -n $(AIRFLOW_NAMESPACE) get service $(AIRFLOW_API_SERVICE)

port-forward-airflow:
	kubectl -n $(AIRFLOW_NAMESPACE) port-forward svc/$(AIRFLOW_API_SERVICE) 8080:8080

trigger-airflow-hello:
	kubectl -n $(AIRFLOW_NAMESPACE) exec deployment/$(AIRFLOW_RELEASE)-scheduler -- airflow dags trigger hello_kubernetes_pod

lint-python:
	@if [ -n "$(EXISTING_PYTHON_DIRS)" ]; then ruff check $(EXISTING_PYTHON_DIRS); else echo "No Python source directories found. Skipping Ruff."; fi

test-python:
	@if [ -d tests ]; then pytest -q; else echo "No tests directory found. Skipping pytest."; fi

lint-yaml:
	@yamllint .

lint-dbt:
	@if [ -d $(DBT_DIR) ]; then cd $(DBT_DIR) && sqlfluff lint models --dialect duckdb --templater dbt; else echo "No dbt directory found. Skipping SQLFluff."; fi

dbt-parse:
	@if [ -d $(DBT_DIR) ]; then cd $(DBT_DIR) && dbt deps && dbt parse --profiles-dir .; else echo "No dbt directory found. Skipping dbt parse."; fi

dbt-compile:
	@if [ -d $(DBT_DIR) ]; then cd $(DBT_DIR) && dbt compile --profiles-dir .; else echo "No dbt directory found. Skipping dbt compile."; fi

dbt-test:
	@if [ -d $(DBT_DIR) ]; then cd $(DBT_DIR) && dbt test --profiles-dir .; else echo "No dbt directory found. Skipping dbt test."; fi

validate-k8s:
	@if [ -n "$(K8S_MANIFEST_FILES)" ]; then \
		if command -v kubeconform >/dev/null 2>&1; then kubeconform -summary -strict $(K8S_MANIFEST_FILES); else echo "kubeconform not installed. Skipping Kubernetes validation."; fi; \
	else echo "No Kubernetes manifest directories found. Skipping Kubernetes validation."; fi

lint-docker:
	@if [ -n "$(DOCKERFILES)" ]; then \
		if command -v hadolint >/dev/null 2>&1; then hadolint $(DOCKERFILES); else echo "hadolint not installed. Skipping Dockerfile lint."; fi; \
	else echo "No Dockerfiles found. Skipping Dockerfile lint."; fi

security-scan:
	@if [ -n "$(EXISTING_PYTHON_DIRS)" ]; then bandit -q -r $(EXISTING_PYTHON_DIRS); else echo "No Python source directories found. Skipping Bandit."; fi
	@if command -v trivy >/dev/null 2>&1; then trivy fs --scanners vuln,secret,misconfig --exit-code 1 --severity HIGH,CRITICAL .; else echo "trivy not installed. Skipping Trivy scan."; fi

docs-check:
	@if [ -d $(DOCS_DIR) ]; then find $(DOCS_DIR) -name "*.md" -print -quit | grep -q . && echo "Documentation files found." || echo "No markdown docs found."; else echo "No docs directory found. Skipping docs check."; fi

docker-build: build-airflow-image
	@if [ -d $(DOCKER_DIR) ] && ls $(DOCKER_DIR)/*Dockerfile >/dev/null 2>&1; then \
		for file in $(DOCKER_DIR)/*Dockerfile; do image_name=$$(basename $$file | tr '[:upper:]' '[:lower:]' | sed 's/.dockerfile//'); docker build -f $$file -t open-lakehouse-lab-$$image_name:ci .; done; \
	else echo "No Dockerfiles found. Skipping Docker build."; fi

ci-pr: check-requirements lint-python test-python lint-yaml lint-dbt dbt-parse dbt-compile validate-k8s lint-docker security-scan docs-check

pre-push: ci-pr
