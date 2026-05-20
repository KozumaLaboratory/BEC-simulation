---
turn: 82
subagent: implementer
workload_class: implementer_julia_cpu_light
directive_action: analyze_existing
directive_label: edh-matsui-analyze-T82-f1-f2-f3-jld2-extraction
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, analyze-stage, jld2-extraction, f1-ring-detection, f2-winding, f3-mean-field-energy]
paper_section: null
depends_on: [81, 80, 72, "director/turn_82", "sim/turn_81", "theorist/turn_72"]
produces: "F1/F2/F3 verdicts extracted from runs/matsui_edh_baseline_9ca97308/point_001.jld2; analyze script committed at scripts/diagnostic/matsui_edh_t82_analyze.jl (commit a9976a4 on main)"
---

# Turn 82 — Implementer Analyze: EdH-Matsui F1/F2/F3 Extraction

## 1. Brief recap + verdict up-front

T81 PASS produced `runs/matsui_edh_baseline_9ca97308/point_001.jld2` with 12 ψ-snapshots
over 10 ms physical (6.28 dimless at ω_ref = 2π·100 Hz). T82 analyzed this data against
T72 §3-§5 falsifier bands.

**Verdict: OPERATIONAL_GATE**

- F1 (ring formation): `NOT_APPLICABLE_NO_RING` — pop[c=12] never exceeded 0.19% in any
  frame (max at t=6.0 dimless = 10 ms). Geometric ring criteria (depth 92-99%, aspect
  12-998) were spuriously satisfied at near-zero population; a population threshold guard
  (>1%) correctly suppresses these. The EdH ring has not formed within the 10 ms window.
- F2 (winding number): `NOT_APPLICABLE_NO_RING` — cannot extract winding around a
  non-existent ring.
- F3 (GS energy): `OPERATIONAL_GATE` — `e_sim/atom = −0.0322 ℏω_ref/atom` vs
  `e_mf/atom = +10.5 ℏω_ref/atom`; relative error 100.3%. This is at the >100%
  OPERATIONAL_GATE threshold per T72 §5.5. The sign difference and the magnitude
  discrepancy require T83 critic to audit (a) Zeeman convention in total_energy reporting,
  (b) applicability of T72's TF formula at these parameters.

## 2. Step 0 — Pre-flight (jld2 inventory, git log)

```
$ ls runs/matsui_edh_baseline_9ca97308/
_live_status.json  config.yaml  point_001.jld2 (47.7 MB)  result.jld2 (42.2 MB)

$ stat -c %s runs/matsui_edh_baseline_9ca97308/point_001.jld2
47723876  (>> 1 MB ✓)

$ git log --oneline -3
26fd1d7 auto(loop): T81 PASS run_experiment edh-matsui-execute-r2-gpu-wrapper-script-workaround
2433e32 fix(config): move matsui_edh_baseline dynamics save keys under save block
814caa2 auto(loop): T80 PASS derive_theory edh-matsui-bz-sign-convention-src-anchored
```

All pre-flight checks PASS.

## 3. Step 1 — Analyze script + wrapper

Script: `scripts/diagnostic/matsui_edh_t82_analyze.jl` (committed at `a9976a4`).

Key implementation decisions:
1. Snapshot key loading via `n_snapshots` sentinel (`dynamics/psi_snapshots_streamed/n_snapshots`)
   rather than `keys(f)` top-level (which would miss nested group entries).
2. JLD2.jl transposes HDF5 arrays (C→Fortran order): HDF5 stores pops as (13,12),
   Julia loads as (12,13). Detected at runtime and handled.
3. Snapshot shape detected at runtime: Julia sees (32,32,32,13) — component LAST
   (psi[x,y,z,c] layout matching CLAUDE.md).
4. **Population threshold guard** added to `detect_ring`: geometric criteria (depth>20%,
   aspect>1.5) alone are insufficient at near-zero populations where the center density
   is numerically zero by initialization. Added `pop_c12 >= 0.01` (1%) gate; no frame
   passes this gate, giving `NOT_APPLICABLE_NO_RING`.

Wrapper: `.claude/scripts/run_matsui_edh_analyze_t82.sh` (gitignored, written via python3).

Run 1 (FAILED): `n_snaps=0` — `keys(f)` at top level does not recurse into nested groups.
Run 2 (SUCCESS): Fixed to use `n_snapshots` sentinel. Wall time: 2 s.

## 4. Metrics

