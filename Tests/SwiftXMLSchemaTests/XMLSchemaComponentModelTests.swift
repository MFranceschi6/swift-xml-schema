import XCTest
@testable import SwiftXMLSchema

// Tests for the indexed O(1) component model and the type hierarchy navigator.
// All code here is Swift 5.4 compatible — no primary associated types or `some` params.
final class XMLSchemaComponentModelTests: XCTestCase {

    // MARK: - Fixture

    // Schema with:
    //   complexTypes: Base, Child (extends Base), GrandChild (extends Child)
    //   simpleTypes:  StatusCode, RestrictedStatus (restricts StatusCode)
    //   elements:     item (type=Base), order (type=Child)
    //   substitutionGroup: order can substitute item
    //   attributeGroup: CommonAttrs
    //   modelGroup:   ItemFields
    private static let xsd = """
    <?xml version="1.0" encoding="UTF-8"?>
    <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                targetNamespace="urn:cm"
                xmlns:tns="urn:cm">

      <xsd:simpleType name="StatusCode">
        <xsd:restriction base="xsd:string">
          <xsd:enumeration value="active"/>
          <xsd:enumeration value="inactive"/>
        </xsd:restriction>
      </xsd:simpleType>

      <xsd:simpleType name="RestrictedStatus">
        <xsd:restriction base="tns:StatusCode">
          <xsd:enumeration value="active"/>
        </xsd:restriction>
      </xsd:simpleType>

      <xsd:attributeGroup name="CommonAttrs">
        <xsd:attribute name="id" type="xsd:string"/>
        <xsd:attribute name="version" type="xsd:string"/>
      </xsd:attributeGroup>

      <xsd:group name="ItemFields">
        <xsd:sequence>
          <xsd:element name="name" type="xsd:string"/>
          <xsd:element name="code" type="xsd:string"/>
        </xsd:sequence>
      </xsd:group>

      <xsd:complexType name="Base">
        <xsd:sequence>
          <xsd:element name="id" type="xsd:string"/>
        </xsd:sequence>
        <xsd:attributeGroup ref="tns:CommonAttrs"/>
      </xsd:complexType>

      <xsd:complexType name="Child">
        <xsd:complexContent>
          <xsd:extension base="tns:Base">
            <xsd:sequence>
              <xsd:element name="extra" type="xsd:string"/>
            </xsd:sequence>
          </xsd:extension>
        </xsd:complexContent>
      </xsd:complexType>

      <xsd:complexType name="GrandChild">
        <xsd:complexContent>
          <xsd:extension base="tns:Child">
            <xsd:sequence>
              <xsd:element name="leaf" type="xsd:string"/>
            </xsd:sequence>
          </xsd:extension>
        </xsd:complexContent>
      </xsd:complexType>

      <xsd:element name="item" type="tns:Base"/>
      <xsd:element name="order" type="tns:Child" substitutionGroup="tns:item"/>

    </xsd:schema>
    """

    private func makeNormalized() throws -> XMLNormalizedSchemaSet {
        let set = try XMLSchemaDocumentParser().parse(data: Data(Self.xsd.utf8))
        return try XMLSchemaNormalizer().normalize(set)
    }

    // MARK: - O(1) Lookup

