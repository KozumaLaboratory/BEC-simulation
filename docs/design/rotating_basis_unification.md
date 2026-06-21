# Rotating-basis ⇄ standard path: term-level unification plan

**Status:** design (2026-06-19). Companion to `option_gamma_rotating_basis.md`.

## Thesis (verified)

The rotating basis (Option γ) and the standard split-step path differ **only by
the rotation**: the time-dependent frame `U_B(t) = exp(-iφ F_z) exp(-iθ F_y)`
that aligns the quantization axis with `B̂(t)`. Everything else — the contact,
spin-mixing, singlet-pair, tensor, DDI, LHY, loss, kinetic, trap physics — is
**identical physics** in both frames. The two paths are separate code today not
because the physics differs but because the rotating path **hand-reimplements**
a subset of terms instead of reusing the shared operators.

This causes two symptoms from one root:

- **Drift** — a sign/coefficient declared in the registry and re-declared in the
  rotating path can diverge silently (the Zeeman / LHY / gauge clusters fixed in
  PR #30).
- **Feature gap** — the rotating path supports only `{c0, c1 (optional), DDI,
  scalar LHY, loss}`; it is missing singlet-pair `c2`, the LHY model dispatch
  (polar / FM / **icosahedral** — the F=6 Eu form), tensor / scattering-length,
  light-shift, and Raman.

## Evidence: the term operators are already workspace-agnostic

Every shared term step takes `(psi::AbstractArray, params…, dt, ndim)` — **not**
the typed `Workspace`. So they can be called on `ws.psi_tilde` directly, exactly
as the rotating path **already** does for spin-mixing, DDI, and loss:

| Operator | Signature | Used by rotating? |
|---|---|---|
| `apply_spin_mixing_step!` | `(psi, sm, c1, dt, ndim)` | ✅ yes |
| `apply_ddi_step!` | `(psi, sm, ddi_params, bufs, dt, ndim)` | ✅ yes (U_B-wrapped) |
| `apply_loss_step!` | `(psi, loss, F, dt, D, ndim, rho_buf)` | ✅ yes |
| `apply_singlet_pair_step!` | `(psi, interactions, F, dt, ndim)` | ❌ not wired |
| `apply_tensor_interaction_step!` | `(psi, cache, sm, dt, ndim)` | ❌ not wired |
| `apply_raman_step!` | `(psi, sm, raman, grid, dt)` | ❌ not wired |
| `apply_light_shift_step!` | `(psi, ls, dt, ndim)` | ❌ not wired |

The machinery exists. The rotating path simply does not (1) store the params on
`RotatingBasisWS`, nor (2) call the step in `split_step_rotating!`.

## What is genuinely rotating-specific (the real "difference")

1. **Frame + gauge connection.** State is `ψ̃ = U_B(t)† ψ_lab`; the
   time-dependence of `U_B` produces the gauge connection
   `Â/ℏ = θ̇ F_y + φ̇(cosθ F_z − sinθ F_x)`, folded into the local-spin step.
   This is the only term with no standard-path counterpart.
2. **Zeeman is diagonal in the frame.** Frame alignment makes the linear Zeeman
   `−p F_z`; the transverse part is absorbed by `U_B`. Handled by the
   eigen-exact local-spin step (with the static-field diagonal fast path).
3. **Eigen-exact spin integrator.** Klaus regime `p ≈ 30000` makes Strang-
   splitting the Zeeman vs `Â` fail; combining them in one matrix exponential is
   exact at any `dt`. This is a *numerical-method* enhancement, orthogonal to the
   rotation — the standard path could adopt it as an option, and in the rotating
   frame it is free for the diagonal case.

Everything else is shared physics.

## Term classification → wiring pattern

Each term falls into one of three buckets by how it transforms under `U_B`:

| Bucket | Behaviour under `U_B` | Wiring in `split_step_rotating!` | Terms |
|---|---|---|---|
| **Invariant** | scalar (commutes with `U_B`) | call the shared step **directly** on `ψ̃` | kinetic, trap, c0 density, LHY density, spin-mixing `c1`, **singlet-pair `c2`**, loss |
| **Covariant** | `U_B X U_B†` (rank-≥2 tensor) | **wrap in U_B** like DDI: `U_B → step → U_B†` | DDI (done), **tensor `c2/c4/c6`** |
| **Frame-special** | tied to lab geometry / frame | bespoke (gauge, eigen-exact) | Zeeman+gauge (done); **Raman / light-shift** (lab laser axis ⇒ `U_B`-rotated, time-dependent — treat as covariant w/ wrap, verify) |

Invariance rationale: spin-mixing `c1` and singlet-pair `c2` are the `|F|²` /
`S=0` scalar channels — rotationally invariant, so they act identically on `ψ̃`
(this is *why* `c1` already works applied directly). Tensor channels are rank-2/4
and transform, so they need the same `U_B` wrap as the DDI `Q`-tensor.

## Migration plan (each feature is the same recipe)

For each missing term:

1. Add its param(s) to `RotatingBasisWS` (mirror `c1` / `ddi_params`).
2. Plumb through `make_rotating_basis_ws` (default = inactive, short-circuits).
3. Slot the call into the `split_step_rotating!` Strang sandwich — directly for
   invariant terms (next to the `c1` calls), `U_B`-wrapped for covariant terms
   (next to `apply_ddi_step_rotating!`).
4. Single-source the coefficient from the registry declaration (no new sign).
5. Add an oracle/parity gate (rotating term ≡ standard term on a static field).

Recommended order (low → high risk):

1. **singlet-pair `c2`** — invariant, shared step exists, smallest change.
2. **LHY model dispatch** — replace `gamma_lhy::T` with an `AbstractLHY`; call
   `_lhy_V(ρ, model)` (the dispatcher) instead of the scalar fallback. Unlocks
   the F=6 icosahedral form.
3. **tensor / scattering-length** — covariant; wrap `apply_tensor_interaction_step!`
   in `U_B` like DDI; verify the `Q`-tensor-style covariance.
4. **light-shift / Raman** — frame-special; the lab laser axis becomes
   time-dependent in the rotating frame. Derive the `U_B`-rotated coupling before
   wiring; needs the most validation.

## Non-goals

- **Do not merge `RotatingBasisWS` into `Workspace`.** Folding 16 type params into
  the 23+-param `Workspace` explodes the inference lattice (the type-stability
  firewall; 30-min JIT hang). Unify at the **term/declaration** level, not the
  struct level.
- **Do not wire TDHFB into the rotating path** without an explicit ask
  (CLAUDE.md design boundary).

## Stage 0 (foundational, codebase-wide)

The m-value convention `m = F − (c−1)` is hand-recomputed in 8+ sites
(spin_rotation, zeeman, raman, spatial_zeeman, spin_mixing, observables,
analysis, dumb_reference). Optionally single-source via
`m_from_component_index(c, F)` in `foundation/spin_matrices.jl` + a gate pinning
`sm.system.m_values`. Low physics-risk (trivial formula, also pinned indirectly
by the layout convention `c=1 → m=F`), so lower priority than the term wiring.

## Retirement plan (delete RotatingBasisWS — scoped 2026-06-21)

The enabling physics is DONE: the standard split-step path now applies the
Zeeman **eigen-exact with field-axis q(b̂·F)²** (commit `feat(zeeman): unify…`),
so for a tilted/rotating B̂(t) it is numerically equal to the rotating-basis
path. Pinned by `test_rotating_basis_standard_parity.jl` (static GS) and
`test_rotating_vs_standard_dynamics.jl` (time-dependent B̂; per-m Δ<1e-3,
density overlap >0.9999). No dt/efficiency advantage for the rotating frame —
both obey the same Larmor guard `p·F·dt<π` (measured F=1/F=6, with DDI).

**Scope is small — NOT a 25-file rewrite.** Grep shows NOTHING outside
`run_step_rotating/` reads `:rotating_basis_ws` (the WS object). Every external
consumer (analyzers = thesis Fig 6, `save_rotating_result`, `bayesian_opt_yaml`,
`runner`) reads only the `:rotating_basis_dynamics` **dict of recorded arrays**
(`times`, `per_m_history`, `Lz`, `Fz`, `psi_snapshots`). So the retirement is:

1. **dynamics handler** (`run_step_rotating/dynamics.jl`): build a standard
   `Workspace` with `TimeDependentZeeman(bx,by,bz from θ(t),φ(t); q)`, seed
   `ψ_lab(0)=U_B(0)·ψ̃_GS`, run `run_simulation!` (map integrator: strang→
   split_step, yoshida4/6→composers). In `on_step`, transform `ψ_lab(t)→ψ̃(t)=
   U_B(t)†ψ_lab(t)` and record the SAME tilde observables (per_m, Lz, Fz,
   ψ̃ snapshots) → identical `:rotating_basis_dynamics` dict. Consumers unchanged.
2. **ground_state handler** (`run_step_rotating/ground_state.jl`): standard
   `find_ground_state` with the tilted `TimeDependentZeeman` (eigen-exact now
   handles the tilt); stash the couplings + ψ̃-equivalent the dynamics step needs
   (replace the internal `:rotating_basis_ws` handoff with plain params).
3. **Delete** `RotatingBasisWS`, `rotating_basis_propagators.jl`,
   `rotating_basis_integrators.jl` (engine ~815 lines) + the rotating analyzers'
   dependence on the WS, once both handlers no longer construct it.
4. **Validate** a real magnetostir YAML end-to-end (rotating output vs migrated
   standard output: per_m_history / Lz arrays match) BEFORE removing the engine,
   then regenerate the Fig-6 panels and diff.

Each step is independently committable; the equivalence gates above protect the
migration.

### ⚠ Integrator subtlety (found 2026-06-21 — corrects the "no efficiency advantage" claim)

The Strang⇄Strang equivalence is gated (`test_rotating_vs_standard_dynamics.jl`,
`test_rotating_dynamics_pipeline_parity.jl`). BUT the production magnetostir
defaults to **yoshida6** (`_default_rotating_integrator → "yoshida6"`), and the
two frames are NOT equivalent at high order:

- The standard-path high-order driver `run_simulation_yoshida!` uses a **frozen
  mean-field** base (`_strang_core!`); its docstring measures it degrading to
  **order ~1.0 for Y6** on the lab path (time-dependent Zeeman + DDI, Eu151 F=6)
  because the spin precesses fast (Larmor) between frozen sub-times.
- The rotating frame REMOVES the fast Larmor precession, so the tilde-frame
  dynamics is slow and frozen-MF Yoshida keeps its nominal order. **This is a
  genuine numerical advantage of the rotating frame for the magnetostir** — my
  earlier "no dt/efficiency advantage" conclusion was Strang-only and does NOT
  hold at high order.

So a naive "route magnetostir through the standard path with `run_simulation_yoshida!`"
would produce order-1 garbage and corrupt Fig 6. The faithful lab-frame path is
`split_step_midpoint!` (implicit-midpoint Picard restores sub-time
self-consistency).

**RESOLVED 2026-06-21 (measured).** `test_rotating_yoshida6_vs_lab_midpoint.jl`:
lab `split_step_midpoint!` reproduces rotating `yoshida6` to **~1e-5 per-m at the
SAME dt / step count**, and the error is **p-INDEPENDENT** (1.1e-5 / 2.2e-5 /
7.0e-6 at p = 50 / 500 / 2000, fixed `p·F·dt = 1`). Both paths obey the same
Larmor guard `p·F·dt<π`, so the step counts match — **the rotating frame has no
meaningful efficiency OR accuracy advantage** once the lab path uses the midpoint
(not frozen-MF) integrator. 1e-5 is far below Fig-6 population resolution; if
sub-1e-5 is ever needed, compose `split_step_midpoint!` as Y6-mid. **Retirement
is viable: the migrated dynamics handler must use `split_step_midpoint!` (NOT
`split_step!` Strang at the config dt, NOT `run_simulation_yoshida!`).**

## Testing

Each wired term must pass a rotating-vs-standard parity gate on a **static
field** (where the two frames coincide): same config, assert ground-state
populations / density agree. This is the rotating-path analogue of the standard
per-term oracle suite, and closes the per-term-oracle blind spot the rotating
path has had.

The gate exists: `test/rotating_basis/test_rotating_basis_standard_parity.jl`
descends both `find_ground_state` (standard) and `find_ground_state_rotating!`
(rotating, B̂=ẑ) from the *same* seed and asserts per-m populations + the
basis-invariant density agree. The config is the spin-1 **broken-axisymmetry**
phase (ferromagnetic c₁<0, 0 < q < q_c ≈ |c₁|·n_peak) — the only static-B̂=ẑ
regime where the ground state is genuinely 3-component and ALL of c₀/c₁/c₂/q
shape the populations (the polar and antiferromagnetic phases are c₁- and/or
c₂-blind because ⟨F⟩=0 and singlet pairing is population-invariant). This pins
kinetic + trap + c₀ + c₁ + c₂ + diagonal Zeeman in one shot; canary checks
confirm dropping c₁ moves per-m by ~0.25 and dropping c₂ by ~0.03, both ≫ the
2e-3 tolerance. A second testset pins the c₂ energetic sign (attractive singlet
lowers μ). New terms extend this file with their own static-field config.
