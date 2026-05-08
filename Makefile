.PHONY: help install-dev check-requirements cluster-create cluster-delete kubectl-context cluster-status deploy-minio delete-minio minio-status port-forward-minio lint-python test-python lint-yaml lint-dbt dbt-parse dbt-compile dbt-test validate-k8s lint-docker security-scan docs-check docker-build ci-pr pre-push

PYTHON_DIRS := ingestion airflow transformations tests scripts
EXISTING_PYTHON_DIRS := $(wildcard $(PYTHON_DIRS))
K8S_DIR := k8s
KIND_CONFIG := $(K8S_DIR)/kind/kind-config.yaml
K8S_NAMESPACE_MANIFEST := $(K8S_DIR)/namespaces/data-platform.yaml
MINIO_DIR := $(K8S_DIR)/minio
MINIO_NAMESPACE ?= data-platform
MINIO_SERVICE ?= minio
K8S_MANIFEST_DIRS := \
	$(K8S_DIR)/namespaces \
	$(K8S_DIR)/minio \
	$(K8S_DIR)/polaris \
	$(K8S_DIR)/airflow \
	$(K8S_DIR)/monitoring \
	$(K8S_DIR)/rbac
EXISTING_K8S_MANIFEST_DIRS := $(wildcard $(K8S_MANIFEST_DIRS))
KIND_CLUSTER_NAME ?= open-lakehouse-lab
KUBECTL_CONTEXT ?= kind-$(KIND_CLUSTER_NAME)
DOCKER_DIR := docker
DBT_DIR := dbt
DOCS_DIR := docs
PYTHON ?= python3

help:
	@echo "Open Lakehouse Lab quality commands"
	@echo "  make install-dev       Install local development dependencies"
	@echo "  make ci-pr             Run the same checks used by GitHub Actions"
	@echo "  make pre-push          Run checks before pushing"
	@echo "  make check-requirements Validate requirements files against pyproject.toml"
	@echo "  make cluster-create    Create the local kind cluster and base namespace"
	@echo "  make cluster-delete    Delete the local kind cluster"
	@echo "  make kubectl-context   Select the local kind kubectl context"
	@echo "  make cluster-status    Show local kind nodes and base namespace"
	@echo "  make deploy-minio      Deploy MinIO and create the lakehouse bucket"
	@echo "  make delete-minio      Delete MinIO manifests"
	@echo "  make minio-status      Show MinIO pods, service and bucket job"
	@echo "  make port-forward-minio Forward MinIO API and console ports"
	@echo "  make lint-python       Run Ruff lint"
	@echo "  make test-python       Run pytest when tests exist"
	@echo "  make lint-yaml         Run yamllint"
	@echo "  make lint-dbt          Run SQLFluff for dbt SQL when dbt exists"
	@echo "  make dbt-parse         Run dbt parse when dbt exists"
	@echo "  make dbt-compile       Run dbt compile when dbt exists"
	@echo "  make validate-k8s      Validate Kubernetes manifests when k8s exists"
	@echo "  make lint-docker       Run Hadolint when docker files exist"
	@echo "  make security-scan     Run Bandit and optional Trivy checks"

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

lint-python:
	@if [ -n "$(EXISTING_PYTHON_DIRS)" ]; then \
		ruff check $(EXISTING_PYTHON_DIRS); \
	else \
		echo "No Python source directories found. Skipping Ruff."; \
	fi

test-python:
	@if [ -d tests ]; then \
		pytest -q; \
	else \
		echo "No tests directory found. Skipping pytest."; \
	fi

lint-yaml:
	@yamllint .

lint-dbt:
	@if [ -d $(DBT_DIR) ]; then \
		cd $(DBT_DIR) && sqlfluff lint models --dialect duckdb --templater dbt; \
	else \
		echo "No dbt directory found. Skipping SQLFluff."; \
	fi

dbt-parse:
	@if [ -d $(DBT_DIR) ]; then \
		cd $(DBT_DIR) && dbt deps && dbt parse --profiles-dir .; \
	else \
		echo "No dbt directory found. Skipping dbt parse."; \
	fi

dbt-compile:
	@if [ -d $(DBT_DIR) ]; then \
		cd $(DBT_DIR) && dbt compile --profiles-dir .; \
	else \
		echo "No dbt directory found. Skipping dbt compile."; \
	fi

dbt-test:
	@if [ -d $(DBT_DIR) ]; then \
		cd $(DBT_DIR) && dbt test --profiles-dir .; \
	else \
		echo "No dbt directory found. Skipping dbt test."; \
	fi

validate-k8s:
	@if [ -n "$(EXISTING_K8S_MANIFEST_DIRS)" ]; then \
		if command -v kubeconform >/dev/null 2>&1; then \
			kubeconform -summary -strict $(EXISTING_K8S_MANIFEST_DIRS); \
		else \
			echo "kubeconform not installed. Skipping Kubernetes validation."; \
		fi; \
	else \
		echo "No Kubernetes manifest directories found. Skipping Kubernetes validation."; \
	fi

lint-docker:
	@if [ -d $(DOCKER_DIR) ] && ls $(DOCKER_DIR)/*Dockerfile >/dev/null 2>&1; then \
		if command -v hadolint >/dev/null 2>&1; then \
			hadolint $(DOCKER_DIR)/*Dockerfile; \
		else \
			echo "hadolint not installed. Skipping Dockerfile lint."; \
		fi; \
	else \
		echo "No Dockerfiles found. Skipping Dockerfile lint."; \
	fi

security-scan:
	@if [ -n "$(EXISTING_PYTHON_DIRS)" ]; then \
		bandit -q -r $(EXISTING_PYTHON_DIRS); \
	else \
		echo "No Python source directories found. Skipping Bandit."; \
	fi
	@if command -v trivy >/dev/null 2>&1; then \
		trivy fs --scanners vuln,secret,misconfig --exit-code 1 --severity HIGH,CRITICAL .; \
	else \
		echo "trivy not installed. Skipping Trivy scan."; \
	fi

docs-check:
	@if [ -d $(DOCS_DIR) ]; then \
		find $(DOCS_DIR) -name "*.md" -print -quit | grep -q . && echo "Documentation files found." || echo "No markdown docs found."; \
	else \
		echo "No docs directory found. Skipping docs check."; \
	fi

docker-build:
	@if [ -d $(DOCKER_DIR) ] && ls $(DOCKER_DIR)/*Dockerfile >/dev/null 2>&1; then \
		for file in $(DOCKER_DIR)/*Dockerfile; do \
			image_name=$$(basename $$file | tr '[:upper:]' '[:lower:]' | sed 's/.dockerfile//'); \
			docker build -f $$file -t open-lakehouse-lab-$$image_name:ci .; \
		done; \
	else \
		echo "No Dockerfiles found. Skipping Docker build."; \
	fi

ci-pr: check-requirements lint-python test-python lint-yaml lint-dbt dbt-parse dbt-compile validate-k8s lint-docker security-scan docs-check

pre-push: ci-pr
