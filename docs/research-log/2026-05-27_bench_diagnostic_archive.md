# bench/ + diagnostic/ archive — 2026-05-27

> **FROZEN 2026-05-27.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

`scripts/bench/` and `scripts/diagnostic/` are retired. Each file there
was a one-shot research probe — printed measurements + findings to
stdout, no `@test` blocks, no regression contract. Per the architectural
refactor (anko, 2026-05-27): forensic snapshots belong in `docs/` or
in git history, not in a directory the reader mistakes for live code.

What follows is the catalog. Each entry's *purpose* was originally
documented in the corresponding `docs/design/integrator_*.md` design
note (see "Anchor" column). To recover the code for any entry, use
`git log -- scripts/<dir>/<file>.jl` — the canonical pre-retirement
commit is `04d9c9a` (bench/) / `df1afa2` (diagnostic/).

## scripts/bench/ (26 entries)

| File | Purpose | Anchor |
|---|---|---|
| `avf_drift_phase5_smoke.jl` | AVF drift smoke probe at Phase 5 | `docs/design/integrator_ch3_plan.md` |
| `backend_grid_scan.jl` | Backend × grid recommendation table (feeds `recommend_backend_dtype`) | `src/workflow/io/budget.jl` |
| `bench_overnight.jl` | R32–R39 overnight integrated bench orchestrator | (orchestrator only) |
| `cuda_graph_rotating.jl` | `split_step_rotating!` plain vs `CUDA.@captured` speedup | (turn-50 audit) |
| `eu151_order_phase2b.jl` | Eu151 F=6 order-of-accuracy at Phase 2b | `docs/manuscript/thesis/appendices/AppendixB_spinorbec_api.md` |
| `forcegrad_phase5.jl` | Force-gradient validation at Phase 5 | `docs/design/integrator_ch3_5_narrative.md` |
| `forcegrad_smoke.jl` | Force-gradient smoke probe | `docs/design/integrator_track_c_derivation.md` |
| `itp_profile.jl` | ITP runtime profile (FFT vs spin-mixing vs DDI breakdown) | `docs/design/integrator_ch3_8_narrative.md` |
| `jit_baseline.jl` | JIT + cascade cost baseline (was `scripts/diag/`) | `src/foundation/types/workspace.jl` |
| `midpoint_order_phase2a.jl` | Midpoint-rule order at Phase 2a | `docs/design/integrator_ch3_plan.md` |
| `mps4_lab_diagnostic.jl` | Lab-path MPS-4 diagnostic (Track A wrap-up) | `docs/design/integrator_ch3_plan.md` |
| `mps_smoke.jl` | Chin–Geiser Multi-Product Splitting smoke test | `docs/design/integrator_modernization_plan.md` |
| `tdhfb_eu_production.jl` | TDHFB Eu F=6 post-quench, Phase 6 deliverable | `docs/manuscript/figures_data/tdhfb_eu_F6_T0.4_2026-05-12.md` |
| `track_a22_mps_pareto.jl` | A2.2 Pareto: MPS-{4,6,8} vs Y4/Y6/Strang-mid at Phase 2a | `docs/design/integrator_architecture_completion_plan.md` |
| `track_a3_adaptive_burst.jl` | A3 adaptive on multi-scale near-instability problem | same |
| `track_a3_adaptive_y4mid.jl` | A3 adaptive timestep control via Hairer–Wanner defect | `src/hamiltonian/integrator/adaptive.jl` |
| `track_a3_eu_postquench.jl` | A3 production validation on Eu151 F=6 post-quench | `docs/design/integrator_architecture_completion_plan.md` |
| `track_c_v4_a11_alpha_sweep.jl` | Track C v4 A1.1 α-sweep | same |
| `track_c_v4_a11_chin4A.jl` | Track C v4 A1.1 Chin–Krotscheck 4A composition | same |
| `track_c_v4_step1a_smoke.jl` | Track C v4 1a smoke (multiplicative terms, F=1) | same |
| `track_c_v4_step1b_palindrome.jl` | Track C v4 1b analytical Strang + palindromic gate | same |
| `track_c_v4_step1c_direct.jl` | Track C v4 1c direct discrete commutator | same |
| `track_c_v4_step1d_order.jl` | Track C v4 1d lab-path order test | same |
| `trap_picard_diag.jl` | Trap + Picard iteration diagnostic | (Phase-2a follow-up) |

## scripts/diagnostic/ (10 entries)

| File | Purpose | Anchor |
|---|---|---|
| `T_sweep_alpha0.jl` | Falsifier: phase accumulation slope at α=0 | `docs/design/integrator_order_mechanism_tdhfb.md` |
| `asymmetry_probe.jl` | B-3 substep generator asymmetry probe | same |
| `intermediate_delta_sweep.jl` | B-3 intermediate-Δ falsifier | same |
| `klaus_bch_leak_verification.jl` | T57 fast-Larmor BCH-leak verification | `runs/_loop/judge/turn_57.json` (archived) |
| `matsui_edh_t82_analyze.jl` | T82 Matsui EdH analyzer | `runs/_loop/judge/turn_82.json` (archived) |
| `order_ladder_full_matrix.jl` | B-2 extended 4×3 order ladder | `docs/design/integrator_order_mechanism_tdhfb.md` |
| `palindrome_residual_probe.jl` | B-1 palindrome residual probe | same |
| `tdhfb_f1_bogoliubov_cross_check.jl` | T100 TDHFB F1/F2/F3 falsifiers + F4 advisory | `runs/_loop/regression/turn_100.expected.json` (archived) |
| `tdhfb_palindromic_gate.jl` | TDHFB Y4 palindromic-gate diagnostic (#86 Option B) | `docs/design/tdhfb_y4_palindromic_substep_design.md` |
| `tdhfb_per_term_audit.jl` | Per-term FD audit (δE_piece / δφ*) | `docs/manuscript/thesis/chapters/ch5_v3_raw.md` |

## Recovering the code

```bash
# Single file:
git show 04d9c9a:scripts/bench/forcegrad_phase5.jl > /tmp/forcegrad_phase5.jl

# Full directory listing at retirement:
git show 04d9c9a --stat -- scripts/bench/ | head
git show df1afa2 --stat -- scripts/diagnostic/ | head
```

If a probe needs to become a regression test, wrap it in `@testset`
with explicit pass thresholds and add to `test/benchmark/` (FAST_TESTS
or CI_EXTRA tier as appropriate).
