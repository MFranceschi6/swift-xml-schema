import Foundation
import Logging
import SwiftXMLCoder
// swiftlint:disable file_length

private typealias XMLCoderDocument = SwiftXMLCoder.XMLDocument
private typealias XMLCoderNode = SwiftXMLCoder.XMLNode

extension XMLSchemaDocumentParser {
    func parseDocument(data: Data, sourceURL: URL?) throws -> XMLSchemaSet {
        logger.debug("Parsing XSD document", metadata: [
            "source": .string(sourceURL?.path ?? "<data>")
        ])

        let document: XMLCoderDocument
        do {
            if let sourceURL = sourceURL {
                document = try XMLCoderDocument(data: data, sourceURL: sourceURL)
            } else {
                document = try XMLCoderDocument(data: data)
            }
        } catch {
            throw XMLSchemaParsingError.invalidDocument(
                message: "Unable to parse XML document.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
            )
        }

        let schemaNodes = try findSchemaNodes(in: document)
        if schemaNodes.isEmpty {
            throw XMLSchemaParsingError.invalidDocument(
                message: "Missing xsd:schema root node.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
            )
        }

        var collectedSchemas: [XMLSchema] = []
        var loadedSchemaURLs = Set<String>()

        if let sourceURL = sourceURL, sourceURL.isFileURL {
            loadedSchemaURLs.insert(sourceURL.standardizedFileURL.path)
        }

        let fallbackNamespaceMappings = document.rootElement()?.namespaceDeclarationsInScope() ?? [:]
        for schemaNode in schemaNodes {
            try appendSchemaRecursively(
                schemaNode: schemaNode,
                sourceURL: sourceURL,
                fallbackNamespaceMappings: fallbackNamespaceMappings,
                loadedSchemaURLs: &loadedSchemaURLs,
                schemas: &collectedSchemas
            )
        }

        let schemaSet = XMLSchemaSet(schemas: collectedSchemas)
        try validateSchemaConsistency(schemaSet)

        let totalComplex  = schemaSet.schemas.reduce(0) { $0 + $1.complexTypes.count }
        let totalSimple   = schemaSet.schemas.reduce(0) { $0 + $1.simpleTypes.count }
        let totalElements = schemaSet.schemas.reduce(0) { $0 + $1.elements.count }
        logger.info("Parsed XSD document", metadata: [
            "source": .string(sourceURL?.path ?? "<data>"),
            "schemas": .stringConvertible(schemaSet.schemas.count),
            "complexTypes": .stringConvertible(totalComplex),
            "simpleTypes": .stringConvertible(totalSimple),
            "elements": .stringConvertible(totalElements)
        ])

        return schemaSet
    }

    private func appendSchemaRecursively(
        schemaNode: XMLCoderNode,
        sourceURL: URL?,
        fallbackNamespaceMappings: [String: String],
        loadedSchemaURLs: inout Set<String>,
        schemas: inout [XMLSchema]
    ) throws {
        logger.debug("Loading schema", metadata: [
            "source": .string(sourceURL?.path ?? "<inline>")
        ])

        let namespaceMappings = mergedNamespaceMappings(
            schemaNode.namespaceDeclarationsInScope(),
            fallback: fallbackNamespaceMappings
        )

        let parsedSchema = try parseSchema(schemaNode: schemaNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings)
        logger.debug("Schema parsed", metadata: [
            "namespace": .string(parsedSchema.targetNamespace ?? "(none)"),
            "complexTypes": .stringConvertible(parsedSchema.complexTypes.count),
            "simpleTypes": .stringConvertible(parsedSchema.simpleTypes.count),
            "elements": .stringConvertible(parsedSchema.elements.count),
            "imports": .stringConvertible(parsedSchema.imports.count),
            "includes": .stringConvertible(parsedSchema.includes.count)
        ])
        schemas.append(parsedSchema)

        let importReferences = parsedSchema.imports.compactMap { $0.schemaLocation }
        let includeReferences = parsedSchema.includes.map { $0.schemaLocation }
        for schemaLocation in importReferences + includeReferences {
            let schemaURL = try resourceResolver.resolve(schemaLocation: schemaLocation, relativeTo: sourceURL)
            let schemaURLKey = schemaURL.standardizedFileURL.path
            if loadedSchemaURLs.contains(schemaURLKey) {
                logger.warning("Schema already loaded, skipping (cycle guard)", metadata: [
                    "schemaLocation": .string(schemaLocation),
                    "resolvedPath": .string(schemaURLKey)
                ])
                continue
            }
            logger.debug("Resolving import/include", metadata: [
                "schemaLocation": .string(schemaLocation),
                "relativeTo": .string(sourceURL?.path ?? "<none>")
            ])
            loadedSchemaURLs.insert(schemaURLKey)

            let importedData = try resourceResolver.loadSchemaData(from: schemaURL)
            let importedDocument: XMLCoderDocument
            do {
                importedDocument = try XMLCoderDocument(data: importedData, sourceURL: schemaURL)
            } catch {
                throw XMLSchemaParsingError.invalidSchema(
                    name: nil,
                    message: "Unable to parse imported schema '\(schemaLocation)'.",
                    sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
                )
            }

            let importedSchemaNodes = try findSchemaNodes(in: importedDocument)
            for importedSchemaNode in importedSchemaNodes {
                try appendSchemaRecursively(
                    schemaNode: importedSchemaNode,
                    sourceURL: schemaURL,
                    fallbackNamespaceMappings: namespaceMappings,
                    loadedSchemaURLs: &loadedSchemaURLs,
                    schemas: &schemas
                )
            }
        }

        for redefine in parsedSchema.redefines {
            let schemaURL = try resourceResolver.resolve(schemaLocation: redefine.schemaLocation, relativeTo: sourceURL)
            let schemaURLKey = schemaURL.standardizedFileURL.path
            if loadedSchemaURLs.contains(schemaURLKey) {
                logger.warning("Redefine target already loaded, skipping (cycle guard)", metadata: [
                    "schemaLocation": .string(redefine.schemaLocation),
                    "resolvedPath": .string(schemaURLKey)
                ])
                continue
            }
            logger.debug("Resolving redefine", metadata: [
                "schemaLocation": .string(redefine.schemaLocation),
                "relativeTo": .string(sourceURL?.path ?? "<none>")
            ])
            loadedSchemaURLs.insert(schemaURLKey)

            let importedData = try resourceResolver.loadSchemaData(from: schemaURL)
            let importedDocument: XMLCoderDocument
            do {
                importedDocument = try XMLCoderDocument(data: importedData, sourceURL: schemaURL)
            } catch {
                throw XMLSchemaParsingError.invalidSchema(
                    name: nil,
                    message: "Unable to parse redefined schema '\(redefine.schemaLocation)'.",
                    sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
                )
            }

            let importedSchemaNodes = try findSchemaNodes(in: importedDocument)
            for importedSchemaNode in importedSchemaNodes {
                var tempSchemas: [XMLSchema] = []
                try appendSchemaRecursively(
                    schemaNode: importedSchemaNode,
                    sourceURL: schemaURL,
                    fallbackNamespaceMappings: namespaceMappings,
                    loadedSchemaURLs: &loadedSchemaURLs,
                    schemas: &tempSchemas
                )
                for loadedSchema in tempSchemas {
                    schemas.append(applyRedefine(redefine, to: loadedSchema))
                }
            }
        }
    }

    private func applyRedefine(_ redefine: XMLSchemaRedefine, to schema: XMLSchema) -> XMLSchema {
        let redefinedComplexTypeNames = Set(redefine.complexTypes.map(\.name))
        let redefinedSimpleTypeNames = Set(redefine.simpleTypes.map(\.name))
        let redefinedAttributeGroupNames = Set(redefine.attributeGroups.map(\.name))
        let redefinedModelGroupNames = Set(redefine.modelGroups.map(\.name))

        let patchedComplexTypes = schema.complexTypes.filter { !redefinedComplexTypeNames.contains($0.name) }
            + redefine.complexTypes
        let patchedSimpleTypes = schema.simpleTypes.filter { !redefinedSimpleTypeNames.contains($0.name) }
            + redefine.simpleTypes
        let patchedAttributeGroups = schema.attributeGroups.filter { !redefinedAttributeGroupNames.contains($0.name) }
            + redefine.attributeGroups
        let patchedModelGroups = schema.modelGroups.filter { !redefinedModelGroupNames.contains($0.name) }
            + redefine.modelGroups

        return XMLSchema(
            annotation: schema.annotation,
            targetNamespace: schema.targetNamespace,
            imports: schema.imports,
            includes: schema.includes,
            redefines: schema.redefines,
            notations: schema.notations,
            elements: schema.elements,
            attributeDefinitions: schema.attributeDefinitions,
            attributeGroups: patchedAttributeGroups,
            modelGroups: patchedModelGroups,
            complexTypes: patchedComplexTypes,
            simpleTypes: patchedSimpleTypes,
            defaultOpenContent: schema.defaultOpenContent
        )
    }

