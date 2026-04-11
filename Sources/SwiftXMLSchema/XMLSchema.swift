import Foundation
import SwiftXMLCoder

public struct XMLSchemaSet: Sendable, Equatable {
    public let schemas: [XMLSchema]

    public init(schemas: [XMLSchema]) {
        self.schemas = schemas
    }

    public func merging(_ other: XMLSchemaSet) -> XMLSchemaSet {
        XMLSchemaSet(schemas: schemas + other.schemas)
    }
}

public struct XMLSchemaOccurrenceBounds: Sendable, Equatable, Codable {
    public let minOccurs: Int
    public let maxOccurs: Int?

    public init(minOccurs: Int = 1, maxOccurs: Int? = 1) {
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
    }

    public static func from(minOccurs: Int?, maxOccurs: String?) -> XMLSchemaOccurrenceBounds {
        let resolvedMinOccurs = minOccurs ?? 1
        let resolvedMaxOccurs: Int?
        if let maxOccurs = maxOccurs {
            resolvedMaxOccurs = maxOccurs == "unbounded" ? nil : Int(maxOccurs)
        } else {
            resolvedMaxOccurs = 1
        }
        return XMLSchemaOccurrenceBounds(minOccurs: resolvedMinOccurs, maxOccurs: resolvedMaxOccurs)
    }
}

public struct XMLSchemaNotation: Sendable, Equatable, Codable {
    public let name: String
    public let publicID: String?
    public let systemID: String?

    public init(name: String, publicID: String? = nil, systemID: String? = nil) {
        self.name = name
        self.publicID = publicID
        self.systemID = systemID
    }
}

public enum XMLSchemaIdentityConstraintKind: String, Sendable, Equatable, Codable {
    case key
    case keyref
    case unique
}

public struct XMLSchemaIdentityConstraint: Sendable, Equatable, Codable {
    public let kind: XMLSchemaIdentityConstraintKind
    public let name: String
    public let selector: String
    public let fields: [String]
    public let refer: XMLQualifiedName?

    public init(
        kind: XMLSchemaIdentityConstraintKind,
        name: String,
        selector: String,
        fields: [String],
        refer: XMLQualifiedName? = nil
    ) {
        self.kind = kind
        self.name = name
        self.selector = selector
        self.fields = fields
        self.refer = refer
    }
}

public struct XMLSchemaRedefine: Sendable, Equatable {
    public let schemaLocation: String
    public let complexTypes: [XMLSchemaComplexType]
    public let simpleTypes: [XMLSchemaSimpleType]
    public let attributeGroups: [XMLSchemaAttributeGroup]
    public let modelGroups: [XMLSchemaModelGroup]

    public init(
        schemaLocation: String,
        complexTypes: [XMLSchemaComplexType] = [],
        simpleTypes: [XMLSchemaSimpleType] = [],
        attributeGroups: [XMLSchemaAttributeGroup] = [],
        modelGroups: [XMLSchemaModelGroup] = []
    ) {
        self.schemaLocation = schemaLocation
        self.complexTypes = complexTypes
        self.simpleTypes = simpleTypes
        self.attributeGroups = attributeGroups
        self.modelGroups = modelGroups
    }
}

public struct XMLSchemaAnnotation: Sendable, Equatable, Codable {
    public let documentation: [String]
    public let appinfo: [String]

    public init(documentation: [String] = [], appinfo: [String] = []) {
        self.documentation = documentation
        self.appinfo = appinfo
    }

    public var isEmpty: Bool {
        documentation.isEmpty && appinfo.isEmpty
    }
}

public enum XMLSchemaContentDerivationKind: String, Sendable, Equatable, Codable {
    case `extension`
    case restriction
}

public enum XMLSchemaSimpleTypeDerivationKind: String, Sendable, Equatable, Codable {
    case restriction
    case list
    case union
}

public enum XMLSchemaWildcardKind: String, Sendable, Equatable, Codable {
    case element
    case attribute
}

/// How an XML wildcard (`xsd:any` / `xsd:anyAttribute`) handles unrecognised content.
public enum XMLSchemaWildcardProcessContents: String, Sendable, Equatable, Codable {
    /// Validate against the schema if available; error if no schema is found. Default.
    case strict
    /// Validate against the schema if available; ignore if no schema is found.
    case lax
    /// Do not validate.
    case skip
}

