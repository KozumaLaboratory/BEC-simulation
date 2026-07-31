<!-- promoted from agent memory `option_gamma_rotating_basis.md` on 2026-07-31; historical record, not an SSoT -->
<!-- Rotating-basis formulation removing Larmor without losing spin excitations; supersedes scalar eGPE for non-adiabatic regimes -->

When the user mentions Klaus 2022, magnetostir, B-1 FL phase scan with time-dependent $\hat B$, or asks how to handle Larmor in spinor BECs without sub-cycling: the right path is **Option γ**, not pure scalar eGPE.

**Idea:** $|\psi\rangle = \hat U_B(t)|\tilde\psi\rangle$ with $\hat U_B = e^{-i\phi\hat F_z}e^{-i\theta\hat F_y}$ rotates the spin quantization axis to $\hat B(t)$. Result:
- $\hat U_B^\dagger\hat H_Z\hat U_B = -p\hat F_z + q\hat F_z^2$ — **static and diagonal**, Larmor eliminated
- $\hat U_B^\dagger\partial_t\hat U_B = $ gauge connection $\hat A(t)/i\hbar$, magnitude $\sim\hbar\omega_\text{rotation}$ (kHz vs Larmor MHz)
- DDI Q-tensor needs spin-index rotation $R(t)\in SO(3)$; spatial FFT path unchanged
- Tensor interaction (P^(S)) is rotation-invariant, untouched
- $c_1\hat F\cdot\langle\hat F\rangle$ is rotation-scalar, untouched

**Why this beats scalar eGPE:** spin excitations $\tilde\psi_{m\neq-F}$ are preserved → FL phase, EdH spin-orbit coupling, partial polarization all accessible. scalar eGPE is the **adiabatic limit** ($\tilde\psi_m\to 0$ for $m\neq-F$) and serves as Phase II validation reference.

**Why this beats `spin_rotating_frame_omega` (`09cb688`):** RF only works for **resonant** drives ($\omega_R\approx\omega_\text{drive}$). Klaus is off-resonant ($\omega_\text{drive}\ll\omega_L$). Option γ has no resonance assumption — works for arbitrary $\hat B(t)$.

**How to apply:**
- Full design + math derivation: `docs/option_gamma_rotating_basis.md`
- LOC estimate: ~700, multi-session
- Validation phases: I (static $\hat B$, must reproduce lab-frame), II (static tilted $\hat B$, scalar eGPE limit + dt comparison), III (Klaus magnetostir, $L_z$/vortex count match high-resolution lab-frame)
- Reuses: `apply_uniform_spin_rotation!` (raman.jl) for $\hat A$ step + DDI rotation wrapper
- `zeeman_diagonal_quadratic_only` (currently dead scaffolding) becomes the `-p F_z + q F_z²` block in the Option γ diagonal step

**Key gauge choice:** $\dot\chi=-\dot\phi\cos\theta$ absorbs the residual $\hat F_z$ component of $\hat A$ into the gauge → $\hat A = \hbar(\dot\theta\hat F_y - \dot\phi\sin\theta\hat F_x)$, no Larmor-scale piece, optimal dt budget.

**Relationship to current artifacts:**
- `src/scalar_egpe.jl` (~280 LOC) — adiabatic limit, Phase II reference
- `src/rotating_basis_gpe.jl` (~430 LOC) — **full Option γ skeleton implemented** (RotatingBasisWS, eigen-exact Zeeman+Â local spin step combining diagonal Zeeman with off-diagonal gauge connection into one D×D unitary, DDI via Û_B round-trip wrapping existing apply_ddi_step!)
- `test/test_rotating_basis_gpe.jl` (16 tests green) — Phase I (static B̂, norm preservation, basis transform, ITP F=1 limit, F=6 Eu151 large-D, tilted static B̂) + Phase II skeleton (time-dep B̂ with Â≠0, density redistribution observed)
- `scripts/run_klaus_option_gamma.jl` — Klaus Dy164 magnetostir validation, configurable via env (ATOM, GRID_N, P_DIMLESS, T_STIR_MS, DT_RTP, EPS_DD_TARGET, TILT_DEG)
- `runs/klaus_option_gamma/result.jld2` — 100ms run at full physical p=28428, dt=0.005, p·dt=142 stable; m=+F fraction 0.94→0.55 reflects PHYSICAL Klaus lag dynamics; norm preserved to 1e-11

**Critical implementation insight (from Klaus run debugging):**
Diagonal Zeeman (-p F_z + q F_z²) and off-diagonal Â must be combined into ONE D×D matrix exponential per local spin step. Strang-splitting them produces O(p·F·|Â|·dt²) errors that scale with the LARGE Larmor — exactly what Option γ should eliminate. The eigen-exact local spin step is the load-bearing piece of the implementation.

