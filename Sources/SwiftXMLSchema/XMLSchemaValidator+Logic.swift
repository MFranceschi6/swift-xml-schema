import Foundation
import Logging
import SwiftXMLCoder

// MARK: - Validation context

extension XMLSchemaValidator {
    struct ValidationContext {
        let schemaSet: XMLNormalizedSchemaSet
        var diagnostics: [XMLSchemaValidationDiagnostic] = []
        let logger: Logger

        mutating func addError(path: String, message: String) {
            logger.trace("Validation error", metadata: ["path": .string(path), "message": .string(message)])
            diagnostics.append(XMLSchemaValidationDiagnostic(severity: .error, path: path, message: message))
        }

        mutating func addWarning(path: String, message: String) {
            logger.trace("Validation warning", metadata: ["path": .string(path), "message": .string(message)])
            diagnostics.append(XMLSchemaValidationDiagnostic(severity: .warning, path: path, message: message))
        }
    }
}

// MARK: - Root and element dispatch

extension XMLSchemaValidator {

    /// Entry point: validates the document root against its top-level element declaration.
    func validateRoot(_ element: XMLTreeElement, context: inout ValidationContext) {
        let path = "/\(element.name.localName)"
        let decl = context.schemaSet.element(
            named: element.name.localName,
            namespaceURI: element.name.namespaceURI
        )
        guard let decl = decl else {
            context.addError(
                path: path,
                message: "Root element '\(element.name.localName)' is not declared in the schema"
            )
            return
        }
        logger.trace("Validating root element", metadata: [
            "element": .string(element.name.localName),
            "type": .string(decl.typeQName.map { $0.localName } ?? "(anonymous)")
        ])
        validateElementByDeclaration(element, declaration: decl, path: path, context: &context)
    }

    /// Validates a single element node given its top-level element declaration.
    private func validateElementByDeclaration(
        _ element: XMLTreeElement,
        declaration: XMLNormalizedElementDeclaration,
        path: String,
        context: inout ValidationContext
    ) {
        guard let typeQName = declaration.typeQName else {
            // No explicit type — check children heuristically (any content allowed)
            return
        }
        validateElementByType(element, typeQName: typeQName, path: path, context: &context)
    }

    /// Validates a single element node given its type QName.
    func validateElementByType(
        _ element: XMLTreeElement,
        typeQName: XMLQualifiedName,
        path: String,
        context: inout ValidationContext
    ) {
        // XSD built-in simple types — validate text content via facets
        if typeQName.namespaceURI == Self.xsdNamespace {
            let text = textContent(of: element)
            validateBuiltinSimpleType(
                value: text,
                typeName: typeQName.localName,
                path: path,
                context: &context
            )
            return
        }

        // User-defined complex type
        if let complexType = context.schemaSet.complexType(typeQName) {
            validateComplexTyped(element, complexType: complexType, path: path, context: &context)
            return
        }

        // User-defined simple type
        if let simpleType = context.schemaSet.simpleType(typeQName) {
            let text = textContent(of: element)
            validateSimpleType(value: text, simpleType: simpleType, path: path, context: &context)
            return
        }

        // Type unknown (could be from an external namespace — skip silently)
        logger.trace("Type not found in schema set — skipping element validation", metadata: [
            "element": .string(element.name.localName),
            "type": .string(typeQName.localName),
            "typeNamespace": .string(typeQName.namespaceURI ?? "(none)")
        ])
    }

    // MARK: - Complex type validation

    private func validateComplexTyped(
        _ element: XMLTreeElement,
        complexType: XMLNormalizedComplexType,
        path: String,
        context: inout ValidationContext
    ) {
        validateAttributes(element, complexType: complexType, path: path, context: &context)

        // Simple content path
        if let valueTypeQName = complexType.effectiveSimpleContentValueTypeQName {
            let text = textContent(of: element)
            validateElementByType(
                element,
                typeQName: valueTypeQName,
                path: "\(path)/@text",
                context: &context
            )
            _ = text // text consumed by validateElementByType above
            return
        }

        // Sequence content
        validateContentModel(
            element,
            effectiveContent: complexType.effectiveContent,
            openContent: complexType.openContent,
            path: path,
            context: &context
        )
    }

