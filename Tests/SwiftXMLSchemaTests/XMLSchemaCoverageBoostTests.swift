import Foundation
import SwiftXMLCoder
import SwiftXMLSchema
import XCTest
// swiftlint:disable function_body_length optional_data_string_conversion

final class XMLSchemaCoverageBoostTests: XCTestCase {
    func test_rawModelTypes_exposeComputedViewsAndInitializers() {
        let annotation = XMLSchemaAnnotation(documentation: ["Docs"], appinfo: ["Meta"])
        let emptyAnnotation = XMLSchemaAnnotation()
        let builtQName = XMLQualifiedName(
            localName: "Value",
            namespaceURI: "urn:test",
            prefix: "tns"
        )
        let defaultBounds = XMLSchemaOccurrenceBounds.from(minOccurs: nil, maxOccurs: nil)
        let unboundedBounds = XMLSchemaOccurrenceBounds.from(minOccurs: 2, maxOccurs: "unbounded")
        let numericBounds = XMLSchemaOccurrenceBounds.from(minOccurs: 0, maxOccurs: "3")
        let wildcard = XMLSchemaWildcard(
            kind: .element,
            namespaceConstraint: "##other",
            processContents: .lax,
            minOccurs: 0,
            maxOccurs: "unbounded"
        )
        let groupReference = XMLSchemaGroupReference(refQName: builtQName, minOccurs: 1, maxOccurs: "2")
        let simpleType = XMLSchemaSimpleType(
            annotation: annotation,
            name: "Code",
            baseQName: builtQName,
            enumerationValues: ["A", "B"],
            pattern: "[A-Z]",
            facets: XMLSchemaFacetSet(pattern: "[A-Z]"),
            derivationKind: .union,
            listItemQName: builtQName,
            unionMemberQNames: [builtQName]
        )
        let anonymousSimpleType = XMLSchemaAnonymousSimpleType(
            annotation: annotation,
            baseQName: builtQName,
            enumerationValues: ["A"],
            pattern: "[A]"
        )
        let attribute = XMLSchemaAttribute(
            annotation: annotation,
            name: "lang",
            typeQName: builtQName,
            use: .required,
            defaultValue: "en",
            fixedValue: "EN",
            inlineSimpleType: anonymousSimpleType
        )
        let attributeRef = XMLSchemaAttributeReference(
            refQName: builtQName,
            use: .optional,
            defaultValue: "fr",
            fixedValue: "FR",
            annotation: annotation
        )
        let child = XMLSchemaElement(
            annotation: annotation,
            name: "child",
            typeQName: builtQName,
            refQName: nil,
            minOccurs: 0,
            maxOccurs: "2",
            nillable: true,
            defaultValue: "fallback",
            fixedValue: "fixed",
            isAbstract: true,
            substitutionGroup: builtQName,
            inlineSimpleType: anonymousSimpleType
        )
        let choice = XMLSchemaChoiceGroup(
            elements: [child],
            minOccurs: 0,
            maxOccurs: "1",
            groupReferences: [groupReference],
            anyElements: [wildcard]
        )
        let anonymousComplexType = XMLSchemaAnonymousComplexType(
            annotation: annotation,
            baseQName: builtQName,
            baseDerivationKind: .extension,
            simpleContentBaseQName: builtQName,
            simpleContentDerivationKind: .restriction,
            isAbstract: true,
            sequence: [child],
            choiceGroups: [choice],
            groupReferences: [groupReference],
            anyElements: [wildcard],
            attributes: [attribute],
            attributeRefs: [attributeRef],
            attributeGroupRefs: [builtQName],
            anyAttribute: XMLSchemaWildcard(kind: .attribute, namespaceConstraint: "##any")
        )
        let inlineSequenceElement = XMLSchemaElement(
            name: "inline",
            typeQName: nil,
            refQName: nil,
            minOccurs: nil,
            maxOccurs: nil,
            nillable: false,
            inlineSequenceElements: [child]
        )
        let complexType = XMLSchemaComplexType(
            annotation: annotation,
            name: "Container",
            baseQName: builtQName,
            baseDerivationKind: .extension,
            simpleContentBaseQName: builtQName,
            simpleContentDerivationKind: .restriction,
            isAbstract: true,
            sequence: [child],
            choice: [child],
            groupReferences: [groupReference],
            anyElements: [wildcard],
            attributes: [attribute],
            attributeRefs: [attributeRef],
            attributeGroupRefs: [builtQName],
            anyAttribute: XMLSchemaWildcard(kind: .attribute, namespaceConstraint: "##other")
        )
        let attributeGroup = XMLSchemaAttributeGroup(name: "Attrs", attributes: [attribute], attributeRefs: [attributeRef], attributeGroupRefs: [builtQName])
        let modelGroup = XMLSchemaModelGroup(
            name: "Items",
            sequence: [child],
            choiceGroups: [choice],
            groupReferences: [groupReference],
            anyElements: [wildcard]
        )
        let schema = XMLSchema(
            annotation: annotation,
            targetNamespace: "urn:test",
            imports: [XMLSchemaImport(namespace: "urn:other", schemaLocation: "other.xsd")],
            includes: [XMLSchemaInclude(schemaLocation: "local.xsd")],
            elements: [child],
            attributeDefinitions: [attribute],
            attributeGroups: [attributeGroup],
            modelGroups: [modelGroup],
            complexTypes: [complexType],
            simpleTypes: [simpleType]
        )
        let mergedSchemaSet = XMLSchemaSet(schemas: [schema]).merging(XMLSchemaSet(schemas: [schema]))

        XCTAssertTrue(emptyAnnotation.isEmpty)
        XCTAssertFalse(annotation.isEmpty)
        XCTAssertEqual(defaultBounds, XMLSchemaOccurrenceBounds())
        XCTAssertEqual(unboundedBounds.minOccurs, 2)
        XCTAssertNil(unboundedBounds.maxOccurs)
        XCTAssertEqual(numericBounds.maxOccurs, 3)
        XCTAssertEqual(wildcard.occurrenceBounds.minOccurs, 0)
        XCTAssertNil(wildcard.occurrenceBounds.maxOccurs)
        XCTAssertEqual(groupReference.occurrenceBounds.maxOccurs, 2)
        XCTAssertEqual(choice.elements.map(\.name), ["child"])
        XCTAssertEqual(choice.groupReferences.map(\.refQName.qualifiedName), ["tns:Value"])
        XCTAssertEqual(choice.anyElements.first?.namespaceConstraint, "##other")
        XCTAssertEqual(choice.occurrenceBounds.minOccurs, 0)
        XCTAssertEqual(anonymousComplexType.sequence.map(\.name), ["child"])
        XCTAssertEqual(anonymousComplexType.choiceGroups.first?.elements.map(\.name), ["child"])
        XCTAssertEqual(anonymousComplexType.groupReferences.first?.refQName.localName, "Value")
        XCTAssertEqual(anonymousComplexType.anyElements.first?.processContents, .lax)
        XCTAssertEqual(inlineSequenceElement.inlineSequenceElements.map(\.name), ["child"])
        XCTAssertEqual(complexType.sequence.map(\.name), ["child"])
        XCTAssertEqual(complexType.choice.map(\.name), ["child"])
        XCTAssertEqual(complexType.groupReferences.first?.refQName.localName, "Value")
        XCTAssertEqual(complexType.anyElements.first?.namespaceConstraint, "##other")
        XCTAssertEqual(modelGroup.sequence.map(\.name), ["child"])
        XCTAssertEqual(modelGroup.choiceGroups.first?.elements.map(\.name), ["child"])
        XCTAssertEqual(modelGroup.groupReferences.first?.refQName.localName, "Value")
        XCTAssertEqual(modelGroup.anyElements.first?.processContents, .lax)
        XCTAssertFalse(XMLSchemaFacetSet(pattern: "x").isEmpty)
        XCTAssertEqual(simpleType.unionMemberQNames.map(\.localName), ["Value"])
        XCTAssertEqual(attributeGroup.attributes.map(\.name), ["lang"])
        XCTAssertEqual(mergedSchemaSet.schemas.count, 2)
        XCTAssertEqual(schema.annotation?.documentation, ["Docs"])
    }

