# Evaporative-cooling model (¹⁵¹Eu → BEC)

> **FROZEN 2026-06-16.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

State `N`, `T`; truncation `η = U/(k_B T)`. With peak density
`n₀ = N (m ω̄²/2π k_B T)^{3/2}`, `v̄ = √(8 k_B T/π m)`, elastic `σ = 8π a_s²`,
per-atom rate `γ_el = n₀ σ v̄/√2`:

- evaporation `dN/dt = -N γ_el · evap_scale · e^{-η}(η P(2,η) − 3 P(3,η))/P(2,η)²` —
  the **all-η Luiten–Reynolds–Walraven** incomplete-gamma rate (`P(2,η)=1−e^{-η}(1+η)`,
  `P(3,η)=1−e^{-η}(1+η+η²/2)` closed form). → `~(η−3)e^{-η}` at large η, but stays
  **positive at low η** (spilling) — unlike the simple `(η−4)e^{-η}`, which goes
  unphysically negative (atoms *gained*) below η=4. `evap_scale` is a dimensionless
  calibration prefactor on the collision rate (peak-thermal `γ_el` overestimates the
  real rate for a gravity-sagged / cigar cloud),
- temperature `dT/T = (dN/N)(η+κ-3)/3 + dω̄/ω̄` (κ ≈ 1),
- background 1-body `-N/τ_bg`, optional 3-body `-K3 ⟨n²⟩ N` (+ heating),
- gravity lowers the vertical escape barrier (shallow end-trap),
- BEC onset at `ρ = N(ℏω̄/k_B T)³ = ζ(3) ≈ 1.202`.

The `dω̄/ω̄` term is **adiabatic compression/expansion heating**: a harmonic trap
obeys the adiabatic invariant `E ∝ ω̄`, so a change of trap frequency from the ramp
gives `dT/T = dω̄/ω̄` (energy balance `E = 3Nk_BT` + evaporated atoms carrying
`(η+κ)k_BT` reproduces both terms). Lowering the trap (ω̄↓) cools; re-tightening
(ω̄↑) heats, keeping `ρ` invariant under a *pure* compression — without this term a
ramp could re-tighten the trap to spike `ρ` across `ζ(3)` for free, a non-physical
path the optimizer will otherwise exploit.

## Researched tentative defaults

`euv3_defaults()` carries researched placeholder values so the model runs with no
args (`run_euv3_evaporation()`), from Miyazawa/Matsui et al. PRL 129, 223401 (2022)
(arXiv:2207.11692): ODT **1550 nm**, waists **H 31 µm / V 42 µm**, start of
evaporation **3.5×10⁶ atoms @ 50 µK**, measured BEC **5.02×10⁴ @ 349 nK**, final trap
**(97, 226, 217) Hz**. The polarizability **α ≈ 1.25×10⁻³⁶ J/(W/m²) (≈400 a.u.)** is
**calibrated** from those measured trap frequencies at the euv3 ramp-endpoint powers
(νz and νx agree) — Eu has no published 1550 nm value. `τ_bg = 15 s` is an estimate.
The evaporation ramp starts from the **loaded crossed trap** (both FORTs on; the
VFORT turn-on is trap loading, not evaporation — see `euv3_evaporation_ramp`), and
with the adiabatic-heating term and a single fitted 3-body rate `K₃ = 1.61×10⁻⁴⁰ m⁶/s`
the predicted endpoint is **N_BEC ≈ 5.0×10⁴** — matching the measured 5.02×10⁴ @ 349 nK
(`fit_euv3_K3` recovers this K₃; verification type **C**, caveat: 1-parameter K₃ fit,
Eu's 3-body rate is unmeasured). **Replace with the current euv3 r14 notebook values
when known.**

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
res = run_euv3_evaporation()                       # researched defaults
res = run_euv3_evaporation(; waists=[31e-6,42e-6,42e-6], alpha=1.25e-36, N0=3.5e6, T0=50e-6, tau_bg=15.0)
evaporation_summary(res)        # (; reached_bec, N_BEC[=NaN if !reached], T_BEC_uK, t_BEC_s, gamma_eff, survival, peak_psd, eta_onset, eta_start, cooled)

# pin α from a measured single-beam radial trap frequency:
calibrate_polarizability(; waist=42e-6, power_W=1.2, freq_Hz=217.0)
```

### Is the trap capable of runaway evaporation? — `evaporation_diagnostics`

Before optimizing the *ramp*, check whether the *trap* even supports runaway evaporation
(the ramp optimizers reshape the schedule, not the trap depth or collision rate):

```julia
trap, p = euv3_evap_trap(), EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1.61e-40)
r = run_evaporation(trap, euv3_evaporation_ramp(), p; N0=3.5e6, T0=50e-6)
evaporation_diagnostics(r, trap, p)
# (; eta_start, eta_min, collision_ratio_R, gamma_el_start, gamma_el_peak,
#    collisions_per_atom, gamma_eff, runaway)
```

On the researched euv3 defaults: `collision_ratio_R ≈ 6.4×10³` (good-to-bad collisions
≫ the ~10²–10³ runaway threshold), `collisions_per_atom ≈ 6.7×10³` (≫ the few hundred
needed — not collisionally limited), `γ_el ≈ 12 kHz`, `runaway = true`. The trap is
**collisionally excellent**; the *only* marginal quantity is `eta_start ≈ 4.5` (the
loaded depth vs `T₀ = 50 µK`, near the `eta_min = 4` floor). Real setups load at
η ~ 7–10, so if your `eta_start` comes out near 4.5 the model is likely *under*estimating
the loaded depth (raise `α`/power or lower `T₀` to match the measured loaded η).

Optimize the ramp for max `N_BEC`. Three optimizers, increasing in reach:

```julia
# (a) 3-param transform (duration / final-power / warp) via Bayesian optimization —
#     fast but a narrow family: on the experiment-matched defaults it only finds +2%.
out = optimize_euv3_evaporation(; n_iter=40)
out.bo.best_p          # [duration_scale, final_power_scale, warp_γ]

