
#include "USDUtilsHelper.hpp"
#include "pxr/base/tf/token.h"
#include "pxr/base/tf/diagnosticMgr.h"
#include <exception>
#include <regex>
#include <set>

// Thread-local cache for unresolved paths
static thread_local std::vector<std::string> g_unresolvedCache;
struct PackagingDiagnosticCacheItem {
  int severity;
  std::string message;
};
static thread_local std::vector<PackagingDiagnosticCacheItem>
    g_packagingDiagnosticCache;
static thread_local std::vector<std::string> g_packagingFailedAssetPathCache;

namespace {
void CacheFailedAssetPath(const std::string &path, std::set<std::string> &seenPaths) {
  if (path.empty()) {
    return;
  }
  if (seenPaths.insert(path).second) {
    g_packagingFailedAssetPathCache.push_back(path);
  }
}

void CachePackagingDiagnostic(
    int severity,
    const std::string &commentary,
    std::set<std::string> &seenPaths) {
  g_packagingDiagnosticCache.push_back(
      PackagingDiagnosticCacheItem{severity, commentary});

  std::smatch match;
  static const std::regex addFilePattern("Failed to add file '([^']+)'");
  static const std::regex mapFilePattern("Failed to map '([^']+)'");
  static const std::regex resolveReferencePattern(
      "Failed to resolve reference @([^@]+)@");

  if (std::regex_search(commentary, match, addFilePattern) && match.size() > 1) {
    CacheFailedAssetPath(match[1].str(), seenPaths);
    return;
  }
  if (std::regex_search(commentary, match, mapFilePattern) && match.size() > 1) {
    CacheFailedAssetPath(match[1].str(), seenPaths);
    return;
  }
  if (std::regex_search(commentary, match, resolveReferencePattern) &&
      match.size() > 1) {
    CacheFailedAssetPath(match[1].str(), seenPaths);
    return;
  }
}

class PackagingDiagnosticDelegate final : public TfDiagnosticMgr::Delegate {
 public:
  void IssueError(const TfError &error) override {
    CachePackagingDiagnostic(2, error.GetCommentary(), _seenPaths);
  }

  void IssueFatalError(const TfCallContext &, const std::string &message) override {
    CachePackagingDiagnostic(3, message, _seenPaths);
  }

  void IssueStatus(const TfStatus &status) override {
    CachePackagingDiagnostic(0, status.GetCommentary(), _seenPaths);
  }

  void IssueWarning(const TfWarning &warning) override {
    CachePackagingDiagnostic(1, warning.GetCommentary(), _seenPaths);
  }

 private:
  std::set<std::string> _seenPaths;
};

class ScopedPackagingDelegateRegistration {
 public:
  explicit ScopedPackagingDelegateRegistration(
      TfDiagnosticMgr::Delegate *delegate)
      : _delegate(delegate) {
    TfDiagnosticMgr::GetInstance().AddDelegate(_delegate);
  }

  ~ScopedPackagingDelegateRegistration() {
    if (_delegate) {
      TfDiagnosticMgr::GetInstance().RemoveDelegate(_delegate);
    }
  }

 private:
  TfDiagnosticMgr::Delegate *_delegate;
};

void ClearPackagingCaches() {
  g_packagingDiagnosticCache.clear();
  g_packagingFailedAssetPathCache.clear();
}
} // namespace

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
                             const std::string &outputPath) {
  return CreateUsdzPackageNativeDetailed(assetPath, outputPath).success;
}

UsdzPackagingResultCxx CreateUsdzPackageNativeDetailed(
    const std::string &assetPath,
    const std::string &outputPath) {
  UsdzPackagingResultCxx result;
  result.success = false;
  result.diagnosticCount = 0;
  result.warningCount = 0;
  result.errorCount = 0;
  result.failedAssetCount = 0;

  ClearPackagingCaches();
  try {
    PackagingDiagnosticDelegate delegate;
    ScopedPackagingDelegateRegistration registration(&delegate);
    SdfAssetPath sdfAssetPath(assetPath);
    result.success = UsdUtilsCreateNewUsdzPackage(
        sdfAssetPath, outputPath, std::string(), false);
    result.diagnosticCount =
        static_cast<int>(g_packagingDiagnosticCache.size());
    result.failedAssetCount =
        static_cast<int>(g_packagingFailedAssetPathCache.size());
    for (const auto &diagnostic : g_packagingDiagnosticCache) {
      if (diagnostic.severity == 1) {
        result.warningCount += 1;
      } else if (diagnostic.severity >= 2) {
        result.errorCount += 1;
      }
    }
    return result;
  } catch (const std::exception &e) {
    g_packagingDiagnosticCache.push_back(
        PackagingDiagnosticCacheItem{2, std::string("C++ exception: ") + e.what()});
    result.diagnosticCount = 1;
    result.errorCount = 1;
    return result;
  } catch (...) {
    g_packagingDiagnosticCache.push_back(
        PackagingDiagnosticCacheItem{2, "Unknown C++ exception"});
    result.diagnosticCount = 1;
    result.errorCount = 1;
    return result;
  }
}

