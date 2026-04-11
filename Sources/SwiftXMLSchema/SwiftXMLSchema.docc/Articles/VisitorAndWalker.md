# Visitor and Walker

Traverse every component in a normalised schema set using the type-safe visitor protocol.

## Overview

``XMLSchemaWalker`` drives a depth-first walk of an ``XMLNormalizedSchemaSet``. You
supply a value that conforms to ``XMLSchemaVisitor`` and the walker calls the appropriate
`visit` method for each component it encounters.

The visitor uses a *primary associated type* `Result` (Swift 5.7+). When `Result == Void`
every method has a default no-op implementation, so you only need to override the methods
you care about.

### A Simple Visitor

```swift
import SwiftXMLSchema

struct ElementCollector: XMLSchemaVisitor {
    typealias Result = Void

    var elementNames: [String] = []

    mutating func visitElement(_ element: XMLNormalizedElementDeclaration) {
        elementNames.append(element.name)
    }
}

var collector = ElementCollector()
XMLSchemaWalker(schemaSet: normalizedSet).walkComponents(visitor: &collector)
print(collector.elementNames)
```

The visitor is taken `inout` so value-type conformers can accumulate state across the
entire walk without heap allocation.

### Collecting Results

When your visitor has a non-`Void` result type, use `walkComponents(collecting:)`:

```swift
struct TypeNameVisitor: XMLSchemaVisitor {
    typealias Result = String

    func visitComplexType(_ type: XMLNormalizedComplexType) -> String {
        type.name
    }
}

let names = XMLSchemaWalker(schemaSet: normalized)
    .walkComponents(collecting: TypeNameVisitor())
// names: [String] — one entry per complex type visited
```

### What the Walker Visits

The walker performs a single depth-first pass in this order:

1. For each schema in the set (in declaration order):
   a. All top-level element declarations
   b. All named complex types — for each:
      - `effectiveContent` nodes (elements, choices, wildcards)
      - `effectiveAttributes`
   c. All named simple types
   d. All attribute group definitions
   e. All model group definitions

Anonymous complex types (synthesised inline by the normalizer) are included in the
walk under the parent element's type; they do **not** appear in the top-level complex
type iteration.

### Class-Based Visitors

If you prefer a class:

```swift
final class SchemaAuditor: XMLSchemaVisitor {
    typealias Result = Void
    var abstractTypes: [String] = []

    func visitComplexType(_ type: XMLNormalizedComplexType) {
        if type.isAbstract { abstractTypes.append(type.name) }
    }
}

let auditor = SchemaAuditor()
var auditorMut = auditor  // class ref is copyable; inout here is trivial
XMLSchemaWalker(schemaSet: normalized).walkComponents(visitor: &auditorMut)
print(auditor.abstractTypes)
```

### Using the Walker for Code Generation

A common pattern for code generators is to extend the visitor with a `context` carrying
the output buffer:

```swift
struct SwiftEmitter: XMLSchemaVisitor {
    typealias Result = Void

    var output = ""

    mutating func visitComplexType(_ type: XMLNormalizedComplexType) {
        output += "struct \(type.name) {\n"
        for elem in type.effectiveSequence {
            let swiftType = mapXSDType(elem.typeQName)
            output += "    var \(elem.name): \(swiftType)\n"
        }
        output += "}\n\n"
    }

    private func mapXSDType(_ qname: XMLQualifiedName?) -> String {
        switch qname?.localName {
        case "string": return "String"
        case "int", "integer": return "Int"
        case "boolean": return "Bool"
        default: return qname?.localName ?? "Any"
        }
    }
}

var emitter = SwiftEmitter()
XMLSchemaWalker(schemaSet: normalized).walkComponents(visitor: &emitter)
print(emitter.output)
```