    func test_element_lookupByNameAndNamespace() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.element(named: "item", namespaceURI: "urn:cm"))
        XCTAssertNotNil(n.element(named: "order", namespaceURI: "urn:cm"))
        XCTAssertNil(n.element(named: "missing", namespaceURI: "urn:cm"))
    }

    func test_element_fallbackToBareLookupWhenNoNamespace() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.element(named: "item", namespaceURI: nil))
        XCTAssertNotNil(n.element(named: "order", namespaceURI: nil))
    }

    func test_complexType_lookupByNameAndNamespace() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.complexType(named: "Base", namespaceURI: "urn:cm"))
        XCTAssertNotNil(n.complexType(named: "Child", namespaceURI: "urn:cm"))
        XCTAssertNotNil(n.complexType(named: "GrandChild", namespaceURI: "urn:cm"))
        XCTAssertNil(n.complexType(named: "Missing", namespaceURI: "urn:cm"))
    }

    func test_simpleType_lookupByNameAndNamespace() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.simpleType(named: "StatusCode", namespaceURI: "urn:cm"))
        XCTAssertNotNil(n.simpleType(named: "RestrictedStatus", namespaceURI: "urn:cm"))
    }

    func test_attributeGroup_lookup() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.attributeGroup(named: "CommonAttrs", namespaceURI: "urn:cm"))
        XCTAssertNil(n.attributeGroup(named: "Missing", namespaceURI: "urn:cm"))
    }

    func test_modelGroup_lookup() throws {
        let n = try makeNormalized()
        XCTAssertNotNil(n.modelGroup(named: "ItemFields", namespaceURI: "urn:cm"))
    }

    func test_rootElementBinding_byTypeAndNamespace() throws {
        let n = try makeNormalized()
        let binding = try XCTUnwrap(n.rootElementBinding(forTypeNamed: "Base", namespaceURI: "urn:cm"))
        XCTAssertEqual(binding.name, "item")
        XCTAssertEqual(binding.namespaceURI, "urn:cm")
    }

    func test_rootElementBinding_fallbackBareKey() throws {
        let n = try makeNormalized()
        let binding = try XCTUnwrap(n.rootElementBinding(forTypeNamed: "Base", namespaceURI: nil))
        XCTAssertEqual(binding.name, "item")
    }

    func test_substitutionGroupMembers_returnsOrderForItem() throws {
        let n = try makeNormalized()
        let members = n.substitutionGroupMembers(ofLocalName: "item", namespaceURI: "urn:cm")
        XCTAssertEqual(members.count, 1)
        XCTAssertEqual(members.first?.name, "order")
    }

    func test_substitutionGroupMembers_emptyWhenNoMembers() throws {
        let n = try makeNormalized()
        let members = n.substitutionGroupMembers(ofLocalName: "order", namespaceURI: "urn:cm")
        XCTAssertTrue(members.isEmpty)
    }

    // MARK: - Type Hierarchy Navigator

    func test_baseComplexType_returnsParent() throws {
        let n = try makeNormalized()
        let child = try XCTUnwrap(n.complexType(named: "Child", namespaceURI: "urn:cm"))
        let base = try XCTUnwrap(n.baseComplexType(of: child))
        XCTAssertEqual(base.name, "Base")
    }

    func test_baseComplexType_twoLevels() throws {
        let n = try makeNormalized()
        let grandChild = try XCTUnwrap(n.complexType(named: "GrandChild", namespaceURI: "urn:cm"))
        let child = try XCTUnwrap(n.baseComplexType(of: grandChild))
        XCTAssertEqual(child.name, "Child")
        let base = try XCTUnwrap(n.baseComplexType(of: child))
        XCTAssertEqual(base.name, "Base")
    }

    func test_baseComplexType_nilForRootType() throws {
        let n = try makeNormalized()
        let base = try XCTUnwrap(n.complexType(named: "Base", namespaceURI: "urn:cm"))
        XCTAssertNil(n.baseComplexType(of: base))
    }

    func test_baseSimpleType_returnsParent() throws {
        let n = try makeNormalized()
        let restricted = try XCTUnwrap(n.simpleType(named: "RestrictedStatus", namespaceURI: "urn:cm"))
        let parent = try XCTUnwrap(n.baseSimpleType(of: restricted))
        XCTAssertEqual(parent.name, "StatusCode")
    }

    func test_baseSimpleType_nilWhenBaseIsBuiltIn() throws {
        let n = try makeNormalized()
        let statusCode = try XCTUnwrap(n.simpleType(named: "StatusCode", namespaceURI: "urn:cm"))
        // Base is xsd:string — not in this schema set, so nil
        XCTAssertNil(n.baseSimpleType(of: statusCode))
    }

    func test_derivedComplexTypes_returnsDirectChildren() throws {
        let n = try makeNormalized()
        let base = try XCTUnwrap(n.complexType(named: "Base", namespaceURI: "urn:cm"))
        let derived = n.derivedComplexTypes(of: base)
        XCTAssertEqual(derived.count, 1)
        XCTAssertEqual(derived.first?.name, "Child")
    }

    func test_derivedComplexTypes_grandchildOfChild() throws {
        let n = try makeNormalized()
        let child = try XCTUnwrap(n.complexType(named: "Child", namespaceURI: "urn:cm"))
        let derived = n.derivedComplexTypes(of: child)
        XCTAssertEqual(derived.count, 1)
        XCTAssertEqual(derived.first?.name, "GrandChild")
    }

    func test_derivedComplexTypes_emptyForLeaf() throws {
        let n = try makeNormalized()
        let grandChild = try XCTUnwrap(n.complexType(named: "GrandChild", namespaceURI: "urn:cm"))
        XCTAssertTrue(n.derivedComplexTypes(of: grandChild).isEmpty)
    }

    func test_derivedSimpleTypes_returnsDirectChildren() throws {
        let n = try makeNormalized()
        let statusCode = try XCTUnwrap(n.simpleType(named: "StatusCode", namespaceURI: "urn:cm"))
        let derived = n.derivedSimpleTypes(of: statusCode)
        XCTAssertEqual(derived.count, 1)
        XCTAssertEqual(derived.first?.name, "RestrictedStatus")
    }

    func test_derivedSimpleTypes_emptyForLeaf() throws {
        let n = try makeNormalized()
        let restricted = try XCTUnwrap(n.simpleType(named: "RestrictedStatus", namespaceURI: "urn:cm"))
        XCTAssertTrue(n.derivedSimpleTypes(of: restricted).isEmpty)
    }

    // MARK: - canSubstitute

    func test_canSubstitute_trueForDirectMember() throws {
        let n = try makeNormalized()
        let item = try XCTUnwrap(n.element(named: "item", namespaceURI: "urn:cm"))
        let order = try XCTUnwrap(n.element(named: "order", namespaceURI: "urn:cm"))
        XCTAssertTrue(n.canSubstitute(order, for: item))
    }

    func test_canSubstitute_falseForNonMember() throws {
        let n = try makeNormalized()
        let item = try XCTUnwrap(n.element(named: "item", namespaceURI: "urn:cm"))
        let order = try XCTUnwrap(n.element(named: "order", namespaceURI: "urn:cm"))
        XCTAssertFalse(n.canSubstitute(item, for: order))
    }

    func test_canSubstitute_falseForSelf() throws {
        let n = try makeNormalized()
        let item = try XCTUnwrap(n.element(named: "item", namespaceURI: "urn:cm"))
        XCTAssertFalse(n.canSubstitute(item, for: item))
    }
}
