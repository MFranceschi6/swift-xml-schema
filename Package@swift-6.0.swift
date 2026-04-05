// swift-tools-version: 6.0

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
        .package(url: "https://github.com/MFranceschi6/swift-xml-coder.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
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
    ],
    swiftLanguageModes: [
        .v6
    ]
)
