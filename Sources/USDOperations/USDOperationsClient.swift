import CxxStdlib
import Foundation
import OpenUSD
import USDInterfaces
import USDInterop
import USDInteropCxx

fileprivate typealias pxr = pxrInternal_v0_26_3__pxrReserved__
fileprivate typealias UsdStage = pxr.UsdStage
fileprivate typealias UsdPrim = pxr.UsdPrim
fileprivate typealias SdfPath = pxr.SdfPath
fileprivate typealias TfToken = pxr.TfToken
fileprivate typealias VtValue = pxr.VtValue
fileprivate typealias UsdShadeMaterialBindingAPI = pxr.UsdShadeMaterialBindingAPI
fileprivate typealias UsdShadeMaterial = pxr.UsdShadeMaterial
fileprivate typealias SdfLayerHandle = pxr.SdfLayerHandle
fileprivate typealias UsdEditTarget = pxr.UsdEditTarget
fileprivate typealias SdfReference = pxr.SdfReference
fileprivate typealias SdfLayerOffset = pxr.SdfLayerOffset
fileprivate typealias VtDictionary = pxr.VtDictionary
fileprivate typealias SdfPathVector = pxr.SdfPathVector
fileprivate typealias GfVec3d = pxr.GfVec3d
fileprivate typealias GfVec3f = pxr.GfVec3f
fileprivate typealias UsdTimeCode = pxr.UsdTimeCode
fileprivate typealias UsdGeomXformCommonAPI = pxr.UsdGeomXformCommonAPI
fileprivate typealias SdfAssetPath = pxr.SdfAssetPath

public enum USDOperationsError: Error, LocalizedError, Sendable {
    case stageOpenFailed(URL)
    case primNotFound(String)
    case rootLayerMissing(URL)
    case saveFailed(URL)
    case materialNotFound(String)
    case variantSetNotFound(String)
    case createPrimFailed(path: String, typeName: String)
    case deletePrimFailed(String)
    case transformWriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .stageOpenFailed(url):
            return "Failed to open USD stage at \(url.path)."
        case let .primNotFound(path):
            return "No prim found at path \(path)."
        case let .rootLayerMissing(url):
            return "USD stage at \(url.path) has no root layer."
        case let .saveFailed(url):
            return "Failed to save USD stage at \(url.path)."
        case let .materialNotFound(path):
            return "Material not found at \(path)."
        case let .variantSetNotFound(name):
            return "Variant set not found: \(name)."
        case let .createPrimFailed(path, typeName):
            return "Failed to create prim at \(path) with type \(typeName)."
        case let .deletePrimFailed(path):
            return "Failed to delete prim at \(path)."
        case let .transformWriteFailed(path):
            return "Failed to author transform on \(path)."
        }
    }
}

public struct USDOperationsClient: Sendable {
    private let interopClient = USDInteropClient()

    public init() {}

    public func exportUSDA(url: URL) -> String? {
        interopClient.exportUSDA(url: url)
    }

    public func sceneGraphJSON(url: URL) -> String? {
        interopClient.sceneGraphJSON(url: url)
    }

    public func sceneBounds(url: URL) -> USDSceneBounds? {
        interopClient.sceneBounds(url: url)
    }

