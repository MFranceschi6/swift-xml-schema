# 03 - Validation and Quality Gates

## Required Commands

- `swift build -c debug`
- `swift test --enable-code-coverage`
- `swiftlint lint`

## Coverage and Tests

- Bug fixes require regression tests.
- Feature work must cover core and edge-case parsing behavior.
- Tests must be deterministic and avoid real network access.
- Package line coverage must remain above `90%`.

## Test Structure

Tests live in `Tests/SwiftXMLSchemaTests/` and cover:
- standalone XSD parsing,
- include/import recursion,
- namespace and QName resolution,
- duplicate-name diagnostics,
- unresolved-reference diagnostics.

## Validation Policy

- Partial checks are fine during iteration.
- Final closure requires all three commands.
