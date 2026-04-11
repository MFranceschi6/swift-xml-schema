# SwiftXMLSchema

[![Swift 5.4+](https://img.shields.io/badge/Swift-5.4%2B-orange)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

`SwiftXMLSchema` parses W3C XSD documents into a strongly-typed, normalised schema model. It assembles include/import/redefine graphs and exposes typed APIs for downstream tooling — code generators, JSON Schema exporters, schema differs, and beyond.

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

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/MFranceschi6/swift-xml-schema.git", from: "1.0.0")
```

Then add `SwiftXMLSchema` to your target's dependencies:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SwiftXMLSchema", package: "swift-xml-schema")
    ]
)
```

The package supports Swift 5.4 at runtime, with progressive opt-ins for Swift 5.6 (tooling), 5.9 (macros), 5.10 (quality lane), and the latest Swift toolchain.

## Quick Start

The core pipeline is two steps: **parse**, then **normalise**.

```swift
import SwiftXMLSchema

// 1. Parse raw XSD bytes
let xsdData = Data("""
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:tns="urn:orders" targetNamespace="urn:orders">
  <xsd:complexType name="Order">
    <xsd:sequence>
      <xsd:element name="id"     type="xsd:string"/>
      <xsd:element name="amount" type="xsd:decimal"/>
    </xsd:sequence>
  </xsd:complexType>
  <xsd:element name="Order" type="tns:Order"/>
</xsd:schema>
""".utf8)

let schemaSet = try XMLSchemaDocumentParser().parse(data: xsdData)

// 2. Normalise — resolves inheritance, flattens groups, builds lookup indices
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)

// 3. Query
if let order = normalized.complexType(named: "Order", namespaceURI: "urn:orders") {
    for element in order.effectiveSequence {
        print(element.name, "→", element.typeQName?.localName ?? "?")
    }
}
// id → string
// amount → decimal
```

### Walking the Schema Tree

Use `XMLSchemaWalker` with a custom `XMLSchemaVisitor` for depth-first traversal:

```swift
struct ElementCollector: XMLSchemaVisitor {
    var names: [String] = []
    mutating func visitElement(_ element: XMLNormalizedElementDeclaration) {
        names.append(element.name)
    }
}

var collector = ElementCollector()
XMLSchemaWalker(schemaSet: normalized).walkComponents(visitor: &collector)
print(collector.names) // ["Order"]
```

### Detecting Breaking Changes

```swift
let differ = XMLSchemaDiffer()
let diff   = differ.diff(old: previousSchema, new: currentSchema)

if diff.hasBreakingChanges {
    for entry in diff.breakingComplexTypeChanges {
        print("BREAKING change in '\(entry.name)'")
    }
}
```

### Exporting to JSON Schema

```swift
let exporter  = XMLJSONSchemaExporter()
let document  = exporter.export(normalized)
let jsonData  = try JSONEncoder().encode(document)
```

## Documentation

Full DocC documentation is available in `Sources/SwiftXMLSchema/SwiftXMLSchema.docc/`. Generate locally with:

```sh
swift package generate-documentation --target SwiftXMLSchema
```

Articles cover:

- Getting Started — parse, normalise, and query
- Working with the Component Model — lookups, inheritance, substitution groups
- Visitor and Walker — depth-first traversal and code-generation patterns
- JSON Schema Export — XSD-to-JSON-Schema conversion and mapping rules
- Schema Diff and Statistics — breaking-change detection and aggregate metrics
- Build Plugin — generate schema artefacts at build time via the SPM plugin

## Development Scripts

- `scripts/install-git-hooks.sh`
- `scripts/ci-local-matrix.sh`

## License

MIT — see [LICENSE](LICENSE).