    public func stageMetadata(url: URL) -> USDStageMetadata {
        guard let stage = try? openStage(url, loadAll: true) else {
            return USDStageMetadata()
        }

        var metadata = USDStageMetadata()

        var upAxisValue = VtValue()
        if stage.GetMetadata(TfToken("upAxis"), &upAxisValue),
           let normalized = normalizeAxis(String(describing: upAxisValue))
        {
            metadata.upAxis = normalized
        }

        var metersPerUnitValue = VtValue()
        if stage.GetMetadata(TfToken("metersPerUnit"), &metersPerUnitValue) {
            metadata.metersPerUnit = Double(String(describing: metersPerUnitValue))
        }

        let defaultPrim = stage.GetDefaultPrim()
        if defaultPrim.IsValid() {
            let name = String(defaultPrim.GetName().GetString())
            if !name.isEmpty {
                metadata.defaultPrimName = name
            }
        }

        var autoPlayValue = VtValue()
        if stage.GetMetadata(TfToken("autoPlay"), &autoPlayValue) {
            metadata.autoPlay = String(describing: autoPlayValue).lowercased().contains("true")
        }

        var playbackModeValue = VtValue()
        if stage.GetMetadata(TfToken("playbackMode"), &playbackModeValue) {
            metadata.playbackMode = String(describing: playbackModeValue)
        }

        metadata.timeCodesPerSecond = stage.GetTimeCodesPerSecond()
        metadata.startTimeCode = stage.GetStartTimeCode()
        metadata.endTimeCode = stage.GetEndTimeCode()

        var animationTracks: [String] = []
        var availableCameras: [String] = []
        for prim in stage.Traverse() {
            let typeName = String(prim.GetTypeName().GetString())
            if typeName == "SkelAnimation" || typeName == "Animation" || typeName == "RealityKitTimeline" {
                animationTracks.append(String(prim.GetPath().GetString()))
            }
            if typeName == "Camera" {
                availableCameras.append(String(prim.GetPath().GetString()))
            }
        }
        metadata.animationTracks = animationTracks
        metadata.availableCameras = availableCameras
        return metadata
    }

