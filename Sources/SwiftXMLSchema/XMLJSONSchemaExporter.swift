import Foundation
import SwiftXMLCoder

// MARK: - Output model

/// A JSON Schema document (draft 2020-12) produced by ``XMLJSONSchemaExporter``.
///
/// The document is `Encodable` so callers can write it directly with `JSONEncoder`.
/// The `$defs` dictionary holds every named XSD type as a reusable JSON Schema definition.
/// Top-level XSD elements become entries in `properties` of the root schema object.
public struct XMLJSONSchemaDocument: Sendable, Encodable {
    public let schema: String
    public let title: String?
    public let description: String?
    public let defs: [String: JSONSchemaNode]
    public let properties: [String: JSONSchemaNode]?
    public let required: [String]?
    public let type: String?

    private enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case title, description, type, properties, required
        case defs = "$defs"
    }
}

/// A single JSON Schema node. Covers the subset of JSON Schema needed to represent
/// well-formed XSD types. Encoded as a plain JSON object.
public struct JSONSchemaNode: Sendable, Encodable {
    public var type: JSONSchemaType?
    public var ref: String?
    public var title: String?
    public var description: String?
    public var `enum`: [String]?
    public var properties: [String: JSONSchemaNode]?
    public var required: [String]?
    public var additionalProperties: JSONSchemaAdditionalProperties?
    public var items: JSONSchemaItems?
    public var minItems: Int?
    public var maxItems: Int?
    public var format: String?
    public var pattern: String?
    public var minLength: Int?
    public var maxLength: Int?
    public var minimum: Double?
    public var maximum: Double?
    public var exclusiveMinimum: Double?
    public var exclusiveMaximum: Double?
    public var allOf: [JSONSchemaNode]?
    public var anyOf: [JSONSchemaNode]?
    public var oneOf: [JSONSchemaNode]?

    private enum CodingKeys: String, CodingKey {
        case type, ref = "$ref", title, description
        case `enum`, properties, required, additionalProperties
        case items, minItems, maxItems, format, pattern
        case minLength, maxLength, minimum, maximum
        case exclusiveMinimum, exclusiveMaximum
        case allOf, anyOf, oneOf
    }
}

public enum JSONSchemaType: String, Sendable, Encodable {
    case string, number, integer, boolean, object, array, null
}

/// Either `false` (no additional properties allowed) or a schema node.
public indirect enum JSONSchemaAdditionalProperties: Sendable, Encodable {
    case allowed(Bool)
    case schema(JSONSchemaNode)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .allowed(let flag):
            var container = encoder.singleValueContainer()
            try container.encode(flag)
        case .schema(let node):
            try node.encode(to: encoder)
        }
    }
}

/// Either an inline schema or a `$ref`.
public indirect enum JSONSchemaItems: Sendable, Encodable {
    case schema(JSONSchemaNode)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .schema(let node):
            try node.encode(to: encoder)
        }
    }
}

// MARK: - Exporter

/// Converts an ``XMLNormalizedSchemaSet`` to a JSON Schema document (draft 2020-12).
///
/// ```swift
/// let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
/// let doc = XMLJSONSchemaExporter().export(normalized)
/// let data = try JSONEncoder().encode(doc)
/// ```
///
/// ### Mapping rules
///
/// | XSD construct | JSON Schema output |
/// |---|---|
/// | Named `complexType` | `$defs/<typeName>` with `type: "object"` |
/// | Named `simpleType` with enumerations | `$defs/<typeName>` with `enum: [...]` |
/// | Named `simpleType` (restriction) | `$defs/<typeName>` with `type` derived from base |
/// | Named `simpleType` (list) | `$defs/<typeName>` with `type: "array"` |
/// | Named `simpleType` (union) | `$defs/<typeName>` with `anyOf: [...]` |
/// | Top-level element | entry in root `properties` |
/// | `typeQName` reference | `$ref: "#/$defs/<localName>"` |
/// | `occurrenceBounds` maxOccurs > 1 or unbounded | wrapped in `type: "array"` |
/// | `anyAttribute` or element wildcard | `additionalProperties: true` |
/// | XSD built-in types | mapped to JSON Schema primitives |
///
/// Only components from `effectiveContent` and `effectiveAttributes` are emitted,
/// matching the code-generation recommendation in `SCHEMA_FORMAT.md`.
public struct XMLJSONSchemaExporter: Sendable {

