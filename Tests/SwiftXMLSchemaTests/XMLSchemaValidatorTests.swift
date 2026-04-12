import Foundation
import Logging
import SwiftXMLSchema
import XCTest

final class XMLSchemaValidatorTests: XCTestCase {

    // MARK: - Helpers

    private func schemaSet(xsd: String) throws -> XMLNormalizedSchemaSet {
        let schema = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schema)
    }

    private func validate(xml: String, xsd: String) throws -> XMLSchemaValidationResult {
        let set = try schemaSet(xsd: xsd)
        return try XMLSchemaValidator().validate(data: Data(xml.utf8), against: set)
    }

    // MARK: - Root element

    func test_validate_undeclaredRootElement_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:v"/>
        """
        let xml = """
        <?xml version="1.0"?><Unknown/>
        """
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("not declared") })
    }

    func test_validate_declaredRootElement_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:v">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let xml = "<root>hello</root>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - isValid / isEmpty helpers

    func test_validationResult_isValid_whenNoDiagnostics() {
        let result = XMLSchemaValidationResult(diagnostics: [])
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func test_validationResult_isValid_withOnlyWarnings() {
        let warning = XMLSchemaValidationDiagnostic(severity: .warning, path: "/x", message: "w")
        let result = XMLSchemaValidationResult(diagnostics: [warning])
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func test_validationResult_isInvalid_withError() {
        let err = XMLSchemaValidationDiagnostic(severity: .error, path: "/x", message: "e")
        let result = XMLSchemaValidationResult(diagnostics: [err])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
    }

    // MARK: - Sequence content model

    func test_validate_requiredChildMissing_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="id" type="xsd:string"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Order></Order>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("id") && $0.message.contains("at least 1") })
    }

    func test_validate_requiredChildPresent_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="id" type="xsd:string"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Order><id>123</id></Order>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_optionalChildMissing_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="note" type="xsd:string" minOccurs="0"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Order></Order>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_undeclaredChildElement_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="id" type="xsd:string"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Order><id>1</id><extra/></Order>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("extra") && $0.message.contains("not declared") })
    }

    func test_validate_maxOccursExceeded_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="List">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="item" type="xsd:string" maxOccurs="2"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<List><item>a</item><item>b</item><item>c</item></List>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("at most 2") })
    }

    func test_validate_unboundedChildren_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="List">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="item" type="xsd:string" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<List><item>a</item><item>b</item><item>c</item></List>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_wildcardContent_allowsAnyChild() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Open">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Open><anything/><else/></Open>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Attributes

    func test_validate_requiredAttributeMissing_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Item">
            <xsd:complexType>
              <xsd:sequence/>
              <xsd:attribute name="id" type="xsd:string" use="required"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Item/>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("Required attribute 'id'") })
    }

    func test_validate_requiredAttributePresent_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Item">
            <xsd:complexType>
              <xsd:sequence/>
              <xsd:attribute name="id" type="xsd:string" use="required"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Item id=\"abc\"/>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_unknownAttribute_producesWarning() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Item">
            <xsd:complexType>
              <xsd:sequence/>
              <xsd:attribute name="id" type="xsd:string"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Item id=\"1\" unknown=\"x\"/>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid) // warning, not error
        XCTAssertTrue(result.warnings.contains { $0.message.contains("unknown") })
    }

    func test_validate_anyAttribute_allowsExtraAttrs() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Open">
            <xsd:complexType>
              <xsd:sequence/>
              <xsd:anyAttribute namespace="##any" processContents="lax"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Open custom=\"x\" other=\"y\"/>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Simple type enumeration

    func test_validate_enumerationValue_valid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Status">
            <xsd:simpleType>
              <xsd:restriction base="xsd:string">
                <xsd:enumeration value="open"/>
                <xsd:enumeration value="closed"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Status>open</Status>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_enumerationValue_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Status">
            <xsd:simpleType>
              <xsd:restriction base="xsd:string">
                <xsd:enumeration value="open"/>
                <xsd:enumeration value="closed"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Status>invalid</Status>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("invalid") && $0.message.contains("enumeration") })
    }

    // MARK: - Facet validation

    func test_validate_facet_minLength_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Code">
            <xsd:simpleType>
              <xsd:restriction base="xsd:string">
                <xsd:minLength value="3"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Code>AB</Code>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("minLength") })
    }

    func test_validate_facet_maxLength_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Code">
            <xsd:simpleType>
              <xsd:restriction base="xsd:string">
                <xsd:maxLength value="5"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Code>ABCDEFG</Code>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("maxLength") })
    }

    // MARK: - Built-in type validation

    func test_validate_builtinInteger_valid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="qty" type="xsd:integer"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<qty>42</qty>", xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_builtinInteger_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="qty" type="xsd:integer"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<qty>not-a-number</qty>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinBoolean_valid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="flag" type="xsd:boolean"/>
        </xsd:schema>
        """
        XCTAssertTrue(try validate(xml: "<flag>true</flag>", xsd: xsd).isValid)
        XCTAssertTrue(try validate(xml: "<flag>false</flag>", xsd: xsd).isValid)
        XCTAssertTrue(try validate(xml: "<flag>1</flag>", xsd: xsd).isValid)
        XCTAssertTrue(try validate(xml: "<flag>0</flag>", xsd: xsd).isValid)
    }

    func test_validate_builtinBoolean_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="flag" type="xsd:boolean"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<flag>yes</flag>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("boolean") })
    }

    func test_validate_builtinDate_valid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="dob" type="xsd:date"/>
        </xsd:schema>
        """
        XCTAssertTrue(try validate(xml: "<dob>2024-01-15</dob>", xsd: xsd).isValid)
    }

    func test_validate_builtinDate_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="dob" type="xsd:date"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<dob>not-a-date</dob>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Attribute type validation

    func test_validate_attributeWithBuiltinIntType_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Item">
            <xsd:complexType>
              <xsd:sequence/>
              <xsd:attribute name="count" type="xsd:integer" use="required"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Item count=\"not-an-int\"/>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("integer") || $0.message.contains("not a valid") })
    }

    // MARK: - Simple content

    func test_validate_simpleContent_withValidValue_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Amount">
            <xsd:complexType>
              <xsd:simpleContent>
                <xsd:extension base="xsd:decimal">
                  <xsd:attribute name="currency" type="xsd:string" use="required"/>
                </xsd:extension>
              </xsd:simpleContent>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Amount currency=\"USD\">19.99</Amount>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_simpleContent_invalidNumericValue_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Amount">
            <xsd:complexType>
              <xsd:simpleContent>
                <xsd:extension base="xsd:decimal">
                  <xsd:attribute name="currency" type="xsd:string" use="required"/>
                </xsd:extension>
              </xsd:simpleContent>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Amount currency=\"USD\">not-a-number</Amount>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Logger autoclosures at trace level

    func test_validate_traceLogger_exercisesAllAutoclosures() throws {
        var logger = Logger(label: "test.validator")
        logger.logLevel = .trace
        let validator = XMLSchemaValidator(logger: logger)

        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="id" type="xsd:string"/>
                <xsd:element name="qty" type="xsd:integer"/>
              </xsd:sequence>
              <xsd:attribute name="status" type="xsd:string" use="required"/>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<order status=\"ok\"><id>1</id><qty>5</qty></order>"
        let schema = try schemaSet(xsd: xsd)
        let result = try validator.validate(data: Data(xml.utf8), against: schema)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Fixed value constraint

    func test_validate_fixedValue_mismatch_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Msg">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="version" type="xsd:string" fixed="1.0"/>
              </xsd:sequence>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Msg><version>2.0</version></Msg>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("fixed") })
    }

    // MARK: - Choice group content

    func test_validate_choiceGroup_oneBranchPresent_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Payment">
            <xsd:complexType>
              <xsd:choice>
                <xsd:element name="creditCard" type="xsd:string"/>
                <xsd:element name="bankTransfer" type="xsd:string"/>
              </xsd:choice>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Payment><creditCard>VISA</creditCard></Payment>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertTrue(result.isValid)
    }

    func test_validate_choiceGroup_noBranchPresent_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Payment">
            <xsd:complexType>
              <xsd:choice>
                <xsd:element name="creditCard" type="xsd:string"/>
                <xsd:element name="bankTransfer" type="xsd:string"/>
              </xsd:choice>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """
        let xml = "<Payment></Payment>"
        let result = try validate(xml: xml, xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("Choice group") })
    }

    // MARK: - Element with no type (anonymous, no typeQName)

    func test_validate_elementWithNoType_doesNotCrash() throws {
        // An element declared without a type attribute — no explicit typeQName
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="anything"/>
        </xsd:schema>
        """
        let xml = "<anything>hello</anything>"
        let result = try validate(xml: xml, xsd: xsd)
        // No crash and no spurious errors for untyped elements
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Facets: exact length, max/min exclusive, totalDigits

    func test_validate_facet_exactLength_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Pin">
            <xsd:simpleType>
              <xsd:restriction base="xsd:string">
                <xsd:length value="4"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Pin>12345</Pin>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("length") && $0.message.contains("4") })
    }

    func test_validate_facet_maxInclusive_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Score">
            <xsd:simpleType>
              <xsd:restriction base="xsd:integer">
                <xsd:maxInclusive value="100"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Score>150</Score>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("maxInclusive") })
    }

    func test_validate_facet_minExclusive_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Temp">
            <xsd:simpleType>
              <xsd:restriction base="xsd:decimal">
                <xsd:minExclusive value="0"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Temp>0</Temp>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("minExclusive") })
    }

    func test_validate_facet_maxExclusive_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Prob">
            <xsd:simpleType>
              <xsd:restriction base="xsd:decimal">
                <xsd:maxExclusive value="1"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Prob>1</Prob>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("maxExclusive") })
    }

    func test_validate_facet_totalDigits_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Code">
            <xsd:simpleType>
              <xsd:restriction base="xsd:integer">
                <xsd:totalDigits value="3"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Code>12345</Code>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("totalDigits") || $0.message.contains("digit") })
    }

    // MARK: - Built-in integer range types

    func test_validate_builtinNonNegativeInteger_negative_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="qty" type="xsd:nonNegativeInteger"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<qty>-5</qty>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinPositiveInteger_zero_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="count" type="xsd:positiveInteger"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<count>0</count>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinNonPositiveInteger_positive_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:nonPositiveInteger"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<val>1</val>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinNegativeInteger_zero_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:negativeInteger"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<val>0</val>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinByte_outOfRange_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:byte"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<val>1000</val>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinShort_outOfRange_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:short"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<val>99999</val>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinInt_outOfRange_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="val" type="xsd:int"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<val>9999999999</val>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - dateTime and anyURI

    func test_validate_builtinDateTime_valid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="ts" type="xsd:dateTime"/>
        </xsd:schema>
        """
        XCTAssertTrue(try validate(xml: "<ts>2024-01-15T10:30:00</ts>", xsd: xsd).isValid)
    }

    func test_validate_builtinDateTime_invalid_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="ts" type="xsd:dateTime"/>
        </xsd:schema>
        """
        let result = try validate(xml: "<ts>not-a-datetime</ts>", xsd: xsd)
        XCTAssertFalse(result.isValid)
    }

    func test_validate_builtinAnyURI_doesNotError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="uri" type="xsd:anyURI"/>
        </xsd:schema>
        """
        XCTAssertTrue(try validate(xml: "<uri>https://example.com</uri>", xsd: xsd).isValid)
    }

    // MARK: - Numeric range facets

    func test_validate_minInclusive_violated_producesError() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Age">
            <xsd:simpleType>
              <xsd:restriction base="xsd:integer">
                <xsd:minInclusive value="0"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        let result = try validate(xml: "<Age>-1</Age>", xsd: xsd)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.message.contains("minInclusive") })
    }

    func test_validate_maxInclusive_ok_isValid() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:element name="Score">
            <xsd:simpleType>
              <xsd:restriction base="xsd:integer">
                <xsd:minInclusive value="0"/>
                <xsd:maxInclusive value="100"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:element>
        </xsd:schema>
        """
        XCTAssertTrue(try validate(xml: "<Score>50</Score>", xsd: xsd).isValid)
    }
}
