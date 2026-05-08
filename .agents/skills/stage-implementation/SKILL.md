---
name: stage-implementation
description: Use this skill when implementing or updating a numbered project stage, GitHub issue, or stage-specific task in Open Lakehouse Lab.
---

# Stage Implementation Skill

## When to use

Use this skill for tasks related to issues named `[STAGE XX]`, stage planning, stage implementation, or stage closure.

## Required context

Before changing files:

1. Read `docs/project-plan.md`.
2. Read `AGENTS.md`.
3. Read the relevant GitHub issue.
4. Identify previous and next stage dependencies.

## Workflow

1. Confirm the target stage and its Definition of Done.
2. Implement only the scope described in the issue.
3. Keep changes small and easy to review.
4. Update documentation when behavior or commands change.
5. Run or document the relevant checks:

```bash
make ci-pr
```

6. Update the issue checklist when work is completed.
7. Reference the issue in commits or PRs with `Refs #<issue>` or `Closes #<issue>`.

## Output expectations

Summaries should include:

- files changed;
- commands executed;
- limitations;
- next recommended step.

## Do not

- Do not implement future stages early.
- Do not introduce cloud services.
- Do not add product dashboards unless explicitly requested.
- Do not bypass quality checks.
