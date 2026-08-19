# 12h Thesis Batch Audit — 2026-04-28

> **FROZEN 2026-04-28.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

24 production runs + 6 audit follow-up runs. Conservation laws, anomaly investigation, and a thesis-affecting numerical finding.

## Conservation laws — all clean

- **Norm**: max deviation across all 30 runs is 6.2e-10 (Yoshida6 unitary).
- **Lz, Fz**: bounded, no instability.

## Anomaly inventory and resolution

### `p_3000` ε=1e-3 → catastrophic depolarisation (NUMERICAL ARTIFACT)

| | ε=1e-3 (original) | ε=1e-6 (validation) |
|---|---|---|
| pm_init  | 0.997 | 0.999 |
| pm_final | **0.106** (full thermal scrambling) | **0.999** (frozen) |
| Fz drift | -5.22 | +0.0003 |

Final m-spectrum at ε=1e-3 is uniform across all 13 m levels (`[0.106, 0.094, 0.094, 0.088, …]`) — equipartition. At ε=1e-6 it stays in m=+F.

**Conclusion**: ε=1e-3 was insufficient at p=3000. The Y6 ε-formula `dt = 0.1 · (ε / T)^(1/6)` assumes commutator scales of O(1), but for fast-Larmor p · F · dt the leading 6-fold splitting commutator has scale ∝ pᵏ for some k > 0 — the safety prefactor 0.1 is empirically too lax.

### `p_10000` initial state spreading (also NUMERICAL)

| | ε=1e-3 | ε=1e-6 |
|---|---|---|
| pm at start of stir | 0.565 | 0.586 |
| pm at end of stir   | 0.615 | 0.644 |

NOTE: this is *not* a GS quality bug — `pm_init` reported by the launcher is the population at the **start of the steady-stir phase** (= end of ramp + chirp). The lower number reflects more chirp-driven depolarisation at higher p, not failed ITP. ε=1e-6 gives slightly different values (within ~5 %); the original ε=1e-3 result is *qualitatively* OK at p=10000 (unlike p=3000 where it failed catastrophically), but quantitatively biased.

### `grid_48cube` initial state spreading (RESOLUTION-DEPENDENT)

| | grid 24×24×12 | grid 48×48×24 |
|---|---|---|
| pm at start of stir | 0.768 | 0.378 |
| pm at end of stir   | 0.877 | 0.522 |

Higher resolution shows **more** chirp-driven depolarisation. This is real physics: 24³ under-resolved the high-frequency Berry kick. The 48³ result is closer to the converged answer. Long-ITP (n_steps=1500) re-run gave 0.376 → 0.522, confirming this is *not* an ITP convergence issue.

### `dy164_main_500ms` Dy-frozen result

ε=1e-3 gave m=+F: 0.9999 → 0.9999. ε=1e-6 in flight (in-progress at audit-write time). Dy164 has p=28428, so larmor_phase_per_step at ε=1e-3 is 28428 × 8 × 0.0158 ≈ 3592 — far above π. The frozen result *may* be physical (Dy F=8 is in deeper adiabatic regime than Eu F=6) but needs ε=1e-6 confirmation.

## Numerical regime classification

| run | p | dt (ε=1e-3) | p·F·dt | ε=1e-3 status |
|---|---|---|---|---|
| p_30 | 30 | 0.018 | 3.2 | OK (0.977→0.933, mild physics) |
| p_100 | 100 | 0.018 | 11 | OK (0.998→0.998 frozen) |
| p_300 | 300 | 0.018 | 32 | OK (0.988→0.994, marginal) |
| p_1000 | 1000 | 0.018 | 108 | OK (1.0→1.0 frozen) |
| **p_3000** | 3000 | 0.018 | 324 | **BROKEN** (0.997→0.106) |
| p_10000 | 10000 | 0.018 | 1080 | quantitatively biased |
| dy164_main | 28428 | 0.018 | ~3600 | frozen (TBD if physical) |

The threshold sits somewhere in p·F·dt ∈ [108, 324]. ε=1e-6 brings dt down to ~0.005 (3× smaller), pushing all of these except dy164 into nominally safe regime.

## Software response

1. **`pipeline_runner.jl` Larmor guard warning**: `_run_rotating_basis_dynamics_inner` now warns when `p·F·dt > π` at YAML load, citing this audit.
2. **dt + integrator metadata in dynamics_result**: `:dt_used`, `:integrator`, `:epsilon_target`, `:p_zeeman`, `:F_atom`, `:larmor_phase_per_step` are now saved per-phase. Future audit can read these without re-loading YAML.
3. **Open instrumentation suggestions** (deferred):
   - Independent ε=1e-6 reference comparison at run end (auto-flag drift)
   - `dt_history` dump for adaptive controllers (when adaptive is added)

## Recommendations

### For thesis figures

- **Re-run all 6 high-p configs (p_3000, p_10000, dy164_main and any others with p·F·dt > 100) at ε=1e-6.** The 24×24×12 grid is fine. Cost: 3-5h wall clock at 3-parallel.
- **Re-run the entire 48³ grid_48cube at ε=1e-6 with longer duration** for the grid-convergence figure (currently shows quantitative diff vs 24³ but without enough duration to show stir-phase saturation).

### For B-1 phase scan

- **Default ε for B-1 should be 1e-6**, not 1e-3. Cost increase is 3× (Y6 dt scales as ε^(1/6)), well within the run budget.
- **rotating_basis is mandatory** for any run with p·F > O(10²). The rotating-basis solver folds the dominant -p·F_z into an eigen-exact spin step; remaining errors come from non-commutativity with DDI / kinetic, which the Larmor guard now flags.

### Open questions for future audit

- Does the Y6 ε prefactor 0.1 scale as p^(-k/6)? Empirical bisection between ε=1e-3 and 1e-6 at p=3000 would pin k.
- Is the BM-S6 adaptive integrator (in `embedded_adaptive.jl`) similarly affected? The reviewer's "embedded estimator false convergence" hypothesis applies *there* but not to the fixed-dt Y6 used in thesis_batch.
