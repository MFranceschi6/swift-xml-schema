// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftXMLSchema",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15)
    ],
    products: [
        .library(name: "SwiftXMLSchema", targets: ["SwiftXMLSchema"]),
        .executable(name: "XMLSchemaTool", targets: ["XMLSchemaTool"]),
        .plugin(name: "XMLSchemaPlugin", targets: ["XMLSchemaPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/MFranceschi6/swift-xml-coder.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftXMLSchema",
            dependencies: [
                .product(name: "SwiftXMLCoder", package: "swift-xml-coder")
            ]
        ),
        .executableTarget(
            name: "XMLSchemaTool",
            dependencies: ["SwiftXMLSchema"]
        ),
        .plugin(
            name: "XMLSchemaPlugin",
            capability: .buildTool(),
            dependencies: ["XMLSchemaTool"]
        ),
        .testTarget(
            name: "SwiftXMLSchemaTests",
            dependencies: ["SwiftXMLSchema"]
        )
    ],
    swiftLanguageModes: [
        .v6
    ]
)
