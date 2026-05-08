# Codex development environment

This directory documents the recommended AI-assisted development setup for Open Lakehouse Lab.

The initial AI development environment targets Codex only.

## Repository instructions

Codex should use the repository-level instructions in:

```text
AGENTS.md
```

These instructions define project context, architecture constraints, quality commands and contribution expectations.

## Repository skills

Repository-scoped skills are stored under:

```text
.agents/skills/<skill-name>/SKILL.md
```

Current skills:

```text
stage-implementation
lakehouse-architecture
kubernetes-local-platform
dbt-duckdb-iceberg
airflow-orchestration
public-api-ingestion
observability-monitoring
ci-quality
technical-documentation
```

## Recommended local setup

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

Run repository checks:

```bash
make ci-pr
```

Run the same pre-push checks manually:

```bash
make pre-push
```

## Recommended Codex workflow

For stage work:

1. Read `AGENTS.md`.
2. Read `docs/project-plan.md`.
3. Read the target GitHub issue.
4. Select the matching skill from `.agents/skills/`.
5. Implement only the issue scope.
6. Run or document the relevant quality commands.
7. Update the issue checklist.

## Guardrails

Codex should not:

- add paid cloud dependencies;
- commit secrets or local credentials;
- introduce private datasets;
- add product dashboard scope unless requested;
- bypass CI/pre-push checks;
- implement future stages without an issue requesting it.

## Notes

This setup is intentionally minimal. Future AI tooling can be added later, but Stage 00 only covers Codex-oriented instructions and skills.
