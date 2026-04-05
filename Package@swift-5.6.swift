// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SwiftXMLSchema",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v15)
    ],
    products: [
        .library(name: "SwiftXMLSchema", targets: ["SwiftXMLSchema"])
    ],
    dependencies: [
        .package(url: "https://github.com/MFranceschi6/swift-xml-coder.git", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "SwiftXMLSchema",
            dependencies: [
                .product(name: "SwiftXMLCoder", package: "swift-xml-coder")
            ],
            // XMLSchemaVisitor.swift and XMLSchemaWalker.swift use Swift 5.7 features
            // (primary associated types, `some` parameter types) and must be excluded
            // from the 5.6 toolchain lane.
            exclude: [
                "XMLSchemaVisitor.swift",
                "XMLSchemaWalker.swift"
            ]
        ),
        .testTarget(
            name: "SwiftXMLSchemaTests",
            dependencies: ["SwiftXMLSchema"],
            exclude: [
                "XMLSchemaVisitorWalkerTests.swift"
            ]
        )
    ]
)
