import Foundation
import Logging
import SwiftXMLSchema
import XCTest

final class XMLSchemaFlattenerTests: XCTestCase {

    // MARK: - Helpers

    private func normalize(xsd: String) throws -> XMLNormalizedSchemaSet {
        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    private func flatten(xsd: String) throws -> Data {
        let normalized = try normalize(xsd: xsd)
        return try XMLSchemaFlattener().flatten(normalized)
    }

    private func flattenWithNamespace(xsd: String, targetNamespace: String?) throws -> Data {
        let normalized = try normalize(xsd: xsd)
        return try XMLSchemaFlattener().flatten(normalized, targetNamespace: targetNamespace)
    }

    /// Flattens, then re-parses + re-normalizes the output. Verifies the flattened XSD is valid.
    private func roundTrip(xsd: String) throws -> XMLNormalizedSchemaSet {
        let data = try flatten(xsd: xsd)
        let reparsed = try XMLSchemaDocumentParser().parse(data: data)
        return try XMLSchemaNormalizer().normalize(reparsed)
    }

    private func utf8String(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Top-level structure

    func test_flatten_emptySchema_producesValidXSD() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:empty"/>
        """
        let data = try flatten(xsd: xsd)
        let xml = utf8String(data)
        XCTAssertTrue(xml.hasPrefix("<?xml"))
        XCTAssertTrue(xml.contains("<xsd:schema"))
        XCTAssertTrue(xml.contains("targetNamespace=\"urn:empty\""))
        // Must be parseable
        _ = try roundTrip(xsd: xsd)
    }

    func test_flatten_outputIsValidUTF8() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let data = try flatten(xsd: xsd)
        XCTAssertNotNil(String(data: data, encoding: .utf8))
    }

    func test_flatten_outputHasNewlines() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("\n"))
    }

    func test_flatten_noNamespaceSchema_omitsTargetNamespaceAttribute() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertFalse(xml.contains("targetNamespace"))
    }

    // MARK: - Simple types

    func test_flatten_simpleType_restriction_enumeration_roundTrips() throws {
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
        let result = try roundTrip(xsd: xsd)
        let status = try XCTUnwrap(result.simpleType(named: "Status", namespaceURI: "urn:st"))
        XCTAssertEqual(status.enumerationValues.sorted(), ["active", "inactive"])
    }

    func test_flatten_simpleType_list_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:st">
          <xsd:simpleType name="IntList">
            <xsd:list itemType="xsd:integer"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let intList = try XCTUnwrap(result.simpleType(named: "IntList", namespaceURI: "urn:st"))
        XCTAssertEqual(intList.derivationKind, .list)
        XCTAssertEqual(intList.listItemQName?.localName, "integer")
    }

    func test_flatten_simpleType_union_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:st">
          <xsd:simpleType name="NumOrStr">
            <xsd:union memberTypes="xsd:integer xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let numOrStr = try XCTUnwrap(result.simpleType(named: "NumOrStr", namespaceURI: "urn:st"))
        XCTAssertEqual(numOrStr.derivationKind, .union)
        XCTAssertEqual(numOrStr.unionMemberQNames.map(\.localName).sorted(), ["integer", "string"])
    }

    func test_flatten_simpleType_facets_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:st">
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string">
              <xsd:minLength value="2"/>
              <xsd:maxLength value="10"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let code = try XCTUnwrap(result.simpleType(named: "Code", namespaceURI: "urn:st"))
        XCTAssertEqual(code.facets?.minLength, 2)
        XCTAssertEqual(code.facets?.maxLength, 10)
    }

    // MARK: - Complex types

    func test_flatten_complexType_sequence_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="qty" type="xsd:integer"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let order = try XCTUnwrap(result.complexType(named: "Order", namespaceURI: "urn:ct"))
        let names = order.effectiveContent.compactMap {
            if case .element(let use) = $0 { return use.name }
            return nil
        }
        XCTAssertEqual(names, ["id", "qty"])
    }

    func test_flatten_complexType_withAttributes_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Priced">
            <xsd:sequence/>
            <xsd:attribute name="currency" type="xsd:string" use="required"/>
            <xsd:attribute name="amount" type="xsd:decimal"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let priced = try XCTUnwrap(result.complexType(named: "Priced", namespaceURI: "urn:ct"))
        let attrNames = priced.effectiveAttributes.map(\.name)
        XCTAssertTrue(attrNames.contains("currency"))
        XCTAssertTrue(attrNames.contains("amount"))
        let currency = priced.effectiveAttributes.first { $0.name == "currency" }
        XCTAssertEqual(currency?.use, .required)
    }

    func test_flatten_complexType_isMixed_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Mixed" mixed="true">
            <xsd:sequence>
              <xsd:element name="span" type="xsd:string" minOccurs="0"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("mixed=\"true\""))
    }

    func test_flatten_complexType_isAbstract_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Base" abstract="true">
            <xsd:sequence/>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("abstract=\"true\""))
    }

    func test_flatten_complexType_simpleContent_withAttributes_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Amount">
            <xsd:simpleContent>
              <xsd:extension base="xsd:decimal">
                <xsd:attribute name="currency" type="xsd:string" use="required"/>
              </xsd:extension>
            </xsd:simpleContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("xsd:simpleContent"))
        // Re-parse succeeds
        let result = try roundTrip(xsd: xsd)
        let amount = try XCTUnwrap(result.complexType(named: "Amount", namespaceURI: "urn:ct"))
        XCTAssertNotNil(amount.effectiveSimpleContentValueTypeQName)
    }

    func test_flatten_complexType_anyAttribute_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Open">
            <xsd:sequence/>
            <xsd:anyAttribute namespace="##any" processContents="lax"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("xsd:anyAttribute"))
    }

    func test_flatten_contentNode_wildcard_producesAny() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Open">
            <xsd:sequence>
              <xsd:any namespace="##any" processContents="lax" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("<xsd:any "))
    }

    func test_flatten_complexType_choiceGroup_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ct">
          <xsd:complexType name="Payment">
            <xsd:choice>
              <xsd:element name="creditCard" type="xsd:string"/>
              <xsd:element name="bankTransfer" type="xsd:string"/>
            </xsd:choice>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("<xsd:choice>"))
        let result = try roundTrip(xsd: xsd)
        let payment = try XCTUnwrap(result.complexType(named: "Payment", namespaceURI: "urn:ct"))
        let choiceNames = payment.effectiveContent.compactMap {
            if case .choice(let g) = $0 { return g.elements.map(\.name) }
            return nil
        }.flatMap { $0 }
        XCTAssertTrue(choiceNames.contains("creditCard"))
        XCTAssertTrue(choiceNames.contains("bankTransfer"))
    }

    // MARK: - Top-level elements

    func test_flatten_topLevelElement_typeRef_roundTrips() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:tns="urn:el" targetNamespace="urn:el">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:element name="order" type="tns:Order"/>
        </xsd:schema>
        """
        let result = try roundTrip(xsd: xsd)
        let element = try XCTUnwrap(result.element(named: "order", namespaceURI: "urn:el"))
        XCTAssertEqual(element.typeQName?.localName, "Order")
    }

    func test_flatten_topLevelElement_nillable_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:el">
          <xsd:element name="root" type="xsd:string" nillable="true"/>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("nillable=\"true\""))
    }

    func test_flatten_occurrenceBounds_unbounded_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:occ">
          <xsd:complexType name="Container">
            <xsd:sequence>
              <xsd:element name="item" type="xsd:string" minOccurs="0" maxOccurs="unbounded"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("maxOccurs=\"unbounded\""))
    }

    func test_flatten_annotation_documentation_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ann">
          <xsd:complexType name="Documented">
            <xsd:annotation>
              <xsd:documentation>A well-documented type.</xsd:documentation>
            </xsd:annotation>
            <xsd:sequence/>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("xsd:documentation"))
        XCTAssertTrue(xml.contains("A well-documented type."))
    }

    // MARK: - Multiple schemas

    func test_flatten_multipleSchemas_sameNamespace_mergedIntoOne() throws {
        // Two independent schemas with the same namespace; flatten should merge both types
        let xsd1 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:m">
          <xsd:complexType name="TypeA"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let xsd2 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:m">
          <xsd:complexType name="TypeB"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let set1 = try normalize(xsd: xsd1)
        let set2 = try normalize(xsd: xsd2)
        // Merge by creating a new set with schemas from both
        let merged = XMLNormalizedSchemaSet(schemas: set1.schemas + set2.schemas)
        let data = try XMLSchemaFlattener().flatten(merged)
        let xml = utf8String(data)
        XCTAssertTrue(xml.contains("name=\"TypeA\""))
        XCTAssertTrue(xml.contains("name=\"TypeB\""))
    }

    func test_flatten_ambiguousNamespace_throwsError() throws {
        let xsd1 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:a">
          <xsd:complexType name="A"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let xsd2 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:b">
          <xsd:complexType name="B"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let set1 = try normalize(xsd: xsd1)
        let set2 = try normalize(xsd: xsd2)
        let merged = XMLNormalizedSchemaSet(schemas: set1.schemas + set2.schemas)

        XCTAssertThrowsError(try XMLSchemaFlattener().flatten(merged)) { error in
            guard case XMLSchemaFlattenerError.ambiguousNamespace(let namespaces) = error else {
                return XCTFail("Expected ambiguousNamespace, got \(error)")
            }
            XCTAssertEqual(namespaces.sorted(), ["urn:a", "urn:b"])
        }
    }

    func test_flatten_ambiguousNamespace_withExplicitNamespace_succeeds() throws {
        let xsd1 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:a">
          <xsd:complexType name="A"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let xsd2 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:b">
          <xsd:complexType name="B"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let set1 = try normalize(xsd: xsd1)
        let set2 = try normalize(xsd: xsd2)
        let merged = XMLNormalizedSchemaSet(schemas: set1.schemas + set2.schemas)

        let data = try XMLSchemaFlattener().flatten(merged, targetNamespace: "urn:a")
        let xml = utf8String(data)
        XCTAssertTrue(xml.contains("targetNamespace=\"urn:a\""))
        XCTAssertTrue(xml.contains("name=\"A\""))
        XCTAssertTrue(xml.contains("name=\"B\""))
    }

    // MARK: - Logger autoclosures at trace level

    func test_flatten_traceLogger_exercisesAllAutoclosures() throws {
        var logger = Logger(label: "test.flattener")
        logger.logLevel = .trace
        let flattener = XMLSchemaFlattener(logger: logger)

        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:log">
          <xsd:complexType name="Item">
            <xsd:sequence><xsd:element name="name" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="A"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:element name="item" type="xsd:string"/>
        </xsd:schema>
        """
        let normalized = try normalize(xsd: xsd)
        let data = try flattener.flatten(normalized)
        XCTAssertFalse(data.isEmpty)
    }

    func test_flatten_crossNamespaceRef_logsWarning() throws {
        // Exercises the warning branch in qnameString when namespaces differ
        var logger = Logger(label: "test.flattener")
        logger.logLevel = .trace
        let flattener = XMLSchemaFlattener(logger: logger)

        let xsd1 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:a">
          <xsd:complexType name="A"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let xsd2 = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:b">
          <xsd:complexType name="B"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let set1 = try normalize(xsd: xsd1)
        let set2 = try normalize(xsd: xsd2)
        let merged = XMLNormalizedSchemaSet(schemas: set1.schemas + set2.schemas)
        // Explicit namespace — types from urn:b will trigger the cross-namespace warning
        let data = try flattener.flatten(merged, targetNamespace: "urn:a")
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Schema-level annotation

    func test_flatten_schemaAnnotation_preserved() throws {
        // Uses schema annotation to exercise the schema-level annotation branch
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:sa">
          <xsd:annotation>
            <xsd:documentation>Schema-level documentation.</xsd:documentation>
          </xsd:annotation>
          <xsd:complexType name="T"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("Schema-level documentation."))
    }

    // MARK: - Top-level attribute definition

    func test_flatten_topLevelAttributeDefinition_emitted() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:td">
          <xsd:attribute name="lang" type="xsd:string"/>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("name=\"lang\""))
    }

    // MARK: - SimpleType with annotation

    func test_flatten_simpleTypeAnnotation_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:st">
          <xsd:simpleType name="Status">
            <xsd:annotation>
              <xsd:documentation>Active or inactive.</xsd:documentation>
            </xsd:annotation>
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("Active or inactive."))
    }

    // MARK: - Element default/fixed values

    func test_flatten_elementDefaultAndFixed_preserved() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:df">
          <xsd:complexType name="T">
            <xsd:sequence>
              <xsd:element name="withDefault" type="xsd:string" default="hello"/>
              <xsd:element name="withFixed" type="xsd:string" fixed="world"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("default=\"hello\""))
        XCTAssertTrue(xml.contains("fixed=\"world\""))
    }

    // MARK: - Attribute groups and model groups

    func test_flatten_attributeGroup_emittedAsTopLevel() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:ag">
          <xsd:attributeGroup name="CommonAttrs">
            <xsd:attribute name="id" type="xsd:string"/>
          </xsd:attributeGroup>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("<xsd:attributeGroup "))
        XCTAssertTrue(xml.contains("name=\"CommonAttrs\""))
    }

    func test_flatten_modelGroup_emittedAsGroup() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:mg">
          <xsd:group name="AddressGroup">
            <xsd:sequence>
              <xsd:element name="street" type="xsd:string"/>
            </xsd:sequence>
          </xsd:group>
        </xsd:schema>
        """
        let xml = utf8String(try flatten(xsd: xsd))
        XCTAssertTrue(xml.contains("<xsd:group "))
        XCTAssertTrue(xml.contains("name=\"AddressGroup\""))
    }
}
