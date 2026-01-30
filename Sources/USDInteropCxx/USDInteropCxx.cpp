#include "USDInteropCxx.h"

#include "pxr/pxr.h"
#include "pxr/usd/usd/prim.h"
#include "pxr/usd/usd/stage.h"

#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <string>
#include <vector>

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
