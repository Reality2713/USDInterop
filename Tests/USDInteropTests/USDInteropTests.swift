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
