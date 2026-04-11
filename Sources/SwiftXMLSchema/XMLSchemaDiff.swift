import Foundation
import SwiftXMLCoder

// MARK: - Field-level change

/// A single field-level change within a modified schema component.
public struct XMLSchemaFieldChange: Sendable, Equatable {
    /// How the field changed.
    public enum Kind: Sendable, Equatable {
        // swiftlint:disable identifier_name
        /// A scalar value was replaced.
        case valueChanged(from: String, to: String)
        // swiftlint:enable identifier_name
        /// A new item (element, attribute, enum value) was added to a collection.
        case itemAdded(String)
        /// An existing item was removed from a collection.
        case itemRemoved(String)
    }

    /// Dot-path naming the field, e.g. `"content.id.type"` or `"attribute.currency.use"`.
    public let fieldName: String
    /// What changed.
    public let kind: Kind
    /// Whether this change is considered a breaking change for downstream consumers.
    public let isBreaking: Bool
}

// MARK: - Component-level change envelope

/// How a top-level schema component changed between two schema set versions.
public enum XMLSchemaComponentChange<T: Sendable & Equatable>: Sendable, Equatable {
    /// The component exists only in the new schema set.
    case added(T)
    /// The component existed only in the old schema set.
    case removed(T)
    /// The component exists in both but has structural differences.
    case modified(old: T, new: T, fieldChanges: [XMLSchemaFieldChange])

    /// `true` when this change is likely to break existing consumers of the schema.
    ///
    /// Removal is always breaking. For modifications, breaking is determined by the
    /// individual field changes.
    public var isBreaking: Bool {
        switch self {
        case .removed: return true
        case .added: return false
        case .modified(_, _, let changes): return changes.contains { $0.isBreaking }
        }
    }
}

// MARK: - Per-component diff entries

/// Diff entry for a single named complex type.
public struct XMLSchemaComplexTypeDiff: Sendable, Equatable {
    public let name: String
    public let namespaceURI: String?
    public let change: XMLSchemaComponentChange<XMLNormalizedComplexType>

    public var isBreaking: Bool { change.isBreaking }
}

/// Diff entry for a single named simple type.
public struct XMLSchemaSimpleTypeDiff: Sendable, Equatable {
    public let name: String
    public let namespaceURI: String?
    public let change: XMLSchemaComponentChange<XMLNormalizedSimpleType>

    public var isBreaking: Bool { change.isBreaking }
}

/// Diff entry for a single top-level element declaration.
public struct XMLSchemaElementDiff: Sendable, Equatable {
    public let name: String
    public let namespaceURI: String?
    public let change: XMLSchemaComponentChange<XMLNormalizedElementDeclaration>

    public var isBreaking: Bool { change.isBreaking }
}

// MARK: - XMLSchemaDiff

/// The complete structural difference between two ``XMLNormalizedSchemaSet`` versions.
///
/// Produced by ``XMLSchemaDiffer/diff(old:new:)``. All changes are expressed as
/// typed, navigable values — not as text patches.
///
/// ```swift
/// let diff = XMLSchemaDiffer().diff(old: v1, new: v2)
///
/// if diff.hasBreakingChanges {
///     for entry in diff.complexTypeChanges where entry.isBreaking {
///         // handle breaking change in entry.name
///     }
/// }
/// ```
///
/// ### Breaking change rules
///
/// | Change | Breaking |
/// |---|---|
/// | Component removed | Yes |
/// | Required content element added | Yes |
/// | Content element removed | Yes |
/// | Content element type changed | Yes |
/// | `minOccurs` increased | Yes |
/// | `maxOccurs` decreased | Yes |
/// | Required attribute added | Yes |
/// | Attribute removed | Yes |
/// | Attribute type changed | Yes |
/// | Attribute `use` changed | Yes |
/// | Base type changed | Yes |
/// | `isMixed` changed | Yes |
/// | `isAbstract` false → true | Yes |
/// | Simple type base changed | Yes |
/// | Enumeration value removed | Yes |
/// | Optional content element added | No |
/// | Optional attribute added | No |
/// | Enumeration value added | No |
/// | Component added | No |
public struct XMLSchemaDiff: Sendable, Equatable {
    /// All complex type additions, removals, and modifications.
    public let complexTypeChanges: [XMLSchemaComplexTypeDiff]
    /// All simple type additions, removals, and modifications.
    public let simpleTypeChanges: [XMLSchemaSimpleTypeDiff]
    /// All top-level element additions, removals, and modifications.
    public let elementChanges: [XMLSchemaElementDiff]