    public init() {}

    /// Export all schemas in the set as a single JSON Schema document.
    /// `title` defaults to the first target namespace if not provided.
    public func export(
        _ schemaSet: XMLNormalizedSchemaSet,
        title: String? = nil
    ) -> XMLJSONSchemaDocument {
        var defs: [String: JSONSchemaNode] = [:]

        for schema in schemaSet.schemas {
            for complexType in schema.complexTypes where !complexType.isAnonymous {
                let key = defKey(name: complexType.name, namespaceURI: complexType.namespaceURI)
                defs[key] = node(for: complexType, in: schemaSet)
            }
            for simpleType in schema.simpleTypes {
                let key = defKey(name: simpleType.name, namespaceURI: simpleType.namespaceURI)
                defs[key] = node(for: simpleType)
            }
        }

        var properties: [String: JSONSchemaNode] = [:]
        var requiredProps: [String] = []

        for schema in schemaSet.schemas {
            for element in schema.elements {
                let propNode = propertyNode(
                    typeQName: element.typeQName,
                    bounds: element.occurrenceBounds,
                    defaultValue: element.defaultValue,
                    fixedValue: element.fixedValue,
                    annotation: element.annotation
                )
                properties[element.name] = propNode
                // Top-level elements without a default/fixed are treated as required
                if element.defaultValue == nil && element.fixedValue == nil {
                    requiredProps.append(element.name)
                }
            }
        }

        let docTitle = title ?? schemaSet.schemas.first?.targetNamespace
        return XMLJSONSchemaDocument(
            schema: "https://json-schema.org/draft/2020-12/schema",
            title: docTitle,
            description: nil,
            defs: defs,
            properties: properties.isEmpty ? nil : properties,
            required: requiredProps.isEmpty ? nil : requiredProps.sorted(),
            type: properties.isEmpty ? nil : "object"
        )
    }

    // MARK: - Complex type

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func node(
        for complexType: XMLNormalizedComplexType,
        in schemaSet: XMLNormalizedSchemaSet
    ) -> JSONSchemaNode {
        var properties: [String: JSONSchemaNode] = [:]
        var required: [String] = []

        for contentNode in complexType.effectiveContent {
            switch contentNode {
            case .element(let use):
                let propNode = propertyNode(
                    typeQName: use.typeQName,
                    bounds: use.occurrenceBounds,
                    defaultValue: use.defaultValue,
                    fixedValue: use.fixedValue,
                    annotation: use.annotation
                )
                properties[use.name] = propNode
                if use.occurrenceBounds.minOccurs > 0 && use.defaultValue == nil && use.fixedValue == nil {
                    required.append(use.name)
                }
            case .choice(let choice):
                let choiceNode = node(for: choice)
                // Inline choice elements as optional properties
                for element in choice.elements {
                    let propNode = propertyNode(
                        typeQName: element.typeQName,
                        bounds: element.occurrenceBounds,
                        defaultValue: element.defaultValue,
                        fixedValue: element.fixedValue,
                        annotation: element.annotation
                    )
                    properties[element.name] = propNode
                }
                // Also record as oneOf if there are nested choices
                if !choice.choiceGroups.isEmpty {
                    _ = choiceNode // used for nested groups via recursion
                }
            case .wildcard:
                break // handled via additionalProperties below
            case .choice:
                break // already handled above
            }
        }

        for attr in complexType.effectiveAttributes {
            let attrNode = attributeNode(for: attr)
            properties[attr.name] = attrNode
            if attr.use == "required" {
                required.append(attr.name)
            }
        }

        let hasWildcard = complexType.effectiveContent.contains {
            if case .wildcard = $0 { return true }
            return false
        }
        let additionalProperties: JSONSchemaAdditionalProperties? = (hasWildcard || complexType.anyAttribute != nil)
            ? .allowed(true)
            : nil

        var schemaNode = JSONSchemaNode()
        schemaNode.type = .object
        schemaNode.title = complexType.isAnonymous ? nil : complexType.name
        schemaNode.description = complexType.annotation.flatMap { annotationText($0) }
        schemaNode.properties = properties.isEmpty ? nil : properties
        schemaNode.required = required.isEmpty ? nil : required.sorted()
        schemaNode.additionalProperties = additionalProperties

        // Inheritance: if there is a base complex type, use allOf
        if let baseQName = complexType.inheritedComplexTypeQName {
            let refNode = refNode(for: baseQName)
            var extensionNode = schemaNode
            extensionNode.title = nil
            var merged = JSONSchemaNode()
            merged.title = complexType.isAnonymous ? nil : complexType.name
            merged.description = schemaNode.description
            merged.allOf = [refNode, extensionNode]
            return merged
        }

        // Simple-content: the type carries a text value plus attributes
        if let valueTypeQName = complexType.effectiveSimpleContentValueTypeQName {
            var valueNode = typeNode(for: valueTypeQName)
            valueNode.description = schemaNode.description
            if !properties.isEmpty {
                // Represent as allOf combining value type + attribute object
                var attrObject = JSONSchemaNode()
                attrObject.type = .object
                attrObject.properties = properties
                attrObject.required = required.isEmpty ? nil : required.sorted()
                var merged = JSONSchemaNode()
                merged.title = complexType.isAnonymous ? nil : complexType.name
                merged.allOf = [valueNode, attrObject]
                return merged
            }
            return valueNode
        }

        return schemaNode
    }

