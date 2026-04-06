/// Drives depth-first traversal over a ``XMLNormalizedSchemaSet``, invoking an
/// ``XMLSchemaVisitor`` for each component it encounters.
///
/// Traversal order for each schema:
/// 1. ``XMLSchemaVisitor/visitSchema(_:)``
/// 2. For each top-level element declaration: ``XMLSchemaVisitor/visitElement(_:)``
/// 3. For each complex type:
///    - ``XMLSchemaVisitor/visitComplexType(_:)``
///    - Recurse into ``XMLNormalizedComplexType/effectiveContent`` (elements, choices, wildcards)
///    - For each effective attribute: ``XMLSchemaVisitor/visitAttributeUse(_:)``
/// 4. For each simple type: ``XMLSchemaVisitor/visitSimpleType(_:)``
/// 5. For each top-level attribute declaration: ``XMLSchemaVisitor/visitAttribute(_:)``
/// 6. For each attribute group:
///    - ``XMLSchemaVisitor/visitAttributeGroup(_:)``
///    - For each attribute in the group: ``XMLSchemaVisitor/visitAttributeUse(_:)``
/// 7. For each model group:
///    - ``XMLSchemaVisitor/visitModelGroup(_:)``
///    - Recurse into the group's content
///
/// The walker takes the visitor via an `inout` parameter so value-type visitors
/// (e.g. structs that accumulate results) can mutate their state during the walk.
public struct XMLSchemaWalker: Sendable {
    public let schemaSet: XMLNormalizedSchemaSet

    public init(schemaSet: XMLNormalizedSchemaSet) {
        self.schemaSet = schemaSet
    }

    /// Visits all components in declaration order across all schemas.
    ///
    /// Return values from visitor methods are discarded. Use this overload with
    /// `Result == Void` visitors, or value-type visitors that accumulate state
    /// via mutation.
    ///
    /// - Parameter visitor: An `inout` conformer so value-type visitors can accumulate state.
    public func walkComponents(visitor: inout some XMLSchemaVisitor<Void>) {
        for schema in schemaSet.schemas {
            visitor.visitSchema(schema)
            for element in schema.elements { visitor.visitElement(element) }
            for complexType in schema.complexTypes {
                visitor.visitComplexType(complexType)
                walkContentNodes(complexType.effectiveContent, visitor: &visitor)
                for attrUse in complexType.effectiveAttributes { visitor.visitAttributeUse(attrUse) }
            }
            for simpleType in schema.simpleTypes { visitor.visitSimpleType(simpleType) }
            for attribute in schema.attributeDefinitions { visitor.visitAttribute(attribute) }
            for attributeGroup in schema.attributeGroups {
                visitor.visitAttributeGroup(attributeGroup)
                for attrUse in attributeGroup.attributes { visitor.visitAttributeUse(attrUse) }
            }
            for modelGroup in schema.modelGroups {
                visitor.visitModelGroup(modelGroup)
                walkContentNodes(modelGroup.content, visitor: &visitor)
            }
        }
    }

    /// Collects the return values of each visitor call across all schemas and returns
    /// them as a flat array, in traversal order.
    ///
    /// Use this overload when your visitor returns a non-`Void` result and you want
    /// to collect results without maintaining external mutable state.
    ///
    /// ```swift
    /// struct NameCollector: XMLSchemaVisitor {
    ///     func visitComplexType(_ type: XMLNormalizedComplexType) -> String { type.name }
    /// }
    /// var collector = NameCollector()
    /// let names = walker.walkComponents(collecting: &collector)
    /// ```
    ///
    /// - Parameter visitor: An `inout` conformer whose visit methods return `Result`.
    /// - Returns: All non-nil results in traversal order. Each visited component
    ///   contributes exactly one entry.
    public func walkComponents<R>(collecting visitor: inout some XMLSchemaVisitor<R>) -> [R] {
        var results: [R] = []
        for schema in schemaSet.schemas {
            results.append(visitor.visitSchema(schema))
            for element in schema.elements { results.append(visitor.visitElement(element)) }
            for complexType in schema.complexTypes {
                results.append(visitor.visitComplexType(complexType))
                results += walkContentNodes(complexType.effectiveContent, collecting: &visitor)
                for attrUse in complexType.effectiveAttributes {
                    results.append(visitor.visitAttributeUse(attrUse))
                }
            }
            for simpleType in schema.simpleTypes { results.append(visitor.visitSimpleType(simpleType)) }
            for attribute in schema.attributeDefinitions { results.append(visitor.visitAttribute(attribute)) }
            for attributeGroup in schema.attributeGroups {
                results.append(visitor.visitAttributeGroup(attributeGroup))
                for attrUse in attributeGroup.attributes { results.append(visitor.visitAttributeUse(attrUse)) }
            }
            for modelGroup in schema.modelGroups {
                results.append(visitor.visitModelGroup(modelGroup))
                results += walkContentNodes(modelGroup.content, collecting: &visitor)
            }
        }
        return results
    }

    // MARK: - Private

    private func walkContentNodes(
        _ content: [XMLNormalizedContentNode],
        visitor: inout some XMLSchemaVisitor<Void>
    ) {
        for node in content {
            switch node {
            case let .element(use): visitor.visitElementUse(use)
            case let .choice(choice):
                visitor.visitChoiceGroup(choice)
                walkContentNodes(choice.content, visitor: &visitor)
            case .wildcard: break
            }
        }
    }

    private func walkContentNodes<R>(
        _ content: [XMLNormalizedContentNode],
        collecting visitor: inout some XMLSchemaVisitor<R>
    ) -> [R] {
        var results: [R] = []
        for node in content {
            switch node {
            case let .element(use): results.append(visitor.visitElementUse(use))
            case let .choice(choice):
                results.append(visitor.visitChoiceGroup(choice))
                results += walkContentNodes(choice.content, collecting: &visitor)
            case .wildcard: break
            }
        }
        return results
    }
}