    /// `true` when no changes were detected.
    public var isEmpty: Bool {
        complexTypeChanges.isEmpty && simpleTypeChanges.isEmpty && elementChanges.isEmpty
    }

    /// `true` when at least one change is classified as breaking.
    public var hasBreakingChanges: Bool {
        complexTypeChanges.contains { $0.isBreaking }
            || simpleTypeChanges.contains { $0.isBreaking }
            || elementChanges.contains { $0.isBreaking }
    }

    /// All complex type entries that contain at least one breaking change.
    public var breakingComplexTypeChanges: [XMLSchemaComplexTypeDiff] {
        complexTypeChanges.filter(\.isBreaking)
    }

    /// All simple type entries that contain at least one breaking change.
    public var breakingSimpleTypeChanges: [XMLSchemaSimpleTypeDiff] {
        simpleTypeChanges.filter(\.isBreaking)
    }

    /// All element entries that contain at least one breaking change.
    public var breakingElementChanges: [XMLSchemaElementDiff] {
        elementChanges.filter(\.isBreaking)
    }
}

// MARK: - XMLSchemaDiffer

// swiftlint:disable type_body_length
/// Computes the structural difference between two ``XMLNormalizedSchemaSet`` values.
///
/// Identifies added, removed, and modified complex types, simple types, and
/// top-level element declarations. For modifications, enumerates field-level
/// changes with breaking-change classification.
///
/// Matching between old and new is done by `(localName, namespaceURI)`.
/// Anonymous types (synthesised from inline `<xsd:complexType>` children) are excluded.
public struct XMLSchemaDiffer: Sendable {

    public init() {}

    /// Computes the diff from `old` to `new`.
    ///
    /// - Parameters:
    ///   - old: The baseline schema set.
    ///   - new: The updated schema set.
    /// - Returns: A ``XMLSchemaDiff`` describing all structural changes.
    public func diff(old: XMLNormalizedSchemaSet, new: XMLNormalizedSchemaSet) -> XMLSchemaDiff {
        XMLSchemaDiff(
            complexTypeChanges: diffComponents(
                old: old.allComplexTypes.filter { !$0.isAnonymous },
                new: new.allComplexTypes.filter { !$0.isAnonymous },
                key: { ($0.name, $0.namespaceURI) },
                lookup: { new.complexType(named: $0, namespaceURI: $1) },
                oldLookup: { old.complexType(named: $0, namespaceURI: $1) },
                makeEntry: { name, namespaceURI, change in
                    XMLSchemaComplexTypeDiff(name: name, namespaceURI: namespaceURI, change: change)
                },
                computeFieldChanges: diffComplexType
            ),
            simpleTypeChanges: diffComponents(
                old: old.allSimpleTypes,
                new: new.allSimpleTypes,
                key: { ($0.name, $0.namespaceURI) },
                lookup: { new.simpleType(named: $0, namespaceURI: $1) },
                oldLookup: { old.simpleType(named: $0, namespaceURI: $1) },
                makeEntry: { name, namespaceURI, change in
                    XMLSchemaSimpleTypeDiff(name: name, namespaceURI: namespaceURI, change: change)
                },
                computeFieldChanges: diffSimpleType
            ),
            elementChanges: diffComponents(
                old: old.allElements,
                new: new.allElements,
                key: { ($0.name, $0.namespaceURI) },
                lookup: { new.element(named: $0, namespaceURI: $1) },
                oldLookup: { old.element(named: $0, namespaceURI: $1) },
                makeEntry: { name, namespaceURI, change in
                    XMLSchemaElementDiff(name: name, namespaceURI: namespaceURI, change: change)
                },
                computeFieldChanges: diffElement
            )
        )
    }

    // MARK: - Generic component diffing

    // swiftlint:disable:next function_parameter_count
    private func diffComponents<T: Sendable & Equatable, Entry: Sendable>(
        old oldComponents: [T],
        new newComponents: [T],
        key: (T) -> (String, String?),
        lookup: (String, String?) -> T?,
        oldLookup: (String, String?) -> T?,
        makeEntry: (String, String?, XMLSchemaComponentChange<T>) -> Entry,
        computeFieldChanges: (T, T) -> [XMLSchemaFieldChange]
    ) -> [Entry] {
        var entries: [Entry] = []

        for oldComponent in oldComponents {
            let (name, namespaceURI) = key(oldComponent)
            if let newComponent = lookup(name, namespaceURI) {
                if oldComponent != newComponent {
                    let fieldChanges = computeFieldChanges(oldComponent, newComponent)
                    if !fieldChanges.isEmpty {
                        let change = XMLSchemaComponentChange<T>.modified(
                            old: oldComponent, new: newComponent, fieldChanges: fieldChanges
                        )
                        entries.append(makeEntry(name, namespaceURI, change))
                    }
                }
            } else {
                entries.append(makeEntry(name, namespaceURI, .removed(oldComponent)))
            }
        }

        for newComponent in newComponents {
            let (name, namespaceURI) = key(newComponent)
            if oldLookup(name, namespaceURI) == nil {
                entries.append(makeEntry(name, namespaceURI, .added(newComponent)))
            }
        }

        return entries
    }

