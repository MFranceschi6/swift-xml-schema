import Foundation
import SwiftXMLCoder

// MARK: - Inferred simple type

extension XMLSchemaInferrer {

    /// The XSD simple type inferred from observed text values.
    ///
    /// The ordering (raw value) defines widening priority: lower is more specific.
    public enum InferredType: Int, Comparable, Sendable {
        case boolean  = 0
        case integer  = 1
        case decimal  = 2
        case date     = 3
        case dateTime = 4
        case string   = 5

        public static func < (lhs: InferredType, rhs: InferredType) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// Infers the most specific type that can represent `value`.
        public static func infer(_ value: String) -> InferredType {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .string }
            if trimmed == "true" || trimmed == "false" || trimmed == "1" || trimmed == "0" {
                // Only infer boolean if it's EXACTLY one of the four tokens (not a number > 1)
                if trimmed == "true" || trimmed == "false" { return .boolean }
            }
            if let num = Int64(trimmed) {
                return num == 0 || num == 1 ? .boolean : .integer
            }
            if Double(trimmed) != nil { return .decimal }
            if isXSDDate(trimmed) { return .date }
            if isXSDDateTime(trimmed) { return .dateTime }
            return .string
        }

        /// Returns the least-specific type that covers both `self` and `other`.
        public func widened(by other: InferredType) -> InferredType {
            guard self != other else { return self }
            // Numeric group: boolean < integer < decimal
            let numericGroup: Set<InferredType> = [.boolean, .integer, .decimal]
            if numericGroup.contains(self) && numericGroup.contains(other) {
                return max(self, other)
            }
            // Date group: date < dateTime
            if (self == .date && other == .dateTime) || (self == .dateTime && other == .date) {
                return .dateTime
            }
            // Cross-group: fall back to string
            return .string
        }

        /// The `xsd:` prefixed type name for use in schema output.
        public var xsdName: String {
            switch self {
            case .boolean:  return "xsd:boolean"
            case .integer:  return "xsd:integer"
            case .decimal:  return "xsd:decimal"
            case .date:     return "xsd:date"
            case .dateTime: return "xsd:dateTime"
            case .string:   return "xsd:string"
            }
        }
    }

    private static func isXSDDate(_ value: String) -> Bool {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, Int(parts[0]) != nil,
              parts[1].count == 2, let month = Int(parts[1]), (1...12).contains(month),
              parts[2].count == 2, let day = Int(parts[2]), (1...31).contains(day) else { return false }
        return true
    }

    private static func isXSDDateTime(_ value: String) -> Bool {
        guard value.contains("T") else { return false }
        let comps = value.split(separator: "T", maxSplits: 1)
        return comps.count == 2 && isXSDDate(String(comps[0]))
    }
}

// MARK: - Accumulation structures

extension XMLSchemaInferrer {

    /// Accumulated structural + type information for one element name within a parent.
    struct ElementSchema {
        let totalSamples: Int                        // number of documents processed
        var samplesPresent: Int = 0                  // documents where element appeared ≥ 1 time
        var maxOccurrencesInOneSample: Int = 0       // max count in any single (parent, document)

        var hasChildren: Bool = false
        var hasText: Bool = false
        /// `nil` = no text seen yet; set on first occurrence then widened on subsequent ones.
        var textType: InferredType?

        // Ordered children: key = localName, value = accumulated schema
        var children: [String: ElementSchema] = [:]
        var childOrder: [String] = []

        // Ordered attributes
        var attributes: [String: AttributeSchema] = [:]
        var attrOrder: [String] = []

        init(totalSamples: Int) {
            self.totalSamples = totalSamples
        }

        mutating func ensureChild(_ name: String) {
            if children[name] == nil {
                children[name] = ElementSchema(totalSamples: totalSamples)
                childOrder.append(name)
            }
        }

        mutating func ensureAttr(_ name: String) {
            if attributes[name] == nil {
                attributes[name] = AttributeSchema(totalSamples: totalSamples)
                attrOrder.append(name)
            }
        }
    }

    struct AttributeSchema {
        let totalSamples: Int
        var samplesPresent: Int = 0
        var inferredType: InferredType?  // nil = not yet seen

        init(totalSamples: Int) {
            self.totalSamples = totalSamples
        }
    }
}

// MARK: - Accumulation pass

extension XMLSchemaInferrer {

