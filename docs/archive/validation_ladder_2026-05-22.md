<!-- promoted from agent memory `validation_ladder_2026_05_22.md` on 2026-07-31; historical record, not an SSoT -->
<!-- Canonical Eu validation ladder (13 levels, 0-12) + A/B/C verification taxonomy. Level 10 pivoted 2026-05-26 from "Ueda comparison" to "independent reference-RHS comparison" (Ueda code BLOCKED_EXTERNAL). Supersedes 2026-05-24 / 2026-05-22 versions. -->

**Canonical strategy refined 2026-05-24 (anko), Level 10 pivoted 2026-05-26.** Supersedes the 2026-05-22 10-level draft and the 2026-05-24 Ueda-gated Level 10. "Perfect simulation" is *not* "everything turned on + pretty movies" — it is "every approximation, error, and limit is quantified."

**2026-05-26 pivot:** Ueda code comparison is BLOCKED_EXTERNAL (no communication channel). Level 10 rewritten to use an **independent reference-RHS implementation** (small, CPU-only, term-by-term Hψ inside this repo) as the comparison authority instead of Ueda's code. Existing `operator_rhs.jld2` / `parameter_contract_with_Ueda.md` infrastructure is paused, not deleted — usable if communication reopens. See `strategic_pivot_self_contained_validation_2026_05_26.md` for full decision context.

## Three-type verification taxonomy (do NOT mix)

| Type | Question | Examples |
|---|---|---|
| **A. Code verification** | Are we solving the equation correctly? | Strang 2nd-order convergence, norm/energy conservation, CPU/GPU consistency, agreement with analytic ψ |
| **B. Physics validation** | Does the equation reproduce known physics? | spin-1 polar/FM GS, SMA oscillation, spherical-cloud E_DDI≈0, EdH J_z conservation |
| **C. Model validation** | Does this model explain the experiment? | Eu N(t)/density/texture vs lab data, whether K3 is needed, whether LHY is needed |

**K3 question is type-C. The current Ueda-vs-our-code gap is most likely type-A or type-B.** Lock A and B before debating C.

## 13-level ladder (0-12)

```
0.  Environment / reproducibility   (git commit + Manifest + CUDA + seed lock; CPU vs GPU on small system)
1.  Scalar exact tests              (free uniform; plane wave e^{ikx}e^{-ik²t/2}; harmonic GS E/N=1.5)
2.  Strang splitting convergence    (dt, dt/2, dt/4 → ratio ≈ 4 pre-collapse)
3.  Spin matrices / Zeeman          ([F_x,F_y]=iF_z; Zeeman-only N_m constant + phase exp(-i(-pm+qm²)t))
4.  Spinor contact interactions     (spin-1 polar/FM GS; SMA; spin-2 cyclic/nematic singlet-pair sign)
5.  DDI kernel                      (spherical E_DDI≈0; prolate/oblate sign; axis flip; brute-force vs FFT)
6.  EdH canonical benchmark         (F=3 toy or Cr; DDI-on EdH transfer S_z↓ L_z↑ J_z conserved; DDI-off vanishes)
7.  Loss / K3 unit test             (uniform n(t)=n₀/√(1+2K₃n₀²t); Gaussian -dN/dt=K₃∫n³; SI→dimless scaling)
8.  LHY unit test                   (scalar slope: E∝n^{5/2}, μ∝n^{3/2}; coefficient cross-check; spinor LHY caveat)
9.  Eu Hamiltonian-only             (DDI on, loss/K3/LHY/γ_dr OFF; energy decomposition; conservation laws)
10. Reference-RHS comparison        (independent CPU-only term-by-term Hψ in this repo: scalar < 1e-10, Zeeman < 1e-12, contact < 1e-10, DDI 1e-6..1e-8, loss = analytic rate. Ueda-code path BLOCKED_EXTERNAL — paused, not deleted.)
11. Convergence (dt/grid/box/seed)  (dt scan + grid scan + box scan + seed sweep at Eu params)
12. Production Eu simulation        (with controls: DDI off / DDI+loss off / +K3 / +γ_dr / scalar LHY)
```

