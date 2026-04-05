import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaBroadCoverageTests: XCTestCase {
    func test_parseBroadSchema_extractsAllAttributeRefsWildcardsAndModelGroups() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:test" targetNamespace="urn:test">
          <xsd:attribute name="source" type="xsd:string"/>
          <xsd:group name="SharedFields">
            <xsd:sequence>
              <xsd:element name="firstName" type="xsd:string"/>
              <xsd:element name="lastName" type="xsd:string"/>
            </xsd:sequence>
          </xsd:group>
          <xsd:complexType name="Contact">
            <xsd:all>
              <xsd:element name="name" type="xsd:string"/>
              <xsd:element name="email" type="xsd:string" minOccurs="0"/>
            </xsd:all>
            <xsd:attribute ref="tns:source" use="required"/>
            <xsd:anyAttribute namespace="##other" processContents="lax"/>
          </xsd:complexType>
          <xsd:complexType name="Wrapper">
            <xsd:sequence>
              <xsd:group ref="tns:SharedFields"/>
              <xsd:any minOccurs="0" maxOccurs="unbounded" namespace="##other" processContents="skip"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let contact = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Contact" }))
        let wrapper = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Wrapper" }))

        XCTAssertEqual(schema.modelGroups.map(\.name), ["SharedFields"])
        XCTAssertEqual(contact.sequence.map(\.name), ["name", "email"])
        XCTAssertEqual(contact.attributeRefs.map(\.refQName.rawValue), ["tns:source"])
        XCTAssertEqual(contact.attributeRefs.first?.use, "required")
        XCTAssertEqual(contact.anyAttribute?.namespaceConstraint, "##other")
        XCTAssertEqual(contact.anyAttribute?.processContents, "lax")
        XCTAssertEqual(wrapper.groupReferences.map(\.refQName.rawValue), ["tns:SharedFields"])
        XCTAssertEqual(wrapper.anyElements.first?.namespaceConstraint, "##other")
        XCTAssertEqual(wrapper.anyElements.first?.processContents, "skip")
    }

    func test_parseInlineAnonymousTypesListUnionAndExclusiveFacets() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:test" targetNamespace="urn:test">
          <xsd:simpleType name="StrictPrice">
            <xsd:restriction base="xsd:decimal">
              <xsd:minExclusive value="0.00"/>
              <xsd:maxExclusive value="100.00"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:simpleType name="Codes">
            <xsd:list itemType="xsd:string"/>
          </xsd:simpleType>
          <xsd:simpleType name="Flexible">
            <xsd:union memberTypes="xsd:string tns:StrictPrice"/>
          </xsd:simpleType>
          <xsd:element name="order">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="status">
                  <xsd:simpleType>
                    <xsd:restriction base="xsd:string">
                      <xsd:enumeration value="draft"/>
                      <xsd:enumeration value="sent"/>
                    </xsd:restriction>
                  </xsd:simpleType>
                </xsd:element>
              </xsd:sequence>
              <xsd:attribute name="kind">
                <xsd:simpleType>
                  <xsd:restriction base="xsd:string">
                    <xsd:pattern value="[A-Z]+"/>
                  </xsd:restriction>
                </xsd:simpleType>
              </xsd:attribute>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let strictPrice = try XCTUnwrap(schema.simpleTypes.first(where: { $0.name == "StrictPrice" }))
        let codes = try XCTUnwrap(schema.simpleTypes.first(where: { $0.name == "Codes" }))
        let flexible = try XCTUnwrap(schema.simpleTypes.first(where: { $0.name == "Flexible" }))
        let order = try XCTUnwrap(schema.elements.first(where: { $0.name == "order" }))
        let orderComplexType = try XCTUnwrap(order.inlineComplexType)
        let status = try XCTUnwrap(orderComplexType.sequence.first)
        let kindAttribute = try XCTUnwrap(orderComplexType.attributes.first)

        XCTAssertEqual(strictPrice.facets?.minExclusive, "0.00")
        XCTAssertEqual(strictPrice.facets?.maxExclusive, "100.00")
        XCTAssertEqual(codes.derivationKind, .list)
        XCTAssertEqual(codes.listItemQName?.rawValue, "xsd:string")
        XCTAssertEqual(flexible.derivationKind, .union)
        XCTAssertEqual(flexible.unionMemberQNames.map(\.rawValue), ["xsd:string", "tns:StrictPrice"])
        XCTAssertNotNil(status.inlineSimpleType)
        XCTAssertEqual(status.inlineSimpleType?.enumerationValues, ["draft", "sent"])
        XCTAssertNotNil(kindAttribute.inlineSimpleType)
        XCTAssertEqual(kindAttribute.inlineSimpleType?.pattern, "[A-Z]+")
    }

    func test_parseUnknownPrefixInUnionMemberTypes_throwsDiagnostic() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:test">
          <xsd:simpleType name="BrokenUnion">
            <xsd:union memberTypes="missing:Value"/>
          </xsd:simpleType>
        </xsd:schema>
        """

        XCTAssertThrowsError(try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))) { error in
            guard case let XMLSchemaParsingError.invalidDocument(message, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message?.contains("Unknown namespace prefix") == true)
        }
    }
}