/// How an attribute may appear on an element.
public enum XMLSchemaAttributeUseKind: String, Sendable, Equatable, Codable {
    /// The attribute must appear.
    case required
    /// The attribute may appear. Default when no `use` is specified.
    case optional
    /// The attribute must not appear (restriction only).
    case prohibited
}

public struct XMLSchemaWildcard: Sendable, Equatable, Codable {
    public let kind: XMLSchemaWildcardKind
    public let namespaceConstraint: String?
    public let processContents: XMLSchemaWildcardProcessContents?
    public let minOccurs: Int?
    public let maxOccurs: String?

    public init(
        kind: XMLSchemaWildcardKind,
        namespaceConstraint: String? = nil,
        processContents: XMLSchemaWildcardProcessContents? = nil,
        minOccurs: Int? = nil,
        maxOccurs: String? = nil
    ) {
        self.kind = kind
        self.namespaceConstraint = namespaceConstraint
        self.processContents = processContents
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
    }

    public var occurrenceBounds: XMLSchemaOccurrenceBounds {
        XMLSchemaOccurrenceBounds.from(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }
}

public struct XMLSchemaGroupReference: Sendable, Equatable, Codable {
    public let refQName: XMLQualifiedName
    public let minOccurs: Int?
    public let maxOccurs: String?

    public init(refQName: XMLQualifiedName, minOccurs: Int? = nil, maxOccurs: String? = nil) {
        self.refQName = refQName
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
    }

    public var occurrenceBounds: XMLSchemaOccurrenceBounds {
        XMLSchemaOccurrenceBounds.from(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }
}

public enum XMLSchemaContentNode: Sendable, Equatable {
    case element(XMLSchemaElement)
    case choice(XMLSchemaChoiceGroup)
    case groupReference(XMLSchemaGroupReference)
    case wildcard(XMLSchemaWildcard)
}

public struct XMLSchemaAnonymousSimpleType: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let baseQName: XMLQualifiedName?
    public let enumerationValues: [String]
    public let pattern: String?
    public let facets: XMLSchemaFacetSet?
    public let derivationKind: XMLSchemaSimpleTypeDerivationKind
    public let listItemQName: XMLQualifiedName?
    public let unionMemberQNames: [XMLQualifiedName]
    public let unionInlineSimpleTypes: [XMLSchemaAnonymousSimpleType]

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        baseQName: XMLQualifiedName?,
        enumerationValues: [String],
        pattern: String?,
        facets: XMLSchemaFacetSet? = nil,
        derivationKind: XMLSchemaSimpleTypeDerivationKind = .restriction,
        listItemQName: XMLQualifiedName? = nil,
        unionMemberQNames: [XMLQualifiedName] = [],
        unionInlineSimpleTypes: [XMLSchemaAnonymousSimpleType] = []
    ) {
        self.annotation = annotation
        self.baseQName = baseQName
        self.enumerationValues = enumerationValues
        self.pattern = pattern
        self.facets = facets
        self.derivationKind = derivationKind
        self.listItemQName = listItemQName
        self.unionMemberQNames = unionMemberQNames
        self.unionInlineSimpleTypes = unionInlineSimpleTypes
    }
}

