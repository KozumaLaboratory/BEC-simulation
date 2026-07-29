# Day inventory — 2026-05-26

> **Vintage note.** The `runs/` results this document cites predate every
> physics correction merged after 2026-06-02 — including a quadratic Zeeman
> that was 11× too large for Eu until 2026-07-08. See
> [`stored_results_vintage_audit.md`](stored_results_vintage_audit.md) before quoting a number from here.

End-of-day manifest of artifacts produced during the
2026-05-26 BEC-simulation validation session. Provides a single
audit point: commit hash, environment, paths, cell census, and the
mapping between findings and source data.

## Environment

| | Value |
|---|---|
| Repo commit | `15a9f1ee8afe14ad79e82e9f2e2e0663994b876c` (2026-05-26 08:26:34 +0900) |
| Branch | `main` (working tree dirty — see git status for in-flight files) |
| Julia | 1.12.6 |
| CUDA driver | `/usr/lib/wsl/lib/libcuda.so.1.1` (WSL2) |
| OS | Linux 6.6.87.2-microsoft-standard-WSL2 |

## Cell census

| Batch | Total analyzed | New today | Reused (cache or earlier session) |
|---|---|---|---|
| L4 K3 ladder (64/96/128³) | 12 | 12 | 0 |
| Eu collapse search (32³) | 4 | 4 | 0 |
| Eu robust factorial (32³) | 8 | 8 | 0 |
| K3 sweep + 96³ anchor | 10 + 2 = 12 | 10 + 2 | 0 |
| K3=0 LHY control (32³) | 3 | 3 | 0 |
| K3=200 LHY interference (32³) | 4 (LHY) + 1 K3=200 baseline | 3 + 0 | 1 (cache from K3 sweep) |
| LHY long-time (64³ GPU) | 5 (50/100/200 ms × {polar, icosa}, minus icosa-200ms) | 5 | 0 |
| Matsui baseline (32³ + 64³ × 2) | 3 | 3 | 0 |
| Barnett Ω scan (32³) | 14 (9 DDI on + 5 DDI off) | 8 | 6 (cache from initial 6-cell) |
| **Total** | **65** | **58** | **7** |

Note: an earlier wrap-up message said "38 production cells run today";
the correct counts are **65 analyzed in total** with **58 new cells
executed today**. The 7 "reused" cells are cache-hits from the
in-session 6-cell Barnett seed + 1 K3=200 baseline shared across the
K3 sweep and the K3=200 LHY interference run.

## Figures (publication-ready)

```
docs/validation/figures/
├── fig1_l4_isotropic_grid_convergence.png    MAIN: cross-grid no-collapse
├── fig2_k3_sweep_cigar.png                   APPENDIX: K3-alone dose-response
├── fig3_class_map.png                        APPENDIX: K3-alone class map
├── fig4_lhy_model_interference.png           APPENDIX: 2×4 K3 × LHY factorial
├── fig5_matsui_reproduction.png              MAIN: Matsui Fig 2C reproduction
├── fig6_matsui_morphology_slices.png         MAIN: Fig 1 morphology z=0 slices
└── fig7_barnett_window.png                   NEXT: 14-cell Barnett Ω scan
```

## Source data paths

| Finding | Source files |
|---|---|
| 1. L4 isotropic no-collapse | `runs/l4_k3_ladder/summary.json` + 12 cell dirs `L4_K3_n{64,96,128}_*_<hash>` |
| 2. Matsui Fig 2C reproduction | `runs/matsui_baseline/summary.json` + `matsui_5ms_n64_density_slice.json` + 3 cell dirs |
| 3. scalar LHY ≡ off at F=6 — **evidence VACUOUS, see below** | `runs/eu_k3_lhy_control/factorial_2x4.json` (cells K3∈{0,200} × LHY=scalar vs off) |
| 4. spinor LHY closure stabilizes alone — **UNDER REVIEW, see below** | same factorial_2x4.json (K3=0 + polar/icosa rows) |

### 2026-07-29: the factorial ran under three LHY defects

Every LHY-enabled cell of `factorial_2x4.json` predates fixes that change what it
measured. Three defects, each silent:

- **#174** — the dynamics phase never resolved its own `lhy:` block. For a
  SCALAR kind that meant `interactions.c_lhy = 0`: **the dynamics ran with no
  LHY at all** while `lhy: {kind: scalar}` sat in the YAML. Being absent rather
  than wrong, it conserved energy and reported `lhy = +0` — the failure mode
  that looks exactly like success.
- **#158** — the closed-form tables were exactly `N_atoms` too large (here
  30000×), in the **propagator** as well as the energy.
