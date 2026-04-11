import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaDiffTests: XCTestCase {

    // MARK: - Helpers

    private func normalized(from xsd: String) throws -> XMLNormalizedSchemaSet {
        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    private func diff(old: String, new: String) throws -> XMLSchemaDiff {
        let oldSet = try normalized(from: old)
        let newSet = try normalized(from: new)
        return XMLSchemaDiffer().diff(old: oldSet, new: newSet)
    }

    private func fieldChanges(_ entry: XMLSchemaComplexTypeDiff) -> [XMLSchemaFieldChange] {
        if case .modified(_, _, let changes) = entry.change { return changes }
        return []
    }

    private func fieldChanges(_ entry: XMLSchemaSimpleTypeDiff) -> [XMLSchemaFieldChange] {
        if case .modified(_, _, let changes) = entry.change { return changes }
        return []
    }

    private func fieldChanges(_ entry: XMLSchemaElementDiff) -> [XMLSchemaFieldChange] {
        if case .modified(_, _, let changes) = entry.change { return changes }
        return []
    }

    private func fieldIsAdded(_ change: XMLSchemaFieldChange, name: String) -> Bool {
        if case .itemAdded(let n) = change.kind { return n == name }
        return false
    }

    private func fieldIsRemoved(_ change: XMLSchemaFieldChange, name: String) -> Bool {
        if case .itemRemoved(let n) = change.kind { return n == name }
        return false
    }

    // MARK: - No changes

    func test_diff_identical_isEmpty() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: xsd, new: xsd)
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(result.hasBreakingChanges)
    }

    func test_diff_empty_schemas_isEmpty() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let result = try diff(old: xsd, new: xsd)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Complex type added / removed

    func test_diff_complexType_added_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="NewType">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertFalse(result.isEmpty)
        XCTAssertFalse(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertEqual(entry.name, "NewType")
        if case .added = entry.change {} else { XCTFail("Expected .added") }
    }

    func test_diff_complexType_removed_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertEqual(entry.name, "Order")
        XCTAssertTrue(entry.isBreaking)
        if case .removed = entry.change {} else { XCTFail("Expected .removed") }
    }

    // MARK: - Content element changes

    func test_diff_requiredElementAdded_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="required" type="xsd:string" minOccurs="1"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(
            fieldChanges(entry).first { $0.fieldName == "content" && fieldIsAdded($0, name: "required") }
        )
        XCTAssertTrue(fieldChange.isBreaking)
    }

    func test_diff_optionalElementAdded_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="optional" type="xsd:string" minOccurs="0"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(
            fieldChanges(entry).first { $0.fieldName == "content" && fieldIsAdded($0, name: "optional") }
        )
        XCTAssertFalse(fieldChange.isBreaking)
        XCTAssertFalse(result.hasBreakingChanges)
    }

    func test_diff_elementRemoved_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
              <xsd:element name="amount" type="xsd:decimal"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(
            fieldChanges(entry).first { $0.fieldName == "content" && fieldIsRemoved($0, name: "amount") }
        )
        XCTAssertTrue(fieldChange.isBreaking)
    }

    func test_diff_elementTypeChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="amount" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Order">
            <xsd:sequence><xsd:element name="amount" type="xsd:decimal"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "content.amount.type" && $0.isBreaking })
    }

    // MARK: - Attribute changes

    func test_diff_requiredAttributeAdded_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="currency" type="xsd:string" use="required"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains {
            $0.fieldName == "attribute" && fieldIsAdded($0, name: "currency") && $0.isBreaking
        })
    }

    func test_diff_optionalAttributeAdded_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="lang" type="xsd:string" use="optional"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertFalse(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertFalse(fieldChanges(entry).isEmpty)
        XCTAssertFalse(fieldChanges(entry).contains { $0.isBreaking })
    }

    func test_diff_attributeRemoved_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="status" type="xsd:string" use="required"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T"><xsd:sequence/></xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { fieldIsRemoved($0, name: "status") && $0.isBreaking })
    }

    // MARK: - Simple type changes

    func test_diff_enumerationValueRemoved_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Status">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
              <xsd:enumeration value="inactive"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Status">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { fieldIsRemoved($0, name: "inactive") && $0.isBreaking })
    }

    func test_diff_enumerationValueAdded_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Status">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Status">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="active"/>
              <xsd:enumeration value="pending"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertFalse(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertFalse(fieldChanges(entry).isEmpty)
    }

    func test_diff_simpleType_baseChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:integer"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "baseType" && $0.isBreaking })
    }

    // MARK: - Top-level element changes

    func test_diff_elementTypeChanged_topLevel_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:integer"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.elementChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "type" && $0.isBreaking })
    }

    func test_diff_elementAdded_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertFalse(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.elementChanges.first)
        if case .added = entry.change {} else { XCTFail("Expected .added") }
    }

    // MARK: - breakingChanges helpers

    func test_breakingComplexTypeChanges_filtersCorrectly() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Removed">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Added">
            <xsd:sequence><xsd:element name="y" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertEqual(result.breakingComplexTypeChanges.count, 1)
        XCTAssertEqual(result.breakingComplexTypeChanges.first?.name, "Removed")
        XCTAssertEqual(result.complexTypeChanges.count, 2)
    }

    // MARK: - isMixed change

    func test_diff_isMixedChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" mixed="false">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" mixed="true">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "isMixed" && $0.isBreaking })
    }
}
