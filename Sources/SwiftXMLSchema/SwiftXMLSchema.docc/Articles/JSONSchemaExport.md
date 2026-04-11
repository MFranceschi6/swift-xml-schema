# JSON Schema Export

Convert a normalised XSD schema set to JSON Schema draft 2020-12.

## Overview

``XMLJSONSchemaExporter`` converts an ``XMLNormalizedSchemaSet`` into an
``XMLJSONSchemaDocument`` that conforms to JSON Schema draft 2020-12. The output is
fully `Encodable` — pass it to `JSONEncoder` to get a ready-to-use `.json` file.

This enables interoperability with REST/OpenAPI toolchains that consume JSON Schema
instead of XSD.

## Basic Usage

```swift
import SwiftXMLSchema

let exporter  = XMLJSONSchemaExporter()
let document  = exporter.export(normalizedSet)

let encoder   = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let jsonData  = try encoder.encode(document)
try jsonData.write(to: URL(fileURLWithPath: "schema.json"))
```

### Custom Title

```swift
let document = exporter.export(normalizedSet, title: "Orders API Schema")
```

When `title` is omitted it defaults to the first schema's `targetNamespace`.

## Mapping Rules

### Complex Types → Object Definitions

Each named complex type becomes an entry under `$defs`:

```json
{
  "$defs": {
    "Order": {
      "type": "object",
      "properties": {
        "id":     { "type": "string" },
        "amount": { "type": "number" }
      },
      "required": ["id", "amount"]
    }
  }
}
```

- Required fields: elements where `minOccurs >= 1`.
- Optional fields: elements where `minOccurs == 0` (omitted from `required`).
- Repeated fields (`maxOccurs > 1`): wrapped in `{ "type": "array", "items": ... }`.

### Simple Types → Enumerations

Simple types with `<xsd:enumeration>` facets become `enum` arrays:

```json
{
  "$defs": {
    "Status": { "enum": ["open", "closed", "pending"] }
  }
}
```

`list` derivation produces `{ "type": "array" }`.  
`union` derivation produces `{ "anyOf": [...] }`.

### Type Inheritance → `allOf`

Extension types use `allOf` to compose the base schema reference with the new properties:

```json
{
  "$defs": {
    "PriorityOrder": {
      "allOf": [
        { "$ref": "#/$defs/Order" },
        { "type": "object", "properties": { "priority": { "type": "integer" } } }
      ]
    }
  }
}
```

### XSD Built-in Type Mapping

| XSD type | JSON Schema |
|---|---|
| `xsd:string`, `xsd:token`, `xsd:anyURI`, `xsd:ID`, `xsd:IDREF` | `"type": "string"` |
| `xsd:int`, `xsd:long`, `xsd:integer`, `xsd:positiveInteger`, … | `"type": "integer"` |
| `xsd:decimal`, `xsd:float`, `xsd:double` | `"type": "number"` |
| `xsd:boolean` | `"type": "boolean"` |
| `xsd:date` | `"type": "string", "format": "date"` |
| `xsd:dateTime` | `"type": "string", "format": "date-time"` |
| `xsd:time` | `"type": "string", "format": "time"` |
| `xsd:duration` | `"type": "string", "format": "duration"` |
| `xsd:base64Binary` | `"type": "string", "format": "byte"` |

### Facet Propagation

Facets from ``XMLSchemaFacetSet`` are mapped to their JSON Schema equivalents:

| XSD Facet | JSON Schema keyword |
|---|---|
| `minLength` / `maxLength` / `length` | `minLength` / `maxLength` |
| `pattern` | `pattern` |
| `minInclusive` / `maxInclusive` | `minimum` / `maximum` |
| `minExclusive` / `maxExclusive` | `exclusiveMinimum` / `exclusiveMaximum` |
| `enumeration` | `enum` |

### Wildcards

Elements declared with `<xsd:any>` or types with `anyAttribute` produce
`"additionalProperties": true` in the enclosing object.

## Output Structure

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "urn:orders",
  "type": "object",
  "properties": {
    "Order": { "$ref": "#/$defs/Order" }
  },
  "$defs": {
    "Order": { ... },
    "Status": { ... }
  }
}
```

Top-level element declarations appear in the root `properties` object, each referencing
the corresponding `$defs` entry (or an inline definition when the element's type is
anonymous).
