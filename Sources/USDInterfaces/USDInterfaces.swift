import Foundation
import simd

/// Pure-Swift DTOs and protocols for USD operations.
/// Shared libraries should depend on this module, not on OpenUSD.

public struct USDSceneBounds: Sendable, Hashable {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>
    public var center: SIMD3<Float>
    public var maxExtent: Float

    public init(
        min: SIMD3<Float>,
        max: SIMD3<Float>,
        center: SIMD3<Float>,
        maxExtent: Float
    ) {
        self.min = min
        self.max = max
        self.center = center
        self.maxExtent = maxExtent
    }
}

public protocol USDAExporting: Sendable {
    func exportUSDA(url: URL) -> String?
}

public protocol USDSceneGraphProviding: Sendable {
    func sceneGraphJSON(url: URL) -> String?
}

public protocol USDSceneBoundsProviding: Sendable {
    func sceneBounds(url: URL) -> USDSceneBounds?
}

public typealias USDStageInteropProviding =
    USDAExporting & USDSceneGraphProviding & USDSceneBoundsProviding

public struct USDPrimSummary: Sendable, Hashable {
    public var path: String
    public var typeName: String

    public init(path: String, typeName: String) {
        self.path = path
        self.typeName = typeName
    }
}

public enum USDVariantScope: Hashable, Sendable {
    case catalog
    case prim(path: String)

    public var keyPrefix: String {
        switch self {
        case .catalog:
            return "catalog"
        case .prim(let path):
            return path
        }
    }
}

public struct USDVariantOption: Hashable, Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName ?? id
    }
}

public struct USDVariantSetDescriptor: Hashable, Sendable {
    public let scope: USDVariantScope
    public let name: String
    public let options: [USDVariantOption]
    public let selectedOptionId: String?
    public let defaultOptionId: String?

    public init(
        scope: USDVariantScope,
        name: String,
        options: [USDVariantOption],
        selectedOptionId: String? = nil,
        defaultOptionId: String? = nil
    ) {
        self.scope = scope
        self.name = name
        self.options = options
        self.selectedOptionId = selectedOptionId
        self.defaultOptionId = defaultOptionId
    }

    public var key: String {
        "\(scope.keyPrefix):\(name)"
    }
}

public struct USDVariantSelectionRequest: Hashable, Sendable {
    public let scope: USDVariantScope
    public let setName: String
    public let selectionId: String?

    public init(scope: USDVariantScope, setName: String, selectionId: String?) {
        self.scope = scope
        self.setName = setName
        self.selectionId = selectionId
    }
}

public enum USDVariantEditTarget: Sendable {
    case sessionLayer
    case rootLayer
}

/// Generic edit target for authoring opinions into a USD stage.
///
/// This is intentionally not variant-specific even though `USDVariantEditTarget` exists,
/// because multiple editing domains (transforms, bindings, schemas) need the same concept.
public enum USDLayerEditTarget: Sendable, Equatable {
    case sessionLayer
    case rootLayer
}

public extension USDLayerEditTarget {
    init(_ target: USDVariantEditTarget) {
        switch target {
        case .sessionLayer: self = .sessionLayer
        case .rootLayer: self = .rootLayer
        }
    }
}

public struct USDSchemaSpec: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case api
        case multipleApplyAPI(instanceName: String)
        case typed
    }

    public var identifier: String
    public var kind: Kind

    public init(identifier: String, kind: Kind = .api) {
        self.identifier = identifier
        self.kind = kind
    }
}

public protocol USDPrimListing: Sendable {
    func listPrimSummaries(url: URL) throws -> [USDPrimSummary]
}

public protocol USDDefaultPrimEditing: Sendable {
    func defaultPrimPath(url: URL) throws -> String?
    func setDefaultPrim(url: URL, primPath: String) throws
}

public protocol USDPrimTransformEditing: Sendable {
    func setPrimTransform(url: URL, path: String, transform: USDTransformData) throws
}

public protocol USDMaterialBindingEditing: Sendable {
    /// Authors a material binding relationship onto `primPath`.
    ///
    /// - Important: This must be implemented by `USDInteropAdvanced` (or higher), not in app code.
    func setMaterialBinding(
        url: URL,
        primPath: String,
        materialPath: String,
        editTarget: USDLayerEditTarget
    ) throws

    /// Removes authored material bindings on `primPath`.
    func clearMaterialBinding(
        url: URL,
        primPath: String,
        editTarget: USDLayerEditTarget
    ) throws
}

public protocol USDSchemaApplying: Sendable {
    func applySchema(url: URL, primPath: String, schema: USDSchemaSpec) throws
}

