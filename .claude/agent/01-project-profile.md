# 01 - Project Profile

## Mission

Maintain a schema-focused Swift package that turns XSD documents into a clean, reusable model for the rest of the XML ecosystem.

## Scope

In scope:
- standalone XSD parsing,
- schema-set assembly,
- QName and namespace resolution,
- local include/import resolution,
- parser diagnostics and internal consistency validation.

Out of scope:
- SOAP or WSDL concerns,
- code generation,
- runtime XML instance validation,
- transport or framework adapters.

## Context

`SwiftXMLSchema` is a satellite repo extracted from the schema/XSD seed already present in `swift-soap`, but it must remain fully SOAP-free at the public API level.

## Platform and Tooling Constraints

- Swift Package Manager only.
- Linux-compatible runtime behavior.
- No Apple-only runtime APIs.
- Deterministic tests only.

## Compatibility Lanes

- `runtime-5.4`
- `tooling-5.6-plus`
- `macro-5.9`
- `quality-5.10`
- `latest`

## Dependency Policy

- Keep dependencies minimal.
- Document any new dependency with rationale, rejected alternatives, impact, and rollback.
- Current bootstrap dependency is the sibling core repo `../swift-xml-coder`.
