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

State `N`, `T`; truncation `η = U/(k_B T)`. With peak density
`n₀ = N (m ω̄²/2π k_B T)^{3/2}`, `v̄ = √(8 k_B T/π m)`, elastic `σ = 8π a_s²`,
per-atom rate `γ_el = n₀ σ v̄/√2`:

- evaporation `dN/dt = -N γ_el (η-4) e^{-η}` (valid η ≳ 4),
- temperature `dT/T = (dN/N)(η+κ-3)/3` (κ ≈ 1),
- background 1-body `-N/τ_bg`, optional 3-body `-K3 ⟨n²⟩ N` (+ heating),
- gravity lowers the vertical escape barrier (shallow end-trap),
- BEC onset at `ρ = N(ℏω̄/k_B T)³ = ζ(3) ≈ 1.202`.

## Required lab inputs (from the experiment notebook)

These are not derivable and must be supplied:

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

One-call over the actual euv3 ramp (HFORT 6→0.14 W, VFORT 0→0.09 W, 2.7 s):

```julia
using SpinorBEC
res = run_euv3_evaporation(; waists=30e-6, alpha=2.0e-36, N0=2e6, T0=40e-6, tau_bg=10.0)
evaporation_summary(res)        # (; reached_bec, N_BEC, T_BEC_uK, t_BEC_s, gamma_eff, survival, peak_psd, eta_onset)
```

Optimize the ramp (3-param transform: duration / final-power / warp) for max `N_BEC`:

```julia
out = optimize_euv3_evaporation(; waists=30e-6, alpha=2.0e-36, N0=2e6, T0=40e-6, n_iter=40)
out.bo.best_p          # [duration_scale, final_power_scale, warp_γ]
evaporation_summary(out.result)
```

1-D landscape before trusting the optimizer:

```julia
trap = euv3_evap_trap(; waists=30e-6, alpha=2.0e-36)
p    = EvapParams(; a_s=Eu151.a_s, tau_bg=10.0)
scan_ramp_param(trap, p, euv3_evaporation_ramp(); index=1, values=0.5:0.5:3.0, N0=2e6, T0=40e-6)
```

Hand off the endpoint to the GP simulator (dimensionless trap, ℏ=m=ω_ref=1):

```julia
h  = bec_handoff(trap, euv3_evaporation_ramp(), res)   # (; omega_ref, omega_dimless, a_ho, N_BEC, T_BEC, T_over_Tc)
ht = harmonic_trap_dimless(trap, euv3_evaporation_ramp(), res)
# ws = make_workspace(; potential=ht, atom=Eu151, ...); find_ground_state(ws)
```

A general (non-euv3) ramp is a `FortRamp(times, powers_W)` (`n_beams × n_breakpoints`),
fed to `run_evaporation(trap, ramp, p; N0, T0)`.

## Building the ramp from control voltages

The euv3 FORT power ↔ control-voltage calibrations are transcribed:
`hfort_power(V)` / `hfort_volts(P)` (and `vfort_*`, `sfort_*`), so a ramp can be
built from logged control voltages.

## Validation status

`test/solvers/test_evaporation.jl` (fast tier): single-beam geometry vs closed
form, RHS scaling coefficient, no-loss / background-loss limits, gravity-lowers-depth,
ramp transform, BO wrapper, handoff consistency (`T_BEC = T_c` at onset), and the
euv3 ramp reaching BEC. **Verification type A/B** (code + physics-internal).
End-to-end agreement with the lab `NumberOfAtoms.csv` (type C) is `@test_skip`
until the lab inputs above are supplied — see `EvapTrap` / `run_euv3_evaporation`.

## Files

`src/solvers/evaporation/`: `trap_geometry.jl` (depth/frequencies on `GaussianBeam`),
`evaporation_model.jl` (structs + `evap_rhs`), `evaporation_solve.jl` (`FortRamp`,
RK4 `run_evaporation`, `evaporation_summary`), `evaporation_optimize.jl`
(`optimize_evaporation_ramp`, `scan_ramp_param`), `evaporation_handoff.jl`
(`bec_handoff`), `euv3.jl` (lab calibration + ramp + one-call entry points).
