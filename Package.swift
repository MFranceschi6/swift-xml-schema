// swift-tools-version: 5.4

import PackageDescription

let package = Package(
    name: "SwiftXMLSchema",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "SwiftXMLSchema", targets: ["SwiftXMLSchema"])
    ],
    dependencies: [
        .package(url: "https://github.com/MFranceschi6/swift-xml-coder.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SwiftXMLSchema",
            dependencies: [
                .product(name: "SwiftXMLCoder", package: "swift-xml-coder")
            ]
        ),
        .testTarget(
            name: "SwiftXMLSchemaTests",
            dependencies: ["SwiftXMLSchema"]
        )
    ]
)
