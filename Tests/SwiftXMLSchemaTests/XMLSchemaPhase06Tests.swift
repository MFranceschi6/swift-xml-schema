import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaPhase06Tests: XCTestCase {

    // MARK: - Helpers

    private func normalizedSchemaSet(from xsd: String) throws -> XMLNormalizedSchemaSet {
        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    // MARK: - JSON round-trip

    func test_codable_roundTrip_emptySchemaSet() throws {
        let normalized = XMLNormalizedSchemaSet(schemas: [])
        let data = try JSONEncoder().encode(normalized)
        let decoded = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: data)
        XCTAssertEqual(decoded.schemas.count, 0)
    }

    func test_codable_roundTrip_complexSchema() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:rt">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="amount" type="xsd:decimal"/>
            </xsd:sequence>
            <xsd:attribute name="status" type="xsd:string" use="required"/>
          </xsd:complexType>
          <xsd:simpleType name="Currency">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="EUR"/>
              <xsd:enumeration value="USD"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let encoded = try JSONEncoder().encode(normalized)
        let decoded = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: encoded)

        XCTAssertEqual(normalized, decoded)
        XCTAssertNotNil(decoded.complexType(named: "Order", namespaceURI: "urn:rt"))
        XCTAssertNotNil(decoded.simpleType(named: "Currency", namespaceURI: "urn:rt"))
        XCTAssertNotNil(decoded.element(named: "root", namespaceURI: "urn:rt"))
    }

    func test_codable_roundTrip_choiceGroup() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ch">
          <xsd:complexType name="Container">
            <xsd:choice>
              <xsd:element name="a" type="xsd:string"/>
              <xsd:element name="b" type="xsd:string"/>
            </xsd:choice>
          </xsd:complexType>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let encoded = try JSONEncoder().encode(normalized)
        let decoded = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: encoded)
        let container = try XCTUnwrap(decoded.complexType(named: "Container", namespaceURI: "urn:ch"))
        XCTAssertFalse(container.effectiveChoiceGroups.isEmpty)
    }

    func test_codable_roundTrip_wildcard() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:wc">
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let encoded = try JSONEncoder().encode(normalized)
        let decoded = try JSONDecoder().decode(XMLNormalizedSchemaSet.self, from: encoded)
        let open = try XCTUnwrap(decoded.complexType(named: "Open", namespaceURI: "urn:wc"))
        XCTAssertFalse(open.effectiveAnyElements.isEmpty)
    }

    // MARK: - JSON structure (schemaVersion, kind discriminator)

    func test_encodedJSON_hasSchemaVersion1() throws {
        let normalized = XMLNormalizedSchemaSet(schemas: [])
        let data = try JSONEncoder().encode(normalized)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schemaVersion"] as? Int, 1)
    }

    func test_encodedJSON_contentNode_hasKindAndValueFields() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:kv">
          <xsd:complexType name="T">
            <xsd:sequence>
              <xsd:element name="x" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(normalized)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schemas = try XCTUnwrap(json["schemas"] as? [[String: Any]])
        let complexTypes = try XCTUnwrap(schemas.first?["complexTypes"] as? [[String: Any]])
        let contentNode = try XCTUnwrap(
            (complexTypes.first?["effectiveContent"] as? [[String: Any]])?.first
        )
        XCTAssertEqual(contentNode["kind"] as? String, "element")
        XCTAssertNotNil(contentNode["value"])
    }

    func test_encodedJSON_qname_isStructuredObject() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:qn">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let data = try JSONEncoder().encode(normalized)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schemas = try XCTUnwrap(json["schemas"] as? [[String: Any]])
        let elements = try XCTUnwrap(schemas.first?["elements"] as? [[String: Any]])
        let typeQName = try XCTUnwrap(elements.first?["typeQName"] as? [String: Any])
        XCTAssertEqual(typeQName["localName"] as? String, "string")
        XCTAssertEqual(typeQName["namespaceURI"] as? String, "http://www.w3.org/2001/XMLSchema")
    }

    func test_encodedJSON_unboundedMaxOccurs_isNull() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ub">
          <xsd:complexType name="List">
            <xsd:sequence>
              <xsd:element name="item" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let normalized = try normalizedSchemaSet(from: xsd)
        let data = try JSONEncoder().encode(normalized)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schemas = try XCTUnwrap(json["schemas"] as? [[String: Any]])
        let complexTypes = try XCTUnwrap(schemas.first?["complexTypes"] as? [[String: Any]])
        let contentNode = try XCTUnwrap(
            (complexTypes.first?["effectiveContent"] as? [[String: Any]])?.first
        )
        let value = try XCTUnwrap(contentNode["value"] as? [String: Any])
        let occurrenceBounds = try XCTUnwrap(value["occurrenceBounds"] as? [String: Any])
        // JSONEncoder omits nil Optional keys: maxOccurs absent means unbounded
        XCTAssertNil(occurrenceBounds["maxOccurs"])
        XCTAssertEqual(occurrenceBounds["minOccurs"] as? Int, 0)
    }

    // MARK: - Fingerprinting

    #if canImport(CryptoKit)
    func test_fingerprint_isDeterministic() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:fp">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let normalized = try normalizedSchemaSet(from: xsd)
        XCTAssertEqual(normalized.fingerprint, normalized.fingerprint)
        XCTAssertEqual(normalized.fingerprint.count, 64)
    }

    func test_fingerprint_changesOnSchemaChange() throws {
        let xsd1 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:fp">
          <xsd:element name="a" type="xsd:string"/>
        </xsd:schema>
        """
        let xsd2 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:fp">
          <xsd:element name="b" type="xsd:string"/>
        </xsd:schema>
        """
        let n1 = try normalizedSchemaSet(from: xsd1)
        let n2 = try normalizedSchemaSet(from: xsd2)
        XCTAssertNotEqual(n1.fingerprint, n2.fingerprint)
    }

    func test_fingerprint_emptySchemaSetIsNotEmpty() {
        let normalized = XMLNormalizedSchemaSet(schemas: [])
        XCTAssertFalse(normalized.fingerprint.isEmpty)
        XCTAssertEqual(normalized.fingerprint.count, 64)
    }
    #endif

    // MARK: - currentSchemaVersion constant

    func test_currentSchemaVersion_is1() {
        XCTAssertEqual(XMLNormalizedSchemaSet.currentSchemaVersion, 1)
    }
}
