import OpenUSD
import CxxStdlib
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

    /// Swift-facing convenience for `UsdAttribute::Get(VtValue*)` call sites.
    @inline(__always)
    public static func getAttributeValue(
        _ attr: pxrInternal_v0_26_3__pxrReserved__.UsdAttribute,
        _ value: inout pxrInternal_v0_26_3__pxrReserved__.VtValue
    ) -> Bool {
        withUnsafeMutablePointer(to: &value) { pointer in
            getAttributeValue(attr, pointer)
        }
    }

    @inline(__always)
    public static func clearAttributeConnections(
        _ attr: pxrInternal_v0_26_3__pxrReserved__.UsdAttribute
    ) -> Bool {
        USDInteropCxx.USDInterop.ClearAttributeConnections(attr)
    }

    @inline(__always)
    public static func setAttributeAssetPath(
        _ attr: pxrInternal_v0_26_3__pxrReserved__.UsdAttribute,
        assetPath: String,
        timeCode: pxrInternal_v0_26_3__pxrReserved__.UsdTimeCode
    ) -> Bool {
        USDInteropCxx.USDInterop.SetAttributeAssetPath(attr, std.string(assetPath), timeCode)
    }

    @inline(__always)
    public static func createShaderInput(
        _ shader: pxrInternal_v0_26_3__pxrReserved__.UsdShadeShader,
        name: pxrInternal_v0_26_3__pxrReserved__.TfToken,
        typeName: pxrInternal_v0_26_3__pxrReserved__.SdfValueTypeName
    ) -> pxrInternal_v0_26_3__pxrReserved__.UsdShadeInput {
        USDInteropCxx.USDInterop.CreateShaderInput(shader, name, typeName)
    }

    @inline(__always)
    public static func createShaderOutput(
        _ shader: pxrInternal_v0_26_3__pxrReserved__.UsdShadeShader,
        name: pxrInternal_v0_26_3__pxrReserved__.TfToken,
        typeName: pxrInternal_v0_26_3__pxrReserved__.SdfValueTypeName
    ) -> pxrInternal_v0_26_3__pxrReserved__.UsdShadeOutput {
        USDInteropCxx.USDInterop.CreateShaderOutput(shader, name, typeName)
    }

    @inline(__always)
    public static func createShaderIdAttr(
        _ shader: pxrInternal_v0_26_3__pxrReserved__.UsdShadeShader,
        identifier: pxrInternal_v0_26_3__pxrReserved__.TfToken
    ) -> Bool {
        USDInteropCxx.USDInterop.CreateShaderIdAttr(shader, identifier)
    }

    @inline(__always)
    public static func connectShadeInputToOutput(
        _ input: pxrInternal_v0_26_3__pxrReserved__.UsdShadeInput,
        _ output: pxrInternal_v0_26_3__pxrReserved__.UsdShadeOutput
    ) -> Bool {
        USDInteropCxx.USDInterop.ConnectShadeInputToOutput(input, output)
    }

    @inline(__always)
    public static func exportStage(
        _ stage: pxrInternal_v0_26_3__pxrReserved__.UsdStage,
        path: String,
        addSourceFileComment: Bool
    ) -> Bool {
        USDInteropCxx.USDInterop.ExportStage(stage, std.string(path), addSourceFileComment)
    }
}

public enum USDInteropAttributeReader {
    public typealias UsdAttribute = pxrInternal_v0_26_3__pxrReserved__.UsdAttribute
    public typealias VtIntArray = pxrInternal_v0_26_3__pxrReserved__.VtIntArray
    public typealias VtTokenArray = pxrInternal_v0_26_3__pxrReserved__.VtTokenArray
    public typealias VtValue = pxrInternal_v0_26_3__pxrReserved__.VtValue
    public typealias VtVec3fArray = pxrInternal_v0_26_3__pxrReserved__.VtVec3fArray

    public static func value(from attr: UsdAttribute) -> VtValue? {
        var value = VtValue()
        guard USDInteropOpenUSDShim.getAttributeValue(attr, &value) else { return nil }
        return value
    }

    public static func stringValueDescription(from attr: UsdAttribute) -> String? {
        value(from: attr).map { String(describing: $0) }
    }

    public static func cleanedStringValueDescription(from attr: UsdAttribute) -> String? {
        stringValueDescription(from: attr)?
            .replacingOccurrences(of: "VtValue(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    public static func assetPathString(from attr: UsdAttribute) -> String? {
        guard let description = stringValueDescription(from: attr) else { return nil }
        if description.hasPrefix("VtValue(@"), let atRange = description.range(of: "@") {
            let remainder = description[atRange.upperBound...]
            if let end = remainder.firstIndex(of: "@") {
                return String(remainder[..<end])
            }
        }
        if description.hasPrefix("VtValue(SdfAssetPath(") {
            return description
                .replacingOccurrences(of: "VtValue(SdfAssetPath(", with: "")
                .replacingOccurrences(of: "))", with: "")
                .replacingOccurrences(of: "\"", with: "")
        }
        return nil
    }

    public static func tokenArray(from attr: UsdAttribute) -> VtTokenArray? {
        value(from: attr).map {
            var value = $0
            return value.Get() as VtTokenArray
        }
    }

    public static func intArray(from attr: UsdAttribute) -> VtIntArray? {
        value(from: attr).map {
            var value = $0
            return value.Get() as VtIntArray
        }
    }

    public static func vec3fArray(from attr: UsdAttribute) -> VtVec3fArray? {
        value(from: attr).map {
            var value = $0
            return value.Get() as VtVec3fArray
        }
    }
}
