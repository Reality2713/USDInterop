// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "USDInterop",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "USDInterop",
            targets: ["USDInterop"]
        ),
        .library(
            name: "USDOperations",
            targets: ["USDOperations"]
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
        .package(url: "https://github.com/Reality2713/SwiftUsd.git", exact: "6.1.0-preflight.2")
    ],
    targets: [
        .target(
            name: "USDInterfaces",
            swiftSettings: [
                // The higher-level USD tools package is built for distribution, so its compiled code expects
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
                "USDInteropCxx",
                .product(name: "OpenUSD", package: "SwiftUsd")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .target(
            name: "USDOperations",
            dependencies: [
                "USDInterfaces",
                "USDInterop",
                "USDInteropCxx",
                .product(name: "OpenUSD", package: "SwiftUsd")
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
        .testTarget(
            name: "USDInteropTests",
            dependencies: [
                "USDInterop",
                "USDOperations"
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