public struct XMLSchemaAnonymousComplexType: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let baseQName: XMLQualifiedName?
    public let baseDerivationKind: XMLSchemaContentDerivationKind?
    public let simpleContentBaseQName: XMLQualifiedName?
    public let simpleContentDerivationKind: XMLSchemaContentDerivationKind?
    public let isAbstract: Bool
    public let isMixed: Bool
    public let content: [XMLSchemaContentNode]
    public let attributes: [XMLSchemaAttribute]
    public let attributeRefs: [XMLSchemaAttributeReference]
    public let attributeGroupRefs: [XMLQualifiedName]
    public let anyAttribute: XMLSchemaWildcard?

    public var sequence: [XMLSchemaElement] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var choiceGroups: [XMLSchemaChoiceGroup] {
        content.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var groupReferences: [XMLSchemaGroupReference] {
        content.compactMap { node in
            guard case let .groupReference(reference) = node else { return nil }
            return reference
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        baseQName: XMLQualifiedName? = nil,
        baseDerivationKind: XMLSchemaContentDerivationKind? = nil,
        simpleContentBaseQName: XMLQualifiedName? = nil,
        simpleContentDerivationKind: XMLSchemaContentDerivationKind? = nil,
        isAbstract: Bool = false,
        isMixed: Bool = false,
        sequence: [XMLSchemaElement] = [],
        choiceGroups: [XMLSchemaChoiceGroup] = [],
        groupReferences: [XMLSchemaGroupReference] = [],
        anyElements: [XMLSchemaWildcard] = [],
        content: [XMLSchemaContentNode]? = nil,
        attributes: [XMLSchemaAttribute],
        attributeRefs: [XMLSchemaAttributeReference] = [],
        attributeGroupRefs: [XMLQualifiedName] = [],
        anyAttribute: XMLSchemaWildcard? = nil
    ) {
        self.annotation = annotation
        self.baseQName = baseQName
        self.baseDerivationKind = baseDerivationKind
        self.simpleContentBaseQName = simpleContentBaseQName
        self.simpleContentDerivationKind = simpleContentDerivationKind
        self.isAbstract = isAbstract
        self.isMixed = isMixed
        self.content = content ?? XMLSchemaAnonymousComplexType.makeContent(
            sequence: sequence,
            choiceGroups: choiceGroups,
            groupReferences: groupReferences,
            anyElements: anyElements
        )
        self.attributes = attributes
        self.attributeRefs = attributeRefs
        self.attributeGroupRefs = attributeGroupRefs
        self.anyAttribute = anyAttribute
    }

    private static func makeContent(
        sequence: [XMLSchemaElement],
        choiceGroups: [XMLSchemaChoiceGroup],
        groupReferences: [XMLSchemaGroupReference],
        anyElements: [XMLSchemaWildcard]
    ) -> [XMLSchemaContentNode] {
        sequence.map(XMLSchemaContentNode.element) +
            choiceGroups.map(XMLSchemaContentNode.choice) +
            groupReferences.map(XMLSchemaContentNode.groupReference) +
            anyElements.map(XMLSchemaContentNode.wildcard)
    }
}

public struct XMLSchema: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let targetNamespace: String?
    public let imports: [XMLSchemaImport]
    public let includes: [XMLSchemaInclude]
    public let redefines: [XMLSchemaRedefine]
    public let notations: [XMLSchemaNotation]
    public let elements: [XMLSchemaElement]
    public let attributeDefinitions: [XMLSchemaAttribute]
    public let attributeGroups: [XMLSchemaAttributeGroup]
    public let modelGroups: [XMLSchemaModelGroup]
    public let complexTypes: [XMLSchemaComplexType]
    public let simpleTypes: [XMLSchemaSimpleType]

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        targetNamespace: String?,
        imports: [XMLSchemaImport],
        includes: [XMLSchemaInclude],
        redefines: [XMLSchemaRedefine] = [],
        notations: [XMLSchemaNotation] = [],
        elements: [XMLSchemaElement],
        attributeDefinitions: [XMLSchemaAttribute] = [],
        attributeGroups: [XMLSchemaAttributeGroup] = [],
        modelGroups: [XMLSchemaModelGroup] = [],
        complexTypes: [XMLSchemaComplexType],
        simpleTypes: [XMLSchemaSimpleType]
    ) {
        self.annotation = annotation
        self.targetNamespace = targetNamespace
        self.imports = imports
        self.includes = includes
        self.redefines = redefines
        self.notations = notations
        self.elements = elements
        self.attributeDefinitions = attributeDefinitions
        self.attributeGroups = attributeGroups
        self.modelGroups = modelGroups
        self.complexTypes = complexTypes
        self.simpleTypes = simpleTypes
    }
}

public struct XMLSchemaImport: Sendable, Equatable {
    public let namespace: String?
    public let schemaLocation: String?

    public init(namespace: String?, schemaLocation: String?) {
        self.namespace = namespace
        self.schemaLocation = schemaLocation
    }
}

public struct XMLSchemaInclude: Sendable, Equatable {
    public let schemaLocation: String

    public init(schemaLocation: String) {
        self.schemaLocation = schemaLocation
    }
}

