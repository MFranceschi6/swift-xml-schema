# agent.md

Primary multi-agent policy entrypoint for `SwiftXMLSchema`.

## Repository Identity

- Package: `SwiftXMLSchema`
- Role: XSD parser and schema-set satellite
- Boundary: no SOAP, no WSDL, no code generation

## Validation Gates

- `swift build -c debug`
- `swift test --enable-code-coverage`
- `swiftlint lint`
- Package line coverage must stay above `90%`.

## Active Deep-Dive Modules

- `.claude/agent/01-project-profile.md`
- `.claude/agent/02-engineering-standards.md`
- `.claude/agent/03-validation-and-quality-gates.md`
- `.claude/agent/04-workflow-reporting-and-commits.md`
- `.claude/agent/05-skills-and-context-organization.md`

## Active Plans

- `.claude/plans/bootstrap-roadmap.md`
- `.claude/plans/release-0.1.md`
