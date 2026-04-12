# Getting Started

Parse an XSD file and assemble a normalised schema set in a few lines of code.

## Overview

The two-step pipeline — parse, then normalise — maps directly onto two small APIs:

- ``XMLSchemaDocumentParser`` reads raw bytes and produces a ``XMLSchemaSet`` (the raw,
  denormalised parse tree).
- ``XMLSchemaNormalizer`` resolves cross-schema references, expands attribute groups and
  model groups, and produces an ``XMLNormalizedSchemaSet`` that is ready to query.

### Parsing from Data

If you already have the XSD in memory as `Data`:

```swift
import SwiftXMLSchema

let xsdData = Data("""
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:tns="urn:example" targetNamespace="urn:example">
  <xsd:complexType name="Order">
    <xsd:sequence>
      <xsd:element name="id"     type="xsd:string"/>
      <xsd:element name="amount" type="xsd:decimal"/>
    </xsd:sequence>
  </xsd:complexType>
  <xsd:element name="Order" type="tns:Order"/>
</xsd:schema>
""".utf8)

let parser = XMLSchemaDocumentParser()
let schemaSet = try parser.parse(data: xsdData)
```

### Parsing from a File URL

```swift
let url = URL(fileURLWithPath: "/path/to/orders.xsd")
let schemaSet = try XMLSchemaDocumentParser().parse(url: url)
```

Local `<xsd:import>` and `<xsd:include>` directives are resolved automatically relative
to the source URL via ``LocalFileXMLSchemaResourceResolver``.

### Normalising

```swift
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
```

After normalisation every ``XMLNormalizedComplexType`` carries both:

- `declaredContent` / `declaredAttributes` — components written directly in that type's
  body.
- `effectiveContent` / `effectiveAttributes` — the full inherited set after walking the
  extension/restriction chain.

### Querying the Normalised Set

```swift
// O(1) lookup by local name + optional namespace URI
if let order = normalized.complexType(named: "Order", namespaceURI: "urn:example") {
    for attr in order.effectiveAttributes {
        print(attr.name, attr.use ?? .optional)
    }
}

// Cross-schema flat iterators
let allElements = normalized.allElements
let allTypes    = normalized.allComplexTypes
```

### Typed Throws (Swift 6.0+)

On Swift 6.0 the parsing and normalisation calls declare
`throws(XMLSchemaParsingError)`, enabling exhaustive error handling:

```swift
do {
    let set = try XMLSchemaDocumentParser().parse(data: xsdData)
    let normalized = try XMLSchemaNormalizer().normalize(set)
} catch let error as XMLSchemaParsingError {
    switch error {
    case .invalidDocument(let msg):
        print("Malformed XSD:", msg)
    case .missingRequiredAttribute(let attr, _, _):
        print("Missing attribute:", attr)
    default:
        print("Parse error:", error)
    }
}
```

### Async Parsing (Swift 5.5+)

```swift
let normalized = try await XMLSchemaDocumentParser().parse(url: remoteURL)
```

The async overload uses the async variant of the resource resolver, which avoids
blocking threads with `URLSession`.

## Next Steps

- Validate XML documents against the schema: <doc:Validation>
- Flatten a multi-file schema into one XSD: <doc:SchemaFlattening>
- Infer a schema from XML instances: <doc:SchemaInference>
- Explore the full component model: <doc:WorkingWithTheComponentModel>
- Walk the schema tree with a visitor: <doc:VisitorAndWalker>
- Export to JSON Schema: <doc:JSONSchemaExport>