public protocol USDVariantEditing: Sendable {
    func listVariantSets(url: URL, scope: USDVariantScope) throws -> [USDVariantSetDescriptor]
    func applyVariantSelection(
        url: URL,
        request: USDVariantSelectionRequest,
        editTarget: USDVariantEditTarget,
        persist: Bool
    ) throws
}

public struct USDVariantSource: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public let variantName: String

    public init(id: UUID = UUID(), fileURL: URL, variantName: String) {
        self.id = id
        self.fileURL = fileURL
        self.variantName = variantName
    }
}

public enum USDTimecodeMode: String, Codable, Hashable, Sendable {
    case useSource
    case startAtZero
    case startAtCustom
}

public struct USDVariantCombineConfig: Sendable {
    public let baseSource: USDVariantSource
    public let variantSources: [USDVariantSource]
    public let materialVariantSetName: String
    public let animationVariantSetName: String
    public let timecodeMode: USDTimecodeMode
    public let customStartTimecode: Double?

    public init(
        baseSource: USDVariantSource,
        variantSources: [USDVariantSource],
        materialVariantSetName: String = "materialVariant",
        animationVariantSetName: String = "animationVariant",
        timecodeMode: USDTimecodeMode = .useSource,
        customStartTimecode: Double? = nil
    ) {
        self.baseSource = baseSource
        self.variantSources = variantSources
        self.materialVariantSetName = materialVariantSetName
        self.animationVariantSetName = animationVariantSetName
        self.timecodeMode = timecodeMode
        self.customStartTimecode = customStartTimecode
    }
}

public struct USDVariantCombineResult: Sendable {
    public let outputURL: URL
    public let variantSets: [USDVariantSetDescriptor]
    public let resourcesCopied: [URL]
    public let startTimecode: Double?
    public let endTimecode: Double?

    public init(
        outputURL: URL,
        variantSets: [USDVariantSetDescriptor],
        resourcesCopied: [URL],
        startTimecode: Double? = nil,
        endTimecode: Double? = nil
    ) {
        self.outputURL = outputURL
        self.variantSets = variantSets
        self.resourcesCopied = resourcesCopied
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
    }
}

public protocol USDVariantCombining: Sendable {
    func combineVariants(config: USDVariantCombineConfig, outputURL: URL) async throws -> USDVariantCombineResult
}

public typealias USDAdvancedInteropProviding =
    USDPrimListing
    & USDDefaultPrimEditing
    & USDPrimTransformEditing
    & USDSchemaApplying
    & USDVariantEditing
    & USDVariantCombining

// MARK: - Inspection & Validation (Swift-only DTOs)

public struct USDStageMetadata: Equatable, Sendable {
    public var upAxis: String?
    public var metersPerUnit: Double?
    public var defaultPrimName: String?
    public var autoPlay: Bool?
    public var playbackMode: String?
    public var timeCodesPerSecond: Double?
    public var startTimeCode: Double?
    public var endTimeCode: Double?
    public var animationTracks: [String]
    public var availableCameras: [String]

    public init(
        upAxis: String? = nil,
        metersPerUnit: Double? = nil,
        defaultPrimName: String? = nil,
        autoPlay: Bool? = nil,
        playbackMode: String? = nil,
        timeCodesPerSecond: Double? = nil,
        startTimeCode: Double? = nil,
        endTimeCode: Double? = nil,
        animationTracks: [String] = [],
        availableCameras: [String] = []
    ) {
        self.upAxis = upAxis
        self.metersPerUnit = metersPerUnit
        self.defaultPrimName = defaultPrimName
        self.autoPlay = autoPlay
        self.playbackMode = playbackMode
        self.timeCodesPerSecond = timeCodesPerSecond
        self.startTimeCode = startTimeCode
        self.endTimeCode = endTimeCode
        self.animationTracks = animationTracks
        self.availableCameras = availableCameras
    }
}


public struct USDTransformData: Equatable, Sendable {
    public var position: SIMD3<Double>
    public var rotationDegrees: SIMD3<Double>
    public var scale: SIMD3<Double>

    public init(
        position: SIMD3<Double> = .zero,
        rotationDegrees: SIMD3<Double> = .zero,
        scale: SIMD3<Double> = SIMD3<Double>(repeating: 1)
    ) {
        self.position = position
        self.rotationDegrees = rotationDegrees
        self.scale = scale
    }
}

public struct USDPrimTreeNode: Equatable, Sendable {
    public var primPath: String
    public var primName: String
    public var typeName: String
    public var purpose: String
    public var children: [USDPrimTreeNode]