    private func findSchemaNodes(in document: XMLCoderDocument) throws -> [XMLCoderNode] {
        if let rootNode = document.rootElement(), rootNode.name == "schema" {
            return [rootNode]
        }

        do {
            let schemaNodes: [XMLCoderNode] = try document.xpathNodes("//*[local-name()='schema']")
            return schemaNodes
        } catch {
            throw XMLSchemaParsingError.invalidSchema(name: nil, message: "Unable to locate schema root in document.")
        }
    }

    private func parseSchema(schemaNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchema {
        let annotation = parseAnnotation(from: schemaNode)
        let targetNamespace = normalized(schemaNode.attribute(named: "targetNamespace"))

        let imports = schemaNode.children()
            .filter { $0.name == "import" }
            .map { importNode in
                XMLSchemaImport(
                    namespace: normalized(importNode.attribute(named: "namespace")),
                    schemaLocation: normalized(importNode.attribute(named: "schemaLocation"))
                )
            }

        let includes = schemaNode.children()
            .filter { $0.name == "include" }
            .compactMap { includeNode -> XMLSchemaInclude? in
                guard let schemaLocation = normalized(includeNode.attribute(named: "schemaLocation")) else {
                    return nil
                }
                return XMLSchemaInclude(schemaLocation: schemaLocation)
            }

        let redefines = try schemaNode.children()
            .filter { $0.name == "redefine" }
            .compactMap { redefineNode -> XMLSchemaRedefine? in
                guard let schemaLocation = normalized(redefineNode.attribute(named: "schemaLocation")) else {
                    return nil
                }
                let redefinedComplexTypes = try redefineNode.children()
                    .filter { $0.name == "complexType" }
                    .map { try parseComplexType($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }
                let redefinedSimpleTypes = try redefineNode.children()
                    .filter { $0.name == "simpleType" }
                    .map { try parseSimpleType($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }
                let redefinedAttributeGroups = try redefineNode.children()
                    .filter { $0.name == "attributeGroup" && normalized($0.attribute(named: "name")) != nil }
                    .map { try parseAttributeGroup($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }
                let redefinedModelGroups = try redefineNode.children()
                    .filter { $0.name == "group" && normalized($0.attribute(named: "name")) != nil }
                    .map { try parseModelGroup($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }
                return XMLSchemaRedefine(
                    schemaLocation: schemaLocation,
                    complexTypes: redefinedComplexTypes,
                    simpleTypes: redefinedSimpleTypes,
                    attributeGroups: redefinedAttributeGroups,
                    modelGroups: redefinedModelGroups
                )
            }

        let notations = schemaNode.children()
            .filter { $0.name == "notation" }
            .compactMap { notationNode -> XMLSchemaNotation? in
                guard let name = normalized(notationNode.attribute(named: "name")) else {
                    return nil
                }
                return XMLSchemaNotation(
                    name: name,
                    publicID: normalized(notationNode.attribute(named: "public")),
                    systemID: normalized(notationNode.attribute(named: "system"))
                )
            }

        let elements = try schemaNode.children()
            .filter { $0.name == "element" }
            .map { try parseSchemaElement($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }

        let attributeDefinitions = try parseAttributes(
            from: schemaNode.children().filter { $0.name == "attribute" },
            contextName: "schema",
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )

        let attributeGroups = try schemaNode.children()
            .filter { $0.name == "attributeGroup" && normalized($0.attribute(named: "name")) != nil }
            .map { try parseAttributeGroup($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }

        let modelGroups = try schemaNode.children()
            .filter { $0.name == "group" && normalized($0.attribute(named: "name")) != nil }
            .map { try parseModelGroup($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }

        let complexTypes = try schemaNode.children()
            .filter { $0.name == "complexType" }
            .map { try parseComplexType($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }

        let simpleTypes = try schemaNode.children()
            .filter { $0.name == "simpleType" }
            .map { try parseSimpleType($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }

        // XSD 1.1: schema-level defaultOpenContent
        let defaultOpenContent = try schemaNode.children()
            .first(where: { $0.name == "defaultOpenContent" })
            .map { try parseOpenContentNode($0) }

        return XMLSchema(
            annotation: annotation,
            targetNamespace: targetNamespace,
            imports: imports,
            includes: includes,
            redefines: redefines,
            notations: notations,
            elements: elements,
            attributeDefinitions: attributeDefinitions,
            attributeGroups: attributeGroups,
            modelGroups: modelGroups,
            complexTypes: complexTypes,
            simpleTypes: simpleTypes,
            defaultOpenContent: defaultOpenContent
        )
    }

    private func parseSchemaElement(_ elementNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaElement {
        let annotation = parseAnnotation(from: elementNode)
        let name = normalized(elementNode.attribute(named: "name"))
        let refQName = try resolveQName(
            fromQualifiedName: elementNode.attribute(named: "ref"),
            namespaceMappings: namespaceMappings,
            context: "schema element reference"
        )
        let resolvedName = name ?? refQName?.localName
        guard let resolvedName = resolvedName else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "Schema element is missing both 'name' and 'ref'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: elementNode.lineNumber)
            )
        }

        let typeQName = try resolveQName(
            fromQualifiedName: elementNode.attribute(named: "type"),
            namespaceMappings: namespaceMappings,
            context: "schema element type"
        )

        let minOccurs = normalized(elementNode.attribute(named: "minOccurs")).flatMap(Int.init)
        let maxOccurs = normalized(elementNode.attribute(named: "maxOccurs"))
        let nillable = parseBooleanAttribute(named: "nillable", on: elementNode)
        let defaultValue = normalized(elementNode.attribute(named: "default"))
        let fixedValue = normalized(elementNode.attribute(named: "fixed"))
        let isAbstract = parseBooleanAttribute(named: "abstract", on: elementNode)
        let substitutionGroup = try resolveQName(
            fromQualifiedName: elementNode.attribute(named: "substitutionGroup"),
            namespaceMappings: namespaceMappings,
            context: "schema element substitutionGroup"
        )
        let inlineComplexType = try elementNode.children()
            .first(where: { $0.name == "complexType" })
            .map { try parseAnonymousComplexType($0, sourceURL: sourceURL, namespaceMappings: namespaceMappings) }
        let inlineSimpleType = try elementNode.children()
            .first(where: { $0.name == "simpleType" })
            .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
        let identityConstraints = try parseIdentityConstraints(
            from: elementNode.children(),
            namespaceMappings: namespaceMappings
        )
        let typeAlternatives = try parseTypeAlternatives(
            from: elementNode.children(),
            namespaceMappings: namespaceMappings
        )

        return XMLSchemaElement(
            annotation: annotation,
            name: resolvedName,
            typeQName: typeQName,
            refQName: refQName,
            minOccurs: minOccurs,
            maxOccurs: maxOccurs,
            nillable: nillable,
            defaultValue: defaultValue,
            fixedValue: fixedValue,
            isAbstract: isAbstract,
            substitutionGroup: substitutionGroup,
            identityConstraints: identityConstraints,
            typeAlternatives: typeAlternatives,
            inlineComplexType: inlineComplexType,
            inlineSimpleType: inlineSimpleType
        )
    }

    private func parseIdentityConstraints(
        from nodes: [XMLCoderNode],
        namespaceMappings: [String: String]
    ) throws -> [XMLSchemaIdentityConstraint] {
        var result: [XMLSchemaIdentityConstraint] = []
        for node in nodes {
            let kind: XMLSchemaIdentityConstraintKind
            switch node.name {
            case "key": kind = .key
            case "keyref": kind = .keyref
            case "unique": kind = .unique
            default: continue
            }
            guard let name = normalized(node.attribute(named: "name")) else { continue }
            let selector = node.children().first(where: { $0.name == "selector" })
                .flatMap { normalized($0.attribute(named: "xpath")) } ?? ""
            let fields = node.children()
                .filter { $0.name == "field" }
                .compactMap { normalized($0.attribute(named: "xpath")) }
            let refer = try resolveQName(
                fromQualifiedName: node.attribute(named: "refer"),
                namespaceMappings: namespaceMappings,
                context: "keyref refer"
            )
            result.append(XMLSchemaIdentityConstraint(
                kind: kind,
                name: name,
                selector: selector,
                fields: fields,
                refer: refer
            ))
        }
        return result
    }

    private func parseComplexType(_ complexTypeNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaComplexType {
        let annotation = parseAnnotation(from: complexTypeNode)
        guard let name = normalized(complexTypeNode.attribute(named: "name")) else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "complexType node is missing required 'name'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: complexTypeNode.lineNumber)
            )
        }
        logger.trace("Parsing complexType", metadata: ["name": .string(name)])

        let complexTypeChildren = complexTypeNode.children()
        let complexContentNode = complexTypeChildren.first(where: { $0.name == "complexContent" })
        let complexDerivedNode = complexContentNode?.children().first(where: { ["extension", "restriction"].contains($0.name) })
        let simpleContentNode = complexTypeChildren.first(where: { $0.name == "simpleContent" })
        let simpleDerivedNode = simpleContentNode?.children().first(where: { ["extension", "restriction"].contains($0.name) })
        let complexDerivedChildren = complexDerivedNode?.children() ?? []
        let simpleDerivedChildren = simpleDerivedNode?.children() ?? []

        let baseQName = try resolveQName(
            fromQualifiedName: complexDerivedNode?.attribute(named: "base"),
            namespaceMappings: namespaceMappings,
            context: "complexType derivation base"
        )
        let simpleContentBaseQName = try resolveQName(
            fromQualifiedName: simpleDerivedNode?.attribute(named: "base"),
            namespaceMappings: namespaceMappings,
            context: "simpleContent derivation base"
        )
        let content = try parseSchemaContent(
            from: complexTypeChildren + complexDerivedChildren,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let attributes = try parseAttributes(
            from: complexTypeChildren.filter { $0.name == "attribute" } +
                complexDerivedChildren.filter { $0.name == "attribute" } +
                simpleDerivedChildren.filter { $0.name == "attribute" },
            contextName: name,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let attributeRefs = try parseAttributeRefs(
            from: complexTypeChildren.filter { $0.name == "attribute" } +
                complexDerivedChildren.filter { $0.name == "attribute" } +
                simpleDerivedChildren.filter { $0.name == "attribute" },
            namespaceMappings: namespaceMappings
        )
        let attributeGroupRefs = try parseAttributeGroupRefs(
            from: complexTypeChildren.filter { $0.name == "attributeGroup" } +
                complexDerivedChildren.filter { $0.name == "attributeGroup" } +
                simpleDerivedChildren.filter { $0.name == "attributeGroup" },
            contextName: name,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let anyAttribute = try parseAnyAttribute(
            from: complexTypeChildren.filter { $0.name == "anyAttribute" } +
                complexDerivedChildren.filter { $0.name == "anyAttribute" } +
                simpleDerivedChildren.filter { $0.name == "anyAttribute" }
        )

        let isMixed = parseBooleanAttribute(named: "mixed", on: complexTypeNode)
            || (complexContentNode.map { parseBooleanAttribute(named: "mixed", on: $0) } ?? false)

        let assertions = parseAssertions(from: complexTypeChildren + complexDerivedChildren)
        let openContent = try parseOpenContent(from: complexTypeChildren + complexDerivedChildren)

        return XMLSchemaComplexType(
            annotation: annotation,
            name: name,
            baseQName: baseQName,
            baseDerivationKind: complexDerivedNode.flatMap(parseContentDerivationKind),
            simpleContentBaseQName: simpleContentBaseQName,
            simpleContentDerivationKind: simpleDerivedNode.flatMap(parseContentDerivationKind),
            isAbstract: parseBooleanAttribute(named: "abstract", on: complexTypeNode),
            isMixed: isMixed,
            sequence: [],
            choiceGroups: [],
            content: content,
            attributes: attributes,
            attributeRefs: attributeRefs,
            attributeGroupRefs: attributeGroupRefs,
            anyAttribute: anyAttribute,
            assertions: assertions,
            openContent: openContent
        )
    }

    private func parseAnonymousComplexType(
        _ complexTypeNode: XMLCoderNode,
        sourceURL: URL?,
        namespaceMappings: [String: String]
    ) throws -> XMLSchemaAnonymousComplexType {
        let annotation = parseAnnotation(from: complexTypeNode)
        let complexTypeChildren = complexTypeNode.children()
        let complexContentNode = complexTypeChildren.first(where: { $0.name == "complexContent" })
        let complexDerivedNode = complexContentNode?.children().first(where: { ["extension", "restriction"].contains($0.name) })
        let simpleContentNode = complexTypeChildren.first(where: { $0.name == "simpleContent" })
        let simpleDerivedNode = simpleContentNode?.children().first(where: { ["extension", "restriction"].contains($0.name) })
        let complexDerivedChildren = complexDerivedNode?.children() ?? []
        let simpleDerivedChildren = simpleDerivedNode?.children() ?? []
        let content = try parseSchemaContent(
            from: complexTypeChildren + complexDerivedChildren,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let attributes = try parseAttributes(
            from: complexTypeChildren.filter { $0.name == "attribute" } +
                complexDerivedChildren.filter { $0.name == "attribute" } +
                simpleDerivedChildren.filter { $0.name == "attribute" },
            contextName: "anonymousComplexType",
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let attributeRefs = try parseAttributeRefs(
            from: complexTypeChildren.filter { $0.name == "attribute" } +
                complexDerivedChildren.filter { $0.name == "attribute" } +
                simpleDerivedChildren.filter { $0.name == "attribute" },
            namespaceMappings: namespaceMappings
        )
        let attributeGroupRefs = try parseAttributeGroupRefs(
            from: complexTypeChildren.filter { $0.name == "attributeGroup" } +
                complexDerivedChildren.filter { $0.name == "attributeGroup" } +
                simpleDerivedChildren.filter { $0.name == "attributeGroup" },
            contextName: "anonymousComplexType",
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let anyAttribute = try parseAnyAttribute(
            from: complexTypeChildren.filter { $0.name == "anyAttribute" } +
                complexDerivedChildren.filter { $0.name == "anyAttribute" } +
                simpleDerivedChildren.filter { $0.name == "anyAttribute" }
        )

        let isMixed = parseBooleanAttribute(named: "mixed", on: complexTypeNode)
            || (complexContentNode.map { parseBooleanAttribute(named: "mixed", on: $0) } ?? false)

        let assertions = parseAssertions(from: complexTypeChildren + complexDerivedChildren)
        let openContent = try parseOpenContent(from: complexTypeChildren + complexDerivedChildren)

        return XMLSchemaAnonymousComplexType(
            annotation: annotation,
            baseQName: try resolveQName(
                fromQualifiedName: complexDerivedNode?.attribute(named: "base"),
                namespaceMappings: namespaceMappings,
                context: "anonymous complexType derivation base"
            ),
            baseDerivationKind: complexDerivedNode.flatMap(parseContentDerivationKind),
            simpleContentBaseQName: try resolveQName(
                fromQualifiedName: simpleDerivedNode?.attribute(named: "base"),
                namespaceMappings: namespaceMappings,
                context: "anonymous simpleContent derivation base"
            ),
            simpleContentDerivationKind: simpleDerivedNode.flatMap(parseContentDerivationKind),
            isAbstract: parseBooleanAttribute(named: "abstract", on: complexTypeNode),
            isMixed: isMixed,
            sequence: [],
            choiceGroups: [],
            content: content,
            attributes: attributes,
            attributeRefs: attributeRefs,
            attributeGroupRefs: attributeGroupRefs,
            anyAttribute: anyAttribute,
            assertions: assertions,
            openContent: openContent
        )
    }

    private func parseAttributeGroup(
        _ attributeGroupNode: XMLCoderNode,
        sourceURL: URL?,
        namespaceMappings: [String: String]
    ) throws -> XMLSchemaAttributeGroup {
        guard let name = normalized(attributeGroupNode.attribute(named: "name")) else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "attributeGroup node is missing required 'name'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: attributeGroupNode.lineNumber)
            )
        }

        let attributes = try parseAttributes(
            from: attributeGroupNode.children().filter { $0.name == "attribute" },
            contextName: name,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        let attributeRefs = try parseAttributeRefs(
            from: attributeGroupNode.children().filter { $0.name == "attribute" },
            namespaceMappings: namespaceMappings
        )
        let attributeGroupRefs = try parseAttributeGroupRefs(
            from: attributeGroupNode.children().filter { $0.name == "attributeGroup" },
            contextName: name,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )

        return XMLSchemaAttributeGroup(
            name: name,
            attributes: attributes,
            attributeRefs: attributeRefs,
            attributeGroupRefs: attributeGroupRefs
        )
    }

    private func parseModelGroup(_ modelGroupNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaModelGroup {
        guard let name = normalized(modelGroupNode.attribute(named: "name")) else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "group node is missing required 'name'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: modelGroupNode.lineNumber)
            )
        }
        let content = try parseSchemaContent(from: modelGroupNode.children(), sourceURL: sourceURL, namespaceMappings: namespaceMappings)
        return XMLSchemaModelGroup(name: name, content: content)
    }

    private func parseSchemaContent(from nodes: [XMLCoderNode], sourceURL: URL?, namespaceMappings: [String: String]) throws -> [XMLSchemaContentNode] {
        var content: [XMLSchemaContentNode] = []
        for node in nodes {
            switch node.name {
            case "sequence", "all":
                content.append(contentsOf: try parseContainerContent(from: node, sourceURL: sourceURL, namespaceMappings: namespaceMappings))
            case "choice":
                content.append(.choice(try parseChoiceGroup(node, sourceURL: sourceURL, namespaceMappings: namespaceMappings)))
            case "group":
                if normalized(node.attribute(named: "ref")) != nil {
                    content.append(.groupReference(try parseGroupReference(node, sourceURL: sourceURL, namespaceMappings: namespaceMappings)))
                }
            case "any":
                content.append(.wildcard(try parseWildcard(node, kind: .element)))
            default:
                continue
            }
        }
        return content
    }

    private func parseContainerContent(
        from containerNode: XMLCoderNode,
        sourceURL: URL?,
        namespaceMappings: [String: String]
    ) throws -> [XMLSchemaContentNode] {
        var content: [XMLSchemaContentNode] = []
        for childNode in containerNode.children() {
            switch childNode.name {
            case "element":
                content.append(.element(try parseSchemaElement(childNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings)))
            case "choice":
                content.append(.choice(try parseChoiceGroup(childNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings)))
            case "group":
                if normalized(childNode.attribute(named: "ref")) != nil {
                    content.append(.groupReference(try parseGroupReference(childNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings)))
                }
            case "any":
                content.append(.wildcard(try parseWildcard(childNode, kind: .element)))
            case "sequence", "all":
                content.append(contentsOf: try parseContainerContent(from: childNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings))
            default:
                continue
            }
        }
        return content
    }

    private func parseChoiceGroup(_ choiceNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaChoiceGroup {
        XMLSchemaChoiceGroup(
            elements: [],
            minOccurs: normalized(choiceNode.attribute(named: "minOccurs")).flatMap(Int.init),
            maxOccurs: normalized(choiceNode.attribute(named: "maxOccurs")),
            content: try parseContainerContent(from: choiceNode, sourceURL: sourceURL, namespaceMappings: namespaceMappings)
        )
    }

    private func parseGroupReference(_ groupNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaGroupReference {
        guard let refQName = try resolveQName(
            fromQualifiedName: groupNode.attribute(named: "ref"),
            namespaceMappings: namespaceMappings,
            context: "group ref"
        ) else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "group reference is missing required 'ref'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: groupNode.lineNumber)
            )
        }

        return XMLSchemaGroupReference(
            refQName: refQName,
            minOccurs: normalized(groupNode.attribute(named: "minOccurs")).flatMap(Int.init),
            maxOccurs: normalized(groupNode.attribute(named: "maxOccurs"))
        )
    }

    private func parseWildcard(_ wildcardNode: XMLCoderNode, kind: XMLSchemaWildcardKind) throws -> XMLSchemaWildcard {
        let processContentsString = normalized(wildcardNode.attribute(named: "processContents"))
        let processContents = processContentsString.flatMap(XMLSchemaWildcardProcessContents.init(rawValue:))
        return XMLSchemaWildcard(
            kind: kind,
            namespaceConstraint: normalized(wildcardNode.attribute(named: "namespace")),
            processContents: processContents,
            minOccurs: normalized(wildcardNode.attribute(named: "minOccurs")).flatMap(Int.init),
            maxOccurs: normalized(wildcardNode.attribute(named: "maxOccurs"))
        )
    }

    private func parseAnyAttribute(from anyAttributeNodes: [XMLCoderNode]) throws -> XMLSchemaWildcard? {
        guard let anyAttributeNode = anyAttributeNodes.first else {
            return nil
        }
        return try parseWildcard(anyAttributeNode, kind: .attribute)
    }

    private func parseContentDerivationKind(_ node: XMLCoderNode) -> XMLSchemaContentDerivationKind? {
        guard let nodeName = node.name else {
            return nil
        }
        return XMLSchemaContentDerivationKind(rawValue: nodeName)
    }

    private func parseAnonymousSimpleType(_ simpleTypeNode: XMLCoderNode, namespaceMappings: [String: String]) throws -> XMLSchemaAnonymousSimpleType {
        let annotation = parseAnnotation(from: simpleTypeNode)
        let restrictionNode = simpleTypeNode.children().first(where: { $0.name == "restriction" })
        let listNode = simpleTypeNode.children().first(where: { $0.name == "list" })
        let unionNode = simpleTypeNode.children().first(where: { $0.name == "union" })

        if let listNode = listNode {
            let itemQName = try resolveQName(
                fromQualifiedName: listNode.attribute(named: "itemType"),
                namespaceMappings: namespaceMappings,
                context: "simpleType list itemType"
            )
            return XMLSchemaAnonymousSimpleType(
                annotation: annotation,
                baseQName: nil,
                enumerationValues: [],
                pattern: nil,
                derivationKind: .list,
                listItemQName: itemQName,
                unionMemberQNames: [],
                unionInlineSimpleTypes: try listNode.children()
                    .filter { $0.name == "simpleType" }
                    .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
            )
        }

        if let unionNode = unionNode {
            let memberQNames = try parseQNameList(
                unionNode.attribute(named: "memberTypes"),
                namespaceMappings: namespaceMappings,
                context: "simpleType union memberTypes"
            )
            return XMLSchemaAnonymousSimpleType(
                annotation: annotation,
                baseQName: nil,
                enumerationValues: [],
                pattern: nil,
                derivationKind: .union,
                listItemQName: nil,
                unionMemberQNames: memberQNames,
                unionInlineSimpleTypes: try unionNode.children()
                    .filter { $0.name == "simpleType" }
                    .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
            )
        }

        let restrictionChildren = restrictionNode?.children() ?? []
        let enumerationValues = restrictionChildren
            .filter { $0.name == "enumeration" }
            .compactMap { normalized($0.attribute(named: "value")) }
        let pattern = normalized(restrictionChildren.first(where: { $0.name == "pattern" })?.attribute(named: "value"))
        let facets = restrictionNode.flatMap { makeFacetSet(from: $0.children()) }
        return XMLSchemaAnonymousSimpleType(
            annotation: annotation,
            baseQName: try resolveQName(
                fromQualifiedName: restrictionNode?.attribute(named: "base"),
                namespaceMappings: namespaceMappings,
                context: "anonymous simpleType restriction base"
            ),
            enumerationValues: enumerationValues,
            pattern: pattern,
            facets: facets,
            derivationKind: .restriction
        )
    }

    private func parseAttributes(
        from attributeNodes: [XMLCoderNode],
        contextName: String,
        sourceURL: URL?,
        namespaceMappings: [String: String]
    ) throws -> [XMLSchemaAttribute] {
        try attributeNodes.compactMap { attributeNode -> XMLSchemaAttribute? in
            guard normalized(attributeNode.attribute(named: "ref")) == nil else {
                return nil
            }
            guard let attributeName = normalized(attributeNode.attribute(named: "name")) else {
                throw XMLSchemaParsingError.invalidSchema(
                    name: contextName,
                    message: "Context '\(contextName)' contains an attribute without required 'name'.",
                    sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: attributeNode.lineNumber)
                )
            }
            let typeQName = try resolveQName(
                fromQualifiedName: attributeNode.attribute(named: "type"),
                namespaceMappings: namespaceMappings,
                context: "schema attribute type"
            )
            let inlineSimpleType = try attributeNode.children()
                .first(where: { $0.name == "simpleType" })
                .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
            return XMLSchemaAttribute(
                annotation: parseAnnotation(from: attributeNode),
                name: attributeName,
                typeQName: typeQName,
                use: normalized(attributeNode.attribute(named: "use")).flatMap(XMLSchemaAttributeUseKind.init(rawValue:)),
                defaultValue: normalized(attributeNode.attribute(named: "default")),
                fixedValue: normalized(attributeNode.attribute(named: "fixed")),
                inlineSimpleType: inlineSimpleType
            )
        }
    }

    private func parseAttributeRefs(from attributeNodes: [XMLCoderNode], namespaceMappings: [String: String]) throws -> [XMLSchemaAttributeReference] {
        try attributeNodes.compactMap { attributeNode -> XMLSchemaAttributeReference? in
            guard let refQName = try resolveQName(
                fromQualifiedName: attributeNode.attribute(named: "ref"),
                namespaceMappings: namespaceMappings,
                context: "attribute ref"
            ) else {
                return nil
            }

            return XMLSchemaAttributeReference(
                refQName: refQName,
                use: normalized(attributeNode.attribute(named: "use")).flatMap(XMLSchemaAttributeUseKind.init(rawValue:)),
                defaultValue: normalized(attributeNode.attribute(named: "default")),
                fixedValue: normalized(attributeNode.attribute(named: "fixed")),
                annotation: parseAnnotation(from: attributeNode)
            )
        }
    }

    private func parseAttributeGroupRefs(
        from attributeGroupNodes: [XMLCoderNode],
        contextName: String,
        sourceURL: URL?,
        namespaceMappings: [String: String]
    ) throws -> [XMLQualifiedName] {
        try attributeGroupNodes.map { attributeGroupNode in
            guard let refQName = try resolveQName(
                fromQualifiedName: attributeGroupNode.attribute(named: "ref"),
                namespaceMappings: namespaceMappings,
                context: "attributeGroup ref"
            ) else {
                throw XMLSchemaParsingError.invalidSchema(
                    name: contextName,
                    message: "attributeGroup reference in '\(contextName)' is missing required 'ref'.",
                    sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: attributeGroupNode.lineNumber)
                )
            }
            return refQName
        }
    }

    private func parseSimpleType(_ simpleTypeNode: XMLCoderNode, sourceURL: URL?, namespaceMappings: [String: String]) throws -> XMLSchemaSimpleType {
        let annotation = parseAnnotation(from: simpleTypeNode)
        guard let name = normalized(simpleTypeNode.attribute(named: "name")) else {
            throw XMLSchemaParsingError.invalidSchema(
                name: nil,
                message: "simpleType node is missing required 'name'.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL, lineNumber: simpleTypeNode.lineNumber)
            )
        }
        logger.trace("Parsing simpleType", metadata: ["name": .string(name)])

        let restrictionNode = simpleTypeNode.children().first(where: { $0.name == "restriction" })
        let listNode = simpleTypeNode.children().first(where: { $0.name == "list" })
        let unionNode = simpleTypeNode.children().first(where: { $0.name == "union" })

        if let listNode = listNode {
            return XMLSchemaSimpleType(
                annotation: annotation,
                name: name,
                baseQName: nil,
                enumerationValues: [],
                pattern: nil,
                derivationKind: .list,
                listItemQName: try resolveQName(
                    fromQualifiedName: listNode.attribute(named: "itemType"),
                    namespaceMappings: namespaceMappings,
                    context: "simpleType list itemType"
                ),
                unionInlineSimpleTypes: try listNode.children()
                    .filter { $0.name == "simpleType" }
                    .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
            )
        }

        if let unionNode = unionNode {
            return XMLSchemaSimpleType(
                annotation: annotation,
                name: name,
                baseQName: nil,
                enumerationValues: [],
                pattern: nil,
                derivationKind: .union,
                unionMemberQNames: try parseQNameList(
                    unionNode.attribute(named: "memberTypes"),
                    namespaceMappings: namespaceMappings,
                    context: "simpleType union memberTypes"
                ),
                unionInlineSimpleTypes: try unionNode.children()
                    .filter { $0.name == "simpleType" }
                    .map { try parseAnonymousSimpleType($0, namespaceMappings: namespaceMappings) }
            )
        }

        let restrictionChildren = restrictionNode?.children() ?? []
        let baseQName = try resolveQName(
            fromQualifiedName: restrictionNode?.attribute(named: "base"),
            namespaceMappings: namespaceMappings,
            context: "simpleType restriction base"
        )
        let enumerationValues = restrictionChildren
            .filter { $0.name == "enumeration" }
            .compactMap { normalized($0.attribute(named: "value")) }
        let pattern = normalized(restrictionChildren.first(where: { $0.name == "pattern" })?.attribute(named: "value"))
        let facets = restrictionNode.flatMap { makeFacetSet(from: $0.children()) }

        return XMLSchemaSimpleType(
            annotation: annotation,
            name: name,
            baseQName: baseQName,
            enumerationValues: enumerationValues,
            pattern: pattern,
            facets: facets,
            derivationKind: .restriction
        )
    }

    private func parseQNameList(
        _ value: String?,
        namespaceMappings: [String: String],
        context: String
    ) throws -> [XMLQualifiedName] {
        guard let normalizedValue = normalized(value) else {
            return []
        }

        return try normalizedValue
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .compactMap { member in
                try resolveQName(fromQualifiedName: member, namespaceMappings: namespaceMappings, context: context)
            }
    }

    private func makeFacetSet(from restrictionChildren: [XMLCoderNode]) -> XMLSchemaFacetSet? {
        let enumerationValues = restrictionChildren
            .filter { $0.name == "enumeration" }
            .compactMap { normalized($0.attribute(named: "value")) }
        let pattern = normalized(restrictionChildren.first(where: { $0.name == "pattern" })?.attribute(named: "value"))
        let facetSet = XMLSchemaFacetSet(
            enumeration: enumerationValues,
            pattern: pattern,
            minLength: restrictionChildren.first(where: { $0.name == "minLength" })?.attribute(named: "value").flatMap(Int.init),
            maxLength: restrictionChildren.first(where: { $0.name == "maxLength" })?.attribute(named: "value").flatMap(Int.init),
            length: restrictionChildren.first(where: { $0.name == "length" })?.attribute(named: "value").flatMap(Int.init),
            minInclusive: normalized(restrictionChildren.first(where: { $0.name == "minInclusive" })?.attribute(named: "value")),
            maxInclusive: normalized(restrictionChildren.first(where: { $0.name == "maxInclusive" })?.attribute(named: "value")),
            minExclusive: normalized(restrictionChildren.first(where: { $0.name == "minExclusive" })?.attribute(named: "value")),
            maxExclusive: normalized(restrictionChildren.first(where: { $0.name == "maxExclusive" })?.attribute(named: "value")),
            totalDigits: restrictionChildren.first(where: { $0.name == "totalDigits" })?.attribute(named: "value").flatMap(Int.init),
            fractionDigits: restrictionChildren.first(where: { $0.name == "fractionDigits" })?.attribute(named: "value").flatMap(Int.init)
        )
        return facetSet.isEmpty ? nil : facetSet
    }

    private func validateSchemaConsistency(_ schemaSet: XMLSchemaSet) throws {
        try validateUniqueSymbolNames(schemaSet)
        try validateReferences(schemaSet)
    }

    private func validateUniqueSymbolNames(_ schemaSet: XMLSchemaSet) throws {
        var seenComplexNames = Set<String>()
        var seenSimpleNames = Set<String>()
        var seenElementNames = Set<String>()
        var seenAttributeNames = Set<String>()
        var seenAttributeGroupNames = Set<String>()
        var seenModelGroupNames = Set<String>()

        for schema in schemaSet.schemas {
            for complexType in schema.complexTypes {
                let key = "\(schema.targetNamespace ?? ""):\(complexType.name)"
                guard seenComplexNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: complexType.name, message: "Duplicated complex type '\(complexType.name)'.")
                }
            }
            for simpleType in schema.simpleTypes {
                let key = "\(schema.targetNamespace ?? ""):\(simpleType.name)"
                guard seenSimpleNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: simpleType.name, message: "Duplicated simple type '\(simpleType.name)'.")
                }
            }
            for element in schema.elements {
                let key = "\(schema.targetNamespace ?? ""):\(element.name)"
                guard seenElementNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: element.name, message: "Duplicated schema element '\(element.name)'.")
                }
            }
            for attribute in schema.attributeDefinitions {
                let key = "\(schema.targetNamespace ?? ""):\(attribute.name)"
                guard seenAttributeNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: attribute.name, message: "Duplicated attribute definition '\(attribute.name)'.")
                }
            }
            for attributeGroup in schema.attributeGroups {
                let key = "\(schema.targetNamespace ?? ""):\(attributeGroup.name)"
                guard seenAttributeGroupNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: attributeGroup.name, message: "Duplicated attributeGroup '\(attributeGroup.name)'.")
                }
            }
            for modelGroup in schema.modelGroups {
                let key = "\(schema.targetNamespace ?? ""):\(modelGroup.name)"
                guard seenModelGroupNames.insert(key).inserted else {
                    throw XMLSchemaParsingError.invalidSchema(name: modelGroup.name, message: "Duplicated group '\(modelGroup.name)'.")
                }
            }
        }
    }

