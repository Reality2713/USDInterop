import Foundation
import USDInteropCxx

public enum USDInteropStage {
	public static func exportUSDA(url: URL) -> String? {
		exportUSDA(path: url.path)
	}

	public static func exportUSDA(path: String) -> String? {
		path.withCString { pointer in
			guard let result = usdinterop_export_usda(pointer) else {
				return nil
			}
			defer { usdinterop_free_string(result) }
			return String(cString: result)
		}
	}

	public static func sceneGraphJSON(url: URL) -> String? {
		sceneGraphJSON(path: url.path)
	}

	public static func sceneGraphJSON(path: String) -> String? {
		path.withCString { pointer in
			guard let result = usdinterop_scene_graph_json(pointer) else {
				return nil
			}
			defer { usdinterop_free_string(result) }
			return String(cString: result)
		}
	}

	/// Scene bounds with min, max, center and maxExtent
	public struct SceneBounds {
		public var min: SIMD3<Float>
		public var max: SIMD3<Float>
		public var center: SIMD3<Float>
		public var maxExtent: Float
	}

	/// Get scene bounds by iterating mesh points
	public static func sceneBounds(url: URL) -> SceneBounds? {
		sceneBounds(path: url.path)
	}

	public static func sceneBounds(path: String) -> SceneBounds? {
		let result = path.withCString { pointer in
			usdinterop_scene_bounds(pointer)
		}
		guard result.hasGeometry != 0 else {
			return nil
		}
		return SceneBounds(
			min: SIMD3(result.minX, result.minY, result.minZ),
			max: SIMD3(result.maxX, result.maxY, result.maxZ),
			center: SIMD3(result.centerX, result.centerY, result.centerZ),
			maxExtent: result.maxExtent
		)
	}
}
