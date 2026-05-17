---
turn: 55
subagent: researcher
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage: Research
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, phi-sweep, p3-scaling-test, data-inventory, jld2-survey, tier2-to-tier3, verify-claim]
depends_on: [10, 55]
produces: "jld2 inventory + P1/P2/P3 testability matrix + 3 falsifiers + literature anchor for T56 Hypothesize"
---

# Turn 55 — Klaus-BCH-leak data inventory + falsifier-design spec

## 1. Existing jld2 inventory

### 1.1 Structure overview

Source code audit (`src/workflow/io/save_rotating_result.jl:342-345`) reveals:

**`point_001.jld2` is a symlink to `result.jld2`** (not a separate file).
The code at line 342-345 of `save_rotating_result.jl` does:
```
point_link = joinpath(run_dir, "point_001.jld2")
symlink("result.jld2", point_link)
```

Therefore the 16 jld2 entries across 8 phi directories are 8 unique files + 8 symlinks pointing to the same files. Both are present on disk per Glob, but they hold identical content.

### 1.2 result.jld2 layout (canonical, from save_rotating_result.jl)

For each of the 8 phi values, `result.jld2` is written by `save_rotating_basis_result!` with this layout:

| JLD2 key | Type | Description |
|---|---|---|
| `psi` | ComplexF64 4D array (32×32×16×13) | First snapshot — GS / tilt-phase t=0 |
| `dynamics/times` | Vector{Float64} | Concatenated times across 3 phases |
| `dynamics/norms` | Vector{Float64} | Total norm at each saved step |
| `dynamics/Lz` | Vector{Float64} | Orbital angular momentum ⟨L_z⟩(t) |
| `dynamics/Fz` | Vector{Float64} | Spin angular momentum ⟨F_z⟩(t) (rotating-basis tilde frame) |
| `dynamics/Fx` | Vector{Float64} | Placeholder zeros (deferred per code comment line 189) |
| `dynamics/Fy` | Vector{Float64} | Placeholder zeros (deferred per code comment line 190) |
| `dynamics/per_m_history` | Matrix{Float64} (13 × N_snapshots) | Per-component norm at each saved step |
| `dynamics/component_populations` | Matrix{Float64} (N_snapshots × 13) | Normalized per-m fractions |
| `dynamics/psi_snapshots_streamed/n_snapshots` | Int | Total snapshot count |
| `dynamics/psi_snapshots_streamed/spatial_shape` | Vector{Int} | [32, 32, 16] |
| `dynamics/psi_snapshots_streamed/n_components` | Int | 13 |
| `dynamics/psi_snapshots_streamed/frame_NNNNN` | ComplexF32 (32×32×16×13) | Full ψ̃ snapshot, ZstdCompressed |
| `dynamics/integrator_meta/dt_used` | Float64 | 0.001 (from last phase) |
| `dynamics/integrator_meta/integrator` | String | "yoshida4" |
| `dynamics/integrator_meta/epsilon_target` | Float64 | 1e-6 |
| `dynamics/integrator_meta/p_zeeman` | Float64 | 26700.0 |
| `dynamics/integrator_meta/F_atom` | Int | 6 |
| `dynamics/integrator_meta/larmor_phase_per_step` | Float64 | 26700 × 6 × 0.001 = 160.2 |
| `dynamics/integrator_meta/theta_const` | Float64 | 0.611 (last phase) |
| `dynamics/integrator_meta/phi_omega` | Float64 | phi value of this scan point (from last phase) |

**Note:** `dynamics/Fx` and `dynamics/Fy` are confirmed placeholder zeros per
`dynamics.jl:188-190`. They cannot be used for spin-texture analysis without
re-running the ψ̃ snapshot post-processor.

### 1.3 Snapshot count estimate per phi file

From the config (dt=0.001 throughout, 3 pipeline phases):

