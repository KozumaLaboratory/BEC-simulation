# Evaporative-cooling model (¹⁵¹Eu → BEC)

A 0-D truncated-Boltzmann model of evaporative cooling in the crossed optical
dipole trap (FORT), for **simulating and optimizing the BEC-preparation ramp**.

## What it is / is not

This is a **thermal-gas kinetic model** (scalar `N(t)`, `T(t)` ODEs), NOT a
Gross–Pitaevskii simulation. GP/SGPE describes the condensate (T ≈ 0 mean field);
the evaporation that *produces* the condensate is collisional thermal-cloud
physics, which GP cannot represent. Accordingly:

- **In scope:** evaporation dynamics in the final FORT (`N(t)`, `T(t)`,
  phase-space density `ρ(t)`), the BEC atom number `N_BEC`, efficiency, and
  Bayesian optimization of the FORT power ramp.
- **Out of scope:** MOT / laser cooling / FORT loading (not a condensate), and
  any condensate dynamics — for those use the GP path. Use `bec_handoff` to pass
  the evaporation endpoint into the GP simulator.

Model: Luiten–Reynolds–Walraven PRA 53, 381 (1996); O'Hara et al. PRA 64, 051403
(2001); Olson et al. PRA 88, 043426 (2013).

## Physics

State `N`, `T`; truncation `η = U/(k_B T)`. Every rate is a **parameter-free** 3-D harmonic
truncated-Boltzmann form (Luiten–Reynolds–Walraven PRA 53 381; O'Hara PRA 64 051403; Gehm thesis
§2.4.2), via the regularized lower incomplete gammas `P(a,η) = 1 − e^{-η}Σ_{k<a}η^k/k!` (elementary
at integer a). With the untruncated peak `n_pk = N(m ω̄²/2π k_B T)^{3/2}`, the LRW **reference**
density `n₀ = n_pk/P(3,η)`, `v̄ = √(8 k_B T/π m)` (mean relative speed, no extra 1/√2), and
`σ = 8π a_s²/(1+k²a²)` (s-wave + unitarity correction):

- **evaporation** `dN/dt = −N · n₀ σ v̄ · e^{-η}(η − 4 P(4,η)/P(3,η))` (LRW Eq 37 + 42a). → `(η−4)e^{-η}`
  at large η; stays positive at low η where the crude `(η−4)e^{-η}` goes unphysically negative;
  clamped to 0 when `V_ev = η P(3,η) − 4 P(4,η) ≤ 0` (the trap can no longer eject — the
  first-principles replacement for a hard η floor). **No free prefactor** — the rate is fixed once
  `n₀` and `σ` are known.
- **temperature** `dT/T = (dN/N)·L + dω̄/ω̄`, EXACT energy-balance `L = (ε_ev − c)/(c − η dc/dη)`:
  each evaporated atom carries `ε_ev = η + 1 − P(5,η)/V_ev`; the cloud's mean energy per atom is
  `c(η) = 3 P(4,η)/P(3,η)` (→3). → `(η−2)/3` at large η (O'Hara); **grows at low η** (a truncated
  cloud's reduced heat capacity `c − η dc/dη` cools it more per atom lost — this replaced a
  hand-tuned η<1 spilling patch).
- **three-body** `dN/dt = −3 K₃ ⟨n²⟩ N`, `⟨n²⟩ = n_pk²/3^{3/2}` (atoms-lost convention) +
  antievaporation heating `dT/T = −(1/3) dN/N` (derived: 3-body removes the densest/coldest atoms);
  + background 1-body `−N/τ_bg`; + optional technical heating `Γ_h` (measurable, default 0).
- gravity lowers the vertical escape barrier (shallow end-trap); BEC onset at `ρ = N(ℏω̄/k_B T)³ = ζ(3)`.

There is **no fit parameter** — the former `evap_scale`, `κ`, and η<1 spilling patch were removed;
`K₃` is the ab-initio universal-van-der-Waals value (below), not a fit.