- **#125** — the broadcast propagator, which the GPU always takes, dropped every
  tabulated LHY entirely.

**Claim 3 is circular.** "scalar LHY ≡ off" was read off two rows whose dynamics
both ran with scalar LHY off:

    K3=0, LHY=off      Fz_per_N = -4.2489457
    K3=0, LHY=scalar   Fz_per_N = -4.2487269

Agreement to 7 significant figures is the signature of the same physics run
twice, not of a physical equivalence. The **conclusion may well survive** — at
this gas parameter (`n_SI·a_s³ ≈ 4e-5`) a correctly-built scalar LHY is ~0.05%
of the energy, so the difference would be small anyway — but this evidence does
not establish it.

**Claim 4 is the one that may not survive.** The `stable_arrest` classification
appears only in the `polar_contact` / `icosa` rows, and those are exactly the
rows whose LHY was **30000× too strong**. The arrest may be an artefact of the
defect rather than of the closure.

Both claims are being re-measured with all three fixes in; `fig4_lhy_model_
interference.png` rests on the same factorial and inherits the same status.
| 5. K3 not primary arrest mechanism | factorial_2x4.json + `runs/eu_k3_sweep/summary.json` (10-pt K3 sweep) + `runs/eu_k3_sweep_96/summary.json` (96³ anchor) |
| LHY long-time stability | `runs/eu_lhy_longtime/` (5 cells: polar 50/100/200, icosa 50/100) |
| Barnett window | `runs/barnett_eu_window/summary.json` (14 cells) |

## Validation scripts

```
scripts/validation/
├── make_week_figures.py                    Python plotting (7 figures)
├── matsui_baseline_gen.jl                  Matsui parameter set generator
├── matsui_baseline_summary.jl              Matsui Fig 2C reproduction summary
├── matsui_density_slice_dump.jl            z=0 density slice extractor
├── eu_collapse_search_gen.jl               4-cell collapse regime search
├── eu_collapse_search_summary.jl           collapse search summary
├── eu_k3_arrest_gen.jl                     K3 arrest 8-cell factorial generator
├── eu_k3_arrest_summary.jl                 (same)
├── eu_k3_sweep_gen.jl                      10-point K3 dose-response sweep
├── eu_k3_sweep_summary.jl                  (same)
├── eu_k3_sweep_96_gen.jl                   96³ anchor for K3=150,200
├── eu_k3_sweep_96_summary.jl               (same)
├── eu_k3_lhy_gen.jl                        K3=200 LHY interference 3-cell
├── eu_k3_lhy_summary.jl                    (same)
├── eu_k3_lhy_control_gen.jl                K3=0 LHY control 3-cell
├── eu_k3_lhy_factorial_summary.jl          full 2×4 factorial
├── eu_lhy_longtime_gen.jl                  50/100/200ms × {polar, icosa}
├── barnett_eu_window_gen.jl                14-cell Barnett Ω×DDI scan
├── barnett_eu_window_summary.jl            (same)
├── barnett_week1_gen.jl                    scalar rotation sanity Ω scan
├── l4_k3_ladder_gen.jl                     12-cell L4 K3 ladder
├── l4_k3_ladder_summary.jl                 (same)
└── k3_unit_audit.jl                        K3 unit-scale audit
```

## Main claims (5 publishable)

1. **L4 isotropic Eu EdH is robustly no-collapse** across N = 64/96/128
   (12 cells; pre-dealias "64³+ collapse" intuition was a numerical
   artifact).
2. **Matsui-style loss-free simulation qualitatively reproduces Fig 2C**:
   m=−6 → m=−5 → m=−4 EdH cascade with N conserved and partial
   coherent recovery (32³/64³ cross-grid converged for spin sector).
3. **scalar LHY at F=6 is insufficient** — indistinguishable from no
   LHY in the F=6 cigar collapse stress regime (4-cell confirmation).
4. **Spinor-branch-aware effective LHY closure (polar_contact /
   icosahedral) alone gives bounded, lossless dynamics up to 200 ms**
   in the F=6 collapse stress regime. Peak hard-capped at 1.28×
   initial across 50/100/200 ms; N drift < 3 × 10⁻⁸ at 200 ms (= 138
   ω_ref⁻¹); peak rises then falls back below max — bounded
   breathing, NOT metastable plateau or delayed collapse.
5. **K3 is not the primary arrest mechanism in F=6 collapse-prone
   regimes.** K3 = 200×proxy adds 17.5% atom loss on top of proper
   LHY for marginal extra peak suppression. K3-alone arrest is
   sacrificial (≥ 65% atom loss at the K3 ≈ 200× operational
   threshold).