    public func primAttributes(url: URL, path: String) -> USDPrimAttributes? {
        guard let stage = try? openStage(url, loadAll: true) else { return nil }
        let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))
        guard prim.IsValid() else { return nil }

        let primPath = String(prim.GetPath().GetAsString())
        let primName = String(prim.GetName().GetString())
        let typeName = String(prim.GetTypeName().GetString())
        let isActive = prim.IsActive()

        var visibility = "inherited"
        let visibilityAttr = prim.GetAttribute(TfToken("visibility"))
        if visibilityAttr.IsValid() {
            var value = VtValue()
            if USDInteropOpenUSDShim.getAttributeValue(visibilityAttr, &value) {
                let raw = String(describing: value)
                if raw.contains("invisible") {
                    visibility = "invisible"
                } else {
                    visibility = "inherited"
                }
            }
        }

        var purpose = "default"
        let purposeAttr = prim.GetAttribute(TfToken("purpose"))
        if purposeAttr.IsValid() {
            var value = VtValue()
            if USDInteropOpenUSDShim.getAttributeValue(purposeAttr, &value) {
                purpose = String(describing: value)
            }
        }

        var kind = ""
        if prim.HasMetadata(TfToken("kind")) {
            var kindValue = VtValue()
            if prim.GetMetadata(TfToken("kind"), &kindValue) {
                kind = String(describing: kindValue)
            }
        }

        var authoredAttributes: [USDPrimAttributes.AuthoredAttribute] = []
        for attr in prim.GetAttributes() {
            guard attr.IsAuthored() else { continue }
            let name = String(attr.GetName().GetString())
            var value = VtValue()
            let rendered: String
            if USDInteropOpenUSDShim.getAttributeValue(attr, &value) {
                rendered = String(describing: value)
            } else {
                rendered = "(authored)"
            }
            authoredAttributes.append(.init(name: name, value: rendered))
        }

        authoredAttributes.sort { lhs, rhs in lhs.name < rhs.name }

        return USDPrimAttributes(
            primPath: primPath,
            primName: primName,
            typeName: typeName,
            isActive: isActive,
            visibility: visibility,
            purpose: purpose,
            kind: kind,
            authoredAttributes: authoredAttributes
        )
    }

    public func primTransform(url: URL, path: String) -> USDTransformData? {
        guard let stage = try? openStage(url, loadAll: true) else { return nil }
        let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))
        guard prim.IsValid() else { return nil }
        return extractTransform(from: prim)
    }

    public func primReferences(url: URL, path: String) -> [USDReference] {
        guard let stage = try? openStage(url, loadAll: true) else { return [] }
        let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))
        guard prim.IsValid(), prim.HasAuthoredReferences() else { return [] }

        var refsValue = VtValue()
        guard prim.GetMetadata(TfToken("references"), &refsValue) else { return [] }
        return parseReferencesFromMetadata(String(describing: refsValue))
    }

    public func listVariantSets(url: URL, scope: USDVariantScope) throws -> [USDVariantSetDescriptor] {
        let stage = try openStage(url)
        let prim = try prim(for: scope, stage: stage)
        var descriptors: [USDVariantSetDescriptor] = []
        var variantSets = prim.GetVariantSets()
        let names = variantSets.GetNames()

        for i in 0..<names.size() {
            let setName = String(names[i])
            var variantSet = variantSets.GetVariantSet(std.string(setName))
            guard variantSet.IsValid() else { continue }

            let selection = String(variantSet.GetVariantSelection())
            let selectedOptionId = selection.isEmpty ? nil : selection
            let options = variantSet.GetVariantNames()
                .map { USDVariantOption(id: String($0)) }
                .sorted { $0.id < $1.id }

            descriptors.append(
                USDVariantSetDescriptor(
                    scope: scope,
                    name: setName,
                    options: options,
                    selectedOptionId: selectedOptionId,
                    defaultOptionId: nil
                )
            )
        }

        return descriptors.sorted { $0.name < $1.name }
    }

    public func allMaterials(url: URL) -> [USDMaterialInfo] {
        guard let stage = try? openStage(url, loadAll: true) else { return [] }
        var materials: [USDMaterialInfo] = []
        for prim in stage.Traverse() {
            let typeName = String(prim.GetTypeName().GetString())
            guard typeName == "Material" else { continue }
            materials.append(
                USDMaterialInfo(
                    path: String(prim.GetPath().GetAsString()),
                    name: String(prim.GetName().GetString()),
                    materialType: .unknown,
                    properties: []
                )
            )
        }
        return materials.sorted { $0.path < $1.path }
    }

    public func materialBinding(url: URL, path: String) -> String? {
        materialBindingDetails(url: url, path: path).effectiveMaterialPath
    }

    public func materialBindingStrength(url: URL, path: String) -> USDMaterialBindingStrength? {
        materialBindingDetails(url: url, path: path).bindingStrength
    }

    public func createPrim(url: URL, parentPath: String, name: String, typeName: String) throws -> String {
        let stage = try openStage(url)
        let fullPath: String = parentPath == "/" ? "/\(name)" : "\(parentPath)/\(name)"
        let sdfPath = SdfPath(std.string(fullPath))
        let typeToken = TfToken(std.string(typeName))
        let prim = stage.DefinePrim(sdfPath, typeToken)
        guard prim.IsValid() else {
            throw USDOperationsError.createPrimFailed(path: fullPath, typeName: typeName)
        }
        try saveRootLayer(stage: stage, url: url)
        return fullPath
    }

    public func existingPrimNames(url: URL, parentPath: String) throws -> [String] {
        let stage = try openStage(url)
        let parent: UsdPrim
        if parentPath == "/" {
            parent = stage.GetPseudoRoot()
        } else {
            parent = try primAtPath(parentPath, stage: stage)
        }
        return parent.GetChildren().map { String($0.GetName().GetString()) }.sorted()
    }

    public func setPrimTransform(url: URL, path: String, transform: USDTransformData) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(path, stage: stage)
        let xformCommon = UsdGeomXformCommonAPI(prim)

        let didTranslate = xformCommon.SetTranslate(
            GfVec3d(transform.position.x, transform.position.y, transform.position.z),
            UsdTimeCode.Default()
        )
        let didRotate = xformCommon.SetRotate(
            GfVec3f(
                Float(transform.rotationDegrees.x),
                Float(transform.rotationDegrees.y),
                Float(transform.rotationDegrees.z)
            ),
            UsdGeomXformCommonAPI.RotationOrderXYZ,
            UsdTimeCode.Default()
        )
        let didScale = xformCommon.SetScale(
            GfVec3f(
                Float(transform.scale.x),
                Float(transform.scale.y),
                Float(transform.scale.z)
            ),
            UsdTimeCode.Default()
        )

        guard didTranslate, didRotate, didScale else {
            throw USDOperationsError.transformWriteFailed(path)
        }
        try saveRootLayer(stage: stage, url: url)
    }

    public func addReference(
        url: URL,
        primPath: String,
        reference: USDReference,
        editTarget: USDLayerEditTarget = .rootLayer
    ) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        let target = makeEditTarget(stage: stage, mode: editTarget)

        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            var refs = prim.GetReferences()
            let primPathValue = if let path = reference.primPath, !path.isEmpty {
                SdfPath(std.string(path))
            } else {
                SdfPath()
            }
            let ref = SdfReference(
                std.string(reference.assetPath),
                primPathValue,
                SdfLayerOffset(0.0, 1.0),
                VtDictionary()
            )
            _ = refs.AddReference(ref, pxr.UsdListPosition.UsdListPositionBackOfPrependList)
        }

        try saveEditedLayer(stage: stage, url: url, editTarget: editTarget)
    }

    public func removeReference(
        url: URL,
        primPath: String,
        reference: USDReference,
        editTarget: USDLayerEditTarget = .rootLayer
    ) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        let target = makeEditTarget(stage: stage, mode: editTarget)

        var refsValue = VtValue()
        let existing: [USDReference]
        if prim.GetMetadata(TfToken("references"), &refsValue) {
            existing = parseReferencesFromMetadata(String(describing: refsValue))
        } else {
            existing = []
        }

        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            var refs = prim.GetReferences()
            _ = refs.ClearReferences()
            for item in existing where !isSameReference(item, reference) {
                let primPathValue = if let path = item.primPath, !path.isEmpty {
                    SdfPath(std.string(path))
                } else {
                    SdfPath()
                }
                let ref = SdfReference(
                    std.string(item.assetPath),
                    primPathValue,
                    SdfLayerOffset(0.0, 1.0),
                    VtDictionary()
                )
                _ = refs.AddReference(ref, pxr.UsdListPosition.UsdListPositionBackOfPrependList)
            }
        }

        try saveEditedLayer(stage: stage, url: url, editTarget: editTarget)
    }

    public func setMaterialBinding(
        url: URL,
        primPath: String,
        materialPath: String,
        editTarget: USDLayerEditTarget = .rootLayer
    ) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        let materialPrim = stage.GetPrimAtPath(SdfPath(std.string(materialPath)))
        guard materialPrim.IsValid() else {
            throw USDOperationsError.materialNotFound(materialPath)
        }

        let target = makeEditTarget(stage: stage, mode: editTarget)
        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            let bindingAPI = UsdShadeMaterialBindingAPI.Apply(prim)
            let material = UsdShadeMaterial(materialPrim)
            let strengthToken = TfToken(std.string(USDMaterialBindingStrength.fallbackStrength.rawValue))
            let purposeToken = TfToken(std.string("allPurpose"))
            bindingAPI.Bind(material, strengthToken, purposeToken)
        }

        try saveEditedLayer(stage: stage, url: url, editTarget: editTarget)
    }

    public func clearMaterialBinding(
        url: URL,
        primPath: String,
        editTarget: USDLayerEditTarget = .rootLayer
    ) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        let target = makeEditTarget(stage: stage, mode: editTarget)
        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            let bindingAPI = UsdShadeMaterialBindingAPI.Apply(prim)
            bindingAPI.UnbindAllBindings()
        }
        try saveEditedLayer(stage: stage, url: url, editTarget: editTarget)
    }

    public func setMaterialBindingStrength(
        url: URL,
        primPath: String,
        strength: USDMaterialBindingStrength,
        editTarget: USDLayerEditTarget = .rootLayer
    ) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        let target = makeEditTarget(stage: stage, mode: editTarget)

        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            let bindingAPI = UsdShadeMaterialBindingAPI.Apply(prim)
            let purposeToken = TfToken(std.string("allPurpose"))
            let rel = bindingAPI.GetDirectBindingRel(purposeToken)
            guard rel.IsValid() else { return }
            let token = TfToken(std.string(strength.rawValue))
            _ = UsdShadeMaterialBindingAPI.SetMaterialBindingStrength(rel, token)
        }

        try saveEditedLayer(stage: stage, url: url, editTarget: editTarget)
    }

    public func setDefaultPrim(url: URL, primPath: String) throws {
        let stage = try openStage(url)
        let prim = try primAtPath(primPath, stage: stage)
        stage.SetDefaultPrim(prim)
        try saveRootLayer(stage: stage, url: url)
    }

    public func setMetersPerUnit(url: URL, value: Double) throws {
        let stage = try openStage(url)
        stage.SetMetadata(TfToken("metersPerUnit"), VtValue(Double(value)))
        try saveRootLayer(stage: stage, url: url)
    }

    public func setUpAxis(url: URL, axis: String) throws {
        let stage = try openStage(url)
        stage.SetMetadata(TfToken("upAxis"), VtValue(TfToken(std.string(axis))))
        try saveRootLayer(stage: stage, url: url)
    }

    public func deletePrim(url: URL, primPath: String) throws {
        let stage = try openStage(url)
        let removed = stage.RemovePrim(SdfPath(std.string(primPath)))
        guard removed else {
            throw USDOperationsError.deletePrimFailed(primPath)
        }
        try saveRootLayer(stage: stage, url: url)
    }

    public func applyVariantSelection(
        url: URL,
        request: USDVariantSelectionRequest,
        editTarget: USDVariantEditTarget = .rootLayer,
        persist: Bool = true
    ) throws {
        let stage = try openStage(url)
        let prim = try prim(for: request.scope, stage: stage)
        var variantSets = prim.GetVariantSets()
        var variantSet = variantSets.GetVariantSet(std.string(request.setName))
        guard variantSet.IsValid() else {
            throw USDOperationsError.variantSetNotFound(request.setName)
        }

        let target = makeEditTarget(stage: stage, mode: editTarget)
        OpenUSD.Overlay.withUsdEditContext(stage, target) {
            if let selectionId = request.selectionId, !selectionId.isEmpty {
                variantSet.SetVariantSelection(std.string(selectionId))
            } else {
                variantSet.ClearVariantSelection()
            }
        }

        if persist {
            try saveRootLayer(stage: stage, url: url)
        }
    }

    public func materialBindingDetails(url: URL, path: String) -> USDMaterialBindingDetails {
        guard let stage = try? openStage(url, loadAll: true) else {
            return USDMaterialBindingDetails(selectedPrimPath: path)
        }
        let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))
        guard prim.IsValid() else {
            return USDMaterialBindingDetails(selectedPrimPath: path)
        }

        let primTypeName = String(prim.GetTypeName().GetString())
        if primTypeName == "Material" {
            return USDMaterialBindingDetails(
                selectedPrimPath: path,
                effectiveMaterialPath: path,
                authoredMaterialPath: path,
                bindingSourcePrimPath: path
            )
        }

        let effectiveMaterialPath: String? = {
            let bindingAPI = UsdShadeMaterialBindingAPI(prim)
            let material = bindingAPI.ComputeBoundMaterial()
            if material.GetPrim().IsValid() {
                return String(material.GetPath().GetAsString())
            }

            let directRel = prim.GetRelationship(TfToken("material:binding"))
            if directRel.IsValid(), let target = firstBindingTarget(from: directRel) {
                return target
            }

            return nil
        }()

        var authoredMaterialPath: String?
        var bindingSourcePrimPath: String?
        var bindingStrength: USDMaterialBindingStrength?
        var currentPrim = prim
        let selectedPrimPath = prim.GetPath()
        let purposeToken = TfToken(std.string("allPurpose"))

        while currentPrim.IsValid() {
            let direct = directBindingDetails(for: currentPrim, purposeToken: purposeToken)
            if let targetPath = direct.targetPath {
                let inherited = currentPrim.GetPath() != selectedPrimPath
                authoredMaterialPath = targetPath
                bindingSourcePrimPath = String(currentPrim.GetPath().GetAsString())
                bindingStrength = direct.strength
                if inherited, bindingStrength == .fallbackStrength {
                    bindingStrength = .weakerThanDescendants
                }
                break
            }
            currentPrim = currentPrim.GetParent()
        }

        return USDMaterialBindingDetails(
            selectedPrimPath: path,
            effectiveMaterialPath: effectiveMaterialPath,
            authoredMaterialPath: authoredMaterialPath,
            bindingSourcePrimPath: bindingSourcePrimPath,
            bindingStrength: bindingStrength
        )
    }
}