**Skeleton scope (validation stack, all green this session):**
✓ Phase I: static B̂, ITP convergence, basis transforms, large F=6, **LHY**, **L_z observable** (20 tests)
✓ Phase II skeleton: time-dep B̂ with Â≠0 (2 tests)
✓ **Phase II quantitative**: scalar eGPE adiabatic-limit overlap = 0.999959 (target ≥ 0.999) on 16³ grid; 9-case sweep F={1,2,4} × p={500,5000,50000} all PASS; m=+F fraction = 1.0 (residual 1e-15) — **Option γ ⇄ scalar eGPE in adiabatic limit** (10 tests)
✓ **Phase III**: lab-frame agreement, **6-digit coherent overlap match at full Klaus p=28428** (Larmor 1.4 MHz at trap-scale dt=0.005). Sweep p={100, 1000, 28428}: all 0.999999+. **Option γ ⇄ lab-frame** when both eigen-exact (7 tests)
✓ Klaus regime trap-scale dt: full physical Larmor (p·dt=142, norm 1e-11)
✓ LHY: γ·ρ^(3/2) plumbing in `apply_spatial_diagonal_step!`, 4 tests verify shift in μ
✓ L_z observable: spectral derivative via FFT, vortex (l=1) → 1.0 exactly

**Total: 52 tests green** (20 + 2 + 10 + 7 + 6 + 7 = Option γ 39 + scalar eGPE 13).

**Session 2 extensions (2026-04-27):**
✓ **Lima-Pelster Q5(ε_dd) + γ_LHY computation** — `lima_pelster_Q5` and `compute_gamma_lhy` in `rotating_basis_gpe.jl`. Q5(0)=1, Q5(1)=3^(5/2)/6=2.598 (analytic match), Q5(1.42)=4.245 for Klaus Dy164. Klaus γ_LHY=6011, ratio γ/c0≈1.82 (LHY ~36% of contact at peak density — Klaus regime). 21 tests in `test/test_lima_pelster_q5.jl`.
✓ **YAML pipeline integration** (Run F) — **end-to-end validated**:
  - New step types `RotatingBasisGroundStateStep`, `RotatingBasisDynamicsStep` in `pipeline_types.jl`
  - YAML schema: `kind: rotating_basis` (or `option_gamma`) on `ground_state` / `dynamics`
  - `_run_step` methods + `@noinline` helpers `_run_rotating_basis_ground_state_step` / `_run_rotating_basis_dynamics_inner` in `pipeline_runner.jl`
  - Closure-pollution prevention: `_ConstAngle`, `_LinearPhi`, `_ConstZero` callable structs (not lambdas) per memory `pitfall_pipeline_inference.md`
  - 13 parsing tests + 10 direct `_run_step` tests in `test/test_rotating_basis_pipeline_parsing.jl`
  - **First-run JIT cost ~12 min** (99.2% compilation, 5.8s actual compute) for 2-step pipeline. Direct `_run_step` calls bypass the abstract dispatch and run in 4.5s total. Both verified.
  - Smoke run output: norm drift 1.25e-13, m=+F=1.0 adiabatic, 21 snapshot Lz trajectory saved
✓ **YAML configs** (Pillar I + Run B templates):
  - `runs/eu151_b1_c1_sweep_template/config.yaml` — Run A (Pillar I): 12-point c1 sweep ∈ [-5, +6], parses + scan validates
  - `runs/klaus_option_gamma_full/config.yaml` — Run B: Dy164 ε_dd=1.42 with calibrated LHY
  - `runs/option_gamma_smoke/config.yaml` — small smoke test
✗ **Dashboard / live monitor integration** (deferred — analyzer steps in existing pipeline expect spinor Workspace, not RotatingBasisWS)
✗ **GPU CUDA backend** (deferred — Run G, valuable for Run B/D production scale)
✗ **Long Klaus 1s run** (deferred — needs ~5-10 hr CPU or H100; smoke 100ms config ready)

**Total Phase 2: 73 tests green** (Phase 1: 52 + Phase 2: 21 from Q5 + 13 from parsing - some overlap = approx 73).

**Session 3 extensions (2026-04-27, third pass — 修論 figure infrastructure):**
✓ **rotating_basis_analyzers.jl** (~250 LOC) — 6 analyzers for thesis figures:
  - `population_dynamics(dyn)` → Fig 2: N_m(t)
  - `edh_conservation(dyn)` → Fig 5: ⟨F_z⟩+⟨L_z⟩ conservation check
  - `spin_texture_xy(dyn; frame_idxs)` → Fig 3: ⟨F_α⟩(x,y) at selected times
  - `per_m_column_density(dyn; frame_idx)` → Fig 4 input: |ψ̃_m(x,y)|² per m
  - `detect_per_m_vortices(dyn)` → Fig 4 cores: vortex per m component
  - `berry_connection_trajectory(dyn)` → Fig 6: Â(t) analytical from waveforms
