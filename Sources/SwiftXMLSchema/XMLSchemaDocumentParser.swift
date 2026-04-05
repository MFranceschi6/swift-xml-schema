import Foundation
import SwiftXMLCoder

public struct XMLSchemaDocumentParser: Sendable {
    let resourceResolver: any XMLSchemaResourceResolver

    public init(resourceResolver: any XMLSchemaResourceResolver = LocalFileXMLSchemaResourceResolver()) {
        self.resourceResolver = resourceResolver
    }

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
}
