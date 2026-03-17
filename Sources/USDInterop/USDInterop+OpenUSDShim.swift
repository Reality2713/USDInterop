import OpenUSD
import USDInteropCxx

public enum USDInteropOpenUSDShim {
    @inline(__always)
    public static func dereferenceStage(
        _ stage: pxrInternal_v0_26_3__pxrReserved__.UsdStageRefPtr
    ) -> pxrInternal_v0_26_3__pxrReserved__.UsdStage {
        OpenUSD.Overlay.Dereference(stage)
    }

    @inline(__always)
    public static func dereferenceLayer(
        _ layer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle
    ) -> pxrInternal_v0_26_3__pxrReserved__.SdfLayer {
        OpenUSD.Overlay.Dereference(layer)
    }

    @inline(__always)
    public static func dereferenceLayer(
        _ layer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerRefPtr
    ) -> pxrInternal_v0_26_3__pxrReserved__.SdfLayer {
        OpenUSD.Overlay.Dereference(layer)
    }

    @inline(__always)
    public static func sdfCopySpec(
        from srcLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle,
        srcPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath,
        to dstLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle,
        dstPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath
    ) -> Bool {
        pxrInternal_v0_26_3__pxrReserved__.SdfCopySpec(srcLayer, srcPath, dstLayer, dstPath)
    }

    @inline(__always)
    public static func sdfCopySpec(
        from srcLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerRefPtr,
        srcPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath,
        to dstLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle,
        dstPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath
    ) -> Bool {
        USDInteropCxx.USDInterop.CopySpecFromLayerRefPtr(srcLayer, srcPath, dstLayer, dstPath)
    }

    /// Swift-facing shim for `UsdAttribute::Get(VtValue*)` that avoids
    /// Swift/C++ interop SIL deserialization crashes in Release/Archive builds.
    @inline(__always)
    public static func getAttributeValue(
        _ attr: pxrInternal_v0_26_3__pxrReserved__.UsdAttribute,
        _ value: UnsafeMutablePointer<pxrInternal_v0_26_3__pxrReserved__.VtValue>
    ) -> Bool {
        USDInteropCxx.USDInterop.GetAttributeValue(attr, value)
    }
}
