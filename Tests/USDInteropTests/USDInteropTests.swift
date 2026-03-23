import Foundation
import Testing
@testable import USDInterop

@Test func builtInFileFormatsAreResolvable() {
    #expect(USDInteropPlugins.hasFileFormat("usd"))
    #expect(USDInteropPlugins.hasFileFormat("usda"))
    #expect(USDInteropPlugins.hasFileFormat("usdc"))
    #expect(USDInteropPlugins.hasFileFormat("usdz"))
}

@Test func unknownFileFormatIsNotResolvable() {
    #expect(USDInteropPlugins.hasFileFormat("definitely-not-a-format") == false)
}

@Test func pluginRegistrationForMissingPathReturnsZero() {
    let missingURL = URL(filePath: NSTemporaryDirectory())
        .appending(path: "usdinterop-missing-plugins-\(UUID().uuidString)")
    #expect(USDInteropPlugins.registerPlugins(url: missingURL) == 0)
}

@Test func packageRelativePathsUseCanonicalArUtilities() {
    let nested = "/tmp/outer.usdz[source.usdz[materials/textures/albedo.png]]"

    #expect(USDInteropPackagePaths.isPackageRelativePath(nested))

    let outer = try #require(USDInteropPackagePaths.splitOuter(nested))
    #expect(outer.packagePath == "/tmp/outer.usdz")
    #expect(outer.packagedPath == "source.usdz[materials/textures/albedo.png]")

    let inner = try #require(USDInteropPackagePaths.splitInner(nested))
    #expect(inner.packagePath == "/tmp/outer.usdz[source.usdz]")
    #expect(inner.packagedPath == "materials/textures/albedo.png")

    #expect(
        USDInteropPackagePaths.join(
            packagePath: "/tmp/outer.usdz[source.usdz]",
            packagedPath: "materials/textures/albedo.png"
        ) == nested
    )
    #expect(
        USDInteropPackagePaths.innermostPackagedPath(nested)
            == "materials/textures/albedo.png"
    )
}
