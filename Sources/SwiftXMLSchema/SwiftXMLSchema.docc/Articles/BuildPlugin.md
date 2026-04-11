# Build Plugin

Generate a normalised JSON schema artefact from XSD files at build time using the
`XMLSchemaPlugin` SPM build tool plugin.

## Overview

The `XMLSchemaPlugin` plugin scans each `.xsd` file that is a source of the consuming
target and produces two artefacts in the build output directory:

| Output | Description |
|---|---|
| `<name>.schema.json` | Normalised ``XMLNormalizedSchemaSet`` encoded as JSON |
| `<name>.schema.json.sha256` | SHA-256 hex digest of the JSON for cache invalidation |

The JSON format is documented in `SCHEMA_FORMAT.md` at the repository root. It is
language-agnostic: code generators written in any language can consume it without
depending on SwiftXMLSchema itself.

## Setting Up the Plugin

### 1. Add SwiftXMLSchema as a Dependency

In your package manifest (Swift 5.6 or later):

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/your-org/SwiftXMLSchema.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            plugins: [
                .plugin(name: "XMLSchemaPlugin", package: "SwiftXMLSchema")
            ]
        )
    ]
)
```

### 2. Add XSD Files to Your Target

Place `.xsd` files in your target's source directory. The plugin picks up every file
with a `.xsd` suffix automatically — no additional configuration is required.

```
Sources/MyApp/
  orders.xsd
  products.xsd
  MyApp.swift
```

### 3. Build

```sh
swift build
```

The plugin runs `XMLSchemaTool` for each XSD file. The generated JSON files land in
the SPM plugin work directory (`.build/plugins/outputs/MyApp/XMLSchemaPlugin/`).

## Generated JSON Format

The JSON envelope looks like this:

```json
{
  "schemaVersion": 1,
  "schemas": [
    {
      "targetNamespace": "urn:orders",
      "complexTypes": [ ... ],
      "simpleTypes": [ ... ],
      "elements": [ ... ]
    }
  ]
}
```

`XMLNormalizedSchemaSet` is `Codable`, so you can load the artefact at runtime:

```swift
let data = try Data(contentsOf: outputURL)
let schemaSet = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: data)
```

Or verify the fingerprint before loading:

```swift
let json      = try Data(contentsOf: jsonURL)
let stored    = try String(contentsOf: sha256URL, encoding: .utf8).trimmingCharacters(in: .whitespaces)
let schemaSet = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: json)
let computed  = schemaSet.fingerprint   // nil on Linux without CryptoKit
if let computed, computed != stored {
    fatalError("Schema fingerprint mismatch — regenerate the build artefact")
}
```

## Running XMLSchemaTool Directly

The `XMLSchemaTool` executable is also available as a standalone CLI:

```sh
swift run XMLSchemaTool path/to/input.xsd path/to/output.schema.json
```

This is useful for CI pipelines that pre-generate the JSON and commit it to the
repository, skipping the plugin entirely.

## Schema Fingerprinting

``XMLNormalizedSchemaSet/fingerprint`` returns the lowercase hex SHA-256 digest of the
canonical (sorted-keys, pretty-printed) JSON encoding. The fingerprint:

- Is stable across invocations on the same schema.
- Changes whenever any component, type name, or field value changes.
- Is available only when `CryptoKit` can be imported (Apple platforms + Linux with
  the `swift-crypto` shim).

Use the fingerprint in CI to detect schema drift between committed artefacts and the
current XSD source files.
