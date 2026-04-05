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
    /// - Parameter visitor: An `inout` conformer so value-type visitors can accumulate state.
    public func walkComponents(visitor: inout some XMLSchemaVisitor<Void>) {
        for schema in schemaSet.schemas {
            visitor.visitSchema(schema)

            for element in schema.elements {
                visitor.visitElement(element)
            }

            for complexType in schema.complexTypes {
                visitor.visitComplexType(complexType)
                walkContentNodes(complexType.effectiveContent, visitor: &visitor)
                for attrUse in complexType.effectiveAttributes {
                    visitor.visitAttributeUse(attrUse)
                }
            }

            for simpleType in schema.simpleTypes {
                visitor.visitSimpleType(simpleType)
            }

            for attribute in schema.attributeDefinitions {
                visitor.visitAttribute(attribute)
            }

            for attributeGroup in schema.attributeGroups {
                visitor.visitAttributeGroup(attributeGroup)
                for attrUse in attributeGroup.attributes {
                    visitor.visitAttributeUse(attrUse)
                }
            }

            for modelGroup in schema.modelGroups {
                visitor.visitModelGroup(modelGroup)
                walkContentNodes(modelGroup.content, visitor: &visitor)
            }
        }
    }

    // MARK: - Private

    private func walkContentNodes(
        _ content: [XMLNormalizedContentNode],
        visitor: inout some XMLSchemaVisitor<Void>
    ) {
        for node in content {
            switch node {
            case let .element(use):
                visitor.visitElementUse(use)
            case let .choice(choice):
                visitor.visitChoiceGroup(choice)
                walkContentNodes(choice.content, visitor: &visitor)
            case .wildcard:
                break
            }
        }
    }
}
