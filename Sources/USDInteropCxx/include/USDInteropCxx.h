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

#ifdef __cplusplus
}
#endif

#endif // USDINTEROPCXX_H
