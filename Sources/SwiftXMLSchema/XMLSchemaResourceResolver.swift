import Foundation

public protocol XMLSchemaResourceResolver: Sendable {
    func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL
    func loadSchemaData(from url: URL) throws -> Data
}

public struct LocalFileXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    public init() {}

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if schemaLocation.hasPrefix("http://") || schemaLocation.hasPrefix("https://") {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                location: schemaLocation,
                message: "Remote schema locations are not supported in this phase."
            )
        }

        guard let sourceURL = sourceURL else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                location: schemaLocation,
                message: "Cannot resolve a relative schema location without a source URL."
            )
        }

        let baseDirectoryURL: URL
        if sourceURL.hasDirectoryPath {
            baseDirectoryURL = sourceURL
        } else {
            baseDirectoryURL = sourceURL.deletingLastPathComponent()
        }

        guard sourceURL.isFileURL else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                location: schemaLocation,
                message: "Only local file URL resolution is supported."
            )
        }

        return URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectoryURL).standardizedFileURL
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                location: url.path,
                message: "Unable to load schema data."
            )
        }
    }
}
