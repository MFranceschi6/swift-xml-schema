# SwiftXMLSchema

[![Swift 5.4+](https://img.shields.io/badge/Swift-5.4%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

`SwiftXMLSchema` is the schema-focused satellite of the XML stack. It parses W3C XSD documents into a reusable, normalised schema model, assembles include/import/redefine graphs, and exposes typed APIs for downstream tooling — code generators, JSON-Schema exporters, schema differs, and beyond.

## Features

- **XSD parsing** — full W3C XML Schema 1.1 surface (complex/simple types, attribute and model groups, identity constraints, substitution groups, redefine, mixed content, notations).
- **Normalised schema set** — `XMLNormalizedSchemaSet` resolves inheritance, flattens groups, and pre-computes O(1) lookup indices keyed by `XMLQualifiedName`.
- **Visitor + walker** — `XMLSchemaVisitor` / `XMLSchemaWalker` drive a depth-first traversal over every component, ideal for code generation.
- **Schema diff** — `XMLSchemaDiffer` computes a structural diff between two schema sets and classifies each change as breaking or non-breaking.
- **Statistics** — `XMLNormalizedSchemaSet.statistics` exposes counts, inheritance depths, namespace breakdowns, and unreferenced-type detection.
- **JSON Schema export** — `XMLJSONSchemaExporter` produces a draft 2020-12 JSON Schema document from any normalised schema set.
- **SPM build plugin** — `XMLSchemaPlugin` generates a normalised JSON artefact (with SHA-256 fingerprint) for every `.xsd` file in a target.
- **Resource resolution** — local file, remote `http(s)`, OASIS catalog, and composite resolvers, with both sync and async APIs.
- **Diagnostics** — non-fatal `XMLSchemaParsingDiagnostic` collection alongside typed `XMLSchemaParsingError` throws (typed `throws` on Swift 6.0+).

Out of scope:

- XML instance validation against XSD
- SOAP or WSDL parsing
- Swift code generation (consumers can build it on top of the visitor API)

## Installation

```swift
.package(url: "https://github.com/your-org/swift-xml-schema.git", from: "1.0.0")
```

The package supports Swift 5.4 at runtime, with progressive opt-ins for Swift 5.6 (tooling), 5.9 (macros), 5.10 (quality lane), and the latest Swift toolchain.

## Documentation

Full DocC documentation is available in `Sources/SwiftXMLSchema/SwiftXMLSchema.docc/`. Generate locally with:

```sh
swift package generate-documentation --target SwiftXMLSchema
```

Articles cover Getting Started, the component model, the visitor/walker, the build plugin, JSON Schema export, and schema diff & statistics.

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
