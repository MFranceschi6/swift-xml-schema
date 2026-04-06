import Foundation
import SwiftXMLCoder
// swiftlint:disable file_length

public struct XMLSchemaComponentID: Sendable, Equatable, Hashable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum XMLNormalizedContentNode: Sendable, Equatable, Codable {
    case element(XMLNormalizedElementUse)
    case choice(XMLNormalizedChoiceGroup)
    case wildcard(XMLSchemaWildcard)
}

public struct XMLNormalizedElementDeclaration: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let typeQName: XMLQualifiedName?
    public let nillable: Bool
    public let defaultValue: String?
    public let fixedValue: String?
    public let isAbstract: Bool
    public let substitutionGroup: XMLQualifiedName?
    public let identityConstraints: [XMLSchemaIdentityConstraint]
    public let occurrenceBounds: XMLSchemaOccurrenceBounds

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        typeQName: XMLQualifiedName?,
        nillable: Bool,
        defaultValue: String?,
        fixedValue: String?,
        isAbstract: Bool,
        substitutionGroup: XMLQualifiedName?,
        identityConstraints: [XMLSchemaIdentityConstraint] = [],
        occurrenceBounds: XMLSchemaOccurrenceBounds
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.typeQName = typeQName
        self.nillable = nillable
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
        self.isAbstract = isAbstract
        self.substitutionGroup = substitutionGroup
        self.identityConstraints = identityConstraints
        self.occurrenceBounds = occurrenceBounds
    }
}

public struct XMLNormalizedElementUse: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let typeQName: XMLQualifiedName?
    public let nillable: Bool
    public let defaultValue: String?
    public let fixedValue: String?
    public let isAbstract: Bool
    public let substitutionGroup: XMLQualifiedName?
    public let occurrenceBounds: XMLSchemaOccurrenceBounds

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        typeQName: XMLQualifiedName?,
        nillable: Bool,
        defaultValue: String?,
        fixedValue: String?,
        isAbstract: Bool,
        substitutionGroup: XMLQualifiedName?,
        occurrenceBounds: XMLSchemaOccurrenceBounds
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.typeQName = typeQName
        self.nillable = nillable
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
        self.isAbstract = isAbstract
        self.substitutionGroup = substitutionGroup
        self.occurrenceBounds = occurrenceBounds
    }
}

public struct XMLNormalizedChoiceGroup: Sendable, Equatable, Codable {
    public let content: [XMLNormalizedContentNode]
    public let occurrenceBounds: XMLSchemaOccurrenceBounds

    public var elements: [XMLNormalizedElementUse] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var choiceGroups: [XMLNormalizedChoiceGroup] {
        content.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public init(content: [XMLNormalizedContentNode], occurrenceBounds: XMLSchemaOccurrenceBounds) {
        self.content = content
        self.occurrenceBounds = occurrenceBounds
    }
}

public struct XMLNormalizedAttributeDefinition: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let typeQName: XMLQualifiedName?
    public let use: String?
    public let defaultValue: String?
    public let fixedValue: String?

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        typeQName: XMLQualifiedName?,
        use: String?,
        defaultValue: String?,
        fixedValue: String?
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.typeQName = typeQName
        self.use = use
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
    }
}

public struct XMLNormalizedAttributeUse: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let typeQName: XMLQualifiedName?
    public let use: String?
    public let defaultValue: String?
    public let fixedValue: String?

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        typeQName: XMLQualifiedName?,
        use: String?,
        defaultValue: String?,
        fixedValue: String?
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.typeQName = typeQName
        self.use = use
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
    }
}

public struct XMLNormalizedAttributeGroup: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let name: String
    public let namespaceURI: String?
    public let attributes: [XMLNormalizedAttributeUse]

    public init(
        componentID: XMLSchemaComponentID,
        name: String,
        namespaceURI: String?,
        attributes: [XMLNormalizedAttributeUse]
    ) {
        self.componentID = componentID
        self.name = name
        self.namespaceURI = namespaceURI
        self.attributes = attributes
    }
}

public struct XMLNormalizedModelGroup: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let name: String
    public let namespaceURI: String?
    public let content: [XMLNormalizedContentNode]

    public var sequence: [XMLNormalizedElementUse] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var choiceGroups: [XMLNormalizedChoiceGroup] {
        content.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public init(
        componentID: XMLSchemaComponentID,
        name: String,
        namespaceURI: String?,
        content: [XMLNormalizedContentNode]
    ) {
        self.componentID = componentID
        self.name = name
        self.namespaceURI = namespaceURI
        self.content = content
    }
}

public struct XMLNormalizedSimpleType: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let baseQName: XMLQualifiedName?
    public let enumerationValues: [String]
    public let pattern: String?
    public let facets: XMLSchemaFacetSet?
    public let derivationKind: XMLSchemaSimpleTypeDerivationKind
    public let listItemQName: XMLQualifiedName?
    public let unionMemberQNames: [XMLQualifiedName]

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        baseQName: XMLQualifiedName?,
        enumerationValues: [String],
        pattern: String?,
        facets: XMLSchemaFacetSet?,
        derivationKind: XMLSchemaSimpleTypeDerivationKind,
        listItemQName: XMLQualifiedName?,
        unionMemberQNames: [XMLQualifiedName]
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.baseQName = baseQName
        self.enumerationValues = enumerationValues
        self.pattern = pattern
        self.facets = facets
        self.derivationKind = derivationKind
        self.listItemQName = listItemQName
        self.unionMemberQNames = unionMemberQNames
    }
}

public struct XMLNormalizedComplexType: Sendable, Equatable, Codable {
    public let componentID: XMLSchemaComponentID
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let namespaceURI: String?
    public let baseQName: XMLQualifiedName?
    public let baseDerivationKind: XMLSchemaContentDerivationKind?
    public let simpleContentBaseQName: XMLQualifiedName?
    public let simpleContentDerivationKind: XMLSchemaContentDerivationKind?
    public let inheritedComplexTypeQName: XMLQualifiedName?
    public let effectiveSimpleContentValueTypeQName: XMLQualifiedName?
    public let declaredContent: [XMLNormalizedContentNode]
    public let effectiveContent: [XMLNormalizedContentNode]
    public let declaredAttributes: [XMLNormalizedAttributeUse]
    public let effectiveAttributes: [XMLNormalizedAttributeUse]
    public let anyAttribute: XMLSchemaWildcard?
    public let isAbstract: Bool
    public let isMixed: Bool
    public let isAnonymous: Bool

