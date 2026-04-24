#include "USDInteropCxx.h"

#include "pxr/base/gf/bbox3d.h"
#include "pxr/base/gf/range3d.h"
#include "pxr/base/gf/vec3d.h"
#include "pxr/base/gf/vec3f.h"
#include "pxr/base/plug/registry.h"
#include "pxr/base/plug/plugin.h"
#include "pxr/base/tf/token.h"
#include "pxr/base/vt/array.h"
#include "pxr/pxr.h"
#include "pxr/usd/ar/asset.h"
#include "pxr/usd/ar/packageUtils.h"
#include "pxr/usd/ar/resolver.h"
#include "pxr/usd/ar/resolverContextBinder.h"
#include "pxr/usd/sdf/copyUtils.h"
#include "pxr/usd/sdf/primSpec.h"
#include "pxr/usd/sdf/propertySpec.h"
#include "pxr/usd/usd/attribute.h"
#include "pxr/usd/usd/prim.h"
#include "pxr/usd/usd/primRange.h"
#include "pxr/usd/usd/property.h"
#include "pxr/usd/usd/stage.h"
#include "pxr/usd/usd/timeCode.h"
#include "pxr/usd/sdf/fileFormat.h"
#include "pxr/usd/usdGeom/bboxCache.h"
#include "pxr/usd/usdGeom/tokens.h"

#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <limits>
#include <string>

PXR_NAMESPACE_USING_DIRECTIVE

