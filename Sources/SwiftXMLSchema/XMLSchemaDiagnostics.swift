import Foundation

// MARK: - XMLSchemaSourceLocation

/// The location of a schema construct within a source file.
public struct XMLSchemaSourceLocation: Sendable, Equatable, Hashable {
    /// The URL of the XSD file in which the construct was found.
    public let fileURL: URL?

    /// The 1-based line number of the construct in the source file, if available.
    ///
    /// Populated for structural parse errors (missing required attributes, malformed
    /// QNames) where the offending XML node is available. Resolution errors emitted
    /// after the full parse (e.g., unresolved type references) carry only `fileURL`.
    public let lineNumber: Int?

    public init(fileURL: URL? = nil, lineNumber: Int? = nil) {
        self.fileURL = fileURL
        self.lineNumber = lineNumber
    }
}

extension XMLSchemaSourceLocation: CustomStringConvertible {
    public var description: String {
        switch (fileURL, lineNumber) {
        case let (url?, line?): return "\(url.lastPathComponent):\(line)"
        case let (url?, nil): return url.lastPathComponent
        case let (nil, line?): return "line \(line)"
        case (nil, nil): return "<unknown>"
        }
    }
}

// MARK: - XMLSchemaParsingDiagnostic

/// A non-fatal diagnostic emitted during parsing or normalisation.
///
/// Fatal errors are still surfaced as thrown ``XMLSchemaParsingError`` values.
public struct XMLSchemaParsingDiagnostic: Sendable {
    /// The severity of the diagnostic.
    public enum Severity: Sendable, Equatable {
        /// An unrecognised but non-fatal construct. Parsing continues.
        case warning
        /// Supplementary context about a warning or error.
        case note
    }

    public let severity: Severity
    /// Human-readable description of the issue.
    public let message: String
    /// Source location, if available.
    public let location: XMLSchemaSourceLocation?

    public init(severity: Severity, message: String, location: XMLSchemaSourceLocation? = nil) {
        self.severity = severity
        self.message = message
        self.location = location
    }
}

extension XMLSchemaParsingDiagnostic: CustomStringConvertible {
    public var description: String {
        let prefix: String
        switch severity {
        case .warning: prefix = "warning"
        case .note: prefix = "note"
        }
        if let loc = location {
            return "\(loc): \(prefix): \(message)"
        }
        return "\(prefix): \(message)"
    }
}

// MARK: - XMLSchemaParsingResult (internal — not yet connected to parser output)

// Reserved for future use when the parser emits non-fatal warnings alongside
// a successfully parsed value. Currently all issues cause a thrown
// XMLSchemaParsingError; this type will become public once the parser
// threads diagnostic collection through its internals.
struct XMLSchemaParsingResult<Value: Sendable>: Sendable {
    let value: Value
    let diagnostics: [XMLSchemaParsingDiagnostic]

    init(value: Value, diagnostics: [XMLSchemaParsingDiagnostic] = []) {
        self.value = value
        self.diagnostics = diagnostics
    }

    var warnings: [XMLSchemaParsingDiagnostic] {
        diagnostics.filter { $0.severity == .warning }
    }

    var hasWarnings: Bool { !warnings.isEmpty }
}