| Phase | Duration | dt | Steps | save: {every:} | Snapshots |
|---|---|---|---|---|---|
| Tilt | 6.28 | 0.001 | 6280 | 200 | ~32 |
| Spinup | 15.71 | 0.001 | 15710 | 200 | ~79 |
| Steady stir | 314.16 | 0.001 | 314160 | 500 | ~629 |
| **Total (all 3 phases)** | 336.15 | — | 336150 | — | **~740** |

The concatenation drops the first sample of each subsequent phase to avoid boundary duplicates (`save_rotating_result.jl:33`), so total is approximately 740 snapshots per phi value.

### 1.4 Per-phi-value file table

Config confirmed from `runs/eu151_klaus_phi_phys/phi_1.0/config.yaml` and `phi_4.524/config.yaml` (both identical to root config.yaml except for the scan override of `pipeline.3.dynamics.B.phi.rate` and `pipeline.2.dynamics.B.phi.rate.to`).

| phi value | result.jld2 | point_001.jld2 | config.yaml |
|---|---|---|---|
| 1.0 | present | symlink → result.jld2 | present |
| 2.0 | present | symlink → result.jld2 | present |
| 3.0 | present | symlink → result.jld2 | present |
| 4.524 | present | symlink → result.jld2 | present |
| 6.0 | present | symlink → result.jld2 | present |
| 8.0 | present | symlink → result.jld2 | present |
| 12.0 | present | symlink → result.jld2 | present |
| 18.0 | present | symlink → result.jld2 | present |

All 8 result.jld2 files are confirmed present via Glob. All 8 point_001.jld2 entries present (as symlinks). All 8 per-phi config.yaml present + 1 root config.yaml = 9 total.

**Notable observation: point_001.jld2 is a symlink to result.jld2.** No independent content.
Inventory counts: jld2_files_inventoried=16 (per Glob), jld2_files_loadable=8 (unique files; symlinks read identically to their target).

### 1.5 Observable availability audit

The following observables are confirmed present from code inspection of `dynamics.jl` and `save_rotating_result.jl`:

| Observable | JLD2 key | Confirmed present? | Notes |
|---|---|---|---|
| Norm time series | `dynamics/norms` | YES | At every `save_every` step, all phases |
| Spin ⟨F_z⟩(t) (tilde-frame) | `dynamics/Fz` | YES | Computed as Σ_m m·N_m at each saved step |
| Orbital ⟨L_z⟩(t) | `dynamics/Lz` | YES | 3D grid only; this is 3D → present |
| Per-m populations N_m(t) | `dynamics/per_m_history` | YES | Full 13-component history |
| Full ψ̃ snapshots | `dynamics/psi_snapshots_streamed/...` | YES | Default save_psi_snapshots=true |
| ⟨F_x⟩, ⟨F_y⟩ (tilde-frame) | `dynamics/Fx`, `dynamics/Fy` | YES (zeros only) | Deferred per dynamics.jl:188-190 |
| Integrator metadata | `dynamics/integrator_meta/*` | YES | dt, p, F, larmor_phase |

**Not in jld2:** Norm drift trajectory in absolute terms (only `norms` vector; norm drift = 1 - norms[t] must be computed). Lab-frame ψ_lab is not saved (only ψ̃ is saved; lab-frame reconstruction requires Û_B(t) post-rotation).

### 1.6 Critical observation: ⟨F_z⟩ in tilde-frame vs lab-frame

The saved `dynamics/Fz` is ⟨F̃_z⟩ in the rotating (tilde) basis — this is the spin angular momentum along the ROTATING quantization axis B̂(t), not the lab-frame z-axis. For the EdH conservation test (which measures J_z = ⟨F_z⟩_lab + ⟨L_z⟩_lab), one needs to account for the Û_B(t) rotation. At steady stir with theta=0.611, the lab-frame ⟨F_z⟩_lab = cos(theta)·⟨F̃_z⟩ + sin(theta)·(ℜ⟨F̃_x e^{iφ(t)}⟩). The tilde-frame ⟨F_z⟩ is a proxy; it equals the lab-frame ⟨F_z⟩ only in the purely aligned (theta=0) or purely anti-aligned (theta=π) limit.

