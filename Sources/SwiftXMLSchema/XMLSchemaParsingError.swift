public enum XMLSchemaParsingError: Error, Sendable, Equatable {
    case invalidDocument(message: String?, sourceLocation: XMLSchemaSourceLocation? = nil)
    case invalidSchema(name: String?, message: String?, sourceLocation: XMLSchemaSourceLocation? = nil)
    case unresolvedReference(name: String?, message: String?, sourceLocation: XMLSchemaSourceLocation? = nil)
    /// - Parameters:
    ///   - schemaLocation: The URI of the schema that could not be resolved.
    case resourceResolutionFailed(schemaLocation: String, message: String?, sourceLocation: XMLSchemaSourceLocation? = nil)
    case other(message: String?, sourceLocation: XMLSchemaSourceLocation? = nil)
}

extension XMLSchemaParsingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .invalidDocument(message, loc):
            return formatted(prefix: "invalidDocument", name: nil, message: message, location: loc)
        case let .invalidSchema(name, message, loc):
            return formatted(prefix: "invalidSchema", name: name, message: message, location: loc)
        case let .unresolvedReference(name, message, loc):
            return formatted(prefix: "unresolvedReference", name: name, message: message, location: loc)
        case let .resourceResolutionFailed(schemaLocation, message, loc):
            return formatted(prefix: "resourceResolutionFailed", name: schemaLocation, message: message, location: loc)
        case let .other(message, loc):
            return formatted(prefix: "other", name: nil, message: message, location: loc)
        }
    }

    private func formatted(
        prefix: String,
        name: String?,
        message: String?,
        location: XMLSchemaSourceLocation?
    ) -> String {
        var result = prefix
        if let name { result += "(\(name))" }
        result += ": \(message ?? "<nil>")"
        if let location { result += " [\(location)]" }
        return result
    }
}