    func test_normalizedTypes_andLookupApis_coverFallbackPaths() {
        let annotation = XMLSchemaAnnotation(documentation: ["Docs"], appinfo: ["Meta"])
        let componentID = XMLSchemaComponentID(rawValue: "component")
        let qName = XMLQualifiedName(localName: "Animal", namespaceURI: "urn:animals", prefix: "tns")
        let elementUse = XMLNormalizedElementUse(
            componentID: componentID,
            annotation: annotation,
            name: "dog",
            namespaceURI: "urn:animals",
            typeQName: qName,
            nillable: false,
            defaultValue: "dog",
            fixedValue: "DOG",
            isAbstract: false,
            substitutionGroup: qName,
            occurrenceBounds: XMLSchemaOccurrenceBounds(minOccurs: 0, maxOccurs: 2)
        )
        let choice = XMLNormalizedChoiceGroup(
            content: [.element(elementUse), .wildcard(XMLSchemaWildcard(kind: .element, namespaceConstraint: "##any"))],
            occurrenceBounds: XMLSchemaOccurrenceBounds(minOccurs: 0, maxOccurs: 1)
        )
        let attributeUse = XMLNormalizedAttributeUse(
            componentID: componentID,
            annotation: annotation,
            name: "lang",
            namespaceURI: "urn:animals",
            typeQName: qName,
            use: .required,
            defaultValue: "en",
            fixedValue: "EN"
        )
        let attributeDefinition = XMLNormalizedAttributeDefinition(
            componentID: componentID,
            annotation: annotation,
            name: "lang",
            namespaceURI: "urn:animals",
            typeQName: qName,
            use: .optional,
            defaultValue: "en",
            fixedValue: "EN"
        )
        let elementDeclaration = XMLNormalizedElementDeclaration(
            componentID: componentID,
            annotation: annotation,
            name: "dog",
            namespaceURI: "urn:animals",
            typeQName: qName,
            nillable: false,
            defaultValue: "dog",
            fixedValue: "DOG",
            isAbstract: false,
            substitutionGroup: qName,
            occurrenceBounds: XMLSchemaOccurrenceBounds()
        )
        let rootDeclaration = XMLNormalizedElementDeclaration(
            componentID: XMLSchemaComponentID(rawValue: "root"),
            annotation: nil,
            name: "animal",
            namespaceURI: "urn:animals",
            typeQName: qName,
            nillable: false,
            defaultValue: nil,
            fixedValue: nil,
            isAbstract: true,
            substitutionGroup: nil,
            occurrenceBounds: XMLSchemaOccurrenceBounds()
        )
        let simpleType = XMLNormalizedSimpleType(
            componentID: componentID,
            annotation: annotation,
            name: "Animal",
            namespaceURI: "urn:animals",
            baseQName: qName,
            enumerationValues: ["dog"],
            pattern: "[a-z]+",
            facets: XMLSchemaFacetSet(pattern: "[a-z]+"),
            derivationKind: .restriction,
            listItemQName: nil,
            unionMemberQNames: [qName]
        )
        let complexType = XMLNormalizedComplexType(
            componentID: componentID,
            annotation: annotation,
            name: "Animal",
            namespaceURI: "urn:animals",
            baseQName: qName,
            baseDerivationKind: .extension,
            simpleContentBaseQName: qName,
            simpleContentDerivationKind: .restriction,
            inheritedComplexTypeQName: qName,
            effectiveSimpleContentValueTypeQName: qName,
            declaredContent: [.element(elementUse), .choice(choice)],
            effectiveContent: [.element(elementUse), .choice(choice), .wildcard(XMLSchemaWildcard(kind: .element, namespaceConstraint: "##other"))],
            declaredAttributes: [attributeUse],
            effectiveAttributes: [attributeUse],
            anyAttribute: XMLSchemaWildcard(kind: .attribute, namespaceConstraint: "##any"),
            isAbstract: true,
            isAnonymous: false
        )
        let attributeGroup = XMLNormalizedAttributeGroup(
            componentID: componentID,
            name: "Attrs",
            namespaceURI: "urn:animals",
            attributes: [attributeUse]
        )
        let modelGroup = XMLNormalizedModelGroup(
            componentID: componentID,
            name: "Items",
            namespaceURI: "urn:animals",
            content: [.element(elementUse), .choice(choice), .wildcard(XMLSchemaWildcard(kind: .element, namespaceConstraint: "##other"))]
        )
        let animalsSchema = XMLNormalizedSchema(
            annotation: annotation,
            targetNamespace: "urn:animals",
            elements: [rootDeclaration, elementDeclaration],
            attributeDefinitions: [attributeDefinition],
            attributeGroups: [attributeGroup],
            modelGroups: [modelGroup],
            complexTypes: [complexType],
            simpleTypes: [simpleType]
        )
        let fallbackSchema = XMLNormalizedSchema(
            targetNamespace: "urn:fallback",
            elements: [
                XMLNormalizedElementDeclaration(
                    componentID: XMLSchemaComponentID(rawValue: "fallback"),
                    annotation: nil,
                    name: "fallback",
                    namespaceURI: "urn:fallback",
                    typeQName: nil,
                    nillable: false,
                    defaultValue: nil,
                    fixedValue: nil,
                    isAbstract: false,
                    substitutionGroup: nil,
                    occurrenceBounds: XMLSchemaOccurrenceBounds()
                )
            ],
            attributeDefinitions: [],
            attributeGroups: [],
            modelGroups: [],
            complexTypes: [],
            simpleTypes: []
        )
        let schemaSet = XMLNormalizedSchemaSet(schemas: [animalsSchema, fallbackSchema])

        XCTAssertEqual(choice.elements.map(\.name), ["dog"])
        XCTAssertTrue(choice.choiceGroups.isEmpty)
        XCTAssertEqual(choice.anyElements.first?.namespaceConstraint, "##any")
        XCTAssertEqual(modelGroup.sequence.map(\.name), ["dog"])
        XCTAssertEqual(modelGroup.choiceGroups.first?.elements.map(\.name), ["dog"])
        XCTAssertEqual(modelGroup.anyElements.first?.namespaceConstraint, "##other")
        XCTAssertEqual(complexType.declaredSequence.map(\.name), ["dog"])
        XCTAssertEqual(complexType.declaredChoiceGroups.count, 1)
        XCTAssertEqual(complexType.declaredAnyElements.count, 0)
        XCTAssertEqual(complexType.effectiveSequence.map(\.name), ["dog"])
        XCTAssertEqual(complexType.effectiveChoiceGroups.count, 1)
        XCTAssertEqual(complexType.effectiveAnyElements.first?.namespaceConstraint, "##other")

        XCTAssertEqual(schemaSet.element(named: "dog", namespaceURI: "urn:animals")?.fixedValue, "DOG")
        XCTAssertEqual(schemaSet.element(named: "fallback", namespaceURI: nil)?.name, "fallback")
        XCTAssertEqual(schemaSet.complexType(named: "Animal", namespaceURI: "urn:missing")?.name, "Animal")
        XCTAssertEqual(schemaSet.complexType(named: "Animal", namespaceURI: "urn:animals")?.isAbstract, true)
        XCTAssertEqual(schemaSet.simpleType(named: "Animal", namespaceURI: "urn:missing")?.name, "Animal")
        XCTAssertEqual(schemaSet.simpleType(named: "Animal", namespaceURI: nil)?.pattern, "[a-z]+")
        XCTAssertEqual(schemaSet.attribute(named: "lang", namespaceURI: "urn:missing")?.name, "lang")
        XCTAssertEqual(schemaSet.attribute(named: "lang", namespaceURI: nil)?.defaultValue, "en")
        XCTAssertEqual(schemaSet.attributeGroup(named: "Attrs", namespaceURI: "urn:missing")?.name, "Attrs")
        XCTAssertEqual(schemaSet.attributeGroup(named: "Attrs", namespaceURI: nil)?.attributes.count, 1)
        XCTAssertEqual(schemaSet.modelGroup(named: "Items", namespaceURI: "urn:missing")?.name, "Items")
        XCTAssertEqual(schemaSet.modelGroup(named: "Items", namespaceURI: nil)?.sequence.map(\.name), ["dog"])
        XCTAssertEqual(schemaSet.rootElementBinding(forTypeNamed: "Animal", namespaceURI: "urn:missing")?.name, "animal")
        XCTAssertEqual(schemaSet.rootElementBinding(forTypeNamed: "Animal", namespaceURI: "urn:animals")?.name, "animal")
        XCTAssertEqual(schemaSet.substitutionGroupMembers(ofLocalName: "Animal", namespaceURI: "urn:animals").map(\.name), ["dog"])
        XCTAssertNil(schemaSet.element(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.complexType(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.simpleType(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.attribute(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.attributeGroup(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.modelGroup(named: "missing", namespaceURI: nil))
        XCTAssertNil(schemaSet.rootElementBinding(forTypeNamed: "missing", namespaceURI: nil))
        XCTAssertTrue(schemaSet.substitutionGroupMembers(ofLocalName: "missing", namespaceURI: nil).isEmpty)
    }

    func test_parsingErrorsAndLocalResolver_coverFailureAndSuccessPaths() throws {
        XCTAssertEqual(
            XMLSchemaParsingError.invalidDocument(message: "broken").description,
            "invalidDocument: broken"
        )
        XCTAssertEqual(
            XMLSchemaParsingError.invalidSchema(name: "Order", message: nil).description,
            "invalidSchema(Order): <nil>"
        )
        XCTAssertEqual(
            XMLSchemaParsingError.unresolvedReference(name: nil, message: "missing").description,
            "unresolvedReference: missing"
        )
        XCTAssertEqual(
            XMLSchemaParsingError.resourceResolutionFailed(schemaLocation: "file.xsd", message: "bad").description,
            "resourceResolutionFailed(file.xsd): bad"
        )
        XCTAssertEqual(
            XMLSchemaParsingError.other(message: nil).description,
            "other: <nil>"
        )

        let resolver = LocalFileXMLSchemaResourceResolver()
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let schemaURL = tempDirectory.appendingPathComponent("schema.xsd")
        try Data("<xsd:schema/>".utf8).write(to: schemaURL)

        let resolvedFromFile = try resolver.resolve(schemaLocation: "nested/file.xsd", relativeTo: schemaURL)
        let resolvedFromDirectory = try resolver.resolve(schemaLocation: "nested/file.xsd", relativeTo: tempDirectory)
        let loadedData = try resolver.loadSchemaData(from: schemaURL)

        XCTAssertTrue(resolvedFromFile.path.hasSuffix("nested/file.xsd"))
        XCTAssertTrue(resolvedFromDirectory.path.hasSuffix("nested/file.xsd"))
        XCTAssertEqual(String(decoding: loadedData, as: UTF8.self), "<xsd:schema/>")

        XCTAssertThrowsError(try resolver.resolve(schemaLocation: "https://example.com/schema.xsd", relativeTo: schemaURL))
        XCTAssertThrowsError(try resolver.resolve(schemaLocation: "child.xsd", relativeTo: nil))
        XCTAssertThrowsError(
            try resolver.resolve(
                schemaLocation: "child.xsd",
                relativeTo: URL(string: "https://example.com/root.xsd")
            )
        )
        XCTAssertThrowsError(try resolver.loadSchemaData(from: tempDirectory.appendingPathComponent("missing.xsd")))
    }

    func test_documentParserConvenienceOverloads_areCovered() throws {
        struct StubResolver: XMLSchemaResourceResolver {
            let data: Data

            func resolve(schemaLocation: String, relativeTo sourceURL: URL?) throws -> URL {
                URL(fileURLWithPath: schemaLocation, relativeTo: sourceURL).standardizedFileURL
            }

            func loadSchemaData(from url: URL) throws -> Data {
                data
            }
        }

        let xsd = Data("""
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:test">
          <xsd:element name="value" type="xsd:string"/>
        </xsd:schema>
        """.utf8)
        let parser = XMLSchemaDocumentParser(resourceResolver: StubResolver(data: xsd))
        let sourceURL = URL(fileURLWithPath: "/tmp/schema.xsd")

        let parsedFromData = try parser.parse(data: xsd)
        let parsedFromDataAndURL = try parser.parse(data: xsd, sourceURL: sourceURL)
        let parsedFromURL = try parser.parse(url: sourceURL)

        XCTAssertEqual(parsedFromData.schemas.first?.elements.map(\.name), ["value"])
        XCTAssertEqual(parsedFromDataAndURL.schemas.first?.targetNamespace, "urn:test")
        XCTAssertEqual(parsedFromURL.schemas.first?.elements.first?.name, "value")
    }

    func test_normalizer_withoutTargetNamespace_usesFallbackResolvers() throws {
        let xsd = """
        <xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">
          <xsd:attribute name="shared" type="xsd:string"/>
          <xsd:attributeGroup name="SharedAttrs">
            <xsd:attribute ref="shared"/>
          </xsd:attributeGroup>
          <xsd:group name="SharedGroup">
            <xsd:sequence>
              <xsd:element name="id" type="xsd:string"/>
            </xsd:sequence>
          </xsd:group>
          <xsd:simpleType name="Code">
            <xsd:restriction base="xsd:string"/>
          </xsd:simpleType>
          <xsd:complexType name="Base">
            <xsd:sequence>
              <xsd:group ref="SharedGroup"/>
            </xsd:sequence>
            <xsd:attributeGroup ref="SharedAttrs"/>
          </xsd:complexType>
          <xsd:complexType name="Derived">
            <xsd:complexContent>
              <xsd:extension base="Base">
                <xsd:sequence>
                  <xsd:element name="code" type="Code"/>
                </xsd:sequence>
              </xsd:extension>
            </xsd:complexContent>
          </xsd:complexType>
          <xsd:element name="base" type="Base"/>
          <xsd:element name="derived" type="Derived"/>
          <xsd:element name="baseRef" ref="base"/>
        </xsd:schema>
        """

        let schemaSet = try XMLSchemaDocumentParser().parse(data: Data(xsd.utf8))
        let normalized = try XMLSchemaNormalizer().normalize(schemaSet)
        let base = try XCTUnwrap(normalized.complexType(named: "Base", namespaceURI: nil))
        let derived = try XCTUnwrap(normalized.complexType(named: "Derived", namespaceURI: nil))
        let baseBinding = try XCTUnwrap(normalized.rootElementBinding(forTypeNamed: "Base", namespaceURI: nil))

        XCTAssertEqual(base.effectiveSequence.map(\.name), ["id"])
        XCTAssertEqual(base.effectiveAttributes.map(\.name), ["shared"])
        XCTAssertEqual(derived.effectiveSequence.map(\.name), ["id", "code"])
        XCTAssertNotNil(schemaSet.schemas.first?.elements.first(where: { $0.name == "baseRef" }))
        XCTAssertEqual(baseBinding.name, "base")
    }
}
