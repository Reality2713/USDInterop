# USDInterop

Small shim package that isolates Swift <-> OpenUSD (C++) interop behind a
single target. The goal is to keep C++ types out of most Swift modules,
avoid Swift module deserialization issues in Release, and keep build settings
consistent across the app and tools.

## Why this exists

- OpenUSD Swift bindings use C++ interop and can inject C++ types into
  Swift modules. This can cause Release-only build failures and module
  deserialization crashes when those types leak into public APIs.
- By routing OpenUSD access through USDInterop (and higher-level wrappers),
  we keep most modules pure Swift and reduce build fragility.

## How to use

- Depend on `USDInterop` instead of `SwiftUsd` directly.
- Only interop-facing modules should import `USDInterop`.
- Higher-level modules should depend on pure-Swift interfaces (clients,
  value types) defined elsewhere.

## Notes

- This target enables Swift C++ interop and disables cross-module optimization
  in Release to avoid known Swift/Clang deserialization issues.
- Keep C++ symbols and OpenUSD types out of public APIs whenever possible.

