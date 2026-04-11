import Foundation
import SwiftXMLCoder

// MARK: - Namespace breakdown

/// Component counts for a single target namespace within a schema set.
public struct XMLSchemaNamespaceBreakdown: Sendable, Equatable, Codable {
    /// The target namespace URI, or `nil` for no-namespace schemas.
    public let namespace: String?
    public let complexTypeCount: Int
    public let simpleTypeCount: Int
    public let elementCount: Int
    public let attributeDefinitionCount: Int
    public let attributeGroupCount: Int
    public let modelGroupCount: Int

    public init(
        namespace: String?,
        complexTypeCount: Int,
        simpleTypeCount: Int,
        elementCount: Int,
        attributeDefinitionCount: Int,
        attributeGroupCount: Int,
        modelGroupCount: Int
    ) {
        self.namespace = namespace
        self.complexTypeCount = complexTypeCount
        self.simpleTypeCount = simpleTypeCount
        self.elementCount = elementCount
        self.attributeDefinitionCount = attributeDefinitionCount
        self.attributeGroupCount = attributeGroupCount
        self.modelGroupCount = modelGroupCount
    }
}

// MARK: - XMLSchemaStatistics

/// Aggregate statistics for an ``XMLNormalizedSchemaSet``.
///
/// Obtain via ``XMLNormalizedSchemaSet/statistics``.
///
/// ### Unreferenced types
/// A named complex or simple type is considered *unreferenced* when no element declaration,
/// element use, attribute, or other type references it as a type name or base type.
/// Anonymous synthesised types are excluded from this analysis.
public struct XMLSchemaStatistics: Sendable, Equatable {
    // MARK: Total counts

    /// Number of named complex types across all schemas (anonymous types excluded).
    public let totalComplexTypes: Int
    /// Number of named simple types across all schemas.
    public let totalSimpleTypes: Int
    /// Number of top-level element declarations across all schemas.
    public let totalElements: Int
    /// Number of top-level attribute declarations across all schemas.
    public let totalAttributeDefinitions: Int
    /// Number of named attribute group definitions across all schemas.
    public let totalAttributeGroups: Int
    /// Number of named model group definitions across all schemas.
    public let totalModelGroups: Int

    // MARK: Inheritance depth

    /// Maximum number of in-schema-set ancestors in any complex type's derivation chain.
    /// A root type (no base in this schema set) has depth 0.
    public let maxComplexTypeInheritanceDepth: Int
    /// Maximum number of in-schema-set ancestors in any simple type's derivation chain.
    /// A root simple type has depth 0.
    public let maxSimpleTypeInheritanceDepth: Int

    // MARK: Namespace breakdown

    /// Per-namespace component counts, one entry per distinct `targetNamespace`
    /// (including `nil` for no-namespace schemas), sorted by namespace URI.
    public let namespaceBreakdown: [XMLSchemaNamespaceBreakdown]

    // MARK: Unreferenced types

    /// Qualified names (in `"namespace:localName"` form, bare `":localName"` when no namespace)
    /// of named complex types that are not referenced by any element, attribute, or other type
    /// in this schema set. Sorted lexicographically.
    public let unreferencedComplexTypeNames: [String]

    /// Qualified names of named simple types that are not referenced by any element, attribute,
    /// or other type in this schema set. Sorted lexicographically.
    public let unreferencedSimpleTypeNames: [String]
}

// MARK: - XMLNormalizedSchemaSet + statistics

private struct NamespaceCountAccumulator {
    var complexTypes: Int = 0
    var simpleTypes: Int = 0
    var elements: Int = 0
    var attributes: Int = 0
    var attributeGroups: Int = 0
    var modelGroups: Int = 0
}

