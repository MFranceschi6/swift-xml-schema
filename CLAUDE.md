# CLAUDE.md — SwiftXMLSchema

Open-source Swift package for XSD parsing and schema-set assembly. SPM-only. Linux-compatible runtime. SOAP and WSDL stay out of scope.

## Compatibility Lanes

`runtime-5.4` | `tooling-5.6-plus` | `macro-5.9` | `quality-5.10` | `latest`

## Required Validation

```sh
swift build -c debug
swift test --enable-code-coverage
swiftlint lint
```

## Scope

- Standalone XSD parsing
- `XMLSchemaSet` assembly
- Local include/import resolution
- Namespace and QName resolution
- Parser diagnostics

Out of scope:

- SOAP and WSDL
- Code generation
- Runtime XML instance validation

## Workflow

- Search with Grep first.
- Keep public APIs typed and explicit.
- Update `CHANGELOG.md` for every completed technical task.
- Use neutral branch names: `ai/<slug>`.

## Deep-Dive Policy

- `agent.md`
- `.claude/agent/01-project-profile.md`
- `.claude/agent/02-engineering-standards.md`
- `.claude/agent/03-validation-and-quality-gates.md`
- `.claude/agent/04-workflow-reporting-and-commits.md`
- `.claude/agent/05-skills-and-context-organization.md`