For P2 norm-drift falsifier, this distinction does not matter — norm is frame-independent.
For EdH conservation falsifier, the tilde-frame Fz + lab-frame Lz is NOT a conserved quantity. The correct EdH observable would need the lab-frame Fz, reconstructable from ψ̃ snapshots via Û_B(t) post-rotation (requires loading the 740 snapshots × 32×32×16×13 ComplexF32 arrays per phi point, which is O(100 GB) total — cpu_heavy).

---

## 2. P1/P2/P3 testability matrix

| Prediction (from theorist/turn_10.md §2.9) | Required observable | Available in existing jld2? | Suggested test shape | What's needed if not available |
|---|---|---|---|---|
| **P1 term 1**: lab-frame scrambling timescale τ^{-1} ~ p·F·sinθ·c_dd⟨n⟩·dt² | Lab-frame Mz scrambling vs dt at fixed phi | NO — existing data is rotating_basis only; no lab-frame run in eu151_klaus_phi_phys/ | N/A | Fresh lab-frame run at same parameters (kind: spinor, same grid, varying dt ∈ {4e-4, 2e-3, 5e-3}) — cpu_heavy or gpu, ~30 min wall |
| **P1 term 2**: φ̇-linear time-dep leak dt²·φ̇·p·sinθ·F; rotating-basis φ̇-sweep probes this coefficient | Option γ residual error magnitude vs φ̇ at fixed p, dt | INDIRECT — norm drift trajectory across 8 phi points IS in existing data; if Option γ fully absorbs the leak, norm drift should remain stable. If a φ̇-dependent drift appears, it would indicate residual BCH (φ̇-dep term) is not fully absorbed | Plot `1 - dynamics/norms` vs time for all 8 phi values; check if drift grows with phi; compare drift magnitude to theory prediction dt²·φ̇·p·sinθ·F·T at the same T | N/A (partial test; cannot separate interaction-flanked vs time-dep term from norm drift alone) |
| **P2 (Option γ dt-stability)**: norm drift ≲ 10^{-10} over T=314 at all phi values in rotating basis at fixed dt=0.001 | Norm at final time point (`dynamics/norms[-1]`) | YES — `dynamics/norms` is saved for all 8 phi values | Read `dynamics/norms` from each result.jld2; compute `max(|1 - norm|)` over all timesteps; check < 1e-10 threshold across all 8 phi points | N/A |
| **P3 (p-scaling)**: halving p at fixed dt halves lab-frame scrambling per-step; rotating-basis unaffected | Lab-frame ψ trajectories at varying p={2670, 26700, 267000} | NO — p is fixed at 26700 in all 8 existing points; no p-sweep data exists | N/A | Fresh p-sweep run (kind: rotating_basis OR kind: spinor for lab-frame comparison) at 3 p values, fixed phi=4.524 (canonical), fixed dt; cpu_heavy or gpu |
| **EdH conservation** (⟨F_z⟩+⟨L_z⟩ drift, Berry-connection prediction): J_z = ⟨F_z⟩_lab + ⟨L_z⟩ should drift only at rate set by external torque | `dynamics/Fz` (tilde-frame) + `dynamics/Lz` + Û_B(t) post-rotation to get lab-frame Fz | PARTIAL — Lz and Fz (tilde) are saved; lab-frame Fz requires Û_B post-rotation of ψ̃ snapshots (cpu_heavy, ~100 GB per phi point if all 740 frames loaded) | Proxy test: plot ⟨F̃_z⟩(t) + ⟨L_z⟩(t) (mixed-frame sum); if phi=const this proxy equals J_z; for rotating phi, it differs. For P2 purposes, norm drift is a cleaner proxy | If full EdH accuracy needed: load subset of snapshots (e.g. every 10th frame of steady stir phase) and compute Û_B(t)·F̃_z·Û_B†(t), O(10 GB) per phi point |