The `dω̄/ω̄` term is **adiabatic compression/expansion heating** (adiabatic invariant `T ∝ ω̄`),
added SEPARATELY from the fixed-depth evaporation `L`. On a fixed-η lowered-ODT trajectory
(ω̄²∝U∝T ⇒ dω̄/ω̄ = ½ dT/T) the two combine to O'Hara's `2(η'−3)/3` (Gehm Eq 2.32) — the separation
is exact, not double-counted. Lowering the trap cools; re-tightening heats, keeping `ρ` invariant
under a pure compression — without this term the optimizer could re-tighten to spike `ρ` for free.

## Researched tentative defaults

`euv3_defaults()` carries researched placeholder values so the model runs with no
args (`run_euv3_evaporation()`), from Miyazawa/Matsui et al. PRL 129, 223401 (2022)
(arXiv:2207.11692): ODT **1550 nm**, waists **H 31 µm / V 42 µm**, start of
loaded **3.5×10⁶ atoms @ 18 µK** (2023 notebook, the epoch the ramp comes from — pairing it with
the 2022 PRL 50 µK was epoch-mixing that drove η_start≈2 and inflated a fitted K₃), measured BEC
**5.02×10⁴ @ 349 nK**, final trap **(97, 226, 217) Hz**. The polarizability **α = 5.88×10⁻³⁷ J/(W/m²)
(≈189 a.u.)** is the Eu ⁸S₇/₂ atomic constant (2021 thesis; the depth and frequency anchors agree
when each is evaluated at its own powers). `τ_bg = 15 s` is an estimate.

The three-body rate is **ab-initio**, not a fit: Eu's K₃ is unmeasured, so we use the universal
van-der-Waals law `K₃ = 3C ℏa⁴/m` (Braaten–Hammer), `C∈[0,67]` log-periodic. For a=110a₀ a typical
non-resonant `C≈7` gives **`K₃ ≈ 1×10⁻⁴¹ m⁶/s`** (band `10⁻⁴²…10⁻⁴⁰ m⁶/s`; Eu is only marginally
universal, a/r_vdW≈1.3, so order-of-magnitude). The model therefore **PREDICTS** the endpoint: across
the K₃ band the predicted N_BEC spans ~5×10⁴…10⁶ and brackets the measured 5.02×10⁴, which sits at
the high-loss (high-K₃) edge (verification type **C**, honest prediction — no tuned identity).

## Required lab inputs (from the experiment notebook)

> **Calibration data by epoch** (2022 paper / 2023 notebooks / now) is collected in
> [`eu_evaporation_calibration.md`](eu_evaporation_calibration.md). The trap drifts
> between epochs — validate against the 2022 paper, but optimize against fresh
> current-setup measurements; do **not** mix epochs (it caused a spurious α conflict).

These override the researched defaults and pin the model to the current setup:

| Input | Meaning |
|---|---|
| FORT **waists** `w₀` (H, V, S) [m] | 1/e² radii at focus |
| FORT **wavelength** `λ` [m] | e.g. 1064 nm |
| Eu scalar **polarizability** `α` [J/(W/m²)] | sets depth `U₀ = α·2P/(πw₀²)` |
| **N₀**, **T₀** after FORT loading | evaporation start |
| **vacuum lifetime** `τ_bg` [s] | 1-body loss |
| Eu **K₃** [m⁶/s] (optional) | 3-body loss; default 0 |
| measured **BEC atom number** | validation only (`NumberOfAtoms.csv`) |

`mass`, `a_s = 110 a₀`, `F = 6` come from `Eu151`.

## Usage

One-call over the euv3 evaporation ramp (from the loaded crossed trap: HFORT 4→0.14 W,
VFORT 1.8→0.09 W, 2.4 s; pass `from_loaded=false` for the raw logged schedule incl. the
VFORT turn-on). With no args it uses the researched defaults; override with lab values:

