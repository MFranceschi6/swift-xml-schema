# AGENTS.md

Compatibility bridge for agent frameworks other than Claude Code.
Primary policy source remains `agent.md`.

## Required Baseline

- Swift Package Manager only.
- Linux-compatible runtime behavior.
- Lane model:
  - `runtime-5.4`
  - `tooling-5.6-plus`
  - `macro-5.9`
  - `quality-5.10`
  - `latest`

## Mandatory Checks Before Closure

- `swift build -c debug`
- `swift test --enable-code-coverage`
- `swiftlint lint`
- Keep package line coverage above `90%`.

## Policy Modules

- `agent.md`
- `.claude/agent/01-project-profile.md`
- `.claude/agent/02-engineering-standards.md`
- `.claude/agent/03-validation-and-quality-gates.md`
- `.claude/agent/04-workflow-reporting-and-commits.md`
- `.claude/agent/05-skills-and-context-organization.md`

## Safety

- Do not perform destructive cleanup without explicit approval.
- Never revert unrelated local changes.
- Always update `CHANGELOG.md` for completed technical tasks.
