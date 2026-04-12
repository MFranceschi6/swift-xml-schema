# Validation

Validate XML instance documents against a parsed schema.

## Overview

``XMLSchemaValidator`` checks whether an XML document conforms to an ``XMLNormalizedSchemaSet``.
It works on the output of the standard parse → normalise pipeline, so no additional setup is
required beyond what you already do to work with the component model.

### Basic Usage

```swift
import SwiftXMLSchema

// 1. Parse and normalise the schema
let schemaSet  = try XMLSchemaDocumentParser().parse(data: xsdData)
let normalized = try XMLSchemaNormalizer().normalize(schemaSet)

// 2. Validate an XML instance
let validator = XMLSchemaValidator()
let result    = try validator.validate(data: xmlData, against: normalized)

if result.isValid {
    print("Document is valid")
} else {
    for error in result.errors {
        print("[\(error.path)] \(error.message)")
    }
}
```

### Validation Result

``XMLSchemaValidationResult`` carries all diagnostics found during validation:

```swift
result.isValid    // true when no error-severity diagnostics were found
result.errors     // [XMLSchemaValidationDiagnostic] — severity == .error
result.warnings   // [XMLSchemaValidationDiagnostic] — severity == .warning
```

Each ``XMLSchemaValidationDiagnostic`` provides:

- `path` — an XPath-like string locating the offending node (e.g. `/Order/items/item[2]`)
- `message` — a human-readable description of the issue
- `severity` — `.error` or `.warning`

### What Is Validated

| Check | Covered |
|---|---|
| Root element declared as top-level `<xsd:element>` | ✅ |
| Child element names and occurrence bounds (`minOccurs`/`maxOccurs`) | ✅ |
| Choice groups (exactly one branch must match) | ✅ |
| Required attributes (`use="required"`) present | ✅ |
| Prohibited attributes (`use="prohibited"`) absent | ✅ |
| Unknown attributes (when no `<xsd:anyAttribute>`) | ✅ |
| Simple type enumerations | ✅ |
| String-length facets (`length`, `minLength`, `maxLength`) | ✅ |
| Numeric range facets (`minInclusive`, `maxInclusive`, `minExclusive`, `maxExclusive`) | ✅ |
| Built-in XSD scalar types (integer subtypes, boolean, date, dateTime, decimal) | ✅ |
| `<xsd:simpleContent>` text value | ✅ |
| Open content (`<xsd:openContent>` mode `.interleave`/`.append`) | ✅ |

### Known v1 Limitations

- Strict sequence ordering is not enforced — child elements are counted but not
  order-checked within a sequence.
- Identity constraints (`<xsd:key>`, `<xsd:keyref>`, `<xsd:unique>`) are not evaluated.
- Pattern facets (regex) are not evaluated.
- Substitution group compatibility is not checked.
- Nillable element handling (`xsi:nil`) is not implemented.

### Open Content (XSD 1.1)

Types that declare `<xsd:openContent mode="interleave">` or `mode="append"` accept additional
child elements beyond those in the declared sequence. The validator skips the unknown-element
check for such types. Types with `mode="none"` — or no `<xsd:openContent>` at all — still
reject unexpected child elements.

```swift
// A type with openContent — "extra" is allowed
let xsd = """
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:element name="root" type="Open"/>
  <xsd:complexType name="Open">
    <xsd:sequence>
      <xsd:element name="id" type="xsd:string"/>
    </xsd:sequence>
    <xsd:openContent mode="interleave">
      <xsd:any processContents="lax"/>
    </xsd:openContent>
  </xsd:complexType>
</xsd:schema>
"""
let normalized = try XMLSchemaNormalizer().normalize(
    try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
)
let result = try XMLSchemaValidator().validate(
    data: Data("<root><id>1</id><extra>foo</extra></root>".utf8),
    against: normalized
)
// result.isValid == true
```

### Injecting a Logger

``XMLSchemaValidator`` follows the same injected-logger pattern as all other pipeline structs:

```swift
import Logging

var logger = Logger(label: "com.example.validator")
logger.logLevel = .trace
let validator = XMLSchemaValidator(logger: logger)
```

## See Also

- ``XMLSchemaDocumentParser``
- ``XMLSchemaNormalizer``
- ``XMLNormalizedSchemaSet``
- <doc:GettingStarted>
