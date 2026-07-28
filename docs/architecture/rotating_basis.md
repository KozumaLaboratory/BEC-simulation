# Rotating-basis (Klaus-regime) support — layer map

**There is no rotating-basis engine.** It was retired 2026-06-21
(`refactor(rotating_basis)!: retire the RotatingBasisWS engine`, −2580 lines).
`kind: rotating_basis` is now a *pipeline step kind* that runs on the standard
lab-frame split-step path; only the setup conventions and the reporting frame
are its own.

Everything below describes the code as it exists. For the design history — the
Phase I/II/III decomposition, `RotatingBasisWS`, `split_step_rotating!`,
`find_ground_state_rotating!` — see `docs/design/option_gamma_rotating_basis.md`
and `docs/design/rotating_basis_unification.md`. Those names no longer exist in
`src/`.

## Why the engine was retired

The rotating basis removed Larmor precession analytically via the gauge
transform $|\psi\rangle = \hat U_B(t)|\tilde\psi\rangle$ with
$\hat U_B(t) = e^{-i\varphi(t) F_z} e^{-i\theta F_y}$, at the cost of a
rotating-frame inertial term $-\dot\varphi F_z$.

That term is exactly where a sign/coefficient drift hides, and one was there.
The arbitration (`test/rotating_basis/test_magnetostir_rotating_field_analytic.jl`):
with `c1 = c_dd = 0` the spin sector is a single-particle problem, so per-m
populations must equal the exact evolution of $H(t) = -p\,(\hat B(t)\cdot F)$.
Measured against that reference,

| path | error |
|---|---|
| retired rotating engine | **1.8e-3** (dt-independent, DDI-independent ⇒ a Hamiltonian difference) |
| unified lab-frame path | **6.2e-6** |

The migration was a correctness improvement, not just a refactor. Meanwhile
`split_step_midpoint!` reproduces the rotating `yoshida6` magnetostir to ~1e-5
per-m at the same dt and step count, so the cost argument for a separate engine
had also gone.

## What `kind: rotating_basis` does now

| step | file | behaviour |
|---|---|---|
| `ground_state` | `pipeline/run_step_rotating/ground_state.jl` | standard ITP (`split_step!`) from a Gaussian seed under a **static** tilted field $\hat B=(\theta_0,\varphi_0)$, built as a `TimeDependentZeeman` with constant waveforms |
| `dynamics` | `pipeline/run_step_rotating/dynamics.jl` | standard `split_step_midpoint!` under a lab-frame `TimeDependentZeeman` with $\hat B(t)=(\theta(t),\varphi(t))$ |
| waveforms | `pipeline/run_step_rotating/waveforms.jl` | concrete callable structs for const / ramp / chirp $\theta$ and $\varphi$ (not closures — see `pitfall_pipeline_inference`) |
| dispatch | `pipeline/run_step_rotating/dispatch.jl` | `_run_step(::RotatingBasis*Step)` |
| analyzers | `workflow/experiments/analyzers/rotating_basis.jl` | operate on the `:rotating_basis_dynamics` Dict |
| save | `workflow/io/save_rotating_result.jl` | JLD2 layout for that Dict |

The GS hands off a plain `NamedTuple` (couplings + `sm` + tilde-basis ψ), not a
workspace object.

## The reporting frame — the one real trap

`kind: rotating_basis` records observables in the **tilde (field-following)**
frame, $\tilde\psi = \hat U_B(t)^\dagger \psi_{\text{lab}}$:

* `:per_m_history` — populations along the **instantaneous field**.
* `:Fz` — $\sum_m m\,|\tilde\psi_m|^2 = \langle F\cdot\hat B(t)\rangle$.
* `:psi_snapshots` — $\tilde\psi$, not $\psi_{\text{lab}}$.
* `:Lz` — lab-frame, computed on $\psi_{\text{lab}}$ (⟨L_z⟩ is invariant under
  the spatially uniform spin rotation $\hat U_B$, so no transform is needed).

**`:Fz` is not the axial magnetisation.** For a field rotating in the xy-plane
the tilde z-axis is perpendicular to the lab z-axis, and the two numbers differ
by a large factor — in the parity fixture, +1.95 versus +0.44. Any study whose
observable is magnetisation *along the rotation axis* (Einstein-de Haas,
Barnett) must transform back: `_apply_UB!(psi, sm, θ(t), φ(t), ndim)` on a saved
snapshot, then `spin_density_vector`. Both facts are pinned by
`test/rotating_basis/test_rotating_basis_standard_parity.jl`.

`:Fx` and `:Fy` in that Dict are **placeholders written as 0.0** — they are not
measured. Do not read them.

## rotating_basis vs the standard spinor path

Same Hamiltonian, same lab-frame time-dependent Zeeman. Differences:

| | `kind: rotating_basis` | `kind: spinor` |
|---|---|---|
| propagator | `split_step_midpoint!` | leapfrog loop → `split_step!` |
| field spec | `B: {p, q}` + `B_direction: {theta, phi}` (constant magnitude, direction rotates) | `B: {Bx, By, Bz}` in Gauss, each a waveform |
| observables | tilde frame (above) | lab frame |
| ψ snapshots | $\tilde\psi$ | $\psi_{\text{lab}}$ |

Measured agreement (parity gate, F=2, with and without DDI): per-m to **<1e-6**,
lab ⟨F_z⟩ to **<1e-6**. A term-level drift would land far above that.

Equivalent field specs: `theta: π/2, phi: {rate: Ω}` on the rotating path equals
`Bx: sin(Ωt + π/2)`, `By: sin(Ωt)` on the standard path — note
`SinusoidalWaveform` is **sin**, so a `+π/2` phase on Bx gives $\hat B(0)=+\hat x$.

## When to use which

Use **`kind: spinor`** by default, including for rotating fields. Its
observables are already in the lab frame, which is the frame nearly every
physical claim is stated in.

Use **`kind: rotating_basis`** when the natural question is about the spin
relative to the field — per-m populations along $\hat B(t)$, adiabaticity,
Klaus-style magnetostir spin-up — or to reuse its analyzers.

Note the standard dynamics path takes plain `split_step!`, which is only
1st-order in time once the DDI is active. Pass `integrator: midpoint` for
2nd order at ~1.5–2× per-step cost.

## Related paths

`solvers/scalar_egpe.jl` — scalar GPE with a time-dependent dipole axis
$\hat B(t)$ (adiabatic elimination). The deep-adiabatic alternative when
$\tilde\psi_{m\neq -F} \to 0$.

## Tests

| file | what it gates |
|---|---|
| `test_magnetostir_rotating_field_analytic.jl` | φ̇≠0 vs exact single-spin reference (the engine-retirement arbiter) |
| `test_rotating_basis_standard_parity.jl` | rotating_basis ⇄ standard equivalence + the `Fz` frame distinction |
| `test_magnetostir_pipeline_physics.jl` | self-contained pipeline physics |
| `test_rotating_basis_pipeline_parsing.jl` | YAML parsing + ε threshold |
| `test_rotating_basis_analyzers.jl` | analyzer dispatch on the history Dict |
| `test_rotating_frame_regression.jl` | `secular_ddi=true` round-by-round pins |
| `test_scalar_egpe_smoke.jl`, `test_scalar_egpe_dipole_kernel.jl` | scalar-eGPE |

## See also

* `docs/design/rotating_basis_unification.md` — the retirement plan and its execution.
* `docs/design/option_gamma_rotating_basis.md` — original design (historical).
* `docs/conventions/hamiltonian_sign_audit.md` — where the Zeeman sign is declared.
