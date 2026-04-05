import Foundation

// MARK: - XMLSchemaSourceLocation

/// The location of a schema construct within a source file.
///
/// Line-number tracking requires the tree-based parser path (``XMLTreeMetadata``).
/// When using the default ``XMLNode``-based parser, ``lineNumber`` is always `nil`.
public struct XMLSchemaSourceLocation: Sendable, Equatable, Hashable {
    /// The URL of the XSD file in which the construct was found.
    public let fileURL: URL?

    /// The 1-based line number of the construct in the source file, if available.
    ///
    /// This value is `nil` when parsing via the ``XMLNode``-based path because
    /// `libxml2` line numbers are only accessible on the immutable ``XMLTreeDocument``
    /// after the full parse completes. Future work will expose this via the
    /// tree-based parser.
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
/// Use ``XMLSchemaParsingResult`` to collect non-fatal diagnostics alongside a
/// successfully parsed value.
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

// MARK: - XMLSchemaParsingResult

/// A successfully parsed value together with any non-fatal diagnostics emitted
/// during parsing.
///
/// Fatal errors cause a throw instead of producing an ``XMLSchemaParsingResult``.
public struct XMLSchemaParsingResult<Value: Sendable>: Sendable {
    /// The parsed value.
    public let value: Value
    /// All non-fatal diagnostics collected during parsing, in emission order.
    public let diagnostics: [XMLSchemaParsingDiagnostic]

    public init(value: Value, diagnostics: [XMLSchemaParsingDiagnostic] = []) {
        self.value = value
        self.diagnostics = diagnostics
    }

    /// Diagnostics with `.warning` severity.
    public var warnings: [XMLSchemaParsingDiagnostic] {
        diagnostics.filter { $0.severity == .warning }
    }

    /// `true` when at least one warning was emitted.
    public var hasWarnings: Bool { !warnings.isEmpty }
}
