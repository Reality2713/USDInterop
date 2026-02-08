
#ifndef USD_UTILS_HELPER_HPP
#define USD_UTILS_HELPER_HPP

#include "pxr/base/vt/value.h"
#include "pxr/pxr.h"
#include "pxr/usd/sdf/layer.h"
#include "pxr/usd/sdf/path.h"
#include "pxr/usd/sdf/reference.h"
#include "pxr/usd/usd/attribute.h"
#include "pxr/usd/usd/editTarget.h"
#include "pxr/usd/usd/prim.h"
#include "pxr/usd/usd/references.h"
#include "pxr/usd/usd/stage.h"
#include "pxr/usd/usd/timeCode.h"
#include "pxr/usd/usd/variantSets.h"
#include "pxr/usd/usdGeom/imageable.h"
#include "pxr/usd/usdGeom/mesh.h"
#include "pxr/usd/usdGeom/primvarsAPI.h"
#include "pxr/usd/usdGeom/xformCommonAPI.h"
#include "pxr/usd/usdGeom/xformOp.h"
#include "pxr/usd/usdGeom/xformable.h"
#include "pxr/usd/usdShade/connectableAPI.h"
#include "pxr/usd/usdShade/material.h"
#include "pxr/usd/usdShade/materialBindingAPI.h"
#include "pxr/usd/usdShade/shader.h"
#include "pxr/usd/usdSkel/bindingAPI.h"
#include "pxr/usd/usdUtils/api.h"
#include "pxr/usd/usdUtils/dependencies.h"
#include "pxr/usd/usdUtils/usdzPackage.h"
#include <string>
#include <vector>

PXR_NAMESPACE_USING_DIRECTIVE

/// Result struct for dependency checking - Swift friendly
struct DependencyCheckResultCxx {
  bool success;
  int unresolvedCount;
};

/// Check dependencies and return result struct
DependencyCheckResultCxx CheckDependenciesSimple(const std::string &assetPath);

/// Get unresolved path at index (call after CheckDependenciesSimple)
/// Returns empty string if index out of bounds
std::string GetUnresolvedPath(int index);

/// Clear cached unresolved paths
void ClearUnresolvedCache();

/// Creates a USDZ package using native OpenUSD API
///
/// @param assetPath Path to the source USD asset (usda/usdc)
/// @param outputPath Path for the output USDZ file
/// @param arkitCompatible Controls which OpenUSD packaging function is used:
///
/// ## arkitCompatible = false (RECOMMENDED for Preflight)
/// Uses `UsdUtilsCreateNewUsdzPackage`:
/// - Preserves original stage metadata (metersPerUnit, upAxis)
/// - Bundles all dependencies into the USDZ archive
/// - No automatic unit/scale normalization
///
/// ## arkitCompatible = true
/// Uses `UsdUtilsCreateNewARKitUsdzPackage`:
/// - Designed for Apple ARKit/RealityKit compatibility
/// - **NORMALIZES metersPerUnit to 1.0** (meters) during packaging
/// - May apply additional ARKit-specific optimizations
/// - Use ONLY when you want geometry scaled to meters
///
/// @warning The ARKit variant changes your model's scale! A model with
///          metersPerUnit=0.01 (centimeters) will be converted to 1.0 (meters),
///          making it appear 100x larger when loaded in apps that respect
///          metersPerUnit.
///
/// @return true on success, false on failure
bool CreateUsdzPackageNative(const std::string &assetPath,
                             const std::string &outputPath,
                             bool arkitCompatible);

// Clean namespaced aliases for Swift to bypass 'pxr' shadowing
namespace USD {
using UsdPrim = pxr::UsdPrim;
using UsdStage = pxr::UsdStage;
using UsdStageRefPtr = pxr::UsdStageRefPtr;
using TfToken = pxr::TfToken;
using SdfPath = pxr::SdfPath;
using VtValue = pxr::VtValue;
using UsdTimeCode = pxr::UsdTimeCode;
using UsdAttribute = pxr::UsdAttribute;
using SdfLayerHandle = pxr::SdfLayerHandle;
using SdfLayer = pxr::SdfLayer;
using UsdEditTarget = pxr::UsdEditTarget;
using UsdVariantSets = pxr::UsdVariantSets;
using UsdVariantSet = pxr::UsdVariantSet;

// Geometry
using UsdGeomXformable = pxr::UsdGeomXformable;
using UsdGeomXformCommonAPI = pxr::UsdGeomXformCommonAPI;
using UsdGeomMesh = pxr::UsdGeomMesh;
using UsdGeomImageable = pxr::UsdGeomImageable;
using UsdGeomPrimvarsAPI = pxr::UsdGeomPrimvarsAPI;
using UsdGeomXformOp = pxr::UsdGeomXformOp;

// Shade & Skel
using UsdShadeMaterial = pxr::UsdShadeMaterial;
using UsdShadeShader = pxr::UsdShadeShader;
using UsdShadeMaterialBindingAPI = pxr::UsdShadeMaterialBindingAPI;
using UsdShadeConnectableAPI = pxr::UsdShadeConnectableAPI;
using UsdSkelBindingAPI = pxr::UsdSkelBindingAPI;
using Usd_PrimFlagsPredicate = pxr::Usd_PrimFlagsPredicate;
} // namespace USD

namespace USDInterop {
/// Swift-facing shim to avoid Swift/C++ interop default-argument
/// deserialization crashes when calling `UsdAttribute::Get(VtValue*)`.
bool GetAttributeValue(const USD::UsdAttribute &attr, USD::VtValue *value);

/// Add a reference to a prim.
bool AddReference(const USD::UsdPrim &prim, const std::string &assetPath,
                  const std::string &primPath);

/// Remove a reference from a prim.
bool RemoveReference(const USD::UsdPrim &prim, const std::string &assetPath,
                     const std::string &primPath);
} // namespace USDInterop

#endif
