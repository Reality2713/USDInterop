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
}
