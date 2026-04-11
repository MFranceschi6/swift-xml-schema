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

### Core types at a glance

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