std::string GetPackagingDiagnosticMessage(int index) {
  if (index < 0 || index >= static_cast<int>(g_packagingDiagnosticCache.size())) {
    return "";
  }
  return g_packagingDiagnosticCache[index].message;
}

int GetPackagingDiagnosticSeverity(int index) {
  if (index < 0 || index >= static_cast<int>(g_packagingDiagnosticCache.size())) {
    return -1;
  }
  return g_packagingDiagnosticCache[index].severity;
}

std::string GetPackagingFailedAssetPath(int index) {
  if (index < 0 ||
      index >= static_cast<int>(g_packagingFailedAssetPathCache.size())) {
    return "";
  }
  return g_packagingFailedAssetPathCache[index];
}

void ClearPackagingDiagnosticCache() {
  ClearPackagingCaches();
}

namespace USDInterop {
bool RewriteAttributeSpecTypeToString(const USD::SdfLayerHandle &layer,
                                      const USD::SdfPath &attrPath) {
  if (!layer) {
    return false;
  }

  pxr::SdfAttributeSpecHandle attrSpec = layer->GetAttributeAtPath(attrPath);
  if (!attrSpec) {
    return false;
  }

  pxr::SdfPrimSpecHandle owner = layer->GetPrimAtPath(attrPath.GetPrimPath());
  if (!owner) {
    return false;
  }

  const pxr::SdfVariability variability = attrSpec->GetVariability();
  const bool isCustom = attrSpec->IsCustom();

  bool hasDefaultValue = attrSpec->HasDefaultValue();
  std::string defaultStringValue;
  if (hasDefaultValue) {
    const pxr::VtValue defaultValue = attrSpec->GetDefaultValue();
    if (defaultValue.IsHolding<std::string>()) {
      defaultStringValue = defaultValue.UncheckedGet<std::string>();
    } else if (defaultValue.IsHolding<pxr::TfToken>()) {
      defaultStringValue = defaultValue.UncheckedGet<pxr::TfToken>().GetString();
    } else {
      hasDefaultValue = false;
    }
  }

  owner->RemoveProperty(attrSpec);
  if (layer->GetAttributeAtPath(attrPath)) {
    return false;
  }

  pxr::SdfAttributeSpecHandle rewritten = pxr::SdfAttributeSpec::New(
      owner,
      attrPath.GetName(),
      pxr::SdfValueTypeNames->String,
      variability,
      isCustom);
  if (!rewritten) {
    return false;
  }

  if (hasDefaultValue) {
    rewritten->SetDefaultValue(pxr::VtValue(defaultStringValue));
  }

  return true;
}

int RewriteAllTokenAttributeSpecsToString(const USD::SdfLayerHandle &layer,
                                          const std::string &propertyName) {
  if (!layer || propertyName.empty()) {
    return 0;
  }

  const pxr::TfToken propertyToken(propertyName);
  std::vector<pxr::SdfPath> pathsToRewrite;
  layer->Traverse(pxr::SdfPath::AbsoluteRootPath(),
                  [&](const pxr::SdfPath &path) {
                    if (!path.IsPropertyPath()) {
                      return;
                    }
                    if (path.GetNameToken() != propertyToken) {
                      return;
                    }

                    const pxr::SdfAttributeSpecHandle attrSpec =
                        layer->GetAttributeAtPath(path);
                    if (!attrSpec) {
                      return;
                    }
                    if (attrSpec->GetTypeName() != pxr::SdfValueTypeNames->Token) {
                      return;
                    }

                    pathsToRewrite.push_back(path);
                  });

  int rewrittenCount = 0;
  for (const pxr::SdfPath &path : pathsToRewrite) {
    if (RewriteAttributeSpecTypeToString(layer, path)) {
      ++rewrittenCount;
    }
  }

  return rewrittenCount;
}
} // namespace USDInterop
