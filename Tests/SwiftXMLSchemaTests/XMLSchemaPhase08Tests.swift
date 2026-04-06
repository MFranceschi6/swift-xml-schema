import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaPhase08Tests: XCTestCase {

    // MARK: - Helpers

    private func normalizedSchemaSet(from xsd: String) throws -> XMLNormalizedSchemaSet {
        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    private func exportedJSON(from xsd: String) throws -> [String: Any] {
        let normalized = try normalizedSchemaSet(from: xsd)
        let doc = XMLJSONSchemaExporter().export(normalized)
        let data = try JSONEncoder().encode(doc)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Top-level structure

    func test_export_hasJsonSchemaField() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:test"/>
        """
        let json = try exportedJSON(from: xsd)
        XCTAssertEqual(json["$schema"] as? String, "https://json-schema.org/draft/2020-12/schema")
    }

    func test_export_titleIsTargetNamespace() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:orders"/>
        """
        let json = try exportedJSON(from: xsd)
        XCTAssertEqual(json["title"] as? String, "urn:orders")
    }

    func test_export_emptySchema_noProperties() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:empty"/>
        """
        let json = try exportedJSON(from: xsd)
        XCTAssertNil(json["properties"])
    }

    // MARK: - Complex type → $defs object

    func test_export_complexType_appearsInDefs() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        XCTAssertNotNil(defs["Order"])
    }

    func test_export_complexType_isTypeObject() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Person">
            <xsd:sequence>
              <xsd:element name="name" type="xsd:string"/>
              <xsd:element name="age" type="xsd:integer"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let personDef = try XCTUnwrap(defs["Person"] as? [String: Any])
        XCTAssertEqual(personDef["type"] as? String, "object")
        let properties = try XCTUnwrap(personDef["properties"] as? [String: Any])
        XCTAssertNotNil(properties["name"])
        XCTAssertNotNil(properties["age"])
    }

    func test_export_complexType_requiredFields() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:req">
          <xsd:complexType name="Item">
            <xsd:sequence>
              <xsd:element name="required" type="xsd:string" minOccurs="1"/>
              <xsd:element name="optional" type="xsd:string" minOccurs="0"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let itemDef = try XCTUnwrap(defs["Item"] as? [String: Any])
        let required = try XCTUnwrap(itemDef["required"] as? [String])
        XCTAssertTrue(required.contains("required"))
        XCTAssertFalse(required.contains("optional"))
    }

    func test_export_complexType_requiredAttribute() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:attr">
          <xsd:complexType name="Priced">
            <xsd:sequence/>
            <xsd:attribute name="currency" type="xsd:string" use="required"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["Priced"] as? [String: Any])
        let required = try XCTUnwrap(def["required"] as? [String])
        XCTAssertTrue(required.contains("currency"))
    }

    // MARK: - Simple type → $defs

    func test_export_simpleType_enumeration() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:st">
          <xsd:simpleType name="Status">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
              <xsd:enumeration value="inactive"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let statusDef = try XCTUnwrap(defs["Status"] as? [String: Any])
        let enumValues = try XCTUnwrap(statusDef["enum"] as? [String])
        XCTAssertEqual(enumValues.sorted(), ["active", "inactive"])
    }

    func test_export_simpleType_listBecomesArray() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:list">
          <xsd:simpleType name="IntList">
            <xsd:list itemType="xsd:integer"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let listDef = try XCTUnwrap(defs["IntList"] as? [String: Any])
        XCTAssertEqual(listDef["type"] as? String, "array")
        let items = try XCTUnwrap(listDef["items"] as? [String: Any])
        XCTAssertEqual(items["type"] as? String, "integer")
    }

    // MARK: - XSD built-in type mapping

    func test_export_builtIn_string() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:bi">
          <xsd:complexType name="T">
            <xsd:sequence>
              <xsd:element name="s" type="xsd:string"/>
              <xsd:element name="n" type="xsd:integer"/>
              <xsd:element name="b" type="xsd:boolean"/>
              <xsd:element name="d" type="xsd:decimal"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["T"] as? [String: Any])
        let props = try XCTUnwrap(def["properties"] as? [String: Any])
        XCTAssertEqual((props["s"] as? [String: Any])?["type"] as? String, "string")
        XCTAssertEqual((props["n"] as? [String: Any])?["type"] as? String, "integer")
        XCTAssertEqual((props["b"] as? [String: Any])?["type"] as? String, "boolean")
        XCTAssertEqual((props["d"] as? [String: Any])?["type"] as? String, "number")
    }

    func test_export_builtIn_dateFormats() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:dates">
          <xsd:complexType name="Dates">
            <xsd:sequence>
              <xsd:element name="d" type="xsd:date"/>
              <xsd:element name="dt" type="xsd:dateTime"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["Dates"] as? [String: Any])
        let props = try XCTUnwrap(def["properties"] as? [String: Any])
        XCTAssertEqual((props["d"] as? [String: Any])?["format"] as? String, "date")
        XCTAssertEqual((props["dt"] as? [String: Any])?["format"] as? String, "date-time")
    }

    // MARK: - Occurrence bounds

    func test_export_unboundedOccurrence_isArray() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:occ">
          <xsd:complexType name="Container">
            <xsd:sequence>
              <xsd:element name="items" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["Container"] as? [String: Any])
        let props = try XCTUnwrap(def["properties"] as? [String: Any])
        let itemsProp = try XCTUnwrap(props["items"] as? [String: Any])
        XCTAssertEqual(itemsProp["type"] as? String, "array")
        XCTAssertNil(itemsProp["maxItems"])
    }

    func test_export_boundedOccurrence_hasMinsAndMaxs() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:occ2">
          <xsd:complexType name="Multi">
            <xsd:sequence>
              <xsd:element name="items" type="xsd:string" minOccurs="2" maxOccurs="5"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["Multi"] as? [String: Any])
        let props = try XCTUnwrap(def["properties"] as? [String: Any])
        let itemsProp = try XCTUnwrap(props["items"] as? [String: Any])
        XCTAssertEqual(itemsProp["type"] as? String, "array")
        XCTAssertEqual(itemsProp["minItems"] as? Int, 2)
        XCTAssertEqual(itemsProp["maxItems"] as? Int, 5)
    }

    // MARK: - $ref for non-built-in types

    func test_export_typeRef_generatesRef() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:tns="urn:ref" targetNamespace="urn:ref">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="address" type="tns:Address"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Address">
            <xsd:sequence>
              <xsd:element name="city" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let orderDef = try XCTUnwrap(defs["Order"] as? [String: Any])
        let props = try XCTUnwrap(orderDef["properties"] as? [String: Any])
        let addressProp = try XCTUnwrap(props["address"] as? [String: Any])
        XCTAssertEqual(addressProp["$ref"] as? String, "#/$defs/Address")
    }

    // MARK: - Top-level elements → root properties

    func test_export_topLevelElement_appearsInProperties() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:el">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let properties = try XCTUnwrap(json["properties"] as? [String: Any])
        XCTAssertNotNil(properties["root"])
        XCTAssertEqual(json["type"] as? String, "object")
    }

    // MARK: - Wildcards → additionalProperties

    func test_export_wildcard_setsAdditionalProperties() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:wc">
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let openDef = try XCTUnwrap(defs["Open"] as? [String: Any])
        let additional = openDef["additionalProperties"]
        XCTAssertEqual(additional as? Bool, true)
    }

    // MARK: - Inheritance (allOf)

    func test_export_extension_usesAllOf() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:tns="urn:inh" targetNamespace="urn:inh">
          <xsd:complexType name="Base">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Extended">
            <xsd:complexContent>
              <xsd:extension base="tns:Base">
                <xsd:sequence>
                  <xsd:element name="extra" type="xsd:string"/>
                </xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let extDef = try XCTUnwrap(defs["Extended"] as? [String: Any])
        let allOf = try XCTUnwrap(extDef["allOf"] as? [[String: Any]])
        XCTAssertFalse(allOf.isEmpty)
        // First element should be the $ref to Base
        XCTAssertEqual(allOf.first?["$ref"] as? String, "#/$defs/Base")
    }

    // MARK: - Annotation → description

    func test_export_annotation_becomesDescription() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ann">
          <xsd:complexType name="Documented">
            <xsd:annotation>
              <xsd:documentation>A documented type.</xsd:documentation>
            </xsd:annotation>
            <xsd:sequence>
              <xsd:element name="value" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let def = try XCTUnwrap(defs["Documented"] as? [String: Any])
        XCTAssertEqual(def["description"] as? String, "A documented type.")
    }

    // MARK: - Facets

    func test_export_facets_minMaxLength() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:fac">
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string">
              <xsd:minLength value="2"/>
              <xsd:maxLength value="10"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let json = try exportedJSON(from: xsd)
        let defs = try XCTUnwrap(json["$defs"] as? [String: Any])
        let codeDef = try XCTUnwrap(defs["Code"] as? [String: Any])
        XCTAssertEqual(codeDef["minLength"] as? Int, 2)
        XCTAssertEqual(codeDef["maxLength"] as? Int, 10)
    }

    // MARK: - Custom title parameter

    func test_export_customTitle() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let normalized = try normalizedSchemaSet(from: xsd)
        let doc = XMLJSONSchemaExporter().export(normalized, title: "My API Schema")
        let data = try JSONEncoder().encode(doc)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "My API Schema")
    }
}
