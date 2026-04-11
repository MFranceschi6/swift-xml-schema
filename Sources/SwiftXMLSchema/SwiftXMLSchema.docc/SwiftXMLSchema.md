# ``SwiftXMLSchema``

Parse XSD documents, assemble schema sets, and navigate the normalised component model.

## Overview

SwiftXMLSchema is a Swift Package Manager library for reading W3C XML Schema (XSD) files and
assembling them into a strongly-typed, navigable component model. It is standalone — no SOAP,
no WSDL, no runtime XML instance validation.

**Typical pipeline:**

1. Feed raw XSD data into ``XMLSchemaDocumentParser`` → ``XMLSchemaSet``
2. Normalise with ``XMLSchemaNormalizer`` → ``XMLNormalizedSchemaSet``
3. Query, walk, diff, or export the normalised set

### Quick Start

```swift
import SwiftXMLSchema

// 1. Parse
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

let schemaSet  = try XMLSchemaDocumentParser().parse(data: xsdData)

// 2. Normalise — resolves inheritance, flattens groups, builds O(1) lookup indices
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)

// 3. Look up a type by name and namespace
if let order = normalized.complexType(named: "Order", namespaceURI: "urn:orders") {
    for element in order.effectiveSequence {
        print(element.name, "→", element.typeQName?.localName ?? "?")
    }
}
// id → string
// amount → decimal
```

For multi-file schemas, pass the source file URL so that relative `<xsd:import>` and
`<xsd:include>` paths resolve automatically:

```swift
let url       = URL(fileURLWithPath: "/path/to/orders.xsd")
let schemaSet = try XMLSchemaDocumentParser().parse(url: url)
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
```

### Core Types at a Glance

| Type | Role |
|---|---|
| ``XMLSchemaDocumentParser`` | Parses raw XSD bytes into a raw ``XMLSchemaSet`` |
| ``XMLSchemaNormalizer`` | Resolves references, computes effective content → ``XMLNormalizedSchemaSet`` |
| ``XMLNormalizedSchemaSet`` | O(1)-indexed component model: types, elements, attributes, groups |
| ``XMLSchemaWalker`` | Depth-first traversal driven by an ``XMLSchemaVisitor`` |
| ``XMLSchemaDiffer`` | Structural diff between two schema sets |
| ``XMLJSONSchemaExporter`` | Converts a normalised schema set to JSON Schema draft 2020-12 |

## Topics

### Getting Started

- <doc:GettingStarted>
- ``XMLSchemaDocumentParser``
- ``XMLSchemaNormalizer``
- ``XMLSchemaSet``
- ``XMLNormalizedSchemaSet``

### Component Model

- <doc:WorkingWithTheComponentModel>
- ``XMLNormalizedComplexType``
- ``XMLNormalizedSimpleType``
- ``XMLNormalizedElementDeclaration``
- ``XMLNormalizedAttributeDefinition``
- ``XMLNormalizedAttributeGroup``
- ``XMLNormalizedModelGroup``
- ``XMLNormalizedSchema``

### Visitor and Walker

- <doc:VisitorAndWalker>
- ``XMLSchemaVisitor``
- ``XMLSchemaWalker``

### Build Plugin

- <doc:BuildPlugin>

### JSON Schema Export

- <doc:JSONSchemaExport>
- ``XMLJSONSchemaExporter``
- ``XMLJSONSchemaDocument``

### Schema Diff and Statistics

- <doc:SchemaDiffAndStatistics>
- ``XMLSchemaDiffer``
- ``XMLSchemaDiff``
- ``XMLSchemaStatistics``

### Diagnostics and Error Model

- ``XMLSchemaParsingError``
- ``XMLSchemaSourceLocation``
- ``XMLSchemaParsingDiagnostic``

### Resource Resolution

- ``XMLSchemaResourceResolver``
- ``LocalFileXMLSchemaResourceResolver``
- ``RemoteXMLSchemaResourceResolver``
- ``CatalogXMLSchemaResourceResolver``
- ``CompositeXMLSchemaResourceResolver``