private extension USDOperationsClient {
    func openStage(_ url: URL, loadAll: Bool = true) throws -> UsdStage {
        let loadSet: pxr.UsdStage.InitialLoadSet = loadAll ? .LoadAll : .LoadNone
        let stageRef = pxr.UsdStage.Open(std.string(url.path), loadSet)
        guard stageRef._isNonnull() else {
            throw USDOperationsError.stageOpenFailed(url)
        }
        return OpenUSD.Overlay.Dereference(stageRef)
    }

    func primAtPath(_ path: String, stage: UsdStage) throws -> UsdPrim {
        let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))
        guard prim.IsValid() else {
            throw USDOperationsError.primNotFound(path)
        }
        return prim
    }

    func saveRootLayer(stage: UsdStage, url: URL) throws {
        let rootLayerHandle = stage.GetRootLayer()
        guard Bool(rootLayerHandle) else {
            throw USDOperationsError.rootLayerMissing(url)
        }
        let rootLayer = USDInteropOpenUSDShim.dereferenceLayer(rootLayerHandle)
        guard rootLayer.Save(false) else {
            throw USDOperationsError.saveFailed(url)
        }
    }

    func prim(for scope: USDVariantScope, stage: UsdStage) throws -> UsdPrim {
        switch scope {
        case .catalog:
            throw USDOperationsError.primNotFound("catalog")
        case .prim(let path):
            return try primAtPath(path, stage: stage)
        }
    }
}

