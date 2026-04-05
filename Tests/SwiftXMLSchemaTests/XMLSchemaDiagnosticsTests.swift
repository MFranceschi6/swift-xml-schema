import XCTest
@testable import SwiftXMLSchema

final class XMLSchemaDiagnosticsTests: XCTestCase {

    // MARK: - XMLSchemaSourceLocation

    func testSourceLocationWithFileURLAndLine() {
        let url = URL(fileURLWithPath: "/tmp/schema.xsd")
        let loc = XMLSchemaSourceLocation(fileURL: url, lineNumber: 42)
        XCTAssertEqual(loc.fileURL, url)
        XCTAssertEqual(loc.lineNumber, 42)
        XCTAssertEqual(loc.description, "schema.xsd:42")
    }

    func testSourceLocationWithFileURLOnly() {
        let url = URL(fileURLWithPath: "/tmp/schema.xsd")
        let loc = XMLSchemaSourceLocation(fileURL: url)
        XCTAssertEqual(loc.fileURL, url)
        XCTAssertNil(loc.lineNumber)
        XCTAssertEqual(loc.description, "schema.xsd")
    }

    func testSourceLocationWithLineOnly() {
        let loc = XMLSchemaSourceLocation(lineNumber: 7)
        XCTAssertNil(loc.fileURL)
        XCTAssertEqual(loc.lineNumber, 7)
        XCTAssertEqual(loc.description, "line 7")
    }

    func testSourceLocationEmpty() {
        let loc = XMLSchemaSourceLocation()
        XCTAssertNil(loc.fileURL)
        XCTAssertNil(loc.lineNumber)
        XCTAssertEqual(loc.description, "<unknown>")
    }

    func testSourceLocationEquality() {
        let url = URL(fileURLWithPath: "/tmp/a.xsd")
        let a = XMLSchemaSourceLocation(fileURL: url, lineNumber: 1)
        let b = XMLSchemaSourceLocation(fileURL: url, lineNumber: 1)
        let c = XMLSchemaSourceLocation(fileURL: url, lineNumber: 2)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testSourceLocationHashable() {
        let url = URL(fileURLWithPath: "/tmp/a.xsd")
        let set: Set<XMLSchemaSourceLocation> = [
            XMLSchemaSourceLocation(fileURL: url, lineNumber: 1),
            XMLSchemaSourceLocation(fileURL: url, lineNumber: 1),
            XMLSchemaSourceLocation(fileURL: url, lineNumber: 2)
        ]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - XMLSchemaParsingError with sourceLocation

    func testErrorDescriptionIncludesLocation() {
        let loc = XMLSchemaSourceLocation(fileURL: URL(fileURLWithPath: "/tmp/a.xsd"), lineNumber: 10)
        let error = XMLSchemaParsingError.invalidSchema(name: "Foo", message: "bad type", sourceLocation: loc)
        XCTAssert(error.description.contains("a.xsd:10"))
        XCTAssert(error.description.contains("Foo"))
        XCTAssert(error.description.contains("bad type"))
    }

    func testErrorDescriptionWithoutLocation() {
        let error = XMLSchemaParsingError.invalidSchema(name: "Foo", message: "bad type")
        XCTAssertFalse(error.description.contains("["))
    }

    func testResourceResolutionFailedUsesSchemaLocationLabel() {
        let error = XMLSchemaParsingError.resourceResolutionFailed(schemaLocation: "types.xsd", message: "not found")
        XCTAssert(error.description.contains("types.xsd"))
        XCTAssert(error.description.contains("not found"))
    }

    func testParserAttachesSourceURLToInvalidDocumentError() throws {
        let url = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).xsd")
        let parser = XMLSchemaDocumentParser(resourceResolver: LocalFileXMLSchemaResourceResolver())
        do {
            _ = try parser.parse(data: Data("not xml".utf8), sourceURL: url)
            XCTFail("Expected error")
        } catch let err as XMLSchemaParsingError {
            if case let .invalidDocument(_, loc) = err {
                XCTAssertEqual(loc?.fileURL, url)
            } else {
                XCTFail("Unexpected error case: \(err)")
            }
        }
    }

    func testParserAttachesSourceURLToMissingRootError() throws {
        let url = URL(fileURLWithPath: "/tmp/empty_\(UUID().uuidString).xsd")
        let xml = Data("<root/>".utf8)
        let parser = XMLSchemaDocumentParser(resourceResolver: LocalFileXMLSchemaResourceResolver())
        do {
            _ = try parser.parse(data: xml, sourceURL: url)
            XCTFail("Expected error")
        } catch let err as XMLSchemaParsingError {
            if case let .invalidDocument(_, loc) = err {
                XCTAssertEqual(loc?.fileURL, url)
            } else {
                XCTFail("Unexpected error case: \(err)")
            }
        }
    }

    // MARK: - XMLSchemaParsingDiagnostic

    func testDiagnosticWarningDescription() {
        let diag = XMLSchemaParsingDiagnostic(severity: .warning, message: "unknown facet 'foo'")
        XCTAssertEqual(diag.description, "warning: unknown facet 'foo'")
    }

    func testDiagnosticNoteDescription() {
        let loc = XMLSchemaSourceLocation(fileURL: URL(fileURLWithPath: "/tmp/a.xsd"))
        let diag = XMLSchemaParsingDiagnostic(severity: .note, message: "see base type", location: loc)
        XCTAssert(diag.description.contains("note:"))
        XCTAssert(diag.description.contains("a.xsd"))
        XCTAssert(diag.description.contains("see base type"))
    }

    func testDiagnosticSeverityEquality() {
        XCTAssertEqual(XMLSchemaParsingDiagnostic.Severity.warning, .warning)
        XCTAssertNotEqual(XMLSchemaParsingDiagnostic.Severity.warning, .note)
    }

    // MARK: - XMLSchemaParsingResult

    func testParsingResultNoWarnings() {
        let result = XMLSchemaParsingResult(value: 42)
        XCTAssertEqual(result.value, 42)
        XCTAssertTrue(result.diagnostics.isEmpty)
        XCTAssertFalse(result.hasWarnings)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testParsingResultWithWarnings() {
        let w1 = XMLSchemaParsingDiagnostic(severity: .warning, message: "w1")
        let n1 = XMLSchemaParsingDiagnostic(severity: .note, message: "n1")
        let result = XMLSchemaParsingResult(value: "schema", diagnostics: [w1, n1])
        XCTAssertEqual(result.value, "schema")
        XCTAssertEqual(result.diagnostics.count, 2)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(result.warnings.first?.message, "w1")
    }

    func testParsingResultFiltersByWarningOnly() {
        let diags = [
            XMLSchemaParsingDiagnostic(severity: .note, message: "a"),
            XMLSchemaParsingDiagnostic(severity: .warning, message: "b"),
            XMLSchemaParsingDiagnostic(severity: .note, message: "c"),
            XMLSchemaParsingDiagnostic(severity: .warning, message: "d")
        ]
        let result = XMLSchemaParsingResult(value: 0, diagnostics: diags)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertEqual(result.warnings.map(\.message), ["b", "d"])
    }
}