    /// Walks `element` from sample `sampleIndex` and accumulates into `schema`.
    func accumulateElement(
        _ element: XMLTreeElement,
        into schema: inout ElementSchema,
        sampleIndex: Int
    ) {
        schema.samplesPresent += 1

        // Accumulate attributes
        for xmlAttr in element.attributes {
            guard xmlAttr.name.namespaceURI != "http://www.w3.org/2000/xmlns/" else { continue }
            let attrName = xmlAttr.name.localName
            schema.ensureAttr(attrName)
            // Read-modify-write via local copy (avoids force-unwrap on dict subscript)
            var attrSchema = schema.attributes[attrName] ?? AttributeSchema(totalSamples: schema.totalSamples)
            attrSchema.samplesPresent += 1
            let inferred = InferredType.infer(xmlAttr.value)
            attrSchema.inferredType = attrSchema.inferredType.map { $0.widened(by: inferred) } ?? inferred
            schema.attributes[attrName] = attrSchema
        }

        // Collect child elements and text
        var childOccurrences: [String: Int] = [:]
        var textParts: [String] = []

        for node in element.children {
            switch node {
            case .element(let child):
                childOccurrences[child.name.localName, default: 0] += 1
            case .text(let txt):
                let trimmed = txt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { textParts.append(trimmed) }
            case .cdata(let txt):
                let trimmed = txt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { textParts.append(trimmed) }
            default:
                break
            }
        }

        // Accumulate text
        if !textParts.isEmpty {
            schema.hasText = true
            let inferred = InferredType.infer(textParts.joined())
            schema.textType = schema.textType.map { $0.widened(by: inferred) } ?? inferred
        }

        // Accumulate children
        if !childOccurrences.isEmpty { schema.hasChildren = true }

        for (childName, count) in childOccurrences {
            schema.ensureChild(childName)
            let prev = schema.children[childName]?.maxOccurrencesInOneSample ?? 0
            schema.children[childName]?.maxOccurrencesInOneSample = max(prev, count)
        }

        // Recurse into each child element, using a local copy to avoid force-unwrap
        for node in element.children {
            if case .element(let child) = node {
                let name = child.name.localName
                var childSchema = schema.children[name] ?? ElementSchema(totalSamples: schema.totalSamples)
                accumulateElement(child, into: &childSchema, sampleIndex: sampleIndex)
                schema.children[name] = childSchema
            }
        }
    }
}

// MARK: - XSD rendering

extension XMLSchemaInferrer {

    // swiftlint:disable:next function_body_length
    func render(root rootName: String, schema: ElementSchema, targetNamespace: String?) -> String {
        var out = XMLWriter()
        out.line("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")

        var schemaAttrs: [(String, String)] = [("xmlns:xsd", "http://www.w3.org/2001/XMLSchema")]
        if let tns = targetNamespace {
            schemaAttrs.append(("xmlns:tns", tns))
            schemaAttrs.append(("targetNamespace", tns))
        }
        schemaAttrs.append(("elementFormDefault", "qualified"))
        out.open("xsd:schema", attrs: schemaAttrs)

        renderElement(name: rootName, schema: schema, into: &out)

        out.close("xsd:schema")
        return out.build()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func renderElement(
        name: String,
        schema: ElementSchema,
        into out: inout XMLWriter,
        occurrenceBounds: (min: Int, max: Int?)? = nil
    ) {
        var attrs: [(String, String)] = [("name", name)]
        if let bounds = occurrenceBounds {
            if bounds.min != 1 { attrs.append(("minOccurs", "\(bounds.min)")) }
            if let max = bounds.max {
                if max != 1 { attrs.append(("maxOccurs", "\(max)")) }
            } else {
                attrs.append(("maxOccurs", "unbounded"))
            }
        }

        let hasContent = schema.hasChildren || !schema.attributes.isEmpty || schema.hasText
        guard hasContent else {
            // Simple string element
            attrs.append(("type", "xsd:string"))
            out.selfClose("xsd:element", attrs: attrs)
            return
        }

        // Simple content with no child elements and no attributes → inline type
        if !schema.hasChildren && schema.attributes.isEmpty {
            attrs.append(("type", (schema.textType ?? .string).xsdName))
            out.selfClose("xsd:element", attrs: attrs)
            return
        }

        out.open("xsd:element", attrs: attrs)
        out.open("xsd:complexType")

        // Simple content with attributes
        if !schema.hasChildren && schema.hasText {
            out.open("xsd:simpleContent")
            out.open("xsd:extension", attrs: [("base", (schema.textType ?? .string).xsdName)])
            renderAttributes(schema: schema, into: &out)
            out.close("xsd:extension")
            out.close("xsd:simpleContent")
        } else {
            // Sequence of child elements
            if schema.hasChildren {
                out.open("xsd:sequence")
                for childName in schema.childOrder {
                    guard let childSchema = schema.children[childName] else { continue }
                    let minOcc = childSchema.samplesPresent == childSchema.totalSamples ? 1 : 0
                    let maxOcc: Int? = childSchema.maxOccurrencesInOneSample > 1 ? nil : 1
                    renderElement(
                        name: childName,
                        schema: childSchema,
                        into: &out,
                        occurrenceBounds: (min: minOcc, max: maxOcc)
                    )
                }
                out.close("xsd:sequence")
            }
            renderAttributes(schema: schema, into: &out)
        }

        out.close("xsd:complexType")
        out.close("xsd:element")
    }

    private func renderAttributes(schema: ElementSchema, into out: inout XMLWriter) {
        for attrName in schema.attrOrder {
            guard let attrSchema = schema.attributes[attrName] else { continue }
            var attrs: [(String, String)] = [("name", attrName)]
            attrs.append(("type", (attrSchema.inferredType ?? .string).xsdName))
            let isRequired = attrSchema.samplesPresent == attrSchema.totalSamples
            attrs.append(("use", isRequired ? "required" : "optional"))
            out.selfClose("xsd:attribute", attrs: attrs)
        }
    }
}