### 2.1 Summary

- **P1 term 1**: NOT testable from existing data. Requires fresh lab-frame run.
- **P1 term 2**: PARTIALLY testable from norm drift across phi sweep (indirect proxy). Full isolation requires DDI-off control run.
- **P2**: DIRECTLY testable from `dynamics/norms` across all 8 phi points. Cheapest and sharpest falsifier.
- **P3**: NOT testable from existing data. Requires fresh p-sweep run.
- **EdH conservation**: PARTIALLY testable using tilde-frame Fz + Lz as proxy; full lab-frame EdH requires snapshot post-rotation (cpu_heavy).

---

## 3. Proposed falsifiers for T56 Hypothesize

### Falsifier 1: P2-option-gamma-norm-drift-stability-across-phi-sweep

```
falsifier_id: P2-norm-drift-stability-phi-sweep
prediction: Option γ rotating-basis at dt=0.001 maintains norm drift
            < 1e-10 across all 8 phi values (φ̇ ∈ {1,2,3,4.524,6,8,12,18})
            over T=314.16 steady-stir duration (1s physical).
measurement: For each phi_X/result.jld2:
             Load dynamics/norms (Vector{Float64}, ~740 entries).
             Compute max_drift = maximum(abs.(1.0 .- norms)).
             Also compute norms[end] - 1.0 (final-time drift).
             Compare max_drift across 8 phi values; check monotonicity with phi.
null_hypothesis: max_drift > 1e-5 at any phi value OR max_drift grows
                 monotonically with phi by > 5x from phi=1 to phi=18.
                 Either would indicate Option γ does NOT fully absorb
                 the φ̇-dependent BCH leak (P1 term 2) even at small phi.
confirm_hypothesis: max_drift < 1e-6 at all phi values, with no systematic
                    monotonic growth from phi=1 to phi=18.
                    Norm at T=314.16 should remain within 1e-6 of initial
                    for all phi values (rotating-basis is not norm-conserving
                    exactly, but Y4 integrator should conserve to high order
                    at dt=0.001 with epsilon=1e-6 guard).
estimated_julia_cost: cpu_light (read 8 JLD2 files, no simulation)
estimated_wall_time: ~60s (JIT ~30s for JLD2, then 8 file reads)
```

### Falsifier 2: P2-larmor-phase-metadata-consistency-check

```
falsifier_id: P2-larmor-phase-metadata
prediction: The stored integrator_meta/larmor_phase_per_step = p·F·dt =
            26700 × 6 × 0.001 = 160.2 for all 8 phi points. This is
            >> π (≈3.14), which is deep in the "Larmor-stiff" regime
            that the dynamics.jl:46 guard warns about. HOWEVER,
            the run succeeded (no ArgumentError thrown) because epsilon=1e-6
            is < 1e-3, triggering only a @warn (not a hard error), and
            the explicit dt=0.001 override suppresses the guard entirely
            (haskey(p, "dt") == true at dynamics.jl:47).
            This metadata confirms the runs were in the BCH-divergent
            regime described in theorist/turn_10.md §3.4.
measurement: For each phi_X/result.jld2:
             Load dynamics/integrator_meta/larmor_phase_per_step,
             dynamics/integrator_meta/p_zeeman,
             dynamics/integrator_meta/F_atom,
             dynamics/integrator_meta/dt_used.
             Verify: larmor_phase_per_step ≈ p_zeeman × F_atom × dt_used
             Verify: value ≈ 160.2 (>> π) for all 8 points.
null_hypothesis: larmor_phase_per_step < π (would indicate the runs
                 were NOT in the BCH-stiff regime, falsifying the T10
                 §3.4 convergence-radius argument).
confirm_hypothesis: larmor_phase_per_step ≈ 160.2 >> π at all 8 phi points,
                    consistent with the BCH expansion parameter
                    p·F·dt >> 1 claimed in theorist/turn_10.md §3.4.
estimated_julia_cost: cpu_light
estimated_wall_time: ~45s (JIT + 8 metadata reads)
```