private func makeEditTarget(stage: UsdStage, mode: USDVariantEditTarget) -> UsdEditTarget {
    switch mode {
    case .sessionLayer:
        let sessionLayer = stage.GetSessionLayer()
        if Bool(sessionLayer) {
            return stage.GetEditTargetForLocalLayer(sessionLayer)
        }
        return stage.GetEditTargetForLocalLayer(stage.GetRootLayer())
    case .rootLayer:
        return stage.GetEditTargetForLocalLayer(stage.GetRootLayer())
    }
}

private func makeEditTarget(stage: UsdStage, mode: USDLayerEditTarget) -> UsdEditTarget {
    switch mode {
    case .sessionLayer:
        let sessionLayer = stage.GetSessionLayer()
        if Bool(sessionLayer) {
            return stage.GetEditTargetForLocalLayer(sessionLayer)
        }
        return stage.GetEditTargetForLocalLayer(stage.GetRootLayer())
    case .rootLayer:
        return stage.GetEditTargetForLocalLayer(stage.GetRootLayer())
    }
}

private func saveEditedLayer(stage: UsdStage, url: URL, editTarget: USDLayerEditTarget) throws {
    switch editTarget {
    case .rootLayer:
        try USDOperationsClient().saveRootLayer(stage: stage, url: url)
    case .sessionLayer:
        break
    }
}

