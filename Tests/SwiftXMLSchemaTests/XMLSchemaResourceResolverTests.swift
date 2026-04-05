import XCTest
@testable import SwiftXMLSchema

final class XMLSchemaResourceResolverTests: XCTestCase {

    // MARK: - LocalFileXMLSchemaResourceResolver

    func testLocalResolverRejectsRemoteHTTP() {
        let resolver = LocalFileXMLSchemaResourceResolver()
        XCTAssertThrowsError(
            try resolver.resolve(schemaLocation: "http://example.com/types.xsd", relativeTo: nil)
        ) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testLocalResolverRejectsRemoteHTTPS() {
        let resolver = LocalFileXMLSchemaResourceResolver()
        XCTAssertThrowsError(
            try resolver.resolve(schemaLocation: "https://example.com/types.xsd", relativeTo: nil)
        ) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testLocalResolverRejectsRelativeWithoutSourceURL() {
        let resolver = LocalFileXMLSchemaResourceResolver()
        XCTAssertThrowsError(
            try resolver.resolve(schemaLocation: "types.xsd", relativeTo: nil)
        ) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testLocalResolverResolvesRelativeToFileURL() throws {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let resolved = try resolver.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
        XCTAssert(resolved.path.contains("schemas"))
    }

    func testLocalResolverResolvesRelativeToDirectoryURL() throws {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let dirURL = URL(fileURLWithPath: "/tmp/schemas/", isDirectory: true)
        let resolved = try resolver.resolve(schemaLocation: "types.xsd", relativeTo: dirURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }

    func testLocalLoadSchemaDataThrowsForMissingFile() {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).xsd")
        XCTAssertThrowsError(try resolver.loadSchemaData(from: url)) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed, got \(error)")
            }
        }
    }

    func testLocalLoadSchemaDataSucceedsForExistingFile() throws {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_\(UUID().uuidString).xsd")
        let content = Data("<xs:schema/>".utf8)
        try content.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try resolver.loadSchemaData(from: url)
        XCTAssertEqual(loaded, content)
    }

    // MARK: - RemoteXMLSchemaResourceResolver

    func testRemoteResolverRejectsFileURLOnResolve() {
        let resolver = RemoteXMLSchemaResourceResolver()
        XCTAssertThrowsError(
            try resolver.resolve(schemaLocation: "file:///tmp/a.xsd", relativeTo: nil)
        ) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testRemoteResolverRejectsFileURLOnLoad() {
        let resolver = RemoteXMLSchemaResourceResolver()
        let url = URL(fileURLWithPath: "/tmp/a.xsd")
        XCTAssertThrowsError(try resolver.loadSchemaData(from: url)) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testRemoteResolverAcceptsAbsoluteHTTPS() throws {
        let resolver = RemoteXMLSchemaResourceResolver()
        let resolved = try resolver.resolve(
            schemaLocation: "https://example.com/types.xsd",
            relativeTo: nil
        )
        XCTAssertEqual(resolved.absoluteString, "https://example.com/types.xsd")
    }

    func testRemoteResolverResolvesRelativeAgainstHTTPSBase() throws {
        let resolver = RemoteXMLSchemaResourceResolver()
        let base = URL(string: "https://example.com/schemas/main.xsd")!
        let resolved = try resolver.resolve(schemaLocation: "types.xsd", relativeTo: base)
        XCTAssert(resolved.absoluteString.hasPrefix("https://"))
        XCTAssert(resolved.absoluteString.contains("types.xsd"))
    }

    // MARK: - CatalogXMLSchemaResourceResolver

    private func writeTempFile(_ name: String, content: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testCatalogResolverSystemMapping() throws {
        let schemaURL = try writeTempFile("types_\(UUID().uuidString).xsd", content: "<xs:schema/>")
        defer { try? FileManager.default.removeItem(at: schemaURL) }

        let catalogContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
          <system systemId="http://example.com/types.xsd" uri="\(schemaURL.lastPathComponent)"/>
        </catalog>
        """
        let catalogURL = try writeTempFile("catalog_\(UUID().uuidString).xml", content: catalogContent)
        // Move schema next to catalog
        let schemaNextToCatalog = catalogURL.deletingLastPathComponent()
            .appendingPathComponent(schemaURL.lastPathComponent)
        try? FileManager.default.copyItem(at: schemaURL, to: schemaNextToCatalog)
        defer {
            try? FileManager.default.removeItem(at: catalogURL)
            try? FileManager.default.removeItem(at: schemaNextToCatalog)
        }

        let resolver = try CatalogXMLSchemaResourceResolver(catalogURL: catalogURL)
        let resolved = try resolver.resolve(schemaLocation: "http://example.com/types.xsd", relativeTo: nil)
        XCTAssertEqual(resolved.lastPathComponent, schemaURL.lastPathComponent)
    }

    func testCatalogResolverURIMapping() throws {
        let schemaURL = try writeTempFile("base_\(UUID().uuidString).xsd", content: "<xs:schema/>")
        defer { try? FileManager.default.removeItem(at: schemaURL) }

        let catalogContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
          <uri name="base.xsd" uri="\(schemaURL.lastPathComponent)"/>
        </catalog>
        """
        let catalogURL = try writeTempFile("catalog_\(UUID().uuidString).xml", content: catalogContent)
        let schemaNextToCatalog = catalogURL.deletingLastPathComponent()
            .appendingPathComponent(schemaURL.lastPathComponent)
        try? FileManager.default.copyItem(at: schemaURL, to: schemaNextToCatalog)
        defer {
            try? FileManager.default.removeItem(at: catalogURL)
            try? FileManager.default.removeItem(at: schemaNextToCatalog)
        }

        let resolver = try CatalogXMLSchemaResourceResolver(catalogURL: catalogURL)
        let resolved = try resolver.resolve(schemaLocation: "base.xsd", relativeTo: nil)
        XCTAssertEqual(resolved.lastPathComponent, schemaURL.lastPathComponent)
    }

    func testCatalogResolverFallbackForUnknownLocation() throws {
        let catalogContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog"/>
        """
        let catalogURL = try writeTempFile("catalog_\(UUID().uuidString).xml", content: catalogContent)
        defer { try? FileManager.default.removeItem(at: catalogURL) }

        let resolver = try CatalogXMLSchemaResourceResolver(catalogURL: catalogURL)
        let resolved = try resolver.resolve(schemaLocation: "unknown.xsd", relativeTo: nil)
        XCTAssertEqual(resolved.lastPathComponent, "unknown.xsd")
    }

    func testCatalogResolverThrowsForMissingCatalogFile() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_catalog_\(UUID().uuidString).xml")
        XCTAssertThrowsError(try CatalogXMLSchemaResourceResolver(catalogURL: url)) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    // MARK: - CompositeXMLSchemaResourceResolver

    func testCompositeResolverReturnsFirstSuccess() throws {
        let local = LocalFileXMLSchemaResourceResolver()
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let composite = CompositeXMLSchemaResourceResolver([local])
        let resolved = try composite.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }

    func testCompositeResolverFallsBackToSecondResolver() throws {
        let remote = RemoteXMLSchemaResourceResolver()
        let local = LocalFileXMLSchemaResourceResolver()
        let composite = CompositeXMLSchemaResourceResolver([remote, local])
        // remote rejects relative location without http base; local succeeds with file base
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let resolved = try composite.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }

    func testCompositeResolverThrowsLastErrorWhenAllFail() {
        let composite = CompositeXMLSchemaResourceResolver([
            LocalFileXMLSchemaResourceResolver(),
            RemoteXMLSchemaResourceResolver()
        ])
        // Neither local (no base) nor remote (relative, no http base) can resolve
        XCTAssertThrowsError(
            try composite.resolve(schemaLocation: "types.xsd", relativeTo: nil)
        ) { error in
            XCTAssertNotNil(error as? XMLSchemaParsingError)
        }
    }

    func testCompositeResolverWithNoResolversThrows() {
        let composite = CompositeXMLSchemaResourceResolver([])
        XCTAssertThrowsError(
            try composite.resolve(schemaLocation: "types.xsd", relativeTo: nil)
        ) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed")
            }
        }
    }

    func testCompositeLoadDataFallsBack() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_\(UUID().uuidString).xsd")
        let content = Data("<xs:schema/>".utf8)
        try content.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        // remote rejects file:// urls; local succeeds
        let composite = CompositeXMLSchemaResourceResolver([
            RemoteXMLSchemaResourceResolver(),
            LocalFileXMLSchemaResourceResolver()
        ])
        let loaded = try composite.loadSchemaData(from: url)
        XCTAssertEqual(loaded, content)
    }

    func testCompositeLoadDataThrowsWhenAllFail() {
        // RemoteXMLSchemaResourceResolver rejects file:// URLs on loadSchemaData;
        // composite propagates the last error.
        let composite = CompositeXMLSchemaResourceResolver([RemoteXMLSchemaResourceResolver()])
        let url = URL(fileURLWithPath: "/tmp/a.xsd")
        XCTAssertThrowsError(try composite.loadSchemaData(from: url)) { error in
            XCTAssertNotNil(error as? XMLSchemaParsingError)
        }
    }

    // MARK: - CatalogXMLSchemaResourceResolver — loadSchemaData

    func testCatalogLoadSchemaDataSucceeds() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catalog_load_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let schemaContent = Data("<xs:schema/>".utf8)
        let schemaURL = tmpDir.appendingPathComponent("types.xsd")
        try schemaContent.write(to: schemaURL)

        let catalogContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
          <system systemId="urn:types" uri="types.xsd"/>
        </catalog>
        """
        let catalogURL = tmpDir.appendingPathComponent("catalog.xml")
        try catalogContent.write(to: catalogURL, atomically: true, encoding: .utf8)

        let resolver = try CatalogXMLSchemaResourceResolver(catalogURL: catalogURL)
        let resolved = try resolver.resolve(schemaLocation: "urn:types", relativeTo: nil)
        let loaded = try resolver.loadSchemaData(from: resolved)
        XCTAssertEqual(loaded, schemaContent)
    }

    func testCatalogResolverThrowsForInvalidXMLContent() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bad_catalog_\(UUID().uuidString).xml")
        try "<<< not xml >>>".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try CatalogXMLSchemaResourceResolver(catalogURL: url)) { error in
            guard case .resourceResolutionFailed = error as? XMLSchemaParsingError else {
                return XCTFail("Expected resourceResolutionFailed, got \(error)")
            }
        }
    }

    // MARK: - Async defaults (Swift 5.5+)

    #if swift(>=5.5)
    func testLocalResolverAsyncResolveBridgesToSync() async throws {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let resolved = try await resolver.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }

    func testLocalResolverAsyncLoadDataBridgesToSync() async throws {
        let resolver = LocalFileXMLSchemaResourceResolver()
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("async_load_\(UUID().uuidString).xsd")
        let content = Data("<xs:schema/>".utf8)
        try content.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try await resolver.loadSchemaData(from: url)
        XCTAssertEqual(loaded, content)
    }

    func testRemoteResolverAsyncLoadDataRejectsFileURL() async throws {
        let resolver = RemoteXMLSchemaResourceResolver()
        let url = URL(fileURLWithPath: "/tmp/a.xsd")
        do {
            _ = try await resolver.loadSchemaData(from: url)
            XCTFail("Expected error")
        } catch let error as XMLSchemaParsingError {
            guard case .resourceResolutionFailed = error else {
                return XCTFail("Expected resourceResolutionFailed, got \(error)")
            }
        }
    }
    #endif
}
