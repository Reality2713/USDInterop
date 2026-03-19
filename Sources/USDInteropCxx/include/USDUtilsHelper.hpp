
#ifndef USD_UTILS_HELPER_HPP
#define USD_UTILS_HELPER_HPP

#include "pxr/base/vt/value.h"
#include "pxr/pxr.h"
#include "pxr/usd/sdf/layer.h"
#include "pxr/usd/sdf/path.h"
#include "pxr/usd/sdf/attributeSpec.h"
#include "pxr/usd/usd/editTarget.h"
#include "pxr/usd/usd/attribute.h"
#include "pxr/usd/usd/prim.h"
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

/// Creates a USDZ package using the current native OpenUSD API.
///
/// This always uses `UsdUtilsCreateNewUsdzPackage`, which preserves authored
/// stage metadata such as `metersPerUnit` and `upAxis`.
///
/// @param assetPath Path to the source USD asset (usda/usdc)
/// @param outputPath Path for the output USDZ file
/// @return true on success, false on failure
bool CreateUsdzPackageNative(const std::string &assetPath,
                             const std::string &outputPath);

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
using SdfLayerRefPtr = pxr::SdfLayerRefPtr;
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
/// Swift-facing shim to avoid Swift/C++ interop default-argument deserialization
/// crashes when calling `UsdAttribute::Get(VtValue*)`.
bool GetAttributeValue(const USD::UsdAttribute &attr, USD::VtValue *value);

/// Rewrites an authored attribute spec in a layer to `string`, preserving the
/// current default value when it is authored as `string` or `token`.
bool RewriteAttributeSpecTypeToString(const USD::SdfLayerHandle &layer,
                                      const USD::SdfPath &attrPath);

/// Rewrites all authored attribute specs in the layer with the given property
/// name from token to string. Returns the number of rewritten specs.
int RewriteAllTokenAttributeSpecsToString(const USD::SdfLayerHandle &layer,
                                          const std::string &propertyName);

/// Copies a spec from a ref-counted source layer into a destination layer
/// handle. This lets C++ perform the ref->weak conversion that Swift interop
/// does not expose directly.
bool CopySpecFromLayerRefPtr(const USD::SdfLayerRefPtr &srcLayer,
                             const USD::SdfPath &srcPath,
                             const USD::SdfLayerHandle &dstLayer,
                             const USD::SdfPath &dstPath);
}

#endif
