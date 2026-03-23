import Foundation
import USDInteropCxx

public enum USDInteropPlugins {
	public static func registerPlugins(url: URL) -> Int {
		registerPlugins(path: url.path)
	}

	@discardableResult
	public static func registerPlugins(path: String) -> Int {
		path.withCString { pointer in
			Int(usdinterop_register_plugins(pointer))
		}
	}

	public static func hasFileFormat(_ formatID: String) -> Bool {
		formatID.withCString { pointer in
			usdinterop_has_file_format(pointer) != 0
		}
	}
}

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

public enum USDInteropPackagePaths {
	private static func stringResult(
		_ body: () -> UnsafePointer<CChar>?
	) -> String? {
		guard let result = body() else { return nil }
		defer { usdinterop_free_string(result) }
		return String(cString: result)
	}

	public static func isPackageRelativePath(_ path: String) -> Bool {
		path.withCString { pointer in
			usdinterop_is_package_relative_path(pointer) != 0
		}
	}

	public static func splitOuter(_ path: String) -> (packagePath: String, packagedPath: String)? {
		guard isPackageRelativePath(path) else { return nil }
		let packagePath = path.withCString { pointer in
			stringResult {
				usdinterop_split_package_relative_path_outer_package(pointer)
			}
		}
		let packagedPath = path.withCString { pointer in
			stringResult {
				usdinterop_split_package_relative_path_outer_packaged(pointer)
			}
		}
		guard let packagePath, let packagedPath else { return nil }
		return (packagePath, packagedPath)
	}

	public static func splitInner(_ path: String) -> (packagePath: String, packagedPath: String)? {
		guard isPackageRelativePath(path) else { return nil }
		let packagePath = path.withCString { pointer in
			stringResult {
				usdinterop_split_package_relative_path_inner_package(pointer)
			}
		}
		let packagedPath = path.withCString { pointer in
			stringResult {
				usdinterop_split_package_relative_path_inner_packaged(pointer)
			}
		}
		guard let packagePath, let packagedPath else { return nil }
		return (packagePath, packagedPath)
	}

	public static func join(packagePath: String, packagedPath: String) -> String? {
		packagePath.withCString { outer in
			packagedPath.withCString { inner in
				stringResult {
					usdinterop_join_package_relative_path(outer, inner)
				}
			}
		}
	}

	public static func innermostPackagedPath(_ path: String) -> String {
		var current = path
			.replacingOccurrences(of: "@", with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)

		while let split = splitInner(current) {
			current = split.packagedPath
		}

		return current.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
	}
}
