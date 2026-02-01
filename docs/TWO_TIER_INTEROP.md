# Two-tier USD interop model

This repo is the **Tier 1** interop layer. Tier 2 is **app-local SwiftUsd**.
The goal is to prevent cross-package C++ interop leakage that causes fragile
builds and Release-only deserialization failures.

## Quick Decision Flowchart

```
┌─────────────────────────────────────────────────────────────┐
│  Do I need USD functionality in my code?                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │  Is this a SHARED LIBRARY?  │
              │  (used by multiple apps)    │
              └─────────────┬───────────────┘
                            │
           ┌────────────────┼────────────────┐
           │ YES            │                │ NO (app target)
           ▼                │                ▼
┌──────────────────────┐    │    ┌─────────────────────────────┐
│  Use TIER 1 only:    │    │    │  Can use TIER 2:            │
│  • USDInterfaces     │    │    │  • USDInteropAdvanced       │
│  • USDInterop (C API)│    │    │  • Direct OpenUSD if needed │
└──────────────────────┘    │    └─────────────────────────────┘
           │                │
           ▼                │
┌──────────────────────────────────────────────────────────────┐
│  Does Tier 1 C API have what I need?                         │
│  (bounds, scene graph, USDA export)                          │
└───────────────────────────┬──────────────────────────────────┘
                            │
           ┌────────────────┼────────────────┐
           │ YES            │                │ NO
           ▼                │                ▼
   ┌───────────────┐        │    ┌─────────────────────────────┐
   │  Use it!      │        │    │  ADD a new C API function   │
   └───────────────┘        │    │  to USDInteropCxx           │
                            │    └─────────────────────────────┘
```

## Definitions

**Tier 1 (USDInterop):**
- C ABI in `USDInteropCxx` with a thin Swift wrapper in `USDInterop`.
- Intended for shared libraries and lightweight dependencies.
- Stable, narrow surface area.
- Current API: `sceneBounds`, `exportUSDA`, `sceneGraphJSON`

**Tier 2 (USDInteropAdvanced):**
- Depends on `OpenUSD` (SwiftUsd) directly.
- Contains advanced OpenUSD operations (UsdGeom, Sdf, validation, surgery).
- Must not be depended on by shared libraries.
- Rich API: inspection, validation, surgery, variant combining, session export

**Interface layer (USDInterfaces):**
- Pure Swift protocols + DTOs for shared libraries.
- Lets shared code depend on USD behavior without importing `OpenUSD`.
- ~25 types: `USDStageMetadata`, `USDPrimTreeNode`, `USDValidationOutput`, etc.

## Rules (hard)

- Shared libraries must **not** import `OpenUSD` or `SwiftUsd`.
- C++ types must **not** appear in public APIs outside the app-local interop.
- If a shared library needs USD data, use Tier 1 APIs or add a new C ABI
  function to USDInterop.
- If a feature truly requires advanced OpenUSD, implement it **only** in the
  app-local interop target or use `USDInteropAdvanced` in app targets.
- Shared libraries should depend on `USDInterfaces` for reusable protocols.

## Decision checklist for changes

1. Is this needed by multiple apps or shared libs?
   - Yes -> Tier 1 only.
2. Can it be expressed using existing USDInterop APIs?
   - Yes -> use them.
3. If not, can a minimal C ABI function be added safely?
   - Yes -> add to `USDInteropCxx` + Swift wrapper.
4. Only if it requires advanced OpenUSD APIs:
   - Keep it in the app-local interop target or `USDInteropAdvanced`.

## Examples

**Good:**
- A shared library calls `USDInteropStage.sceneBounds(...)` to get bounds.
- A shared library requests a new C ABI function for a small USD query.

**Not allowed:**
- A shared library imports `OpenUSD` to traverse prims or edit layers.
- A shared library exposes `OpenUSD.pxr` types in its public API.

## Extending Tier 1

When adding a new Tier 1 capability:
- Add a C ABI function in `Sources/USDInteropCxx/include/USDInteropCxx.h`.
- Implement it in `Sources/USDInteropCxx/USDInteropCxx.cpp`.
- Add a thin Swift wrapper in `Sources/USDInterop/USDInterop.swift`.
- Keep arguments and returns C-friendly (numbers, plain structs, C strings).

## Extending Tier 2

When adding a new advanced operation:
- Add the method to `USDAdvancedClient` or an appropriate extension file.
- Use only types from `USDInterfaces` in the public signature.
- Add any new error cases to `USDAdvancedError`.
- Keep `OpenUSD` imports confined to the implementation.

## Creating/maintaining app-local interop

Each app should have a dedicated target/module (e.g. `MyAppUSDInterop`) that:
- Imports `OpenUSD` directly.
- Implements advanced USD operations.
- Exposes only Swift-safe value types or app-specific client APIs.

If you are about to move C++ logic into Swift and it requires `OpenUSD` inside
a shared library, stop and either keep it in C++ (Tier 1) or move the logic
into the app-local interop target (Tier 2).
