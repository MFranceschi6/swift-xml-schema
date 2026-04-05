import Foundation

// Mutable reference box used to pass a Result value across a DispatchSemaphore
// boundary without triggering Swift 6 captured-var concurrency warnings.
// The semaphore.wait() provides the required memory barrier before the value
// is read back on the calling thread.
private final class _ResultBox: @unchecked Sendable {
    var value: Result<Data, Error>
    init(_ value: Result<Data, Error>) { self.value = value }
}

/// A type that can locate and load XSD schema files.
///
/// Implement this protocol to support custom schema resolution strategies such
/// as remote HTTP fetching, OASIS XML Catalog remapping, or in-memory caches.
/// All conforming types must be `Sendable` so they can be shared across
/// concurrency domains without data races.
public protocol XMLSchemaResourceResolver: Sendable {
    /// Returns the canonical URL for a schema at `schemaLocation`, optionally
    /// resolved relative to `sourceURL`.
    func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL

    /// Loads the raw XSD bytes from `url`.
    func loadSchemaData(from url: URL) throws -> Data
}

// MARK: - LocalFileXMLSchemaResourceResolver

/// Resolves schema locations to local file URLs only.
///
/// Remote (`http://`, `https://`) and relative-without-base locations are
/// rejected. Use ``CompositeXMLSchemaResourceResolver`` to chain this resolver
/// with ``RemoteXMLSchemaResourceResolver`` when network access is needed.
public struct LocalFileXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    public init() {}

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if schemaLocation.hasPrefix("http://") || schemaLocation.hasPrefix("https://") {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: schemaLocation,
                message: "Remote schema locations are not supported by LocalFileXMLSchemaResourceResolver."
            )
        }

        guard let sourceURL = sourceURL else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: schemaLocation,
                message: "Cannot resolve a relative schema location without a source URL."
            )
        }

        guard sourceURL.isFileURL else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: schemaLocation,
                message: "Only local file URL resolution is supported."
            )
        }

        let baseDirectoryURL: URL
        if sourceURL.hasDirectoryPath {
            baseDirectoryURL = sourceURL
        } else {
            baseDirectoryURL = sourceURL.deletingLastPathComponent()
        }

        return URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectoryURL).standardizedFileURL
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: url.path,
                message: "Unable to load schema data from '\(url.path)'."
            )
        }
    }
}

// MARK: - RemoteXMLSchemaResourceResolver

/// Resolves and loads schemas from remote `http://` and `https://` URLs.
///
/// Network I/O is performed synchronously using a ``DispatchSemaphore``-based
/// wrapper around `URLSession`. Async variants will be available in Phase 0.5.
///
/// This resolver rejects `file://` and relative locations. Combine it with
/// ``LocalFileXMLSchemaResourceResolver`` and ``CatalogXMLSchemaResourceResolver``
/// via ``CompositeXMLSchemaResourceResolver`` for a full production setup.
public struct RemoteXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    /// The request timeout in seconds. Defaults to 30.
    public let timeout: TimeInterval

    public init(timeout: TimeInterval = 30) {
        self.timeout = timeout
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if let absolute = URL(string: schemaLocation),
           let scheme = absolute.scheme,
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if let sourceURL = sourceURL,
           let scheme = sourceURL.scheme,
           (scheme == "http" || scheme == "https"),
           let base = URL(string: schemaLocation, relativeTo: sourceURL) {
            return base
        }

        throw XMLSchemaParsingError.resourceResolutionFailed(
            schemaLocation: schemaLocation,
            message: "RemoteXMLSchemaResourceResolver requires an http:// or https:// location."
        )
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: url.absoluteString,
                message: "RemoteXMLSchemaResourceResolver only loads http:// and https:// URLs."
            )
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"

        // Use a class-based box so the URLSession callback can mutate the result
        // across threads without triggering Swift 6 captured-var warnings.
        // The DispatchSemaphore.wait() call provides the necessary memory barrier
        // before the box's value is read back on the calling thread.
        let box = _ResultBox(
            .failure(XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: url.absoluteString,
                message: "Network request did not complete."
            ))
        )
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data {
                box.value = .success(data)
            } else {
                box.value = .failure(
                    XMLSchemaParsingError.resourceResolutionFailed(
                        schemaLocation: url.absoluteString,
                        message: error?.localizedDescription ?? "Unknown network error."
                    )
                )
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()

        return try box.value.get()
    }
}