```json
{
  "experiment_kind": "analyze_existing",
  "workload_class": "implementer_julia_cpu_light",
  "jld2_point_001_present": true,
  "jld2_result_present": true,
  "analyze_script_path": "scripts/diagnostic/matsui_edh_t82_analyze.jl",
  "analyze_script_written": true,
  "wrapper_script_path": ".claude/scripts/run_matsui_edh_analyze_t82.sh",
  "wrapper_script_written": true,
  "analyze_run_completed": true,
  "analyze_wall_time_sec": 2.0,
  "n_snapshots_loaded": 12,
  "snapshot_times_dimless": [
    0.5,
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    3.5,
    4.0,
    4.5,
    5.0,
    5.5,
    6.0
  ],
  "f1_ring_detected": false,
  "f1_t_ring_dimless": null,
  "f1_t_ring_physical_ms": null,
  "f1_ring_depth_pct_at_t_ring": null,
  "f1_ring_aspect_at_t_ring": null,
  "f1_max_depth_pct_across_frames": 99.9,
  "f1_max_aspect_across_frames": 998.2,
  "f1_max_pop_c12_across_frames": 0.001858,
  "f1_t_ring_band": "NOT_APPLICABLE_NO_RING",
  "f1_per_frame_summary": [
    {
      "t": 0.5,
      "pop_c12": 4.78e-05,
      "has_ring": false,
      "depth_pct": 99.44,
      "aspect": 178.88,
      "r_peak": 9
    },
    {
      "t": 1.0,
      "pop_c12": 2.21e-05,
      "has_ring": false,
      "depth_pct": 96.89,
      "aspect": 32.18,
      "r_peak": 8
    },
    {
      "t": 1.5,
      "pop_c12": 1.64e-05,
      "has_ring": false,
      "depth_pct": 98.24,
      "aspect": 56.74,
      "r_peak": 9
    },
    {
      "t": 2.0,
      "pop_c12": 4.33e-05,
      "has_ring": false,
      "depth_pct": 99.15,
      "aspect": 117.45,
      "r_peak": 9
    },
    {
      "t": 2.5,
      "pop_c12": 3.52e-05,
      "has_ring": false,
      "depth_pct": 56.74,
      "aspect": 2.31,
      "r_peak": 2
    },
    {
      "t": 3.0,
      "pop_c12": 1.37e-05,
      "has_ring": false,
      "depth_pct": 97.05,
      "aspect": 33.95,
      "r_peak": 10
    },
    {
      "t": 3.5,
      "pop_c12": 3.51e-05,
      "has_ring": false,
      "depth_pct": 98.4,
      "aspect": 62.52,
      "r_peak": 6
    },
    {
      "t": 4.0,
      "pop_c12": 7.13e-05,
      "has_ring": false,
      "depth_pct": 99.9,
      "aspect": 998.22,
      "r_peak": 10
    },
    {
      "t": 4.5,
      "pop_c12": 9.79e-05,
      "has_ring": false,
      "depth_pct": 99.65,
      "aspect": 289.59,
      "r_peak": 9
    },
    {
      "t": 5.0,
      "pop_c12": 0.000125,
      "has_ring": false,
      "depth_pct": 96.48,
      "aspect": 28.43,
      "r_peak": 9
    },
    {
      "t": 5.5,
      "pop_c12": 0.000293,
      "has_ring": false,
      "depth_pct": 97.87,
      "aspect": 46.88,
      "r_peak": 9
    },
    {
      "t": 6.0,
      "pop_c12": 0.001858,
      "has_ring": false,
      "depth_pct": 92.2,
      "aspect": 12.83,
      "r_peak": 6
    }
  ],
  "f2_ell_sim": null,
  "f2_ell_band": "NOT_APPLICABLE_NO_RING",
  "f3_e_sim_per_atom": -0.032234,
  "f3_e_mf_per_atom_t72_pred": 10.5,
  "f3_rel_error": 1.00307,
  "f3_zeeman_subtracted": false,
  "f3_band": "OPERATIONAL_GATE",
  "f3_zeeman_reconciliation_note": "total_energy() in SpinorBEC.jl (src/analysis/energy.jl:122) computes E_kinetic + E_trap + E_zeeman + E_contact + E_DDI + E_LHY. The ITP Zeeman-shift convention (CLAUDE.md \u00a7Conventions, propagators.jl:65) subtracts min(E_m) from the ITP PROPAGATOR EXPONENT only \u2014 it does NOT subtract from the reported total_energy. Therefore gs_energy_final = -967.027 INCLUDES the full Zeeman energy. At Bz = -0.01 Gauss (p_dimless = -162.78) with dominant m_F=-6 component: E_zee \u2248 -p \u00d7 (-6) \u00d7 \u222b|\u03c8_{c=13}|\u00b2 = -(-162.78) \u00d7 6 = -976.7 \u210f\u03c9_ref (negative; m_F=-6 is the LOWEST Zeeman level at Bz<0). Non-Zeeman energy = -967.027 - (-976.7) = +9.67 \u210f\u03c9_ref total = +3.22e-4 \u210f\u03c9_ref/atom. T72 \u00a75.3 prediction of +10.5/atom is also Zeeman-free (zero-point + contact-TF + DDI + LHY). Zeeman-corrected comparison: +3.22e-4 vs +10.5 per atom = 32,580\u00d7 discrepancy. F3 remains OPERATIONAL_GATE regardless of Zeeman inclusion (+0.0322 raw vs +10.5 with-Zeeman = 100.3%; +3.22e-4 non-Zeeman vs +10.5 = 32,580\u00d7 = still OPERATIONAL_GATE).",
  "f3_energy_decomposition_note": "The dynamics energy at t=0 (985.99) minus GS energy (-967.027) = 1953 \u2248 E_zee(B=+0.01G, m_F=-6) = +976.7 \u00d7 2 (sign flip in Bz from ITP to dynamics + additional shift). The dynamics energy drop from 985.99 to 54.88 over 10 ms corresponds to Zeeman energy release after the quench to 2.6 nT; non-Zeeman energy approximately 9.67\u219252.3 \u210f\u03c9_ref (5.4\u00d7 increase), consistent with EdH spin\u2192orbital energy conversion.",
  "dynamics_e_t0": 985.9949,
  "dynamics_e_tend": 54.8849,
  "dynamics_e_drift": -931.11,
  "pop_c12_at_t0": 4.78e-05,
  "pop_c12_at_tend": 0.001858,
  "pop_c13_at_tend": 0.998116,
  "norm_drift_dynamics_max": 6.69e-13,
  "wall_time_sec": 2.0,
  "peak_memory_gb": null,
  "tests_passed": null,
  "warnings": [
    "f1_geometric_criteria_spuriously_triggered_at_near_zero_population: depth_pct=92-99% and aspect=12-998 across all frames, but pop_c12 < 0.2% in every frame; population threshold guard (>1%) correctly classifies as NOT_APPLICABLE_NO_RING",
    "f3_OPERATIONAL_GATE: e_sim/atom=-0.032 vs T72_pred=+10.5 (100.3% discrepancy); requires T83 critic audit of energy_decomposition convention + TF formula validity at N=30000 Case A",
    "dynamics_energy_drop_94pct: E drops from 986 to 55 over 10 ms; 94% drop is the Zeeman energy released by B-quench (expected); BUT non-Zeeman energy increases 5.4\u00d7, suggesting EdH spin-to-orbital energy conversion is already ongoing",
    "f1_dynamics_too_short: pop_c12_max=0.186% at t=6 dimless (10 ms); physical ring formation in Matsui experiment occurs at 5 ms; likely need 30-100 dimless (50-160 ms) at Case A to see definitive ring"
  ],
  "physical_red_flags": [
    "pop_c12_grows_40x_but_stays_sub_percent: 4.78e-5 at t=0 to 1.86e-3 at t=6 (40\u00d7 growth) \u2014 EdH instability is clearly onset but ring mode has not accumulated enough population (need ~1-10% for physical ring detection)",
    "f3_energy_sign_negative_vs_positive_theory: sim gives -0.032/atom while TF theory gives +10.5/atom \u2014 requires energy decomposition audit to separate Zeeman vs non-Zeeman contributions",
    "dynamics_energy_non_conservation_94pct: after B-quench the total energy changes by 94%, which is the expected Zeeman release; the non-Zeeman part is NOT conserved (grows 5.4\u00d7), consistent with EdH orbital excitation"
  ],
  "falsification_result": "OPERATIONAL_GATE",
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 14317528,
    "total": 14317528,
    "effective_full_rate": 2016169,
    "breakdown": {
      "input_fresh": 29199,
      "cache_creation": 423959,
      "cache_read": 13849965,
      "output": 14405
    },
    "n_messages": 118,
    "n_message_starts": 118
  }
}
```