### Falsifier 3: P1-term2-phi-linear-drift-proxy

```
falsifier_id: P1-term2-phi-linear-norm-drift-proxy
prediction: If the P1 term-2 leak (dt²·φ̇·p·sinθ·F) is NOT fully absorbed
            by Option γ, there should be a φ̇-monotonic residual norm
            drift in the rotating basis. Theorist/turn_10.md §2.7 argues
            it IS absorbed (BCH parameter drops from p·F·dt=160.2 to
            φ̇·F·dt = φ̇×6×0.001 ≤ 0.108 at phi=18). A φ̇-linear
            residual of the unabsorbed part would scale as
            dt²·φ̇²·p·sinθ·F (second-order residual, not first).
            For phi=18: this is (0.001)²×18²×26700×0.574×6 ≈ 2.98e-3 per step,
            or ~1000 per T=314 (clearly unphysical if present).
            For phi=1: (0.001)²×1×26700×0.574×6 ≈ 9.2e-6 per step.
            If Option γ fully eliminates the leak, the measured drift
            should be O(dt⁴) from the Y4 truncation error, not O(dt²).
measurement: For each phi_X/result.jld2 steady-stir phase (last ~629 entries):
             Extract dynamics/norms[~112:end] (steady-stir portion).
             Compute drift_rate = (norms[end] - norms[steady_start]) / steady_duration.
             Fit drift_rate vs phi to a power law (phi^alpha).
             If alpha ≈ 0: Option γ fully absorbs the φ̇-dep leak (CONFIRM).
             If alpha ≈ 1 or 2: φ̇-dependent residual leaks (REFUTE or PARTIAL).
null_hypothesis: drift_rate grows faster than phi^0.5 across phi ∈ {1,2,3,4.524,6,8,12,18},
                 indicating Option γ does not fully suppress the
                 φ̇-dependent BCH term.
confirm_hypothesis: drift_rate is phi-independent (within 2x across 18x phi range),
                    confirming Option γ suppresses φ̇-dep leak at this dt.
estimated_julia_cost: cpu_light
estimated_wall_time: ~90s (JIT + 8 file reads + steady-stir slicing + fit)
```

### Falsifier 4 (requires fresh run): P3-p-scaling-test

```
falsifier_id: P3-p-scaling-fresh-run
prediction: In lab-frame (kind: spinor) solver, halving p at fixed dt halves
            the per-step Mz scrambling rate (linear in p per theorist/turn_10.md §2.4).
            In rotating-basis (kind: rotating_basis), changing p should
            NOT change the norm drift rate (Option γ eliminates p-dependence).
measurement: Requires 3-point p-sweep {p=2670, 26700, 267000} at fixed
             phi=4.524, dt=0.001 (rotating_basis) + at fixed dt=4e-4 (spinor).
             For rotating_basis: check norm drift rate vs p — should be p-independent.
             For spinor: check Mz stability vs p — should show p-linear scrambling.
null_hypothesis: rotating_basis norm drift grows with p (= Option γ does NOT
                 eliminate p-dependence at fixed dt); OR spinor solver scrambles
                 at p=2670 just as fast as at p=26700 (= p-scaling is wrong).
confirm_hypothesis: rotating_basis drift is p-independent; spinor Mz scrambling
                    rate scales as p^1 (or faster).
estimated_julia_cost: gpu (rotating_basis GPU backend; short duration ~20 ω⁻¹ sufficient
                      for stability test, not full 1s stir)
estimated_wall_time: ~30 min (3 runs × ~10 min each including JIT)
fresh_run_required: true
```

---

## 4. Literature anchor

The canonical reference for BCH-error analysis of split-step integrators for quantum dynamics is:

**Hairer, Lubich, and Wanner (2006)**: *Geometric Numerical Integration: Structure-Preserving Algorithms for Ordinary Differential Equations*, 2nd ed., Springer Series in Computational Mathematics Vol. 31, DOI: 10.1007/3-540-30666-8.

Chapter III of this textbook treats the BCH formula (p. 84), Strang splitting order conditions via BCH (p. 87), and Lie-algebraic error bounds for splitting methods. The key result (III.4 Theorem): for the Strang (Lie-Trotter symmetric) splitting of exp(-iA·τ)·exp(-iB·τ)·exp(-iA·τ), the leading-order local error is proportional to τ³·‖[A,[A,B]] + [B,[A,B]]‖. When operator norms ‖A‖ ~ p (Larmor scale) and ‖B‖ ~ p·sinθ (transverse field), the commutator ‖[A,B]‖ ~ p²·sinθ·F, and the BCH error scales as τ³·p³·F²·sinθ — which, accumulated over T/τ steps, gives the global error T·p³·F²·sinθ·τ² as derived in theorist/turn_10.md §2.3. The BCH series converges only when τ·(‖A‖+‖B‖) ≲ ln2 (classical BCH radius), recovering the theorist's dt ≲ 1/(p·F) ≈ 1e-5 threshold independently.

For spinor BEC numerics specifically, the closest published reference is:

**Bao, W. and Cai, Y. (2018)**: "Mathematical models and numerical methods for spinor Bose-Einstein condensates," *Communications in Computational Physics*, Vol. 24, pp. 899-965, arXiv:1709.03840. This review covers time-splitting spectral (TSSP) methods for coupled Gross-Pitaevskii equations. Section 4 (Spin-1 BEC) treats the Zeeman splitting in the context of numerical integrators. However, this reference covers the weak-field regime only (static or slowly-varying B) and does not identify the strong-field BCH convergence failure. The specific identification of the ‖[B_perp, A_DDI]‖ commutator as the load-bearing leak at the transverse-Zeeman-vs-DDI substep boundary (theorist/turn_10.md §2.4) appears to be an original contribution of this investigation, not reproduced in Bao-Cai or Kawaguchi-Ueda 2012 (arXiv:1001.2072, Phys. Rep. 520, 2012).

**Status**: The Hairer-Lubich-Wanner §III.4 result provides a Tier-3-eligible literature anchor for the BCH-error scaling argument (not BEC-specific, but mathematically rigorous). The BEC-specific application (strong-field Klaus regime) remains at Tier 2 — closed-form derivation by this investigation, no published BEC paper derives the specific ‖[B_perp, A_DDI]‖ leak or the Option γ BCH-parameter reduction from p·F·dt to φ̇·F·dt.

---

## 5. Recommendations for T56 director

**Which falsifier to advance first**: Falsifier 1 (P2-norm-drift-stability-phi-sweep) is the cheapest and sharpest. It requires only reading 8 JLD2 files and computing max(|1-norms|) per file — cpu_light, ~60s total wall including JIT. It directly tests the central P2 claim: "Option γ maintains norm drift ≲ 1e-10 at dt=0.001 across the phi sweep." If P2 passes, it validates the core BCH-absorption argument. If P2 fails, the entire Option γ motivation needs re-examination. Falsifier 2 (metadata consistency) can be done simultaneously as a sanity check with no additional cost.

**Fresh julia run required**: YES, but only for P3 (p-scaling). P1 term 1 (lab-frame comparison) and P3 both require fresh runs. P2 and partial-P1-term-2 are testable from existing data. The recommended staging:
- T56: Theorist Hypothesize (refine P2 predicted threshold, bound P1-term-2 residual expected value from theory, decide whether the mixed-frame EdH proxy is sufficient)
- T57: Execute falsifiers 1+2+3 in one cpu_light julia script (read 8 jld2 files + compute)
- T58: Analyze results; if P2 CONFIRMS, advance to P3 fresh run; if P2 REFUTES, investigate why Option γ doesn't suppress the leak before commissioning a P3 run