## Caveats (must accompany above claims)

- **Long-time stability untested beyond 200 ms.** Up to 200 ms the
  dynamics are bounded breathing; whether a slower instability mode
  appears at, e.g., 500 ms or 1 s is not yet tested.
- **Effective LHY closure ≠ full BdG LHY.** polar_contact and
  icosahedral models are constructed assuming a specific local order
  parameter (polar phase / I_h F=6 symmetric state). They are NOT a
  full nonequilibrium F=6 BdG-LHY treatment; the "lossless arrest"
  result is therefore an upper bound on the LHY contribution for
  arbitrary non-equilibrium spin textures.
- **Barnett recommendation Ω ∈ [-0.5, -0.3] depends on sign convention.**
  Under the current code's Ω sign convention and initial m=−F state,
  negative Ω gives the strong (anti-parallel-rotation) Barnett
  response. Translating to lab convention requires the sign mapping
  to be verified per-experiment.
- **External code comparison BLOCKED_EXTERNAL.** All claims rest on
  the self-contained validation chain (analytic / conservation /
  literature / reference-RHS / convergence). See
  `docs/validation/ueda_status.md`.

## N drift / Fz drift table (LHY long-time)

```
                       N(T)/N(0) − 1     Fz(0) → Fz(T)     ΔFz
polar  50 ms          −1.40 × 10⁻⁹      −6.000 → −5.342   +0.658
polar 100 ms          −5.71 × 10⁻⁹      −6.000 → −4.273   +1.727
polar 200 ms          −2.78 × 10⁻⁸      −6.000 → −4.453   +1.547
icosa  50 ms          −1.40 × 10⁻⁹      −6.000 → −5.342   +0.658
icosa 100 ms          −5.71 × 10⁻⁹      −6.000 → −4.273   +1.727
```

N drift remains below 3 × 10⁻⁸ over 200 ms (≈ 138 ω_ref⁻¹). This is
well below any meaningful physical loss; cumulative Strang dt² error
+ rounding accounts for the residual. The Fz "drift" is real EdH
transfer physics, NOT numerical drift.

## Next session priorities (anko-confirmed)

```
1. icosa_200ms — confirm polar / icosa identical trajectory persists
2. Matsui loss-on variant — experiment-side reproduction
3. Barnett 64³ anchor at Ω = -0.3 + N = 5e4 — upgrade recommendation
4. Final presentation slides + caption polish
```