namespace {
bool StartsWithPathPrefix(const std::string &value, const std::string &prefix) {
  if (prefix.empty()) {
    return false;
  }
  if (value.size() < prefix.size()) {
    return false;
  }
  return value.compare(0, prefix.size(), prefix) == 0;
}

const char *CopyToCString(const std::string &value) {
  char *buffer = static_cast<char *>(std::malloc(value.size() + 1));
  if (!buffer) {
    return nullptr;
  }
  std::memcpy(buffer, value.data(), value.size());
  buffer[value.size()] = '\0';
  return buffer;
}

const unsigned char *CopyToByteBuffer(const char *data, size_t size) {
  if (!data && size != 0) {
    return nullptr;
  }

  auto *buffer = static_cast<unsigned char *>(std::malloc(size == 0 ? 1 : size));
  if (!buffer) {
    return nullptr;
  }

  if (size != 0) {
    std::memcpy(buffer, data, size);
  }

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

USDInteropSourceSite MakeSourceSite(
    const SdfLayerHandle &layer,
    const std::string &specPath,
    int role
) {
  USDInteropSourceSite result = {};
  if (!layer) {
    return result;
  }

  const std::string layerIdentifier = layer->GetIdentifier();
  const std::string layerRealPath = layer->GetRealPath();

  result.layerIdentifier = CopyToCString(layerIdentifier);
  result.layerRealPath =
      layerRealPath.empty() ? nullptr : CopyToCString(layerRealPath);
  result.specPath = specPath.empty() ? nullptr : CopyToCString(specPath);
  result.role = role;
  result.kind = 0; // unknown until we add canonical arc classification.
  return result;
}

template <typename HandleVector>
USDInteropSourceSiteList MakeSourceSiteList(const HandleVector &specStack) {
  USDInteropSourceSiteList result = {};
  if (specStack.empty()) {
    return result;
  }

  auto *sites = static_cast<USDInteropSourceSite *>(
      std::calloc(specStack.size(), sizeof(USDInteropSourceSite)));
  if (!sites) {
    return result;
  }

  size_t count = 0;
  for (size_t index = 0; index < specStack.size(); ++index) {
    const auto &spec = specStack[index];
    if (!spec) {
      continue;
    }

    const SdfLayerHandle layer = spec->GetLayer();
    if (!layer) {
      continue;
    }

    sites[count++] = MakeSourceSite(
        layer, spec->GetPath().GetAsString(), index == 0 ? 0 : 1);
  }

  if (count == 0) {
    std::free(sites);
    return result;
  }

  result.count = count;
  result.sites = sites;
  return result;
}
} // namespace

namespace USDInterop {
bool GetAttributeValue(const USD::UsdAttribute &attr, USD::VtValue *value) {
  if (!value) {
    return false;
  }
  return attr.Get(value, USD::UsdTimeCode::Default());
}

bool CopySpecFromLayerRefPtr(const USD::SdfLayerRefPtr &srcLayer,
                             const USD::SdfPath &srcPath,
                             const USD::SdfLayerHandle &dstLayer,
                             const USD::SdfPath &dstPath) {
  if (!srcLayer || !dstLayer) {
    return false;
  }
  return SdfCopySpec(srcLayer, srcPath, dstLayer, dstPath);
}

bool ClearAttributeConnections(USD::UsdAttribute attr) {
  try {
    return attr.ClearConnections();
  } catch (...) {
    return false;
  }
}

bool SetAttributeAssetPath(USD::UsdAttribute attr,
                           const std::string &assetPath,
                           const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(SdfAssetPath(assetPath)), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeBool(USD::UsdAttribute attr,
                      bool value,
                      const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(value), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeFloat(USD::UsdAttribute attr,
                       float value,
                       const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(value), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeInt(USD::UsdAttribute attr,
                     int value,
                     const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(static_cast<int32_t>(value)), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeColor3f(USD::UsdAttribute attr,
                         float red,
                         float green,
                         float blue,
                         const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(GfVec3f(red, green, blue)), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeString(USD::UsdAttribute attr,
                        const std::string &value,
                        const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(value), timeCode);
  } catch (...) {
    return false;
  }
}

bool SetAttributeToken(USD::UsdAttribute attr,
                       const USD::TfToken &value,
                       const USD::UsdTimeCode &timeCode) {
  try {
    return attr.Set(USD::VtValue(value), timeCode);
  } catch (...) {
    return false;
  }
}

bool BlockAttribute(USD::UsdAttribute attr) {
  try {
    attr.Block();
    return true;
  } catch (...) {
    return false;
  }
}

bool DisconnectShadeInput(USD::UsdShadeInput input) {
  try {
    return input.DisconnectSource(USD::UsdAttribute());
  } catch (...) {
    return false;
  }
}

USD::UsdShadeInput CreateShaderInput(USD::UsdShadeShader shader,
                                     const USD::TfToken &name,
                                     const pxr::SdfValueTypeName &typeName) {
  try {
    return shader.CreateInput(name, typeName);
  } catch (...) {
    return USD::UsdShadeInput();
  }
}

USD::UsdShadeOutput CreateShaderOutput(USD::UsdShadeShader shader,
                                       const USD::TfToken &name,
                                       const pxr::SdfValueTypeName &typeName) {
  try {
    return shader.CreateOutput(name, typeName);
  } catch (...) {
    return USD::UsdShadeOutput();
  }
}

bool CreateShaderIdAttr(USD::UsdShadeShader shader,
                        const USD::TfToken &identifier) {
  try {
    return shader.CreateIdAttr(USD::VtValue(identifier), false).IsValid();
  } catch (...) {
    return false;
  }
}

bool ConnectShadeInputToOutput(USD::UsdShadeInput input,
                               USD::UsdShadeOutput output) {
  try {
    return input.ConnectToSource(output);
  } catch (...) {
    return false;
  }
}

bool ExportStage(const USD::UsdStage &stage,
                 const std::string &path,
                 bool addSourceFileComment) {
  try {
    return stage.Export(path, addSourceFileComment, SdfLayer::FileFormatArguments());
  } catch (...) {
    return false;
  }
}
} // namespace USDInterop

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

  const std::string stagePath(path);
  const bool isSessionLayer =
      std::filesystem::path(stagePath).filename() == "session.usda";

  if (isSessionLayer) {
    try {
      std::filesystem::last_write_time(
          stagePath, std::filesystem::file_time_type::clock::now());
    } catch (...) {
      // Best-effort cache-bust for session layers.
    }
  }

  UsdStageRefPtr stage = UsdStage::Open(stagePath);
  if (!stage) {
    return result;
  }

  if (isSessionLayer) {
    // Avoid reloading immediately after opening session.usda.
    // Open() already reflects current on-disk state, and a forced Reload()
    // has been observed to crash intermittently during startup.
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

USDInteropSourceSiteList usdinterop_stage_prim_source_sites(
    const char *stage_path,
    const char *prim_path
) {
  USDInteropSourceSiteList result = {};

  if (!stage_path || stage_path[0] == '\0' || !prim_path || prim_path[0] == '\0') {
    return result;
  }

  UsdStageRefPtr stage = UsdStage::Open(std::string(stage_path), UsdStage::LoadAll);
  if (!stage) {
    return result;
  }

  const UsdPrim prim = stage->GetPrimAtPath(SdfPath(std::string(prim_path)));
  if (!prim.IsValid()) {
    return result;
  }

  const auto primStack = prim.GetPrimStack();
  return MakeSourceSiteList(primStack);
}

USDInteropSourceSiteList usdinterop_stage_property_source_sites(
    const char *stage_path,
    const char *property_path
) {
  USDInteropSourceSiteList result = {};

  if (!stage_path || stage_path[0] == '\0' || !property_path || property_path[0] == '\0') {
    return result;
  }

  UsdStageRefPtr stage = UsdStage::Open(std::string(stage_path), UsdStage::LoadAll);
  if (!stage) {
    return result;
  }

  const UsdProperty property = stage->GetPropertyAtPath(SdfPath(std::string(property_path)));
  if (!property.IsDefined()) {
    return result;
  }

  const auto propertyStack = property.GetPropertyStack(UsdTimeCode::Default());
  return MakeSourceSiteList(propertyStack);
}

void usdinterop_free_source_site_list(USDInteropSourceSiteList list) {
  if (!list.sites) {
    return;
  }

  for (size_t index = 0; index < list.count; ++index) {
    const USDInteropSourceSite &site = list.sites[index];
    if (site.layerIdentifier) {
      usdinterop_free_string(site.layerIdentifier);
    }
    if (site.layerRealPath) {
      usdinterop_free_string(site.layerRealPath);
    }
    if (site.specPath) {
      usdinterop_free_string(site.specPath);
    }
  }

  std::free(list.sites);
}

int usdinterop_register_plugins(const char *path) {
  if (!path || path[0] == '\0') {
    return 0;
  }

  const std::string rootPath(path);
  const PlugPluginPtrVector plugins =
      PlugRegistry::GetInstance().RegisterPlugins(rootPath);

  for (const PlugPluginPtr &plugin : plugins) {
    if (plugin) {
      plugin->Load();
    }
  }

  const PlugPluginPtrVector allPlugins =
      PlugRegistry::GetInstance().GetAllPlugins();
  for (const PlugPluginPtr &plugin : allPlugins) {
    if (!plugin) {
      continue;
    }

    const std::string &pluginPath = plugin->GetPath();
    const std::string &resourcePath = plugin->GetResourcePath();
    if (StartsWithPathPrefix(pluginPath, rootPath) ||
        StartsWithPathPrefix(resourcePath, rootPath)) {
      plugin->Load();
    }
  }

  return static_cast<int>(plugins.size());
}

int usdinterop_has_file_format(const char *format_id) {
  if (!format_id || format_id[0] == '\0') {
    return 0;
  }

  const TfToken token(format_id);
  return SdfFileFormat::FindById(token) ? 1 : 0;
}

int usdinterop_is_package_relative_path(const char *path) {
  if (!path || path[0] == '\0') {
    return 0;
  }
  return ArIsPackageRelativePath(std::string(path)) ? 1 : 0;
}

const unsigned char *usdinterop_read_asset_bytes(const char *asset_path,
                                                 const char *anchor_asset_path,
                                                 size_t *size) {
  if (!asset_path || asset_path[0] == '\0' || !size) {
    return nullptr;
  }

  *size = 0;

  try {
    ArResolver &resolver = ArGetResolver();

    const std::string assetPath(asset_path);
    const std::string anchorAssetPath =
        (anchor_asset_path && anchor_asset_path[0] != '\0')
            ? std::string(anchor_asset_path)
            : std::string();

    const std::string contextAssetPath =
        !anchorAssetPath.empty() ? anchorAssetPath : assetPath;
    ArResolverContext context =
        resolver.CreateDefaultContextForAsset(contextAssetPath);
    ArResolverContextBinder binder(&resolver, context);

    const ArResolvedPath anchorResolvedPath =
        !anchorAssetPath.empty() ? resolver.Resolve(anchorAssetPath)
                                 : ArResolvedPath();
    const std::string identifier =
        resolver.CreateIdentifier(assetPath, anchorResolvedPath);
    const ArResolvedPath resolvedPath = resolver.Resolve(identifier);
    if (resolvedPath.empty()) {
      return nullptr;
    }

    std::shared_ptr<ArAsset> asset = resolver.OpenAsset(resolvedPath);
    if (!asset) {
      return nullptr;
    }

    const size_t assetSize = asset->GetSize();
    std::shared_ptr<const char> buffer = asset->GetBuffer();
    if (!buffer && assetSize != 0) {
      return nullptr;
    }

    const unsigned char *copied =
        CopyToByteBuffer(buffer.get(), assetSize);
    if (!copied) {
      return nullptr;
    }

    *size = assetSize;
    return copied;
  } catch (...) {
    *size = 0;
    return nullptr;
  }
}

void usdinterop_free_bytes(const void *value) {
  if (!value) {
    return;
  }
  std::free(const_cast<void *>(value));
}

const char *usdinterop_split_package_relative_path_outer_package(
    const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }
  const auto result = ArSplitPackageRelativePathOuter(std::string(path));
  return CopyToCString(result.first);
}

const char *usdinterop_split_package_relative_path_outer_packaged(
    const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }
  const auto result = ArSplitPackageRelativePathOuter(std::string(path));
  return CopyToCString(result.second);
}

const char *usdinterop_split_package_relative_path_inner_package(
    const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }
  const auto result = ArSplitPackageRelativePathInner(std::string(path));
  return CopyToCString(result.first);
}

const char *usdinterop_split_package_relative_path_inner_packaged(
    const char *path) {
  if (!path || path[0] == '\0') {
    return nullptr;
  }
  const auto result = ArSplitPackageRelativePathInner(std::string(path));
  return CopyToCString(result.second);
}

const char *usdinterop_join_package_relative_path(const char *package_path,
                                                  const char *packaged_path) {
  if (!package_path || package_path[0] == '\0' || !packaged_path ||
      packaged_path[0] == '\0') {
    return nullptr;
  }
  return CopyToCString(ArJoinPackageRelativePath(std::string(package_path),
                                                 std::string(packaged_path)));
}