**K3 is Level 7 (analytic unit test) and re-enters at Level 12 (with controls).** Forbidden to cite K3 effect from older runs until Level 9 + reference-RHS Level 10 pass.

## Acceptance criteria for "K3 effective" claim (revised 2026-05-26)

```
1. Level 9 Hamiltonian-only converged in grid/dt (DONE — ΔF_z=0.00886 at k_cut=16)
2. Level 10 production Hψ matches independent reference-RHS at expected tolerance
3. DDI off makes EdH/collapse signature vanish (Level 6 + Level 9 control)
4. Level 7: K3 alone reproduces analytic n(t)
5. Level 12 K3 A/B: peak_density + N(t) diverge only at/after collapse onset
6. Level 12 factorial K3 × γ_dr: separable contribution
7. Level 11 convergence held up to collapse onset
```

If Level 10 reference-RHS diff exceeds tolerance → bug is in production
Hψ assembly (DDI convention / Zeeman sign / m ordering / normalization /
secular vs full / state assembly). **Do not blame K3.**

External-code comparison would be a stronger Level 10 if available, but
the reference-RHS check rules out most internal Hψ-assembly bugs
without it. Eu production claims become "robust under
reasonable-convention + validated-solver factorial" rather than
"matches the Ueda lab" — see strategic-pivot memory for framing.

## 10 most important validation runs (priority order)

```
1.  scalar_free_uniform                (Level 1, norm drift < 1e-10)
2.  harmonic_oscillator_ground         (Level 1, E/N = 1.5)
3.  zeeman_only_F6_phase               (Level 3, N_m constant + phase exp(-i(-pm+qm²)t))
4.  spin1_polar_FM_contact             (Level 4, c₁>0 polar / c₁<0 FM)
5.  spin1_spin_mixing                  (Level 4, SMA oscillation, M_z conserved)
6.  DDI_spherical_Eddi_zero            (Level 5, spherical polarized → E_DDI → 0 with grid)
7.  DDI_axis_flip                      (Level 5, anisotropy follows B axis)
8.  EdH_F3_canonical_no_loss           (Level 6, EdH transfer + J_z conserved, DDI on→off control)
9.  loss_only_uniform_K3               (Level 7, analytic n(t))
10. Eu_F6_Hamiltonian_only_no_loss     (Level 9, full Eu minus dissipation; for Level 10 Ueda comparison)
```

## 5 essential Ueda-alignment checks (Level 10)

```
1. Parameter contract               (signed table of every convention, see below)
2. Same ψ₀ energy decomposition     (E_kin / E_trap / E_contact / E_DDI / E_Zeeman)
3. Same ψ₀ Hψ comparison            (‖H_ours·ψ − H_Ueda·ψ‖; strongest test)
4. One-step comparison              (same ψ₀, same dt, one step → diff O(dt³))
5. Short-time comparison            (early slope of F_z(t), L_z(t), N_m(t) pre-collapse)
```

Image comparison of late-time collapse is the *weakest* test — chaotic amplification of any A/B error. Do not start there.

## Current ladder status (2026-05-24, mapped to new numbering)