public struct XMLSchemaElement: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let typeQName: XMLQualifiedName?
    public let refQName: XMLQualifiedName?
    public let minOccurs: Int?
    public let maxOccurs: String?
    public let nillable: Bool
    public let defaultValue: String?
    public let fixedValue: String?
    public let isAbstract: Bool
    public let substitutionGroup: XMLQualifiedName?
    public let identityConstraints: [XMLSchemaIdentityConstraint]
    public let inlineComplexType: XMLSchemaAnonymousComplexType?
    public let inlineSimpleType: XMLSchemaAnonymousSimpleType?

    public var inlineSequenceElements: [XMLSchemaElement] {
        inlineComplexType?.sequence ?? []
    }

    public var occurrenceBounds: XMLSchemaOccurrenceBounds {
        XMLSchemaOccurrenceBounds.from(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        name: String,
        typeQName: XMLQualifiedName?,
        refQName: XMLQualifiedName?,
        minOccurs: Int?,
        maxOccurs: String?,
        nillable: Bool,
        defaultValue: String? = nil,
        fixedValue: String? = nil,
        isAbstract: Bool = false,
        substitutionGroup: XMLQualifiedName? = nil,
        identityConstraints: [XMLSchemaIdentityConstraint] = [],
        inlineSequenceElements: [XMLSchemaElement] = [],
        inlineComplexType: XMLSchemaAnonymousComplexType? = nil,
        inlineSimpleType: XMLSchemaAnonymousSimpleType? = nil
    ) {
        self.annotation = annotation
        self.name = name
        self.typeQName = typeQName
        self.refQName = refQName
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
        self.nillable = nillable
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
        self.isAbstract = isAbstract
        self.substitutionGroup = substitutionGroup
        self.identityConstraints = identityConstraints
        if let inlineComplexType = inlineComplexType {
            self.inlineComplexType = inlineComplexType
        } else if !inlineSequenceElements.isEmpty {
            self.inlineComplexType = XMLSchemaAnonymousComplexType(
                sequence: inlineSequenceElements,
                attributes: []
            )
        } else {
            self.inlineComplexType = nil
        }
        self.inlineSimpleType = inlineSimpleType
    }
}

