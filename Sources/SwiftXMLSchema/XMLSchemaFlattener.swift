import Foundation
import Logging
import SwiftXMLCoder

// MARK: - Error

/// An error thrown by ``XMLSchemaFlattener``.
public enum XMLSchemaFlattenerError: Error, Sendable, Equatable {
    /// The schema set contains more than one distinct non-nil `targetNamespace` and
    /// no explicit namespace was provided to ``XMLSchemaFlattener/flatten(_:targetNamespace:)``.
    ///
    /// The associated value lists the conflicting namespaces in sorted order.
    case ambiguousNamespace([String])
}

// MARK: - XMLSchemaFlattener

/// Converts an ``XMLNormalizedSchemaSet`` — potentially assembled from multiple XSD files with
/// imports and includes — into a single self-contained XSD `Data` value.
///
/// ### Flattening semantics
///
/// The output schema uses **effective content** from every normalized type: the fully-expanded
/// content that the normalizer computed, with all model-group, attribute-group, and inheritance
/// expansions already applied. No `<xsd:import>`, `<xsd:include>`, `<xsd:extension>`, or
/// `<xsd:restriction>` elements are emitted. Every type is self-contained in the output.
///
/// ### Namespace handling
///
/// When the input set contains exactly one `targetNamespace`, that namespace is used as the output
/// `targetNamespace`. When there are multiple distinct namespaces, supply an explicit
/// `targetNamespace` via ``flatten(_:targetNamespace:)``; calling ``flatten(_:)`` in that case
/// throws ``XMLSchemaFlattenerError/ambiguousNamespace(_:)``.
///
/// Type references whose `namespaceURI` differs from the output namespace are serialised as bare
/// local names — a documented v1 limitation.
///
/// ### Usage
///
/// ```swift
/// let parser = XMLSchemaDocumentParser()
/// let normalizer = XMLSchemaNormalizer()
/// let schemaSet = try parser.parse(data: xsdData)
/// let normalized = try normalizer.normalize(schemaSet)
/// let flattened = try XMLSchemaFlattener().flatten(normalized)
/// // `flattened` is a single, import-free XSD Data value.
/// ```
public struct XMLSchemaFlattener: Sendable {
    public let logger: Logger

    public init(logger: Logger = Logger(label: "SwiftXMLSchema.flattener")) {
        self.logger = logger
    }

    // MARK: - Public API

    /// Flattens `schemaSet` into a single XSD document.
    ///
    /// Throws ``XMLSchemaFlattenerError/ambiguousNamespace(_:)`` when the set contains
    /// more than one distinct non-nil `targetNamespace`. Use ``flatten(_:targetNamespace:)``
    /// to provide an explicit namespace in that case.
    public func flatten(_ schemaSet: XMLNormalizedSchemaSet) throws -> Data {
        let distinctNamespaces = Set(schemaSet.schemas.compactMap { $0.targetNamespace })
        if distinctNamespaces.count > 1 {
            throw XMLSchemaFlattenerError.ambiguousNamespace(distinctNamespaces.sorted())
        }
        return try flatten(schemaSet, targetNamespace: distinctNamespaces.first)
    }

    /// Flattens `schemaSet`, using `targetNamespace` as the output schema's target namespace
    /// regardless of the namespaces present in the input.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func flatten(_ schemaSet: XMLNormalizedSchemaSet, targetNamespace: String?) throws -> Data {
        let totalComplex  = schemaSet.allComplexTypes.filter { !$0.isAnonymous }.count
        let totalSimple   = schemaSet.allSimpleTypes.count
        let totalElements = schemaSet.allElements.count
        logger.debug("Starting schema flattening", metadata: [
            "targetNamespace": .string(targetNamespace ?? "(none)"),
            "complexTypes": .stringConvertible(totalComplex),
            "simpleTypes": .stringConvertible(totalSimple),
            "elements": .stringConvertible(totalElements)
        ])

        var out = XMLWriter()

        // XML declaration + root element opening
        out.line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        var schemaAttrs: [(String, String)] = [
            ("xmlns:xsd", xsdNamespace)
        ]
        if let tns = targetNamespace {
            schemaAttrs.append(("xmlns:tns", tns))
            schemaAttrs.append(("targetNamespace", tns))
        }
        schemaAttrs.append(("elementFormDefault", "qualified"))
        out.open("xsd:schema", attrs: schemaAttrs)

