# Changelog

All notable changes to `SwiftXMLSchema` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

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
