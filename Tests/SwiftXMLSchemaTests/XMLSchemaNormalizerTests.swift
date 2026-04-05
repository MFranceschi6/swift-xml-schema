import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaNormalizerTests: XCTestCase {
    func test_normalizer_expandsModelGroupsAttributeGroupsAndWildcards() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:test" targetNamespace="urn:test">
          <xsd:attribute name="locale" type="xsd:string"/>
          <xsd:attributeGroup name="BaseMetadata">
            <xsd:attribute name="source" type="xsd:string" use="required"/>
          </xsd:attributeGroup>
          <xsd:attributeGroup name="ExtendedMetadata">
            <xsd:attributeGroup ref="tns:BaseMetadata"/>
            <xsd:attribute ref="tns:locale"/>
          </xsd:attributeGroup>
          <xsd:group name="OrderFields">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:choice minOccurs="0">
                <xsd:element name="couponCode" type="xsd:string"/>
                <xsd:element name="voucherCode" type="xsd:string"/>
              </xsd:choice>
              <xsd:any minOccurs="0" maxOccurs="unbounded" namespace="##other" processContents="lax"/>
            </xsd:sequence>
          </xsd:group>
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:group ref="tns:OrderFields"/>
            </xsd:sequence>
            <xsd:attributeGroup ref="tns:ExtendedMetadata"/>
          </xsd:complexType>
          <xsd:element name="order" type="tns:Order"/>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let order = try XCTUnwrap(normalized.complexType(named: "Order", namespaceURI: "urn:test"))
        let orderFields = try XCTUnwrap(normalized.modelGroup(named: "OrderFields", namespaceURI: "urn:test"))
        let extendedMetadata = try XCTUnwrap(normalized.attributeGroup(named: "ExtendedMetadata", namespaceURI: "urn:test"))

        XCTAssertEqual(orderFields.sequence.map(\.name), ["id"])
        XCTAssertEqual(orderFields.choiceGroups.first?.elements.map(\.name), ["couponCode", "voucherCode"])
        XCTAssertEqual(orderFields.anyElements.first?.namespaceConstraint, "##other")

        XCTAssertEqual(order.effectiveSequence.map(\.name), ["id"])
        XCTAssertEqual(order.effectiveChoiceGroups.first?.elements.map(\.name), ["couponCode", "voucherCode"])
        XCTAssertEqual(order.effectiveAnyElements.first?.processContents, "lax")
        XCTAssertEqual(order.effectiveAttributes.map(\.name).sorted(), ["locale", "source"])
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: order.effectiveAttributes.map { ($0.name, $0.use) })["source"],
            "required"
        )
        XCTAssertEqual(extendedMetadata.attributes.map(\.name).sorted(), ["locale", "source"])
        XCTAssertEqual(normalized.rootElementBinding(forTypeNamed: "Order", namespaceURI: "urn:test")?.name, "order")
    }

    func test_normalizer_synthesizesStableAnonymousTypeBindings() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:test">
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

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let orderElement = try XCTUnwrap(normalized.element(named: "order", namespaceURI: "urn:test"))
        let orderTypeQName = try XCTUnwrap(orderElement.typeQName)
        let orderType = try XCTUnwrap(
            normalized.complexType(named: orderTypeQName.localName, namespaceURI: orderTypeQName.namespaceURI)
        )
        let statusTypeQName = try XCTUnwrap(orderType.effectiveSequence.first?.typeQName)
        let statusType = try XCTUnwrap(
            normalized.simpleType(named: statusTypeQName.localName, namespaceURI: statusTypeQName.namespaceURI)
        )
        let kindAttributeTypeQName = try XCTUnwrap(orderType.effectiveAttributes.first?.typeQName)
        let kindAttributeType = try XCTUnwrap(
            normalized.simpleType(named: kindAttributeTypeQName.localName, namespaceURI: kindAttributeTypeQName.namespaceURI)
        )

        XCTAssertNotEqual(orderType.name, "order")
        XCTAssertNotEqual(orderType.componentID, statusType.componentID)
        XCTAssertEqual(statusType.enumerationValues, ["draft", "sent"])
        XCTAssertEqual(kindAttributeType.pattern, "[A-Z]+")
    }

    func test_normalizer_reportsCyclicModelGroupReferences() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:test" targetNamespace="urn:test">
          <xsd:group name="A">
            <xsd:sequence>
              <xsd:group ref="tns:B"/>
            </xsd:sequence>
          </xsd:group>
          <xsd:group name="B">
            <xsd:sequence>
              <xsd:group ref="tns:A"/>
            </xsd:sequence>
          </xsd:group>
          <xsd:complexType name="Wrapper">
            <xsd:sequence>
              <xsd:group ref="tns:A"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))

        XCTAssertThrowsError(try XMLSchemaNormalizer().normalize(schemaSet)) { error in
            guard case let XMLSchemaParsingError.other(message, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(message?.contains("Cyclic group reference") == true)
        }
    }

    func test_normalizer_supportsRestrictionsAndMetadataPropagation() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:test" targetNamespace="urn:test">
          <xsd:attribute name="shared" type="xsd:string" default="en">
            <xsd:annotation>
              <xsd:documentation>Shared docs</xsd:documentation>
            </xsd:annotation>
          </xsd:attribute>
          <xsd:complexType name="BaseOrder">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="note" type="xsd:string" minOccurs="0"/>
            </xsd:sequence>
            <xsd:attribute name="status" type="xsd:string"/>
            <xsd:attribute name="legacy" type="xsd:string"/>
            <xsd:attribute ref="tns:shared"/>
          </xsd:complexType>
          <xsd:complexType name="RestrictedOrder">
            <xsd:annotation>
              <xsd:documentation>Restricted order docs</xsd:documentation>
            </xsd:annotation>
            <xsd:complexContent>
              <xsd:restriction base="tns:BaseOrder">
                <xsd:sequence>
                  <xsd:element name="id" type="xsd:string"/>
                </xsd:sequence>
                <xsd:attribute name="status" type="xsd:string" use="required"/>
                <xsd:attribute name="legacy" type="xsd:string" use="prohibited"/>
              </xsd:restriction>
            </xsd:complexContent>
          </xsd:complexType>
          <xsd:complexType name="Amount">
            <xsd:simpleContent>
              <xsd:extension base="xsd:decimal">
                <xsd:attribute name="currency" type="xsd:string" use="required"/>
                <xsd:attribute name="unit" type="xsd:string"/>
              </xsd:extension>
            </xsd:simpleContent>
          </xsd:complexType>
          <xsd:complexType name="RestrictedAmount">
            <xsd:simpleContent>
              <xsd:restriction base="tns:Amount">
                <xsd:attribute name="currency" type="xsd:string" use="required"/>
                <xsd:attribute name="unit" type="xsd:string" use="prohibited"/>
                <xsd:attribute name="scale" type="xsd:int"/>
              </xsd:restriction>
            </xsd:simpleContent>
          </xsd:complexType>
          <xsd:complexType name="DirectCode">
            <xsd:simpleContent>
              <xsd:restriction base="xsd:string">
                <xsd:attribute name="scheme" type="xsd:string" default="internal"/>
              </xsd:restriction>
            </xsd:simpleContent>
          </xsd:complexType>
          <xsd:element name="animal" type="xsd:string" abstract="true">
            <xsd:annotation>
              <xsd:documentation>Animal docs</xsd:documentation>
            </xsd:annotation>
          </xsd:element>
          <xsd:element name="dog" type="xsd:string" substitutionGroup="tns:animal" fixed="DOG">
            <xsd:annotation>
              <xsd:documentation>Dog docs</xsd:documentation>
            </xsd:annotation>
          </xsd:element>
          <xsd:complexType name="Zoo">
            <xsd:sequence>
              <xsd:element ref="tns:dog" minOccurs="0"/>
            </xsd:sequence>
            <xsd:attribute ref="tns:shared"/>
          </xsd:complexType>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let restrictedOrder = try XCTUnwrap(normalized.complexType(named: "RestrictedOrder", namespaceURI: "urn:test"))
        let restrictedAmount = try XCTUnwrap(normalized.complexType(named: "RestrictedAmount", namespaceURI: "urn:test"))
        let directCode = try XCTUnwrap(normalized.complexType(named: "DirectCode", namespaceURI: "urn:test"))
        let zoo = try XCTUnwrap(normalized.complexType(named: "Zoo", namespaceURI: "urn:test"))
        let dog = try XCTUnwrap(normalized.element(named: "dog", namespaceURI: "urn:test"))
        let animal = try XCTUnwrap(normalized.element(named: "animal", namespaceURI: "urn:test"))
        let zooDog = try XCTUnwrap(zoo.effectiveSequence.first)
        let sharedAttribute = try XCTUnwrap(zoo.effectiveAttributes.first(where: { $0.name == "shared" }))

        XCTAssertEqual(restrictedOrder.annotation?.documentation, ["Restricted order docs"])
        XCTAssertEqual(restrictedOrder.effectiveSequence.map(\.name), ["id"])
        XCTAssertEqual(
            Set(restrictedOrder.effectiveAttributes.map(\.name)),
            Set(["shared", "status"])
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: restrictedOrder.effectiveAttributes.map { ($0.name, $0.use) })["status"],
            "required"
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: restrictedOrder.effectiveAttributes.map { ($0.name, $0.defaultValue) })["shared"],
            "en"
        )

        XCTAssertEqual(restrictedAmount.effectiveSimpleContentValueTypeQName?.rawValue, "xsd:decimal")
        XCTAssertEqual(Set(restrictedAmount.effectiveAttributes.map(\.name)), Set(["currency", "scale"]))
        XCTAssertEqual(directCode.effectiveSimpleContentValueTypeQName?.rawValue, "xsd:string")
        XCTAssertEqual(directCode.effectiveAttributes.first?.defaultValue, "internal")

        XCTAssertTrue(animal.isAbstract)
        XCTAssertEqual(dog.annotation?.documentation, ["Dog docs"])
        XCTAssertEqual(dog.substitutionGroup?.rawValue, "tns:animal")
        XCTAssertEqual(normalized.substitutionGroupMembers(ofLocalName: "animal", namespaceURI: "urn:test").map(\.name), ["dog"])

        XCTAssertEqual(zooDog.name, "dog")
        XCTAssertEqual(zooDog.fixedValue, "DOG")
        XCTAssertEqual(zooDog.annotation?.documentation, ["Dog docs"])
        XCTAssertEqual(zooDog.substitutionGroup?.rawValue, "tns:animal")
        XCTAssertEqual(sharedAttribute.defaultValue, "en")
        XCTAssertEqual(sharedAttribute.annotation?.documentation, ["Shared docs"])
    }
}