    private func node(for choice: XMLNormalizedChoiceGroup) -> JSONSchemaNode {
        let options = choice.elements.map { element -> JSONSchemaNode in
            propertyNode(
                typeQName: element.typeQName,
                bounds: element.occurrenceBounds,
                defaultValue: element.defaultValue,
                fixedValue: element.fixedValue,
                annotation: element.annotation
            )
        }
        var node = JSONSchemaNode()
        node.oneOf = options
        return node
    }

    // MARK: - Simple type

    private func node(for simpleType: XMLNormalizedSimpleType) -> JSONSchemaNode {
        var node = JSONSchemaNode()
        node.title = simpleType.name
        node.description = simpleType.annotation.flatMap { annotationText($0) }

        switch simpleType.derivationKind {
        case .restriction:
            if !simpleType.enumerationValues.isEmpty {
                node.enum = simpleType.enumerationValues
                return node
            }
            if let baseQName = simpleType.baseQName {
                node = typeNode(for: baseQName)
                node.title = simpleType.name
                node.description = simpleType.annotation.flatMap { annotationText($0) }
            }
            if let facets = simpleType.facets {
                applyFacets(facets, to: &node)
            }
            if let pattern = simpleType.pattern {
                node.pattern = pattern
            }

        case .list:
            node.type = .array
            if let itemQName = simpleType.listItemQName {
                node.items = .schema(typeNode(for: itemQName))
            }

        case .union:
            node.anyOf = simpleType.unionMemberQNames.map { typeNode(for: $0) }
        }

        return node
    }

    // MARK: - Attribute

    private func attributeNode(for attr: XMLNormalizedAttributeUse) -> JSONSchemaNode {
        var node = JSONSchemaNode()
        if let typeQName = attr.typeQName {
            node = typeNode(for: typeQName)
        } else {
            node.type = .string
        }
        node.description = attr.annotation.flatMap { annotationText($0) }
        return node
    }

    // MARK: - Property node (handles occurrenceBounds wrapping)