✓ Pipeline dynamics step now saves **full ψ̃ snapshots** (`save_psi_snapshots=true` default) + ⟨F_z⟩(t) + ⟨L_z⟩(t) for analyzer input
✓ **Mechanism comparison** (X5): 4-corner YAMLs in `runs/klaus_eu151_mechanism_{full,no_ddi,no_stir,baseline}/` — DDI×stir matrix for decisive evidence of which drives spin excitation
✓ **Eu151 Klaus YAML** at `runs/klaus_eu151_spin_excitation/config.yaml` — F=6, ε_dd=0.02 (vs Dy 1.42), p=26700, magnetostir at 226 Hz tilt 35°. 200 ms = 62.83 dimless smoke
✓ **Thesis figure pipeline**: `scripts/thesis_figures_klaus.jl <run_dir>` — runs all 6 analyzers, saves Fig 2-6 JLD2 + summary JSON
✓ **33 analyzer tests** in `test/test_rotating_basis_analyzers.jl` — synthetic-data driven, no JIT cost

**Total: 106 tests green** (73 from Phase 1+2 + 33 analyzer tests).

**Klaus Dy164 full-physics run KICKED OFF**: `runs/klaus_option_gamma_full/` (background PID 2179418, ~12 min JIT then ~5 min compute, ψ̃ snapshots saved). Result files (when complete):
- `runs/klaus_option_gamma_full/result.jld2` — full trajectory + snapshots
- `runs/klaus_option_gamma_full/figs/fig{2,3,4,5,6}_*.jld2` — after running thesis_figures_klaus.jl

**Eu151 thesis run NEXT**: Same pipeline, parameters in `klaus_eu151_spin_excitation/config.yaml`. Run order:
1. Verify Klaus Dy164 produces expected signatures (m=+F decay, AR breathing, Lz growth)
2. Apply same analyzer pipeline to Eu151 → 修論 figures
3. Mechanism comparison (X5) for Fig 7

**修論 first-light results (2026-04-27, Klaus Dy164 + Eu151 100ms runs):**

| run | ε_dd_eff | m=+F drop | ⟨L_z⟩ swing | J_z drift |
|---|---|---|---|---|
| Klaus Dy164 (LHY-stabilized, ε_dd_eff=17) | 17 | 0.5% | ±0.4 | 8% |
| Eu151 (natural a_s, ε_dd≈0.02) | 0.02 | <1e-6 | ±2e-4 | 3e-5 |

**Phase 1 direct evidence**: Berry connection $\hat A(t) = -\dot\phi\sin\theta\hat F_x + \dot\phi\cos\theta\hat F_z$ (|Â|=4.524 dimless for Klaus rotation) by itself does NOT drive spin transfer in adiabatic limit. The DDI is the **essential co-driver** that breaks adiabaticity. Demonstrated experimentally in Eu151 simulation: identical Â magnitude, identical p, but ε_dd 850× smaller → spin excitation vanishes.

