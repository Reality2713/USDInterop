# USDInterop

This repository owns the public OpenUSD interop boundary.

## Purpose

- `USDInterfaces`: shared pure-Swift DTOs and contract types
- `USDInteropCxx`: C++ bridge layer
- `USDInterop`: low-level Swift-facing interop helpers
- `USDOperations`: public generic scene operations for app consumers

## Boundary Rule

`USDOperations` is for generic USD scene operations only:

- stage metadata
- scene graph and bounds
- prim inspection
- transforms
- references
- variants
- material bindings
- create/delete prims

It must not become a home for:

- validation workflows
- diagnostics heuristics
- texture conversion
- USDZ packaging
- plugin orchestration
- repair/surgery pipelines
- app-specific authoring logic

Those belong in `USDTools`.

## Canonical Boundary Doc

See `docs/USD_OPERATIONS_BOUNDARY.md`.

## Cross-Repo Context

The broader rationale and release evaluation for this split live in the `Deconstructed` repo:

- `Docs/USDOperations-Refactor-Evaluation.md`
- `Docs/USDOperations-Release-Checklist.md`