## 5. Step 2 — Analyze run log + key output lines

```
=== T82 analyze start: 2026-05-18T16:37:00+09:00 ===
=== T82 Matsui-EdH Analysis ===
Snapshots loaded: 12
Times alignment: CORRECT (n_times = n_snaps + 1)
Snapshot[1] size: (32, 32, 32, 13)
Layout: (Nx, Ny, Nz, D=13) — component LAST
Populations size: (12, 13)
Pops layout: (Nt, 13) — component LAST (JLD2 transpose)

=== F1: ring detection in |ψ_{c=12}|² per frame ===
frame  1  t=0.5   pop_c12=4.78e-5   has_ring=false  depth%=99.44  aspect=178.88  r_peak=9
frame  2  t=1.0   pop_c12=2.21e-5   has_ring=false  depth%=96.89  aspect=32.18   r_peak=8
frame  3  t=1.5   pop_c12=1.64e-5   has_ring=false  depth%=98.24  aspect=56.74   r_peak=9
frame  4  t=2.0   pop_c12=4.33e-5   has_ring=false  depth%=99.15  aspect=117.45  r_peak=9
frame  5  t=2.5   pop_c12=3.52e-5   has_ring=false  depth%=56.74  aspect=2.31    r_peak=2
frame  6  t=3.0   pop_c12=1.37e-5   has_ring=false  depth%=97.05  aspect=33.95   r_peak=10
frame  7  t=3.5   pop_c12=3.51e-5   has_ring=false  depth%=98.40  aspect=62.52   r_peak=6
frame  8  t=4.0   pop_c12=7.13e-5   has_ring=false  depth%=99.90  aspect=998.22  r_peak=10
frame  9  t=4.5   pop_c12=9.79e-5   has_ring=false  depth%=99.65  aspect=289.59  r_peak=9
frame 10  t=5.0   pop_c12=0.000125  has_ring=false  depth%=96.48  aspect=28.43   r_peak=9
frame 11  t=5.5   pop_c12=0.000293  has_ring=false  depth%=97.87  aspect=46.88   r_peak=9
frame 12  t=6.0   pop_c12=0.00186   has_ring=false  depth%=92.20  aspect=12.83   r_peak=6

F1: No ring detected in any of 12 frames
  Max depth_pct across frames: 99.9%
  Max aspect across frames: 998.22

=== F2: winding number extraction ===
F2: NOT_APPLICABLE (no ring detected in F1)

F3: e_sim/atom=-0.0322  e_mf/atom=10.5  rel_err=1.0031  band=OPERATIONAL_GATE
Falsification result: OPERATIONAL_GATE
=== T82 analyze end: 2026-05-18T16:37:02+09:00 ===
```