public struct XMLSchemaComplexType: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let baseQName: XMLQualifiedName?
    public let baseDerivationKind: XMLSchemaContentDerivationKind?
    public let simpleContentBaseQName: XMLQualifiedName?
    public let simpleContentDerivationKind: XMLSchemaContentDerivationKind?
    public let isAbstract: Bool
    public let isMixed: Bool
    public let content: [XMLSchemaContentNode]
    public let attributes: [XMLSchemaAttribute]
    public let attributeRefs: [XMLSchemaAttributeReference]
    public let attributeGroupRefs: [XMLQualifiedName]
    public let anyAttribute: XMLSchemaWildcard?

    public var sequence: [XMLSchemaElement] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var choiceGroups: [XMLSchemaChoiceGroup] {
        content.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var groupReferences: [XMLSchemaGroupReference] {
        content.compactMap { node in
            guard case let .groupReference(reference) = node else { return nil }
            return reference
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public var choice: [XMLSchemaElement] {
        choiceGroups.flatMap(\.elements)
    }

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        name: String,
        baseQName: XMLQualifiedName? = nil,
        baseDerivationKind: XMLSchemaContentDerivationKind? = nil,
        simpleContentBaseQName: XMLQualifiedName? = nil,
        simpleContentDerivationKind: XMLSchemaContentDerivationKind? = nil,
        isAbstract: Bool = false,
        isMixed: Bool = false,
        sequence: [XMLSchemaElement],
        choice: [XMLSchemaElement] = [],
        choiceGroups: [XMLSchemaChoiceGroup]? = nil,
        groupReferences: [XMLSchemaGroupReference] = [],
        anyElements: [XMLSchemaWildcard] = [],
        content: [XMLSchemaContentNode]? = nil,
        attributes: [XMLSchemaAttribute],
        attributeRefs: [XMLSchemaAttributeReference] = [],
        attributeGroupRefs: [XMLQualifiedName] = [],
        anyAttribute: XMLSchemaWildcard? = nil
    ) {
        self.annotation = annotation
        self.name = name
        self.baseQName = baseQName
        self.baseDerivationKind = baseDerivationKind
        self.simpleContentBaseQName = simpleContentBaseQName
        self.simpleContentDerivationKind = simpleContentDerivationKind
        self.isAbstract = isAbstract
        self.isMixed = isMixed
        let resolvedChoiceGroups = choiceGroups ?? (choice.isEmpty ? [] : [XMLSchemaChoiceGroup(elements: choice)])
        self.content = content ?? XMLSchemaComplexType.makeContent(
            sequence: sequence,
            choiceGroups: resolvedChoiceGroups,
            groupReferences: groupReferences,
            anyElements: anyElements
        )
        self.attributes = attributes
        self.attributeRefs = attributeRefs
        self.attributeGroupRefs = attributeGroupRefs
        self.anyAttribute = anyAttribute
    }

    private static func makeContent(
        sequence: [XMLSchemaElement],
        choiceGroups: [XMLSchemaChoiceGroup],
        groupReferences: [XMLSchemaGroupReference],
        anyElements: [XMLSchemaWildcard]
    ) -> [XMLSchemaContentNode] {
        sequence.map(XMLSchemaContentNode.element) +
            choiceGroups.map(XMLSchemaContentNode.choice) +
            groupReferences.map(XMLSchemaContentNode.groupReference) +
            anyElements.map(XMLSchemaContentNode.wildcard)
    }
}

public struct XMLSchemaChoiceGroup: Sendable, Equatable {
    public let content: [XMLSchemaContentNode]
    public let minOccurs: Int?
    public let maxOccurs: String?

    public var elements: [XMLSchemaElement] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var groupReferences: [XMLSchemaGroupReference] {
        content.compactMap { node in
            guard case let .groupReference(reference) = node else { return nil }
            return reference
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public var occurrenceBounds: XMLSchemaOccurrenceBounds {
        XMLSchemaOccurrenceBounds.from(minOccurs: minOccurs, maxOccurs: maxOccurs)
    }

    public init(
        elements: [XMLSchemaElement],
        minOccurs: Int? = nil,
        maxOccurs: String? = nil,
        groupReferences: [XMLSchemaGroupReference] = [],
        anyElements: [XMLSchemaWildcard] = [],
        content: [XMLSchemaContentNode]? = nil
    ) {
        self.content = content ?? XMLSchemaChoiceGroup.makeContent(
            elements: elements,
            groupReferences: groupReferences,
            anyElements: anyElements
        )
        self.minOccurs = minOccurs
        self.maxOccurs = maxOccurs
    }

    private static func makeContent(
        elements: [XMLSchemaElement],
        groupReferences: [XMLSchemaGroupReference],
        anyElements: [XMLSchemaWildcard]
    ) -> [XMLSchemaContentNode] {
        elements.map(XMLSchemaContentNode.element) +
            groupReferences.map(XMLSchemaContentNode.groupReference) +
            anyElements.map(XMLSchemaContentNode.wildcard)
    }
}

public struct XMLSchemaModelGroup: Sendable, Equatable {
    public let name: String
    public let content: [XMLSchemaContentNode]

    public var sequence: [XMLSchemaElement] {
        content.compactMap { node in
            guard case let .element(element) = node else { return nil }
            return element
        }
    }

    public var choiceGroups: [XMLSchemaChoiceGroup] {
        content.compactMap { node in
            guard case let .choice(choiceGroup) = node else { return nil }
            return choiceGroup
        }
    }

    public var groupReferences: [XMLSchemaGroupReference] {
        content.compactMap { node in
            guard case let .groupReference(reference) = node else { return nil }
            return reference
        }
    }

    public var anyElements: [XMLSchemaWildcard] {
        content.compactMap { node in
            guard case let .wildcard(wildcard) = node else { return nil }
            return wildcard
        }
    }

    public init(
        name: String,
        sequence: [XMLSchemaElement] = [],
        choiceGroups: [XMLSchemaChoiceGroup] = [],
        groupReferences: [XMLSchemaGroupReference] = [],
        anyElements: [XMLSchemaWildcard] = [],
        content: [XMLSchemaContentNode]? = nil
    ) {
        self.name = name
        self.content = content ?? sequence.map(XMLSchemaContentNode.element) +
            choiceGroups.map(XMLSchemaContentNode.choice) +
            groupReferences.map(XMLSchemaContentNode.groupReference) +
            anyElements.map(XMLSchemaContentNode.wildcard)
    }
}

public struct XMLSchemaFacetSet: Sendable, Equatable, Codable {
    public let enumeration: [String]
    public let pattern: String?
    public let minLength: Int?
    public let maxLength: Int?
    public let length: Int?
    public let minInclusive: String?
    public let maxInclusive: String?
    public let minExclusive: String?
    public let maxExclusive: String?
    public let totalDigits: Int?
    public let fractionDigits: Int?

    public init(
        enumeration: [String] = [],
        pattern: String? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        length: Int? = nil,
        minInclusive: String? = nil,
        maxInclusive: String? = nil,
        minExclusive: String? = nil,
        maxExclusive: String? = nil,
        totalDigits: Int? = nil,
        fractionDigits: Int? = nil
    ) {
        self.enumeration = enumeration
        self.pattern = pattern
        self.minLength = minLength
        self.maxLength = maxLength
        self.length = length
        self.minInclusive = minInclusive
        self.maxInclusive = maxInclusive
        self.minExclusive = minExclusive
        self.maxExclusive = maxExclusive
        self.totalDigits = totalDigits
        self.fractionDigits = fractionDigits
    }

    public var isEmpty: Bool {
        enumeration.isEmpty && pattern == nil && minLength == nil &&
            maxLength == nil && length == nil && minInclusive == nil &&
            maxInclusive == nil && minExclusive == nil && maxExclusive == nil &&
            totalDigits == nil && fractionDigits == nil
    }
}

public struct XMLSchemaSimpleType: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let baseQName: XMLQualifiedName?
    public let enumerationValues: [String]
    public let pattern: String?
    public let facets: XMLSchemaFacetSet?
    public let derivationKind: XMLSchemaSimpleTypeDerivationKind
    public let listItemQName: XMLQualifiedName?
    public let unionMemberQNames: [XMLQualifiedName]
    public let unionInlineSimpleTypes: [XMLSchemaAnonymousSimpleType]

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        name: String,
        baseQName: XMLQualifiedName?,
        enumerationValues: [String],
        pattern: String?,
        facets: XMLSchemaFacetSet? = nil,
        derivationKind: XMLSchemaSimpleTypeDerivationKind = .restriction,
        listItemQName: XMLQualifiedName? = nil,
        unionMemberQNames: [XMLQualifiedName] = [],
        unionInlineSimpleTypes: [XMLSchemaAnonymousSimpleType] = []
    ) {
        self.annotation = annotation
        self.name = name
        self.baseQName = baseQName
        self.enumerationValues = enumerationValues
        self.pattern = pattern
        self.facets = facets
        self.derivationKind = derivationKind
        self.listItemQName = listItemQName
        self.unionMemberQNames = unionMemberQNames
        self.unionInlineSimpleTypes = unionInlineSimpleTypes
    }
}

public struct XMLSchemaAttribute: Sendable, Equatable {
    public let annotation: XMLSchemaAnnotation?
    public let name: String
    public let typeQName: XMLQualifiedName?
    public let use: XMLSchemaAttributeUseKind?
    public let defaultValue: String?
    public let fixedValue: String?
    public let inlineSimpleType: XMLSchemaAnonymousSimpleType?

    public init(
        annotation: XMLSchemaAnnotation? = nil,
        name: String,
        typeQName: XMLQualifiedName?,
        use: XMLSchemaAttributeUseKind?,
        defaultValue: String? = nil,
        fixedValue: String? = nil,
        inlineSimpleType: XMLSchemaAnonymousSimpleType? = nil
    ) {
        self.annotation = annotation
        self.name = name
        self.typeQName = typeQName
        self.use = use
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
        self.inlineSimpleType = inlineSimpleType
    }
}

public struct XMLSchemaAttributeReference: Sendable, Equatable {
    public let refQName: XMLQualifiedName
    public let use: XMLSchemaAttributeUseKind?
    public let defaultValue: String?
    public let fixedValue: String?
    public let annotation: XMLSchemaAnnotation?

    public init(
        refQName: XMLQualifiedName,
        use: XMLSchemaAttributeUseKind? = nil,
        defaultValue: String? = nil,
        fixedValue: String? = nil,
        annotation: XMLSchemaAnnotation? = nil
    ) {
        self.refQName = refQName
        self.use = use
        self.defaultValue = defaultValue
        self.fixedValue = fixedValue
        self.annotation = annotation
    }
}

public struct XMLSchemaAttributeGroup: Sendable, Equatable {
    public let name: String
    public let attributes: [XMLSchemaAttribute]
    public let attributeRefs: [XMLSchemaAttributeReference]
    public let attributeGroupRefs: [XMLQualifiedName]

    public init(
        name: String,
        attributes: [XMLSchemaAttribute],
        attributeRefs: [XMLSchemaAttributeReference] = [],
        attributeGroupRefs: [XMLQualifiedName] = []
    ) {
        self.name = name
        self.attributes = attributes
        self.attributeRefs = attributeRefs
        self.attributeGroupRefs = attributeGroupRefs
    }
}