    private func validateReferences(_ schemaSet: XMLSchemaSet) throws {
        let resolver = SchemaReferenceResolver(schemaSet: schemaSet)

        for schema in schemaSet.schemas {
            for element in schema.elements {
                try validateElement(element, in: schema, resolver: resolver)
            }
            for complexType in schema.complexTypes {
                if let baseQName = complexType.baseQName,
                   !isXMLSchemaBuiltIn(baseQName),
                   resolver.complexType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: complexType.name,
                        message: "complexType '\(complexType.name)' extends unknown base type '\(baseQName.qualifiedName)'."
                    )
                }

                if let baseQName = complexType.simpleContentBaseQName,
                   !isXMLSchemaBuiltIn(baseQName),
                   resolver.complexType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil,
                   resolver.simpleType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: complexType.name,
                        message: "simpleContent type '\(complexType.name)' extends unknown base '\(baseQName.qualifiedName)'."
                    )
                }

                try validateContentNodes(complexType.content, in: schema, contextName: complexType.name, resolver: resolver)
                for attribute in complexType.attributes {
                    try validateAttribute(attribute, contextName: complexType.name, resolver: resolver)
                }
                for attributeRef in complexType.attributeRefs
                where resolver.attribute(
                    named: attributeRef.refQName.localName,
                    namespaceURI: attributeRef.refQName.namespaceURI
                ) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: complexType.name,
                        message: "attribute reference '\(attributeRef.refQName.qualifiedName)' could not be resolved."
                    )
                }
                for attributeGroupRef in complexType.attributeGroupRefs
                where resolver.attributeGroup(
                    named: attributeGroupRef.localName,
                    namespaceURI: attributeGroupRef.namespaceURI
                ) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: complexType.name,
                        message: "attributeGroup reference '\(attributeGroupRef.qualifiedName)' could not be resolved."
                    )
                }
            }
            for simpleType in schema.simpleTypes {
                switch simpleType.derivationKind {
                case .restriction:
                    if let baseQName = simpleType.baseQName,
                       !isXMLSchemaBuiltIn(baseQName),
                       resolver.simpleType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
                        throw XMLSchemaParsingError.unresolvedReference(
                            name: simpleType.name,
                            message: "simpleType '\(simpleType.name)' references unknown base '\(baseQName.qualifiedName)'."
                        )
                    }
                case .list:
                    if let itemQName = simpleType.listItemQName,
                       !isXMLSchemaBuiltIn(itemQName),
                       resolver.simpleType(named: itemQName.localName, namespaceURI: itemQName.namespaceURI) == nil {
                        throw XMLSchemaParsingError.unresolvedReference(
                            name: simpleType.name,
                            message: "simpleType '\(simpleType.name)' references unknown list item type '\(itemQName.qualifiedName)'."
                        )
                    }
                case .union:
                    for memberQName in simpleType.unionMemberQNames
                    where !isXMLSchemaBuiltIn(memberQName) &&
                        resolver.simpleType(named: memberQName.localName, namespaceURI: memberQName.namespaceURI) == nil {
                        throw XMLSchemaParsingError.unresolvedReference(
                            name: simpleType.name,
                            message: "simpleType '\(simpleType.name)' references unknown union member '\(memberQName.qualifiedName)'."
                        )
                    }
                }
            }
            for attributeGroup in schema.attributeGroups {
                for attribute in attributeGroup.attributes {
                    try validateAttribute(attribute, contextName: attributeGroup.name, resolver: resolver)
                }
                for attributeRef in attributeGroup.attributeRefs
                where resolver.attribute(
                    named: attributeRef.refQName.localName,
                    namespaceURI: attributeRef.refQName.namespaceURI
                ) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: attributeGroup.name,
                        message: "attribute reference '\(attributeRef.refQName.qualifiedName)' could not be resolved."
                    )
                }
                for nestedRef in attributeGroup.attributeGroupRefs
                where resolver.attributeGroup(
                    named: nestedRef.localName,
                    namespaceURI: nestedRef.namespaceURI
                ) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: attributeGroup.name,
                        message: "attributeGroup reference '\(nestedRef.qualifiedName)' could not be resolved."
                    )
                }
            }
            for modelGroup in schema.modelGroups {
                try validateContentNodes(modelGroup.content, in: schema, contextName: modelGroup.name, resolver: resolver)
            }
        }
    }

    private func validateContentNodes(
        _ contentNodes: [XMLSchemaContentNode],
        in schema: XMLSchema,
        contextName: String,
        resolver: SchemaReferenceResolver
    ) throws {
        for contentNode in contentNodes {
            switch contentNode {
            case let .element(element):
                try validateElement(element, in: schema, resolver: resolver)
            case let .choice(choiceGroup):
                try validateContentNodes(choiceGroup.content, in: schema, contextName: contextName, resolver: resolver)
            case let .groupReference(groupReference):
                if resolver.modelGroup(named: groupReference.refQName.localName, namespaceURI: groupReference.refQName.namespaceURI) == nil {
                    throw XMLSchemaParsingError.unresolvedReference(
                        name: contextName,
                        message: "group reference '\(groupReference.refQName.qualifiedName)' could not be resolved."
                    )
                }
            case .wildcard:
                continue
            }
        }
    }

    private func validateElement(_ element: XMLSchemaElement, in schema: XMLSchema, resolver: SchemaReferenceResolver) throws {
        if let substitutionGroup = element.substitutionGroup,
           resolver.element(
               named: substitutionGroup.localName,
               namespaceURI: substitutionGroup.namespaceURI ?? schema.targetNamespace
           ) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: element.name,
                message: "element '\(element.name)' references unknown substitutionGroup '\(substitutionGroup.qualifiedName)'."
            )
        }

        if let typeQName = element.typeQName,
           !isXMLSchemaBuiltIn(typeQName),
           resolver.complexType(named: typeQName.localName, namespaceURI: typeQName.namespaceURI) == nil,
           resolver.simpleType(named: typeQName.localName, namespaceURI: typeQName.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: element.name,
                message: "element '\(element.name)' references unknown type '\(typeQName.qualifiedName)'."
            )
        }

        if let refQName = element.refQName,
           resolver.element(named: refQName.localName, namespaceURI: refQName.namespaceURI ?? schema.targetNamespace) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: element.name,
                message: "element '\(element.name)' references unknown element '\(refQName.qualifiedName)'."
            )
        }

        if let inlineComplexType = element.inlineComplexType {
            try validateAnonymousComplexType(inlineComplexType, in: schema, contextName: element.name, resolver: resolver)
        }
        if let inlineSimpleType = element.inlineSimpleType {
            try validateAnonymousSimpleType(inlineSimpleType, contextName: element.name, resolver: resolver)
        }
    }

    private func validateAttribute(_ attribute: XMLSchemaAttribute, contextName: String, resolver: SchemaReferenceResolver) throws {
        if let typeQName = attribute.typeQName,
           !isXMLSchemaBuiltIn(typeQName),
           resolver.simpleType(named: typeQName.localName, namespaceURI: typeQName.namespaceURI) == nil,
           resolver.complexType(named: typeQName.localName, namespaceURI: typeQName.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: contextName,
                message: "attribute '\(attribute.name)' references unknown type '\(typeQName.qualifiedName)'."
            )
        }
        if let inlineSimpleType = attribute.inlineSimpleType {
            try validateAnonymousSimpleType(inlineSimpleType, contextName: attribute.name, resolver: resolver)
        }
    }

    private func validateAnonymousComplexType(
        _ complexType: XMLSchemaAnonymousComplexType,
        in schema: XMLSchema,
        contextName: String,
        resolver: SchemaReferenceResolver
    ) throws {
        if let baseQName = complexType.baseQName,
           !isXMLSchemaBuiltIn(baseQName),
           resolver.complexType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: contextName,
                message: "anonymous complexType references unknown base '\(baseQName.qualifiedName)'."
            )
        }

        if let baseQName = complexType.simpleContentBaseQName,
           !isXMLSchemaBuiltIn(baseQName),
           resolver.complexType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil,
           resolver.simpleType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: contextName,
                message: "anonymous simpleContent references unknown base '\(baseQName.qualifiedName)'."
            )
        }

        try validateContentNodes(complexType.content, in: schema, contextName: contextName, resolver: resolver)
        for attribute in complexType.attributes {
            try validateAttribute(attribute, contextName: contextName, resolver: resolver)
        }
        for attributeRef in complexType.attributeRefs
        where resolver.attribute(named: attributeRef.refQName.localName, namespaceURI: attributeRef.refQName.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: contextName,
                message: "attribute reference '\(attributeRef.refQName.qualifiedName)' could not be resolved."
            )
        }
        for attributeGroupRef in complexType.attributeGroupRefs
        where resolver.attributeGroup(named: attributeGroupRef.localName, namespaceURI: attributeGroupRef.namespaceURI) == nil {
            throw XMLSchemaParsingError.unresolvedReference(
                name: contextName,
                message: "attributeGroup reference '\(attributeGroupRef.qualifiedName)' could not be resolved."
            )
        }
    }

    private func validateAnonymousSimpleType(
        _ simpleType: XMLSchemaAnonymousSimpleType,
        contextName: String,
        resolver: SchemaReferenceResolver
    ) throws {
        switch simpleType.derivationKind {
        case .restriction:
            if let baseQName = simpleType.baseQName,
               !isXMLSchemaBuiltIn(baseQName),
               resolver.simpleType(named: baseQName.localName, namespaceURI: baseQName.namespaceURI) == nil {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: contextName,
                    message: "anonymous simpleType references unknown base '\(baseQName.qualifiedName)'."
                )
            }
        case .list:
            if let itemQName = simpleType.listItemQName,
               !isXMLSchemaBuiltIn(itemQName),
               resolver.simpleType(named: itemQName.localName, namespaceURI: itemQName.namespaceURI) == nil {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: contextName,
                    message: "anonymous simpleType references unknown list item '\(itemQName.qualifiedName)'."
                )
            }
        case .union:
            for memberQName in simpleType.unionMemberQNames
            where !isXMLSchemaBuiltIn(memberQName) &&
                resolver.simpleType(named: memberQName.localName, namespaceURI: memberQName.namespaceURI) == nil {
                throw XMLSchemaParsingError.unresolvedReference(
                    name: contextName,
                    message: "anonymous simpleType references unknown union member '\(memberQName.qualifiedName)'."
                )
            }
            for memberSimpleType in simpleType.unionInlineSimpleTypes {
                try validateAnonymousSimpleType(memberSimpleType, contextName: contextName, resolver: resolver)
            }
        }
    }

    private func mergedNamespaceMappings(_ currentNamespaceMappings: [String: String], fallback: [String: String]) -> [String: String] {
        var merged = fallback
        for (key, value) in currentNamespaceMappings {
            merged[key] = value
        }
        return merged
    }

    private func resolveQName(
        fromQualifiedName value: String?,
        namespaceMappings: [String: String],
        context: String
    ) throws -> XMLQualifiedName? {
        guard let normalizedValue = normalized(value) else {
            return nil
        }

        if let separatorIndex = normalizedValue.firstIndex(of: ":") {
            let prefix = String(normalizedValue[..<separatorIndex])
            let localName = String(normalizedValue[normalizedValue.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard !localName.isEmpty else {
                throw XMLSchemaParsingError.invalidDocument(message: "Invalid qualified name '\(normalizedValue)' for \(context).")
            }
            guard let namespaceURI = namespaceMappings[prefix] else {
                throw XMLSchemaParsingError.invalidDocument(message: "Unknown namespace prefix '\(prefix)' for \(context) in '\(normalizedValue)'.")
            }

            return XMLQualifiedName(
                localName: localName,
                namespaceURI: namespaceURI,
                prefix: prefix
            )
        }

        return XMLQualifiedName(
            localName: normalizedValue,
            namespaceURI: namespaceMappings[""]
        )
    }

    private func isXMLSchemaBuiltIn(_ qName: XMLQualifiedName) -> Bool {
        if qName.namespaceURI == "http://www.w3.org/2001/XMLSchema" {
            return true
        }

        let builtInLocalNames: Set<String> = [
            "string", "boolean", "decimal", "float", "double", "duration", "dateTime", "time", "date", "gYearMonth",
            "gYear", "gMonthDay", "gDay", "gMonth", "hexBinary", "base64Binary", "anyURI", "QName", "NOTATION",
            "normalizedString", "token", "language", "NMTOKEN", "NMTOKENS", "Name", "NCName", "ID", "IDREF", "IDREFS",
            "ENTITY", "ENTITIES", "integer", "nonPositiveInteger", "negativeInteger", "long", "int", "short", "byte",
            "nonNegativeInteger", "unsignedLong", "unsignedInt", "unsignedShort", "unsignedByte", "positiveInteger",
            "anyType", "anySimpleType"
        ]
        return qName.namespaceURI == nil && builtInLocalNames.contains(qName.localName)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value else {
            return nil
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func parseBooleanAttribute(named attributeName: String, on node: XMLCoderNode) -> Bool {
        guard let value = normalized(node.attribute(named: attributeName)) else {
            return false
        }
        return value == "true" || value == "1"
    }

    // MARK: - XSD 1.1 parse helpers

    /// Parses `<xsd:assert>` children of `node` into ``XMLSchemaAssertion`` values.
    private func parseAssertions(from nodes: [XMLCoderNode]) -> [XMLSchemaAssertion] {
        nodes.filter { $0.name == "assert" }.compactMap { assertNode -> XMLSchemaAssertion? in
            guard let test = normalized(assertNode.attribute(named: "test")) else { return nil }
            return XMLSchemaAssertion(
                test: test,
                xpathDefaultNamespace: normalized(assertNode.attribute(named: "xpathDefaultNamespace")),
                annotation: parseAnnotation(from: assertNode)
            )
        }
    }

    /// Parses an `<xsd:openContent>` or `<xsd:defaultOpenContent>` node into an ``XMLSchemaOpenContent`` value.
    private func parseOpenContentNode(_ ocNode: XMLCoderNode) throws -> XMLSchemaOpenContent {
        let modeString = normalized(ocNode.attribute(named: "mode")) ?? "interleave"
        let mode = XMLSchemaOpenContentMode(rawValue: modeString) ?? .interleave
        let appliesToEmpty = parseBooleanAttribute(named: "appliesToEmpty", on: ocNode)
        let anyNode = ocNode.children().first(where: { $0.name == "any" })
        let wildcard = try anyNode.map { try parseWildcard($0, kind: .element) }
        return XMLSchemaOpenContent(
            mode: mode,
            any: wildcard,
            appliesToEmpty: appliesToEmpty,
            annotation: parseAnnotation(from: ocNode)
        )
    }

    /// Parses the first `<xsd:openContent>` child among `nodes`.
    private func parseOpenContent(from nodes: [XMLCoderNode]) throws -> XMLSchemaOpenContent? {
        guard let ocNode = nodes.first(where: { $0.name == "openContent" }) else { return nil }
        return try parseOpenContentNode(ocNode)
    }

    /// Parses `<xsd:alternative>` children of `node` into ``XMLSchemaTypeAlternative`` values.
    private func parseTypeAlternatives(
        from nodes: [XMLCoderNode],
        namespaceMappings: [String: String]
    ) throws -> [XMLSchemaTypeAlternative] {
        try nodes.filter { $0.name == "alternative" }.map { altNode in
            let typeQName = try resolveQName(
                fromQualifiedName: altNode.attribute(named: "type"),
                namespaceMappings: namespaceMappings,
                context: "alternative type"
            )
            return XMLSchemaTypeAlternative(
                test: normalized(altNode.attribute(named: "test")),
                typeQName: typeQName,
                annotation: parseAnnotation(from: altNode)
            )
        }
    }

    private func parseAnnotation(from node: XMLCoderNode) -> XMLSchemaAnnotation? {
        guard let annotationNode = node.children().first(where: { $0.name == "annotation" }) else {
            return nil
        }

        let documentation = annotationNode.children()
            .filter { $0.name == "documentation" }
            .compactMap { normalized($0.text()) }
        let appinfo = annotationNode.children()
            .filter { $0.name == "appinfo" }
            .compactMap { normalized($0.text()) }

        let annotation = XMLSchemaAnnotation(documentation: documentation, appinfo: appinfo)
        return annotation.isEmpty ? nil : annotation
    }
}

private struct SchemaReferenceResolver {
    let schemaSet: XMLSchemaSet

    func element(named localName: String, namespaceURI: String?) -> XMLSchemaElement? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let element = schema.elements.first(where: { $0.name == localName }) {
                    return element
                }
            }
        }
        for schema in schemaSet.schemas {
            if let element = schema.elements.first(where: { $0.name == localName }) {
                return element
            }
        }
        return nil
    }

    func complexType(named localName: String, namespaceURI: String?) -> XMLSchemaComplexType? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                    return complexType
                }
            }
        }
        for schema in schemaSet.schemas {
            if let complexType = schema.complexTypes.first(where: { $0.name == localName }) {
                return complexType
            }
        }
        return nil
    }

    func simpleType(named localName: String, namespaceURI: String?) -> XMLSchemaSimpleType? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let simpleType = schema.simpleTypes.first(where: { $0.name == localName }) {
                    return simpleType
                }
            }
        }
        for schema in schemaSet.schemas {
            if let simpleType = schema.simpleTypes.first(where: { $0.name == localName }) {
                return simpleType
            }
        }
        return nil
    }

    func attribute(named localName: String, namespaceURI: String?) -> XMLSchemaAttribute? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let attribute = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                    return attribute
                }
            }
        }
        for schema in schemaSet.schemas {
            if let attribute = schema.attributeDefinitions.first(where: { $0.name == localName }) {
                return attribute
            }
        }
        return nil
    }

    func attributeGroup(named localName: String, namespaceURI: String?) -> XMLSchemaAttributeGroup? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                    return attributeGroup
                }
            }
        }
        for schema in schemaSet.schemas {
            if let attributeGroup = schema.attributeGroups.first(where: { $0.name == localName }) {
                return attributeGroup
            }
        }
        return nil
    }

    func modelGroup(named localName: String, namespaceURI: String?) -> XMLSchemaModelGroup? {
        if let namespaceURI = namespaceURI {
            for schema in schemaSet.schemas where schema.targetNamespace == namespaceURI {
                if let modelGroup = schema.modelGroups.first(where: { $0.name == localName }) {
                    return modelGroup
                }
            }
        }
        for schema in schemaSet.schemas {
            if let modelGroup = schema.modelGroups.first(where: { $0.name == localName }) {
                return modelGroup
            }
        }
        return nil
    }
}