    public var declaredSequence: [XMLNormalizedElementUse] {
        declaredContent.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var declaredChoiceGroups: [XMLNormalizedChoiceGroup] {
        declaredContent.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var declaredAnyElements: [XMLSchemaWildcard] {
        declaredContent.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public var effectiveSequence: [XMLNormalizedElementUse] {
        effectiveContent.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var effectiveChoiceGroups: [XMLNormalizedChoiceGroup] {
        effectiveContent.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var effectiveAnyElements: [XMLSchemaWildcard] {
        effectiveContent.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public init(
        componentID: XMLSchemaComponentID,
        annotation: XMLSchemaAnnotation?,
        name: String,
        namespaceURI: String?,
        baseQName: XMLQualifiedName?,
        baseDerivationKind: XMLSchemaContentDerivationKind?,
        simpleContentBaseQName: XMLQualifiedName?,
        simpleContentDerivationKind: XMLSchemaContentDerivationKind?,
        inheritedComplexTypeQName: XMLQualifiedName?,
        effectiveSimpleContentValueTypeQName: XMLQualifiedName?,
        declaredContent: [XMLNormalizedContentNode],
        effectiveContent: [XMLNormalizedContentNode],
        declaredAttributes: [XMLNormalizedAttributeUse],
        effectiveAttributes: [XMLNormalizedAttributeUse],
        anyAttribute: XMLSchemaWildcard?,
        isAbstract: Bool,
        isMixed: Bool = false,
        isAnonymous: Bool
    ) {
        self.componentID = componentID
        self.annotation = annotation
        self.name = name
        self.namespaceURI = namespaceURI
        self.baseQName = baseQName
        self.baseDerivationKind = baseDerivationKind
        self.simpleContentBaseQName = simpleContentBaseQName
        self.simpleContentDerivationKind = simpleContentDerivationKind
        self.inheritedComplexTypeQName = inheritedComplexTypeQName
        self.effectiveSimpleContentValueTypeQName = effectiveSimpleContentValueTypeQName
        self.declaredContent = declaredContent
        self.effectiveContent = effectiveContent
        self.declaredAttributes = declaredAttributes
        self.effectiveAttributes = effectiveAttributes
        self.anyAttribute = anyAttribute
        self.isAbstract = isAbstract
        self.isMixed = isMixed
        self.isAnonymous = isAnonymous
    }
}

public struct XMLNormalizedSchema: Sendable, Equatable, Codable {
    public let annotation: XMLSchemaAnnotation?
    public let targetNamespace: String?
    public let elements: [XMLNormalizedElementDeclaration]
    public let attributeDefinitions: [XMLNormalizedAttributeDefinition]
    public let attributeGroups: [XMLNormalizedAttributeGroup]
    public let modelGroups: [XMLNormalizedModelGroup]
    public let complexTypes: [XMLNormalizedComplexType]
    public let simpleTypes: [XMLNormalizedSimpleType]

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        targetNamespace: String?,
        elements: [XMLNormalizedElementDeclaration],
        attributeDefinitions: [XMLNormalizedAttributeDefinition],
        attributeGroups: [XMLNormalizedAttributeGroup],
        modelGroups: [XMLNormalizedModelGroup],
        complexTypes: [XMLNormalizedComplexType],
        simpleTypes: [XMLNormalizedSimpleType]
    ) {
        self.annotation = annotation
        self.targetNamespace = targetNamespace
        self.elements = elements
        self.attributeDefinitions = attributeDefinitions
        self.attributeGroups = attributeGroups
        self.modelGroups = modelGroups
        self.complexTypes = complexTypes
        self.simpleTypes = simpleTypes
    }
}

// MARK: - XMLNormalizedSchemaSet

/// Holds the result of ``XMLSchemaSourceLocation`` after normalisation and stores pre-computed
/// indices so that every lookup is O(1) rather than O(n × m).
public struct XMLNormalizedSchemaSet: Sendable, Equatable, Codable {
    public let schemas: [XMLNormalizedSchema]

    // Namespace-qualified key  → component
    // Bare key (namespaceURI: nil) → first component with that local name across all schemas
    private let elementIndex: [String: XMLNormalizedElementDeclaration]
    private let complexTypeIndex: [String: XMLNormalizedComplexType]
    private let simpleTypeIndex: [String: XMLNormalizedSimpleType]
    private let attributeIndex: [String: XMLNormalizedAttributeDefinition]
    private let attributeGroupIndex: [String: XMLNormalizedAttributeGroup]
    private let modelGroupIndex: [String: XMLNormalizedModelGroup]

    // typeQName key → (elementName, schemaNamespace)
    private struct _RootBinding: Equatable {
        let elementName: String
        let namespaceURI: String?
    }
    private let rootElementByTypeIndex: [String: _RootBinding]

    // head-element key → [members]
    private let substitutionGroupIndex: [String: [XMLNormalizedElementDeclaration]]

    // base-type key → [types that directly derive from it]
    private let derivedComplexTypeIndex: [String: [XMLNormalizedComplexType]]
    private let derivedSimpleTypeIndex: [String: [XMLNormalizedSimpleType]]

    public init(schemas: [XMLNormalizedSchema]) {
        self.schemas = schemas

        var elemIdx: [String: XMLNormalizedElementDeclaration] = [:]
        var ctIdx: [String: XMLNormalizedComplexType] = [:]
        var stIdx: [String: XMLNormalizedSimpleType] = [:]
        var attrIdx: [String: XMLNormalizedAttributeDefinition] = [:]
        var agIdx: [String: XMLNormalizedAttributeGroup] = [:]
        var mgIdx: [String: XMLNormalizedModelGroup] = [:]
        var rootIdx: [String: _RootBinding] = [:]
        var sgIdx: [String: [XMLNormalizedElementDeclaration]] = [:]
        var dcIdx: [String: [XMLNormalizedComplexType]] = [:]
        var dsIdx: [String: [XMLNormalizedSimpleType]] = [:]

        for schema in schemas {
            let ns = schema.targetNamespace

            for element in schema.elements {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: element.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: element.name)
                elemIdx[qualKey] = element
                if elemIdx[bareKey] == nil { elemIdx[bareKey] = element }

                if let typeQName = element.typeQName {
                    let binding = _RootBinding(elementName: element.name, namespaceURI: ns)
                    // Namespace-qualified key
                    let typeKey = Self.makeLookupKey(namespaceURI: typeQName.namespaceURI, localName: typeQName.localName)
                    if rootIdx[typeKey] == nil { rootIdx[typeKey] = binding }
                    // Bare key — replicates the original fallback that scanned all schemas
                    // by local name only (ignoring the type's namespace).
                    let bareTypeKey = Self.makeLookupKey(namespaceURI: nil, localName: typeQName.localName)
                    if rootIdx[bareTypeKey] == nil { rootIdx[bareTypeKey] = binding }
                }

                if let sg = element.substitutionGroup {
                    let sgKey = Self.makeLookupKey(namespaceURI: sg.namespaceURI, localName: sg.localName)
                    sgIdx[sgKey, default: []].append(element)
                }
            }

            for complexType in schema.complexTypes {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: complexType.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: complexType.name)
                ctIdx[qualKey] = complexType
                if ctIdx[bareKey] == nil { ctIdx[bareKey] = complexType }

                // `inheritedComplexTypeQName` is the resolved parent complex type (set by the
                // normalizer to baseQName for complex-content derivation, or simpleContentBaseQName
                // when the simple-content base is itself a complex type).
                let baseKey = complexType.inheritedComplexTypeQName.map {
                    Self.makeLookupKey(namespaceURI: $0.namespaceURI, localName: $0.localName)
                }
                if let key = baseKey {
                    dcIdx[key, default: []].append(complexType)
                }
            }

            for simpleType in schema.simpleTypes {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: simpleType.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: simpleType.name)
                stIdx[qualKey] = simpleType
                if stIdx[bareKey] == nil { stIdx[bareKey] = simpleType }

                if let baseQName = simpleType.baseQName {
                    let baseKey = Self.makeLookupKey(namespaceURI: baseQName.namespaceURI, localName: baseQName.localName)
                    dsIdx[baseKey, default: []].append(simpleType)
                }
            }

            for attribute in schema.attributeDefinitions {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: attribute.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: attribute.name)
                attrIdx[qualKey] = attribute
                if attrIdx[bareKey] == nil { attrIdx[bareKey] = attribute }
            }

            for attributeGroup in schema.attributeGroups {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: attributeGroup.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: attributeGroup.name)
                agIdx[qualKey] = attributeGroup
                if agIdx[bareKey] == nil { agIdx[bareKey] = attributeGroup }
            }

            for modelGroup in schema.modelGroups {
                let qualKey = Self.makeLookupKey(namespaceURI: ns, localName: modelGroup.name)
                let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: modelGroup.name)
                mgIdx[qualKey] = modelGroup
                if mgIdx[bareKey] == nil { mgIdx[bareKey] = modelGroup }
            }
        }

