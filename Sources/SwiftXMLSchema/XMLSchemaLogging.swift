// MARK: - Logging label conventions
//
// All SwiftXMLSchema components accept an optional `Logger` at initialisation time.
// When you want to route or filter logs, pass a pre-configured `Logger` instance.
//
// Recommended label prefixes:
//   "SwiftXMLSchema.parser"     — XMLSchemaDocumentParser
//   "SwiftXMLSchema.normalizer" — XMLSchemaNormalizer
//   "SwiftXMLSchema.differ"     — XMLSchemaDiffer
//   "SwiftXMLSchema.exporter"   — XMLJSONSchemaExporter
//   "SwiftXMLSchema.resolver"   — any XMLSchemaResourceResolver conformance
//
// Example — silence all SwiftXMLSchema logs except warnings:
//
//     var logger = Logger(label: "SwiftXMLSchema.parser")
//     logger.logLevel = .warning
//     let parser = XMLSchemaDocumentParser(logger: logger)
//
// Example — enable trace-level logs for the parser only:
//
//     var logger = Logger(label: "SwiftXMLSchema.parser")
//     logger.logLevel = .trace
//     let parser = XMLSchemaDocumentParser(logger: logger)