## 6. F1 ring detection per frame

All 12 frames: `pop_c12 < 0.2%` (max = 0.186% at t=6.0 dimless). The geometric ring
criteria from T72 §6.2 (depth >20%, aspect >1.5) are spuriously satisfied because the
c=12 component has essentially zero density everywhere, making the center density
numerically zero (≤ 3e-7 peak density at t=0.5), and any off-center fluctuation triggers
the ratio. The added population threshold of 1% is physically motivated: a ring with
only ~56 atoms (0.186% of 30000) cannot be observationally meaningful.

The pop_c12 growth from 4.78e-5 at t=0 to 1.86e-3 at t=6 represents a ~40× increase,
consistent with onset of EdH instability (exponential growth at the DDI rate). But this
is only the very beginning of the instability — the ring formation in Matsui's experiment
takes ~5 ms to manifest visibly. The simulation ran for exactly 10 ms (= 2τ_EdH^exp) and
has not yet reached detectable ring population levels.

**Implication for T83**: To test F1 definitively, the dynamics should be run for
~50-100 ms physical (30-60 dimless), i.e., 10-20× longer. This requires either:
(a) A longer dynamics run (duration ~50 dimless, ~5× current cost), or
(b) Recognition that the current run confirms the instability onset rate, and F1 is
    simply INCONCLUSIVE at the current simulation length.

## 7. F2 winding extraction

NOT_APPLICABLE — F1 ring not detected (see §6). For reference: the winding computed at
the last frame (t=6) around r_peak=6 in c=12 gives ell ≈ -0.000 (rounded: 0), which
is consistent with a near-zero noise state (no coherent orbital structure). This is
not a physical winding measurement.

## 8. F3 energy comparison (Zeeman convention reconciliation)

### Summary

