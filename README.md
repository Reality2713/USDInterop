# USDInterop

Small shim package that isolates Swift <-> OpenUSD (C++) interop behind a
single target. The goal is to keep C++ types out of most Swift modules,
avoid Swift module deserialization issues in Release, and keep build settings
consistent across the app and tools.

USDInterop is the **Tier 1** of a two-tier interop model. Tier 2 (advanced
SwiftUsd usage) must live inside each app, not in shared libraries.

`USDInterfaces` is a pure-Swift companion module that defines reusable
protocols and DTOs for shared libraries.
`USDInteropAdvanced` is the consolidated Tier 2 package (app-only), if you
choose to reuse advanced operations across apps.

See `docs/TWO_TIER_INTEROP.md` for the full rules, decision checklist, and
examples.

## Why this exists

- OpenUSD Swift bindings use C++ interop and can inject C++ types into
  Swift modules. This can cause Release-only build failures and module
  deserialization crashes when those types leak into public APIs.
- By routing OpenUSD access through USDInterop (and higher-level wrappers),
  we keep most modules pure Swift and reduce build fragility.

## Two-tier model

```
┌────────────────────────────────────────────────────────────────────┐
│                    TIER 1: USDInterop (This Package)               │
│   For: Minimal USD queries without full SwiftUsd overhead          │
├────────────────────────────────────────────────────────────────────┤
│  USDInterfaces/        Pure Swift DTOs (no OpenUSD dependency)     │
│  USDInteropCxx/        C++ wrappers via C ABI                      │
│  USDInterop/           Thin Swift wrappers for C API               │
│                                                                     │
│  Current C API surface:                                             │
│    • usdinterop_export_usda()     - Export stage as USDA text      │
│    • usdinterop_scene_graph_json() - Get prim hierarchy as JSON    │
│    • usdinterop_scene_bounds()    - Compute world bounds           │
│                                                                     │
│  Use when:                                                          │
│    ✓ Shared libraries need basic USD queries                       │
│    ✓ QuickLook extensions or XPC services                          │
│    ✓ Targets that cannot pay the C++ interop compile cost          │
│    ✓ You want absolute minimal OpenUSD exposure                    │
└────────────────────────────────────────────────────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│             TIER 2: USDInteropAdvanced (Separate Package)          │
│   For: Full-featured USD operations with SwiftUsd                  │
├────────────────────────────────────────────────────────────────────┤
│  USDAdvancedClient     - High-level operations facade              │
│  USDAdvancedInspection - Validation, statistics, introspection     │
│  USDAdvancedSurgery    - USD editing (scale, axis, materials, etc) │
│  USDAdvancedSession*   - Session layer and export workflows        │
│  AppleUSDSchemasUSD    - RealityKit schema support                 │
│                                                                     │
│  Use when:                                                          │
│    ✓ App-level targets (not shared libraries)                      │
│    ✓ Need prim traversal, validation, or editing                   │
│    ✓ Need variant/material/animation surgery                        │
│    ✓ Need full UsdGeom, UsdShade, UsdSkel APIs                     │
└────────────────────────────────────────────────────────────────────┘
```

### When to use which layer

| Scenario | Use |
|----------|-----|
| Shared library needs USD file bounds | **Tier 1** C API |
| App needs to validate USD for RealityKit | **Tier 2** Advanced |
| QuickLook extension needs prim list | **Tier 1** C API |
| App needs to apply skeleton remapping | **Tier 2** Advanced |
| New shared library needs USD metadata | **Tier 1** (add C API if needed) |
| App needs to combine variants into USDZ | **Tier 2** Advanced |

### Adding new Tier 1 capabilities

If a shared library needs a USD capability not in the C API:

1. Add a C function in `Sources/USDInteropCxx/include/USDInteropCxx.h`
2. Implement in `Sources/USDInteropCxx/USDInteropCxx.cpp`
3. Add Swift wrapper in `Sources/USDInterop/USDInterop.swift`
4. Keep arguments C-friendly (numbers, plain structs, C strings)

Do **not** add SwiftUsd imports to this package.

## How to use

- Depend on `USDInterop` instead of `SwiftUsd` directly.
- Only interop-facing modules should import `USDInterop`.
- Higher-level modules should depend on pure-Swift interfaces (clients,
  value types) defined elsewhere.
- Prefer `USDInterfaces` for shared protocols and DTOs.
- If you need advanced OpenUSD operations, depend on `USDInteropAdvanced`
  (app targets only).

## Notes

- This target enables Swift C++ interop and disables cross-module optimization
  in Release to avoid known Swift/Clang deserialization issues.
- Keep C++ symbols and OpenUSD types out of public APIs whenever possible.
