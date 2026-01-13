// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "USDInterop",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "USDInterop",
            targets: ["USDInterop"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/SwiftUsd.git", from: "5.2.0")
    ],
    targets: [
        .target(
            name: "USDInterop",
            dependencies: [
                .product(name: "OpenUSD", package: "SwiftUsd")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
                .unsafeFlags(["-disable-cmo"], .when(configuration: .release))
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