// MARK: - Async parsing (Swift 5.5+)

#if swift(>=5.5)
extension XMLSchemaDocumentParser {
    /// Async variant of `parseDocument`. Calls `appendSchemaRecursivelyAsync`
    /// which parallelises schema I/O at each import level with a `TaskGroup`.
    func parseDocumentAsync(data: Data, sourceURL: URL?) async throws -> XMLSchemaSet {
        let document: XMLCoderDocument
        do {
            if let sourceURL = sourceURL {
                document = try XMLCoderDocument(data: data, sourceURL: sourceURL)
            } else {
                document = try XMLCoderDocument(data: data)
            }
        } catch {
            throw XMLSchemaParsingError.invalidDocument(
                message: "Unable to parse XML document.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
            )
        }

        let schemaNodes = try findSchemaNodes(in: document)
        if schemaNodes.isEmpty {
            throw XMLSchemaParsingError.invalidDocument(
                message: "Missing xsd:schema root node.",
                sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
            )
        }

        var collectedSchemas: [XMLSchema] = []
        var loadedSchemaURLs = Set<String>()

        if let sourceURL = sourceURL, sourceURL.isFileURL {
            loadedSchemaURLs.insert(sourceURL.standardizedFileURL.path)
        }

        let fallbackNamespaceMappings = document.rootElement()?.namespaceDeclarationsInScope() ?? [:]
        for schemaNode in schemaNodes {
            try await appendSchemaRecursivelyAsync(
                schemaNode: schemaNode,
                sourceURL: sourceURL,
                fallbackNamespaceMappings: fallbackNamespaceMappings,
                loadedSchemaURLs: &loadedSchemaURLs,
                schemas: &collectedSchemas
            )
        }

        let schemaSet = XMLSchemaSet(schemas: collectedSchemas)
        try validateSchemaConsistency(schemaSet)
        return schemaSet
    }

