---
name: technical-documentation
description: Use this skill for README updates, architecture documentation, ADRs, runbooks, data contracts, project plans, and educational documentation.
---

# Technical Documentation Skill

## Scope

Use this skill when working under:

```text
docs/
metadata/data-contracts/
README.md
AGENTS.md
.agents/
```

## Documentation principles

- The project is an educational study lab.
- Documentation should be practical and executable.
- Prefer clear examples over abstract explanations.
- Keep file names in English.
- Portuguese content is acceptable when it improves learning for the intended audience.
- Document limitations honestly.

## Required documentation types

- Architecture overview.
- ADRs for important decisions.
- Runbooks for operational procedures.
- Data contracts for sources and tables.
- Quickstart commands.
- Troubleshooting notes.

## ADR expectations

ADRs should include:

- status;
- context;
- decision;
- consequences;
- alternatives considered when useful.

## Runbook expectations

Runbooks should include:

- symptoms;
- likely causes;
- diagnostic commands;
- recovery steps;
- validation steps.

## Validation

Run or document:

```bash
make docs-check
make lint-yaml
```

## Do not

- Do not overstate production readiness.
- Do not hide limitations.
- Do not introduce cloud-specific assumptions as mandatory.
