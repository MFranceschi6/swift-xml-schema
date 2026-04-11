import Foundation
import Logging
import SwiftXMLCoder
// On Linux, URLSession/URLRequest live in FoundationNetworking, not Foundation.
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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

    #if swift(>=5.5)
    /// Async variant of ``resolve(schemaLocation:relativeTo:)``.
    ///
    /// The default implementation bridges to the synchronous overload.
    func resolve(schemaLocation: String, relativeTo sourceURL: URL?) async throws -> URL

    /// Async variant of ``loadSchemaData(from:)``.
    ///
    /// The default implementation bridges to the synchronous overload.
    /// ``RemoteXMLSchemaResourceResolver`` overrides this with a native
    /// `URLSession` async implementation that does not block threads.
    func loadSchemaData(from url: URL) async throws -> Data
    #endif
}

#if swift(>=5.5)
extension XMLSchemaResourceResolver {
    // Private sync helpers so the async defaults below call the sync overloads,
    // not the async ones (which would recurse infinitely).
    private func _resolveSync(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        try resolve(schemaLocation: schemaLocation, relativeTo: sourceURL)
    }

    private func _loadDataSync(from url: URL) throws -> Data {
        try loadSchemaData(from: url)
    }

    /// Default implementation: bridges to the synchronous overload.
    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) async throws -> URL {
        try _resolveSync(schemaLocation: schemaLocation, relativeTo: sourceURL)
    }

    /// Default implementation: bridges to the synchronous overload.
    public func loadSchemaData(from url: URL) async throws -> Data {
        try _loadDataSync(from: url)
    }
}
#endif

// MARK: - LocalFileXMLSchemaResourceResolver

