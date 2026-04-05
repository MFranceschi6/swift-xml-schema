# Changelog

All notable changes to `SwiftXMLSchema` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added — Phase 0.5 (Concurrency + Typed Throws, Swift 6.0)

- **Typed throws on public API** (Swift 6.0+): `XMLSchemaDocumentParser.parse(data:)`, `parse(data:sourceURL:)`, and `parse(url:)` now declare `throws(XMLSchemaParsingError)`, enabling exhaustive `catch` at call sites. `XMLSchemaNormalizer.normalize(_:)` is typed identically. A shared `bridged(_:)` helper bridges the untyped-throws internal implementation into the typed public surface. On Swift ≤5.9 the `#else` branch retains untyped `throws` with identical behaviour.
- **Async resource resolver protocol** (Swift 5.5+): `XMLSchemaResourceResolver` gains two async protocol requirements — `resolve(schemaLocation:relativeTo:) async throws` and `loadSchemaData(from:) async throws` — with default implementations that bridge to the synchronous overloads. Existing conformances compile without changes.
- **`RemoteXMLSchemaResourceResolver` async override**: the async `loadSchemaData(from:)` wraps `URLSession.dataTask` in `withCheckedThrowingContinuation`, avoiding the `DispatchSemaphore` thread-blocking in async contexts. Compatible with macOS 10.15+ / iOS 15+.
- **`XMLSchemaDocumentParser.parse(url:) async throws`** (Swift 5.5+): async overload of the existing sync `parse(url:)`. Calls the async resolver and delegates to `parseDocumentAsync`.
- **Concurrent multi-schema parsing** (`parseDocumentAsync` / `appendSchemaRecursivelyAsync`, Swift 5.5+): imported and included schemas are now loaded concurrently at each nesting level via `withThrowingTaskGroup`. URL resolution and cycle detection remain sequential (preserving `inout` correctness); only the I/O phase is parallelised. First task error cancels remaining tasks and rethrows.
- **Sendable audit**: all public types already carry explicit `Sendable` conformances. `@unchecked Sendable` is confined to `_ResultBox` (the semaphore-synchronized result box in `RemoteXMLSchemaResourceResolver`).

### Added — Phase 0.4 (lineNumber in XMLSchemaSourceLocation)

- `XMLSchemaSourceLocation.lineNumber` is now populated for structural parse errors (missing required attributes, malformed QNames) where the offending `XMLNode` is available. Requires `swift-xml-coder` ≥ 2.1.0 which exposes `XMLNode.lineNumber` via `xmlGetLineNo`.
- All 13 internal parse functions in `XMLSchemaDocumentParser+Logic.swift` now thread `sourceURL: URL?` through their signatures so throw sites can construct a complete `XMLSchemaSourceLocation`.
- Updated `XMLSchemaSourceLocation` doc comment to distinguish structural parse errors (line number populated) from post-parse resolution errors (file URL only).
- Replaced hand-rolled `XMLSchemaQName` with `XMLQualifiedName` from `SwiftXMLCoder`. `.rawValue` renamed to `.qualifiedName` everywhere; construction updated to `XMLQualifiedName(localName:namespaceURI:prefix:)`.
- Bumped `swift-xml-coder` lower bound to `2.1.0` across all five Package manifests.

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