extension XMLNormalizedSchemaSet {
    /// Computes aggregate statistics for this schema set.
    ///
    /// The computation is O(n) in the total number of components and content nodes.
    public var statistics: XMLSchemaStatistics {

        // ── Totals ──────────────────────────────────────────────────────────

        let namedComplexTypes = allComplexTypes.filter { !$0.isAnonymous }
        let totalComplex = namedComplexTypes.count
        let totalSimple = allSimpleTypes.count
        let totalElem = allElements.count
        let totalAttr = allAttributeDefinitions.count
        let totalAttrGroups = allAttributeGroups.count
        let totalModelGroups = allModelGroups.count

        // ── Namespace breakdown ─────────────────────────────────────────────

        var nsAccum: [String: NamespaceCountAccumulator] = [:]
        for schema in schemas {
            let key = schema.targetNamespace ?? ""
            var entry = nsAccum[key] ?? NamespaceCountAccumulator()
            entry.complexTypes += schema.complexTypes.filter { !$0.isAnonymous }.count
            entry.simpleTypes += schema.simpleTypes.count
            entry.elements += schema.elements.count
            entry.attributes += schema.attributeDefinitions.count
            entry.attributeGroups += schema.attributeGroups.count
            entry.modelGroups += schema.modelGroups.count
            nsAccum[key] = entry
        }
        let namespaceBreakdown = nsAccum
            .sorted { $0.key < $1.key }
            .map { key, counts in
                XMLSchemaNamespaceBreakdown(
                    namespace: key.isEmpty ? nil : key,
                    complexTypeCount: counts.complexTypes,
                    simpleTypeCount: counts.simpleTypes,
                    elementCount: counts.elements,
                    attributeDefinitionCount: counts.attributes,
                    attributeGroupCount: counts.attributeGroups,
                    modelGroupCount: counts.modelGroups
                )
            }

        // ── Referenced type keys ────────────────────────────────────────────
        // A type is "referenced" when its qualified name appears as a typeQName,
        // baseQName, listItemQName, or union member anywhere in the schema set.

        var referencedKeys = Set<String>()

        func addQName(_ qname: XMLQualifiedName?) {
            guard let qname else { return }
            referencedKeys.insert("\(qname.namespaceURI ?? ""):\(qname.localName)")
        }

        func collectContentKeys(_ nodes: [XMLNormalizedContentNode]) {
            for node in nodes {
                switch node {
                case .element(let use):
                    addQName(use.typeQName)
                case .choice(let group):
                    collectContentKeys(group.content)
                case .wildcard:
                    break
                }
            }
        }

        for element in allElements {
            addQName(element.typeQName)
        }

        for complexType in allComplexTypes {
            addQName(complexType.baseQName)
            addQName(complexType.simpleContentBaseQName)
            addQName(complexType.inheritedComplexTypeQName)
            collectContentKeys(complexType.effectiveContent)
            for attr in complexType.effectiveAttributes {
                addQName(attr.typeQName)
            }
        }

        for simpleType in allSimpleTypes {
            addQName(simpleType.baseQName)
            addQName(simpleType.listItemQName)
            for member in simpleType.unionMemberQNames { addQName(member) }
        }

        for attr in allAttributeDefinitions {
            addQName(attr.typeQName)
        }

        for attrGroup in allAttributeGroups {
            for attr in attrGroup.attributes { addQName(attr.typeQName) }
        }

        // ── Unreferenced named types ─────────────────────────────────────────

        let unreferencedComplex = namedComplexTypes
            .filter { complexType in
                let key = "\(complexType.namespaceURI ?? ""):\(complexType.name)"
                return !referencedKeys.contains(key)
            }
            .map { complexType -> String in
                complexType.namespaceURI.map { "\($0):\(complexType.name)" } ?? complexType.name
            }
            .sorted()

        let unreferencedSimple = allSimpleTypes
            .filter { simpleType in
                let key = "\(simpleType.namespaceURI ?? ""):\(simpleType.name)"
                return !referencedKeys.contains(key)
            }
            .map { simpleType -> String in
                simpleType.namespaceURI.map { "\($0):\(simpleType.name)" } ?? simpleType.name
            }
            .sorted()

        // ── Inheritance depth ────────────────────────────────────────────────

        var maxComplexDepth = 0
        for complexType in namedComplexTypes {
            var depth = 0
            var current: XMLNormalizedComplexType? = baseComplexType(of: complexType)
            var visited = Set<String>()
            while let ancestor = current {
                let key = "\(ancestor.namespaceURI ?? ""):\(ancestor.name)"
                guard !visited.contains(key) else { break }
                visited.insert(key)
                depth += 1
                current = baseComplexType(of: ancestor)
            }
            if depth > maxComplexDepth { maxComplexDepth = depth }
        }

        var maxSimpleDepth = 0
        for simpleType in allSimpleTypes {
            var depth = 0
            var current: XMLNormalizedSimpleType? = baseSimpleType(of: simpleType)
            var visited = Set<String>()
            while let ancestor = current {
                let key = "\(ancestor.namespaceURI ?? ""):\(ancestor.name)"
                guard !visited.contains(key) else { break }
                visited.insert(key)
                depth += 1
                current = baseSimpleType(of: ancestor)
            }
            if depth > maxSimpleDepth { maxSimpleDepth = depth }
        }

        // ── Assemble ─────────────────────────────────────────────────────────

        return XMLSchemaStatistics(
            totalComplexTypes: totalComplex,
            totalSimpleTypes: totalSimple,
            totalElements: totalElem,
            totalAttributeDefinitions: totalAttr,
            totalAttributeGroups: totalAttrGroups,
            totalModelGroups: totalModelGroups,
            maxComplexTypeInheritanceDepth: maxComplexDepth,
            maxSimpleTypeInheritanceDepth: maxSimpleDepth,
            namespaceBreakdown: namespaceBreakdown,
            unreferencedComplexTypeNames: unreferencedComplex,
            unreferencedSimpleTypeNames: unreferencedSimple
        )
    }
}
