import Foundation
import SwiftXMLSchema
import XCTest

/// Focused tests targeting branches in `XMLSchemaDiff` that are not exercised by
/// `XMLSchemaDiffTests`. Kept in a separate file to stay within the per-file
/// length lint budget.
final class XMLSchemaDiffCoverageTests: XCTestCase {

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

    // MARK: - Complex type: base type and derivation

    func test_diff_complexType_baseTypeChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Base"><xsd:sequence/></xsd:complexType>
          <xsd:complexType name="Other"><xsd:sequence/></xsd:complexType>
          <xsd:complexType name="Sub">
            <xsd:complexContent>
              <xsd:extension base="Base"><xsd:sequence/></xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Base"><xsd:sequence/></xsd:complexType>
          <xsd:complexType name="Other"><xsd:sequence/></xsd:complexType>
          <xsd:complexType name="Sub">
            <xsd:complexContent>
              <xsd:extension base="Other"><xsd:sequence/></xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first { $0.name == "Sub" })
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "baseType" && $0.isBreaking })
    }

    func test_diff_complexType_baseDerivationKindChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Base">
            <xsd:sequence><xsd:element name="a" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Sub">
            <xsd:complexContent>
              <xsd:extension base="Base">
                <xsd:sequence><xsd:element name="b" type="xsd:string"/></xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Base">
            <xsd:sequence><xsd:element name="a" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Sub">
            <xsd:complexContent>
              <xsd:restriction base="Base">
                <xsd:sequence><xsd:element name="a" type="xsd:string"/></xsd:sequence>
              </xsd:restriction>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.complexTypeChanges.first { $0.name == "Sub" })
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "baseDerivationKind" && $0.isBreaking })
    }

    func test_diff_complexType_isAbstractFalseToTrue_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" abstract="false">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" abstract="true">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "isAbstract" && $0.isBreaking })
    }

    func test_diff_complexType_isAbstractTrueToFalse_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" abstract="true">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T" abstract="false">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "isAbstract" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    // MARK: - Complex type: existing element occurrence changes

    func test_diff_existingElement_minOccursIncreased_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" minOccurs="0"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" minOccurs="1"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "content.x.minOccurs" && $0.isBreaking })
    }

    func test_diff_existingElement_maxOccursReduced_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="5"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="2"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "content.x.maxOccurs" && $0.isBreaking })
    }

    func test_diff_existingElement_maxOccursWidened_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="2"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="10"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "content.x.maxOccurs" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    func test_diff_existingElement_maxOccursUnboundedToBounded_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="unbounded"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="3"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "content.x.maxOccurs" && $0.isBreaking })
    }

    func test_diff_existingElement_maxOccursBoundedToUnbounded_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="3"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence><xsd:element name="x" type="xsd:string" maxOccurs="unbounded"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "content.x.maxOccurs" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    // MARK: - Complex type: existing attribute changes

    func test_diff_existingAttribute_typeChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="a" type="xsd:string"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="a" type="xsd:integer"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "attribute.a.type" && $0.isBreaking })
    }

    func test_diff_existingAttribute_useChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="a" type="xsd:string" use="optional"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="T">
            <xsd:sequence/>
            <xsd:attribute name="a" type="xsd:string" use="required"/>
          </xsd:complexType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.complexTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "attribute.a.use" && $0.isBreaking })
    }

    // MARK: - Simple type: derivation, list, pattern, facets, union

    func test_diff_simpleType_derivationKindChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:list itemType="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "derivationKind" && $0.isBreaking })
    }

    func test_diff_simpleType_listItemTypeChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T"><xsd:list itemType="xsd:string"/></xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T"><xsd:list itemType="xsd:integer"/></xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "listItemType" && $0.isBreaking })
    }

    func test_diff_simpleType_patternAdded_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string">
              <xsd:pattern value="[A-Z]+"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "pattern" && $0.isBreaking })
    }

    func test_diff_simpleType_patternRemoved_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string">
              <xsd:pattern value="[A-Z]+"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "pattern" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    func test_diff_simpleType_facetsChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string">
              <xsd:minLength value="1"/>
              <xsd:maxLength value="10"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string">
              <xsd:minLength value="2"/>
              <xsd:maxLength value="10"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "facets" && $0.isBreaking })
    }

    func test_diff_simpleType_facetsAllPopulated_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:restriction base="xsd:decimal">
              <xsd:minLength value="1"/>
              <xsd:maxLength value="10"/>
              <xsd:length value="5"/>
              <xsd:pattern value=".*"/>
              <xsd:minInclusive value="0"/>
              <xsd:maxInclusive value="100"/>
              <xsd:minExclusive value="0"/>
              <xsd:maxExclusive value="100"/>
              <xsd:totalDigits value="5"/>
              <xsd:fractionDigits value="2"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        let facetChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "facets" })
        // Smoke-test the summary string contains all populated facets.
        if case .valueChanged(_, let toSummary) = facetChange.kind {
            XCTAssertTrue(toSummary.contains("minLength"))
            XCTAssertTrue(toSummary.contains("fractionDigits"))
        } else {
            XCTFail("Expected .valueChanged kind")
        }
    }

    func test_diff_simpleType_unionMembersChanged() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:union memberTypes="xsd:string xsd:integer"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="T">
            <xsd:union memberTypes="xsd:string xsd:decimal"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains {
            $0.fieldName == "unionMembers" && fieldIsRemoved($0, name: "xsd:integer") && $0.isBreaking
        })
        XCTAssertTrue(fieldChanges(entry).contains {
            $0.fieldName == "unionMembers" && fieldIsAdded($0, name: "xsd:decimal") && !$0.isBreaking
        })
    }

    // MARK: - Top-level element field changes

    func test_diff_topElement_nillableTrueToFalse_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" nillable="true"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" nillable="false"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.elementChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "nillable" && $0.isBreaking })
    }

    func test_diff_topElement_nillableFalseToTrue_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" nillable="false"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" nillable="true"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "nillable" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    func test_diff_topElement_isAbstractFalseToTrue_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" abstract="false"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" abstract="true"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "isAbstract" && $0.isBreaking })
    }

    func test_diff_topElement_substitutionGroupChanged_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="head1" type="xsd:string"/>
          <xsd:element name="head2" type="xsd:string"/>
          <xsd:element name="leaf" type="xsd:string" substitutionGroup="head1"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="head1" type="xsd:string"/>
          <xsd:element name="head2" type="xsd:string"/>
          <xsd:element name="leaf" type="xsd:string" substitutionGroup="head2"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first { $0.name == "leaf" })
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "substitutionGroup" && $0.isBreaking })
    }

    func test_diff_topElement_minOccursDecreased_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" minOccurs="2"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" minOccurs="1"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "minOccurs" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    func test_diff_topElement_maxOccursReduced_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" maxOccurs="5"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" maxOccurs="2"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first)
        XCTAssertTrue(fieldChanges(entry).contains { $0.fieldName == "maxOccurs" && $0.isBreaking })
    }

    func test_diff_topElement_maxOccursWidened_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" maxOccurs="2"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string" maxOccurs="unbounded"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        let entry = try XCTUnwrap(result.elementChanges.first)
        let fieldChange = try XCTUnwrap(fieldChanges(entry).first { $0.fieldName == "maxOccurs" })
        XCTAssertFalse(fieldChange.isBreaking)
    }

    // MARK: - Filtered views and helpers

    func test_breakingSimpleTypeChanges_filtersCorrectly() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="A">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="x"/>
              <xsd:enumeration value="y"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:simpleType name="B">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="z"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="A">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="x"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:simpleType name="B">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="z"/>
              <xsd:enumeration value="w"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertEqual(result.breakingSimpleTypeChanges.count, 1)
        XCTAssertEqual(result.breakingSimpleTypeChanges.first?.name, "A")
    }

    func test_breakingElementChanges_filtersCorrectly() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="kept" type="xsd:string"/>
          <xsd:element name="removed" type="xsd:string"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="kept" type="xsd:string"/>
          <xsd:element name="added" type="xsd:string"/>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertEqual(result.breakingElementChanges.count, 1)
        XCTAssertEqual(result.breakingElementChanges.first?.name, "removed")
    }

    func test_simpleType_added_isNotBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="New">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let result = try diff(old: old, new: new)
        XCTAssertFalse(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        if case .added = entry.change {} else { XCTFail("Expected .added") }
    }

    func test_simpleType_removed_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:simpleType name="Old">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.simpleTypeChanges.first)
        if case .removed = entry.change {} else { XCTFail("Expected .removed") }
    }

    func test_topElement_removed_isBreaking() throws {
        let old = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:element name="root" type="xsd:string"/>
        </xsd:schema>
        """
        let new = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let result = try diff(old: old, new: new)
        XCTAssertTrue(result.hasBreakingChanges)
        let entry = try XCTUnwrap(result.elementChanges.first)
        if case .removed = entry.change {} else { XCTFail("Expected .removed") }
    }
}
