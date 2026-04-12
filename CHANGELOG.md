# Changelog

All notable changes to `SwiftXMLSchema` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.0] — 2026-04-12

### Added — XSD 1.1 features (Phase 1.1)

- **`XMLSchemaAssertion`**: new public struct modelling `<xsd:assert>` — stores `test` (XPath expression), optional `xpathDefaultNamespace`, and `annotation`. Parsed by `XMLSchemaDocumentParser`, stored on `XMLSchemaComplexType` / `XMLSchemaAnonymousComplexType` (field `assertions: [XMLSchemaAssertion]`), and carried through the normalizer into `XMLNormalizedComplexType`.
- **`XMLSchemaTypeAlternative`**: new public struct modelling `<xsd:alternative>` — stores optional `test` (XPath condition), `typeQName`, and `annotation`. Parsed from element children and stored on `XMLSchemaElement` (field `typeAlternatives: [XMLSchemaTypeAlternative]`).
- **`XMLSchemaOpenContent`** + **`XMLSchemaOpenContentMode`**: new public types modelling `<xsd:openContent>` — `mode` (`.none` / `.interleave` / `.append`), `any: XMLSchemaWildcard?`, `appliesToEmpty`, and `annotation`. Stored on `XMLSchemaComplexType`, `XMLSchemaAnonymousComplexType`, and carried through to `XMLNormalizedComplexType`.
- **`XMLSchema.defaultOpenContent`**: schema-level `<xsd:defaultOpenContent>` parsed and stored on `XMLSchema`.
- **Validator awareness**: `XMLSchemaValidator` respects `openContent.mode != .none` — types with open content no longer flag extra child elements as errors (mode `.none` still rejects them).
- **`XMLXSD11Tests`** (21 cases): parsing, normalisation, and validation tests for all new XSD 1.1 constructs.

### Added — XMLSchemaValidator (Phase 1.1)

- **`XMLSchemaValidator`**: new public struct that validates XML instance documents against an `XMLNormalizedSchemaSet`. Entry points: `validate(data:against:)` and `validate(url:against:)`. Returns `XMLSchemaValidationResult` with `isValid`, `errors`, and `warnings`.
- **Validation coverage**: root element lookup, sequence/choice content model, occurrence bounds (`minOccurs`/`maxOccurs`), required/prohibited attributes, `anyAttribute` wildcard, simple type enumerations, string-length facets (`minLength`/`maxLength`/`length`), numeric range facets (`minInclusive`/`maxInclusive`), and built-in XSD scalar types (integer subtypes, boolean, date, dateTime, decimal).
- **`XMLSchemaValidator(logger:)`**: injected-logger pattern; `.info` on completion summary, `.trace` per-element.
- **`XMLSchemaValidatorTests`** (301 cases at launch, 334 total after Inferrer step): covers all validation paths including valid/invalid combinations for every facet and content model.

### Added — XMLSchemaInferrer (Phase 1.1)

- **`XMLSchemaInferrer`**: new public struct that walks one or more XML instance documents and produces a single-file XSD `Data` value. Entry points: `infer(data:)`, `infer(url:)`, `infer(contentsOf:)` (multi-document widening).
- **Type inference**: infers `xsd:boolean`, `xsd:integer`, `xsd:decimal`, `xsd:date`, `xsd:dateTime`, falling back to `xsd:string`. Types are widened across multiple XML samples (e.g., integer + decimal → decimal).
- **Structure inference**: occurrence bounds (`minOccurs`/`maxOccurs="unbounded"`), attribute use (`required` vs `optional`), `simpleContent` + attribute combinations.
- **`XMLSchemaInferrer(logger:)`**: injected-logger pattern consistent with all other pipeline structs.
- **`XMLWriter`**: extracted to shared internal `XMLWriter.swift` to avoid duplication between `XMLSchemaFlattener` and `XMLSchemaInferrer`.
- **`XMLSchemaInferrerTests`** (282 cases): type widening, occurrence inference, attribute use, multi-document merging, round-trip smoke tests.

### Added — XMLSchemaFlattener (Phase 1.1)