        // Schema-level annotation from the first schema that has one
        if let annotation = schemaSet.schemas.first(where: { $0.annotation != nil })?.annotation {
            renderAnnotation(annotation, into: &out)
        }

        // Simple types first (complex types may reference them)
        for schema in schemaSet.schemas {
            for simpleType in schema.simpleTypes {
                logger.trace("Flattening simpleType", metadata: ["name": .string(simpleType.name)])
                renderSimpleType(simpleType, into: &out, targetNamespace: targetNamespace)
            }
        }

        // Complex types (named only — anonymous types are inlined by name in the output)
        for schema in schemaSet.schemas {
            for complexType in schema.complexTypes where !complexType.isAnonymous {
                logger.trace("Flattening complexType", metadata: ["name": .string(complexType.name)])
                renderComplexType(complexType, into: &out, targetNamespace: targetNamespace)
            }
        }

        // Top-level element declarations
        for schema in schemaSet.schemas {
            for element in schema.elements {
                logger.trace("Flattening element", metadata: ["name": .string(element.name)])
                renderElementDeclaration(element, into: &out, targetNamespace: targetNamespace)
            }
        }

        // Top-level attribute definitions
        for schema in schemaSet.schemas {
            for attr in schema.attributeDefinitions {
                renderAttributeDefinition(attr, into: &out, targetNamespace: targetNamespace)
            }
        }

        // Attribute groups
        for schema in schemaSet.schemas {
            for group in schema.attributeGroups {
                renderAttributeGroup(group, into: &out, targetNamespace: targetNamespace)
            }
        }

        // Model groups
        for schema in schemaSet.schemas {
            for group in schema.modelGroups {
                renderModelGroup(group, into: &out, targetNamespace: targetNamespace)
            }
        }

        out.close("xsd:schema")

        let xml = out.build()
        logger.info("Schema flattening complete", metadata: [
            "targetNamespace": .string(targetNamespace ?? "(none)"),
            "outputBytes": .stringConvertible(xml.utf8.count)
        ])

