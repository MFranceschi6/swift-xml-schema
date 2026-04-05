import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaDocumentParserTests: XCTestCase {
    func test_parseStandaloneSchema_extractsComplexTypesSimpleTypesAndAttributes() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:types">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string" minOccurs="1"/>
            </xsd:sequence>
            <xsd:choice>
              <xsd:element name="couponCode" type="xsd:string" minOccurs="0"/>
            </xsd:choice>
            <xsd:attribute name="source" type="xsd:string" use="required"/>
          </xsd:complexType>
          <xsd:simpleType name="OrderStatus">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="pending"/>
              <xsd:enumeration value="shipped"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let schema = try XCTUnwrap(schemaSet.schemas.first)

        XCTAssertEqual(schema.targetNamespace, "urn:types")
        XCTAssertEqual(schema.complexTypes.count, 1)
        XCTAssertEqual(schema.complexTypes[0].sequence.first?.name, "id")
        XCTAssertEqual(schema.complexTypes[0].choiceGroups.first?.elements.first?.name, "couponCode")
        XCTAssertEqual(schema.complexTypes[0].attributes.first?.name, "source")
        XCTAssertEqual(schema.simpleTypes.first?.enumerationValues, ["pending", "shipped"])
    }

    func test_parseSimpleContent_extractsBaseAndAttributes() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:types" targetNamespace="urn:types">
          <xsd:complexType name="Amount">
            <xsd:simpleContent>
              <xsd:extension base="xsd:decimal">
                <xsd:attribute name="currency" type="xsd:string" use="required"/>
              </xsd:extension>
            </xsd:simpleContent>
          </xsd:complexType>
          <xsd:complexType name="LabeledAmount">
            <xsd:simpleContent>
              <xsd:extension base="tns:Amount">
                <xsd:attribute name="label" type="xsd:string"/>
              </xsd:extension>
            </xsd:simpleContent>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertEqual(schema.complexTypes[0].simpleContentBaseQName?.qualifiedName, "xsd:decimal")
        XCTAssertEqual(schema.complexTypes[0].attributes.map(\.name), ["currency"])
        XCTAssertEqual(schema.complexTypes[1].simpleContentBaseQName?.qualifiedName, "tns:Amount")
        XCTAssertEqual(schema.complexTypes[1].attributes.map(\.name), ["label"])
    }

    func test_parseAttributeGroups_extractsDefinitionsAndRefs() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:types" targetNamespace="urn:types">
          <xsd:attributeGroup name="BaseMetadata">
            <xsd:attribute name="source" type="xsd:string"/>
          </xsd:attributeGroup>
          <xsd:complexType name="Order">
            <xsd:attributeGroup ref="tns:BaseMetadata"/>
          </xsd:complexType>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        XCTAssertEqual(schema.attributeGroups.first?.name, "BaseMetadata")
        XCTAssertEqual(schema.attributeGroups.first?.attributes.first?.name, "source")
        XCTAssertEqual(schema.complexTypes.first?.attributeGroupRefs.first?.qualifiedName, "tns:BaseMetadata")
    }

    func test_parseRecursiveIncludesAndImports_loadsReferencedSchemas() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let imported = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:imported">
          <xsd:simpleType name="ExternalCode">
            <xsd:restriction base="xsd:string">
              <xsd:minLength value="2"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let included = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:base">
          <xsd:complexType name="IncludedPayload">
            <xsd:sequence>
              <xsd:element name="value" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let root = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:imp="urn:imported" targetNamespace="urn:base">
          <xsd:include schemaLocation="included.xsd"/>
          <xsd:import namespace="urn:imported" schemaLocation="imported.xsd"/>
          <xsd:element name="request" type="imp:ExternalCode"/>
        </xsd:schema>
        """

        let importedURL = tempDirectory.appendingPathComponent("imported.xsd")
        let includedURL = tempDirectory.appendingPathComponent("included.xsd")
        let rootURL = tempDirectory.appendingPathComponent("root.xsd")
        try imported.write(to: importedURL, atomically: true, encoding: .utf8)
        try included.write(to: includedURL, atomically: true, encoding: .utf8)
        try root.write(to: rootURL, atomically: true, encoding: .utf8)

        let schemaSet = try XMLSchemaDocumentParser().parse(url: rootURL)

        XCTAssertEqual(schemaSet.schemas.count, 3)
        XCTAssertNotNil(schemaSet.schemas.flatMap(\.simpleTypes).first(where: { $0.name == "ExternalCode" }))
        XCTAssertNotNil(schemaSet.schemas.flatMap(\.complexTypes).first(where: { $0.name == "IncludedPayload" }))
    }

    func test_parseDuplicateComplexType_throwsDiagnostic() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:dup">
          <xsd:complexType name="Order"/>
          <xsd:complexType name="Order"/>
        </xsd:schema>
        """

        XCTAssertThrowsError(try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))) { error in
            guard case let XMLSchemaParsingError.invalidSchema(name, message, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(name, "Order")
            XCTAssertTrue(message?.contains("Duplicated complex type") == true)
        }
    }

    func test_parseUnknownTypeReference_throwsDiagnostic() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:missing" targetNamespace="urn:missing">
          <xsd:element name="request" type="tns:MissingType"/>
        </xsd:schema>
        """

        XCTAssertThrowsError(try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))) { error in
            guard case let XMLSchemaParsingError.unresolvedReference(name, message, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(name, "request")
            XCTAssertTrue(message?.contains("MissingType") == true)
        }
    }

    func test_parseCoreMetadata_extractsAnnotationsDefaultsAbstractAndSubstitutionGroup() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:tns="urn:types" targetNamespace="urn:types">
          <xsd:annotation>
            <xsd:documentation>Schema docs</xsd:documentation>
            <xsd:appinfo>schema-meta</xsd:appinfo>
          </xsd:annotation>
          <xsd:attribute name="shared" type="xsd:string" default="en">
            <xsd:annotation>
              <xsd:documentation>Shared docs</xsd:documentation>
            </xsd:annotation>
          </xsd:attribute>
          <xsd:simpleType name="Code">
            <xsd:annotation>
              <xsd:documentation>Code docs</xsd:documentation>
            </xsd:annotation>
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
          <xsd:complexType name="Container" abstract="true">
            <xsd:annotation>
              <xsd:documentation>Container docs</xsd:documentation>
            </xsd:annotation>
            <xsd:sequence>
              <xsd:element name="value" default="fallback">
                <xsd:annotation>
                  <xsd:documentation>Value docs</xsd:documentation>
                </xsd:annotation>
                <xsd:simpleType>
                  <xsd:annotation>
                    <xsd:documentation>Inline simple docs</xsd:documentation>
                  </xsd:annotation>
                  <xsd:restriction base="xsd:string"/>
                </xsd:simpleType>
              </xsd:element>
            </xsd:sequence>
            <xsd:attribute name="mode" type="xsd:string" fixed="sealed">
              <xsd:annotation>
                <xsd:documentation>Mode docs</xsd:documentation>
              </xsd:annotation>
            </xsd:attribute>
          </xsd:complexType>
          <xsd:element name="animal" type="xsd:string" abstract="true">
            <xsd:annotation>
              <xsd:documentation>Animal docs</xsd:documentation>
            </xsd:annotation>
          </xsd:element>
          <xsd:element name="dog" type="tns:Code" substitutionGroup="tns:animal" fixed="DOG">
            <xsd:annotation>
              <xsd:documentation>Dog docs</xsd:documentation>
            </xsd:annotation>
          </xsd:element>
          <xsd:element name="wrapper">
            <xsd:complexType>
              <xsd:annotation>
                <xsd:documentation>Inline complex docs</xsd:documentation>
              </xsd:annotation>
              <xsd:attribute ref="tns:shared" use="required" default="fr">
                <xsd:annotation>
                  <xsd:documentation>Shared ref docs</xsd:documentation>
                </xsd:annotation>
              </xsd:attribute>
            </xsd:complexType>
          </xsd:element>
        </xsd:schema>
        """

        let schema = try XCTUnwrap(XMLSchemaDocumentParser().parse(data: Data(xsd.utf8)).schemas.first)
        let container = try XCTUnwrap(schema.complexTypes.first(where: { $0.name == "Container" }))
        let containerValue = try XCTUnwrap(container.sequence.first)
        let modeAttribute = try XCTUnwrap(container.attributes.first(where: { $0.name == "mode" }))
        let animal = try XCTUnwrap(schema.elements.first(where: { $0.name == "animal" }))
        let dog = try XCTUnwrap(schema.elements.first(where: { $0.name == "dog" }))
        let wrapper = try XCTUnwrap(schema.elements.first(where: { $0.name == "wrapper" }))
        let wrapperInlineComplex = try XCTUnwrap(wrapper.inlineComplexType)
        let sharedRef = try XCTUnwrap(wrapperInlineComplex.attributeRefs.first)
        let sharedDefinition = try XCTUnwrap(schema.attributeDefinitions.first(where: { $0.name == "shared" }))
        let code = try XCTUnwrap(schema.simpleTypes.first(where: { $0.name == "Code" }))

        XCTAssertEqual(schema.annotation?.documentation, ["Schema docs"])
        XCTAssertEqual(schema.annotation?.appinfo, ["schema-meta"])
        XCTAssertEqual(code.annotation?.documentation, ["Code docs"])

        XCTAssertTrue(container.isAbstract)
        XCTAssertEqual(container.annotation?.documentation, ["Container docs"])
        XCTAssertEqual(containerValue.defaultValue, "fallback")
        XCTAssertEqual(containerValue.annotation?.documentation, ["Value docs"])
        XCTAssertEqual(containerValue.inlineSimpleType?.annotation?.documentation, ["Inline simple docs"])
        XCTAssertEqual(modeAttribute.fixedValue, "sealed")
        XCTAssertEqual(modeAttribute.annotation?.documentation, ["Mode docs"])

        XCTAssertTrue(animal.isAbstract)
        XCTAssertEqual(animal.annotation?.documentation, ["Animal docs"])
        XCTAssertEqual(dog.substitutionGroup?.qualifiedName, "tns:animal")
        XCTAssertEqual(dog.fixedValue, "DOG")
        XCTAssertEqual(dog.annotation?.documentation, ["Dog docs"])

        XCTAssertEqual(wrapperInlineComplex.annotation?.documentation, ["Inline complex docs"])
        XCTAssertEqual(sharedRef.use, "required")
        XCTAssertEqual(sharedRef.defaultValue, "fr")
        XCTAssertEqual(sharedRef.annotation?.documentation, ["Shared ref docs"])
        XCTAssertEqual(sharedDefinition.defaultValue, "en")
        XCTAssertEqual(sharedDefinition.annotation?.documentation, ["Shared docs"])
    }

    // MARK: - Async parse (Swift 5.5+)

    #if swift(>=5.5)
    func test_asyncParseURL_simpleSchema_parsesSuccessfully() async throws {
        let xsd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:async-test">
            <xs:element name="Root" type="xs:string"/>
        </xs:schema>
        """
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("async_simple_\(UUID().uuidString).xsd")
        try xsd.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let parser = XMLSchemaDocumentParser()
        let schemaSet = try await parser.parse(url: url)

        XCTAssertEqual(schemaSet.schemas.count, 1)
        XCTAssertEqual(schemaSet.schemas.first?.targetNamespace, "urn:async-test")
        XCTAssertEqual(schemaSet.schemas.first?.elements.first?.name, "Root")
    }

    func test_asyncParseURL_withImport_loadsConcurrently() async throws {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("async_import_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let typesXSD = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:types">
            <xs:complexType name="ItemType">
                <xs:sequence>
                    <xs:element name="name" type="xs:string"/>
                </xs:sequence>
            </xs:complexType>
        </xs:schema>
        """
        try typesXSD.write(to: tmpDir.appendingPathComponent("types.xsd"), atomically: true, encoding: .utf8)

        let mainXSD = """
        <?xml version="1.0" encoding="UTF-8"?>
        <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:main">
            <xs:import namespace="urn:types" schemaLocation="types.xsd"/>
            <xs:element name="Root" type="xs:string"/>
        </xs:schema>
        """
        let mainURL = tmpDir.appendingPathComponent("main.xsd")
        try mainXSD.write(to: mainURL, atomically: true, encoding: .utf8)

        let parser = XMLSchemaDocumentParser()
        let schemaSet = try await parser.parse(url: mainURL)

        XCTAssertEqual(schemaSet.schemas.count, 2)
        let namespaces = schemaSet.schemas.compactMap { $0.targetNamespace }
        XCTAssertTrue(namespaces.contains("urn:main"))
        XCTAssertTrue(namespaces.contains("urn:types"))
    }
    #endif
}