private func normalizeAxis(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if trimmed == "Y" || trimmed.contains("\"Y\"") || trimmed.contains("Y") {
        return "Y"
    }
    if trimmed == "Z" || trimmed.contains("\"Z\"") || trimmed.contains("Z") {
        return "Z"
    }
    return nil
}

private func parseReferencesFromMetadata(_ raw: String) -> [USDReference] {
    var items: [USDReference] = []
    var index = raw.startIndex

    while let atStart = raw[index...].firstIndex(of: "@") {
        let assetStart = raw.index(after: atStart)
        guard let atEnd = raw[assetStart...].firstIndex(of: "@") else { break }
        let assetPath = String(raw[assetStart..<atEnd])

        var next = raw.index(after: atEnd)
        while next < raw.endIndex, raw[next].isWhitespace {
            next = raw.index(after: next)
        }

        var primPath: String?
        if next < raw.endIndex, raw[next] == "<" {
            let primStart = raw.index(after: next)
            if let primEnd = raw[primStart...].firstIndex(of: ">") {
                let parsed = String(raw[primStart..<primEnd])
                primPath = parsed.isEmpty ? nil : parsed
                next = raw.index(after: primEnd)
            }
        }

        if !assetPath.isEmpty {
            items.append(.init(assetPath: assetPath, primPath: primPath))
        }
        index = next
    }

    var seen = Set<String>()
    return items.filter { reference in
        let key = "\(reference.assetPath)|\(reference.primPath ?? "")"
        return seen.insert(key).inserted
    }
}