    public init(
        primPath: String,
        primName: String,
        typeName: String,
        purpose: String = "default",
        children: [USDPrimTreeNode] = []
    ) {
        self.primPath = primPath
        self.primName = primName
        self.typeName = typeName
        self.purpose = purpose
        self.children = children
    }
}

public struct USDGeometryStatistics: Equatable, Sendable {
    public var totalTriangles: Int
    public var totalVertices: Int
    public var meshCount: Int
    public var materialCount: Int
    public var textureCount: Int

    public init(
        totalTriangles: Int = 0,
        totalVertices: Int = 0,
        meshCount: Int = 0,
        materialCount: Int = 0,
        textureCount: Int = 0
    ) {
        self.totalTriangles = totalTriangles
        self.totalVertices = totalVertices
        self.meshCount = meshCount
        self.materialCount = materialCount
        self.textureCount = textureCount
    }
}

public enum USDAnimatableStatus: String, Equatable, Sendable {
    case animatable
    case static_
    case unknown
}

public struct USDBlendShapeInfo: Equatable, Sendable {
    public var path: String
    public var name: String
    public var weightCount: Int
    public var weightNames: [String]

    public init(path: String, name: String, weightCount: Int, weightNames: [String]) {
        self.path = path
        self.name = name
        self.weightCount = weightCount
        self.weightNames = weightNames
    }
}

public struct USDModelInfo: Equatable, Sendable {
    public var boundsExtent: SIMD3<Float>
    public var boundsCenter: SIMD3<Float>
    public var scale: SIMD3<Float>
    public var upAxis: String
    public var animationCount: Int
    public var animationNames: [String]
    public var metersPerUnit: Double
    public var autoPlay: Bool?
    public var playbackMode: String?
    public var animatableStatus: USDAnimatableStatus
    public var hasAnimationLibrary: Bool
    public var skeletonJointCount: Int
    public var maxJointInfluences: Int
    public var hasSkinnedMesh: Bool
    public var blendShapes: [USDBlendShapeInfo]

    public init(
        boundsExtent: SIMD3<Float> = .zero,
        boundsCenter: SIMD3<Float> = .zero,
        scale: SIMD3<Float> = .one,
        upAxis: String = "Unknown",
        animationCount: Int = 0,
        animationNames: [String] = [],
        metersPerUnit: Double = 1.0,
        autoPlay: Bool? = nil,
        playbackMode: String? = nil,
        animatableStatus: USDAnimatableStatus = .unknown,
        hasAnimationLibrary: Bool = false,
        skeletonJointCount: Int = 0,
        maxJointInfluences: Int = 0,
        hasSkinnedMesh: Bool = false,
        blendShapes: [USDBlendShapeInfo] = []
    ) {
        self.boundsExtent = boundsExtent
        self.boundsCenter = boundsCenter
        self.scale = scale
        self.upAxis = upAxis
        self.animationCount = animationCount
        self.animationNames = animationNames
        self.metersPerUnit = metersPerUnit
        self.autoPlay = autoPlay
        self.playbackMode = playbackMode
        self.animatableStatus = animatableStatus
        self.hasAnimationLibrary = hasAnimationLibrary
        self.skeletonJointCount = skeletonJointCount
        self.maxJointInfluences = maxJointInfluences
        self.hasSkinnedMesh = hasSkinnedMesh
        self.blendShapes = blendShapes
    }
}

public struct USDPrimAttributes: Equatable, Sendable {
    public struct AuthoredAttribute: Equatable, Sendable {
        public var name: String
        public var value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    public var primPath: String
    public var primName: String
    public var typeName: String
    public var isActive: Bool
    public var visibility: String
    public var purpose: String
    public var kind: String
    public var authoredAttributes: [AuthoredAttribute]

    public init(
        primPath: String,
        primName: String,
        typeName: String,
        isActive: Bool,
        visibility: String,
        purpose: String,
        kind: String,
        authoredAttributes: [AuthoredAttribute]
    ) {
        self.primPath = primPath
        self.primName = primName
        self.typeName = typeName
        self.isActive = isActive
        self.visibility = visibility
        self.purpose = purpose
        self.kind = kind
        self.authoredAttributes = authoredAttributes
    }
}

public struct USDMaterialInfo: Equatable, Sendable {
    public enum MaterialType: String, Equatable, Sendable {
        case previewSurface
        case materialX
        case unknown
    }

    public var path: String
    public var name: String
    public var materialType: MaterialType
    public var properties: [USDMaterialProperty]