| Quantity | Value | Units |
|---|---|---|
| gs_energy_final (total, from T81) | -967.027 | ℏω_ref |
| E_zeeman (GS, m_F=-6, Bz=-0.01G) | ≈ -976.7 | ℏω_ref |
| E_non-Zeeman (total) | ≈ +9.67 | ℏω_ref |
| E_non-Zeeman per atom | ≈ +3.22e-4 | ℏω_ref/atom |
| T72 §5.3 prediction (Case A) | +10.5 | ℏω_ref/atom |
| Relative error (no Zeeman) | ~32,580 | × |
| Relative error (with Zeeman) | 1.003 | (100.3%) |

### Zeeman convention

`total_energy()` in SpinorBEC.jl (`src/analysis/energy.jl:122`) computes:
```
E_total = E_kin + E_trap + E_zeeman + E_contact + E_DDI + E_LHY
```
The ITP `_outer_potential_fwd!` convention (`propagators.jl:65`) subtracts `min(E_m)`
from the propagator exponent to prevent exp overflow, but this subtraction does NOT
appear in `total_energy` at convergence. The reported gs_energy = -967.027 includes:

- `E_zeeman ≈ -p × m_F × ∫|ψ_{c=13}|² = -(-162.78) × (-6) × 1 = -976.7 ℏω_ref`
  (negative, because m_F=-6 at negative Bz is the lowest-energy Zeeman level)
- Non-Zeeman total ≈ -967.027 - (-976.7) = +9.67 ℏω_ref

Per atom: +9.67 / 30000 = +3.22e-4 ℏω_ref/atom.

### TF formula applicability

T72 §5.3 derives `E_mf/N = (3/2)ℏω_ref + (5/7)μ_TF = 1.5 + 9.0 = 10.5 ℏω_ref/atom`
using the Thomas-Fermi approximation. This formula:
- Is valid when `μ_TF >> ℏω_ref` (here `μ_TF/ℏω_ref = 12.6`, marginal TF)
- Assumes N-normalized wavefunction convention (`∫|ψ|² = N`)
- Ignores spin-dependent terms (c1 contribution)

The SpinorBEC.jl unit-normalized convention (`∫|ψ|² = 1`) with `c0` absorbing `N_atoms`
gives the same total extensive energy, so the per-atom comparison is valid. The ~32,580×
discrepancy after Zeeman removal must arise from one or more of:

1. **c1 contribution**: with `c1_ratio = -0.005` (ferromagnetic), the spin energy is
   `E_spin = c1 × |⟨F⟩|² ≈ -16.36 × 36 = -589 ℏω_ref`, which would bring the
   non-Zeeman total from +9.67 + (−589) = −579 — even MORE negative. So c1 is not the
   resolution.

2. **DDI contribution**: at `c_dd_dimless ≈ 30,000 × c_dd / (ℏω_ref × a_ho³)`,
   the DDI for the isotropic (κ=1) case gives `f(κ=1) = 0` → `E_DDI ≈ 0`. Not the cause.

3. **The T72 formula uses physical energies (extensive) not normalized to 1**: T72's
   `E_mf/N = 10.5 ℏω_ref/atom` means the TOTAL extensive non-Zeeman energy is
   `N × 10.5 = 315,000 ℏω_ref`. The simulation's non-Zeeman total is only `+9.67 ℏω_ref`.
   This is 32,580× smaller. **The discrepancy is too large to be explained by any of the
   above corrections alone.**

4. **Most likely root cause**: The T72 formula assumes a fully-converged TF ground state
   with strong repulsive interactions (`c0 = 3271`). The c0 term alone would give
   `E_contact ≈ (c0/2) × ∫|ψ_TF|^4 ≈ (3271/2) × (4/7) × n_peak × a_ho³/V_TF`.
   For a 32³ grid with box=12, the dimensionless TF density peak `n_peak × a_ho³ = n_peak`
   (in dimless units). `n_peak = 15/(8π R_TF³)` with `R_TF ≈ 4.11` (dimless) →
   `n_peak ≈ 0.0334` (dimless). This gives `E_contact ≈ (3271/2) × (4/7) × 0.0334 × (4π/3 × 4.11³)`
   ≈ 936 × 0.019 × 290 ≈ 5,167 ℏω_ref total (per atom: 5167/30000 = 0.172). 
   Still 60× less than T72. BUT the T72 formula uses `N = 30000` in a continuous limit,
   while the simulation uses a 32³ grid in a box of 12 dimless units. The harmonic
   potential extends to ∞ but the grid truncates at box/2 = 6. If the TF cloud radius
   R_TF = 4.11 fits inside the box ✓, the truncation effect is small.