- **`XMLSchemaFlattener`**: new public struct that converts an `XMLNormalizedSchemaSet` — potentially assembled from multiple XSD files with imports and includes — into a single self-contained XSD `Data` value. The output uses effective content from every normalized type (all model-group, attribute-group, and inheritance expansions pre-applied); no `<xsd:import>`, `<xsd:include>`, `<xsd:extension>`, or `<xsd:restriction>` elements are emitted.
- **`XMLSchemaFlattenerError.ambiguousNamespace`**: thrown when the input set contains more than one distinct non-nil `targetNamespace` and no explicit namespace is provided to `flatten(_:targetNamespace:)`. The associated value lists the conflicting namespaces in sorted order.
- **Namespace handling**: single namespace → auto-detected; multiple namespaces → explicit override via `flatten(_:targetNamespace:)`. Cross-namespace type references are serialised as bare local names with a `.warning`-level log message (documented v1 limitation).
- **`XMLSchemaFlattener(logger:)`**: injected-logger pattern consistent with all other pipeline structs; `.debug` on start/completion, `.trace` per type/element, `.warning` on cross-namespace references.
- **`XMLSchemaFlattenerTests`** (30 cases): round-trip tests for simple types (restriction/enumeration/list/union/facets), complex types (sequence, attributes, mixed, abstract, simpleContent, anyAttribute, wildcard, choice), top-level elements (nillable, default/fixed), occurrence bounds (unbounded), annotations, attribute groups, model groups, multiple schemas, ambiguous-namespace error, explicit-namespace override, and logger autoclosure coverage.

## [1.0.0] — 2026-04-11

### Added — Structured Logging

- **`swift-log` integration** (`apple/swift-log ≥ 1.0.0`): all five public pipeline structs now accept an optional `logger: Logger` parameter at initialisation. No logger is required — the default label follows the `SwiftXMLSchema.<subsystem>` convention and is a no-op until the caller bootstraps a `LoggingSystem` backend.
- **Per-struct injected loggers** (replaces any module-level globals): `XMLSchemaDocumentParser(logger:)`, `XMLSchemaNormalizer(logger:)`, `XMLSchemaDiffer(logger:)`, `XMLJSONSchemaExporter(logger:)`, `LocalFileXMLSchemaResourceResolver(logger:)`, `RemoteXMLSchemaResourceResolver(timeout:logger:)`, `CatalogXMLSchemaResourceResolver(catalogURL:logger:)`, `CompositeXMLSchemaResourceResolver(_:logger:)`. Callers who omit the parameter get the same labelled default; callers who want trace-level output for a single instance pass a pre-configured `Logger` without touching any global state.
- **Five log subsystems with granular levels**:
  - `parser` — `.debug` per document/schema load, `.info` parse summary, `.trace` per complex/simple type, `.warning` on cycle detection.
  - `normalizer` — `.debug` per schema, `.info` completion summary, `.trace` per complex/simple type normalisation.
  - `differ` — `.debug` diff start with component counts, `.info` no-change / non-breaking result, `.notice` breaking-changes result.
  - `exporter` — `.debug` export start, `.trace` per complex/simple type exported, `.info` completion summary.
  - `resolver` — `.debug` on every resolve/load hit, `.warning` on all-resolvers-failed.
- **`XMLSchemaLoggingTests`** (11 cases): exercises all logging `@autoclosure` regions at `.trace` level via injected loggers to maintain llvm-cov coverage above the 90 % gate.

### Changed — Phase 1.0 Release Prep

- **`XMLSchemaPlugin` migrated to URL-based `PackagePlugin` API** under `#if compiler(>=6.0)`, with the legacy `Path`-based path retained for older toolchains. Eliminates 12 deprecation warnings on Swift 6.0+.
- **`XMLJSONSchemaExporter`**: removed unreachable `case .choice` branch in `objectNode(for:)` (already handled earlier in the same `switch`); silences a Swift compiler warning.
- **README refreshed** for 1.0: feature inventory (parsing, normalisation, walker, diff, statistics, JSON Schema export, build plugin, resource resolution, diagnostics), Swift 5.4 runtime support, installation snippet, and DocC generation instructions.
- **Doc-comment hygiene**: removed dead symbol link to internal `XMLSchemaParsingResult` from `XMLSchemaParsingDiagnostic`; downgraded ambiguous DocC link `loadSchemaData(from:)` on `RemoteXMLSchemaResourceResolver` to plain code formatting. DocC now builds without warnings.
- **Swift 5.6 compatibility restored** in `XMLSchemaStatistics` and `XMLSchemaDiff` by replacing shorthand `guard let foo` with `guard let foo = foo`, and by lifting a complex array literal in `facetSummary` into an intermediate `[String?]` variable to avoid the Swift 5.6 type-check timeout. Unblocks the `tooling-5.6-plus` CI lane.
- **Test coverage** for `XMLSchemaDiff` and `XMLSchemaWalker` raised to push aggregate line coverage above the 90% gate enforced by the `quality-5.10` lane. New `XMLSchemaDiffCoverageTests` targets previously uncovered branches across complex/simple type and element diff paths; `XMLSchemaVisitorWalkerTests` now exercises the `walkComponents(collecting:)` overload end-to-end.