| New Level | Status | Notes |
|---|---|---|
| 0 env/reproducibility | partial | git/seed locked; CPU/GPU equivalence on small system not yet a regression test |
| 1 scalar exact | **needs explicit suite** | implicit coverage via existing tests; no dedicated `validation_level1/` |
| 2 Strang convergence | **needs explicit suite** | order-2 verified ad hoc in TDHFB work; no Eu-shape regression |
| 3 Zeeman-only | **needs explicit suite** | scattered in test_zeeman_levels.jl; not a packaged Level-3 test |
| 4 spinor contact | partial (10/10 minimum-physics PASS from old Level-1) | covers SMA M_z conservation 5e-16; spin-2 cyclic not bundled |
| 5 DDI kernel | YAML PASS, **analysis missing** | Bx/prolate/oblate runs OK; post-hoc anisotropy-follows-B analysis pending |
| 6 EdH F=3 toy | YAML PASS | Cr DDI off Fz drift 5.4e-13 ✓; DDI on Fz drift 2.95e-04 (EdH visible) ✓ |
| 7 loss/K3 analytic | qualitative PASS | uniform-box Cr52 + K3=1e-41 m⁶/s → 1.09% loss over t̃=1. Quantitative analytic-match needs ITP-skipped IC |
| 8 LHY unit | **NEW — not started** | scalar slope + coefficient cross-check; spinor LHY caveat documentation |
| 9 Eu Ham-only | **CROSS-GRID CONVERGED 2026-05-24** | Full L4 iteration closed via 5 commits c2c27a0 / aa33bd0 / cb6fddb / aed6e0e / cf8cbb0. Final recipe: `DEALIAS_2_3_ENABLED[]=true` + `DEALIAS_K_CUTOFF[]=16.0` + `dt=0.005` (or `dt_max_for_k_cut(k_cut, safety=10)`). At this setting, N=64/96/128 ALL give ΔF_z = 0.00886 (5-digit agreement, 8× memory difference). Richardson extrapolation from dt=0.005 + dt=0.0025 puts dt→0 limit at 0.00858. Iteration cause-isolation chain: (1) DDI is sole grid-divergence source — c1=0 probe still diverges, DDI=off makes ΔF_z=7e-12 at every grid (machine ε); (2) per-axis (n/3) cutoff caused bandwidth mismatch — DEALIAS_K_CUTOFF equalises; (3) safe k_cut boundary at 2·k_Nyq/3 (above → F-filter aliasing escape, non-monotonic); (4) ITP-GS embedded grid-dependent high-k → filter inside ITP loop; (5) Strang dt²·k² error was the final residual — dt·k_cut ≤ 0.1 heuristic threshold. Original L4 numbers 0.0089/0.0089/0.0147/0.0118/0.0093 were ALL artifacts of either bilinear aliasing (N=64) or Strang dt² (N=96, 128). The physical answer at k≤16 bandwidth is 0.00886 — definitive Eu Hamiltonian-only EdH prediction. |
| 10 reference-RHS comparison | **pivoted 2026-05-26** — Ueda path BLOCKED_EXTERNAL, building independent `src/validation/reference_rhs_*.jl` instead. parameter_contract_with_Ueda.md + operator_rhs.jld2 paused (not deleted). |
| 11 convergence | **two-source diagnosis (2026-05-24)**: (1) bilinear aliasing at N=64 PROVEN by dealias fix (eliminates artifact). (2) Higher-k physics at N≥96 captured by larger bandwidth — genuine, not artifact. Path C (2/3 rule) handles (1); Path A (2× k-pad ψ) needed for (2). Full L5 25/25 PASS confirms operator-RHS correct. |
| 12 production | runs/ exist but **DO NOT INTERPRET** | eu151_edh_k3_compare/, eu151_edh_loss_factorial/, eu151_edh_K3_long/ are pre-validation runs |

## Codebase fixes (2026-05-22, retained)

- `src/workflow/experiments/analyzers/stability.jl:70` — `max_growth` → `max_growth_rate`
- `src/workflow/experiments/schema/schema.jl` — c2-c12 in INTERACTIONS_SCHEMA
- `src/workflow/experiments/runtime/runtime_io.jl:128,263` — dynamic snap_eltype, not hardcoded ComplexF32
- `src/workflow/experiments/analyzers/phase.jl` — `majorana_order` skips F<6 gracefully
- `ext/SpinorBECCUDAExt/gpu_spin_mixing.jl` — accept `psi_mf` kwarg (CPU/GPU API parity)
- `src/workflow/experiments/schema/parsing_blocks.jl` — K3_per_m_cubic emits clear error on string input; docstring corrected (dimless vs SI)

## Parameter contract for Ueda comparison (10 items minimum) — PAUSED 2026-05-26

