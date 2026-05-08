# AGENTS.md

## Project context

Open Lakehouse Lab is a 100% open source study project for modern data lakehouse engineering.

This repository is an educational lab, not a production platform and not a personal portfolio. It studies a local lakehouse architecture using kind, Kubernetes, Airflow, MinIO, Apache Iceberg, Apache Polaris, DuckDB, dbt, Prometheus and Grafana.

## Primary goals

Keep the project:

- 100% open source;
- reproducible locally;
- cloud-cost-free;
- educational and well documented;
- modular and easy to review;
- safe to run on a local development machine.

## Expected repository layout

```text
airflow/       Airflow DAGs and Airflow-specific configuration
ingestion/     Python extractors and shared ingestion utilities
dbt/           dbt project, models, macros and tests
docker/        Dockerfiles for local runtimes
k8s/           Kubernetes manifests and Helm values
metadata/      Metadata contracts, catalog artifacts and examples
docs/          Architecture docs, ADRs and runbooks
.github/       GitHub Actions workflows
.agents/       Codex skills and agent-specific guidance
.codex/        Optional local Codex configuration examples
```

Some directories may not exist yet. Create them only when the task requires it.

## Engineering conventions

- Use English for file names, issue titles, branch names, commits and code identifiers.
- Portuguese is acceptable for educational documentation content.
- Keep changes small and stage-oriented.
- Prefer explicit, readable code over clever abstractions.
- Do not introduce paid cloud services or managed SaaS dependencies.
- Do not add dashboard/product UI scope unless an issue explicitly asks for it.
- Treat Prometheus and Grafana as operational observability, not business dashboards.
- Do not commit secrets, tokens, local credentials, kubeconfigs or generated private files.
- Use public APIs or deterministic fixtures. Do not use private datasets.

## Commit conventions

Use Conventional Commits for every commit that is part of a Pull Request.

Required format:

```text
<type>(optional-scope): <short imperative summary>
```

Allowed types:

```text
feat      new user-facing or project capability
fix       bug fix
chore     repository maintenance, tooling or non-runtime work
docs      documentation-only change
ci        GitHub Actions, pre-commit, quality gates or automation
test      tests or fixtures
refactor  code restructuring without behavior change
build     Docker, dependency or build-system changes
perf      performance improvement
style     formatting-only change
revert    revert commit
```

Examples:

```text
feat(k8s): add kind cluster configuration
fix(dbt): correct Polaris catalog attach macro
docs(adr): document MinIO storage decision
ci(github): validate PR title and commit messages
chore(codex): add repository agent skills
```

Rules:

- Use lowercase `type` and optional lowercase `scope`.
- Keep the first line concise and descriptive.
- Prefer imperative mood, for example `add`, `create`, `fix`, `document`.
- Do not use vague messages like `update`, `changes`, `fix stuff` or `wip`.
- Merge commits, revert commits and automated dependency commits may be handled separately by repository automation.

## Pull request conventions

Every Pull Request must be linked to a GitHub issue in the PR title using an issue reference.

Required title pattern:

```text
<type>(optional-scope): <short summary> (#<issue-number>)
```

Accepted examples:

```text
feat(k8s): add kind cluster bootstrap (#4)
docs(codex): add agent instructions and skills (#2)
ci(github): add convention validation workflow (#2)
```

The `#<issue-number>` reference is required in the title because GitHub automatically links it to the related issue.

Every PR body should include:

- linked issue using `Closes #<issue>` or `Refs #<issue>`;
- concise summary of what changed;
- commands executed for validation;
- known limitations or follow-up tasks.

PRs should be small and stage-oriented. A PR should normally target one issue or one clearly bounded part of a stage.

## Architecture constraints

- MinIO is the object storage abstraction.
- Apache Polaris is the Iceberg REST Catalog target.
- Apache Iceberg is the table format for Silver and Gold.
- DuckDB is the SQL execution engine for dbt.
- dbt should own structured transformations from Raw to Silver and Silver to Gold.
- Initialize the dbt project with `dbt-core` using `dbt init`; do not hand-roll the initial dbt project scaffold unless a later issue explicitly requires a custom layout.
- Airflow project scaffolding and local Airflow workflows should use Astro CLI.
- Use Astronomer Cosmos to integrate dbt with Airflow DAGs instead of manually wiring every dbt model as custom Airflow tasks.
- The MVP should avoid `MERGE INTO`, `ALTER TABLE`, `UPDATE` and `DELETE` on Iceberg tables unless a later issue explicitly introduces safe support.
- Prefer full-refresh idempotent behavior in the initial implementation.

## Local quality commands

Run before opening or updating a PR:

```bash
make ci-pr
```

Run before pushing:

```bash
make pre-push
```

Install hooks with:

```bash
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
pre-commit install --install-hooks
pre-commit install --hook-type pre-push
```

## Testing expectations

- Python changes should include or update pytest coverage when behavior changes.
- dbt changes should compile and include relevant dbt tests.
- Kubernetes manifests should be valid YAML and pass validation when tooling is available.
- Dockerfile changes should build locally when possible.
- Documentation changes should keep links, commands and stage references consistent.

## Pull request expectations

Every PR should include:

- title containing a GitHub issue reference, such as `(#2)`;
- linked issue in the body using `Closes #<issue>` or `Refs #<issue>`;
- concise summary of what changed;
- commands executed for validation;
- known limitations or follow-up tasks.

## Codex working rules

- Read `docs/project-plan.md` before making architecture-level changes.
- Read the relevant issue before implementing a stage.
- Use the repository skills in `.agents/skills/` when the task matches their description.
- Prefer plan-first behavior for multi-file or architecture changes.
- Keep network usage minimal and avoid fetching untrusted content unless required.
- If a task requires a new dependency, explain why it is needed and prefer open source, local-first options.
- If unsure whether a change belongs in the current stage, update documentation or ask for clarification before expanding scope.

## Definition of done

A task is done when:

- requested files are created or updated;
- project conventions are followed;
- relevant local checks are documented or executed;
- issue checklists are updated when applicable;
- no unrelated scope is introduced.
