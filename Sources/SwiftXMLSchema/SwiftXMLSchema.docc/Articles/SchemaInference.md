# Schema Inference

Generate an XSD schema from one or more XML instance documents.

## Overview

``XMLSchemaInferrer`` walks XML instance documents and produces a single-file XSD `Data` value
that describes the structure it observes. This is useful for reverse-engineering a schema when
only instance data is available, bootstrapping a schema to refine manually, or quickly generating
a draft XSD from a set of sample documents.

### Basic Usage

```swift
import SwiftXMLSchema

let inferrer = XMLSchemaInferrer()

// Single sample
let xsdData = try inferrer.infer(from: xmlData)

// Multiple samples — types and occurrence bounds are widened across all documents
let xsdData = try inferrer.infer(from: [xml1, xml2, xml3])
```

The returned `Data` is a well-formed XSD document that can be passed directly to
``XMLSchemaDocumentParser`` for further processing:

```swift
let schemaSet  = try XMLSchemaDocumentParser().parse(data: xsdData)
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
```

### Type Inference

The inferrer examines each element's text content and infers the most specific XSD scalar type
that is compatible with every sample. The widening ladder from most to least specific is:

```
xsd:boolean → xsd:integer → xsd:decimal → xsd:date → xsd:dateTime → xsd:string
```

When multiple samples provide conflicting content (e.g. `"42"` in one sample and `"3.14"` in
another), the type is widened to the common ancestor (`xsd:decimal` in this case).

### Occurrence Inference

| Observation | Result |
|---|---|
| Element absent in at least one sample | `minOccurs="0"` |
| Element present in every sample | `minOccurs="1"` (default) |
| Element appears more than once within a single parent instance | `maxOccurs="unbounded"` |

### Attribute Inference

| Observation | Result |
|---|---|
| Attribute present in every sample | `use="required"` |
| Attribute absent in at least one sample | `use="optional"` |

### Simple Content with Attributes

When an element has both text content and attributes, the inferrer emits a `<xsd:simpleContent>`
complex type:

```xml
<xsd:complexType name="price">
  <xsd:simpleContent>
    <xsd:extension base="xsd:decimal">
      <xsd:attribute name="currency" type="xsd:string" use="required"/>
    </xsd:extension>
  </xsd:simpleContent>
</xsd:complexType>
```

### Known v1 Limitations

- Recursion and type reuse are not detected — every element is expanded inline regardless of
  whether it appears elsewhere in the document.
- Namespace inference uses the root element's `namespaceURI`; mixed namespaces within one
  document are not handled.
- Pattern, enumeration, and length facets are not inferred — the output uses unconstrained
  base types.

### Injecting a Logger

```swift
import Logging

var logger = Logger(label: "com.example.inferrer")
logger.logLevel = .debug
let inferrer = XMLSchemaInferrer(logger: logger)
```

Log levels used:
- `.debug` — start with sample count and root element name, completion with output byte count
- `.trace` — per-sample processing index

## See Also

- ``XMLSchemaDocumentParser``
- ``XMLSchemaNormalizer``
- ``XMLSchemaFlattener``
- <doc:SchemaFlattening>
- <doc:GettingStarted>
