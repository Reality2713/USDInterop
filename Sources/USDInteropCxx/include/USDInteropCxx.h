#ifndef USDINTEROPCXX_H
#define USDINTEROPCXX_H

#ifdef __cplusplus
#include "USDUtilsHelper.hpp"
extern "C" {
#endif

/// Scene bounds result struct
typedef struct {
    float minX, minY, minZ;
    float maxX, maxY, maxZ;
    float centerX, centerY, centerZ;
    float maxExtent;
    int hasGeometry;  // 1 if valid, 0 if no geometry
} USDInteropBounds;

const char *usdinterop_export_usda(const char *path);
const char *usdinterop_scene_graph_json(const char *path);
void usdinterop_free_string(const char *value);

/// Get scene bounds by iterating mesh points
USDInteropBounds usdinterop_scene_bounds(const char *path);

/// Force OpenUSD to scan/register plugins under `path`.
/// Returns the number of plugins registered by this call.
int usdinterop_register_plugins(const char *path);

/// Force OpenUSD to resolve a file format by id (for example: "ply", "gltf").
/// Returns 1 when the file format is available, otherwise 0.
int usdinterop_has_file_format(const char *format_id);

/// Returns 1 when the path is package-relative per Ar package-path rules.
int usdinterop_is_package_relative_path(const char *path);

/// Splits the outermost package-relative path and returns the package path.
const char *usdinterop_split_package_relative_path_outer_package(const char *path);

/// Splits the outermost package-relative path and returns the packaged path.
const char *usdinterop_split_package_relative_path_outer_packaged(const char *path);

/// Splits the innermost package-relative path and returns the package path.
const char *usdinterop_split_package_relative_path_inner_package(const char *path);

/// Splits the innermost package-relative path and returns the packaged path.
const char *usdinterop_split_package_relative_path_inner_packaged(const char *path);

/// Joins a package path and packaged path using canonical Ar rules.
const char *usdinterop_join_package_relative_path(const char *package_path, const char *packaged_path);

/// Reads asset bytes using the canonical Ar resolver and returns a malloc-owned buffer.
/// `anchor_asset_path` is optional and is used to resolve relative asset paths.
const unsigned char *usdinterop_read_asset_bytes(
    const char *asset_path,
    const char *anchor_asset_path,
    size_t *size
);

/// Frees a buffer returned by `usdinterop_read_asset_bytes`.
void usdinterop_free_bytes(const void *value);

#ifdef __cplusplus
}
#endif

#endif // USDINTEROPCXX_H
