# Working with the Component Model

Navigate the normalised schema set: look up types, traverse inheritance chains, and
enumerate components by namespace.

## Overview

``XMLNormalizedSchemaSet`` is the central data structure produced by
``XMLSchemaNormalizer``. It holds:

- All named complex types, simple types, element declarations, attribute declarations,
  attribute groups, and model groups from every schema that was loaded.
- Pre-computed O(1) indices so that every lookup by qualified name is a dictionary read.
- Pre-computed derivation indices for `baseComplexType(of:)` / `derivedComplexTypes(of:)`.

### O(1) Component Lookups

Every lookup method accepts a local name and an optional namespace URI. When a namespace
URI is supplied, the qualified index is consulted first; if that misses, the bare
(namespace-agnostic) index is used as a fallback.

```swift
// By local name + namespace
let order = normalized.complexType(named: "Order", namespaceURI: "urn:example")

// By XMLQualifiedName (convenience overload)
import SwiftXMLCoder
let qname = XMLQualifiedName(localName: "Order", namespaceURI: "urn:example")
let order = normalized.complexType(qname)
```

Available lookup methods: `element(_:)`, `complexType(_:)`, `simpleType(_:)`,
`attribute(_:)`, `attributeGroup(_:)`, `modelGroup(_:)`, `rootElementBinding(forTypeNamed:namespaceURI:)`.

### Flat Cross-Schema Iterators

When you need all components regardless of which schema they came from:

```swift
for ct in normalized.allComplexTypes {
    print(ct.namespaceURI ?? "(no ns)", ct.name)
}

// Other iterators:
// normalized.allSimpleTypes
// normalized.allElements
// normalized.allAttributeDefinitions
// normalized.allAttributeGroups
// normalized.allModelGroups
```

### Effective Content vs. Declared Content

A complex type that extends a base type inherits all of the base's content and
attributes. `effectiveContent` and `effectiveAttributes` always give you the complete,
inherited view:

```swift
guard let shipOrder = normalized.complexType(named: "ShipOrder",
                                             namespaceURI: "urn:orders") else { return }

// Only the fields this type adds itself
let declaredFields = shipOrder.effectiveSequence

// All fields including those inherited from base types
let allFields = shipOrder.effectiveContent.compactMap {
    if case .element(let use) = $0 { return use } else { return nil }
}
```

### Navigating Inheritance

```swift
// Parent type
if let base = normalized.baseComplexType(of: shipOrder) {
    print("Extends:", base.name)
}

// All types that directly extend `shipOrder`
let children = normalized.derivedComplexTypes(of: shipOrder)

// Simple-type derivation chain
if let status = normalized.simpleType(named: "StatusType", namespaceURI: "urn:orders"),
   let base  = normalized.baseSimpleType(of: status) {
    print("Derived from:", base.name)
}
```

### Substitution Groups

```swift
let members = normalized.substitutionGroupMembers(ofLocalName: "BaseElement",
                                                  namespaceURI: "urn:orders")
for member in members {
    print(member.name, "can substitute BaseElement")
}

// Direct membership test
let canSub = normalized.canSubstitute(concreteElement, for: abstractHead)
```

### Schema Statistics

For a quick overview of a loaded schema set — useful in diagnostics, tooling, and
CI gates — use the `statistics` property:

```swift
let stats = normalized.statistics
print("Complex types:", stats.totalComplexTypes)
print("Max inheritance depth:", stats.maxComplexTypeInheritanceDepth)
print("Unreferenced types:", stats.unreferencedComplexTypeNames)

for ns in stats.namespaceBreakdown {
    print(ns.namespace ?? "(none)",
          "→", ns.complexTypeCount, "complex,", ns.simpleTypeCount, "simple")
}
```

See <doc:SchemaDiffAndStatistics> for the full statistics API.