(Retained for the day Ueda communication reopens. Currently
BLOCKED_EXTERNAL — see strategic-pivot memory. The same convention
sheet is also useful as the canonical convention reference for the
independent reference-RHS implementation, so do not delete.)


| Quantity | Question to align |
|---|---|
| DDI coefficient | 1/4π included? (we: no — `c_dd=μ₀μ²`) |
| μ | g_F F μ_B (saturation) or g_F μ_B (per-spin-matrix)? |
| DDI kernel | Q = k_α k_β / k² − δ_αβ/3 or 4π× variant? (we: no 4π) |
| k=0 mode | set to 0? (we: yes) |
| m ordering | +F → −F or −F → +F? (we: c=1→m=F, c=D→m=−F) |
| B_z / p sign | p = +g μ_B B or −g μ_B B? |
| q sign | q = +(g μ_B B)² / (other) or other? |
| initial state | m=+F or m=−F? |
| full DDI vs secular | which? (we: user-chosen; advisory @info when ω_L/(c_dd⟨n⟩) > 100) |
| K3 normalization | dn/dt = −K3 n³ direct, or with 1/6? |
| ψ normalization | ∫|ψ|² = 1 or = N? |
| Loss substep | how is three-body decay split with Hamiltonian? |
| Trap convention | ω_x, ω_y, ω_z values; aspect ratio sign |

Single signed sheet with these BEFORE any numerical comparison.

## Deliverables for "completed validation"

```
validation_report.md                                 (per-level PASS/FAIL with errors)
validation_matrix.csv                                (test | physics | expected | result | status)
parameter_contract_with_Ueda.md                      (signed convention sheet)
convergence_plots/                                   (dt, grid, box, seed)
golden_outputs/                                      (reference jld2 per level)
scripts/validation/run_validation_matrix.jl          (one-shot runner)
test/validation/test_L5_operator_rhs_compare.jl      (operator-RHS diff;
  shipped as OperatorRHSSpec in src/workflow/validation/specs.jl, not a script)
```

## Next immediate actions (2026-05-24)

1. **Decide bilinear-aliasing branch**: (A) implement 2× k-space pad in `_compute_spin_density!` OR (B) accept ≥96³ as production. L4_128 result gates this.
2. **Build Level-10 operator-RHS export tool** (does NOT require Ueda code access yet): given ψ₀ jld2 → save (E_kin, E_trap, E_contact, E_DDI, E_Zeeman) + (Hψ) per component. This is the artifact to send Ueda lab.
3. **Package Level 1-3 explicit suites** under `runs/validation_level{1,2,3}/` so they are regression-tested, not implicit-only.
4. **Level 8 (LHY) explicit unit test**: scalar slope + coefficient — currently no dedicated test.
5. K3 discussion (Level 12) stays gated until Level 9+10 are clean.

## What changed from prior plan (2026-05-22 → 2026-05-24)

- 10 levels → 13 levels (env/reproducibility, Strang convergence, LHY broken out as explicit levels).
- A/B/C verification-type split added.
- Level 10 (Ueda comparison) restructured into 5 explicit sub-checks; image-comparison demoted.
- 10-priority + 5-Ueda-essentials lists added for ordering.
- Production Eu (Level 12) explicitly framed as "with controls" — K3-on must always have K3-off twin.

## References

- `memory/tier3_cost_economics_6_day_retrospective.md` — 6-day data showing Eu physics-sim is expensive
- `memory/hypothesis_opus_f6_spinor_retry_burn.md` — F=6 physics-sim Opus retry-burn
- `memory/established_tier3_trajectories.md` — Matsui rescued at T117 was wrong-shape; should be Level 9 not Level 12
- `memory/design_backlog_post_reform_2026_05_19.md` — 6 design items pending data
- `runs/verification_suite/README.md` — Level 0/1 docs (legacy numbering)
- `runs/verification_suite/checks/expected_observables.yaml` — Level 1 (new) / old-Level-1 pass criteria