/// Resolves schema locations to local file URLs only.
///
/// Remote (`http://`, `https://`) and relative-without-base locations are
/// rejected. Use ``CompositeXMLSchemaResourceResolver`` to chain this resolver
/// with ``RemoteXMLSchemaResourceResolver`` when network access is needed.
public struct LocalFileXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    public let logger: Logger

    public init(logger: Logger = Logger(label: "SwiftXMLSchema.resolver")) {
        self.logger = logger
    }

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

        let resolved = URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectoryURL).standardizedFileURL
        logger.debug("Local file resolved", metadata: [
            "schemaLocation": .string(schemaLocation),
            "resolvedPath": .string(resolved.path)
        ])
        return resolved
    }

    public func loadSchemaData(from url: URL) throws -> Data {
        logger.debug("Loading local schema data", metadata: ["path": .string(url.path)])
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
/// The synchronous ``loadSchemaData(from:)`` implementation blocks the calling
/// thread using a `DispatchSemaphore`. In async contexts, the async overload
/// uses `withCheckedThrowingContinuation` to avoid blocking cooperative threads.
///
/// This resolver rejects `file://` and relative locations. Combine it with
/// ``LocalFileXMLSchemaResourceResolver`` and ``CatalogXMLSchemaResourceResolver``
/// via ``CompositeXMLSchemaResourceResolver`` for a full production setup.
public struct RemoteXMLSchemaResourceResolver: XMLSchemaResourceResolver {
    /// The request timeout in seconds. Defaults to 30.
    public let timeout: TimeInterval
    public let logger: Logger

    public init(timeout: TimeInterval = 30, logger: Logger = Logger(label: "SwiftXMLSchema.resolver")) {
        self.timeout = timeout
        self.logger = logger
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if let absolute = URL(string: schemaLocation),
           let scheme = absolute.scheme,
           scheme == "http" || scheme == "https" {
            return absolute
        }

        if let sourceURL = sourceURL,
           let scheme = sourceURL.scheme,
           scheme == "http" || scheme == "https",
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

        logger.debug("Fetching remote schema", metadata: ["url": .string(url.absoluteString)])

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
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

        switch box.value {
        case .success:
            logger.debug("Remote schema fetched", metadata: ["url": .string(url.absoluteString)])
        case .failure(let err):
            logger.warning("Remote schema fetch failed", metadata: [
                "url": .string(url.absoluteString),
                "error": .string("\(err)")
            ])
        }

        return try box.value.get()
    }

    #if swift(>=5.5)
    /// Async implementation: wraps `URLSession.dataTask` in a
    /// `withCheckedThrowingContinuation` to avoid blocking cooperative threads.
    public func loadSchemaData(from url: URL) async throws -> Data {
        guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            throw XMLSchemaParsingError.resourceResolutionFailed(
                schemaLocation: url.absoluteString,
                message: "RemoteXMLSchemaResourceResolver only loads http:// and https:// URLs."
            )
        }

        logger.debug("Fetching remote schema (async)", metadata: ["url": .string(url.absoluteString)])

        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            request.httpMethod = "GET"
            URLSession.shared.dataTask(with: request) { data, _, error in
                if let data = data {
                    continuation.resume(returning: data)
                } else {
                    let err = XMLSchemaParsingError.resourceResolutionFailed(
                        schemaLocation: url.absoluteString,
                        message: error?.localizedDescription ?? "Unknown network error."
                    )
                    logger.warning("Async remote schema fetch failed", metadata: [
                        "url": .string(url.absoluteString),
                        "error": .string(error?.localizedDescription ?? "Unknown network error.")
                    ])
                    continuation.resume(throwing: err)
                }
            }.resume()
        }
    }
    #endif
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
    public let logger: Logger

    /// Initialises the resolver by parsing the catalog at `catalogURL`.
    ///
    /// - Throws: ``XMLSchemaParsingError/resourceResolutionFailed(schemaLocation:message:sourceLocation:)``
    ///   if the catalog file cannot be read or parsed.
    public init(catalogURL: URL, logger: Logger = Logger(label: "SwiftXMLSchema.resolver")) throws {
        self.catalogURL = catalogURL
        self.logger = logger

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

        // Parse using SwiftXMLCoder (libxml2-backed, Linux-compatible) — this is
        // a build-time or init-time operation so synchronous parsing is fine.
        do {
            let doc = try SwiftXMLCoder.XMLDocument(data: data)
            let children = doc.rootElement()?.children() ?? []
            for element in children {
                switch element.name {
                case "system":
                    if let systemId = element.attribute(named: "systemId"),
                       let uriStr = element.attribute(named: "uri") {
                        system[systemId] = URL(fileURLWithPath: uriStr, relativeTo: baseDirectory)
                            .standardizedFileURL
                    }
                case "uri":
                    if let name = element.attribute(named: "name"),
                       let uriStr = element.attribute(named: "uri") {
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
        logger.debug("Catalog loaded", metadata: [
            "catalog": .string(catalogURL.path),
            "systemMappings": .stringConvertible(system.count),
            "uriMappings": .stringConvertible(uri.count)
        ])
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        if let mapped = systemMappings[schemaLocation] ?? uriMappings[schemaLocation] {
            logger.debug("Catalog hit", metadata: [
                "schemaLocation": .string(schemaLocation),
                "resolvedPath": .string(mapped.path)
            ])
            return mapped
        }
        let baseDirectory = catalogURL.deletingLastPathComponent()
        let fallback = URL(fileURLWithPath: schemaLocation, relativeTo: baseDirectory).standardizedFileURL
        logger.debug("Catalog miss — using relative fallback", metadata: [
            "schemaLocation": .string(schemaLocation),
            "fallbackPath": .string(fallback.path)
        ])
        return fallback
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
    public let logger: Logger

    public init(_ resolvers: [any XMLSchemaResourceResolver], logger: Logger = Logger(label: "SwiftXMLSchema.resolver")) {
        self.resolvers = resolvers
        self.logger = logger
    }

    public func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
        logger.debug("Composite resolving schema location", metadata: [
            "schemaLocation": .string(schemaLocation),
            "resolverCount": .stringConvertible(resolvers.count)
        ])
        var lastError: Error = XMLSchemaParsingError.resourceResolutionFailed(
            schemaLocation: schemaLocation,
            message: "No resolvers configured."
        )
        for resolver in resolvers {
            do {
                let url = try resolver.resolve(schemaLocation: schemaLocation, relativeTo: sourceURL)
                logger.debug("Composite resolver succeeded", metadata: [
                    "schemaLocation": .string(schemaLocation),
                    "resolvedURL": .string(url.absoluteString)
                ])
                return url
            } catch {
                lastError = error
            }
        }
        logger.warning("All resolvers failed for schema location", metadata: [
            "schemaLocation": .string(schemaLocation),
            "lastError": .string("\(lastError)")
        ])
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
        logger.warning("All resolvers failed to load schema data", metadata: [
            "url": .string(url.absoluteString),
            "lastError": .string("\(lastError)")
        ])
        throw lastError
    }
}
