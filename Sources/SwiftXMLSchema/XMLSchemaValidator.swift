import Foundation
import Logging
import SwiftXMLCoder

// MARK: - Validation severity

/// The severity of an ``XMLSchemaValidationDiagnostic``.
public enum XMLSchemaValidationSeverity: String, Sendable, Equatable, Codable {
    /// The document is invalid with respect to the schema.
    case error
    /// The document may be problematic but is not strictly invalid (e.g. undeclared element in a
    /// context that allows wildcards, or a feature not yet checked by this validator).
    case warning
}

// MARK: - Validation diagnostic

/// A single issue found while validating an XML document against a schema.
public struct XMLSchemaValidationDiagnostic: Sendable, Equatable {
    /// Severity of the issue.
    public let severity: XMLSchemaValidationSeverity
    /// XPath-like path to the element or attribute that triggered the issue (e.g. `/Order/items/item[2]`).
    public let path: String
    /// Human-readable description of the issue.
    public let message: String

    public init(severity: XMLSchemaValidationSeverity, path: String, message: String) {
        self.severity = severity
        self.path = path
        self.message = message
    }
}

// MARK: - Validation result

/// The outcome of validating an XML document against an ``XMLNormalizedSchemaSet``.
public struct XMLSchemaValidationResult: Sendable {
    /// All diagnostics produced during validation (both errors and warnings).
    public let diagnostics: [XMLSchemaValidationDiagnostic]

    public init(diagnostics: [XMLSchemaValidationDiagnostic]) {
        self.diagnostics = diagnostics
    }

    /// `true` when no diagnostics with ``XMLSchemaValidationSeverity/error`` severity were found.
    public var isValid: Bool {
        !diagnostics.contains { $0.severity == .error }
    }

    /// Convenience: only the error-severity diagnostics.
    public var errors: [XMLSchemaValidationDiagnostic] {
        diagnostics.filter { $0.severity == .error }
    }

    /// Convenience: only the warning-severity diagnostics.
    public var warnings: [XMLSchemaValidationDiagnostic] {
        diagnostics.filter { $0.severity == .warning }
    }
}

// MARK: - XMLSchemaValidator

/// Validates XML instance documents against an ``XMLNormalizedSchemaSet``.
///
/// ### What is validated
///
/// - Root element must be declared as a top-level `<xsd:element>` in the schema.
/// - For complex-typed elements: child elements and attributes are checked against the effective
///   content model and effective attribute list.
/// - Occurrence bounds (`minOccurs`/`maxOccurs`) on element uses and choice groups.
/// - Required attributes (`use="required"`) must be present; prohibited attributes must be absent.
/// - Unknown attributes are reported when the type has no `<xsd:anyAttribute>`.
/// - For simple-typed elements and attributes: enumeration constraints, string-length facets
///   (`length`, `minLength`, `maxLength`), and numeric range facets
///   (`minInclusive`, `maxInclusive`, `minExclusive`, `maxExclusive`).
/// - `<xsd:simpleContent>` text is validated against the declared value type.
///
/// ### What is not validated (v1 limitations)
///
/// - Strict sequence ordering (child elements are counted but not order-checked).
/// - Identity constraints (`<xsd:key>`, `<xsd:keyref>`, `<xsd:unique>`).
/// - Pattern facets (regex evaluation).
/// - Substitution group compatibility.
/// - Nillable element handling (`xsi:nil`).
///
/// ### Usage
///
/// ```swift
/// let validator = XMLSchemaValidator()
/// let result = try validator.validate(data: xmlData, against: normalizedSchemaSet)
/// if result.isValid {
///     print("Document is valid")
/// } else {
///     result.errors.forEach { print($0.path, $0.message) }
/// }
/// ```
public struct XMLSchemaValidator: Sendable {
    public let logger: Logger

    public init(logger: Logger = Logger(label: "SwiftXMLSchema.validator")) {
        self.logger = logger
    }

    // MARK: - Public API

    /// Parses `data` as an XML document and validates it against `schemaSet`.
    ///
    /// Throws an `XMLParsingError` if the data is not well-formed XML.
    public func validate(data: Data, against schemaSet: XMLNormalizedSchemaSet) throws -> XMLSchemaValidationResult {
        let parser = XMLTreeParser()
        let document = try parser.parse(data: data)
        return validate(document: document, against: schemaSet)
    }

    /// Validates an already-parsed `document` against `schemaSet`.
    public func validate(document: XMLTreeDocument, against schemaSet: XMLNormalizedSchemaSet) -> XMLSchemaValidationResult {
        var ctx = ValidationContext(schemaSet: schemaSet, logger: logger)
        logger.debug("Starting XML instance validation", metadata: [
            "root": .string(document.root.name.localName)
        ])
        validateRoot(document.root, context: &ctx)
        let errorCount = ctx.diagnostics.filter { $0.severity == .error }.count
        let warnCount  = ctx.diagnostics.filter { $0.severity == .warning }.count
        logger.info(
            ctx.diagnostics.isEmpty ? "Validation passed — document is valid" : "Validation complete",
            metadata: ["errors": .stringConvertible(errorCount), "warnings": .stringConvertible(warnCount)]
        )
        return XMLSchemaValidationResult(diagnostics: ctx.diagnostics)
    }
}