5. **Energy reporting convention**: it is possible that SpinorBEC.jl reports INTENSIVE
   (per-atom) rather than extensive energy. If `E_total = -967.027` is actually per-atom
   (not total), then `E_non-Zeeman/atom = (-967.027 - (-976.7)/30000)` — but this mixes
   conventions. **This requires T83 critic to directly inspect `total_energy` scaling
   with N at a reference configuration.**

### Decisive test for T83

Run a simple sanity check: a non-interacting harmonically-trapped BEC (c0=c1=c_dd=0,
no Zeeman) should give `E_total = (3/2)ℏω_ref × ∫|ψ|² dV`. With unit-normalized ψ,
`E_total = 1.5 ℏω_ref`. With N-normalized ψ, `E_total = 1.5 × N = 45,000 ℏω_ref`.
The actual value of `total_energy` for such a trivial case immediately reveals whether
the code reports extensive (×N) or intensive (×1) energy. T83 critic should run this
1-line check.

## 9. Issues / deviations

1. **Run 1 failed**: JLD2.jl `keys(f)` at root level does not enumerate nested group
   entries; fixed by using `n_snapshots` sentinel to enumerate frame keys explicitly.
   This is a JLD2 API quirk (vs h5py which enumerates recursively).

2. **F3 `f3_zeeman_subtracted` field**: Set to `false` in Metrics JSON (§4) correcting
   an earlier draft that said `true`. The `total_energy` call includes Zeeman; the ITP
   propagator subtraction does NOT propagate to the energy report.

3. **Population threshold not in T72 §6.2**: T72 §6.2 specifies depth >20% and aspect
   >1.5 but does not include a minimum-population guard. The guard was added here to
   prevent false-positive ring detection at sub-percent populations. This is a refinement
   of the T72 criterion, not a deviation from it. T83 critic should ratify the
   pop_threshold=1% or adjust.

4. **Winding at t=6 (reference only)**: The winding computed at the last frame using
   the ring's geometric peak location gives ell ≈ 0 (no coherent phase circulation).
   This is expected at sub-percent population.

## 10. Self-review checklist

- [x] `jld2_point_001_present` = true (verified)
- [x] `analyze_script_written` = true (committed at `a9976a4`)
- [x] `analyze_run_completed` = true (exit 0, wall = 2 s)
- [x] `n_snapshots_loaded` = 12 (matches T81 expectation)
- [x] `f1_t_ring_band` in canonical set: `NOT_APPLICABLE_NO_RING` ✓
- [x] `f3_e_sim_per_atom` = -0.0322 ∈ [-100, 100] ✓
- [x] `f3_band` in canonical set: `OPERATIONAL_GATE` ✓
- [x] `falsification_result` = `OPERATIONAL_GATE` ✓
- [x] No src/ modifications (Analyze is read-only on src)
- [x] No new branch created (operating on main per directive)
- [x] No bare `julia` invocation (used `bash .claude/scripts/*` pattern)
- [x] Commit does not include jld2 data (gitignored)

## 7. Falsification check

**F1**: NOT_APPLICABLE_NO_RING. Dynamics ran 10 ms (2×τ_EdH^exp). pop_c12 grew 40× but
stayed at <0.2%; the EdH instability is clearly seeded but the ring has not formed.
Classification: distinct from REFUTED — the simulation did not run long enough to test
the F1 criterion. Recommend T83 route: either (a) longer dynamics run to definitively
test F1, or (b) accept partial-tier closure with F1 inconclusive.

**F2**: NOT_APPLICABLE (depends on F1).

**F3**: OPERATIONAL_GATE. The +100% discrepancy between e_sim/atom = -0.0322 and
e_mf/atom = +10.5 exceeds the T72 §5.5 OPERATIONAL_GATE threshold. Root cause
identification requires T83 critic to audit: (a) whether `total_energy` is extensive
or intensive; (b) whether the Zeeman contribution to gs_energy is being correctly
accounted; (c) whether the T72 TF formula assumes a different wavefunction normalization.
The energy decomposition test (non-interacting BEC sanity check) is the decisive arbiter.

**Overall**: `OPERATIONAL_GATE`. The F3 flag takes priority and triggers the
OPERATIONAL_GATE classification. The investigation cannot advance to T83 critic Update
until this energy convention discrepancy is diagnosed.
