import Foundation
import Logging
import SwiftXMLSchema
import XCTest

final class XMLSchemaInferrerTests: XCTestCase {

    private let inferrer = XMLSchemaInferrer()

    // MARK: - Helpers

    private func infer(_ xml: String) throws -> Data {
        try inferrer.infer(from: Data(xml.utf8))
    }

    private func inferMany(_ xmlList: [String]) throws -> Data {
        try inferrer.infer(from: xmlList.map { Data($0.utf8) })
    }

    private func utf8(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    /// Round-trips: infers schema, then parses + normalizes it to validate it's valid XSD.
    private func roundTrip(_ xml: String) throws -> XMLNormalizedSchemaSet {
        let xsdData = try infer(xml)
        let schemaSet = try XMLSchemaDocumentParser().parse(data: xsdData)
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    // MARK: - Basic structure

    func test_infer_emptyDocuments_returnsEmptySchema() throws {
        // Calling infer(from: [Data]) with an empty list produces an empty schema
        let result = try inferrer.infer(from: [Data]())
        let xml = utf8(result)
        XCTAssertTrue(xml.contains("xsd:schema"))
    }

    func test_infer_singleElement_producesValidXSD() throws {
        let xsd = utf8(try infer("<root/>"))
        XCTAssertTrue(xsd.hasPrefix("<?xml"))
        XCTAssertTrue(xsd.contains("xsd:schema"))
        XCTAssertTrue(xsd.contains("name=\"root\""))
    }

    func test_infer_singleElement_roundTrips() throws {
        _ = try roundTrip("<root/>")
    }

    // MARK: - Text content type inference

    func test_infer_stringContent_usesXsdString() throws {
        let xsd = utf8(try infer("<name>hello</name>"))
        XCTAssertTrue(xsd.contains("xsd:string"))
    }

    func test_infer_integerContent_usesXsdInteger() throws {
        let xsd = utf8(try infer("<qty>42</qty>"))
        XCTAssertTrue(xsd.contains("xsd:integer"))
    }

    func test_infer_decimalContent_usesXsdDecimal() throws {
        let xsd = utf8(try infer("<price>19.99</price>"))
        XCTAssertTrue(xsd.contains("xsd:decimal"))
    }

    func test_infer_booleanContent_usesXsdBoolean() throws {
        let xsd = utf8(try infer("<flag>true</flag>"))
        XCTAssertTrue(xsd.contains("xsd:boolean"))
    }

    func test_infer_dateContent_usesXsdDate() throws {
        let xsd = utf8(try infer("<dob>2024-01-15</dob>"))
        XCTAssertTrue(xsd.contains("xsd:date"))
    }

    func test_infer_dateTimeContent_usesXsdDateTime() throws {
        let xsd = utf8(try infer("<ts>2024-01-15T10:30:00</ts>"))
        XCTAssertTrue(xsd.contains("xsd:dateTime"))
    }

    // MARK: - Type widening across samples

    func test_infer_integerAndDecimal_widensToDecimal() throws {
        let xsd = utf8(try inferMany(["<val>10</val>", "<val>3.14</val>"]))
        XCTAssertTrue(xsd.contains("xsd:decimal"))
        XCTAssertFalse(xsd.contains("xsd:integer"))
    }

    func test_infer_mixedTextAndInteger_widensToString() throws {
        let xsd = utf8(try inferMany(["<val>hello</val>", "<val>42</val>"]))
        XCTAssertTrue(xsd.contains("xsd:string"))
    }

    func test_infer_dateAndDateTime_widensToDateTime() throws {
        let xsd = utf8(try inferMany(["<val>2024-01-01</val>", "<val>2024-01-01T00:00:00</val>"]))
        XCTAssertTrue(xsd.contains("xsd:dateTime"))
    }

    // MARK: - Child elements

    func test_infer_complexTypeWithChildren_producesSequence() throws {
        let xsd = utf8(try infer("<order><id>1</id><name>test</name></order>"))
        XCTAssertTrue(xsd.contains("xsd:sequence"))
        XCTAssertTrue(xsd.contains("name=\"id\""))
        XCTAssertTrue(xsd.contains("name=\"name\""))
    }

    func test_infer_complexTypeWithChildren_roundTrips() throws {
        _ = try roundTrip("<order><id>1</id><name>test</name></order>")
    }

    func test_infer_nestedElements_roundTrips() throws {
        _ = try roundTrip("""
        <orders>
          <order>
            <id>1</id>
            <items>
              <item><sku>A001</sku><qty>2</qty></item>
            </items>
          </order>
        </orders>
        """)
    }

    // MARK: - Occurrence bounds

    func test_infer_optionalChild_emitsMinOccursZero() throws {
        // child present in first sample, absent in second
        let xsd = utf8(try inferMany([
            "<root><note>hello</note></root>",
            "<root></root>"
        ]))
        XCTAssertTrue(xsd.contains("minOccurs=\"0\""))
    }

    func test_infer_requiredChild_omitsMinOccurs() throws {
        // child present in all samples
        let xsd = utf8(try inferMany([
            "<root><id>1</id></root>",
            "<root><id>2</id></root>"
        ]))
        // minOccurs defaults to 1 — should not appear explicitly
        XCTAssertFalse(xsd.contains("minOccurs=\"0\""))
    }

    func test_infer_repeatingChild_emitsMaxOccursUnbounded() throws {
        let xsd = utf8(try infer("""
        <list>
          <item>a</item>
          <item>b</item>
          <item>c</item>
        </list>
        """))
        XCTAssertTrue(xsd.contains("maxOccurs=\"unbounded\""))
    }

    // MARK: - Attributes

    func test_infer_presentAttribute_emittedAsOptional_whenNotInAllSamples() throws {
        let xsd = utf8(try inferMany([
            "<item id=\"1\"/>",
            "<item/>"
        ]))
        XCTAssertTrue(xsd.contains("use=\"optional\""))
    }

    func test_infer_presentAttributeInAllSamples_emittedAsRequired() throws {
        let xsd = utf8(try inferMany([
            "<item id=\"1\"/>",
            "<item id=\"2\"/>"
        ]))
        XCTAssertTrue(xsd.contains("use=\"required\""))
    }

    func test_infer_integerAttribute_inferredType() throws {
        let xsd = utf8(try infer("<item count=\"5\"/>"))
        XCTAssertTrue(xsd.contains("xsd:integer") || xsd.contains("xsd:boolean"))
    }

    // MARK: - Simple content with attributes

    func test_infer_simpleContentWithAttr_usesExtension() throws {
        let xsd = utf8(try infer("<amount currency=\"USD\">19.99</amount>"))
        XCTAssertTrue(xsd.contains("xsd:simpleContent"))
        XCTAssertTrue(xsd.contains("xsd:extension"))
        XCTAssertTrue(xsd.contains("xsd:decimal"))
    }

    func test_infer_simpleContentWithAttr_roundTrips() throws {
        _ = try roundTrip("<amount currency=\"USD\">19.99</amount>")
    }

    // MARK: - Namespace

    func test_infer_withNamespace_includesTargetNamespace() throws {
        let xsd = utf8(try infer("<root xmlns=\"urn:test\"/>"))
        XCTAssertTrue(xsd.contains("targetNamespace=\"urn:test\""))
    }

    func test_infer_withoutNamespace_omitsTargetNamespace() throws {
        let xsd = utf8(try infer("<root/>"))
        XCTAssertFalse(xsd.contains("targetNamespace"))
    }

    // MARK: - Logger autoclosures at trace level

    func test_infer_traceLogger_exercisesAllAutoclosures() throws {
        var logger = Logger(label: "test.inferrer")
        logger.logLevel = .trace
        let traceInferrer = XMLSchemaInferrer(logger: logger)

        let xml = """
        <orders>
          <order id="1">
            <total>99.99</total>
            <shipped>true</shipped>
          </order>
          <order id="2">
            <total>14.50</total>
            <shipped>false</shipped>
          </order>
        </orders>
        """
        let data = try traceInferrer.infer(from: Data(xml.utf8))
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - InferredType widening

    func test_inferredType_wideningSameType_returnsItself() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.integer.widened(by: .integer),
            .integer
        )
    }

    func test_inferredType_integerPlusDecimal_widensToDecimal() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.integer.widened(by: .decimal),
            .decimal
        )
    }

    func test_inferredType_integerPlusString_widensToString() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.integer.widened(by: .string),
            .string
        )
    }

    func test_inferredType_datePlusDateTime_widensToDateTime() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.date.widened(by: .dateTime),
            .dateTime
        )
    }

    func test_inferredType_booleanPlusDecimal_widensToDecimal() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.boolean.widened(by: .decimal),
            .decimal
        )
    }

    func test_inferredType_datePlusInteger_widensToString() {
        XCTAssertEqual(
            XMLSchemaInferrer.InferredType.date.widened(by: .integer),
            .string
        )
    }

    func test_inferredType_xsdNames() {
        XCTAssertEqual(XMLSchemaInferrer.InferredType.boolean.xsdName, "xsd:boolean")
        XCTAssertEqual(XMLSchemaInferrer.InferredType.integer.xsdName, "xsd:integer")
        XCTAssertEqual(XMLSchemaInferrer.InferredType.decimal.xsdName, "xsd:decimal")
        XCTAssertEqual(XMLSchemaInferrer.InferredType.date.xsdName, "xsd:date")
        XCTAssertEqual(XMLSchemaInferrer.InferredType.dateTime.xsdName, "xsd:dateTime")
        XCTAssertEqual(XMLSchemaInferrer.InferredType.string.xsdName, "xsd:string")
    }
}