    // MARK: - Complex type field diff

        // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func diffComplexType(
        old: XMLNormalizedComplexType,
        new: XMLNormalizedComplexType
    ) -> [XMLSchemaFieldChange] {
        var changes: [XMLSchemaFieldChange] = []

        // Scalar flags
        if old.isAbstract != new.isAbstract {
            changes.append(.init(
                fieldName: "isAbstract",
                kind: .valueChanged(from: "\(old.isAbstract)", to: "\(new.isAbstract)"),
                isBreaking: !old.isAbstract && new.isAbstract // false→true = breaking
            ))
        }

        if old.isMixed != new.isMixed {
            changes.append(.init(
                fieldName: "isMixed",
                kind: .valueChanged(from: "\(old.isMixed)", to: "\(new.isMixed)"),
                isBreaking: true
            ))
        }

        // Base type
        if old.inheritedComplexTypeQName != new.inheritedComplexTypeQName {
            changes.append(.init(
                fieldName: "baseType",
                kind: .valueChanged(
                    from: old.inheritedComplexTypeQName?.qualifiedName ?? "none",
                    to: new.inheritedComplexTypeQName?.qualifiedName ?? "none"
                ),
                isBreaking: true
            ))
        }

        if old.baseDerivationKind != new.baseDerivationKind {
            changes.append(.init(
                fieldName: "baseDerivationKind",
                kind: .valueChanged(
                    from: old.baseDerivationKind?.rawValue ?? "none",
                    to: new.baseDerivationKind?.rawValue ?? "none"
                ),
                isBreaking: true
            ))
        }

        // Content elements (by name within effective sequence)
        let oldSeq = Dictionary(
            old.effectiveSequence.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let newSeq = Dictionary(
            new.effectiveSequence.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for (name, oldEl) in oldSeq {
            if let newEl = newSeq[name] {
                if oldEl.typeQName != newEl.typeQName {
                    changes.append(.init(
                        fieldName: "content.\(name).type",
                        kind: .valueChanged(
                            from: oldEl.typeQName?.qualifiedName ?? "none",
                            to: newEl.typeQName?.qualifiedName ?? "none"
                        ),
                        isBreaking: true
                    ))
                }
                if newEl.occurrenceBounds.minOccurs > oldEl.occurrenceBounds.minOccurs {
                    changes.append(.init(
                        fieldName: "content.\(name).minOccurs",
                        kind: .valueChanged(
                            from: "\(oldEl.occurrenceBounds.minOccurs)",
                            to: "\(newEl.occurrenceBounds.minOccurs)"
                        ),
                        isBreaking: true
                    ))
                }
                let oldMax = oldEl.occurrenceBounds.maxOccurs.map(String.init) ?? "unbounded"
                let newMax = newEl.occurrenceBounds.maxOccurs.map(String.init) ?? "unbounded"
                if oldMax != newMax {
                    let isBreaking: Bool
                    switch (oldEl.occurrenceBounds.maxOccurs, newEl.occurrenceBounds.maxOccurs) {
                    case (nil, .some):
                        isBreaking = true  // unbounded → bounded
                    case (.some(let oldBound), .some(let newBound)):
                        isBreaking = newBound < oldBound  // reduced
                    default:
                        isBreaking = false
                    }
                    changes.append(.init(
                        fieldName: "content.\(name).maxOccurs",
                        kind: .valueChanged(from: oldMax, to: newMax),
                        isBreaking: isBreaking
                    ))
                }
            } else {
                changes.append(.init(fieldName: "content", kind: .itemRemoved(name), isBreaking: true))
            }
        }

        for (name, newEl) in newSeq where oldSeq[name] == nil {
            let isRequired = newEl.occurrenceBounds.minOccurs > 0 && newEl.defaultValue == nil
            changes.append(.init(fieldName: "content", kind: .itemAdded(name), isBreaking: isRequired))
        }

        // Attributes
        let oldAttrs = Dictionary(
            old.effectiveAttributes.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let newAttrs = Dictionary(
            new.effectiveAttributes.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for (name, oldAttr) in oldAttrs {
            if let newAttr = newAttrs[name] {
                if oldAttr.typeQName != newAttr.typeQName {
                    changes.append(.init(
                        fieldName: "attribute.\(name).type",
                        kind: .valueChanged(
                            from: oldAttr.typeQName?.qualifiedName ?? "none",
                            to: newAttr.typeQName?.qualifiedName ?? "none"
                        ),
                        isBreaking: true
                    ))
                }
                if oldAttr.use != newAttr.use {
                    changes.append(.init(
                        fieldName: "attribute.\(name).use",
                        kind: .valueChanged(
                            from: oldAttr.use?.rawValue ?? "none",
                            to: newAttr.use?.rawValue ?? "none"
                        ),
                        isBreaking: true
                    ))
                }
            } else {
                changes.append(.init(fieldName: "attribute", kind: .itemRemoved(name), isBreaking: true))
            }
        }

        for (name, newAttr) in newAttrs where oldAttrs[name] == nil {
            let isBreaking = newAttr.use == .required && newAttr.defaultValue == nil
            changes.append(.init(fieldName: "attribute", kind: .itemAdded(name), isBreaking: isBreaking))
        }

        return changes
    }

    // MARK: - Simple type field diff

    // swiftlint:disable:next function_body_length
    private func diffSimpleType(
        old: XMLNormalizedSimpleType,
        new: XMLNormalizedSimpleType
    ) -> [XMLSchemaFieldChange] {
        var changes: [XMLSchemaFieldChange] = []

        if old.derivationKind != new.derivationKind {
            changes.append(.init(
                fieldName: "derivationKind",
                kind: .valueChanged(from: old.derivationKind.rawValue, to: new.derivationKind.rawValue),
                isBreaking: true
            ))
        }

        if old.baseQName != new.baseQName {
            changes.append(.init(
                fieldName: "baseType",
                kind: .valueChanged(
                    from: old.baseQName?.qualifiedName ?? "none",
                    to: new.baseQName?.qualifiedName ?? "none"
                ),
                isBreaking: true
            ))
        }

        if old.listItemQName != new.listItemQName {
            changes.append(.init(
                fieldName: "listItemType",
                kind: .valueChanged(
                    from: old.listItemQName?.qualifiedName ?? "none",
                    to: new.listItemQName?.qualifiedName ?? "none"
                ),
                isBreaking: true
            ))
        }

        // Enumeration values
        let oldEnums = Set(old.enumerationValues)
        let newEnums = Set(new.enumerationValues)
        for removed in oldEnums.subtracting(newEnums).sorted() {
            changes.append(.init(fieldName: "enumeration", kind: .itemRemoved(removed), isBreaking: true))
        }
        for added in newEnums.subtracting(oldEnums).sorted() {
            changes.append(.init(fieldName: "enumeration", kind: .itemAdded(added), isBreaking: false))
        }

        // Pattern
        if old.pattern != new.pattern {
            changes.append(.init(
                fieldName: "pattern",
                kind: .valueChanged(from: old.pattern ?? "none", to: new.pattern ?? "none"),
                isBreaking: new.pattern != nil // adding/tightening a pattern = breaking
            ))
        }

        // Facets — compare only the non-enumeration facets; enumeration diffs are
        // already captured above via the enumerationValues comparison.
        let oldFacetsWithoutEnum = old.facets.map { facetSet in
            XMLSchemaFacetSet(
                pattern: facetSet.pattern, minLength: facetSet.minLength, maxLength: facetSet.maxLength,
                length: facetSet.length, minInclusive: facetSet.minInclusive, maxInclusive: facetSet.maxInclusive,
                minExclusive: facetSet.minExclusive, maxExclusive: facetSet.maxExclusive,
                totalDigits: facetSet.totalDigits, fractionDigits: facetSet.fractionDigits
            )
        }
        let newFacetsWithoutEnum = new.facets.map { facetSet in
            XMLSchemaFacetSet(
                pattern: facetSet.pattern, minLength: facetSet.minLength, maxLength: facetSet.maxLength,
                length: facetSet.length, minInclusive: facetSet.minInclusive, maxInclusive: facetSet.maxInclusive,
                minExclusive: facetSet.minExclusive, maxExclusive: facetSet.maxExclusive,
                totalDigits: facetSet.totalDigits, fractionDigits: facetSet.fractionDigits
            )
        }
        if oldFacetsWithoutEnum != newFacetsWithoutEnum {
            changes.append(.init(
                fieldName: "facets",
                kind: .valueChanged(from: facetSummary(old.facets), to: facetSummary(new.facets)),
                isBreaking: true
            ))
        }

        // Union members
        if old.unionMemberQNames != new.unionMemberQNames {
            let oldMembers = Set(old.unionMemberQNames.map(\.qualifiedName))
            let newMembers = Set(new.unionMemberQNames.map(\.qualifiedName))
            for removed in oldMembers.subtracting(newMembers).sorted() {
                changes.append(.init(fieldName: "unionMembers", kind: .itemRemoved(removed), isBreaking: true))
            }
            for added in newMembers.subtracting(oldMembers).sorted() {
                changes.append(.init(fieldName: "unionMembers", kind: .itemAdded(added), isBreaking: false))
            }
        }

        return changes
    }

    // MARK: - Element field diff

    // swiftlint:disable:next function_body_length
    private func diffElement(
        old: XMLNormalizedElementDeclaration,
        new: XMLNormalizedElementDeclaration
    ) -> [XMLSchemaFieldChange] {
        var changes: [XMLSchemaFieldChange] = []

        if old.typeQName != new.typeQName {
            changes.append(.init(
                fieldName: "type",
                kind: .valueChanged(
                    from: old.typeQName?.qualifiedName ?? "none",
                    to: new.typeQName?.qualifiedName ?? "none"
                ),
                isBreaking: true
            ))
        }

        if old.nillable != new.nillable {
            changes.append(.init(
                fieldName: "nillable",
                kind: .valueChanged(from: "\(old.nillable)", to: "\(new.nillable)"),
                isBreaking: old.nillable && !new.nillable // true→false = breaking
            ))
        }

        if old.isAbstract != new.isAbstract {
            changes.append(.init(
                fieldName: "isAbstract",
                kind: .valueChanged(from: "\(old.isAbstract)", to: "\(new.isAbstract)"),
                isBreaking: !old.isAbstract && new.isAbstract
            ))
        }

        if old.substitutionGroup != new.substitutionGroup {
            changes.append(.init(
                fieldName: "substitutionGroup",
                kind: .valueChanged(
                    from: old.substitutionGroup?.qualifiedName ?? "none",
                    to: new.substitutionGroup?.qualifiedName ?? "none"
                ),
                isBreaking: true
            ))
        }

        // Occurrence bounds
        if old.occurrenceBounds.minOccurs != new.occurrenceBounds.minOccurs {
            changes.append(.init(
                fieldName: "minOccurs",
                kind: .valueChanged(
                    from: "\(old.occurrenceBounds.minOccurs)",
                    to: "\(new.occurrenceBounds.minOccurs)"
                ),
                isBreaking: new.occurrenceBounds.minOccurs > old.occurrenceBounds.minOccurs
            ))
        }

        let oldMax = old.occurrenceBounds.maxOccurs.map(String.init) ?? "unbounded"
        let newMax = new.occurrenceBounds.maxOccurs.map(String.init) ?? "unbounded"
        if oldMax != newMax {
            let isBreaking: Bool
            switch (old.occurrenceBounds.maxOccurs, new.occurrenceBounds.maxOccurs) {
            case (nil, .some):
                isBreaking = true
            case (.some(let oldBound), .some(let newBound)):
                isBreaking = newBound < oldBound
            default:
                isBreaking = false
            }
            changes.append(.init(
                fieldName: "maxOccurs",
                kind: .valueChanged(from: oldMax, to: newMax),
                isBreaking: isBreaking
            ))
        }

        return changes
    }

    // MARK: - Helpers

    private func facetSummary(_ facets: XMLSchemaFacetSet?) -> String {
        guard let facets = facets else { return "none" }
        let optional: [String?] = [
            facets.minLength.map { "minLength:\($0)" },
            facets.maxLength.map { "maxLength:\($0)" },
            facets.length.map { "length:\($0)" },
            facets.pattern.map { "pattern:\($0)" },
            facets.minInclusive.map { "minInclusive:\($0)" },
            facets.maxInclusive.map { "maxInclusive:\($0)" },
            facets.minExclusive.map { "minExclusive:\($0)" },
            facets.maxExclusive.map { "maxExclusive:\($0)" },
            facets.totalDigits.map { "totalDigits:\($0)" },
            facets.fractionDigits.map { "fractionDigits:\($0)" }
        ]
        let parts = optional.compactMap { $0 }
        return parts.isEmpty ? "empty" : parts.joined(separator: ", ")
    }
}
// swiftlint:enable type_body_length
