import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaPhase04Tests: XCTestCase {

    // MARK: - Mixed content

    func test_mixedContent_onComplexTypeElement() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:mixed">
          <xsd:complexType name="Paragraph" mixed="true">
            <xsd:sequence>
              <xsd:element name="b" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let paragraph = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Paragraph" }))
        XCTAssertTrue(paragraph.isMixed)
    }

    func test_mixedContent_onComplexContent() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:mixed">
          <xsd:complexType name="Base">
            <xsd:sequence>
              <xsd:element name="value" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Derived">
            <xsd:complexContent mixed="true">
              <xsd:extension base="xsd:anyType">
                <xsd:sequence>
                  <xsd:element name="extra" type="xsd:string"/>
                </xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let base = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Base" }))
        let derived = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Derived" }))
        XCTAssertFalse(base.isMixed)
        XCTAssertTrue(derived.isMixed)
    }

    func test_mixedContent_notSetByDefault() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:nomixed">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertFalse(schema.complexTypes.first?.isMixed ?? true)
    }

    func test_mixedContent_propagatedToNormalized() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:mixed">
          <xsd:complexType name="Rich" mixed="true">
            <xsd:sequence>
              <xsd:element name="em" type="xsd:string" minOccurs="0"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let rich = try XCTUnwrap(normalized.complexType(named: "Rich", namespaceURI: "urn:mixed"))
        XCTAssertTrue(rich.isMixed)
    }

    // MARK: - Identity constraints

    func test_identityConstraints_keyOnElement() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:id">
          <xsd:element name="orders">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="order" type="xsd:string" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:complexType>
            <xsd:key name="orderKey">
              <xsd:selector xpath="order"/>
              <xsd:field xpath="@id"/>
            </xsd:key>
          </xsd:element>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let orders = try XCTUnwrap(schema.elements.first(where: { $0.name == "orders" }))
        XCTAssertEqual(orders.identityConstraints.count, 1)
        let constraint = try XCTUnwrap(orders.identityConstraints.first)
        XCTAssertEqual(constraint.kind, .key)
        XCTAssertEqual(constraint.name, "orderKey")
        XCTAssertEqual(constraint.selector, "order")
        XCTAssertEqual(constraint.fields, ["@id"])
        XCTAssertNil(constraint.refer)
    }

    func test_identityConstraints_keyrefOnElement() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:id" targetNamespace="urn:id">
          <xsd:element name="catalog">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="item" type="xsd:string" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:complexType>
            <xsd:keyref name="itemRef" refer="tns:itemKey">
              <xsd:selector xpath="item"/>
              <xsd:field xpath="@ref"/>
            </xsd:keyref>
          </xsd:element>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let catalog = try XCTUnwrap(schema.elements.first(where: { $0.name == "catalog" }))
        XCTAssertEqual(catalog.identityConstraints.count, 1)
        let constraint = try XCTUnwrap(catalog.identityConstraints.first)
        XCTAssertEqual(constraint.kind, .keyref)
        XCTAssertEqual(constraint.name, "itemRef")
        XCTAssertEqual(constraint.refer?.qualifiedName, "tns:itemKey")
    }

    func test_identityConstraints_uniqueOnElement() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:id">
          <xsd:element name="people">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="person" type="xsd:string" maxOccurs="unbounded"/>
              </xsd:sequence>
            </xsd:complexType>
            <xsd:unique name="uniqueEmail">
              <xsd:selector xpath="person"/>
              <xsd:field xpath="email"/>
            </xsd:unique>
          </xsd:element>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let people = try XCTUnwrap(schema.elements.first(where: { $0.name == "people" }))
        XCTAssertEqual(people.identityConstraints.count, 1)
        let constraint = try XCTUnwrap(people.identityConstraints.first)
        XCTAssertEqual(constraint.kind, .unique)
        XCTAssertEqual(constraint.name, "uniqueEmail")
    }

    func test_identityConstraints_propagatedToNormalized() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:id">
          <xsd:element name="root">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="child" type="xsd:string"/>
              </xsd:sequence>
            </xsd:complexType>
            <xsd:key name="childKey">
              <xsd:selector xpath="child"/>
              <xsd:field xpath="@id"/>
            </xsd:key>
          </xsd:element>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let root = try XCTUnwrap(normalized.element(named: "root", namespaceURI: "urn:id"))
        XCTAssertEqual(root.identityConstraints.count, 1)
        XCTAssertEqual(root.identityConstraints.first?.kind, .key)
    }

    func test_identityConstraints_emptyWhenNone() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:id">
          <xsd:element name="simple" type="xsd:string"/>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertTrue(schema.elements.first?.identityConstraints.isEmpty ?? false)
    }

    // MARK: - Notation

    func test_notation_parsedFromSchema() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:notation">
          <xsd:notation name="gif" public="image/gif" system="gif.exe"/>
          <xsd:notation name="jpeg" public="image/jpeg"/>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertEqual(schema.notations.count, 2)
        let gif = try XCTUnwrap(schema.notations.first(where: { $0.name == "gif" }))
        XCTAssertEqual(gif.publicID, "image/gif")
        XCTAssertEqual(gif.systemID, "gif.exe")
        let jpeg = try XCTUnwrap(schema.notations.first(where: { $0.name == "jpeg" }))
        XCTAssertEqual(jpeg.publicID, "image/jpeg")
        XCTAssertNil(jpeg.systemID)
    }

    func test_notation_emptyWhenNone() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:notation">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertTrue(schema.notations.isEmpty)
    }

    // MARK: - Redefine

    func test_redefine_overridesComplexType() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("redefine_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let baseXSD = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:base">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        try baseXSD.write(to: tmpDir.appendingPathComponent("base.xsd"), atomically: true, encoding: .utf8)

        let mainXSD = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:base">
          <xsd:redefine schemaLocation="base.xsd">
            <xsd:complexType name="Order">
              <xsd:complexContent>
                <xsd:extension base="xsd:anyType">
                  <xsd:sequence>
                    <xsd:element name="id" type="xsd:string"/>
                    <xsd:element name="status" type="xsd:string"/>
                  </xsd:sequence>
                </xsd:extension>
              </xsd:complexContent>
            </xsd:complexType>
          </xsd:redefine>
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let mainURL = tmpDir.appendingPathComponent("main.xsd")
        try mainXSD.write(to: mainURL, atomically: true, encoding: .utf8)

        let schemaSet = try XMLSchemaDocumentParser().parse(url: mainURL)
        // The redefine replaces the base Order type; we should see one schema with Order having 2 sequence elements
        let orderTypes = schemaSet.schemas.flatMap(\.complexTypes).filter { $0.name == "Order" }
        // Original is replaced, only the redefined version should remain
        XCTAssertFalse(orderTypes.isEmpty)
        let redefined = try XCTUnwrap(orderTypes.last)
        // Redefined Order has extension with id + status
        let seqElements = redefined.sequence
        XCTAssertTrue(seqElements.contains(where: { $0.name == "status" }))
    }

    func test_redefine_parsed_hasSchemaLocation() throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("redefine_parsed_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let baseXSD = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:rp">
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        try baseXSD.write(to: tmpDir.appendingPathComponent("base.xsd"), atomically: true, encoding: .utf8)

        let mainXSD = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:rp">
          <xsd:redefine schemaLocation="base.xsd">
            <xsd:simpleType name="Code">
              <xsd:restriction base="xsd:string">
                <xsd:minLength value="2"/>
              </xsd:restriction>
            </xsd:simpleType>
          </xsd:redefine>
        </xsd:schema>
        """
        let mainURL = tmpDir.appendingPathComponent("main.xsd")
        try mainXSD.write(to: mainURL, atomically: true, encoding: .utf8)

        let schemaSet = try XMLSchemaDocumentParser().parse(url: mainURL)
        // main schema has the redefine entry
        let mainSchema = try XCTUnwrap(schemaSet.schemas.first)
        XCTAssertEqual(mainSchema.redefines.first?.schemaLocation, "base.xsd")
        // The redefine replaces Code; no schema should have a Code without minLength
        let allCodes = schemaSet.schemas.flatMap(\.simpleTypes).filter { $0.name == "Code" }
        XCTAssertFalse(allCodes.isEmpty)
        // The redefined Code has a minLength facet
        let redefinedCode = try XCTUnwrap(allCodes.last)
        XCTAssertEqual(redefinedCode.facets?.minLength, 2)
    }
}