    // MARK: - Content model validation

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func validateContentModel(
        _ parent: XMLTreeElement,
        effectiveContent: [XMLNormalizedContentNode],
        openContent: XMLSchemaOpenContent? = nil,
        path: String,
        context: inout ValidationContext
    ) {
        let childElements = parent.children.compactMap { node -> XMLTreeElement? in
            if case .element(let el) = node { return el }
            return nil
        }

        // Build a set of all declared element names from the effective content
        var declaredNames: Set<String> = []
        var hasWildcard = false
        for node in effectiveContent {
            switch node {
            case .element(let use):
                declaredNames.insert(use.name)
            case .choice(let group):
                for childNode in group.content {
                    if case .element(let use) = childNode { declaredNames.insert(use.name) }
                }
            case .wildcard:
                hasWildcard = true
            }
        }

        // XSD 1.1: openContent with mode != .none allows extra elements not in the declared set.
        let hasOpenContent = openContent.map { $0.mode != .none } ?? false

        // Flag undeclared XML child elements
        if !hasWildcard && !hasOpenContent {
            for child in childElements where !declaredNames.contains(child.name.localName) {
                context.addError(
                    path: "\(path)/\(child.name.localName)",
                    message: "Element '\(child.name.localName)' is not declared in the content model of '\(parent.name.localName)'"
                )
            }
        }

        // Validate occurrence bounds and recurse
        for node in effectiveContent {
            switch node {
            case .element(let use):
                validateElementUse(use, inChildren: childElements, parentPath: path, context: &context)
            case .choice(let group):
                validateChoiceGroup(group, inChildren: childElements, parentPath: path, context: &context)
            case .wildcard:
                break
            }
        }
    }

    /// Validates occurrence bounds for a single element use and recursively validates matching children.
    private func validateElementUse(
        _ use: XMLNormalizedElementUse,
        inChildren children: [XMLTreeElement],
        parentPath: String,
        context: inout ValidationContext
    ) {
        let matching = children.filter { $0.name.localName == use.name }
        let count = matching.count
        let bounds = use.occurrenceBounds

        if count < bounds.minOccurs {
            context.addError(
                path: parentPath,
                message: "Element '\(use.name)' must appear at least \(bounds.minOccurs) time(s); found \(count)"
            )
        }
        if let max = bounds.maxOccurs, count > max {
            context.addError(
                path: parentPath,
                message: "Element '\(use.name)' must appear at most \(max) time(s); found \(count)"
            )
        }

        // Validate fixed value constraint
        if let fixed = use.fixedValue {
            for (index, child) in matching.enumerated() {
                let text = textContent(of: child)
                let elemPath = matchingPath(parentPath: parentPath, name: use.name, index: index, total: count)
                if !text.isEmpty && text != fixed {
                    context.addError(
                        path: elemPath,
                        message: "Element '\(use.name)' has fixed value '\(fixed)' but found '\(text)'"
                    )
                }
            }
        }

        // Recurse into each matching child
        if let typeQName = use.typeQName {
            for (index, child) in matching.enumerated() {
                let childPath = matchingPath(parentPath: parentPath, name: use.name, index: index, total: count)
                logger.trace("Validating child element", metadata: [
                    "element": .string(use.name),
                    "path": .string(childPath)
                ])
                validateElementByType(child, typeQName: typeQName, path: childPath, context: &context)
            }
        }
    }

    /// Validates that at least one branch of a choice group is satisfied, then recurses into it.
    private func validateChoiceGroup(
        _ group: XMLNormalizedChoiceGroup,
        inChildren children: [XMLTreeElement],
        parentPath: String,
        context: inout ValidationContext
    ) {
        // Find the first branch that has at least one matching element
        let matchedBranch = group.content.first { node -> Bool in
            if case .element(let use) = node {
                return children.contains { $0.name.localName == use.name }
            }
            return false
        }

        if matchedBranch == nil, group.occurrenceBounds.minOccurs > 0 {
            let branchNames = group.content.compactMap { node -> String? in
                if case .element(let use) = node { return use.name }
                return nil
            }.joined(separator: ", ")
            context.addError(
                path: parentPath,
                message: "Choice group [\(branchNames)] requires at least one branch to be present"
            )
            return
        }

        // Validate only the selected branch
        if let matchedBranch = matchedBranch, case .element(let use) = matchedBranch {
            validateElementUse(use, inChildren: children, parentPath: parentPath, context: &context)
        }
    }

