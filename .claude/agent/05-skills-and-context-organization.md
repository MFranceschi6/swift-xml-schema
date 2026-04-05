# 05 - Skills and Context Organization

## Goal

Keep agent context small and reusable by storing repeatable workflows as repository skills.

## Repository Skill Layout

- `.claude/skills/<skill-name>/SKILL.md`

Optional companion folders:
- `references/`
- `templates/`
- `scripts/`

## Activation Rules

- Load only the minimum skills needed for the task.
- Prefer progressive context loading.
- Do not bulk-read reports or plans unless they are relevant to the active task.

## Baseline Skills

- `baseline-validation`
- `step-report-and-changelog`
- `commit-checkpoint`
- `plan-status`
