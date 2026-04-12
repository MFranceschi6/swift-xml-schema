import Foundation
import Logging
import SwiftXMLCoder

// MARK: - XMLSchemaInferrer

/// Infers an XSD schema from one or more XML instance documents.
///
/// ### Algorithm
///
/// The inferrer walks each XML document depth-first and accumulates structural and
/// type information per element name (scoped to its parent). Across multiple samples:
///
/// - An element that does not appear in every sample gets `minOccurs="0"`.
/// - An element that appears more than once within a single parent instance gets
///   `maxOccurs="unbounded"`.
/// - An attribute absent in at least one sample is declared `use="optional"`;
///   one present in every sample is declared `use="required"`.
/// - Text content types are widened to the least-specific compatible XSD type
///   (`xsd:boolean` → `xsd:integer` → `xsd:decimal` → `xsd:date` → `xsd:dateTime` → `xsd:string`).
///
/// ### Limitations (v1)
///
/// - Recursion and type reuse are not detected; every element is expanded inline.
/// - Namespace inference uses the root element's `namespaceURI`; mixed namespaces
///   within one document are not handled.
/// - Pattern, enumeration, and length facets are not inferred.
///
/// ### Usage
///
/// ```swift
/// let inferrer = XMLSchemaInferrer()
/// let xsdData = try inferrer.infer(from: xmlData)            // single sample
/// let xsdData = try inferrer.infer(from: [xml1, xml2, xml3]) // multiple samples
/// ```
public struct XMLSchemaInferrer: Sendable {
    public let logger: Logger

    public init(logger: Logger = Logger(label: "SwiftXMLSchema.inferrer")) {
        self.logger = logger
    }

    // MARK: - Public API

    /// Infers an XSD schema from a single XML document.
    ///
    /// Throws an `XMLParsingError` if `data` is not well-formed XML.
    public func infer(from data: Data) throws -> Data {
        let parser = XMLTreeParser()
        let document = try parser.parse(data: data)
        return infer(from: [document])
    }

    /// Infers an XSD schema from multiple XML documents, merging structural information.
    ///
    /// All documents should share the same root element name and overall structure.
    /// Throws an `XMLParsingError` if any element of `samples` is not well-formed XML.
    public func infer(from samples: [Data]) throws -> Data {
        let parser = XMLTreeParser()
        let documents = try samples.map { try parser.parse(data: $0) }
        return infer(from: documents)
    }

    /// Infers an XSD schema from one already-parsed document.
    public func infer(from document: XMLTreeDocument) -> Data {
        infer(from: [document])
    }

    /// Infers an XSD schema from multiple already-parsed documents.
    public func infer(from documents: [XMLTreeDocument]) -> Data {
        guard !documents.isEmpty else {
            return Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"/>\n".utf8)
        }

        logger.debug("Starting schema inference", metadata: [
            "samples": .stringConvertible(documents.count),
            "root": .string(documents[0].root.name.localName)
        ])

        // Infer targetNamespace from first document root
        let targetNamespace = documents[0].root.name.namespaceURI

        // Accumulate element schemas across all documents
        var rootSchema = ElementSchema(totalSamples: documents.count)
        for (index, document) in documents.enumerated() {
            logger.trace("Processing sample", metadata: ["index": .stringConvertible(index)])
            accumulateElement(document.root, into: &rootSchema, sampleIndex: index)
        }

        // Render to XSD
        let xsd = render(root: documents[0].root.name.localName, schema: rootSchema, targetNamespace: targetNamespace)
        logger.info("Schema inference complete", metadata: [
            "targetNamespace": .string(targetNamespace ?? "(none)"),
            "outputBytes": .stringConvertible(xsd.utf8.count)
        ])
        return Data(xsd.utf8)
    }
}
