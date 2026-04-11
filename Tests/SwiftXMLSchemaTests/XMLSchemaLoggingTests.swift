import Foundation
import Logging
import SwiftXMLSchema
import XCTest

/// Exercises every logging call-site at `.trace` level so that swift-log's
/// `@autoclosure` message and metadata closures are evaluated and counted as
/// covered by llvm-cov.
///
/// swift-log's `Logger` methods accept message and metadata as `@autoclosure`
/// parameters. When the effective log level is higher than the call's level
/// (e.g. `.info` suppressing `.debug`), those closures are never invoked and
/// llvm-cov marks them as uncovered regions. Injecting a `.trace`-level logger
/// into each struct ensures every closure body is executed without mutating
/// any global state.
final class XMLSchemaLoggingTests: XCTestCase {

    // MARK: - Helpers

    private func traceLogger(label: String = "test") -> Logger {
        var logger = Logger(label: label)
        logger.logLevel = .trace
        return logger
    }

    private func schemaXML(_ body: String) -> String {
        """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:log">
        \(body)
        </xsd:schema>
        """
    }

    private func parse(_ body: String) throws -> XMLSchemaSet {
        let xml = schemaXML(body)
        return try XMLSchemaDocumentParser(logger: traceLogger()).parse(data: Data(xml.utf8))
    }

    private func normalize(_ body: String) throws -> XMLNormalizedSchemaSet {
        try XMLSchemaNormalizer(logger: traceLogger()).normalize(try parse(body))
    }

    // MARK: - Parser + normalizer

    func test_traceLevel_parserAndNormalizerLogsComplexAndSimpleTypes() throws {
        // Exercises parserLogger .debug/.info/.trace and normalizerLogger .debug/.info/.trace autoclosures
        let normalized = try normalize("""
        <xsd:complexType name="Order">
          <xsd:sequence>
            <xsd:element name="id" type="xsd:string"/>
          </xsd:sequence>
          <xsd:attribute name="status" type="xsd:string"/>
        </xsd:complexType>
        <xsd:simpleType name="Status">
          <xsd:restriction base="xsd:string">
            <xsd:enumeration value="open"/>
          </xsd:restriction>
        </xsd:simpleType>
        """)
        XCTAssertFalse(normalized.allComplexTypes.isEmpty)
        XCTAssertFalse(normalized.allSimpleTypes.isEmpty)
    }

    // MARK: - Exporter

    func test_traceLevel_exporterLogsComplexAndSimpleTypes() throws {
        // Exercises exporterLogger .debug/.info/.trace autoclosures
        let normalized = try normalize("""
        <xsd:complexType name="Item">
          <xsd:sequence>
            <xsd:element name="name" type="xsd:string"/>
          </xsd:sequence>
        </xsd:complexType>
        <xsd:simpleType name="Code">
          <xsd:restriction base="xsd:string"/>
        </xsd:simpleType>
        """)
        let doc = XMLJSONSchemaExporter(logger: traceLogger()).export(normalized)
        XCTAssertFalse(doc.defs.isEmpty)
    }

    // MARK: - Differ

    func test_traceLevel_differLogsNoChanges() throws {
        // Exercises differLogger autoclosures — .info "no changes" branch
        let old = try normalize("""
        <xsd:complexType name="Item">
          <xsd:sequence><xsd:element name="name" type="xsd:string"/></xsd:sequence>
        </xsd:complexType>
        """)
        let diff = XMLSchemaDiffer(logger: traceLogger()).diff(old: old, new: old)
        XCTAssertTrue(diff.isEmpty)
    }

    func test_traceLevel_differLogsNonBreakingChanges() throws {
        // Exercises differLogger autoclosures — .info "non-breaking only" branch
        let old = try normalize("""
        <xsd:complexType name="Item">
          <xsd:sequence><xsd:element name="name" type="xsd:string"/></xsd:sequence>
        </xsd:complexType>
        """)
        let new = try normalize("""
        <xsd:complexType name="Item">
          <xsd:sequence>
            <xsd:element name="name" type="xsd:string"/>
            <xsd:element name="extra" type="xsd:string" minOccurs="0"/>
          </xsd:sequence>
        </xsd:complexType>
        """)
        let diff = XMLSchemaDiffer(logger: traceLogger()).diff(old: old, new: new)
        XCTAssertFalse(diff.isEmpty)
    }

    // MARK: - Resolver

    func test_traceLevel_localResolverResolveLog() throws {
        // Exercises resolverLogger .debug autoclosure in LocalFile.resolve
        let resolver = LocalFileXMLSchemaResourceResolver(logger: traceLogger())
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let resolved = try resolver.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }

    func test_traceLevel_localResolverLoadDataLog() throws {
        // Exercises resolverLogger .debug autoclosure in LocalFile.loadSchemaData
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("logging_\(UUID().uuidString).xsd")
        let content = Data("<xs:schema/>".utf8)
        try content.write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let resolver = LocalFileXMLSchemaResourceResolver(logger: traceLogger())
        let loaded = try resolver.loadSchemaData(from: tmpURL)
        XCTAssertEqual(loaded, content)
    }

    func test_traceLevel_catalogResolverHitAndMissLog() throws {
        // Exercises resolverLogger .debug autoclosures in Catalog.init, Catalog.resolve (hit + miss)
        let catalogContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <catalog xmlns="urn:oasis:names:tc:entity:xmlns:xml:catalog">
          <uri name="known.xsd" uri="known.xsd"/>
        </catalog>
        """
        let catalogURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("catalog_log_\(UUID().uuidString).xml")
        try catalogContent.write(to: catalogURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: catalogURL) }

        let resolver = try CatalogXMLSchemaResourceResolver(catalogURL: catalogURL, logger: traceLogger())
        let hit = try resolver.resolve(schemaLocation: "known.xsd", relativeTo: nil)
        XCTAssertEqual(hit.lastPathComponent, "known.xsd")
        let miss = try resolver.resolve(schemaLocation: "other.xsd", relativeTo: nil)
        XCTAssertEqual(miss.lastPathComponent, "other.xsd")
    }

    func test_traceLevel_compositeResolverSuccessLog() throws {
        // Exercises resolverLogger .debug autoclosures in Composite.resolve (start + success)
        let composite = CompositeXMLSchemaResourceResolver(
            [LocalFileXMLSchemaResourceResolver()],
            logger: traceLogger()
        )
        let sourceURL = URL(fileURLWithPath: "/tmp/schemas/main.xsd")
        let resolved = try composite.resolve(schemaLocation: "types.xsd", relativeTo: sourceURL)
        XCTAssertEqual(resolved.lastPathComponent, "types.xsd")
    }
}
