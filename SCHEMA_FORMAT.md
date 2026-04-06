# SwiftXMLSchema — Normalised Schema Model JSON Format

Version 1 · Stable from SwiftXMLSchema 0.6

---

## Overview

`XMLSchemaTool` and `XMLSchemaPlugin` emit a JSON file that represents a
fully normalised XSD schema set. The format is designed to be consumed by
code-generation tools written in any language (Swift, TypeScript, Kotlin, Go,
Rust, Python, …).

The format is a direct serialisation of `XMLNormalizedSchemaSet`. Consumers
that only care about generating code typically read `effectiveContent` and
`effectiveAttributes` from each complex type and can ignore the `declared*`
variants.

---

## Top-level structure

```json
{
  "schemaVersion": 1,
  "schemas": [ <XMLNormalizedSchema>, … ]
}
```

| Field | Type | Description |
|---|---|---|
| `schemaVersion` | `integer` | Format version. Currently `1`. Increment on incompatible changes. |
| `schemas` | `XMLNormalizedSchema[]` | One entry per parsed XSD document (including imported/included schemas). |

---

## XMLNormalizedSchema

```json
{
  "targetNamespace": "urn:types",
  "annotation": null,
  "elements": [ <XMLNormalizedElementDeclaration>, … ],
  "complexTypes": [ <XMLNormalizedComplexType>, … ],
  "simpleTypes": [ <XMLNormalizedSimpleType>, … ],
  "attributeDefinitions": [ <XMLNormalizedAttributeDefinition>, … ],
  "attributeGroups": [ <XMLNormalizedAttributeGroup>, … ],
  "modelGroups": [ <XMLNormalizedModelGroup>, … ]
}
```

| Field | Type | Description |
|---|---|---|
| `targetNamespace` | `string \| null` | The schema's target namespace URI, or `null` for no-namespace schemas. |
| `annotation` | `XMLSchemaAnnotation \| null` | Schema-level documentation/appinfo. |
| `elements` | array | Top-level element declarations. |
| `complexTypes` | array | Named complex type definitions. |
| `simpleTypes` | array | Named simple type definitions. |
| `attributeDefinitions` | array | Top-level attribute declarations. |
| `attributeGroups` | array | Named attribute group definitions. |
| `modelGroups` | array | Named model group definitions. |

---

## XMLNormalizedElementDeclaration

```json
{
  "componentID": { "rawValue": "urn:types|element|element/Order/0" },
  "name": "Order",
  "namespaceURI": "urn:types",
  "typeQName": { "localName": "OrderType", "namespaceURI": "urn:types", "prefix": "tns" },
  "nillable": false,
  "isAbstract": false,
  "defaultValue": null,
  "fixedValue": null,
  "substitutionGroup": null,
  "identityConstraints": [ <XMLSchemaIdentityConstraint>, … ],
  "occurrenceBounds": { "minOccurs": 1, "maxOccurs": 1 },
  "annotation": null
}
```

---

## XMLNormalizedComplexType

```json
{
  "componentID": { "rawValue": "urn:types|complexType|complexType/Order/0" },
  "name": "Order",
  "namespaceURI": "urn:types",
  "isAbstract": false,
  "isMixed": false,
  "isAnonymous": false,
  "baseQName": null,
  "baseDerivationKind": null,
  "simpleContentBaseQName": null,
  "simpleContentDerivationKind": null,
  "inheritedComplexTypeQName": null,
  "effectiveSimpleContentValueTypeQName": null,
  "declaredContent": [ <XMLNormalizedContentNode>, … ],
  "effectiveContent": [ <XMLNormalizedContentNode>, … ],
  "declaredAttributes": [ <XMLNormalizedAttributeUse>, … ],
  "effectiveAttributes": [ <XMLNormalizedAttributeUse>, … ],
  "anyAttribute": null,
  "annotation": null
}
```

**Tip for code generation**: read `effectiveContent` and `effectiveAttributes`
— they contain the fully-flattened content after resolving inheritance chains.
`declaredContent`/`declaredAttributes` reflect only what is explicitly written
in the XSD source for that type.

| Field | Notes |
|---|---|
| `baseDerivationKind` | `"extension"` or `"restriction"`, or `null` for root types. |
| `isMixed` | `true` if text nodes may appear between child elements. |
| `isAnonymous` | `true` for inline types synthesised from anonymous `<xsd:complexType>` children of elements. |
| `inheritedComplexTypeQName` | The resolved parent complex type after extension/restriction. |
| `effectiveSimpleContentValueTypeQName` | For simple-content types: the XSD built-in type that holds the text value. |

---

## XMLNormalizedContentNode (discriminated union)

Content nodes use a `{ "kind": "...", "value": { … } }` envelope:

### element

```json
{
  "kind": "element",
  "value": {
    "componentID": { "rawValue": "…" },
    "name": "id",
    "namespaceURI": "urn:types",
    "typeQName": { "localName": "string", "namespaceURI": "http://www.w3.org/2001/XMLSchema", "prefix": "xsd" },
    "nillable": false,
    "isAbstract": false,
    "defaultValue": null,
    "fixedValue": null,
    "substitutionGroup": null,
    "occurrenceBounds": { "minOccurs": 1, "maxOccurs": 1 },
    "annotation": null
  }
}
```