    private func propertyNode(
        typeQName: XMLQualifiedName?,
        bounds: XMLSchemaOccurrenceBounds,
        defaultValue: String?,
        fixedValue: String?,
        annotation: XMLSchemaAnnotation?
    ) -> JSONSchemaNode {
        var base: JSONSchemaNode
        if let typeQName = typeQName {
            base = typeNode(for: typeQName)
        } else {
            base = JSONSchemaNode()
        }
        base.description = annotation.flatMap { annotationText($0) }

        // maxOccurs nil = unbounded, or > 1 → wrap in array
        let isArray = bounds.maxOccurs == nil || (bounds.maxOccurs ?? 0) > 1
        if isArray {
            var arrayNode = JSONSchemaNode()
            arrayNode.type = .array
            arrayNode.items = .schema(base)
            if bounds.minOccurs > 0 {
                arrayNode.minItems = bounds.minOccurs
            }
            if let max = bounds.maxOccurs {
                arrayNode.maxItems = max
            }
            return arrayNode
        }

        return base
    }

    // MARK: - Type node from QName

    private func typeNode(for qname: XMLQualifiedName) -> JSONSchemaNode {
        let xsdNS = "http://www.w3.org/2001/XMLSchema"
        if qname.namespaceURI == xsdNS {
            return builtInTypeNode(localName: qname.localName)
        }
        return refNode(for: qname)
    }

    private func refNode(for qname: XMLQualifiedName) -> JSONSchemaNode {
        var node = JSONSchemaNode()
        node.ref = "#/$defs/\(qname.localName)"
        return node
    }

    // MARK: - XSD built-in type mapping

    // swiftlint:disable:next cyclomatic_complexity
    private func builtInTypeNode(localName: String) -> JSONSchemaNode {
        var node = JSONSchemaNode()
        switch localName {
        // String-like
        case "string", "normalizedString", "token",
             "Name", "NCName", "NMTOKEN", "NMTOKENS",
             "ID", "IDREF", "IDREFS", "ENTITY", "ENTITIES",
             "language", "anyURI":
            node.type = .string

        // Numeric — integer family
        case "integer", "nonNegativeInteger", "positiveInteger",
             "nonPositiveInteger", "negativeInteger",
             "long", "int", "short", "byte",
             "unsignedLong", "unsignedInt", "unsignedShort", "unsignedByte":
            node.type = .integer

        // Numeric — decimal/float family
        case "decimal", "float", "double":
            node.type = .number

        // Boolean
        case "boolean":
            node.type = .boolean

        // Date/time — represented as formatted strings
        case "date":
            node.type = .string
            node.format = "date"
        case "dateTime":
            node.type = .string
            node.format = "date-time"
        case "time":
            node.type = .string
            node.format = "time"
        case "duration":
            node.type = .string
            node.format = "duration"

        // Binary
        case "base64Binary":
            node.type = .string
            node.format = "byte"
        case "hexBinary":
            node.type = .string

        // QName / NOTATION — string representation
        case "QName", "NOTATION":
            node.type = .string

        // anySimpleType / anyType — no constraint
        case "anySimpleType", "anyType":
            break

        default:
            node.type = .string
        }
        return node
    }

    // MARK: - Facets

    private func applyFacets(_ facets: XMLSchemaFacetSet, to node: inout JSONSchemaNode) {
        if let minLength = facets.minLength { node.minLength = minLength }
        if let maxLength = facets.maxLength { node.maxLength = maxLength }
        if let length = facets.length {
            node.minLength = length
            node.maxLength = length
        }
        if let pattern = facets.pattern { node.pattern = pattern }
        if let minInclusive = facets.minInclusive { node.minimum = Double(minInclusive) }
        if let maxInclusive = facets.maxInclusive { node.maximum = Double(maxInclusive) }
        if let minExclusive = facets.minExclusive { node.exclusiveMinimum = Double(minExclusive) }
        if let maxExclusive = facets.maxExclusive { node.exclusiveMaximum = Double(maxExclusive) }
        if !facets.enumeration.isEmpty { node.enum = facets.enumeration }
    }

    // MARK: - Helpers

    private func defKey(name: String, namespaceURI: String?) -> String {
        // Use bare localName as key; namespace collisions are uncommon in practice
        // and JSON Schema $defs keys have no namespace concept.
        name
    }

    private func annotationText(_ annotation: XMLSchemaAnnotation) -> String? {
        let text = annotation.documentation.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
