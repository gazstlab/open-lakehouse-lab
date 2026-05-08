.PHONY: help install-dev check-requirements lint-python test-python lint-yaml lint-dbt dbt-parse dbt-compile dbt-test validate-k8s lint-docker security-scan docs-check docker-build ci-pr pre-push

PYTHON_DIRS := ingestion airflow transformations tests scripts
EXISTING_PYTHON_DIRS := $(wildcard $(PYTHON_DIRS))
K8S_DIR := k8s
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
	@if [ -d $(K8S_DIR) ]; then \
		if command -v kubeconform >/dev/null 2>&1; then \
			kubeconform -summary -strict $(K8S_DIR); \
		else \
			echo "kubeconform not installed. Skipping Kubernetes validation."; \
		fi; \
	else \
		echo "No k8s directory found. Skipping Kubernetes validation."; \
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