```julia
using SpinorBEC
res = run_euv3_evaporation()                       # researched defaults (ab-initio K₃, prediction)
res = run_euv3_evaporation(; waists=[31e-6,42e-6,42e-6], alpha=5.88e-37, N0=3.5e6, T0=18e-6, tau_bg=15.0)
evaporation_summary(res)        # (; reached_bec, N_BEC[=NaN if !reached], T_BEC_uK, t_BEC_s, gamma_eff, survival, peak_psd, eta_onset, eta_start, cooled)

# pin α from a measured single-beam radial trap frequency:
calibrate_polarizability(; waist=42e-6, power_W=1.2, freq_Hz=217.0)
```

### Is the trap capable of runaway evaporation? — `evaporation_diagnostics`

Before optimizing the *ramp*, check whether the *trap* even supports runaway evaporation
(the ramp optimizers reshape the schedule, not the trap depth or collision rate):

```julia
trap, p = euv3_evap_trap(), EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1e-41)
r = run_evaporation(trap, euv3_evaporation_ramp(), p; N0=3.5e6, T0=18e-6)
evaporation_diagnostics(r, trap, p)
# (; eta_start, eta_min, collision_ratio_R, gamma_el_start, gamma_el_peak,
#    collisions_per_atom, gamma_eff, runaway)
```

On the defaults the trap is **collisionally excellent** (good-to-bad collision ratio ≫ the
runaway threshold; not collisionally limited; `runaway = true`). At the re-anchored `T₀ = 18 µK`
(the 2023 epoch of the ramp) `eta_start ≈ 5.7` — physical (real ODTs load at η ~ 5–10). The earlier
`eta_start ≈ 2` was the epoch-mixing symptom (2023 ramp paired with the 2022 `T₀ = 50 µK`); check
`evaporation_summary(...).eta_start` lands in 5–10 before trusting any optimization.

Optimize the ramp for max `N_BEC`. Three optimizers, increasing in reach:

```julia
# (a) 3-param transform (duration / final-power / warp) via Bayesian optimization —
#     fast but a narrow family: on the experiment-matched defaults it only finds +2%.
out = optimize_euv3_evaporation(; n_iter=40)
out.bo.best_p          # [duration_scale, final_power_scale, warp_γ]

# (b) MONOTONE per-beam optimizer — the PHYSICAL evaporation family (the trap is only
#     ever lowered; each beam steps down independently). Warm-started from the lab
#     ramp's own ratios, so it can only improve. This is the trustworthy optimizer:
#     a schedule the lab can actually run. It evaporates HARDER EARLY (steeper initial
#     power drop, at high collision rate), η staying in the valid ~5–11 range throughout.
trap = euv3_evap_trap(); p = EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1e-41)
out = optimize_ramp_monotone(trap, p, euv3_evaporation_ramp(); N0=3.5e6, T0=18e-6)
out.ramp               # the optimized, monotone-decreasing FortRamp; out.fracs are the drops

# (c) per-breakpoint coordinate descent — UNCONSTRAINED (can re-tighten the trap).
#     Useful as a diagnostic, but a re-tightening path leans on the adiabatic-heating
#     term being modelled exactly; prefer (b) for a schedule to hand to the lab.
out = optimize_ramp_coordinate(trap, p, euv3_evaporation_ramp(); N0=3.5e6, T0=18e-6, free=2:8)
out.mults              # per-breakpoint power multipliers
```

### Robustness — the optimum is near a cliff

The headroom is a model prediction at the ab-initio `K₃` and the atomic-constant `α`. A
sensitivity sweep shows the **headroom ratio is robust** wherever evaporation works — across the
`K₃` band, `α` ×1.0–1.15, `τ_bg` 8–30 s. But the *aggressive* schedule sits near two cliffs:

- **Loaded-depth floor.** Evaporation can only start if the loaded `η_start = U/(k_BT₀)` exceeds
  `eta_min ≈ 4`. At the re-anchored `T₀ = 18 µK` `η_start ≈ 5.7` (physical), but if `α`/power is
  ~30 % below calibration `η_start < 4` and **no ramp evaporates at all** — check
  `evaporation_summary(...).eta_start` before trusting any optimization.
