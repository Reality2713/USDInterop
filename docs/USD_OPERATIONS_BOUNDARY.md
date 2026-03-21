# USDOperations Boundary

## Goal

Keep one clean public package family for Swift/C++ interop plus generic USD scene operations, while preserving a separate private layer for product-value workflows.

## Public Layer

The public `USDInterop` package family owns:

- `USDInterfaces`
- `USDInteropCxx`
- `USDInterop`
- `USDOperations`

### `USDOperations` belongs here when the API is:

- generic
- reusable across consumers
- required by the open/editor consumer path
- expressible as typed scene read/write behavior

Examples:

- read stage metadata
- export USDA
- inspect prim attributes
- read/write transforms
- read/write references
- read/write variants
- read/write material bindings
- create/delete prims

## Private Layer

`USDTools` owns the high-value workflow layer.

Examples:

- validation execution
- diagnostics heuristics
- repair and surgery
- texture conversion/export
- USDZ packaging
- plugin conversion/orchestration
- session workflows
- performance/caching-oriented tooling

## Decision Rule

Do not move something to `USDOperations` because it is generic in theory.

Move it only if it is both:

1. generic enough to be a stable public scene operation
2. necessary for a real public consumer path

If only `Preflight` needs it, keep it in `USDTools` unless there is a deliberate business and maintenance reason to open it.

## Consumer Shape

- `Deconstructed` should depend on the public `USDInterop` package family for its open build path
- `Preflight` may depend on both `USDOperations` and `USDTools`
- app/features should not bypass this boundary with ad hoc low-level interop

## Cross-Repo Context

The broader evaluation of this split and the release-hardening checklist currently live in the `Deconstructed` repo:

- `Docs/USDOperations-Refactor-Evaluation.md`
- `Docs/USDOperations-Release-Checklist.md`
