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
    USDPrimListing & USDDefaultPrimEditing & USDSchemaApplying & USDVariantEditing & USDVariantCombining
