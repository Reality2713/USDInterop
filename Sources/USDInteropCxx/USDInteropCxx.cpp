#include "USDInteropCxx.h"

#include "pxr/base/gf/bbox3d.h"
#include "pxr/base/gf/range3d.h"
#include "pxr/base/gf/vec3d.h"
#include "pxr/base/gf/vec3f.h"
#include "pxr/base/tf/token.h"
#include "pxr/base/vt/array.h"
#include "pxr/pxr.h"
#include "pxr/usd/usd/attribute.h"
#include "pxr/usd/usd/prim.h"
#include "pxr/usd/usd/primRange.h"
#include "pxr/usd/usd/stage.h"
#include "pxr/usd/usd/timeCode.h"
#include "pxr/usd/usdGeom/bboxCache.h"
#include "pxr/usd/usdGeom/tokens.h"

#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>

PXR_NAMESPACE_USING_DIRECTIVE

namespace {
const char *CopyToCString(const std::string &value) {
  char *buffer = static_cast<char *>(std::malloc(value.size() + 1));
  if (!buffer) {
    return nullptr;
  }
  std::memcpy(buffer, value.data(), value.size());
  buffer[value.size()] = '\0';
  return buffer;
}

void EscapeJson(const std::string &value, std::string &out) {
  for (char c : value) {
    switch (c) {
    case '"':
      out += "\\\"";
      break;
    case '\\':
      out += "\\\\";
      break;
    case '\b':
      out += "\\b";
      break;
    case '\f':
      out += "\\f";
      break;
    case '\n':
      out += "\\n";
      break;
    case '\r':
      out += "\\r";
      break;
    case '\t':
      out += "\\t";
      break;
    default:
      if (static_cast<unsigned char>(c) < 0x20) {
        char buffer[7];
        std::snprintf(buffer, sizeof(buffer), "\\u%04x",
                      static_cast<unsigned char>(c));
        out += buffer;
      } else {
        out += c;
      }
      break;
    }
  }
}

void AppendPrimJson(const UsdPrim &prim, std::string &out) {
  std::string name = prim.GetName().GetString();
  std::string path = prim.GetPath().GetString();
  std::string typeName = prim.GetTypeName().GetString();

  out += "{\"name\":\"";
  EscapeJson(name, out);
  out += "\",\"path\":\"";
  EscapeJson(path, out);
  out += "\"";

  if (!typeName.empty()) {
    out += ",\"type\":\"";
    EscapeJson(typeName, out);
    out += "\"";
  }

  out += ",\"children\":[";

  bool first = true;
  for (const auto &child : prim.GetChildren()) {
    if (!first) {
      out += ",";
    }
    AppendPrimJson(child, out);
    first = false;
  }

  out += "]}";
}
} // namespace

const char *usdinterop_export_usda(const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }

  UsdStageRefPtr stage = UsdStage::Open(std::string(path));
  if (!stage) {
    return nullptr;
  }

  std::string output;
  if (!stage->ExportToString(&output)) {
    return nullptr;
  }

  return CopyToCString(output);
}

const char *usdinterop_scene_graph_json(const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }

  UsdStageRefPtr stage = UsdStage::Open(std::string(path));
  if (!stage) {
    return nullptr;
  }

  UsdPrim pseudoRoot = stage->GetPseudoRoot();
  if (!pseudoRoot.IsValid()) {
    return nullptr;
  }

  std::string output = "[";
  bool first = true;
  for (const auto &child : pseudoRoot.GetChildren()) {
    if (!first) {
      output += ",";
    }
    AppendPrimJson(child, output);
    first = false;
  }
  output += "]";

  return CopyToCString(output);
}

void usdinterop_free_string(const char *value) {
  if (!value) {
    return;
  }
  std::free(const_cast<char *>(value));
}

USDInteropBounds usdinterop_scene_bounds(const char *path) {
  USDInteropBounds result = {};
  result.hasGeometry = 0;

  if (!path || path[0] == '\0') {
    return result;
  }

  UsdStageRefPtr stage = UsdStage::Open(std::string(path));
  if (!stage) {
    return result;
  }

  // Use UsdGeomBBoxCache for proper bounds calculation
  // This works correctly with payloads, references, and variants
  TfTokenVector purposes = {UsdGeomTokens->default_, UsdGeomTokens->render};
  UsdGeomBBoxCache bboxCache(UsdTimeCode::Default(), purposes, true);

  UsdPrim root = stage->GetDefaultPrim();
  if (!root.IsValid()) {
    root = stage->GetPseudoRoot();
  }

  GfBBox3d worldBounds = bboxCache.ComputeWorldBound(root);
  GfRange3d range = worldBounds.ComputeAlignedBox();

  if (!range.IsEmpty()) {
    result.hasGeometry = 1;
    GfVec3d min = range.GetMin();
    GfVec3d max = range.GetMax();
    result.minX = static_cast<float>(min[0]);
    result.minY = static_cast<float>(min[1]);
    result.minZ = static_cast<float>(min[2]);
    result.maxX = static_cast<float>(max[0]);
    result.maxY = static_cast<float>(max[1]);
    result.maxZ = static_cast<float>(max[2]);
    result.centerX = static_cast<float>((min[0] + max[0]) / 2.0);
    result.centerY = static_cast<float>((min[1] + max[1]) / 2.0);
    result.centerZ = static_cast<float>((min[2] + max[2]) / 2.0);
    double extentX = max[0] - min[0];
    double extentY = max[1] - min[1];
    double extentZ = max[2] - min[2];
    result.maxExtent =
        static_cast<float>(std::max(extentX, std::max(extentY, extentZ)));
  }

  return result;
}
