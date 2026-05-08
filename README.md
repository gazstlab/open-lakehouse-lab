# open-lakehouse-lab

Open Lakehouse Lab is a 100% open source study project for modern data lakehouse engineering.

## Development quality checks

Install development dependencies:

```bash
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
```

Install Git hooks:

```bash
pre-commit install --install-hooks
pre-commit install --hook-type pre-push
```

Run the same checks used by GitHub Actions:

```bash
make ci-pr
```

Run the pre-push check manually:

```bash
make pre-push
```

The initial quality gate includes:

- Python lint with Ruff;
- Python tests with pytest, when `tests/` exists;
- YAML lint with yamllint;
- dbt/SQL checks with SQLFluff, when `dbt/` exists;
- dbt parse and compile, when `dbt/` exists;
- Kubernetes manifest validation with kubeconform, when `k8s/` exists;
- Dockerfile lint with Hadolint, when Dockerfiles exist;
- security checks with Bandit and optional Trivy;
- documentation structure check.