        elementIndex = elemIdx
        complexTypeIndex = ctIdx
        simpleTypeIndex = stIdx
        attributeIndex = attrIdx
        attributeGroupIndex = agIdx
        modelGroupIndex = mgIdx
        rootElementByTypeIndex = rootIdx
        substitutionGroupIndex = sgIdx
        derivedComplexTypeIndex = dcIdx
        derivedSimpleTypeIndex = dsIdx
    }

    // MARK: - O(1) Component Lookups

    public func element(named localName: String, namespaceURI: String?) -> XMLNormalizedElementDeclaration? {
        if let ns = namespaceURI,
           let result = elementIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return elementIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func complexType(named localName: String, namespaceURI: String?) -> XMLNormalizedComplexType? {
        if let ns = namespaceURI,
           let result = complexTypeIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return complexTypeIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func simpleType(named localName: String, namespaceURI: String?) -> XMLNormalizedSimpleType? {
        if let ns = namespaceURI,
           let result = simpleTypeIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return simpleTypeIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func attribute(named localName: String, namespaceURI: String?) -> XMLNormalizedAttributeDefinition? {
        if let ns = namespaceURI,
           let result = attributeIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return attributeIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func attributeGroup(named localName: String, namespaceURI: String?) -> XMLNormalizedAttributeGroup? {
        if let ns = namespaceURI,
           let result = attributeGroupIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return attributeGroupIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func modelGroup(named localName: String, namespaceURI: String?) -> XMLNormalizedModelGroup? {
        if let ns = namespaceURI,
           let result = modelGroupIndex[Self.makeLookupKey(namespaceURI: ns, localName: localName)] {
            return result
        }
        return modelGroupIndex[Self.makeLookupKey(namespaceURI: nil, localName: localName)]
    }

    public func rootElementBinding(forTypeNamed localName: String, namespaceURI: String?) -> (name: String, namespaceURI: String?)? {
        // 1. Exact namespace+localName match
        if let ns = namespaceURI {
            let key = Self.makeLookupKey(namespaceURI: ns, localName: localName)
            if let binding = rootElementByTypeIndex[key] {
                return (binding.elementName, binding.namespaceURI)
            }
        }
        // 2. Bare fallback — matches any element whose type has this localName (mirrors old O(n) scan)
        let bareKey = Self.makeLookupKey(namespaceURI: nil, localName: localName)
        if let binding = rootElementByTypeIndex[bareKey] {
            return (binding.elementName, binding.namespaceURI)
        }
        return nil
    }

    public func substitutionGroupMembers(ofLocalName localName: String, namespaceURI: String?) -> [XMLNormalizedElementDeclaration] {
        substitutionGroupIndex[Self.makeLookupKey(namespaceURI: namespaceURI, localName: localName)] ?? []
    }

    // MARK: - Type Hierarchy Navigator

    /// Returns the normalized complex type that `complexType` directly derives from, if it exists
    /// in this schema set. Returns `nil` for root types or types that extend built-in XSD primitives.
    public func baseComplexType(of complexType: XMLNormalizedComplexType) -> XMLNormalizedComplexType? {
        guard let qName = complexType.inheritedComplexTypeQName else { return nil }
        return self.complexType(named: qName.localName, namespaceURI: qName.namespaceURI)
    }

    /// Returns the normalized simple type that `simpleType` directly derives from, if it exists
    /// in this schema set. Returns `nil` for types derived from built-in XSD primitives.
    public func baseSimpleType(of simpleType: XMLNormalizedSimpleType) -> XMLNormalizedSimpleType? {
        guard let qName = simpleType.baseQName else { return nil }
        return self.simpleType(named: qName.localName, namespaceURI: qName.namespaceURI)
    }

    /// Returns all complex types in this schema set that directly extend or restrict `complexType`.
    public func derivedComplexTypes(of complexType: XMLNormalizedComplexType) -> [XMLNormalizedComplexType] {
        let key = Self.makeLookupKey(namespaceURI: complexType.namespaceURI, localName: complexType.name)
        return derivedComplexTypeIndex[key] ?? []
    }

    /// Returns all simple types in this schema set that directly derive from `simpleType`.
    public func derivedSimpleTypes(of simpleType: XMLNormalizedSimpleType) -> [XMLNormalizedSimpleType] {
        let key = Self.makeLookupKey(namespaceURI: simpleType.namespaceURI, localName: simpleType.name)
        return derivedSimpleTypeIndex[key] ?? []
    }

    /// Returns `true` if `element` is a direct member of `head`'s substitution group —
    /// i.e., `element` can appear wherever `head` is referenced in an instance document.
    ///
    /// - Note: Only direct membership is checked. Transitive chains
    ///   (A substitutes B which substitutes C) are deferred to Phase 0.4.
    public func canSubstitute(
        _ element: XMLNormalizedElementDeclaration,
        for head: XMLNormalizedElementDeclaration
    ) -> Bool {
        guard let sg = element.substitutionGroup else { return false }
        return sg.localName == head.name && sg.namespaceURI == head.namespaceURI
    }

    // MARK: - Private

    private static func makeLookupKey(namespaceURI: String?, localName: String) -> String {
        "\(namespaceURI ?? ""):\(localName)"
    }
}

public struct XMLSchemaNormalizer: Sendable {
    public init() {}

    #if swift(>=6.0)
    public func normalize(_ schemaSet: XMLSchemaSet) throws(XMLSchemaParsingError) -> XMLNormalizedSchemaSet {
        do {
            return try normalizeImpl(schemaSet)
        } catch let error as XMLSchemaParsingError {
            throw error
        } catch {
            preconditionFailure("Unexpected non-XMLSchemaParsingError: \(error)")
        }
    }
    #else
    public func normalize(_ schemaSet: XMLSchemaSet) throws -> XMLNormalizedSchemaSet {
        try normalizeImpl(schemaSet)
    }
    #endif

    private func normalizeImpl(_ schemaSet: XMLSchemaSet) throws -> XMLNormalizedSchemaSet {
        var augmentor = InlineTypeAugmentor()
        let augmentedSchemaSet = try augmentor.augment(schemaSet)
        let resolver = RawNormalizationResolver(schemaSet: augmentedSchemaSet)

        let normalizedSchemas: [XMLNormalizedSchema] = try augmentedSchemaSet.schemas.map { schema in
            let normalizedElements = schema.elements.enumerated().map { index, element in
                normalizeElementDeclaration(
                    element,
                    namespaceURI: schema.targetNamespace,
                    resolver: resolver,
                    contextPath: ["element", element.name, "\(index)"]
                )
            }
            let normalizedAttributeDefinitions = schema.attributeDefinitions.enumerated().map { index, attribute in
                normalizeAttributeDefinition(
                    attribute,
                    namespaceURI: schema.targetNamespace,
                    contextPath: ["attribute", attribute.name, "\(index)"]
                )
            }
            let normalizedAttributeGroups = try schema.attributeGroups.enumerated().map { index, attributeGroup in
                try normalizeAttributeGroup(
                    attributeGroup,
                    namespaceURI: schema.targetNamespace,
                    resolver: resolver,
                    contextPath: ["attributeGroup", attributeGroup.name, "\(index)"]
                )
            }
            let normalizedModelGroups = try schema.modelGroups.enumerated().map { index, modelGroup in
                try normalizeModelGroup(
                    modelGroup,
                    namespaceURI: schema.targetNamespace,
                    resolver: resolver,
                    contextPath: ["group", modelGroup.name, "\(index)"]
                )
            }
            let normalizedComplexTypes = try schema.complexTypes.enumerated().map { index, complexType in
                try normalizeComplexType(
                    complexType,
                    namespaceURI: schema.targetNamespace,
                    resolver: resolver,
                    contextPath: ["complexType", complexType.name, "\(index)"]
                )
            }
            let normalizedSimpleTypes = schema.simpleTypes.enumerated().map { index, simpleType in
                normalizeSimpleType(
                    simpleType,
                    namespaceURI: schema.targetNamespace,
                    contextPath: ["simpleType", simpleType.name, "\(index)"]
                )
            }

            return XMLNormalizedSchema(
                annotation: schema.annotation,
                targetNamespace: schema.targetNamespace,
                elements: normalizedElements,
                attributeDefinitions: normalizedAttributeDefinitions,
                attributeGroups: normalizedAttributeGroups,
                modelGroups: normalizedModelGroups,
                complexTypes: normalizedComplexTypes,
                simpleTypes: normalizedSimpleTypes
            )
        }

        return XMLNormalizedSchemaSet(schemas: normalizedSchemas)
    }
}  // end XMLSchemaNormalizer

private extension XMLSchemaNormalizer {
    struct ResolvedElementMetadata {
        let annotation: XMLSchemaAnnotation?
        let name: String
        let namespaceURI: String?
        let typeQName: XMLQualifiedName?
        let nillable: Bool
        let defaultValue: String?
        let fixedValue: String?
        let isAbstract: Bool
        let substitutionGroup: XMLQualifiedName?
    }

    struct ResolvedComplexTypeDerivation {
        let inheritedComplexTypeQName: XMLQualifiedName?
        let effectiveSimpleContentValueTypeQName: XMLQualifiedName?
        let effectiveContent: [XMLNormalizedContentNode]
        let effectiveAttributes: [XMLNormalizedAttributeUse]
    }

    struct RawNormalizationResolver {
        let schemaSet: XMLSchemaSet

        func element(named localName: String, namespaceURI: String?) -> XMLSchemaElement? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let element = schema.elements.first(where: { $0.name == localName }) {
                        return element
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let element = schema.elements.first(where: { $0.name == localName }) {
                    return element
                }
            }
            return nil
        }

        func complexType(named localName: String, namespaceURI: String?) -> XMLSchemaComplexType? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                        return complexType
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                    return complexType
                }
            }
            return nil
        }

        func simpleType(named localName: String, namespaceURI: String?) -> XMLSchemaSimpleType? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let simpleType = schema.simpleTypes.first(where: { $0.name == localName }) {
                        return simpleType
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let simpleType = schema.simpleTypes.first(where: { $0.name == localName }) {
                    return simpleType
                }
            }
            return nil
        }

        func attribute(named localName: String, namespaceURI: String?) -> XMLSchemaAttribute? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let attribute = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                        return attribute
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let attribute = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                    return attribute
                }
            }
            return nil
        }

        func attributeGroup(named localName: String, namespaceURI: String?) -> XMLSchemaAttributeGroup? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                        return attributeGroup
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                    return attributeGroup
                }
            }
            return nil
        }

        func modelGroup(named localName: String, namespaceURI: String?) -> XMLSchemaModelGroup? {
            if let namespaceURI = namespaceURI {
                for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                    if let modelGroup = schema.modelGroups.first(where: { $0.name == localName }) {
                        return modelGroup
                    }
                }
            }
            for schema in schemaSet.schemas {
                if let modelGroup = schema.modelGroups.first(where: { $0.name == localName }) {
                    return modelGroup
                }
            }
            return nil
        }
    }

    struct InlineTypeAugmentor {
        private struct InlineTypeResult {
            var element: XMLSchemaElement
            var complexTypes: [XMLSchemaComplexType]
            var simpleTypes: [XMLSchemaSimpleType]
        }

        private struct AttributeRewriteResult {
            var attribute: XMLSchemaAttribute
            var simpleTypes: [XMLSchemaSimpleType]
        }

        private var usedTypeNames = Set<String>()

        mutating func augment(_ schemaSet: XMLSchemaSet) throws -> XMLSchemaSet {
            var rewrittenSchemas: [XMLSchema] = []

            for schema in schemaSet.schemas {
                usedTypeNames.formUnion(schema.complexTypes.map(\.name))
                usedTypeNames.formUnion(schema.simpleTypes.map(\.name))

                var synthesizedComplexTypes: [XMLSchemaComplexType] = []
                var synthesizedSimpleTypes: [XMLSchemaSimpleType] = []

                let rewrittenElements: [XMLSchemaElement] = try schema.elements.enumerated().map { index, element in
                    let result = try rewriteElement(
                        element,
                        namespaceURI: schema.targetNamespace,
                        path: ["schema", "element", element.name, "\(index)"]
                    )
                    synthesizedComplexTypes.append(contentsOf: result.complexTypes)
                    synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                    return result.element
                }

                let rewrittenAttributeDefinitions: [XMLSchemaAttribute] = try schema.attributeDefinitions.enumerated().map { index, attribute in
                    let result = try rewriteAttribute(
                        attribute,
                        namespaceURI: schema.targetNamespace,
                        path: ["schema", "attribute", attribute.name, "\(index)"]
                    )
                    synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                    return result.attribute
                }

                let rewrittenAttributeGroups = try schema.attributeGroups.enumerated().map { index, attributeGroup in
                    try rewriteAttributeGroup(
                        attributeGroup,
                        namespaceURI: schema.targetNamespace,
                        path: ["schema", "attributeGroup", attributeGroup.name, "\(index)"],
                        synthesizedSimpleTypes: &synthesizedSimpleTypes
                    )
                }

                let rewrittenModelGroups = try schema.modelGroups.enumerated().map { index, modelGroup in
                    try rewriteModelGroup(
                        modelGroup,
                        namespaceURI: schema.targetNamespace,
                        path: ["schema", "group", modelGroup.name, "\(index)"],
                        synthesizedComplexTypes: &synthesizedComplexTypes,
                        synthesizedSimpleTypes: &synthesizedSimpleTypes
                    )
                }

                let rewrittenComplexTypes = try schema.complexTypes.enumerated().map { index, complexType in
                    try rewriteComplexType(
                        complexType,
                        namespaceURI: schema.targetNamespace,
                        path: ["schema", "complexType", complexType.name, "\(index)"],
                        synthesizedComplexTypes: &synthesizedComplexTypes,
                        synthesizedSimpleTypes: &synthesizedSimpleTypes
                    )
                }

                rewrittenSchemas.append(
                    XMLSchema(
                        annotation: schema.annotation,
                        targetNamespace: schema.targetNamespace,
                        imports: schema.imports,
                        includes: schema.includes,
                        elements: rewrittenElements,
                        attributeDefinitions: rewrittenAttributeDefinitions,
                        attributeGroups: rewrittenAttributeGroups,
                        modelGroups: rewrittenModelGroups,
                        complexTypes: rewrittenComplexTypes + synthesizedComplexTypes,
                        simpleTypes: schema.simpleTypes + synthesizedSimpleTypes
                    )
                )
            }

            return XMLSchemaSet(schemas: rewrittenSchemas)
        }

        private mutating func rewriteComplexType(
            _ complexType: XMLSchemaComplexType,
            namespaceURI: String?,
            path: [String],
            synthesizedComplexTypes: inout [XMLSchemaComplexType],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> XMLSchemaComplexType {
            let rewrittenContent = try rewriteContent(
                complexType.content,
                namespaceURI: namespaceURI,
                path: path + ["content"],
                synthesizedComplexTypes: &synthesizedComplexTypes,
                synthesizedSimpleTypes: &synthesizedSimpleTypes
            )
            let rewrittenAttributes: [XMLSchemaAttribute] = try complexType.attributes.enumerated().map { index, attribute in
                let result = try rewriteAttribute(
                    attribute,
                    namespaceURI: namespaceURI,
                    path: path + ["attribute", attribute.name, "\(index)"]
                )
                synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                return result.attribute
            }
            return XMLSchemaComplexType(
                annotation: complexType.annotation,
                name: complexType.name,
                baseQName: complexType.baseQName,
                baseDerivationKind: complexType.baseDerivationKind,
                simpleContentBaseQName: complexType.simpleContentBaseQName,
                simpleContentDerivationKind: complexType.simpleContentDerivationKind,
                isAbstract: complexType.isAbstract,
                isMixed: complexType.isMixed,
                sequence: [],
                choiceGroups: [],
                content: rewrittenContent,
                attributes: rewrittenAttributes,
                attributeRefs: complexType.attributeRefs,
                attributeGroupRefs: complexType.attributeGroupRefs,
                anyAttribute: complexType.anyAttribute
            )
        }

        private mutating func rewriteModelGroup(
            _ modelGroup: XMLSchemaModelGroup,
            namespaceURI: String?,
            path: [String],
            synthesizedComplexTypes: inout [XMLSchemaComplexType],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> XMLSchemaModelGroup {
            XMLSchemaModelGroup(
                name: modelGroup.name,
                content: try rewriteContent(
                    modelGroup.content,
                    namespaceURI: namespaceURI,
                    path: path + ["content"],
                    synthesizedComplexTypes: &synthesizedComplexTypes,
                    synthesizedSimpleTypes: &synthesizedSimpleTypes
                )
            )
        }

        private mutating func rewriteAttributeGroup(
            _ attributeGroup: XMLSchemaAttributeGroup,
            namespaceURI: String?,
            path: [String],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> XMLSchemaAttributeGroup {
            XMLSchemaAttributeGroup(
                name: attributeGroup.name,
                attributes: try attributeGroup.attributes.enumerated().map { index, attribute in
                    let result = try rewriteAttribute(
                        attribute,
                        namespaceURI: namespaceURI,
                        path: path + ["attribute", attribute.name, "\(index)"]
                    )
                    synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                    return result.attribute
                },
                attributeRefs: attributeGroup.attributeRefs,
                attributeGroupRefs: attributeGroup.attributeGroupRefs
            )
        }

        private mutating func rewriteContent(
            _ content: [XMLSchemaContentNode],
            namespaceURI: String?,
            path: [String],
            synthesizedComplexTypes: inout [XMLSchemaComplexType],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> [XMLSchemaContentNode] {
            try content.enumerated().map { index, node in
                switch node {
                case let .element(element):
                    let result = try rewriteElement(
                        element,
                        namespaceURI: namespaceURI,
                        path: path + ["element", element.name, "\(index)"]
                    )
                    synthesizedComplexTypes.append(contentsOf: result.complexTypes)
                    synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                    return .element(result.element)
                case let .choice(choiceGroup):
                    return .choice(
                        try rewriteChoiceGroup(
                            choiceGroup,
                            namespaceURI: namespaceURI,
                            path: path + ["choice", "\(index)"],
                            synthesizedComplexTypes: &synthesizedComplexTypes,
                            synthesizedSimpleTypes: &synthesizedSimpleTypes
                        )
                    )
                case let .groupReference(groupReference):
                    return .groupReference(groupReference)
                case let .wildcard(wildcard):
                    return .wildcard(wildcard)
                }
            }
        }

        private mutating func rewriteChoiceGroup(
            _ choiceGroup: XMLSchemaChoiceGroup,
            namespaceURI: String?,
            path: [String],
            synthesizedComplexTypes: inout [XMLSchemaComplexType],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> XMLSchemaChoiceGroup {
            XMLSchemaChoiceGroup(
                elements: [],
                minOccurs: choiceGroup.minOccurs,
                maxOccurs: choiceGroup.maxOccurs,
                content: try rewriteContent(
                    choiceGroup.content,
                    namespaceURI: namespaceURI,
                    path: path + ["content"],
                    synthesizedComplexTypes: &synthesizedComplexTypes,
                    synthesizedSimpleTypes: &synthesizedSimpleTypes
                )
            )
        }

        private mutating func rewriteElement(
            _ element: XMLSchemaElement,
            namespaceURI: String?,
            path: [String]
        ) throws -> InlineTypeResult {
            var rewrittenElement = element
            var synthesizedComplexTypes: [XMLSchemaComplexType] = []
            var synthesizedSimpleTypes: [XMLSchemaSimpleType] = []

            if let inlineComplexType = element.inlineComplexType,
               element.typeQName == nil,
               element.refQName == nil {
                let synthesizedLocalName = nextSyntheticTypeName(from: path + [element.name])
                var nestedComplexTypes: [XMLSchemaComplexType] = []
                var nestedSimpleTypes: [XMLSchemaSimpleType] = []
                let rewrittenAnonymous = try rewriteAnonymousComplexType(
                    inlineComplexType,
                    namespaceURI: namespaceURI,
                    path: path + ["inlineComplexType"],
                    synthesizedComplexTypes: &nestedComplexTypes,
                    synthesizedSimpleTypes: &nestedSimpleTypes
                )
                synthesizedComplexTypes.append(contentsOf: nestedComplexTypes)
                synthesizedSimpleTypes.append(contentsOf: nestedSimpleTypes)
                synthesizedComplexTypes.append(
                    XMLSchemaComplexType(
                        annotation: rewrittenAnonymous.annotation,
                        name: synthesizedLocalName,
                        baseQName: rewrittenAnonymous.baseQName,
                        baseDerivationKind: rewrittenAnonymous.baseDerivationKind,
                        simpleContentBaseQName: rewrittenAnonymous.simpleContentBaseQName,
                        simpleContentDerivationKind: rewrittenAnonymous.simpleContentDerivationKind,
                        isAbstract: rewrittenAnonymous.isAbstract,
                        isMixed: rewrittenAnonymous.isMixed,
                        sequence: [],
                        choiceGroups: [],
                        content: rewrittenAnonymous.content,
                        attributes: rewrittenAnonymous.attributes,
                        attributeRefs: rewrittenAnonymous.attributeRefs,
                        attributeGroupRefs: rewrittenAnonymous.attributeGroupRefs,
                        anyAttribute: rewrittenAnonymous.anyAttribute
                    )
                )
                rewrittenElement = XMLSchemaElement(
                    annotation: element.annotation,
                    name: element.name,
                    typeQName: makeQName(localName: synthesizedLocalName, namespaceURI: namespaceURI),
                    refQName: element.refQName,
                    minOccurs: element.minOccurs,
                    maxOccurs: element.maxOccurs,
                    nillable: element.nillable,
                    defaultValue: element.defaultValue,
                    fixedValue: element.fixedValue,
                    isAbstract: element.isAbstract,
                    substitutionGroup: element.substitutionGroup,
                    identityConstraints: element.identityConstraints,
                    inlineComplexType: inlineComplexType,
                    inlineSimpleType: nil
                )
            } else if let inlineSimpleType = element.inlineSimpleType,
                      element.typeQName == nil,
                      element.refQName == nil {
                let synthesizedLocalName = nextSyntheticTypeName(from: path + [element.name, "Value"])
                synthesizedSimpleTypes.append(
                    makeNamedSimpleType(
                        name: synthesizedLocalName,
                        anonymousSimpleType: inlineSimpleType
                    )
                )
                rewrittenElement = XMLSchemaElement(
                    annotation: element.annotation,
                    name: element.name,
                    typeQName: makeQName(localName: synthesizedLocalName, namespaceURI: namespaceURI),
                    refQName: element.refQName,
                    minOccurs: element.minOccurs,
                    maxOccurs: element.maxOccurs,
                    nillable: element.nillable,
                    defaultValue: element.defaultValue,
                    fixedValue: element.fixedValue,
                    isAbstract: element.isAbstract,
                    substitutionGroup: element.substitutionGroup,
                    identityConstraints: element.identityConstraints,
                    inlineComplexType: nil,
                    inlineSimpleType: inlineSimpleType
                )
            }

            return InlineTypeResult(
                element: rewrittenElement,
                complexTypes: synthesizedComplexTypes,
                simpleTypes: synthesizedSimpleTypes
            )
        }

        private mutating func rewriteAnonymousComplexType(
            _ complexType: XMLSchemaAnonymousComplexType,
            namespaceURI: String?,
            path: [String],
            synthesizedComplexTypes: inout [XMLSchemaComplexType],
            synthesizedSimpleTypes: inout [XMLSchemaSimpleType]
        ) throws -> XMLSchemaAnonymousComplexType {
            let rewrittenContent = try rewriteContent(
                complexType.content,
                namespaceURI: namespaceURI,
                path: path + ["content"],
                synthesizedComplexTypes: &synthesizedComplexTypes,
                synthesizedSimpleTypes: &synthesizedSimpleTypes
            )
            let rewrittenAttributes: [XMLSchemaAttribute] = try complexType.attributes.enumerated().map { index, attribute in
                let result = try rewriteAttribute(
                    attribute,
                    namespaceURI: namespaceURI,
                    path: path + ["attribute", attribute.name, "\(index)"]
                )
                synthesizedSimpleTypes.append(contentsOf: result.simpleTypes)
                return result.attribute
            }
            return XMLSchemaAnonymousComplexType(
                annotation: complexType.annotation,
                baseQName: complexType.baseQName,
                baseDerivationKind: complexType.baseDerivationKind,
                simpleContentBaseQName: complexType.simpleContentBaseQName,
                simpleContentDerivationKind: complexType.simpleContentDerivationKind,
                isAbstract: complexType.isAbstract,
                isMixed: complexType.isMixed,
                sequence: [],
                choiceGroups: [],
                content: rewrittenContent,
                attributes: rewrittenAttributes,
                attributeRefs: complexType.attributeRefs,
                attributeGroupRefs: complexType.attributeGroupRefs,
                anyAttribute: complexType.anyAttribute
            )
        }

        private mutating func rewriteAttribute(
            _ attribute: XMLSchemaAttribute,
            namespaceURI: String?,
            path: [String]
        ) throws -> AttributeRewriteResult {
            guard let inlineSimpleType = attribute.inlineSimpleType, attribute.typeQName == nil else {
                return AttributeRewriteResult(attribute: attribute, simpleTypes: [])
            }

            let synthesizedLocalName = nextSyntheticTypeName(from: path + [attribute.name, "Attribute"])
            return AttributeRewriteResult(
                attribute: XMLSchemaAttribute(
                    annotation: attribute.annotation,
                    name: attribute.name,
                    typeQName: makeQName(localName: synthesizedLocalName, namespaceURI: namespaceURI),
                    use: attribute.use,
                    defaultValue: attribute.defaultValue,
                    fixedValue: attribute.fixedValue,
                    inlineSimpleType: inlineSimpleType
                ),
                simpleTypes: [makeNamedSimpleType(name: synthesizedLocalName, anonymousSimpleType: inlineSimpleType)]
            )
        }

        private mutating func nextSyntheticTypeName(from path: [String]) -> String {
            let baseName = path
                .map { component in
                    component
                        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                        .map { chunk in chunk.prefix(1).uppercased() + chunk.dropFirst() }
                        .joined()
                }
                .joined()
            let fallback = baseName.isEmpty ? "AnonymousType" : baseName

            if !usedTypeNames.contains(fallback) {
                usedTypeNames.insert(fallback)
                return fallback
            }

            let suffixed = fallback + "Type"
            if !usedTypeNames.contains(suffixed) {
                usedTypeNames.insert(suffixed)
                return suffixed
            }

            var index = 2
            while usedTypeNames.contains("\(suffixed)\(index)") {
                index += 1
            }
            let resolved = "\(suffixed)\(index)"
            usedTypeNames.insert(resolved)
            return resolved
        }

        private func makeQName(localName: String, namespaceURI: String?) -> XMLQualifiedName {
            XMLQualifiedName(localName: localName, namespaceURI: namespaceURI)
        }

        private func makeNamedSimpleType(
            name: String,
            anonymousSimpleType: XMLSchemaAnonymousSimpleType
        ) -> XMLSchemaSimpleType {
            XMLSchemaSimpleType(
                annotation: anonymousSimpleType.annotation,
                name: name,
                baseQName: anonymousSimpleType.baseQName,
                enumerationValues: anonymousSimpleType.enumerationValues,
                pattern: anonymousSimpleType.pattern,
                facets: anonymousSimpleType.facets,
                derivationKind: anonymousSimpleType.derivationKind,
                listItemQName: anonymousSimpleType.listItemQName,
                unionMemberQNames: anonymousSimpleType.unionMemberQNames,
                unionInlineSimpleTypes: anonymousSimpleType.unionInlineSimpleTypes
            )
        }
    }

    private func normalizeElementDeclaration(
        _ element: XMLSchemaElement,
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String]
    ) -> XMLNormalizedElementDeclaration {
        let resolvedElement = resolveElementMetadata(for: element, namespaceURI: namespaceURI, resolver: resolver)
        return XMLNormalizedElementDeclaration(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "element", path: contextPath),
            annotation: resolvedElement.annotation,
            name: resolvedElement.name,
            namespaceURI: resolvedElement.namespaceURI,
            typeQName: resolvedElement.typeQName,
            nillable: resolvedElement.nillable,
            defaultValue: resolvedElement.defaultValue,
            fixedValue: resolvedElement.fixedValue,
            isAbstract: resolvedElement.isAbstract,
            substitutionGroup: resolvedElement.substitutionGroup,
            identityConstraints: element.identityConstraints,
            occurrenceBounds: element.occurrenceBounds
        )
    }

    private func normalizeAttributeDefinition(
        _ attribute: XMLSchemaAttribute,
        namespaceURI: String?,
        contextPath: [String]
    ) -> XMLNormalizedAttributeDefinition {
        XMLNormalizedAttributeDefinition(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "attribute", path: contextPath),
            annotation: attribute.annotation,
            name: attribute.name,
            namespaceURI: namespaceURI,
            typeQName: attribute.typeQName,
            use: attribute.use,
            defaultValue: attribute.defaultValue,
            fixedValue: attribute.fixedValue
        )
    }

    private func normalizeAttributeGroup(
        _ attributeGroup: XMLSchemaAttributeGroup,
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String]
    ) throws -> XMLNormalizedAttributeGroup {
        var visitedGroupKeys = Set<String>()
        return XMLNormalizedAttributeGroup(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "attributeGroup", path: contextPath),
            name: attributeGroup.name,
            namespaceURI: namespaceURI,
            attributes: try resolveAttributeUses(
                attributes: attributeGroup.attributes,
                attributeRefs: attributeGroup.attributeRefs,
                attributeGroupRefs: attributeGroup.attributeGroupRefs,
                namespaceURI: namespaceURI,
                resolver: resolver,
                contextPath: contextPath + ["attributes"],
                visitedGroupKeys: &visitedGroupKeys
            )
        )
    }

    private func normalizeModelGroup(
        _ modelGroup: XMLSchemaModelGroup,
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String]
    ) throws -> XMLNormalizedModelGroup {
        var visitedGroupKeys = Set<String>()
        return XMLNormalizedModelGroup(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "group", path: contextPath),
            name: modelGroup.name,
            namespaceURI: namespaceURI,
            content: try normalizeContentNodes(
                modelGroup.content,
                namespaceURI: namespaceURI,
                resolver: resolver,
                contextPath: contextPath + ["content"],
                visitedGroupKeys: &visitedGroupKeys
            )
        )
    }

    private func normalizeComplexType(
        _ complexType: XMLSchemaComplexType,
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String]
    ) throws -> XMLNormalizedComplexType {
        var visitedGroupKeys = Set<String>()
        let declaredContent = try normalizeContentNodes(
            complexType.content,
            namespaceURI: namespaceURI,
            resolver: resolver,
            contextPath: contextPath + ["declaredContent"],
            visitedGroupKeys: &visitedGroupKeys
        )

        var visitedAttributeGroupKeys = Set<String>()
        let declaredAttributes = try resolveAttributeUses(
            attributes: complexType.attributes,
            attributeRefs: complexType.attributeRefs,
            attributeGroupRefs: complexType.attributeGroupRefs,
            namespaceURI: namespaceURI,
            resolver: resolver,
            contextPath: contextPath + ["declaredAttributes"],
            visitedGroupKeys: &visitedAttributeGroupKeys
        )

        let resolvedDerivation = try resolveComplexTypeDerivation(
            complexType,
            declaredContent: declaredContent,
            declaredAttributes: declaredAttributes,
            resolver: resolver,
            contextPath: contextPath
        )

        return XMLNormalizedComplexType(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "complexType", path: contextPath),
            annotation: complexType.annotation,
            name: complexType.name,
            namespaceURI: namespaceURI,
            baseQName: complexType.baseQName,
            baseDerivationKind: complexType.baseDerivationKind,
            simpleContentBaseQName: complexType.simpleContentBaseQName,
            simpleContentDerivationKind: complexType.simpleContentDerivationKind,
            inheritedComplexTypeQName: resolvedDerivation.inheritedComplexTypeQName,
            effectiveSimpleContentValueTypeQName: resolvedDerivation.effectiveSimpleContentValueTypeQName,
            declaredContent: declaredContent,
            effectiveContent: resolvedDerivation.effectiveContent,
            declaredAttributes: declaredAttributes,
            effectiveAttributes: resolvedDerivation.effectiveAttributes,
            anyAttribute: complexType.anyAttribute,
            isAbstract: complexType.isAbstract,
            isMixed: complexType.isMixed,
            isAnonymous: contextPath.contains("Anonymous")
        )
    }

    private func normalizeSimpleType(
        _ simpleType: XMLSchemaSimpleType,
        namespaceURI: String?,
        contextPath: [String]
    ) -> XMLNormalizedSimpleType {
        XMLNormalizedSimpleType(
            componentID: makeComponentID(namespaceURI: namespaceURI, kind: "simpleType", path: contextPath),
            annotation: simpleType.annotation,
            name: simpleType.name,
            namespaceURI: namespaceURI,
            baseQName: simpleType.baseQName,
            enumerationValues: simpleType.enumerationValues,
            pattern: simpleType.pattern,
            facets: simpleType.facets,
            derivationKind: simpleType.derivationKind,
            listItemQName: simpleType.listItemQName,
            unionMemberQNames: simpleType.unionMemberQNames
        )
    }

    private func normalizeContentNodes(
        _ contentNodes: [XMLSchemaContentNode],
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String],
        visitedGroupKeys: inout Set<String>
    ) throws -> [XMLNormalizedContentNode] {
        var normalizedContent: [XMLNormalizedContentNode] = []

        for (index, contentNode) in contentNodes.enumerated() {
            switch contentNode {
            case let .element(element):
                let resolvedElement = resolveElementMetadata(for: element, namespaceURI: namespaceURI, resolver: resolver)
                normalizedContent.append(
                    .element(
                        XMLNormalizedElementUse(
                            componentID: makeComponentID(
                                namespaceURI: namespaceURI,
                                kind: "elementUse",
                                path: contextPath + [element.name, "\(index)"]
                            ),
                            annotation: resolvedElement.annotation,
                            name: resolvedElement.name,
                            namespaceURI: resolvedElement.namespaceURI,
                            typeQName: resolvedElement.typeQName,
                            nillable: resolvedElement.nillable,
                            defaultValue: resolvedElement.defaultValue,
                            fixedValue: resolvedElement.fixedValue,
                            isAbstract: resolvedElement.isAbstract,
                            substitutionGroup: resolvedElement.substitutionGroup,
                            occurrenceBounds: element.occurrenceBounds
                        )
                    )
                )
            case let .choice(choiceGroup):
                normalizedContent.append(
                    .choice(
                        XMLNormalizedChoiceGroup(
                            content: try normalizeContentNodes(
                                choiceGroup.content,
                                namespaceURI: namespaceURI,
                                resolver: resolver,
                                contextPath: contextPath + ["choice", "\(index)"],
                                visitedGroupKeys: &visitedGroupKeys
                            ),
                            occurrenceBounds: choiceGroup.occurrenceBounds
                        )
                    )
                )
            case let .wildcard(wildcard):
                normalizedContent.append(.wildcard(wildcard))
            case let .groupReference(groupReference):
                let groupKey = makeLookupKey(namespaceURI: groupReference.refQName.namespaceURI ?? namespaceURI, localName: groupReference.refQName.localName)
                guard visitedGroupKeys.insert(groupKey).inserted else {
                    throw XMLSchemaParsingError.other(message: "Cyclic group reference detected for '\(groupReference.refQName.qualifiedName)'.")
                }
                defer { visitedGroupKeys.remove(groupKey) }

                guard let modelGroup = resolver.modelGroup(
                    named: groupReference.refQName.localName,
                    namespaceURI: groupReference.refQName.namespaceURI ?? namespaceURI
                ) else {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: groupReference.refQName.localName,
                        message: "group reference '\(groupReference.refQName.qualifiedName)' could not be resolved."
                    )
                }

                let expandedGroupContent = try normalizeContentNodes(
                    modelGroup.content,
                    namespaceURI: modelGroupNamespace(modelGroup, fallback: namespaceURI),
                    resolver: resolver,
                    contextPath: contextPath + ["groupRef", groupReference.refQName.localName, "\(index)"],
                    visitedGroupKeys: &visitedGroupKeys
                )
                normalizedContent.append(contentsOf: applyOccurrence(groupReference.occurrenceBounds, to: expandedGroupContent))
            }
        }

        return normalizedContent
    }

    private func resolveAttributeUses(
        attributes: [XMLSchemaAttribute],
        attributeRefs: [XMLSchemaAttributeReference],
        attributeGroupRefs: [XMLQualifiedName],
        namespaceURI: String?,
        resolver: RawNormalizationResolver,
        contextPath: [String],
        visitedGroupKeys: inout Set<String>
    ) throws -> [XMLNormalizedAttributeUse] {
        var resolved: [XMLNormalizedAttributeUse] = attributes.enumerated().map { index, attribute in
            XMLNormalizedAttributeUse(
                componentID: makeComponentID(
                    namespaceURI: namespaceURI,
                    kind: "attributeUse",
                    path: contextPath + [attribute.name, "\(index)"]
                ),
                annotation: attribute.annotation,
                name: attribute.name,
                namespaceURI: namespaceURI,
                typeQName: attribute.typeQName,
                use: attribute.use,
                defaultValue: attribute.defaultValue,
                fixedValue: attribute.fixedValue
            )
        }

        for (index, attributeRef) in attributeRefs.enumerated() {
            guard let definition = resolver.attribute(
                named: attributeRef.refQName.localName,
                namespaceURI: attributeRef.refQName.namespaceURI ?? namespaceURI
            ) else {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: attributeRef.refQName.localName,
                    message: "attribute reference '\(attributeRef.refQName.qualifiedName)' could not be resolved."
                )
            }
            resolved.append(
                XMLNormalizedAttributeUse(
                    componentID: makeComponentID(
                        namespaceURI: namespaceURI,
                        kind: "attributeRef",
                        path: contextPath + [attributeRef.refQName.localName, "\(index)"]
                    ),
                    annotation: attributeRef.annotation ?? definition.annotation,
                    name: definition.name,
                    namespaceURI: attributeRef.refQName.namespaceURI ?? namespaceURI,
                    typeQName: definition.typeQName,
                    use: attributeRef.use ?? definition.use,
                    defaultValue: attributeRef.defaultValue ?? definition.defaultValue,
                    fixedValue: attributeRef.fixedValue ?? definition.fixedValue
                )
            )
        }

        for (index, attributeGroupRef) in attributeGroupRefs.enumerated() {
            let groupNamespaceURI = attributeGroupRef.namespaceURI ?? namespaceURI
            let groupKey = makeLookupKey(namespaceURI: groupNamespaceURI, localName: attributeGroupRef.localName)
            guard visitedGroupKeys.insert(groupKey).inserted else {
                throw XMLSchemaParsingError.other(message: "Cyclic attributeGroup reference detected for '\(attributeGroupRef.qualifiedName)'.")
            }
            defer { visitedGroupKeys.remove(groupKey) }

            guard let attributeGroup = resolver.attributeGroup(named: attributeGroupRef.localName, namespaceURI: groupNamespaceURI) else {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: attributeGroupRef.localName,
                    message: "attributeGroup reference '\(attributeGroupRef.qualifiedName)' could not be resolved."
                )
            }
            resolved.append(
                contentsOf: try resolveAttributeUses(
                    attributes: attributeGroup.attributes,
                    attributeRefs: attributeGroup.attributeRefs,
                    attributeGroupRefs: attributeGroup.attributeGroupRefs,
                    namespaceURI: groupNamespaceURI,
                    resolver: resolver,
                    contextPath: contextPath + ["attributeGroupRef", attributeGroup.name, "\(index)"],
                    visitedGroupKeys: &visitedGroupKeys
                )
            )
        }

        return resolved
    }

    private func resolveElementMetadata(
        for element: XMLSchemaElement,
        namespaceURI: String?,
        resolver: RawNormalizationResolver
    ) -> ResolvedElementMetadata {
        guard let refQName = element.refQName,
              let referencedElement = resolver.element(
                  named: refQName.localName,
                  namespaceURI: refQName.namespaceURI ?? namespaceURI
              ) else {
            return ResolvedElementMetadata(
                annotation: element.annotation,
                name: element.name,
                namespaceURI: namespaceURI,
                typeQName: element.typeQName,
                nillable: element.nillable,
                defaultValue: element.defaultValue,
                fixedValue: element.fixedValue,
                isAbstract: element.isAbstract,
                substitutionGroup: element.substitutionGroup
            )
        }

        return ResolvedElementMetadata(
            annotation: element.annotation ?? referencedElement.annotation,
            name: referencedElement.name,
            namespaceURI: refQName.namespaceURI ?? namespaceURI,
            typeQName: referencedElement.typeQName,
            nillable: referencedElement.nillable,
            defaultValue: referencedElement.defaultValue,
            fixedValue: referencedElement.fixedValue,
            isAbstract: referencedElement.isAbstract,
            substitutionGroup: referencedElement.substitutionGroup
        )
    }

    private func resolveComplexTypeDerivation(
        _ complexType: XMLSchemaComplexType,
        declaredContent: [XMLNormalizedContentNode],
        declaredAttributes: [XMLNormalizedAttributeUse],
        resolver: RawNormalizationResolver,
        contextPath: [String]
    ) throws -> ResolvedComplexTypeDerivation {
        var effectiveContent = declaredContent
        var effectiveAttributes = declaredAttributes
        var inheritedComplexTypeQName = complexType.baseQName
        var effectiveSimpleContentValueTypeQName: XMLQualifiedName?

        if let baseQName = complexType.baseQName {
            guard let baseComplexType = resolver.complexType(
                named: baseQName.localName,
                namespaceURI: baseQName.namespaceURI
            ) else {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: complexType.name,
                    message: "complexType '\(complexType.name)' extends unknown base type '\(baseQName.qualifiedName)'."
                )
            }
            let baseNormalized = try normalizeComplexType(
                baseComplexType,
                namespaceURI: baseQName.namespaceURI,
                resolver: resolver,
                contextPath: contextPath + ["base", baseQName.localName]
            )
            effectiveContent = mergeContent(
                baseContent: baseNormalized.effectiveContent,
                declaredContent: declaredContent,
                derivationKind: complexType.baseDerivationKind ?? .extension
            )
            effectiveAttributes = mergeAttributeUses(
                baseAttributes: baseNormalized.effectiveAttributes,
                declaredAttributes: declaredAttributes,
                derivationKind: complexType.baseDerivationKind ?? .extension
            )
            effectiveSimpleContentValueTypeQName = baseNormalized.effectiveSimpleContentValueTypeQName
        } else if let simpleContentBaseQName = complexType.simpleContentBaseQName {
            if let baseComplexType = resolver.complexType(
                named: simpleContentBaseQName.localName,
                namespaceURI: simpleContentBaseQName.namespaceURI
            ) {
                let baseNormalized = try normalizeComplexType(
                    baseComplexType,
                    namespaceURI: simpleContentBaseQName.namespaceURI,
                    resolver: resolver,
                    contextPath: contextPath + ["simpleContentBase", simpleContentBaseQName.localName]
                )
                inheritedComplexTypeQName = simpleContentBaseQName
                effectiveAttributes = mergeAttributeUses(
                    baseAttributes: baseNormalized.effectiveAttributes,
                    declaredAttributes: declaredAttributes,
                    derivationKind: complexType.simpleContentDerivationKind ?? .extension
                )
                effectiveSimpleContentValueTypeQName = baseNormalized.effectiveSimpleContentValueTypeQName
            } else {
                effectiveAttributes = mergeAttributeUses(
                    baseAttributes: [],
                    declaredAttributes: declaredAttributes,
                    derivationKind: complexType.simpleContentDerivationKind ?? .extension
                )
                effectiveSimpleContentValueTypeQName = simpleContentBaseQName
            }
        }

        return ResolvedComplexTypeDerivation(
            inheritedComplexTypeQName: inheritedComplexTypeQName,
            effectiveSimpleContentValueTypeQName: effectiveSimpleContentValueTypeQName,
            effectiveContent: effectiveContent,
            effectiveAttributes: effectiveAttributes
        )
    }

    private func mergeContent(
        baseContent: [XMLNormalizedContentNode],
        declaredContent: [XMLNormalizedContentNode],
        derivationKind: XMLSchemaContentDerivationKind
    ) -> [XMLNormalizedContentNode] {
        switch derivationKind {
        case .extension:
            return baseContent + declaredContent
        case .restriction:
            return declaredContent
        }
    }

    private func mergeAttributeUses(
        baseAttributes: [XMLNormalizedAttributeUse],
        declaredAttributes: [XMLNormalizedAttributeUse],
        derivationKind: XMLSchemaContentDerivationKind
    ) -> [XMLNormalizedAttributeUse] {
        var merged = baseAttributes

        for declaredAttribute in declaredAttributes {
            let key = makeLookupKey(
                namespaceURI: declaredAttribute.namespaceURI,
                localName: declaredAttribute.name
            )

            if let existingIndex = merged.firstIndex(where: {
                makeLookupKey(namespaceURI: $0.namespaceURI, localName: $0.name) == key
            }) {
                if derivationKind == .restriction && declaredAttribute.use == "prohibited" {
                    merged.remove(at: existingIndex)
                } else {
                    merged[existingIndex] = declaredAttribute
                }
                continue
            }

            if derivationKind == .restriction && declaredAttribute.use == "prohibited" {
                continue
            }

            merged.append(declaredAttribute)
        }

        return merged
    }

    private func applyOccurrence(
        _ groupBounds: XMLSchemaOccurrenceBounds,
        to contentNodes: [XMLNormalizedContentNode]
    ) -> [XMLNormalizedContentNode] {
        contentNodes.map { contentNode in
            switch contentNode {
            case let .element(element):
                return .element(
                    XMLNormalizedElementUse(
                        componentID: element.componentID,
                        annotation: element.annotation,
                        name: element.name,
                        namespaceURI: element.namespaceURI,
                        typeQName: element.typeQName,
                        nillable: element.nillable,
                        defaultValue: element.defaultValue,
                        fixedValue: element.fixedValue,
                        isAbstract: element.isAbstract,
                        substitutionGroup: element.substitutionGroup,
                        occurrenceBounds: multiplyOccurrence(groupBounds, element.occurrenceBounds)
                    )
                )
            case let .choice(choiceGroup):
                return .choice(
                    XMLNormalizedChoiceGroup(
                        content: choiceGroup.content,
                        occurrenceBounds: multiplyOccurrence(groupBounds, choiceGroup.occurrenceBounds)
                    )
                )
            case let .wildcard(wildcard):
                let bounds = multiplyOccurrence(groupBounds, wildcard.occurrenceBounds)
                return .wildcard(
                    XMLSchemaWildcard(
                        kind: wildcard.kind,
                        namespaceConstraint: wildcard.namespaceConstraint,
                        processContents: wildcard.processContents,
                        minOccurs: bounds.minOccurs,
                        maxOccurs: bounds.maxOccurs.map(String.init)
                    )
                )
            }
        }
    }

    private func multiplyOccurrence(
        _ lhs: XMLSchemaOccurrenceBounds,
        _ rhs: XMLSchemaOccurrenceBounds
    ) -> XMLSchemaOccurrenceBounds {
        let minOccurs = lhs.minOccurs * rhs.minOccurs
        let maxOccurs: Int?
        switch (lhs.maxOccurs, rhs.maxOccurs) {
        case let (.some(left), .some(right)):
            maxOccurs = left * right
        default:
            maxOccurs = nil
        }
        return XMLSchemaOccurrenceBounds(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }

    private func modelGroupNamespace(_ modelGroup: XMLSchemaModelGroup, fallback: String?) -> String? {
        fallback
    }

    private func makeComponentID(namespaceURI: String?, kind: String, path: [String]) -> XMLSchemaComponentID {
        XMLSchemaComponentID(rawValue: [namespaceURI ?? "", kind, path.joined(separator: "/")].joined(separator: "|"))
    }

    private func makeLookupKey(namespaceURI: String?, localName: String) -> String {
        "\(namespaceURI ?? ""):\(localName)"
    }
}
