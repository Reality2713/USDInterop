// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "USDInterop",
    platforms: [
        .macOS(.v26)
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
            name: "USDInteropCxx",
            dependencies: [
                .product(name: "OpenUSD", package: "SwiftUsd")
            ],
            path: "Sources/USDInteropCxx",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include")
            ]
        ),
        .target(
            name: "USDInterop",
            dependencies: [
                "USDInteropCxx"
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