    /// Async variant of `appendSchemaRecursively`.
    ///
    /// URL resolution and cycle detection remain sequential to preserve
    /// `inout` correctness. Schema data is fetched concurrently via
    /// `withThrowingTaskGroup`, then parsed and recursed sequentially.
    private func appendSchemaRecursivelyAsync(
        schemaNode: XMLCoderNode,
        sourceURL: URL?,
        fallbackNamespaceMappings: [String: String],
        loadedSchemaURLs: inout Set<String>,
        schemas: inout [XMLSchema]
    ) async throws {
        let namespaceMappings = mergedNamespaceMappings(
            schemaNode.namespaceDeclarationsInScope(),
            fallback: fallbackNamespaceMappings
        )

        let parsedSchema = try parseSchema(
            schemaNode: schemaNode,
            sourceURL: sourceURL,
            namespaceMappings: namespaceMappings
        )
        schemas.append(parsedSchema)

        let importReferences = parsedSchema.imports.compactMap { $0.schemaLocation }
        let includeReferences = parsedSchema.includes.map { $0.schemaLocation }
        let references = importReferences + includeReferences

        // Resolve all import URLs sequentially: URL arithmetic is fast and
        // mutation of loadedSchemaURLs must remain single-threaded.
        var toFetch: [(schemaLocation: String, schemaURL: URL)] = []
        for schemaLocation in references {
            let schemaURL = try await resourceResolver.resolve(
                schemaLocation: schemaLocation,
                relativeTo: sourceURL
            )
            let key = schemaURL.standardizedFileURL.path
            if !loadedSchemaURLs.contains(key) {
                loadedSchemaURLs.insert(key)
                toFetch.append((schemaLocation, schemaURL))
            }
        }

        guard !toFetch.isEmpty else { return }

        // Fetch schema data concurrently. Only Sendable values (self, schemaURL)
        // are captured in the task closure — no inout parameters.
        var fetchedData: [(URL, Data)] = []
        fetchedData.reserveCapacity(toFetch.count)
        try await withThrowingTaskGroup(of: (URL, Data).self) { group in
            for (_, schemaURL) in toFetch {
                group.addTask {
                    let data = try await self.resourceResolver.loadSchemaData(from: schemaURL)
                    return (schemaURL, data)
                }
            }
            for try await result in group {
                fetchedData.append(result)
            }
        }

        // Parse and recurse sequentially to maintain inout correctness.
        for (schemaURL, importedData) in fetchedData {
            let importedDocument: XMLCoderDocument
            do {
                importedDocument = try XMLCoderDocument(data: importedData, sourceURL: schemaURL)
            } catch {
                throw XMLSchemaParsingError.invalidSchema(
                    name: nil,
                    message: "Unable to parse imported schema at '\(schemaURL.absoluteString)'.",
                    sourceLocation: XMLSchemaSourceLocation(fileURL: sourceURL)
                )
            }

            let importedSchemaNodes = try findSchemaNodes(in: importedDocument)
            for importedSchemaNode in importedSchemaNodes {
                try await appendSchemaRecursivelyAsync(
                    schemaNode: importedSchemaNode,
                    sourceURL: schemaURL,
                    fallbackNamespaceMappings: namespaceMappings,
                    loadedSchemaURLs: &loadedSchemaURLs,
                    schemas: &schemas
                )
            }
        }
    }
}
#endif