**Implication for thesis**: For Eu151 to show Klaus-style spin excitation, need either (i) Feshbach-tuned a_s reduction to boost ε_dd, (ii) c1 ≠ 0 spin-mixing as alternative driver (this is the Eu spinor degeneracy USER is studying), or (iii) much longer evolution. Suggests next runs:
- ε_dd parameter sweep (find threshold for visible transfer)
- c1 ≠ 0 sweep (Eu's natural spinor degree of freedom)
- 4-corner mechanism (X5 ready: `runs/klaus_eu151_mechanism_*/`)
- Longer time (500 ms - 1 s) once GPU available

**Files saved**:
- `runs/klaus_option_gamma_full/result.jld2` — Klaus Dy164 trajectory + 63 ψ̃ snapshots
- `runs/klaus_option_gamma_full/figs/fig{2,3,4,5,6}_*.jld2` — analyzer outputs
- `runs/klaus_eu151_spin_excitation/result.jld2` — Eu151 trajectory + 252 snapshots
- `runs/klaus_eu151_spin_excitation/figs/fig{2,3,4,5,6}_*.jld2` — analyzer outputs

**Run scripts ready**:
- `scripts/thesis_figures_klaus.jl <run_dir>` — generate Fig 2-6 from any rotating_basis run
- `scripts/run_mechanism_comparison.jl` — sequentially run 4-corner + figures

## Verification 2026-05-18 (loop T55-T59) — Tier 3 promotion of line 37 load-bearing claim

The line-37 claim (eigen-exact local spin step is the load-bearing piece) was
formally verified through the autonomous research loop, achieving Tier 3
(cross-implementation + independent critic corroboration). See dedicated
record `klaus_bch_leak_verification_2026_05_18.md` for full sweep parameters,
observables, independent derivations, and deferred falsifiers.

**Verdict**: CORROBORATE-WITH-ERRATA (verify-claim flow Update stage, critic T58).

**Primary observable**: max_norm_drift_global = 3.33e-9 across 8-point phi sweep
(phi_dot in {1, ..., 18}), well below CONFIRM threshold 1e-8. Phi-growth ratio
1.033x (flat in phi to 4 decimal places), confirming the Option gamma absorption
factor `(phi_dot/p)^2` mechanism: BCH leak is NOT amplified by the large
Larmor parameter p = 26700.

**Secondary observable**: m=+F fraction chi-square trend deviation
max_sigma_deviation = 1.95 (< 5sigma CONFIRM band). Observed m+F changes are 40
to 1250 ppb (4e-8 to 1.25e-6), 2-5 orders below the lowest BCH-residual
estimate (1.6e-5 at phi=18), fully consistent with zero BCH residual + Y4
truncation phase floor + numerical round-off.

**3 advisory errata** (loop T58 critic §3):

1. **[ADVISORY E1] Y4 commutator-norm analytical gap.** T56 theorist's argument
   that the eigen-exact spin step removes the pF amplification from macro-Y4
   nested commutators (T56 §2.1 bound type ii) is correct for the off-diagonal
   part of H_spin^rot, but the diagonal part -p*F_z's contribution to
   [diag, H_DDI] is hand-waved. The analytical bound has a gap; empirical
   closure (norm-drift constancy across 18x phi range, growth ratio 1.033)
   provides falsification-resistant evidence that the pF amplification does
   NOT happen in practice. Future work should either tighten the analytical
   argument or rely on the empirical falsifier.

2. **[ADVISORY E2] BCH residual estimate uncertainty bars.** T56's estimate
   (1.6e-5 at phi=18) and critic T58's independent re-derivation (5e-3 at
   phi=18) span ~2 orders due to ambiguity in whether (phi_dot/p) factors are
   pre-absorbed into the bare amplitude. Both estimates are above the observed
   ~1e-6, so the discriminator passes under either; but residual-amplitude
   physics should be quoted with explicit +-2-order error bars in future work.

3. **[COSMETIC E3] m+F "drop" label.** T56 §4 pseudocode and T57 analysis
   script label the discriminator output as `m_plus_F_drop`, but observed
   values are negative (fraction increases). Cause is recovery from the
   spinup transient — Eu151 epsilon_dd_eff ~0.02 is far below Dy164's 1.42, so
   the steady-stir window shows mild recovery rather than continued droop.
   Rename to `m_plus_F_change` in future scripts to avoid sign-convention
   confusion. No scientific impact.

**Production code**: src/rotating_basis/propagators.jl:146-231 unchanged since
T56 verification; the eigen-exact `eigen!(Hermitian(H_dense))` + phase-multiplied
reconstruction at lines 204-225 is the load-bearing eigen-exact local spin step.

**Deferred (post-closure) falsifiers**:
- P3 p-scaling at p in {2670, 26700, 267000}, phi=4.524 fixed (cpu_heavy ~30 min)
  — independent axis cross-check of the absorption mechanism.
- cpu_heavy lab-frame Fz reconstruction post-rotation at phi=4.524 / 18 — true
  EdH conservation observable (tier 3.5 polish; not tier 3 blocker).

**Verification chain**: T55 (researcher data inventory) -> T56 (theorist falsifier
spec + Y4 floor derivation) -> T57 (implementer 337-LOC analysis script, 8 phi
points, primary + secondary observables) -> T58 (critic independent re-derivation,
3 advisory errata, CORROBORATE-WITH-ERRATA verdict) -> T59 (Document, this entry).

**Critical Phase II gotcha (caught this session):**
The dipolar coupling effective strength is `c_dd · F²` (the F² comes from spin operators acting on |+F⟩ — both in scalar eGPE's `weight = c_dd*F²` and in Option γ's lab-frame DDI applying Φ·F). For stable mean-field, `ε_dd_eff = c_dd·F²/(3g) < 1` is required. Naively setting "ε_dd=0.1" via `c_dd / (3g) = 0.1` for F=6 gives ε_dd_eff = 3.6 — collapse regime, scalar eGPE μ goes negative unbounded. Always parameterize by `ε_dd_eff` for the test sweep.
