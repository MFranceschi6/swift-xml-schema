# Schema Diff and Statistics

Detect breaking changes between schema versions and gather aggregate metrics about a
schema set.

## Overview

SwiftXMLSchema provides two complementary analysis tools:

- **``XMLSchemaDiffer``** computes a structural diff between two ``XMLNormalizedSchemaSet``
  values, classifying each change as breaking or non-breaking.
- **``XMLNormalizedSchemaSet/statistics``** produces aggregate metrics: component counts,
  inheritance depths, per-namespace breakdowns, and unreferenced type detection.

## Schema Diff

### Basic Usage

```swift
import SwiftXMLSchema

let differ = XMLSchemaDiffer()
let diff   = differ.diff(old: previousSchemaSet, new: currentSchemaSet)

if diff.isEmpty {
    print("No changes")
} else if diff.hasBreakingChanges {
    print("BREAKING changes detected")
    for entry in diff.breakingComplexTypeChanges {
        print("  complex type '\(entry.name)'")
        for field in entry.change.fieldChanges.filter(\.isBreaking) {
            print("    \(field.fieldName):", field.kind)
        }
    }
} else {
    print("Non-breaking changes only")
}
```

### What Is Compared

``XMLSchemaDiffer`` diffs three categories:

| Category | Property |
|---|---|
| Named complex types | ``XMLSchemaDiff/complexTypeChanges`` |
| Named simple types | ``XMLSchemaDiff/simpleTypeChanges`` |
| Top-level element declarations | ``XMLSchemaDiff/elementChanges`` |

Anonymous synthesised types are excluded.

### Change Kinds

Each entry wraps an ``XMLSchemaComponentChange``:

- `.added(T)` — component exists only in the new schema set. **Non-breaking.**
- `.removed(T)` — component existed only in the old schema set. **Always breaking.**
- `.modified(old:new:fieldChanges:)` — component present in both; structural fields
  differ. Breaking only when the individual ``XMLSchemaFieldChange`` values have
  `isBreaking == true`.

### Breaking Change Classification

| Change | Breaking? |
|---|---|
| Removing a type or element | Yes |
| Removing a required element from a complex type | Yes |
| Tightening occurrence bounds | Yes |
| Changing a field type | Yes |
| Adding a new required element | Yes |
| Adding an optional element or attribute | No |
| Adding a new type or element | No |
| Widening occurrence bounds | No |

### Filtered Views

```swift
let breaking = diff.breakingComplexTypeChanges  // [XMLSchemaComplexTypeDiff]
let added    = diff.complexTypeChanges.filter { 
    if case .added = $0.change { return true } else { return false }
}
```

## Schema Statistics

### Quick Metrics

```swift
let stats = normalizedSet.statistics

print("Complex types:", stats.totalComplexTypes)
print("Simple types: ", stats.totalSimpleTypes)
print("Elements:     ", stats.totalElements)
print("Attributes:   ", stats.totalAttributeDefinitions)
print("Attr groups:  ", stats.totalAttributeGroups)
print("Model groups: ", stats.totalModelGroups)
```

### Inheritance Depth

```swift
print("Max complex inheritance depth:", stats.maxComplexTypeInheritanceDepth)
print("Max simple inheritance depth: ", stats.maxSimpleTypeInheritanceDepth)
```

A root type (no base in this schema set) has depth 0. A type that extends one
in-schema-set base has depth 1, and so on. Cycles are guarded.

### Namespace Breakdown

```swift
for ns in stats.namespaceBreakdown {
    let label = ns.namespace ?? "(no namespace)"
    print(label, "→",
          ns.complexTypeCount, "complex,",
          ns.simpleTypeCount, "simple,",
          ns.elementCount, "elements")
}
```

Entries are sorted by namespace URI; the no-namespace entry (if any) sorts first
because its key is the empty string.

### Unreferenced Types

A named type is *unreferenced* when no element declaration, element use, attribute,
or other type in the schema set points to it via `typeQName`, `baseQName`,
`listItemQName`, or a union member.

```swift
if !stats.unreferencedComplexTypeNames.isEmpty {
    print("Possibly dead complex types:")
    stats.unreferencedComplexTypeNames.forEach { print(" ", $0) }
}

if !stats.unreferencedSimpleTypeNames.isEmpty {
    print("Possibly dead simple types:")
    stats.unreferencedSimpleTypeNames.forEach { print(" ", $0) }
}
```

Names are returned in `"namespace:localName"` form (bare `"localName"` for
no-namespace types), sorted lexicographically.

> Note: A type referenced only via a schema from a different domain that is not
> included in this ``XMLNormalizedSchemaSet`` will appear as unreferenced. This is
> expected — the detection is local to the loaded schema set.

### Using Statistics in CI

```swift
let stats = normalized.statistics
precondition(stats.maxComplexTypeInheritanceDepth <= 5,
             "Inheritance chain exceeds project limit")
if !stats.unreferencedComplexTypeNames.isEmpty {
    print("Warning: \(stats.unreferencedComplexTypeNames.count) unreferenced types")
}
```