- **3-body cliff.** The aggressive ramp reaches high density fast; if `K₃` is ~2× the
  fit, it over-loses and may miss BEC while the gentle lab ramp still reaches it.

To hedge the calibration-uncertainty set explicitly, optimize the **worst case** over it:

```julia
ens = param_uncertainty_ensemble(trap, p; alpha_factors=(0.95,1.1), K3_factors=(1.0,2.0))
out = optimize_ramp_monotone(trap, p, euv3_evaporation_ramp();
                             N0=3.5e6, T0=18e-6, ensemble=ens)   # max worst-case N_BEC
```

With the first-principles model (re-anchored `T₀=18µK` ⇒ `η_start≈5.7`, ab-initio `K₃`) the
operating point sits comfortably in the runaway regime, so the aggressive optimum is **already
robust**: over the operational-error set below the worst-case `N_BEC` (7.8×10⁵) equals the nominal
optimum and the robust optimizer returns the SAME schedule — there is no cliff to hedge in the ±10%
band (`optimize_ramp_robust` still confirms it). The old model's cliff (worst-case → 0) was largely
an artifact of the epoch-mixed `η_start≈2` sitting on the `eta_min` floor. A cliff only reappears if
`α`/power drops ~30 % (η_start < 4) — keep `alpha_factors` above that floor.

### Robust to apparatus operating errors — `optimize_ramp_robust`

`param_uncertainty_ensemble` hedges only the *physics* calibrations (`α`, `K₃`). The
things the **lab actually gets wrong shot-to-shot** are operational: absolute FORT-power
calibration, beam-to-beam power imbalance, ramp timing, and the scatter of the loaded
`(N₀, T₀)`. An [`EvapScenario`](@ref) generalizes an ensemble member to carry all of
these, [`robustness_scenarios`](@ref) builds the uncertainty set from per-axis
tolerances, and [`optimize_ramp_robust`](@ref) maximizes the worst-case `N_BEC` over it:

```julia
scs = robustness_scenarios(trap, p; N0=3.5e6, T0=18e-6,
    power_frac=0.10,      # absolute DEPTH calibration: power ~3% ⊕ waist→depth ~4–6%
    imbalance_frac=0.02,  # H-vs-V power split (crossed-ODT beam ratio held to ~0.5–1%)
    T0_frac=0.04,         # loaded-temperature scatter (2–4% shot-to-shot)
    N0_frac=0.03)         # loaded-number scatter (2–3% shot-to-shot)
                          # timing DROPPED: ns ARTIQ grain / 2.7 s ramp ≈ 1e-8, never relevant
out = optimize_ramp_robust(trap, p, euv3_evaporation_ramp();
    N0=3.5e6, T0=18e-6, scenarios=scs)
out.worst                 # worst-case N_BEC across the whole envelope (>0 ⇒ all reach BEC)
robustness_report(trap, p, out.ramp; N0=3.5e6, T0=18e-6, scenarios=scs)   # per-axis breakdown
```

**Tolerances are a cited error budget**, not guesses: absolute power at the atoms ~3 %
(Huntemann arXiv:1602.03908), beam-waist→depth ~4–6 % (Sr arXiv:2606.00242 quotes 3.8 %
on U₀; depth ∝ 1/w²), crossed-ODT beam ratio ~0.5–1 % (μXODT arXiv:2408.07187), T₀/N₀
2–4 %/2–3 % shot-to-shot (Szmuk arXiv:1502.03864). **Ramp timing is deliberately excluded**
— a nanosecond ARTIQ/DDS grain over a multi-second ramp is ~10⁻⁸ fractional, 6–8 orders
below every other axis.