    public init(path: String, name: String, materialType: MaterialType, properties: [USDMaterialProperty]) {
        self.path = path
        self.name = name
        self.materialType = materialType
        self.properties = properties
    }
}

public struct USDMaterialProperty: Equatable, Sendable {
    public enum PropertyType: String, Equatable, Sendable {
        case color
        case float
        case texture
    }

    public enum PropertyValue: Equatable, Sendable {
        case color(r: Float, g: Float, b: Float)
        case float(Float)
        case texture(url: String, resolvedPath: String?)
    }

    public var name: String
    public var type: PropertyType
    public var value: PropertyValue

    public init(name: String, type: PropertyType, value: PropertyValue) {
        self.name = name
        self.type = type
        self.value = value
    }
}

public enum USDMaterialBindingStrength: String, CaseIterable, Equatable, Sendable {
    /// Authors the default strength sparsely (maps to `UsdShadeTokens->fallbackStrength`).
    case fallbackStrength
    case weakerThanDescendants
    case strongerThanDescendants

    public var displayName: String {
        switch self {
        case .fallbackStrength:
            return "Default"
        case .weakerThanDescendants:
            return "Weaker"
        case .strongerThanDescendants:
            return "Stronger"
        }
    }
}

public enum USDFeatureOrigin: String, Equatable, Sendable {
    case core = "USD"
    case preliminary = "AR"
    case realityKit = "RK"
    case materialX = "MX"
}

public struct USDTimelineInfo: Equatable, Sendable {
    public var path: String
    public var name: String
    public var trackCount: Int
    public var actionKinds: [String]

    public init(path: String, name: String, trackCount: Int = 0, actionKinds: [String] = []) {
        self.path = path
        self.name = name
        self.trackCount = trackCount
        self.actionKinds = actionKinds
    }
}

public struct USDBehaviorInfo: Equatable, Sendable {
    public var path: String
    public var name: String
    public var triggerTypes: [String]
    public var actionTypes: [String]

    public init(path: String, name: String, triggerTypes: [String] = [], actionTypes: [String] = []) {
        self.path = path
        self.name = name
        self.triggerTypes = triggerTypes
        self.actionTypes = actionTypes
    }
}

public struct USDAnchorInfo: Equatable, Sendable {
    public var path: String
    public var anchorType: String
    public var alignment: String?
    public var referenceImagePath: String?

    public init(path: String, anchorType: String, alignment: String? = nil, referenceImagePath: String? = nil) {
        self.path = path
        self.anchorType = anchorType
        self.alignment = alignment
        self.referenceImagePath = referenceImagePath
    }
}

public struct USDRealityKitExtensionsInfo: Equatable, Sendable {
    public var timelines: [USDTimelineInfo]
    public var behaviors: [USDBehaviorInfo]
    public var anchors: [USDAnchorInfo]
    public var textPrims: [String]
    public var components: [String]

    public init(
        timelines: [USDTimelineInfo] = [],
        behaviors: [USDBehaviorInfo] = [],
        anchors: [USDAnchorInfo] = [],
        textPrims: [String] = [],
        components: [String] = []
    ) {
        self.timelines = timelines
        self.behaviors = behaviors
        self.anchors = anchors
        self.textPrims = textPrims
        self.components = components
    }
}

public struct USDTimelineStructureInfo: Equatable, Sendable {
    public var path: String
    public var tracks: [USDTimelineTrackInfo]

    public init(path: String, tracks: [USDTimelineTrackInfo] = []) {
        self.path = path
        self.tracks = tracks
    }
}

public struct USDTimelineTrackInfo: Equatable, Sendable {
    public var path: String
    public var name: String
    public var actions: [USDRealityKitActionInfo]

    public init(path: String, name: String, actions: [USDRealityKitActionInfo] = []) {
        self.path = path
        self.name = name
        self.actions = actions
    }
}

public struct USDRealityKitActionInfo: Equatable, Sendable {
    public var path: String
    public var name: String
    public var kind: String
    public var startTime: Double
    public var duration: Double

    public init(path: String, name: String, kind: String, startTime: Double = 0, duration: Double = 0) {
        self.path = path
        self.name = name
        self.kind = kind
        self.startTime = startTime
        self.duration = duration
    }
}

public struct USDBehaviorGraphInfo: Equatable, Sendable {
    public var path: String
    public var connections: [USDBehaviorConnection]

    public init(path: String, connections: [USDBehaviorConnection] = []) {
        self.path = path
        self.connections = connections
    }
}

public struct USDBehaviorConnection: Equatable, Sendable {
    public var triggerPath: String
    public var triggerType: String
    public var actionPath: String
    public var actionType: String

