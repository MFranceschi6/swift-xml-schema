/// A type that can visit the top-level components of a normalized XSD schema set.
///
/// The primary associated type `Result` is the value produced by each visit call.
/// When `Result == Void` (the default use-case), every method has a no-op default
/// implementation so you only override the ones you care about.
///
/// All methods are declared `mutating` so that value-type (struct) conformers can
/// accumulate state during a walk without needing a class wrapper.
///
/// Use ``XMLSchemaWalker`` to drive the traversal:
/// ```swift
/// struct TypeNameCollector: XMLSchemaVisitor {
///     var names: [String] = []
///     mutating func visitComplexType(_ complexType: XMLNormalizedComplexType) {
///         names.append(complexType.name)
///     }
/// }
/// var collector = TypeNameCollector()
/// XMLSchemaWalker(schemaSet: normalized).walkComponents(visitor: &collector)
/// ```
public protocol XMLSchemaVisitor<Result> {
    /// The value produced by each visit call. Defaults to `Void`.
    associatedtype Result

    // MARK: Schema-level

    /// Called once for each ``XMLNormalizedSchema`` before its members are visited.
    mutating func visitSchema(_ schema: XMLNormalizedSchema) -> Result

    // MARK: Top-level component declarations

    /// Called for each top-level element declaration.
    mutating func visitElement(_ element: XMLNormalizedElementDeclaration) -> Result

    /// Called for each named complex-type definition.
    mutating func visitComplexType(_ complexType: XMLNormalizedComplexType) -> Result

    /// Called for each named simple-type definition.
    mutating func visitSimpleType(_ simpleType: XMLNormalizedSimpleType) -> Result

    /// Called for each top-level attribute declaration.
    mutating func visitAttribute(_ attribute: XMLNormalizedAttributeDefinition) -> Result

    /// Called for each named attribute-group definition.
    mutating func visitAttributeGroup(_ attributeGroup: XMLNormalizedAttributeGroup) -> Result

    /// Called for each named model-group definition.
    mutating func visitModelGroup(_ modelGroup: XMLNormalizedModelGroup) -> Result

    // MARK: Content nodes (visited when the walker recurses into complex-type content)

    /// Called for each element-use (particle) inside a complex type's effective content.
    mutating func visitElementUse(_ elementUse: XMLNormalizedElementUse) -> Result

    /// Called for each choice group inside a complex type's effective content.
    /// The walker recurses into the choice's own content after this call.
    mutating func visitChoiceGroup(_ choice: XMLNormalizedChoiceGroup) -> Result

    /// Called for each attribute-use on a complex type's effective attribute list.
    mutating func visitAttributeUse(_ attributeUse: XMLNormalizedAttributeUse) -> Result
}

// MARK: - Default no-op implementations for Result == Void

extension XMLSchemaVisitor where Result == Void {
    public mutating func visitSchema(_ schema: XMLNormalizedSchema) {}
    public mutating func visitElement(_ element: XMLNormalizedElementDeclaration) {}
    public mutating func visitComplexType(_ complexType: XMLNormalizedComplexType) {}
    public mutating func visitSimpleType(_ simpleType: XMLNormalizedSimpleType) {}
    public mutating func visitAttribute(_ attribute: XMLNormalizedAttributeDefinition) {}
    public mutating func visitAttributeGroup(_ attributeGroup: XMLNormalizedAttributeGroup) {}
    public mutating func visitModelGroup(_ modelGroup: XMLNormalizedModelGroup) {}
    public mutating func visitElementUse(_ elementUse: XMLNormalizedElementUse) {}
    public mutating func visitChoiceGroup(_ choice: XMLNormalizedChoiceGroup) {}
    public mutating func visitAttributeUse(_ attributeUse: XMLNormalizedAttributeUse) {}
}