**Key structural fact** (verified to 11 digits): the optical depth is `∝ αP`, so a
common-mode −`power_frac` power error is *identical* to `α×(1−power_frac)` — the same
depth cliff. The `power_frac` axis therefore is BOTH the polarizability-α and the
absolute-power/waist depth-calibration axis (the dominant one); `imbalance_frac` is the
genuinely new axis (per-beam, which `α` cannot reach). The scenario set is
**one-axis-at-a-time** (linear in the number of axes, not the exponential box of joint
corners): the worst case for each cliff is that axis's own adverse extreme, so a per-axis
set protects every cliff without over-pessimizing on rare joint corners.

1-D landscape before trusting the optimizer:

```julia
trap = euv3_evap_trap(; waists=30e-6, alpha=2.0e-36)
p    = EvapParams(; a_s=Eu151.a_s, tau_bg=10.0)
scan_ramp_param(trap, p, euv3_evaporation_ramp(); index=1, values=0.5:0.5:3.0, N0=2e6, T0=40e-6)
```

Hand off the endpoint to the GP simulator (dimensionless trap, ℏ=m=ω_ref=1) and build
the actual Eu F=6 BEC ground state — the full "to BEC" pipeline:

```julia
trap, ramp = euv3_evap_trap(), euv3_evaporation_ramp()
res = run_evaporation(trap, ramp, EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1e-41); N0=3.5e6, T0=18e-6)

kw  = bec_workspace_kwargs(trap, ramp, res)   # (; potential, atom, interactions, N_BEC, c0, a_ho, omega_dimless)
grid = make_grid(GridConfig((32,32,32), (16.0,16.0,16.0)))
gs  = find_ground_state(; grid, kw.atom, interactions=kw.interactions, potential=kw.potential,
                        dt=0.001, n_steps=2000)   # gs.workspace.state.psi is the Eu F=6 condensate
```

`c0 = bec_gp_coupling(N_BEC, a_ho) = 4π N a_s / a_ho`; `c1 = 0` by default (the Eu spin
channels are unknown, so this is a c₀-only BEC). For the lower-level handoff use
`bec_handoff` (`; omega_ref, omega_dimless, a_ho, N_BEC, T_BEC, T_over_Tc`) or
`harmonic_trap_dimless`.

A general (non-euv3) ramp is a `FortRamp(times, powers_W)` (`n_beams × n_breakpoints`),
fed to `run_evaporation(trap, ramp, p; N0, T0)`.

## Building the ramp from control voltages

The euv3 FORT power ↔ control-voltage calibrations are transcribed:
`hfort_power(V)` / `hfort_volts(P)` (and `vfort_*`, `sfort_*`), so a ramp can be
built from logged control voltages.

## Validation status

`test/solvers/test_evaporation.jl` (fast tier): single-beam geometry vs closed
form, RHS scaling coefficient, no-loss / background-loss limits, gravity-lowers-depth,
**adiabatic invariant** (`T ∝ ω̄`, `ρ` conserved under pure compression; recompression
≠ BEC), ramp transform, BO wrapper, handoff consistency (`T_BEC = T_c` at onset), and
the euv3 ramp reaching BEC. **Verification type A/B** (code + physics-internal).
`test/solvers/test_evaporation_tools.jl` (ci tier): optimizers (3-param BO, per-beam
monotone, coordinate descent) + `fit_euv3_K3`. End-to-end agreement with the lab
`NumberOfAtoms.csv` (type C) beyond the K₃ fit is `@test_skip` until further lab
inputs are supplied — see `EvapTrap` / `run_euv3_evaporation`.

## Files

`src/solvers/evaporation/`: `trap_geometry.jl` (depth/frequencies on `GaussianBeam`),
`evaporation_model.jl` (structs + `evap_rhs`, incl. adiabatic-heating term),
`evaporation_solve.jl` (`FortRamp`, RK4 `run_evaporation`, `evaporation_summary`,
`evaporation_diagnostics`),
`evaporation_optimize.jl` (`optimize_ramp_monotone`, `optimize_ramp_coordinate`,
`optimize_evaporation_ramp`, `scan_ramp_param`), `evaporation_handoff.jl`
(`bec_handoff`), `euv3.jl` (lab calibration + ramp + one-call entry points).