# (b) MONOTONE per-beam optimizer — the PHYSICAL evaporation family (the trap is only
#     ever lowered; each beam steps down independently). Warm-started from the lab
#     ramp's own ratios, so it can only improve. This is the trustworthy optimizer:
#     a schedule the lab can actually run. On the experiment-matched defaults it finds
#     N_BEC ≈ 3.2× the lab ramp by evaporating HARDER EARLY (steeper initial power
#     drop, at high collision rate), η staying in the valid 4.5–11 range throughout.
trap = euv3_evap_trap(); p = EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1.61e-40)
out = optimize_ramp_monotone(trap, p, euv3_evaporation_ramp(); N0=3.5e6, T0=50e-6)
out.ramp               # the optimized, monotone-decreasing FortRamp; out.fracs are the drops

# (c) per-breakpoint coordinate descent — UNCONSTRAINED (can re-tighten the trap).
#     Useful as a diagnostic, but a re-tightening path leans on the adiabatic-heating
#     term being modelled exactly; prefer (b) for a schedule to hand to the lab.
out = optimize_ramp_coordinate(trap, p, euv3_evaporation_ramp(); N0=3.5e6, T0=50e-6, free=2:8)
out.mults              # per-breakpoint power multipliers
```

### Robustness — the optimum is near a cliff

The ~3× headroom is a model prediction at a fitted `K₃` and a calibrated `α`. A
sensitivity sweep shows the **headroom ratio is robust** (~3.1–3.5×) wherever
evaporation works — across `K₃` ×0.5–1, `α` ×1.0–1.15, `τ_bg` 8–30 s. But the
*aggressive* schedule sits near two cliffs:

- **Loaded-depth floor.** Evaporation can only start if the loaded `η_start = U/(k_BT₀)`
  exceeds `eta_min ≈ 4`. At the researched defaults `η_start ≈ 4.5` — marginal (real
  setups load at η ~ 7–10, so the model likely *under*estimates the loaded depth). If
  `α` is ~15 % below calibration, `η_start < 4` and **no ramp evaporates at all** —
  check `evaporation_summary(...).eta_start` before trusting any optimization.
- **3-body cliff.** The aggressive ramp reaches high density fast; if `K₃` is ~2× the
  fit, it over-loses and may miss BEC while the gentle lab ramp still reaches it.

For a schedule that does **not** sit on a cliff, optimize the **worst case** over the
calibration-uncertainty set:

```julia
ens = param_uncertainty_ensemble(trap, p; alpha_factors=(0.95,1.1), K3_factors=(1.0,2.0))
out = optimize_ramp_monotone(trap, p, euv3_evaporation_ramp();
                             N0=3.5e6, T0=50e-6, ensemble=ens)   # max worst-case N_BEC
```

On the experiment-matched defaults (ensemble `α`×{0.95,1.1}, `K₃`×{1,2}), both the lab
ramp **and** the aggressive optimum miss BEC somewhere in the box (worst-case N_BEC = 0).
The robust schedule keeps essentially the full headroom (nominal 1.56×10⁵ ≈ 3.1×, vs the
aggressive 1.57×10⁵) **and** reaches BEC across the whole box (worst-case ≈ 8.5×10⁴) —
the cliff was a narrow basin, so the robustness costs < 1 % of peak atoms. Keep
`alpha_factors` above the `η_start = eta_min` floor, or every member fails by construction.

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
res = run_evaporation(trap, ramp, EvapParams(; a_s=Eu151.a_s, tau_bg=15, K3=1.61e-40); N0=3.5e6, T0=50e-6)

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