        guard let data = xml.data(using: .utf8) else {
            // Unreachable in practice — Swift strings are always valid UTF-8.
            return Data()
        }
        return data
    }

    // MARK: - Simple type

    private func renderSimpleType(
        _ simpleType: XMLNormalizedSimpleType,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        out.open("xsd:simpleType", attrs: [("name", simpleType.name)])
        if let annotation = simpleType.annotation {
            renderAnnotation(annotation, into: &out)
        }

        switch simpleType.derivationKind {
        case .restriction:
            let base = simpleType.baseQName.map { qnameString($0, targetNamespace: targetNamespace) } ?? "xsd:string"
            out.open("xsd:restriction", attrs: [("base", base)])
            if let facets = simpleType.facets, !facets.isEmpty {
                // facets.enumeration already contains enumeration values when present
                renderFacets(facets, into: &out)
            } else if !simpleType.enumerationValues.isEmpty {
                // Fallback: enumerations surfaced only via enumerationValues (no facet set)
                for value in simpleType.enumerationValues {
                    out.selfClose("xsd:enumeration", attrs: [("value", value)])
                }
            }
            if let pattern = simpleType.pattern {
                out.selfClose("xsd:pattern", attrs: [("value", pattern)])
            }
            out.close("xsd:restriction")

        case .list:
            let itemType = simpleType.listItemQName.map { qnameString($0, targetNamespace: targetNamespace) } ?? "xsd:string"
            out.selfClose("xsd:list", attrs: [("itemType", itemType)])

        case .union:
            let memberTypes = simpleType.unionMemberQNames
                .map { qnameString($0, targetNamespace: targetNamespace) }
                .joined(separator: " ")
            out.selfClose("xsd:union", attrs: memberTypes.isEmpty ? [] : [("memberTypes", memberTypes)])
        }

        out.close("xsd:simpleType")
    }

    // MARK: - Complex type

    // swiftlint:disable:next cyclomatic_complexity
    private func renderComplexType(
        _ complexType: XMLNormalizedComplexType,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = [("name", complexType.name)]
        if complexType.isAbstract { attrs.append(("abstract", "true")) }
        if complexType.isMixed { attrs.append(("mixed", "true")) }

        let hasContent = !complexType.effectiveContent.isEmpty
        let hasAttrs = !complexType.effectiveAttributes.isEmpty
        let hasSimpleContent = complexType.effectiveSimpleContentValueTypeQName != nil
        let hasAnyAttr = complexType.anyAttribute != nil

        if !hasContent && !hasAttrs && !hasSimpleContent && !hasAnyAttr {
            // Empty complex type
            if let annotation = complexType.annotation {
                out.open("xsd:complexType", attrs: attrs)
                renderAnnotation(annotation, into: &out)
                out.close("xsd:complexType")
            } else {
                out.selfClose("xsd:complexType", attrs: attrs)
            }
            return
        }

        out.open("xsd:complexType", attrs: attrs)
        if let annotation = complexType.annotation {
            renderAnnotation(annotation, into: &out)
        }

        // Simple content path
        if let valueTypeQName = complexType.effectiveSimpleContentValueTypeQName {
            let base = qnameString(valueTypeQName, targetNamespace: targetNamespace)
            out.open("xsd:simpleContent")
            out.open("xsd:extension", attrs: [("base", base)])
            for attr in complexType.effectiveAttributes {
                renderAttributeUse(attr, into: &out, targetNamespace: targetNamespace)
            }
            if let anyAttr = complexType.anyAttribute {
                renderAnyAttribute(anyAttr, into: &out)
            }
            out.close("xsd:extension")
            out.close("xsd:simpleContent")
            out.close("xsd:complexType")
            return
        }

        // Sequence content
        if hasContent {
            out.open("xsd:sequence")
            for node in complexType.effectiveContent {
                renderContentNode(node, into: &out, targetNamespace: targetNamespace)
            }
            out.close("xsd:sequence")
        }

        // Attributes
        for attr in complexType.effectiveAttributes {
            renderAttributeUse(attr, into: &out, targetNamespace: targetNamespace)
        }
        if let anyAttr = complexType.anyAttribute {
            renderAnyAttribute(anyAttr, into: &out)
        }

        out.close("xsd:complexType")
    }

    // MARK: - Content nodes

    private func renderContentNode(
        _ node: XMLNormalizedContentNode,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        switch node {
        case .element(let use):
            renderElementUse(use, into: &out, targetNamespace: targetNamespace)
        case .choice(let choice):
            renderChoiceGroup(choice, into: &out, targetNamespace: targetNamespace)
        case .wildcard(let wildcard):
            renderAny(wildcard, into: &out)
        }
    }

    private func renderChoiceGroup(
        _ choice: XMLNormalizedChoiceGroup,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = []
        appendOccurrenceAttrs(choice.occurrenceBounds, to: &attrs)
        out.open("xsd:choice", attrs: attrs)
        for node in choice.content {
            renderContentNode(node, into: &out, targetNamespace: targetNamespace)
        }
        out.close("xsd:choice")
    }

    // MARK: - Element use (inside content models)

    private func renderElementUse(
        _ use: XMLNormalizedElementUse,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = [("name", use.name)]
        if let typeQName = use.typeQName {
            attrs.append(("type", qnameString(typeQName, targetNamespace: targetNamespace)))
        }
        appendOccurrenceAttrs(use.occurrenceBounds, to: &attrs)
        if use.nillable { attrs.append(("nillable", "true")) }
        if let defaultValue = use.defaultValue { attrs.append(("default", defaultValue)) }
        if let fixedValue = use.fixedValue { attrs.append(("fixed", fixedValue)) }

        if let annotation = use.annotation {
            out.open("xsd:element", attrs: attrs)
            renderAnnotation(annotation, into: &out)
            out.close("xsd:element")
        } else {
            out.selfClose("xsd:element", attrs: attrs)
        }
    }

    // MARK: - Top-level element declaration

    private func renderElementDeclaration(
        _ element: XMLNormalizedElementDeclaration,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = [("name", element.name)]
        if let typeQName = element.typeQName {
            attrs.append(("type", qnameString(typeQName, targetNamespace: targetNamespace)))
        }
        if element.nillable { attrs.append(("nillable", "true")) }
        if element.isAbstract { attrs.append(("abstract", "true")) }
        if let sg = element.substitutionGroup {
            attrs.append(("substitutionGroup", qnameString(sg, targetNamespace: targetNamespace)))
        }
        if let defaultValue = element.defaultValue { attrs.append(("default", defaultValue)) }
        if let fixedValue = element.fixedValue { attrs.append(("fixed", fixedValue)) }

        if !element.identityConstraints.isEmpty {
            logger.debug("Skipping identity constraints (not supported in v1)", metadata: [
                "element": .string(element.name),
                "constraintCount": .stringConvertible(element.identityConstraints.count)
            ])
        }

        if let annotation = element.annotation {
            out.open("xsd:element", attrs: attrs)
            renderAnnotation(annotation, into: &out)
            out.close("xsd:element")
        } else {
            out.selfClose("xsd:element", attrs: attrs)
        }
    }

    // MARK: - Attribute use

    private func renderAttributeUse(
        _ attr: XMLNormalizedAttributeUse,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = [("name", attr.name)]
        if let typeQName = attr.typeQName {
            attrs.append(("type", qnameString(typeQName, targetNamespace: targetNamespace)))
        }
        if let use = attr.use, use != .optional {
            attrs.append(("use", use.rawValue))
        }
        if let defaultValue = attr.defaultValue { attrs.append(("default", defaultValue)) }
        if let fixedValue = attr.fixedValue { attrs.append(("fixed", fixedValue)) }

        if let annotation = attr.annotation {
            out.open("xsd:attribute", attrs: attrs)
            renderAnnotation(annotation, into: &out)
            out.close("xsd:attribute")
        } else {
            out.selfClose("xsd:attribute", attrs: attrs)
        }
    }

    // MARK: - anyAttribute / any

    private func renderAnyAttribute(_ wildcard: XMLSchemaWildcard, into out: inout XMLWriter) {
        var attrs: [(String, String)] = []
        if let ns = wildcard.namespaceConstraint { attrs.append(("namespace", ns)) }
        if let pc = wildcard.processContents { attrs.append(("processContents", pc.rawValue)) }
        out.selfClose("xsd:anyAttribute", attrs: attrs)
    }

    private func renderAny(_ wildcard: XMLSchemaWildcard, into out: inout XMLWriter) {
        var attrs: [(String, String)] = []
        if let ns = wildcard.namespaceConstraint { attrs.append(("namespace", ns)) }
        if let pc = wildcard.processContents { attrs.append(("processContents", pc.rawValue)) }
        appendOccurrenceAttrs(wildcard.occurrenceBounds, to: &attrs)
        out.selfClose("xsd:any", attrs: attrs)
    }

    // MARK: - Top-level attribute definition

    private func renderAttributeDefinition(
        _ attr: XMLNormalizedAttributeDefinition,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        var attrs: [(String, String)] = [("name", attr.name)]
        if let typeQName = attr.typeQName {
            attrs.append(("type", qnameString(typeQName, targetNamespace: targetNamespace)))
        }
        if let use = attr.use, use != .optional { attrs.append(("use", use.rawValue)) }
        if let defaultValue = attr.defaultValue { attrs.append(("default", defaultValue)) }
        if let fixedValue = attr.fixedValue { attrs.append(("fixed", fixedValue)) }

        if let annotation = attr.annotation {
            out.open("xsd:attribute", attrs: attrs)
            renderAnnotation(annotation, into: &out)
            out.close("xsd:attribute")
        } else {
            out.selfClose("xsd:attribute", attrs: attrs)
        }
    }

    // MARK: - Attribute group

    private func renderAttributeGroup(
        _ group: XMLNormalizedAttributeGroup,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        out.open("xsd:attributeGroup", attrs: [("name", group.name)])
        for attr in group.attributes {
            renderAttributeUse(attr, into: &out, targetNamespace: targetNamespace)
        }
        out.close("xsd:attributeGroup")
    }

    // MARK: - Model group

    private func renderModelGroup(
        _ group: XMLNormalizedModelGroup,
        into out: inout XMLWriter,
        targetNamespace: String?
    ) {
        out.open("xsd:group", attrs: [("name", group.name)])
        if !group.content.isEmpty {
            out.open("xsd:sequence")
            for node in group.content {
                renderContentNode(node, into: &out, targetNamespace: targetNamespace)
            }
            out.close("xsd:sequence")
        }
        out.close("xsd:group")
    }

    // MARK: - Annotation

    private func renderAnnotation(_ annotation: XMLSchemaAnnotation, into out: inout XMLWriter) {
        let texts = annotation.documentation.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !texts.isEmpty else { return }
        out.open("xsd:annotation")
        for text in texts {
            out.open("xsd:documentation")
            out.text(text)
            out.close("xsd:documentation")
        }
        out.close("xsd:annotation")
    }

    // MARK: - Facets

    // swiftlint:disable:next cyclomatic_complexity
    private func renderFacets(_ facets: XMLSchemaFacetSet, into out: inout XMLWriter) {
        for value in facets.enumeration {
            out.selfClose("xsd:enumeration", attrs: [("value", value)])
        }
        if let val = facets.pattern { out.selfClose("xsd:pattern", attrs: [("value", val)]) }
        if let val = facets.length { out.selfClose("xsd:length", attrs: [("value", "\(val)")]) }
        if let val = facets.minLength { out.selfClose("xsd:minLength", attrs: [("value", "\(val)")]) }
        if let val = facets.maxLength { out.selfClose("xsd:maxLength", attrs: [("value", "\(val)")]) }
        if let val = facets.minInclusive { out.selfClose("xsd:minInclusive", attrs: [("value", val)]) }
        if let val = facets.maxInclusive { out.selfClose("xsd:maxInclusive", attrs: [("value", val)]) }
        if let val = facets.minExclusive { out.selfClose("xsd:minExclusive", attrs: [("value", val)]) }
        if let val = facets.maxExclusive { out.selfClose("xsd:maxExclusive", attrs: [("value", val)]) }
        if let val = facets.totalDigits { out.selfClose("xsd:totalDigits", attrs: [("value", "\(val)")]) }
        if let val = facets.fractionDigits { out.selfClose("xsd:fractionDigits", attrs: [("value", "\(val)")]) }
    }

    // MARK: - Helpers

    private let xsdNamespace = "http://www.w3.org/2001/XMLSchema"

    /// Returns the prefix-qualified string for `qname` in the context of the output schema.
    ///
    /// - `xsd:` for XSD built-in types.
    /// - `tns:` for types in the output target namespace (or bare name when no output namespace).
    /// - Bare local name for anything else (v1 limitation — logs a warning once per call).
    private func qnameString(_ qname: XMLQualifiedName, targetNamespace: String?) -> String {
        if qname.namespaceURI == xsdNamespace {
            return "xsd:\(qname.localName)"
        }
        if qname.namespaceURI == targetNamespace || (qname.namespaceURI == nil && targetNamespace == nil) {
            return targetNamespace == nil ? qname.localName : "tns:\(qname.localName)"
        }
        logger.warning("Type reference from a different namespace serialised as bare local name", metadata: [
            "localName": .string(qname.localName),
            "typeNamespace": .string(qname.namespaceURI ?? "(none)"),
            "outputNamespace": .string(targetNamespace ?? "(none)")
        ])
        return qname.localName
    }

    /// Appends `minOccurs`/`maxOccurs` attributes to `attrs`, omitting them when they equal the XSD defaults (1/1).
    private func appendOccurrenceAttrs(
        _ bounds: XMLSchemaOccurrenceBounds,
        to attrs: inout [(String, String)]
    ) {
        if bounds.minOccurs != 1 {
            attrs.append(("minOccurs", "\(bounds.minOccurs)"))
        }
        let defaultMax = 1
        if bounds.maxOccurs != defaultMax {
            let maxStr = bounds.maxOccurs.map { "\($0)" } ?? "unbounded"
            attrs.append(("maxOccurs", maxStr))
        }
    }
}

// XMLWriter and xml escaping helpers are defined in XMLWriter.swift
