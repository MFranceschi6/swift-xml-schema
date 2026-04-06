import Foundation
import SwiftXMLSchema

// MARK: - Argument parsing

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fputs("""
    Usage: XMLSchemaTool <input.xsd> <output.json>

    Parses an XSD schema file and writes the normalised schema model as JSON.
    A <output.json>.sha256 file containing the schema fingerprint is also written.

    """, stderr)
    exit(1)
}

let inputPath = arguments[1]
let outputPath = arguments[2]

// MARK: - Parse → Normalise → Serialise

do {
    let inputURL = URL(fileURLWithPath: inputPath)
    let schemaSet = try XMLSchemaDocumentParser().parse(url: inputURL)
    let normalized = try XMLSchemaNormalizer().normalize(schemaSet)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let jsonData = try encoder.encode(normalized)

    let outputURL = URL(fileURLWithPath: outputPath)
    try jsonData.write(to: outputURL)

    #if canImport(CryptoKit)
    let fingerprintData = Data(normalized.fingerprint.utf8)
    let fingerprintURL = URL(fileURLWithPath: outputPath + ".sha256")
    try fingerprintData.write(to: fingerprintURL)
    #endif
} catch let error as XMLSchemaParsingError {
    fputs("Error: \(error)\n", stderr)
    exit(1)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
