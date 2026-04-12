import Foundation
import SwiftXMLCoder
import SwiftXMLSchema
import XCTest

/// Tests for XSD 1.1 features: assertions, type alternatives, and open content.
final class XMLXSD11Tests: XCTestCase {

    // MARK: - Helpers

    private func parseAndNormalize(_ xsd: String) throws -> XMLNormalizedSchemaSet {
        let data = Data(xsd.utf8)
        let schemaSet = try XMLSchemaDocumentParser().parse(data: data)
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    private func parse(_ xsd: String) throws -> XMLSchemaSet {
        let data = Data(xsd.utf8)
        return try XMLSchemaDocumentParser().parse(data: data)
    }

    // MARK: - xsd:assert (assertions)

    func test_assert_parsedOnComplexType() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Range">
            <xsd:sequence>
              <xsd:element name="min" type="xsd:integer"/>
              <xsd:element name="max" type="xsd:integer"/>
            </xsd:sequence>
            <xsd:assert test="min le max"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertEqual(complexType.assertions.count, 1)
        XCTAssertEqual(complexType.assertions[0].test, "min le max")
    }

    func test_assert_multipleAssertions() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Date">
            <xsd:sequence>
              <xsd:element name="year" type="xsd:integer"/>
              <xsd:element name="month" type="xsd:integer"/>
            </xsd:sequence>
            <xsd:assert test="month ge 1"/>
            <xsd:assert test="month le 12"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertEqual(complexType.assertions.count, 2)
        XCTAssertEqual(complexType.assertions[0].test, "month ge 1")
        XCTAssertEqual(complexType.assertions[1].test, "month le 12")
    }

    func test_assert_withXpathDefaultNamespace() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Foo">
            <xsd:sequence>
              <xsd:element name="val" type="xsd:string"/>
            </xsd:sequence>
            <xsd:assert test="val != ''" xpathDefaultNamespace="##targetNamespace"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertEqual(complexType.assertions.count, 1)
        XCTAssertEqual(complexType.assertions[0].xpathDefaultNamespace, "##targetNamespace")
    }

    func test_assert_noAssertions_emptyArray() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Simple">
            <xsd:sequence>
              <xsd:element name="val" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertTrue(complexType.assertions.isEmpty)
    }

    func test_assert_survivesNormalization() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Range">
            <xsd:sequence>
              <xsd:element name="min" type="xsd:integer"/>
              <xsd:element name="max" type="xsd:integer"/>
            </xsd:sequence>
            <xsd:assert test="min le max"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let normalized = try parseAndNormalize(xsd)
        let complexType = try XCTUnwrap(normalized.allComplexTypes.first(where: { $0.name == "Range" }))
        XCTAssertEqual(complexType.assertions.count, 1)
        XCTAssertEqual(complexType.assertions[0].test, "min le max")
    }

    // MARK: - xsd:openContent (open content on complex type)

    func test_openContent_parsedOnComplexType() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="interleave">
              <xsd:any processContents="lax"/>
            </xsd:openContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        let oc = try XCTUnwrap(complexType.openContent)
        XCTAssertEqual(oc.mode, .interleave)
        XCTAssertNotNil(oc.any)
        XCTAssertEqual(oc.any?.processContents, .lax)
    }

    func test_openContent_appendMode() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Appendable">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="append">
              <xsd:any processContents="skip"/>
            </xsd:openContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertEqual(complexType.openContent?.mode, .append)
    }

    func test_openContent_noneMode() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Closed">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="none"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertEqual(complexType.openContent?.mode, XMLSchemaOpenContentMode.none)
    }

    func test_openContent_survivesNormalization() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="interleave">
              <xsd:any processContents="lax"/>
            </xsd:openContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let normalized = try parseAndNormalize(xsd)
        let complexType = try XCTUnwrap(normalized.allComplexTypes.first(where: { $0.name == "Open" }))
        XCTAssertEqual(complexType.openContent?.mode, .interleave)
    }

    func test_openContent_nilWhenAbsent() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Normal">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertNil(complexType.openContent)
    }

    // MARK: - xsd:openContent + validator

    func test_openContent_validatorAllowsExtraElements() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="root" type="Open"/>
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="interleave">
              <xsd:any processContents="lax"/>
            </xsd:openContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let normalized = try parseAndNormalize(xsd)
        let validator = XMLSchemaValidator()
        // extra element "extra" not in the sequence — allowed by openContent
        let xml = Data("<root><id>1</id><extra>foo</extra></root>".utf8)
        let result = try validator.validate(data: xml, against: normalized)
        XCTAssertTrue(result.isValid, "Expected valid; errors: \(result.errors.map(\.message))")
    }

    func test_openContent_none_rejectsExtraElements() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="root" type="Closed"/>
          <xsd:complexType name="Closed">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
            <xsd:openContent mode="none"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let normalized = try parseAndNormalize(xsd)
        let validator = XMLSchemaValidator()
        let xml = Data("<root><id>1</id><extra>foo</extra></root>".utf8)
        let result = try validator.validate(data: xml, against: normalized)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.message.contains("extra") }))
    }

    // MARK: - xsd:defaultOpenContent (schema-level)

    func test_defaultOpenContent_parsedAtSchemaLevel() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:defaultOpenContent mode="append">
            <xsd:any processContents="skip"/>
          </xsd:defaultOpenContent>
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let schema = try XCTUnwrap(schemaSet.schemas.first)
        let doc = try XCTUnwrap(schema.defaultOpenContent)
        XCTAssertEqual(doc.mode, .append)
        XCTAssertNotNil(doc.any)
        XCTAssertEqual(doc.any?.processContents, .skip)
    }

    func test_defaultOpenContent_nilWhenAbsent() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        XCTAssertNil(schemaSet.schemas.first?.defaultOpenContent)
    }

    // MARK: - xsd:alternative (type alternatives)

    func test_alternative_parsedOnElement() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="shape">
            <xsd:alternative test="@kind='circle'" type="xsd:string"/>
            <xsd:alternative type="xsd:integer"/>
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="kind" type="xsd:string"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let element = try XCTUnwrap(schemaSet.schemas.first?.elements.first)
        XCTAssertEqual(element.typeAlternatives.count, 2)
        XCTAssertEqual(element.typeAlternatives[0].test, "@kind='circle'")
        XCTAssertEqual(element.typeAlternatives[0].typeQName?.localName, "string")
        XCTAssertNil(element.typeAlternatives[1].test)
        XCTAssertEqual(element.typeAlternatives[1].typeQName?.localName, "integer")
    }

    func test_alternative_noAlternatives_emptyArray() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:string"/>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let element = try XCTUnwrap(schemaSet.schemas.first?.elements.first)
        XCTAssertTrue(element.typeAlternatives.isEmpty)
    }

    // MARK: - XMLSchemaOpenContentMode enum

    func test_openContentMode_rawValues() {
        XCTAssertEqual(XMLSchemaOpenContentMode.none.rawValue, "none")
        XCTAssertEqual(XMLSchemaOpenContentMode.interleave.rawValue, "interleave")
        XCTAssertEqual(XMLSchemaOpenContentMode.append.rawValue, "append")
    }

    // MARK: - XMLSchemaAssertion model

    func test_assertion_model_properties() {
        let assertion = XMLSchemaAssertion(
            test: "x gt 0",
            xpathDefaultNamespace: "##local",
            annotation: nil
        )
        XCTAssertEqual(assertion.test, "x gt 0")
        XCTAssertEqual(assertion.xpathDefaultNamespace, "##local")
        XCTAssertNil(assertion.annotation)
    }

    // MARK: - XMLSchemaTypeAlternative model

    func test_typeAlternative_model_properties() {
        let alt = XMLSchemaTypeAlternative(
            test: "@type='A'",
            typeQName: XMLQualifiedName(localName: "TypeA", namespaceURI: nil as String?),
            annotation: nil
        )
        XCTAssertEqual(alt.test, "@type='A'")
        XCTAssertEqual(alt.typeQName?.localName, "TypeA")
    }

    // MARK: - XMLSchemaOpenContent model

    func test_openContent_model_defaults() {
        let oc = XMLSchemaOpenContent()
        XCTAssertEqual(oc.mode, .interleave)
        XCTAssertNil(oc.any)
        XCTAssertFalse(oc.appliesToEmpty)
        XCTAssertNil(oc.annotation)
    }

    func test_openContent_appliesToEmpty_flag() throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Foo">
            <xsd:openContent mode="interleave" appliesToEmpty="true">
              <xsd:any processContents="lax"/>
            </xsd:openContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let schemaSet = try parse(xsd)
        let complexType = try XCTUnwrap(schemaSet.schemas.first?.complexTypes.first)
        XCTAssertTrue(complexType.openContent?.appliesToEmpty ?? false)
    }
}