private func isSameReference(_ lhs: USDReference, _ rhs: USDReference) -> Bool {
    lhs.assetPath == rhs.assetPath && (lhs.primPath ?? "") == (rhs.primPath ?? "")
}

private func extractTransform(from prim: UsdPrim) -> USDTransformData? {
    let typeName = String(prim.GetTypeName().GetString())
    let lowercased = typeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let nonXformable: Set<String> = [
        "",
        "animation",
        "geomsubset",
        "material",
        "nodegraph",
        "scope",
        "shader",
        "skelanimation",
    ]
    if nonXformable.contains(lowercased) {
        return nil
    }

    var position = SIMD3<Double>.zero
    var rotation = SIMD3<Double>.zero
    var scale = SIMD3<Double>(repeating: 1)

    for attr in prim.GetAttributes() {
        let name = String(attr.GetName().GetString())
        var value = VtValue()
        guard USDInteropOpenUSDShim.getAttributeValue(attr, &value) else { continue }
        let raw = String(describing: value)

        switch name {
        case "xformOp:translate":
            if let vector = parseVector3(raw) {
                position = vector
            }
        case "xformOp:rotateXYZ":
            if let vector = parseVector3(raw) {
                rotation = vector
            }
        case "xformOp:rotateX":
            if let scalar = parseScalar(raw) {
                rotation.x = scalar
            }
        case "xformOp:rotateY":
            if let scalar = parseScalar(raw) {
                rotation.y = scalar
            }
        case "xformOp:rotateZ":
            if let scalar = parseScalar(raw) {
                rotation.z = scalar
            }
        case "xformOp:scale":
            if let vector = parseVector3(raw) {
                scale = vector
            }
        default:
            break
        }
    }

    return USDTransformData(position: position, rotationDegrees: rotation, scale: scale)
}

private func parseVector3(_ raw: String) -> SIMD3<Double>? {
    let sanitized = raw
        .replacingOccurrences(of: "GfVec3d", with: "")
        .replacingOccurrences(of: "GfVec3f", with: "")
        .replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .replacingOccurrences(of: "[", with: "")
        .replacingOccurrences(of: "]", with: "")
        .replacingOccurrences(of: " ", with: "")
    let components = sanitized.split(separator: ",").compactMap { Double($0) }
    guard components.count >= 3 else { return nil }
    return SIMD3<Double>(components[0], components[1], components[2])
}

private func parseScalar(_ raw: String) -> Double? {
    Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func firstBindingTarget(from relationship: pxr.UsdRelationship) -> String? {
    var targets = SdfPathVector()
    relationship.GetTargets(&targets)
    guard !targets.empty() else { return nil }
    return String(targets[0].GetAsString())
}

private func directBindingDetails(
    for prim: UsdPrim,
    purposeToken: TfToken
) -> (targetPath: String?, strength: USDMaterialBindingStrength?) {
    let bindingAPI = UsdShadeMaterialBindingAPI(prim)
    let rel = bindingAPI.GetDirectBindingRel(purposeToken)
    if rel.IsValid(), let directTarget = firstBindingTarget(from: rel) {
        let token = UsdShadeMaterialBindingAPI.GetMaterialBindingStrength(rel)
        let raw = String(token.GetString())
        let strength = USDMaterialBindingStrength(rawValue: raw) ?? .fallbackStrength
        return (directTarget, strength)
    }

    let fallbackRel = prim.GetRelationship(TfToken("material:binding"))
    if fallbackRel.IsValid(), let directTarget = firstBindingTarget(from: fallbackRel) {
        return (directTarget, .fallbackStrength)
    }

    return (nil, nil)
}
