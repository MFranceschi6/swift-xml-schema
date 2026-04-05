import XCTest
@testable import SwiftXMLSchema

// Tests for XMLSchemaVisitor and XMLSchemaWalker.
// Requires Swift 5.7+ (primary associated types, `some` parameter types).
// This file is excluded from Package@swift-5.6.swift.
final class XMLSchemaVisitorWalkerTests: XCTestCase {

    // MARK: - Fixture

    private static let xsd = """
    <?xml version="1.0" encoding="UTF-8"?>
    <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                targetNamespace="urn:vw"
                xmlns:tns="urn:vw">

      <xsd:simpleType name="Color">
        <xsd:restriction base="xsd:string">
          <xsd:enumeration value="red"/>
          <xsd:enumeration value="blue"/>
        </xsd:restriction>
      </xsd:simpleType>

      <xsd:attributeGroup name="MetaAttrs">
        <xsd:attribute name="id" type="xsd:string"/>
      </xsd:attributeGroup>

      <xsd:group name="ShapeFields">
        <xsd:sequence>
          <xsd:element name="width" type="xsd:decimal"/>
          <xsd:element name="height" type="xsd:decimal"/>
        </xsd:sequence>
      </xsd:group>

      <xsd:complexType name="Shape">
        <xsd:sequence>
          <xsd:element name="color" type="tns:Color"/>
          <xsd:choice>
            <xsd:element name="circle" type="xsd:string"/>
            <xsd:element name="rect" type="xsd:string"/>
          </xsd:choice>
        </xsd:sequence>
        <xsd:attributeGroup ref="tns:MetaAttrs"/>
      </xsd:complexType>

      <xsd:complexType name="Canvas">
        <xsd:complexContent>
          <xsd:extension base="tns:Shape">
            <xsd:sequence>
              <xsd:element name="title" type="xsd:string"/>
            </xsd:sequence>
          </xsd:extension>
        </xsd:complexContent>
      </xsd:complexType>

      <xsd:element name="shape" type="tns:Shape"/>
      <xsd:element name="canvas" type="tns:Canvas"/>
      <xsd:attribute name="globalId" type="xsd:string"/>

    </xsd:schema>
    """

    private func makeNormalized() throws -> XMLNormalizedSchemaSet {
        let set = try XMLSchemaDocumentParser().parse(data: Data(Self.xsd.utf8))
        return try XMLSchemaNormalizer().normalize(set)
    }

    // MARK: - Default no-op visitor

    // A struct that only cares about complexType names, using the default no-ops for everything else.
    struct ComplexTypeNameCollector: XMLSchemaVisitor {
        var names: [String] = []
        mutating func visitComplexType(_ complexType: XMLNormalizedComplexType) {
            names.append(complexType.name)
        }
    }

    func test_defaultNoOpVisitor_onlyCollectsOverriddenMethod() throws {
        let n = try makeNormalized()
        var collector = ComplexTypeNameCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertEqual(Set(collector.names), ["Shape", "Canvas"])
    }

    // MARK: - Schema visits