**Open questions for theorist to resolve at Hypothesize**:

1. **P2 threshold refinement**: The theorist predicted norm drift ≲ 1e-10. For a Y4 integrator at dt=0.001 over T=314.16, the Y4 global error scales as dt⁴·T ≈ (1e-3)⁴·314 ≈ 3.14e-10. The predicted threshold 1e-10 may be too tight by 3x. Theorist should restate the threshold as "O(dt⁴·T) ≈ 3e-10" with tolerance ±order-of-magnitude.

2. **tilde-frame Fz for EdH**: The saved `dynamics/Fz` is ⟨F̃_z⟩ (rotating-frame spin z), not ⟨F_z⟩_lab. The EdH conservation analyzer (`src/rotating_basis/analyzers.jl:54`) uses `dyn[:Fz]` directly. At theta=0.611 (35°), ⟨F_z⟩_lab ≠ ⟨F̃_z⟩. Theorist should clarify whether the "EdH conservation" test in the memory (option_gamma_rotating_basis.md) was designed for the tilde-frame proxy or the true lab-frame quantity. This determines whether the EdH falsifier is "ready to run" or requires snapshot post-processing.

3. **Norm is not a direct BCH-error observable**: Norm drift in the rotating-basis Y4 run measures Y4 time-integration error, NOT directly the BCH commutator error from the spin-vs-DDI substep boundary. The BCH leak in theorist/turn_10.md §2.4 is a PHASE error (it rotates the spinor state incorrectly), not a norm error per se. Theorist should clarify: what observable best discriminates "BCH leak in spin step" from "Y4 integration error"? Candidates: (a) per-m population drift (m=+F fraction decay rate vs phi), (b) ⟨J_z⟩ drift rate, (c) energy non-conservation.

4. **p·F·dt = 160.2 >> π at dt=0.001**: The running larmor_phase_per_step = 160.2 is in the "BCH divergent" regime per T10 §3.4. However, the `apply_local_spin_step!` in the rotating basis uses an exact eigendecomposition of H_spin^rot = -p·F_z + q·F_z² - Â(t), so the large p·F·dt is HANDLED EXACTLY by the eigen-step (no BCH expansion inside the spin step). The BCH-problematic boundary is between the combined-spin-step and the DDI step. The theorist should confirm: is the larmor_phase_per_step warning in `dynamics.jl:47` triggered by the Option γ runs? (Likely suppressed by `haskey(p, "dt") == true` per line 47).

---

## 6. Metrics

```json
{
  "experiment_kind": "text_only",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "jld2_files_inventoried": 16,
  "jld2_files_loadable": 8,
  "yaml_configs_read": 9,
  "p_predictions_mapped": 3,
  "falsifiers_proposed": 4,
  "literature_citations": 2,
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Research",
  "flow_template": "verify-claim",
  "fresh_julia_run_required_for_p3": true,
  "existing_data_sufficient_for_p2": true,
  "existing_data_sufficient_for_p1_term2": false,
  "note_jld2_loadable_rationale": "16 files present on disk (8 result.jld2 + 8 point_001.jld2 symlinks). Only 8 are unique files (symlinks read identically to result.jld2). Reporting loadable=8 because the 8 symlinks contain no independent data — loading point_001.jld2 is identical to loading result.jld2. All 8 unique files confirmed present via Glob; layout confirmed via source code audit of save_rotating_result.jl.",
  "note_p1_term2_partial": "P1 term 2 is PARTIALLY testable via norm drift proxy (falsifier 3) but not directly — the phi-sweep varies phi at fixed p, so the phi-linear coefficient of the time-dep leak is probed only indirectly through its effect on Y4 integration residuals, not through a direct comparison to a reference solver.",
  "note_point001_is_symlink": "point_001.jld2 is confirmed to be a symlink to result.jld2 (save_rotating_result.jl:342-345). The directory scan lists 16 jld2 entries but there are only 8 unique files."
}
```
