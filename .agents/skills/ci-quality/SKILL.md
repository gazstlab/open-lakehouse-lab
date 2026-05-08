---
name: ci-quality
description: Use this skill for GitHub Actions, Makefile quality commands, pre-commit, pre-push, linting, tests, security scans, and smoke tests.
---

# CI Quality Skill

## Scope

Use this skill when working with:

```text
.github/workflows/
.pre-commit-config.yaml
Makefile
requirements-dev.txt
pyproject.toml
.yamllint.yml
```

## Quality principle

The same core checks should run in GitHub Actions and locally before push.

Primary commands:

```bash
make ci-pr
make pre-push
```

## Expected checks

- Python lint with Ruff.
- Python tests with pytest when tests exist.
- YAML lint with yamllint.
- dbt/SQL lint with SQLFluff when dbt exists.
- dbt parse and compile when dbt exists.
- Kubernetes manifest validation when k8s exists.
- Dockerfile lint when Dockerfiles exist.
- security checks with Bandit and optional Trivy.
- documentation structure checks.

## Change rules

- Keep CI fast for normal PRs.
- Use deterministic fixtures for PR checks.
- Put heavy tests in smoke or nightly workflows.
- Avoid network-dependent tests in PR checks unless explicitly required.
- Make optional tools skip gracefully when not installed locally.

## Definition of done

For CI changes:

- Makefile target exists.
- GitHub Actions uses the same target when possible.
- Local pre-push runs the same core checks.
- README documents usage.
