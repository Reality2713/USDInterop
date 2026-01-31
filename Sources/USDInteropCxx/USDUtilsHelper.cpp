
#include "USDUtilsHelper.hpp"
#include <exception>

// Thread-local cache for unresolved paths
static thread_local std::vector<std::string> g_unresolvedCache;

DependencyCheckResultCxx CheckDependenciesSimple(const std::string &assetPath) {
  DependencyCheckResultCxx result;
  result.success = false;
  result.unresolvedCount = 0;

  // Clear previous cache
  g_unresolvedCache.clear();

  try {
    SdfAssetPath sdfAssetPath(assetPath);
    std::vector<SdfLayerRefPtr> layers;
    std::vector<std::string> assets;
    std::vector<std::string> unresolved;

    // Call with default std::function()
    bool usdResult = UsdUtilsComputeAllDependencies(
        sdfAssetPath, &layers, &assets, &unresolved,
        std::function<UsdUtilsProcessingFunc>());

    // Cache unresolved paths
    g_unresolvedCache = unresolved;

    result.success = usdResult;
    result.unresolvedCount = static_cast<int>(unresolved.size());
    return result;
  } catch (const std::exception &e) {
    g_unresolvedCache.clear();
    g_unresolvedCache.push_back(std::string("C++ exception: ") + e.what());
    result.unresolvedCount = 1;
    return result;
  } catch (...) {
    g_unresolvedCache.clear();
    g_unresolvedCache.push_back("Unknown C++ exception");
    result.unresolvedCount = 1;
    return result;
  }
}

std::string GetUnresolvedPath(int index) {
  if (index < 0 || index >= static_cast<int>(g_unresolvedCache.size())) {
    return "";
  }
  return g_unresolvedCache[index];
}

void ClearUnresolvedCache() { g_unresolvedCache.clear(); }

bool CreateUsdzPackageNative(const std::string &assetPath,
                             const std::string &outputPath,
                             bool arkitCompatible) {
  try {
    SdfAssetPath sdfAssetPath(assetPath);

    // Empty string for file comment, false for checkCompliance (we do our own
    // validation)
    if (arkitCompatible) {
      return UsdUtilsCreateNewARKitUsdzPackage(sdfAssetPath, outputPath,
                                               std::string(), false);
    }
    return UsdUtilsCreateNewUsdzPackage(sdfAssetPath, outputPath, std::string(),
                                        false);
  } catch (const std::exception &e) {
    // Log error for debugging
    return false;
  } catch (...) {
    return false;
  }
}