YAMLs already in place:
- `runs/eu_lhy_longtime/LHY_icosahedral_200ms.yaml` (queued)
- Matsui loss-on YAMLs (Task #C, not yet generated)
- Barnett 64³ at Ω=−0.3 (Task #20-followup, not yet generated)

## 2026-05-26 evening "全部やろう" execution

Items 1-3 above dispatched same day, plus the manuscript / thesis
4-figure spec drafted to complement the 6-slide presentation outline.

### New YAML configs

```
runs/matsui_baseline/matsui_40ms_lossy_medium.yaml    K3 = 3e-40 m^6/s (factor 30, K3 sweep "delay"→"sacrificial")
runs/matsui_baseline/matsui_40ms_lossy_strong.yaml    K3 = 1e-39 m^6/s (factor 100, brackets the medium probe)
runs/barnett_eu_window/barnett_eu_omm0p3_n64_DDIon.yaml      backend: cpu (see GPU Coriolis gotcha below)
runs/barnett_eu_window/barnett_eu_omm0p3_n64_N50k_DDIon.yaml backend: cpu
```

### Dispatch in progress

- GPU queue (`/tmp/dispatch_2026_05_26.jl`, log
  `/tmp/dispatch_2026_05_26.log`): Matsui loss-on medium / strong /
  icosa 200 ms (icosa was pre-existing, just dispatched).
- CPU queue (`/tmp/dispatch_barnett_cpu_2026_05_26.jl`, log
  `/tmp/dispatch_barnett_cpu_2026_05_26.log`): Barnett 64³ anchor and
  N = 5e4 production at Ω = −0.3.

### New artifacts

```
docs/manuscript/four_figure_spec_2026_05_26.md   manuscript / thesis 4-figure layout
scripts/validation/make_manuscript_figures.py    plotting → docs/manuscript/figures/manuscript_fig{1..4}.png
docs/manuscript/figures/manuscript_fig{1..4}.png 4 figures generated from existing JSONs;
                                                 Fig 1 inset + Fig 4 overlays pending dispatch completion
```

### Bug encountered

`kind: spinor + backend: gpu + rotating_frame_omega ≠ 0` crashes in
`_apply_1d_shear_batch!` with GPU scalar indexing. Existing 32³
Barnett configs already used `backend: cpu` for this exact reason;
my initial 64³ promotion forgot. Documented as memory
`gotcha_rotating_frame_omega_gpu_scalar_indexing.md`. CPU re-dispatch
running.

### Klaus protocol pivot + 3-batch result chain

1. **Pivot** (anko 2026-05-26 evening): Klaus/Barnett scan re-aimed
   from bare-⟨F_z⟩ sustained-rotation response to 2-phase
   rotation-prep + weak-field-quench → post-quench m=−5, −4 excitation.
2. **Batch 1** (10 cells, 32³): keep_rot Ω=−0.5 surprise — P_{−5,−4}
   jumps from 0.22 (any free-hold Ω) to 0.540; DDI off / no B quench
   collapse to 0.
3. **Batch 2** (7 cells, 32³ + 64³): keep_rot Ω scan
   {−0.7,−0.5,−0.3,+0.3,+0.5}; peak at Ω=−0.5 (0.540), 8.2× sign
   asymmetry; 32³ ↔ 64³ identical to 4 digits; keep_rot DDI off → 0.
4. **Batch 3** (10 cells, 32³): 5 killer-control queues — Gate 4
   (symmetry under init m × Ω sign reversal) PASSES at 3-digit
   precision; timing decomposition shows pre-rotation is null
   (hold_only = 0.524 ≈ keep_rot 0.540); B sweep + dt/2 + N=5e4
   continuing.

### Headline finding

> **Pre-rotation is null; sustained rotation during the weak-field
> EdH-active hold drives the excitation.**  The signal is governed
> by the relative chirality of the initial spin polarization and the
> trap rotation — NOT by the absolute Ω sign.  Recommended Klaus
> experimental protocol: skip pre-rotation; quench to B_hold ≈ 2.6 nT;
> rotate during the weak-field hold only, with rotation chirality
> opposite to the initial stretched-state polarisation, at
> |Ω|/ω_⊥ ≈ 0.5 (scan 0.3–0.7).

### Acceptance gate status

| # | Gate | Result | Status |
|---|------|--------|--------|
| 1 | DDI off → 0 | 0.000 | ✅ batch 1 |
| 2 | no B quench → 0 | 0.000 | ✅ batch 1 |
| 3 | 32³ ↔ 64³ identical | 4-digit match | ✅ batch 2 |
| 4 | (init m × Ω sign) reversal symmetry | 3-digit match in both branches | ✅ batch 3 Q1 |
| 5 | dt/2 reproducibility ≤ 5% | 0.02% (keep_rot), 0.14% (baseline) | ✅ batch 3 Q4 |
| 6 | N=5e4 reproducibility | qual. PASS (P_exc +30%); enhancement N-dependent | ✅ (with caveat) batch 3 Q5 |
| Sharpening | hold_only ≈ keep_rot | 97% — pre-rotation null | ✅ batch 3 Q2 |
| Sharpening | B_hold sweep [1.3, 5.2] nT | broad sweet spot; 10 nT Zeeman-pinned | ✅ batch 3 Q3 |
| Mechanism | orbital winding ±k per Δm=∓k flip | verified, Fig K10 | ✅ batch A extraction |

### Batch 4 (in flight 2026-05-26 evening)

7 cells: 4 keep_rot grid corners (B={1.3, 5.2}×Ω={-0.3, -0.7}) +
3 rotation start-delay tests (1, 2, 5 ms). Will populate Fig K11
(robustness map) + Fig K12 (timing tolerance).

### Final artifacts

```
docs/manuscript/
├── klaus_protocol_sheet.md                    ★ 1-page experimentalist sheet
├── klaus_quench_protocol_spec_2026_05_26.md   full spec + mechanism + all batches
├── four_figure_spec_2026_05_26.md             4-figure manuscript layout
├── figures/
│   ├── manuscript_fig{1..4}.png
│   ├── klaus_quench_fig_k{1..9}.png
│   └── klaus_quench_fig_k10_mechanism.png     ★ winding mechanism
└── figures_data/
    └── klaus_quench_mode_extract.json
```

## References

- `docs/validation/self_contained_validation_report.md` — full
  validation chain narrative + 5 findings + caveats
- `docs/validation/matsui_reproduction_status.md` — Matsui parameter
  audit + Fig 2C reproduction status
- `docs/validation/weekly_presentation_outline.md` — 6-slide structure
- `docs/validation/ueda_status.md` — BLOCKED_EXTERNAL declaration
- `docs/validation/fortress_cross_check_scope.md` — FORTRESS install
  tracking doc
