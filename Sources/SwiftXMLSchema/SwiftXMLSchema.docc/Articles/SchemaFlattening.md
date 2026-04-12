# Schema Flattening

Convert a multi-file schema set into a single, import-free XSD document.

## Overview

``XMLSchemaFlattener`` takes an ``XMLNormalizedSchemaSet`` — which may have been assembled
from many XSD files connected by `<xsd:import>` and `<xsd:include>` directives — and produces
a single self-contained XSD `Data` value. The output contains no import or include directives,
no extension chains, and no restriction declarations: every type is fully expanded and
self-contained.

This is useful when distributing schemas to consumers who need a single file, feeding schemas
into tools that do not support multi-file sets, or archiving a resolved snapshot of a schema
that might otherwise depend on remote resources.

### Basic Usage

```swift
import SwiftXMLSchema

let parser     = XMLSchemaDocumentParser()
let normalizer = XMLSchemaNormalizer()
let flattener  = XMLSchemaFlattener()

// Parse a multi-file schema starting from the root XSD
let schemaSet  = try parser.parse(url: URL(fileURLWithPath: "/path/to/root.xsd"))
let normalized = try normalizer.normalize(schemaSet)

// Flatten into a single document
let flatXSD = try flattener.flatten(normalized)

// Write to disk or pass to another tool
try flatXSD.write(to: URL(fileURLWithPath: "/path/to/flat.xsd"))
```

### Flattening Semantics

The flattener works on the **effective content** computed by the normalizer:

- All model-group expansions are inlined — no `<xsd:group ref="..."/>` in the output.
- All attribute-group expansions are inlined — no `<xsd:attributeGroup ref="..."/>`.
- Extension and restriction chains are pre-applied — no `<xsd:extension>` or
  `<xsd:restriction>` in the output.
- Top-level elements, complex types, and simple types from every schema in the set are merged
  into one `<xsd:schema>` element.

### Namespace Handling

When the input set contains exactly one `targetNamespace`, that namespace is used automatically:

```swift
let flatXSD = try flattener.flatten(normalized)
```

When the set spans multiple namespaces, provide an explicit override:

```swift
let flatXSD = try flattener.flatten(normalized, targetNamespace: "urn:my-merged-namespace")
```

Calling ``XMLSchemaFlattener/flatten(_:)`` without an explicit namespace on a multi-namespace set
throws ``XMLSchemaFlattenerError/ambiguousNamespace(_:)`` with the list of conflicting namespaces:

```swift
do {
    let flat = try flattener.flatten(normalized)
} catch XMLSchemaFlattenerError.ambiguousNamespace(let namespaces) {
    print("Conflicting namespaces:", namespaces.joined(separator: ", "))
}
```

Type references whose namespace differs from the output namespace are serialised as bare local
names (a documented v1 limitation). The flattener logs a `.warning` for each such reference.

### Injecting a Logger

```swift
import Logging

var logger = Logger(label: "com.example.flattener")
logger.logLevel = .debug
let flattener = XMLSchemaFlattener(logger: logger)
```

Log levels used:
- `.debug` — start and completion with type/element counts
- `.trace` — per complex type, simple type, and element serialised
- `.warning` — cross-namespace type references that fall back to bare local names

## See Also

- ``XMLSchemaFlattenerError``
- ``XMLSchemaNormalizer``
- ``XMLNormalizedSchemaSet``
- <doc:GettingStarted>