    // MARK: - Attribute validation

    private func validateAttributes(
        _ element: XMLTreeElement,
        complexType: XMLNormalizedComplexType,
        path: String,
        context: inout ValidationContext
    ) {
        let hasAnyAttr = complexType.anyAttribute != nil
        let declaredAttrs = complexType.effectiveAttributes

        // Check required and prohibited attributes
        for declared in declaredAttrs {
            let xmlAttr = element.attributes.first { $0.name.localName == declared.name }
            switch declared.use {
            case .required:
                if xmlAttr == nil {
                    context.addError(
                        path: path,
                        message: "Required attribute '\(declared.name)' is missing on element '\(element.name.localName)'"
                    )
                } else if let value = xmlAttr?.value, let fixed = declared.fixedValue, value != fixed {
                    context.addError(
                        path: "\(path)/@\(declared.name)",
                        message: "Attribute '\(declared.name)' has fixed value '\(fixed)' but found '\(value)'"
                    )
                }
            case .prohibited:
                if xmlAttr != nil {
                    context.addError(
                        path: path,
                        message: "Attribute '\(declared.name)' is prohibited on element '\(element.name.localName)'"
                    )
                }
            default:
                // optional — just validate the value if present
                break
            }

            // Validate attribute value against its type
            if let xmlAttr = xmlAttr, let typeQName = declared.typeQName {
                validateAttributeValue(
                    xmlAttr.value,
                    typeQName: typeQName,
                    attrName: declared.name,
                    path: "\(path)/@\(declared.name)",
                    context: &context
                )
            }
        }

        // Flag unknown attributes when no anyAttribute wildcard
        if !hasAnyAttr {
            let declaredNames = Set(declaredAttrs.map(\.name))
            for xmlAttr in element.attributes {
                // Skip namespace declarations and xsi: attributes
                let attrLocalName = xmlAttr.name.localName
                let attrNS = xmlAttr.name.namespaceURI ?? ""
                guard attrNS != "http://www.w3.org/2000/xmlns/" &&
                      attrNS != "http://www.w3.org/2001/XMLSchema-instance" else { continue }
                if !declaredNames.contains(attrLocalName) {
                    context.addWarning(
                        path: "\(path)/@\(attrLocalName)",
                        message: "Attribute '\(attrLocalName)' is not declared on type '\(element.name.localName)'"
                    )
                }
            }
        }
    }

    // MARK: - Attribute value type validation

    private func validateAttributeValue(
        _ value: String,
        typeQName: XMLQualifiedName,
        attrName: String,
        path: String,
        context: inout ValidationContext
    ) {
        if typeQName.namespaceURI == Self.xsdNamespace {
            validateBuiltinSimpleType(value: value, typeName: typeQName.localName, path: path, context: &context)
        } else if let simpleType = context.schemaSet.simpleType(typeQName) {
            validateSimpleType(value: value, simpleType: simpleType, path: path, context: &context)
        }
    }

    // MARK: - Simple type validation