### Added — Phase 1.0 DocC Documentation

- **`SwiftXMLSchema.docc` catalog** (new): DocC documentation catalog under `Sources/SwiftXMLSchema/`. Picked up automatically by the `swift-docc-plugin` dependency already declared in `Package@swift-5.9.swift` and later manifests.
- **Landing page** (`SwiftXMLSchema.md`): module overview, pipeline diagram table, and topic groups linking every public type and article.
- **Article: Getting Started** — parsing from `Data` and file URL, normalisation, typed throws (Swift 6.0), async parsing (Swift 5.5+).
- **Article: Working with the Component Model** — O(1) lookups, `XMLQualifiedName` overloads, flat cross-schema iterators, `effectiveContent` vs `declaredContent`, inheritance navigation (`baseComplexType(of:)`, `derivedComplexTypes(of:)`), substitution groups, schema statistics summary.
- **Article: Visitor and Walker** — `XMLSchemaVisitor` protocol, `XMLSchemaWalker` depth-first pass, `inout` accumulation pattern, `walkComponents(collecting:)` for non-`Void` results, class-based visitor example, code-generation pattern.
- **Article: Build Plugin** — SPM setup, `XMLSchemaPlugin` build command, `XMLSchemaTool` standalone CLI, loading the generated JSON at runtime, fingerprint verification in CI.
- **Article: JSON Schema Export** — `XMLJSONSchemaExporter`, complex-type mapping, simple-type enumerations, list/union derivation, type-inheritance `allOf` composition, XSD-to-JSON built-in type table, facet propagation table, wildcard handling.
- **Article: Schema Diff and Statistics** — `XMLSchemaDiffer` usage, breaking/non-breaking change table, filtered views, `XMLSchemaStatistics` counters, inheritance-depth metrics, per-namespace breakdown, unreferenced type detection, CI usage pattern.

### Added — Phase 1.0 Schema Statistics

- **`XMLSchemaStatistics`** (new): aggregate statistics for an `XMLNormalizedSchemaSet`. Fields:
  - **Total counts**: `totalComplexTypes`, `totalSimpleTypes`, `totalElements`, `totalAttributeDefinitions`, `totalAttributeGroups`, `totalModelGroups` (anonymous complex types are excluded from `totalComplexTypes`).
  - **Inheritance depth**: `maxComplexTypeInheritanceDepth` and `maxSimpleTypeInheritanceDepth` — maximum number of in-schema-set ancestors in any type's derivation chain (root = 0, one derived level = 1, etc.). Cycles are guarded.
  - **Namespace breakdown**: `namespaceBreakdown: [XMLSchemaNamespaceBreakdown]` — per-`targetNamespace` component counts (including `nil` for no-namespace schemas), sorted by namespace URI.
  - **Unreferenced types**: `unreferencedComplexTypeNames` and `unreferencedSimpleTypeNames` — sorted qualified-name strings of named types that are not referenced as a `typeQName`, base type, list-item type, or union-member type anywhere in the schema set. Useful for tooling diagnostics and dead-type detection.
- **`XMLSchemaNamespaceBreakdown`** (new): `Sendable, Equatable, Codable` struct with `namespace`, `complexTypeCount`, `simpleTypeCount`, `elementCount`, `attributeDefinitionCount`, `attributeGroupCount`, `modelGroupCount`.
- **`XMLNormalizedSchemaSet.statistics`** (new): computed property that runs the O(n) analysis and returns an `XMLSchemaStatistics` value.
- Added `XMLSchemaPhase10StatisticsTests` (14 cases); total test count now 176.

### Changed — Phase 1.0 API Cleanup

