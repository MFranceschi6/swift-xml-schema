import Foundation
import Logging
import SwiftXMLCoder

public struct XMLSchemaDocumentParser: Sendable {
    let resourceResolver: any XMLSchemaResourceResolver
    let logger: Logger

    public init(
        resourceResolver: any XMLSchemaResourceResolver = LocalFileXMLSchemaResourceResolver(),
        logger: Logger = Logger(label: "SwiftXMLSchema.parser")
    ) {
        self.resourceResolver = resourceResolver
        self.logger = logger
    }

    #if swift(>=6.0)
    public func parse(data: Data) throws(XMLSchemaParsingError) -> XMLSchemaSet {
        try bridged { try parseDocument(data: data, sourceURL: nil) }
    }

    public func parse(data: Data, sourceURL: URL) throws(XMLSchemaParsingError) -> XMLSchemaSet {
        try bridged { try parseDocument(data: data, sourceURL: sourceURL) }
    }

    public func parse(url: URL) throws(XMLSchemaParsingError) -> XMLSchemaSet {
        try bridged {
            let data = try resourceResolver.loadSchemaData(from: url)
            return try parseDocument(data: data, sourceURL: url)
        }
    }
    #else
    public func parse(data: Data) throws -> XMLSchemaSet {
        try parseDocument(data: data, sourceURL: nil)
    }

    public func parse(data: Data, sourceURL: URL) throws -> XMLSchemaSet {
        try parseDocument(data: data, sourceURL: sourceURL)
    }

    public func parse(url: URL) throws -> XMLSchemaSet {
        let data = try resourceResolver.loadSchemaData(from: url)
        return try parseDocument(data: data, sourceURL: url)
    }
    #endif
}

#if swift(>=6.0)
extension XMLSchemaDocumentParser {
    /// Bridges an untyped-throws closure into a typed `throws(XMLSchemaParsingError)`.
    ///
    /// All internal parse functions only ever throw `XMLSchemaParsingError`; the
    /// `preconditionFailure` branch is unreachable in practice.
    @inline(__always)
    func bridged<T>(_ body: () throws -> T) throws(XMLSchemaParsingError) -> T {
        do {
            return try body()
        } catch let error as XMLSchemaParsingError {
            throw error
        } catch {
            preconditionFailure("Unexpected non-XMLSchemaParsingError: \(error)")
        }
    }
}
#endif

#if swift(>=5.5)
extension XMLSchemaDocumentParser {
    /// Loads and parses the schema at `url` asynchronously, using the resolver's
    /// async `loadSchemaData(from:)` implementation.
    ///
    /// Imported and included schemas are loaded concurrently at each import level
    /// via a `TaskGroup`, reducing wall-clock time for schemas with many imports.
    public func parse(url: URL) async throws -> XMLSchemaSet {
        let data = try await resourceResolver.loadSchemaData(from: url)
        return try await parseDocumentAsync(data: data, sourceURL: url)
    }
}
#endif
