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

## Two-tier model (short)

- **Tier 1: USDInterop (C ABI + tiny Swift wrapper)**
  - Use in lightweight libraries and shared modules.
  - Exposes a narrow, stable C interface (see `USDInteropCxx.h`).
  - Keeps Swift/C++ interop localized and predictable.
- **Tier 2: App-local SwiftUsd interop**
  - Use only inside an app-specific interop module/target.
  - Import `OpenUSD` directly only here.
  - Never leak C++ types across module boundaries.
- **Interface layer: USDInterfaces (pure Swift)**
  - Protocols + DTOs for shared code.
  - Lets libraries depend on USD behavior without pulling in SwiftUsd.
- **Optional: USDInteropAdvanced (consolidated Tier 2)**
  - Shared advanced operations, but only apps should depend on it.
  - Never a dependency of shared libraries.

## How to use

- Depend on `USDInterop` instead of `SwiftUsd` directly.
- Only interop-facing modules should import `USDInterop`.
- Higher-level modules should depend on pure-Swift interfaces (clients,
  value types) defined elsewhere.
- Prefer `USDInterfaces` for shared protocols and DTOs.
- If you need advanced OpenUSD operations, create an app-local interop
  target and keep `OpenUSD` imports confined there.

## Notes

- This target enables Swift C++ interop and disables cross-module optimization
  in Release to avoid known Swift/Clang deserialization issues.
- Keep C++ symbols and OpenUSD types out of public APIs whenever possible.