- **`XMLSchemaAttributeUseKind` enum** (new): replaces `use: String?` on `XMLSchemaAttribute`, `XMLSchemaAttributeReference`, `XMLNormalizedAttributeUse`, and `XMLNormalizedAttributeDefinition`. Valid cases: `.required`, `.optional`, `.prohibited`. The parser maps the XSD `use` attribute value to the enum; unknown values are silently dropped to `nil`.
- **`XMLSchemaWildcardProcessContents` enum** (new): replaces `processContents: String?` on `XMLSchemaWildcard`. Valid cases: `.strict`, `.lax`, `.skip`. The parser maps the XSD `processContents` attribute value; unknown values are silently dropped to `nil`.
- **`XMLSchemaParsingResult` is now internal**: the type was declared public but never returned by any public API. It is retained internally for future use when the parser threads non-fatal warning collection through its internals. Callers who referenced it directly should remove the dependency.
- **`XMLNormalizedSchemaSet` flat iterators** (new): `allElements`, `allComplexTypes`, `allSimpleTypes`, `allAttributeDefinitions`, `allAttributeGroups`, `allModelGroups` — cross-schema `flatMap` shortcuts so callers no longer need `schemaSet.schemas.flatMap { $0.complexTypes }`.
- **`XMLNormalizedSchemaSet` `XMLQualifiedName` overloads** (new): `element(_:)`, `complexType(_:)`, `simpleType(_:)`, `attribute(_:)`, `attributeGroup(_:)`, `modelGroup(_:)` — accept an `XMLQualifiedName` directly, forwarding to the existing `(named:namespaceURI:)` overloads.
- **`XMLSchemaWalker.walkComponents(collecting:)`** (new): generic overload that collects and returns `[R]` from visitor methods, for visitors with a non-`Void` result type. The existing `walkComponents(visitor:)` (`Result == Void`) is unchanged.
- **`XMLSchemaDiff` / `XMLSchemaDiffer`** (new): structural diff between two `XMLNormalizedSchemaSet` values. `XMLSchemaDiffer.diff(old:new:)` returns an `XMLSchemaDiff` containing typed change lists for complex types (`[XMLSchemaComplexTypeDiff]`), simple types (`[XMLSchemaSimpleTypeDiff]`), and element declarations (`[XMLSchemaElementDiff]`). Each entry wraps an `XMLSchemaComponentChange<T>` (`.added`, `.removed`, `.modified`) and carries `[XMLSchemaFieldChange]` with `fieldName`, `kind` (`.valueChanged(from:to:)`, `.itemAdded`, `.itemRemoved`), and `isBreaking` classification. `XMLSchemaDiff.hasBreakingChanges`, `breakingComplexTypeChanges`, `breakingSimpleTypeChanges`, and `breakingElementChanges` provide filtered views. Anonymous synthesised types are excluded. Adding optional content or non-required attributes is non-breaking; removing components, tightening occurrences, or changing types is breaking.
- Added `XMLSchemaPhase10DiffTests` (18 cases); total test count now 162.

### Added — Phase 0.8 (JSON Schema Export)

- **`XMLJSONSchemaExporter`**: converts an `XMLNormalizedSchemaSet` to a `XMLJSONSchemaDocument` conforming to JSON Schema draft 2020-12. Reads `effectiveContent` and `effectiveAttributes` exclusively (matching the SCHEMA_FORMAT.md recommendation).
- **`XMLJSONSchemaDocument`** and **`JSONSchemaNode`** output model: fully `Encodable`; pass directly to `JSONEncoder` to produce a ready-to-use JSON Schema file.
- **XSD → JSON Schema mapping**: named `complexType` → `$defs` object with `type:"object"`, `properties`, and `required`; named `simpleType` with enumerations → `enum:[...]`; `list` derivation → `type:"array"`; `union` derivation → `anyOf`; type hierarchy extension → `allOf[$ref, ...]`; simple-content types → base type node merged with attribute object; wildcards/`anyAttribute` → `additionalProperties: true`.
- **XSD built-in type mapping**: `xsd:string`/`token`/`anyURI`/`ID`/`IDREF`/… → `string`; integer family → `integer`; `decimal`/`float`/`double` → `number`; `boolean` → `boolean`; `date`/`dateTime`/`time`/`duration` → `string` with `format`; `base64Binary` → `string` with `format:"byte"`.
- **Facet propagation**: `minLength`, `maxLength`, `length`, `pattern`, `minInclusive`, `maxInclusive`, `minExclusive`, `maxExclusive`, `enumeration` from `XMLSchemaFacetSet` are mapped to the corresponding JSON Schema keywords.
- **Occurrence bounds**: `maxOccurs > 1` or unbounded wraps the property node in `type:"array"` with `minItems`/`maxItems`; `minOccurs == 0` omits the field from `required`.
- **Top-level elements** become entries in the root `properties` object (root is `type:"object"`).
- **Custom title**: `XMLJSONSchemaExporter.export(_:title:)` accepts an optional title override; defaults to the first schema's `targetNamespace`.
- Added `XMLSchemaPhase08Tests` (20 cases); total test count now 144.

