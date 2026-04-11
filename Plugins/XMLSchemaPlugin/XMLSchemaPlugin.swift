import Foundation
import PackagePlugin

/// Build tool plugin that generates a normalised schema model JSON for each
/// `.xsd` file found in the target's source files.
///
/// For every `Foo.xsd` the plugin produces:
///   - `<work-dir>/Foo.schema.json`   — the normalised schema model
///   - `<work-dir>/Foo.schema.json.sha256` — SHA-256 fingerprint (Apple only)
///
/// To use the plugin, add it to a target in your `Package.swift`:
///
/// ```swift
/// .target(
///     name: "MyTarget",
///     plugins: [.plugin(name: "XMLSchemaPlugin", package: "swift-xml-schema")]
/// )
/// ```
@main
struct XMLSchemaPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }

        let tool = try context.tool(named: "XMLSchemaTool")

        return sourceTarget.sourceFiles(withSuffix: ".xsd").map { xsdFile in
            #if compiler(>=6.0)
            let xsdURL = xsdFile.url
            let stem = xsdURL.deletingPathExtension().lastPathComponent
            let workDir = context.pluginWorkDirectoryURL
            let outputJSON = workDir.appending(path: "\(stem).schema.json")
            let fingerprintFile = workDir.appending(path: "\(stem).schema.json.sha256")

            return .buildCommand(
                displayName: "Generating schema JSON for \(xsdURL.lastPathComponent)",
                executable: tool.url,
                arguments: [
                    xsdURL.path,
                    outputJSON.path
                ],
                inputFiles: [xsdURL],
                outputFiles: [outputJSON, fingerprintFile]
            )
            #else
            let stem = xsdFile.path.stem
            let outputJSON = context.pluginWorkDirectory.appending("\(stem).schema.json")
            let fingerprintFile = context.pluginWorkDirectory.appending("\(stem).schema.json.sha256")

            return .buildCommand(
                displayName: "Generating schema JSON for \(xsdFile.path.lastComponent)",
                executable: tool.path,
                arguments: [
                    xsdFile.path.string,
                    outputJSON.string
                ],
                inputFiles: [xsdFile.path],
                outputFiles: [outputJSON, fingerprintFile]
            )
            #endif
        }
    }
}