    func validateSimpleType(
        value: String,
        simpleType: XMLNormalizedSimpleType,
        path: String,
        context: inout ValidationContext
    ) {
        switch simpleType.derivationKind {
        case .restriction:
            // Enumeration
            if !simpleType.enumerationValues.isEmpty && !simpleType.enumerationValues.contains(value) {
                context.addError(
                    path: path,
                    message: "Value '\(value)' is not in the allowed enumeration: [\(simpleType.enumerationValues.joined(separator: ", "))]"
                )
            }
            // Facets
            if let facets = simpleType.facets {
                validateFacets(value: value, facets: facets, path: path, context: &context)
            }
            // Base type constraint (delegate to base)
            if let baseQName = simpleType.baseQName {
                if baseQName.namespaceURI == Self.xsdNamespace {
                    validateBuiltinSimpleType(value: value, typeName: baseQName.localName, path: path, context: &context)
                } else if let base = context.schemaSet.simpleType(baseQName) {
                    validateSimpleType(value: value, simpleType: base, path: path, context: &context)
                }
            }

        case .list:
            // Each space-separated token is validated against the item type
            let tokens = value.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            if let itemQName = simpleType.listItemQName {
                for token in tokens {
                    validateAttributeValue(token, typeQName: itemQName, attrName: "", path: "\(path)[list-item]", context: &context)
                }
            }

        case .union:
            // Value must satisfy at least one member type
            var satisfied = false
            for memberQName in simpleType.unionMemberQNames {
                var probe = ValidationContext(schemaSet: context.schemaSet, logger: logger)
                validateAttributeValue(value, typeQName: memberQName, attrName: "", path: path, context: &probe)
                if probe.diagnostics.isEmpty {
                    satisfied = true
                    break
                }
            }
            if !satisfied && !simpleType.unionMemberQNames.isEmpty {
                context.addError(
                    path: path,
                    message: "Value '\(value)' does not satisfy any of the union member types"
                )
            }
        }
    }

    // MARK: - Facet validation

    // swiftlint:disable:next cyclomatic_complexity
    private func validateFacets(
        value: String,
        facets: XMLSchemaFacetSet,
        path: String,
        context: inout ValidationContext
    ) {
        // Enumeration (handled at call site too, but double-check)
        if !facets.enumeration.isEmpty && !facets.enumeration.contains(value) {
            context.addError(
                path: path,
                message: "Value '\(value)' is not in the allowed enumeration: [\(facets.enumeration.joined(separator: ", "))]"
            )
        }

        // String length facets
        let len = value.count
        if let exactLen = facets.length, len != exactLen {
            context.addError(path: path, message: "Value length \(len) does not equal required length \(exactLen)")
        }
        if let minLen = facets.minLength, len < minLen {
            context.addError(path: path, message: "Value length \(len) is less than minLength \(minLen)")
        }
        if let maxLen = facets.maxLength, len > maxLen {
            context.addError(path: path, message: "Value length \(len) exceeds maxLength \(maxLen)")
        }

        // Numeric range facets (best-effort: parse as Double for comparison)
        if let minInclStr = facets.minInclusive, let minIncl = Double(minInclStr), let num = Double(value), num < minIncl {
            context.addError(path: path, message: "Value \(value) is less than minInclusive \(minInclStr)")
        }
        if let maxInclStr = facets.maxInclusive, let maxIncl = Double(maxInclStr), let num = Double(value), num > maxIncl {
            context.addError(path: path, message: "Value \(value) exceeds maxInclusive \(maxInclStr)")
        }
        if let minExclStr = facets.minExclusive, let minExcl = Double(minExclStr), let num = Double(value), num <= minExcl {
            context.addError(path: path, message: "Value \(value) is not greater than minExclusive \(minExclStr)")
        }
        if let maxExclStr = facets.maxExclusive, let maxExcl = Double(maxExclStr), let num = Double(value), num >= maxExcl {
            context.addError(path: path, message: "Value \(value) is not less than maxExclusive \(maxExclStr)")
        }

        // totalDigits / fractionDigits
        if let totalDigits = facets.totalDigits {
            let digits = value.filter(\.isNumber).count
            if digits > totalDigits {
                context.addError(path: path, message: "Value '\(value)' has more than \(totalDigits) total digit(s)")
            }
        }
    }

    // MARK: - Built-in XSD simple type validation

