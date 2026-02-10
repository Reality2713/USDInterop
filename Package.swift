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
        ),
        .library(
            name: "USDInterfaces",
            targets: ["USDInterfaces"]
        ),
        .library(
            name: "USDInteropCxx",
            targets: ["USDInteropCxx"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/SwiftUsd.git", from: "5.2.0")
    ],
    targets: [
        .target(
            name: "USDInterfaces",
            swiftSettings: [
                // USDInteropAdvanced-binaries is built for distribution, so its compiled code expects
                // resilient accessors (e.g. `enum case for ...`) from USDInterfaces' public enums.
                // Enable library evolution so those symbols are emitted when USDInterfaces is built
                // from source in downstream projects (Xcode/SwiftPM).
                .unsafeFlags(["-enable-library-evolution"])
            ]
        ),
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
                "USDInterfaces",
                "USDInteropCxx"
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
