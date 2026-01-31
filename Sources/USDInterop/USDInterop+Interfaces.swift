import Foundation
import USDInterfaces

/// Default adapter that bridges USDInteropStage into USDInterfaces protocols.
public struct USDInteropClient: USDStageInteropProviding {
    public init() {}

    public func exportUSDA(url: URL) -> String? {
        USDInteropStage.exportUSDA(url: url)
    }

    public func sceneGraphJSON(url: URL) -> String? {
        USDInteropStage.sceneGraphJSON(url: url)
    }

    public func sceneBounds(url: URL) -> USDSceneBounds? {
        guard let bounds = USDInteropStage.sceneBounds(url: url) else {
            return nil
        }
        return USDSceneBounds(
            min: bounds.min,
            max: bounds.max,
            center: bounds.center,
            maxExtent: bounds.maxExtent
        )
    }
}
