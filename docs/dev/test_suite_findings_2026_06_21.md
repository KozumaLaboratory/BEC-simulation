# Test-suite audit findings (2026-06-21)

> **FROZEN 2026-06-21.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Surfaced while adding the parallel test runner + optimising the full tier.
Records what was fixed and what remains open (with enough detail to resume).

## Fixed

- **Parallel runner** (`SPINORBEC_TEST_WORKERS=N|auto`): files split into N
  independent julia processes (`run_chunk.jl`), LPT-balanced by a measured
  `_COST` table, aggregated by exit code. Per-chunk `SPINORBEC_TEST_TIMEOUT`
  (default 1800 s) kills a hung chunk. Serial and parallel share one
  run/fail/timing path (`_run_files.jl`). fast 204 s → ~90 s; full 846 s →
  ~450 s (~1.9×, JIT-duplication + BO pole bound).
- **Latent stdlib leaks**: many test files used `norm`/`I`/`MersenneTwister`/…
  with no import and only passed because the serial runner leaked them between
  files. A standard preamble in `_run_files.jl` (LinearAlgebra/Random/
  Statistics/Printf) is the shared environment contract; chunk-safe now.
- **`test_path_coverage.jl`**: scraped `runtests.jl` for the tier list, which
  moved to `_tiers.jl` — now reads `_tiers.jl`.
- **3 silently-red full-tier files** (stale signatures, never updated because
  full is nightly-only): `propagator_references` `_update_batched_kinetic_phase!`
  (missing `imaginary_time` arg), `make_scalar_ws` `dt=` (×3 files, never a
  kwarg), `EnergyContext.dV` Float32 under mixed precision.

## Open — need a domain owner / a GPU machine

### A. CUDA should be a weakdep (deferred — Manifest hazard)
`CUDA` is in `[deps]` but every src `CUDA.` reference is a comment and
`[extensions]` already declares `SpinorBECCUDAExt = "CUDA"` — it is purely an
extension trigger and belongs in `[weakdeps]`. Moving it makes `using
SpinorBEC` stop force-loading CUDA (which segfaults the precompiler on a WSL2
box whose GPU-driver probe crashes). **Attempted and reverted**: after the
Project edit, `Pkg.resolve()` PRUNED CUDA + ~40 transitive deps from the
Manifest (123 → 83), which would break `import CUDA` / the GPU path / nightly
GPU tests. Redo on a machine that can run CUDA's `Pkg` operations and verify
`import CUDA` + a `CUDABackend()` run still work before committing the Manifest.

### B. Pre-existing full-tier failures (physics/numeric — not mechanical)
These fail identically in serial and parallel and predate this work; the full
tier is nightly-only so they drifted unnoticed. Each needs a domain look:
- `oracles/test_propagator_references.jl` (Strang-slope testsets): production
  Strang vs the dumb-RK4 reference differ by a **dt-independent constant**
  (slope ≈ 0, err ≈ 0.096) — a term/composition discrepancy the oracle is
  flagging (the per-term dt-valley gates pass, so it is a full-sandwich issue).
- `analysis/test_spatial_zeeman.jl`: "uniform limit ≡ ZeemanTerm
  (bit-identical)" off by 0.083 — the spatial-Zeeman propagator
  (`-bx,-by,-bz` Euler) and the unified `ZeemanTerm` diverge. **Treat as a
  sign/convention bug and resolve with the directional oracle** (which path
  makes `+Bx ⇒ ⟨F_x⟩ > 0`), per the Hamiltonian sign-bug-proof discipline — do
  NOT guess. May share a root with the Strang-slope discrepancy.
- `gpu/test_mixed_precision{,_phase3}.jl`: F32 vs F64 ITP energy off by **8.8 %**
  (not FP noise) — a real F32-accuracy gap, now that the EnergyContext
  constructor fix lets the path run.
- `test_level4_general_F_phase_emergence.jl`: analytic gap `(c₁/2)F²∫n²` vs
  measured off ~24 % at **F=6, F=8 only** (F=1,2,3 pass) — the leading-order
  formula degrades at high F. Decide whether the rtol (0.15) is simply too
  tight there or there is a real discrepancy.

### C. Coverage / gating gaps
- **Nightly is unwatched.** The full tier runs only nightly and went red
  without anyone noticing (the B items). Add a failure signal (e.g. open/update
  a tracking Issue via the built-in `GITHUB_TOKEN`, or wire `notify_slack`).
- **`ExplicitImports` only checks `src/`**, which is why the test-file import
  leaks went undetected. It operates on modules, not script files, so it can't
  be pointed at `test/` directly; the `_run_files.jl` preamble is the
  pragmatic guard instead.
- **C-layer (model fidelity) isn't running.** `workflow/test_klaus_validation.jl`
  sits in `MANUAL_TESTS_ALLOWLIST` as "pending schema audit" — the published-
  data comparison is not gated anywhere.
- `test_quality.jl`: `check_no_implicit_imports` is `@test_broken` (≈50 implicit
  `using X` in `src/`); JET is default-skipped (>1 h).
