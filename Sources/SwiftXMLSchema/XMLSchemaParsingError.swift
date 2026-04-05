public enum XMLSchemaParsingError: Error, Sendable, Equatable {
    case invalidDocument(message: String?)
    case invalidSchema(name: String?, message: String?)
    case unresolvedReference(name: String?, message: String?)
    case resourceResolutionFailed(location: String, message: String?)
    case other(message: String?)
}

extension XMLSchemaParsingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .invalidDocument(message):
            return "invalidDocument: \(message ?? "<nil>")"
        case let .invalidSchema(name, message):
            return "invalidSchema(\(name ?? "<nil>")): \(message ?? "<nil>")"
        case let .unresolvedReference(name, message):
            return "unresolvedReference(\(name ?? "<nil>")): \(message ?? "<nil>")"
        case let .resourceResolutionFailed(location, message):
            return "resourceResolutionFailed(\(location)): \(message ?? "<nil>")"
        case let .other(message):
            return "other: \(message ?? "<nil>")"
        }
    }
}