    public init(triggerPath: String, triggerType: String, actionPath: String, actionType: String) {
        self.triggerPath = triggerPath
        self.triggerType = triggerType
        self.actionPath = actionPath
        self.actionType = actionType
    }
}

public struct USDDependencyCheckResult: Equatable, Sendable {
    public var allResolved: Bool
    public var unresolvedPaths: [String]

    public init(allResolved: Bool, unresolvedPaths: [String]) {
        self.allResolved = allResolved
        self.unresolvedPaths = unresolvedPaths
    }
}

public enum USDFixAction: Equatable, Sendable {
    case remapSkeleton(source: String, target: String)
    case mergeSkeletons
    case setUpAxis(to: String)
    case setMetersPerUnit(to: Double)
    case makeRCPReady
    case setDefaultPrim(path: String)
    case addUVs(primPath: String)
    case assignMaterial(primPath: String, materialPath: String)
    case cleanupMissingReference(filePath: String)
    case applyMissingSchema(primPath: String, schemaName: String)
    case setDoubleSided(primPath: String, value: Bool)
    case setSubdivisionScheme(primPath: String, scheme: String)
    case flattenNestedShader(parentPath: String, childPath: String)
    case setTexture(materialPath: String, propertyName: String, textureURL: URL)
    case fixShaderPropertyType(primPath: String, inputName: String, expectedType: String)
}

public enum USDValidationSeverity: String, Equatable, Sendable {
    case error
    case warning
    case info
    case success
}

public struct USDValidationIssue: Equatable, Sendable {
    public var severity: USDValidationSeverity
    public var message: String
    public var details: String?
    public var primPath: String?
    public var fix: USDFixAction?

    public init(
        severity: USDValidationSeverity,
        message: String,
        details: String? = nil,
        primPath: String? = nil,
        fix: USDFixAction? = nil
    ) {
        self.severity = severity
        self.message = message
        self.details = details
        self.primPath = primPath
        self.fix = fix
    }
}

public struct USDValidationOutput: Equatable, Sendable {
    public var results: [USDValidationIssue]
    public var detectedUpAxis: String
    public var detectedMetersPerUnit: Double
    public var skeletonJointCount: Int
    public var maxJointInfluences: Int
    public var hasSkinnedMesh: Bool
    public var hasBlendShapes: Bool
    public var hasSkelAnimation: Bool
    public var meshCount: Int
    public var materialCount: Int
    public var pointInstancerCount: Int

    public init(
        results: [USDValidationIssue] = [],
        detectedUpAxis: String = "Unknown",
        detectedMetersPerUnit: Double = 1.0,
        skeletonJointCount: Int = 0,
        maxJointInfluences: Int = 0,
        hasSkinnedMesh: Bool = false,
        hasBlendShapes: Bool = false,
        hasSkelAnimation: Bool = false,
        meshCount: Int = 0,
        materialCount: Int = 0,
        pointInstancerCount: Int = 0
    ) {
        self.results = results
        self.detectedUpAxis = detectedUpAxis
        self.detectedMetersPerUnit = detectedMetersPerUnit
        self.skeletonJointCount = skeletonJointCount
        self.maxJointInfluences = maxJointInfluences
        self.hasSkinnedMesh = hasSkinnedMesh
        self.hasBlendShapes = hasBlendShapes
        self.hasSkelAnimation = hasSkelAnimation
        self.meshCount = meshCount
        self.materialCount = materialCount
        self.pointInstancerCount = pointInstancerCount
    }
}

public extension USDValidationIssue {
    static func error(
        _ message: String,
        details: String? = nil,
        primPath: String? = nil,
        fix: USDFixAction? = nil
    ) -> USDValidationIssue {
        USDValidationIssue(
            severity: .error,
            message: message,
            details: details,
            primPath: primPath,
            fix: fix
        )
    }

    static func warning(
        _ message: String,
        details: String? = nil,
        primPath: String? = nil,
        fix: USDFixAction? = nil
    ) -> USDValidationIssue {
        USDValidationIssue(
            severity: .warning,
            message: message,
            details: details,
            primPath: primPath,
            fix: fix
        )
    }

    static func info(
        _ message: String,
        details: String? = nil,
        primPath: String? = nil,
        fix: USDFixAction? = nil
    ) -> USDValidationIssue {
        USDValidationIssue(
            severity: .info,
            message: message,
            details: details,
            primPath: primPath,
            fix: fix
        )
    }

    static func success(_ message: String) -> USDValidationIssue {
        USDValidationIssue(
            severity: .success,
            message: message,
            details: nil,
            primPath: nil,
            fix: nil
        )
    }
}
