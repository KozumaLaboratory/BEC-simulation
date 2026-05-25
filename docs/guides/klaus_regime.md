# Klaus / fast-Larmor regime

When the linear Zeeman energy `p` dominates everything else (Eu151 at 1 G → p ≈ 26 700; Dy164 at 1 G → p ≈ 28 400), the lab-frame split-step collapses. This page is the one place to read for "how do I run an experiment in this regime in this code".

## The problem in one sentence

`exp(-i p F_z dt)` requires `p · F · dt < π` for the Zeeman substep to not over-rotate; at Eu p=26 700 and F=6 that means `dt < 2 × 10⁻⁵` — infeasible (one trap period would take 50 000 steps).

## The solution in one sentence

Use `kind: rotating_basis` (a.k.a. Option γ): solve in the instantaneous local frame `|m⟩_{B̂(t)}`, which makes the Larmor phase static (`-p F_z + q F_z²` becomes diagonal and time-independent), so `dt` is bound by the trap scale instead.

## YAML template

```yaml
pipeline:
  - ground_state:
      kind: rotating_basis
      atom: Eu151
      grid: {n: [48, 48, 24], box: [12.0, 12.0, 6.0]}
      interactions: {N_atoms: 50000, omega_ref: 691.15}
      ddi: {enabled: true}
      B:                       # unified Zeeman block (:spherical coord)
        B_mag: 1.0             # Gauss
        theta_deg: 0
        phi_deg: 0
      potential: {type: harmonic, omega: [1.0, 1.0, 1.182]}
      epsilon: 1.0e-6          # required — see "ε rule" below
      backend: gpu

  - dynamics:
      duration: 1.0            # ~1.45 ms
      epsilon: 1.0e-6
      B_direction:             # rotating-frame B̂(t) trajectory
        theta: {from: 0, to: 0.611}     # 0 → 35°, in radians
        phi:   {rate: 4.524}            # = 226 Hz at ω_ref = 2π·50 Hz
      save: {every: 100}
```

## Hard constraint: `epsilon: 1.0e-6` is mandatory

Empirical finding (audit 2026-04-28): with the default `ε = 1e-3` and `p · F · dt > 100`, the Yoshida-6 splitting silently fails. `p_3000` ran 0.997 → 0.106 (spurious depolarisation) at `ε = 1e-3` but 0.997 → 0.999 at `ε = 1e-6`. The rotating-basis runner now hard-errors when `epsilon ≥ 1e-3` and `p · F · dt > π`. Always set `epsilon: 1.0e-6` for Klaus-class runs.

## How to specify B(t)

### Pick a coord system

Three equivalent ways to write the field, pick whichever matches your
mental model. The B-block builder auto-detects from keys; mixing across
coord systems in a single block raises `ArgumentError`.

| coord | Form | When to use |
|---|---|---|
| `:dimless`   | `p, q, bx, by`                  | physics-level testing, scans of c₁/c₀ |
| `:cartesian` | `Bx, By, Bz` (Gauss / strings)  | Cartesian lab convention |
| `:spherical` | `B_mag, theta_deg, phi_deg`     | tilt/stir experiments |

Calibration block (`p_mv` + `coil_mode`) auto-converts to a Gauss
`B_mag` value before reaching the parser.

### Unit pitfall: `phi_omega` is dimensionless ω/ω_ref, not Hz

The `B_direction.phi: {rate: X}` form takes a dimensionless rate. Klaus
226 Hz at ω_ref = 2π·50 Hz is `4.524`, not `226`. Use the Hz string
form (`"226 Hz"`) if you want the system to do the conversion. The
dimensionless form silently runs at 36× the intended frequency — this
costs an evening if you miss it.

## DDI behaviour in the Klaus regime