// MARK: - CatalogXMLSchemaResourceResolver

/// Resolves schema locations using an OASIS XML Catalog file.
///
/// Supports `<system>` and `<uri>` catalog entries. Unknown entries fall back
/// to a file URL relative to the catalog file's directory. More advanced
/// catalog features (`delegateSystem`, `rewriteSystem`) are deferred to a
/// later phase.
///
/// - Note: The catalog file itself is parsed with `Foundation.XMLDocument`.
public struct CatalogXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    private let catalogURL: URL
    private let systemMappings: [String: URL]
    private let uriMappings: [String: URL]

    /// Initialises the resolver by parsing the catalog at `catalogURL`.
    ///
    /// - Throws: ``XMLSchemaParsingError/resourceResolutionFailed(schemaLocation:message:sourceLocation:)``
    ///   if the catalog file cannot be read or parsed.
    public init(catalogURL: URL) throws {
        self.catalogURL = catalogURL

        let data: Data
        do {
            data = try Data(contentsOf: catalogURL)
        } catch {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: catalogURL.path,
                message: "Unable to read XML catalog at '\(catalogURL.path)'."
            )
        }

        let baseDirectory = catalogURL.deletingLastPathComponent()
        var system: [String: URL] = [:]
        var uri: [String: URL] = [:]

        // Parse using Foundation.XMLDocument — this is a build-time or init-time
        // operation so synchronous Foundation parsing is acceptable here.
        do {
            let doc = try Foundation.XMLDocument(data: data)
            let root = doc.rootElement()
            let children = root?.children?.compactMap { $0 as? Foundation.XMLElement } ?? []
            for element in children {
                switch element.localName {
                case "system":
                    if let systemId = element.attribute(forName: "systemId")?.stringValue,
                       let uriStr = element.attribute(forName: "uri")?.stringValue {
                        system[systemId] = URL(fileURLWithPath: uriStr, relativeTo: baseDirectory)
                            .standardizedFileURL
                    }
                case "uri":
                    if let name = element.attribute(forName: "name")?.stringValue,
                       let uriStr = element.attribute(forName: "uri")?.stringValue {
                        uri[name] = URL(fileURLWithPath: uriStr, relativeTo: baseDirectory)
                            .standardizedFileURL
                    }
                default:
                    break
                }
            }
        } catch {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: catalogURL.path,
                message: "Unable to parse XML catalog: \(error.localizedDescription)"
            )
        }

        systemMappings = system
        uriMappings = uri
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if let mapped = systemMappings[schemaLocation] ?? uriMappings[schemaLocation] {
            return mapped
        }
        let baseDirectory = catalogURL.deletingLastPathComponent()
        return URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectory).standardizedFileURL
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: url.path,
                message: "Unable to load schema data from '\(url.path)'."
            )
        }
    }
}

// MARK: - CompositeXMLSchemaResourceResolver

/// A resolver that tries a sequence of child resolvers in order, returning the
/// first successful result.
///
/// The recommended production configuration is:
/// ```swift
/// CompositeXMLSchemaResourceResolver([
///     LocalFileXMLSchemaResourceResolver(),
///     CatalogXMLSchemaResourceResolver(catalogURL: catalogURL),
///     RemoteXMLSchemaResourceResolver()
/// ])
/// ```
///
/// If every resolver fails, the error from the last resolver is re-thrown.
public struct CompositeXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    /// The child resolvers, tried in order.
    public let resolvers: [any XMLSchemaResourceResolver]

    public init(_ resolvers: [any XMLSchemaResourceResolver]) {
        self.resolvers = resolvers
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        var lastError: Error = XMLSchemaParsingError.resourceResolutionFailed(
            schemaLocation: schemaLocation,
            message: "No resolvers configured."
        )
        for resolver in resolvers {
            do {
                return try resolver.resolve(schemaLocation: schemaLocation, relativeTo: sourceURL)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        var lastError: Error = XMLSchemaParsingError.resourceResolutionFailed(
            schemaLocation: url.absoluteString,
            message: "No resolvers configured."
        )
        for resolver in resolvers {
            do {
                return try resolver.loadSchemaData(from: url)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