### choice

```json
{
  "kind": "choice",
  "value": {
    "occurrenceBounds": { "minOccurs": 1, "maxOccurs": 1 },
    "content": [ <XMLNormalizedContentNode>, … ]
  }
}
```

### wildcard

```json
{
  "kind": "wildcard",
  "value": {
    "kind": "element",
    "namespaceConstraint": "##any",
    "processContents": "lax",
    "minOccurs": 0,
    "maxOccurs": null
  }
}
```

Note: the inner `"kind"` inside a wildcard value is `XMLSchemaWildcardKind`
(`"element"` or `"attribute"`), distinct from the outer content-node kind.

---

## XMLNormalizedSimpleType

```json
{
  "componentID": { "rawValue": "urn:types|simpleType|simpleType/Status/0" },
  "name": "Status",
  "namespaceURI": "urn:types",
  "baseQName": { "localName": "string", "namespaceURI": "http://www.w3.org/2001/XMLSchema", "prefix": "xsd" },
  "derivationKind": "restriction",
  "enumerationValues": ["pending", "shipped", "cancelled"],
  "pattern": null,
  "facets": null,
  "listItemQName": null,
  "unionMemberQNames": [],
  "annotation": null
}
```

| `derivationKind` | `"restriction"` \| `"list"` \| `"union"` |
|---|---|
| `enumerationValues` | Non-empty for enumeration types. |
| `facets` | `XMLSchemaFacetSet` or `null`. Present when the type restricts a base with facets. |
| `listItemQName` | Set when `derivationKind == "list"`. |
| `unionMemberQNames` | Non-empty when `derivationKind == "union"`. |

---

## XMLSchemaFacetSet

```json
{
  "enumeration": [],
  "pattern": null,
  "minLength": 2,
  "maxLength": 10,
  "length": null,
  "minInclusive": null,
  "maxInclusive": null,
  "minExclusive": null,
  "maxExclusive": null,
  "totalDigits": null,
  "fractionDigits": null
}
```

---

## XMLNormalizedAttributeUse / XMLNormalizedAttributeDefinition

```json
{
  "componentID": { "rawValue": "…" },
  "name": "currency",
  "namespaceURI": "urn:types",
  "typeQName": { "localName": "string", "namespaceURI": "http://www.w3.org/2001/XMLSchema", "prefix": "xsd" },
  "use": "required",
  "defaultValue": null,
  "fixedValue": null,
  "annotation": null
}
```

`use` is `"required"`, `"optional"`, `"prohibited"`, or `null`.

---

## XMLSchemaIdentityConstraint

```json
{
  "kind": "key",
  "name": "orderKey",
  "selector": "order",
  "fields": ["@id"],
  "refer": null
}
```

| `kind` | `"key"` \| `"keyref"` \| `"unique"` |
|---|---|
| `selector` | XPath expression selecting the scope nodes. |
| `fields` | XPath expressions selecting the constrained fields. |
| `refer` | Set only for `"keyref"`: the referenced `key` or `unique` constraint. |

---

## XMLQualifiedName

```json
{
  "localName": "string",
  "namespaceURI": "http://www.w3.org/2001/XMLSchema",
  "prefix": "xsd"
}
```

`namespaceURI` and `prefix` may be `null`. Consumers should use
`localName` + `namespaceURI` for identity comparisons; `prefix` is a
syntactic hint and is NOT guaranteed to be stable across schema documents.

---

## XMLSchemaOccurrenceBounds

```json
{ "minOccurs": 0, "maxOccurs": 5 }
```

`maxOccurs` is omitted (key absent) when the value is `unbounded`. When present,
it is a non-negative integer. `minOccurs` defaults to `1` and is always present.

---

## XMLSchemaAnnotation

```json
{
  "documentation": ["Human-readable description."],
  "appinfo": ["machine-readable metadata"]
}
```

---

## XMLSchemaComponentID

```json
{ "rawValue": "urn:types|complexType|complexType/Order/0" }
```

The `rawValue` format is `<namespaceURI>|<kind>|<path>` and is stable within
a single normalisation run. Do not rely on its internal structure across
versions — treat it as an opaque unique identifier.

---

## Versioning policy

| Change | Version bump? |
|---|---|
| Adding optional fields with `null` defaults | No |
| Removing or renaming fields | Yes — increment `schemaVersion` |
| Changing field types | Yes — increment `schemaVersion` |
| Adding new `kind` values to discriminated unions | Yes — increment `schemaVersion` |

Consumers should check `schemaVersion` and reject versions they do not
understand rather than silently misreading the data.

---

## Fingerprint file

Alongside `Foo.schema.json` the tool writes `Foo.schema.json.sha256`
containing the lowercase hexadecimal SHA-256 digest of the canonical JSON
(keys sorted, no pretty-printing). Use it to detect schema changes without
re-parsing the full JSON.
