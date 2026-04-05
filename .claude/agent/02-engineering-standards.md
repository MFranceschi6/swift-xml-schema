# 02 - Engineering Standards

## API and Design Principles

- Public APIs must be explicit, typed, and stable.
- Prefer small value types over nested mutable state.
- Keep parser behavior deterministic and side-effect free beyond resolver I/O.
- Default to `internal`; expose only deliberate public surface.

## File Structure and Naming

- Main declarations live in `Type.swift`.
- Parsing and traversal logic can live in `Type+Logic.swift`.
- Keep model types top-level and standalone.

## Module Layout

| Module | Purpose |
|--------|---------|
| `SwiftXMLSchema` | XSD model, parser, schema-set assembly, resolver contracts |

## Multi-Version Swift Rules

- Use explicit `#if swift(>=x.y)` only when required by the supported lane set.
- Public behavior must stay consistent across manifests.

## Error Model

- Prefer typed public errors.
- Keep diagnostics stable and readable.
- Primary parser error type: `XMLSchemaParsingError`.

## Concurrency

- Public model types should be `Sendable`.
- Resolver implementations should avoid shared mutable state.

## Documentation Language

All source comments and repository documentation must be in English.