    func test_visitSchema_calledForEachSchema() throws {
        let n = try makeNormalized()
        struct SchemaCounter: XMLSchemaVisitor {
            var count = 0
            mutating func visitSchema(_ schema: XMLNormalizedSchema) { count += 1 }
        }
        var counter = SchemaCounter()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &counter)
        XCTAssertEqual(counter.count, n.schemas.count)
    }

    // MARK: - Element visits

    func test_visitElement_calledForTopLevelElements() throws {
        let n = try makeNormalized()
        struct ElementCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitElement(_ element: XMLNormalizedElementDeclaration) {
                names.append(element.name)
            }
        }
        var collector = ElementCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertTrue(collector.names.contains("shape"))
        XCTAssertTrue(collector.names.contains("canvas"))
    }

    // MARK: - SimpleType visits

    func test_visitSimpleType_calledForSimpleTypes() throws {
        let n = try makeNormalized()
        struct SimpleTypeCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitSimpleType(_ simpleType: XMLNormalizedSimpleType) {
                names.append(simpleType.name)
            }
        }
        var collector = SimpleTypeCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertTrue(collector.names.contains("Color"))
    }

    // MARK: - Attribute visits

    func test_visitAttribute_calledForTopLevelAttributes() throws {
        let n = try makeNormalized()
        struct AttrCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitAttribute(_ attribute: XMLNormalizedAttributeDefinition) {
                names.append(attribute.name)
            }
        }
        var collector = AttrCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertTrue(collector.names.contains("globalId"))
    }

    // MARK: - AttributeGroup visits

    func test_visitAttributeGroup_calledForAttributeGroups() throws {
        let n = try makeNormalized()
        struct AGCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitAttributeGroup(_ attributeGroup: XMLNormalizedAttributeGroup) {
                names.append(attributeGroup.name)
            }
        }
        var collector = AGCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertTrue(collector.names.contains("MetaAttrs"))
    }

    // MARK: - ModelGroup visits

    func test_visitModelGroup_calledForModelGroups() throws {
        let n = try makeNormalized()
        struct MGCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitModelGroup(_ modelGroup: XMLNormalizedModelGroup) {
                names.append(modelGroup.name)
            }
        }
        var collector = MGCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        XCTAssertTrue(collector.names.contains("ShapeFields"))
    }

    // MARK: - Content recursion

    func test_visitElementUse_calledForContentElements() throws {
        let n = try makeNormalized()
        struct UseCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitElementUse(_ elementUse: XMLNormalizedElementUse) {
                names.append(elementUse.name)
            }
        }
        var collector = UseCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        // "color", "title" are direct sequence elements; "circle" and "rect" are inside a choice
        XCTAssertTrue(collector.names.contains("color"))
        XCTAssertTrue(collector.names.contains("circle"))
        XCTAssertTrue(collector.names.contains("rect"))
    }

    func test_visitChoiceGroup_calledForChoicesInContent() throws {
        let n = try makeNormalized()
        struct ChoiceCounter: XMLSchemaVisitor {
            var count = 0
            mutating func visitChoiceGroup(_ choice: XMLNormalizedChoiceGroup) { count += 1 }
        }
        var counter = ChoiceCounter()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &counter)
        XCTAssertGreaterThan(counter.count, 0)
    }

    func test_visitAttributeUse_calledForEffectiveAttributes() throws {
        let n = try makeNormalized()
        struct AttrUseCollector: XMLSchemaVisitor {
            var names: [String] = []
            mutating func visitAttributeUse(_ attributeUse: XMLNormalizedAttributeUse) {
                names.append(attributeUse.name)
            }
        }
        var collector = AttrUseCollector()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &collector)
        // "id" is from MetaAttrs, inherited by both Shape and Canvas
        XCTAssertTrue(collector.names.contains("id"))
    }

    // MARK: - Empty schema set

    func test_walkerOnEmptySchemaSet_callsNothing() throws {
        let n = XMLNormalizedSchemaSet(schemas: [])
        struct Counter: XMLSchemaVisitor {
            var total = 0
            mutating func visitSchema(_ schema: XMLNormalizedSchema) { total += 1 }
            mutating func visitElement(_ element: XMLNormalizedElementDeclaration) { total += 1 }
            mutating func visitComplexType(_ complexType: XMLNormalizedComplexType) { total += 1 }
        }
        var counter = Counter()
        XMLSchemaWalker(schemaSet: n).walkComponents(visitor: &counter)
        XCTAssertEqual(counter.total, 0)
    }

    // MARK: - Result-producing visitor

    // Visitor with Result == [String] — confirms non-Void result type compiles and is usable.
    struct ElementNameMapper: XMLSchemaVisitor {
        func visitElement(_ element: XMLNormalizedElementDeclaration) -> String {
            element.name
        }
        // All other methods must be implemented when Result != Void.
        func visitSchema(_ schema: XMLNormalizedSchema) -> String { "" }
        func visitComplexType(_ complexType: XMLNormalizedComplexType) -> String { "" }
        func visitSimpleType(_ simpleType: XMLNormalizedSimpleType) -> String { "" }
        func visitAttribute(_ attribute: XMLNormalizedAttributeDefinition) -> String { "" }
        func visitAttributeGroup(_ attributeGroup: XMLNormalizedAttributeGroup) -> String { "" }
        func visitModelGroup(_ modelGroup: XMLNormalizedModelGroup) -> String { "" }
        func visitElementUse(_ elementUse: XMLNormalizedElementUse) -> String { "" }
        func visitChoiceGroup(_ choice: XMLNormalizedChoiceGroup) -> String { "" }
        func visitAttributeUse(_ attributeUse: XMLNormalizedAttributeUse) -> String { "" }
    }

    func test_nonVoidVisitor_compilesAndCanBeUsedManually() throws {
        let n = try makeNormalized()
        let mapper = ElementNameMapper()
        var names: [String] = []
        for schema in n.schemas {
            for element in schema.elements {
                let result = mapper.visitElement(element)
                names.append(result)
            }
        }
        XCTAssertTrue(names.contains("shape"))
        XCTAssertTrue(names.contains("canvas"))
    }
}
