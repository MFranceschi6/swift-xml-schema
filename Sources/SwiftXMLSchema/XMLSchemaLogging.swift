import Logging

// MARK: - Per-subsystem loggers
//
// One Logger per logical subsystem, labelled as "SwiftXMLSchema.<subsystem>".
// Consumers can configure routing and minimum log level via LoggingSystem.bootstrap().
//
// Example — silence all SwiftXMLSchema logs except warnings:
//
//     LoggingSystem.bootstrap { label in
//         var handler = StreamLogHandler.standardError(label: label)
//         if label.hasPrefix("SwiftXMLSchema") {
//             handler.logLevel = .warning
//         }
//         return handler
//     }
//
// Example — enable trace-level parser logs only:
//
//     LoggingSystem.bootstrap { label in
//         var handler = StreamLogHandler.standardError(label: label)
//         handler.logLevel = label == "SwiftXMLSchema.parser" ? .trace : .warning
//         return handler
//     }

/// Logs XSD document loading, import/include resolution, and per-component parsing.
let parserLogger = Logger(label: "SwiftXMLSchema.parser")

/// Logs type-reference resolution, inheritance-chain traversal, and effective-content synthesis.
let normalizerLogger = Logger(label: "SwiftXMLSchema.normalizer")

/// Logs schema diff computation and breaking-change classification.
let differLogger = Logger(label: "SwiftXMLSchema.differ")

/// Logs JSON Schema export progress and type mapping.
let exporterLogger = Logger(label: "SwiftXMLSchema.exporter")

/// Logs schema location resolution, file I/O, and remote fetches.
let resolverLogger = Logger(label: "SwiftXMLSchema.resolver")
