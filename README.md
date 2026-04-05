# SwiftXMLSchema

[![Swift 5.6+](https://img.shields.io/badge/Swift-5.6%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

`SwiftXMLSchema` is the schema-focused satellite for the XML stack. It parses XSD documents into a reusable schema model, assembles local include/import graphs, and exposes a standalone `XMLSchemaSet` for other tools.

## Current Scope

- Standalone XSD parsing
- `XMLSchemaSet` assembly
- Local file include/import resolution
- QName and namespace resolution
- Internal schema consistency checks

Out of scope for `0.1`:

- XML instance validation against XSD
- SOAP or WSDL parsing
- Code generation

## Bootstrap Dependency

The current bootstrap uses a local path dependency on the sibling core repo:

```swift
.package(path: "../swift-xml-coder")
```

## AI Workflow

- Root policy entrypoints:
  - `CLAUDE.md`
  - `AGENTS.md`
  - `agent.md`
- Deep-dive policy lives in `.claude/agent/`
- Active plans live in `.claude/plans/`
- Technical reports live in `.claude/reports/`
- Reusable workflows live in `.claude/skills/`

Before closing technical work, run:

```sh
swift build -c debug
swift test --enable-code-coverage
swiftlint lint
```

## Development Scripts

- `scripts/install-git-hooks.sh`
- `scripts/ci-local-matrix.sh`

## License

MIT — see [LICENSE](LICENSE).