### Added — Phase 0.6 (Build Tool Plugin and Schema Caching)

- **`Codable` on all normalised types**: `XMLNormalizedSchemaSet`, `XMLNormalizedSchema`, `XMLNormalizedComplexType`, `XMLNormalizedSimpleType`, `XMLNormalizedElementDeclaration`, `XMLNormalizedAttributeUse`, `XMLNormalizedAttributeDefinition`, `XMLNormalizedAttributeGroup`, `XMLNormalizedModelGroup`, `XMLNormalizedContentNode`, `XMLSchemaOccurrenceBounds`, `XMLSchemaWildcard`, `XMLSchemaAnnotation`, `XMLSchemaComponentID`, `XMLSchemaIdentityConstraint`, `XMLSchemaFacetSet` — all conform to `Codable`. `XMLNormalizedContentNode` uses a custom `{"kind":"element|choice|wildcard","value":{...}}` discriminated-union envelope to avoid field-name collisions with `XMLSchemaWildcard`'s own `kind` field.
- **`XMLNormalizedSchemaSet` versioned JSON envelope**: custom `Codable` emits `schemaVersion: 1` at the top level; the decoder validates the version and reconstructs all O(1) indices by calling `init(schemas:)`.
- **SHA-256 fingerprint** (`#if canImport(CryptoKit)`): `XMLNormalizedSchemaSet.fingerprint` returns the lowercase hex SHA-256 digest of the sorted-keys canonical JSON. Stable across invocations; changes when any schema component changes.
- **`XMLSchemaTool` executable**: CLI that parses one or more XSD files, normalises the schema set, and writes a pretty-printed, sorted-keys JSON file plus a `.sha256` sidecar. Usage: `XMLSchemaTool <input.xsd> <output.schema.json>`.
- **`XMLSchemaPlugin` SPM BuildToolPlugin**: for each `.xsd` source file in the target, emits a `.buildCommand` that runs `XMLSchemaTool`, producing `<name>.schema.json` and `<name>.schema.json.sha256` in the build output directory. Requires Swift 5.6+; plugin source lives under `Plugins/XMLSchemaPlugin/`.
- **All five `Package@swift-*.swift` manifests updated**: added `XMLSchemaTool` executable product/target and `XMLSchemaPlugin` plugin product/target.
- **`SCHEMA_FORMAT.md`**: comprehensive language-agnostic documentation of the JSON output format (all types, discriminated-union envelope, QName structure, occurrence bounds behaviour, versioning policy, fingerprint sidecar). Designed so that external code-generation tools written in any language can consume the output.
- Added `XMLSchemaPhase06Tests` (12 cases): JSON round-trip (4 cases), JSON structure validation (5 cases), fingerprinting (3 cases); total test count now 124.

### Added — Phase 0.4 (Redefine, Mixed Content, Identity Constraints)

- **`<xsd:redefine>` support**: `XMLSchemaRedefine` struct (`schemaLocation`, `complexTypes`, `simpleTypes`, `attributeGroups`, `modelGroups`) added to `XMLSchema`. The parser loads the referenced file and applies overrides — types/groups in the redefine block replace same-named components from the loaded schema (`applyRedefine(_:to:)`), matching the XSD 1.0 override semantics.
- **Mixed content** (`isMixed: Bool`): added to `XMLSchemaComplexType`, `XMLSchemaAnonymousComplexType`, and `XMLNormalizedComplexType`. The parser reads `mixed="true"` from either the `complexType` element or its `complexContent` child; the normalizer threads it through `normalizeComplexType`.
- **Identity constraints**: new `XMLSchemaIdentityConstraintKind` enum (`.key`, `.keyref`, `.unique`) and `XMLSchemaIdentityConstraint` struct (`kind`, `name`, `selector`, `fields`, `refer`). `XMLSchemaElement` gains `identityConstraints: [XMLSchemaIdentityConstraint]`; `XMLNormalizedElementDeclaration` gains the same field. The parser handles `<xsd:key>`, `<xsd:keyref>`, and `<xsd:unique>` children of element nodes via `parseIdentityConstraints(from:namespaceMappings:)`.
- **`<xsd:notation>`**: new `XMLSchemaNotation` struct (`name`, `publicID`, `systemID`). `XMLSchema` gains `notations: [XMLSchemaNotation]`. The parser captures all `<xsd:notation>` children of schema nodes.
- Added `XMLSchemaPhase04Tests` (13 cases): mixed content (4 cases), identity constraints (5 cases), notation (2 cases), redefine (2 cases); total test count now 112.

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
