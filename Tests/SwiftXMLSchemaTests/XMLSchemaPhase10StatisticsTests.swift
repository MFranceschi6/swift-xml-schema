import Foundation
import SwiftXMLSchema
import XCTest

final class XMLSchemaPhase10StatisticsTests: XCTestCase {

    // MARK: - Helpers

    private func normalized(from xsd: String) throws -> XMLNormalizedSchemaSet {
        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        return try XMLSchemaNormalizer().normalize(schemaSet)
    }

    // MARK: - Empty schema

    func test_stats_emptySchema_allZero() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t"/>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.totalComplexTypes, 0)
        XCTAssertEqual(stats.totalSimpleTypes, 0)
        XCTAssertEqual(stats.totalElements, 0)
        XCTAssertEqual(stats.totalAttributeDefinitions, 0)
        XCTAssertEqual(stats.totalAttributeGroups, 0)
        XCTAssertEqual(stats.totalModelGroups, 0)
        XCTAssertEqual(stats.maxComplexTypeInheritanceDepth, 0)
        XCTAssertEqual(stats.maxSimpleTypeInheritanceDepth, 0)
        XCTAssertTrue(stats.unreferencedComplexTypeNames.isEmpty)
        XCTAssertTrue(stats.unreferencedSimpleTypeNames.isEmpty)
    }

    // MARK: - Total counts

    func test_stats_totalCounts() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:tns="urn:t" targetNamespace="urn:t">
          <xsd:complexType name="OrderType">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="LineItemType">
            <xsd:sequence>
              <xsd:element name="sku" type="xsd:string"/>
            </xsd:sequence>
          </xsd:complexType>
          <xsd:simpleType name="StatusType">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="open"/>
              <xsd:enumeration value="closed"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:element name="Order" type="tns:OrderType"/>
          <xsd:element name="LineItem" type="tns:LineItemType"/>
          <xsd:attribute name="version" type="xsd:string"/>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.totalComplexTypes, 2)
        XCTAssertEqual(stats.totalSimpleTypes, 1)
        XCTAssertEqual(stats.totalElements, 2)
        XCTAssertEqual(stats.totalAttributeDefinitions, 1)
    }

    // MARK: - Namespace breakdown

    func test_stats_namespaceBreakdown_singleNamespace() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    xmlns:tns="urn:orders" targetNamespace="urn:orders">
          <xsd:complexType name="OrderType">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:element name="Order" type="tns:OrderType"/>
          <xsd:simpleType name="Currency">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.namespaceBreakdown.count, 1)
        let ns = try XCTUnwrap(stats.namespaceBreakdown.first)
        XCTAssertEqual(ns.namespace, "urn:orders")
        XCTAssertEqual(ns.complexTypeCount, 1)
        XCTAssertEqual(ns.simpleTypeCount, 1)
        XCTAssertEqual(ns.elementCount, 1)
    }

    func test_stats_namespaceBreakdown_noNamespace() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:complexType name="Foo">
            <xsd:sequence><xsd:element name="x" type="xsd:int"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.namespaceBreakdown.count, 1)
        XCTAssertNil(stats.namespaceBreakdown.first?.namespace)
        XCTAssertEqual(stats.namespaceBreakdown.first?.complexTypeCount, 1)
    }

    // MARK: - Inheritance depth

    func test_stats_inheritanceDepth_rootType_isZero() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Base">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.maxComplexTypeInheritanceDepth, 0)
    }

    func test_stats_inheritanceDepth_oneLevelDeep() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:complexType name="Base">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Child">
            <xsd:complexContent>
              <xsd:extension base="tns:Base">
                <xsd:sequence><xsd:element name="extra" type="xsd:string"/></xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.maxComplexTypeInheritanceDepth, 1)
    }

    func test_stats_inheritanceDepth_twoLevelsDeep() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:complexType name="A">
            <xsd:sequence><xsd:element name="a" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="B">
            <xsd:complexContent>
              <xsd:extension base="tns:A">
                <xsd:sequence><xsd:element name="b" type="xsd:string"/></xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
          <xsd:complexType name="C">
            <xsd:complexContent>
              <xsd:extension base="tns:B">
                <xsd:sequence><xsd:element name="c" type="xsd:string"/></xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.maxComplexTypeInheritanceDepth, 2)
    }

    func test_stats_simpleTypeInheritanceDepth() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:simpleType name="BaseString">
            <xsd:restriction base="xsd:string">
              <xsd:maxLength value="100"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:simpleType name="ShortString">
            <xsd:restriction base="tns:BaseString">
              <xsd:maxLength value="20"/>
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.maxSimpleTypeInheritanceDepth, 1)
    }

    // MARK: - Unreferenced types

    func test_stats_unreferencedComplexType_detected() throws {
        // OrphanType is not referenced by any element or other type
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:complexType name="UsedType">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="OrphanType">
            <xsd:sequence><xsd:element name="x" type="xsd:int"/></xsd:sequence>
          </xsd:complexType>
          <xsd:element name="Root" type="tns:UsedType"/>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertTrue(stats.unreferencedComplexTypeNames.contains("urn:t:OrphanType"))
        XCTAssertFalse(stats.unreferencedComplexTypeNames.contains("urn:t:UsedType"))
    }

    func test_stats_unreferencedSimpleType_detected() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:simpleType name="UsedEnum">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="a"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:simpleType name="OrphanEnum">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="x"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:element name="Root" type="tns:UsedEnum"/>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertTrue(stats.unreferencedSimpleTypeNames.contains("urn:t:OrphanEnum"))
        XCTAssertFalse(stats.unreferencedSimpleTypeNames.contains("urn:t:UsedEnum"))
    }

    func test_stats_baseType_isNotUnreferenced() throws {
        // Base is only referenced as a base — not by any element typeQName — but is still referenced
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:complexType name="Base">
            <xsd:sequence><xsd:element name="id" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Child">
            <xsd:complexContent>
              <xsd:extension base="tns:Base">
                <xsd:sequence><xsd:element name="extra" type="xsd:string"/></xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
          <xsd:element name="Root" type="tns:Child"/>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertFalse(stats.unreferencedComplexTypeNames.contains("urn:t:Base"))
        XCTAssertFalse(stats.unreferencedComplexTypeNames.contains("urn:t:Child"))
    }

    func test_stats_noUnreferencedTypes_whenAllReferenced() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                    targetNamespace="urn:t" xmlns:tns="urn:t">
          <xsd:complexType name="OrderType">
            <xsd:sequence><xsd:element name="status" type="tns:StatusEnum"/></xsd:sequence>
          </xsd:complexType>
          <xsd:simpleType name="StatusEnum">
            <xsd:restriction base="xsd:string">
              <xsd:enumeration value="open"/>
            </xsd:restriction>
          </xsd:simpleType>
          <xsd:element name="Order" type="tns:OrderType"/>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertTrue(stats.unreferencedComplexTypeNames.isEmpty)
        XCTAssertTrue(stats.unreferencedSimpleTypeNames.isEmpty)
    }

    func test_stats_unreferencedNames_areSorted() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:complexType name="Zeta">
            <xsd:sequence><xsd:element name="x" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Alpha">
            <xsd:sequence><xsd:element name="y" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
          <xsd:complexType name="Mu">
            <xsd:sequence><xsd:element name="z" type="xsd:string"/></xsd:sequence>
          </xsd:complexType>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.unreferencedComplexTypeNames, stats.unreferencedComplexTypeNames.sorted())
    }

    // MARK: - Namespace breakdown completeness

    func test_stats_namespaceBreakdown_countsAttributeGroups() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:t">
          <xsd:attributeGroup name="CommonAttrs">
            <xsd:attribute name="lang" type="xsd:language"/>
          </xsd:attributeGroup>
          <xsd:group name="CommonGroup">
            <xsd:sequence>
              <xsd:element name="note" type="xsd:string"/>
            </xsd:sequence>
          </xsd:group>
        </xsd:schema>
        """
        let stats = try normalized(from: xsd).statistics
        XCTAssertEqual(stats.totalAttributeGroups, 1)
        XCTAssertEqual(stats.totalModelGroups, 1)
        XCTAssertEqual(stats.namespaceBreakdown.first?.attributeGroupCount, 1)
        XCTAssertEqual(stats.namespaceBreakdown.first?.modelGroupCount, 1)
    }
}