    private func validateBuiltinSimpleType(
        value: String,
        typeName: String,
        path: String,
        context: inout ValidationContext
    ) {
        switch typeName {
        case "integer", "int", "long", "short", "byte",
             "nonNegativeInteger", "positiveInteger",
             "nonPositiveInteger", "negativeInteger",
             "unsignedLong", "unsignedInt", "unsignedShort", "unsignedByte":
            guard Int64(value) != nil else {
                context.addError(path: path, message: "Value '\(value)' is not a valid \(typeName)")
                return
            }
            // Range checks for bounded types
            switch typeName {
            case "int":
                if let num = Int64(value), num < Int64(Int32.min) || num > Int64(Int32.max) {
                    context.addError(path: path, message: "Value '\(value)' is out of range for xsd:int")
                }
            case "short":
                if let num = Int64(value), num < Int64(Int16.min) || num > Int64(Int16.max) {
                    context.addError(path: path, message: "Value '\(value)' is out of range for xsd:short")
                }
            case "byte":
                if let num = Int64(value), num < Int64(Int8.min) || num > Int64(Int8.max) {
                    context.addError(path: path, message: "Value '\(value)' is out of range for xsd:byte")
                }
            case "nonNegativeInteger":
                if let num = Int64(value), num < 0 {
                    context.addError(path: path, message: "Value '\(value)' must be non-negative for xsd:nonNegativeInteger")
                }
            case "positiveInteger":
                if let num = Int64(value), num <= 0 {
                    context.addError(path: path, message: "Value '\(value)' must be positive for xsd:positiveInteger")
                }
            case "nonPositiveInteger":
                if let num = Int64(value), num > 0 {
                    context.addError(path: path, message: "Value '\(value)' must be non-positive for xsd:nonPositiveInteger")
                }
            case "negativeInteger":
                if let num = Int64(value), num >= 0 {
                    context.addError(path: path, message: "Value '\(value)' must be negative for xsd:negativeInteger")
                }
            default:
                break
            }

        case "decimal", "float", "double":
            if Double(value) == nil {
                context.addError(path: path, message: "Value '\(value)' is not a valid \(typeName)")
            }

        case "boolean":
            if value != "true" && value != "false" && value != "1" && value != "0" {
                context.addError(path: path, message: "Value '\(value)' is not a valid xsd:boolean (expected true/false/1/0)")
            }

        case "date":
            if !isValidXSDDate(value) {
                context.addError(path: path, message: "Value '\(value)' is not a valid xsd:date (expected YYYY-MM-DD)")
            }

        case "dateTime":
            if !isValidXSDDateTime(value) {
                context.addError(path: path, message: "Value '\(value)' is not a valid xsd:dateTime")
            }

        case "anyURI":
            // Very permissive — just check it's not empty when non-optional
            break

        default:
            // string, normalizedString, token, language, Name, NCName, ID, IDREF, etc. — no further constraints
            break
        }
    }

    // MARK: - Helpers

    private static let xsdNamespace = "http://www.w3.org/2001/XMLSchema"

    /// Returns the concatenated text content of an element (ignoring child elements).
    private func textContent(of element: XMLTreeElement) -> String {
        element.children.compactMap { node -> String? in
            switch node {
            case .text(let text): return text
            case .cdata(let text): return text
            default: return nil
            }
        }.joined()
    }

    /// Builds a path component for an element use match, adding `[n]` when count > 1.
    private func matchingPath(parentPath: String, name: String, index: Int, total: Int) -> String {
        total > 1 ? "\(parentPath)/\(name)[\(index + 1)]" : "\(parentPath)/\(name)"
    }

    /// Returns `true` if `value` matches the `YYYY-MM-DD` XSD date format.
    private func isValidXSDDate(_ value: String) -> Bool {
        let parts = value.split(separator: "-", maxSplits: 3)
        guard parts.count == 3,
              let year = Int(parts[0]), year >= 1,
              let month = Int(parts[1]), (1...12).contains(month),
              let day = Int(parts[2]), (1...31).contains(day) else { return false }
        return true
    }

    /// Returns `true` if `value` looks like a valid ISO 8601 dateTime.
    private func isValidXSDDateTime(_ value: String) -> Bool {
        guard value.contains("T") else { return false }
        let components = value.split(separator: "T", maxSplits: 1)
        guard components.count == 2 else { return false }
        return isValidXSDDate(String(components[0]))
    }
}
