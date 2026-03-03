import OpenUSD

public enum USDInteropOpenUSDShim {
    @inline(__always)
    public static func sdfCopySpec(
        from srcLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle,
        srcPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath,
        to dstLayer: pxrInternal_v0_26_3__pxrReserved__.SdfLayerHandle,
        dstPath: pxrInternal_v0_26_3__pxrReserved__.SdfPath
    ) -> Bool {
        pxrInternal_v0_26_3__pxrReserved__.SdfCopySpec(srcLayer, srcPath, dstLayer, dstPath)
    }
}
