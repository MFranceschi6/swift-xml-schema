# 04 - Workflow, Reporting, and Commits

## Branching

- Use dedicated task branches.
- Default branch prefix: `ai/<slug>`.

## Execution Workflow

1. Confirm scope and lane constraints.
2. Keep public API changes deliberate.
3. Implement incrementally.
4. Add or update tests.
5. Run validation gates.
6. Update docs and `CHANGELOG.md`.
7. Produce a short technical report when the step is non-trivial.

## Completion Discipline

A step is done only if:
- behavior is implemented end-to-end,
- required tests exist and pass,
- required validation commands were run,
- `CHANGELOG.md` is updated.

## Commit Policy

- Use selective staging.
- Keep commit messages consistent and readable.
- Gitmoji prefix is preferred.