Because Larmor `p` ≫ DDI mean-field, every full-DDI off-diagonal oscillates at ω_L and Larmor-averages to zero. This is the **secular limit**. The runner emits an `@info` advisory when `ω_L / (c_dd · ⟨n⟩) > 100` — almost always true for Eu experiments. Set `ddi: {secular: true}` to make it explicit. **`spin_rotating_frame_omega ≠ 0` requires `secular_ddi=true`** (enforced as `ArgumentError` because non-secular DDI off-diagonals don't average out under that frame).

## Validation: this is trusted

Phase II (static tilted B̂, F=1, p=5000, 30°) overlap with scalar eGPE adiabatic limit:

| F | p | overlap | density overlap |
|---|---|---|---|
| 1, 2, 4 | 500 — 50 000 | ≥ 0.9995 | 1.0 |

Phase III (full Klaus magnetostir, dynamic B̂(t)) vs lab-frame eigen-exact solver at trap-scale dt:

| p | coherent overlap |
|---|---|
| 100 | 1.000000 |
| 1000 | 0.999964 |
| **28 428 (Klaus full)** | **0.999999** |

Tests: `test/test_rotating_basis_phase_ii.jl` (10 tests), `test/test_rotating_basis_phase_iii.jl`. Validation drivers: `scripts/archive/validate_phase_ii_overlap.jl`, `scripts/archive/validate_phase_iii_lab_vs_gamma.jl`.

**Important gauge note.** Equivalence between rotating-basis and lab-frame requires `gauge_fix=false`. With `gauge_fix=true` (the rotating_basis default) the dynamics are still correct, but `ψ_lab(T) ≠ U_B(T) ψ̃(T)` directly — recovering lab state needs a residual `exp(+i χ F_z)`. Caveat applies only when comparing against lab-frame ground-truth code.

## When **not** to use rotating_basis

- Static low-field problems (`p < 100`): lab-frame `kind: spinor` is fine, no benefit from the basis change.
- Multi-component spinor where `c₁ ≠ 0` matters at the spin-mixing scale and no fast Larmor exists: lab-frame spinor is more direct.
- Off-resonant Raman drives where you specifically want lab-frame oscillating envelopes: `spin_rotating_frame_omega` (resonant frame) is a targeted alternative — it bypasses Larmor sub-cycling for one resonant tone, while rotating_basis bypasses it for arbitrary B̂(t).

## Mixed precision

`dtype: f32` on rotating_basis works end-to-end (Eu thesis runs validated). First-time JIT for the F32 specialisation is ~10 min then cached. Some scalar Float64 boundaries remain inside `apply_uniform_spin_rotation!` + `apply_ddi_step!` + `apply_spin_mixing_step!` (rotation builder, DDI dt scalar, c1·dt scalar) — array work stays F32. See `design/mixed_precision_design.md` for the rollout history.

## Why this works (abbreviated)

The lab Hamiltonian `H = T + V + (-p F̂·B̂(t) + q (F̂·B̂(t))²) + H_int[ψ]` becomes, under `|m⟩_{B̂(t)} = U_B(t) |m⟩_z` with `U_B(t) = exp(-i φ(t) F_z) exp(-i θ(t) F_y)`,

```
H̃ = T + V + (-p F_z + q F_z²) + H_int[ψ̃] − Â(t)
```

where `Â(t) = ℏ[θ̇ F_y + φ̇ (cos θ F_z − sin θ F_x)]` is the gauge-connection term — its magnitude is `ℏ · ω_rotation`, ~3 decades smaller than `ℏ · ω_Larmor` for Klaus 226 Hz at Eu 1 G. Strang error on `Â · dt` is well controlled at trap-scale dt.

DDI: the lab kernel `Q_ab(r) = δ_ab − 3 r̂_a r̂_b` is unchanged in real space; under `U_B` the spin indices rotate via `R(t) ∈ SO(3)`. We wrap the existing DDI step with a uniform spin rotation (`apply_uniform_spin_rotation!`) pre-/post-step. The FFT path is untouched.

For the full derivation (term-by-term Hamiltonian transform, gauge freedom, scalar-eGPE adiabatic limit) see `design/option_gamma_rotating_basis.md`.

## What was tried before

Path A (single-axis `B_z` only) — earlier rotating-frame attempt that transformed away the dominant `-p F_z` term but couldn't handle a time-dependent `B̂(t)`. Superseded by Option γ. See `git log -- docs/archive/spin_larmor_frame.md` if the original design note is needed.
