import Foundation
import CxxStdlib
@_exported import OpenUSD

public typealias UsdStage = pxrInternal_v0_25_8__pxrReserved__.UsdStage
public typealias UsdStageRefPtr = pxrInternal_v0_25_8__pxrReserved__.UsdStageRefPtr

public enum USDInteropStage {
    public static func open(
        _ path: String,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        UsdStage.Open(std.string(path), initialLoadSet)
    }

    public static func open(
        url: URL,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        open(url.path, initialLoadSet: initialLoadSet)
    }

    public static func createInMemory(
        _ identifier: String,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        UsdStage.CreateInMemory(std.string(identifier), initialLoadSet)
    }
}

public extension UsdStage {
    static func open(
        _ path: String,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        USDInteropStage.open(path, initialLoadSet: initialLoadSet)
    }

    static func open(
        url: URL,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        USDInteropStage.open(url: url, initialLoadSet: initialLoadSet)
    }

    static func createInMemory(
        _ identifier: String,
        initialLoadSet: UsdStage.InitialLoadSet = .LoadAll
    ) -> UsdStageRefPtr {
        USDInteropStage.createInMemory(identifier, initialLoadSet: initialLoadSet)
    }
}
