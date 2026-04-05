# Changelog

All notable changes to `SwiftXMLSchema` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added — Phase 0.3 (Component Model, Visitor, Traversal API)

- **Indexed component model**: all seven lookup methods on `XMLNormalizedSchemaSet` (`element`, `complexType`, `simpleType`, `attribute`, `attributeGroup`, `modelGroup`, `rootElementBinding`) are now O(1) dictionary lookups backed by indices pre-computed in `init`. Previously O(n × m) linear scans.
- Added `baseComplexType(of:)` — returns the direct parent `XMLNormalizedComplexType` in the derivation chain, or `nil` for root/built-in types.
- Added `baseSimpleType(of:)` — returns the direct parent `XMLNormalizedSimpleType`, or `nil` for types derived from XSD built-ins.
- Added `derivedComplexTypes(of:)` — returns all complex types that directly extend or restrict the given type (O(1) via pre-computed index).
- Added `derivedSimpleTypes(of:)` — returns all simple types that directly derive from the given type.
- Added `canSubstitute(_:for:)` — returns `true` if the first element is a direct member of the second element's substitution group.
- Added `XMLSchemaVisitor<Result>` protocol (Swift 5.7+) with a primary associated type `Result` and `mutating` visit methods for all component kinds: schema, element, complexType, simpleType, attribute, attributeGroup, modelGroup, elementUse, choiceGroup, attributeUse. Default no-op implementations are provided when `Result == Void`.
- Added `XMLSchemaWalker` struct (Swift 5.7+) that drives depth-first traversal of an `XMLNormalizedSchemaSet`: visits all top-level components in declaration order, recurses into `effectiveContent` and `choice` groups of complex types, and visits `effectiveAttributes` on each complex type. Accepts the visitor via `inout` so value-type conformers can accumulate state.
- `Package@swift-5.6.swift`: excludes `XMLSchemaVisitor.swift`, `XMLSchemaWalker.swift`, and `XMLSchemaVisitorWalkerTests.swift` (Swift 5.7+ primary associated types and opaque parameter types are not available in the 5.6 toolchain lane).
- Added `XMLSchemaComponentModelTests` (25 cases) and `XMLSchemaVisitorWalkerTests` (12 cases); total test count now 91.

### Added

- Added `XMLSchemaSourceLocation` struct (`fileURL: URL?`, `lineNumber: Int?`) to surface where in a schema file a parse error originated. Line numbers require the tree-based parser path; the `XMLNode`-based path populates `fileURL` only.
- Added `XMLSchemaParsingDiagnostic` (severity: `.warning` / `.note`, message, optional location) for non-fatal issues that do not interrupt parsing.
- Added `XMLSchemaParsingResult<Value>` carrying a successfully parsed value alongside any collected non-fatal diagnostics, with `warnings` and `hasWarnings` accessors.
- Extended every `XMLSchemaParsingError` case with an optional `sourceLocation` parameter. Throw sites inside `parseDocument` and `appendSchemaRecursively` now populate `fileURL` from the active `sourceURL`.
- Renamed the `location: String` label in `XMLSchemaParsingError.resourceResolutionFailed` to `schemaLocation:` to distinguish it from the new `XMLSchemaSourceLocation` type.
- Added `RemoteXMLSchemaResourceResolver` for loading schemas from `http://` and `https://` URLs using a synchronous `URLSession`-plus-`DispatchSemaphore` wrapper; async variants are planned for Phase 0.5.
- Added `CatalogXMLSchemaResourceResolver` for OASIS XML Catalog remapping (`<system>` and `<uri>` entries) with fallback to a path relative to the catalog file.
- Added `CompositeXMLSchemaResourceResolver` that chains an ordered list of child resolvers and returns the first successful result, enabling a local → catalog → remote resolution pipeline.
- Added `XMLSchemaDiagnosticsTests` (17 cases) and `XMLSchemaResourceResolverTests` (20 cases); total test count now 56.

- Bootstrapped the standalone `SwiftXMLSchema` repository with multi-manifest SPM support.
- Added Claude/Codex-compatible agent entrypoints, plans, reports, scripts, and local hooks.
- Extracted the initial XSD model, parser, schema-set assembly, and local include/import resolution seed from `swift-soap`.
- Added broad-XSD raw model coverage for `group`/`group ref`, `xsd:any`, `xsd:anyAttribute`, `simpleType` list/union variants, inline anonymous element/attribute types, and explicit restriction-vs-extension capture.
- Added public semantic normalization APIs via `XMLSchemaNormalizer` and `XMLNormalizedSchemaSet`, including deterministic component IDs, normalized lookups, expanded attribute/model groups, inherited content flattening, and consolidated root-element bindings.
- Added parser and normalizer tests covering `all`, `attributeRef`, nested `attributeGroup`, wildcard capture, QName-prefix diagnostics, inline anonymous types, exclusive numeric facets, cyclic group diagnostics, and recursive include/import resolution.
- Added Phase 0.1 XSD core completeness support for annotations/documentation, element and attribute default/fixed values, abstract declarations, substitution groups, normalized substitution-group lookup, and complex/simple content restriction handling in the normalizer.
- Added a coverage-focused regression suite for raw model types, normalized lookup APIs, resolver/error helpers, and no-namespace normalization paths; package line coverage now stays above `90%`.

### Changed

- Reframed the package boundary around standalone XSD parsing and schema-set assembly only.
- Kept XML instance validation, SOAP, and WSDL concerns out of the bootstrap scope.
- Preserved `XMLSchemaDocumentParser -> XMLSchemaSet` as the raw parsing layer while moving codegen-oriented semantic expansion into the dedicated normalizer layer.
- Configured the public GitHub repository with lean repository settings, curated issue labels, and `main` branch protection wired to CI, SwiftLint, and documentation checks.
