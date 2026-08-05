# STATE — what this system is, derived from the code

> **GENERATED. Do not edit.** Regenerate with
> `julia --project=. scripts/generate_state.jl`, and
> `test/test_state_doc_is_current.jl` fails if this file and the tree disagree.
>
> This file exists because deltas accumulate and nothing states the present.
> `CLAUDE.md`'s split-step list said 5 operators, was corrected to 7, and the
> real number is 9 — two sessions each appending to a hand-copied list. Every
> section here names the code it is read from, so it cannot drift without
> the gate going red.
>
> **What is NOT here:** anything needing judgement — why a design is what it
> is, what a measurement means, which convention is deliberate. That stays
> hand-written in `CLAUDE.md` and the memory store. Derive what is
> checkable; curate what is not.

## Split-step: the forward outer-potential chain

Read from `_outer_operators_fwd!` (`src/hamiltonian/integrator/split_step.jl:600`), in source order.
**9 substeps.** Each auto-skips when its coupling is ≈ 0.

1. `diagonal`
2. `light_shift`
3. `spin_mixing`
4. `spatial_lhy_spin`
5. `singlet_pair`
6. `tensor`
7. `transverse_zeeman`
8. `spatial_zeeman`
9. `raman`

The backward half reverses this; the pair is the Strang sandwich, with `DDI`
at the centre for RTP. A prose list of this anywhere else is a copy and has
been wrong twice.

## Hamiltonian terms in the registry

`H_TERMS_CANONICAL_ORDER`, in order. **14 terms.**
Each declares its sign in one coefficient function in the file named.

| # | registry symbol | struct | defined at |
|---|---|---|---|
| 1 | `kinetic` | `KineticTerm` | `src/hamiltonian/terms/kinetic.jl:13` |
| 2 | `trap` | `TrapTerm` | `src/hamiltonian/terms/trap/trap.jl:7` |
| 3 | `zeeman` | `ZeemanTerm` | `src/hamiltonian/terms/zeeman.jl:216` |
| 4 | `density_c0` | `DensityC0Term` | `src/hamiltonian/terms/contact/contact.jl:33` |
| 5 | `spin_c1` | `SpinC1Term` | `src/hamiltonian/terms/contact/contact.jl:149` |
| 6 | `ddi` | `DDITerm` | `src/hamiltonian/terms/ddi/ddi_term.jl:8` |
| 7 | `lhy` | `LHYTerm` | `src/hamiltonian/terms/lhy/lhy_term.jl:7` |
| 8 | `tensor` | `TensorTerm` | `src/hamiltonian/terms/contact/contact.jl:289` |
| 9 | `raman` | `RamanTerm` | `src/hamiltonian/terms/raman.jl:78` |
| 10 | `light_shift` | `LightShiftTerm` | `src/hamiltonian/terms/light_shift/light_shift_term.jl:8` |
| 11 | `coriolis` | `CoriolisTerm` | `src/hamiltonian/terms/coriolis.jl:11` |
| 12 | `magnetic_gradient` | `MagneticGradientTerm` | `src/hamiltonian/terms/magnetic_gradient.jl:29` |
| 13 | `spatial_zeeman` | `SpatialZeemanTerm` | `src/hamiltonian/terms/spatial_zeeman.jl:21` |
| 14 | `loss` | `LossTerm` | `src/hamiltonian/terms/loss.jl:210` |

## The B → p sign: every site that touches it

`Units.bfield_to_p` is the ONE declaration (`p ≡ -g_F μ_B B`, Kawaguchi-Ueda).
**20 references** across the tree; every one other than the
declaration itself must delegate. `CLAUDE.md` said "the 3 sibling converters"
until 2026-08-05, and a stale count is how a wrong-sign converter survived
two months — so this list is generated, not typed.

- `src/foundation/types/preset.jl:66`
- `src/hamiltonian/coefficients.jl:347`
- `src/hamiltonian/coefficients.jl:351`
- `src/hamiltonian/coefficients.jl:352`
- `src/hamiltonian/coefficients.jl:359`
- `src/hamiltonian/coefficients.jl:377`
- `src/workflow/experiments/runtime/b_block_builders.jl:102`
- `src/workflow/experiments/runtime/b_block_builders.jl:106`
- `src/workflow/experiments/runtime/b_block_builders.jl:110`
- `src/workflow/experiments/runtime/b_block_builders.jl:132`
- `src/workflow/experiments/schema/parsing_units.jl:33`
- `src/workflow/experiments/schema/parsing_units.jl:39`
- `src/workflow/io/units.jl:52`
- `src/workflow/io/units.jl:69`
- `src/workflow/io/units.jl:71`
- `src/workflow/io/units.jl:76`
- `src/workflow/io/units.jl:89`
- `src/workflow/io/units.jl:90`
- `src/workflow/io/units.jl:94`
- `src/workflow/io/units.jl:95`

## YAML surface

**Top-level keys (10):** `accuracy`, `auto_grid`, `calibration`, `calibration_history`, `defaults`, `mixins`, `pipeline`, `scan`, `target_date`, `units`

**Pipeline step kinds (2):** `dynamics`, `ground_state`

**Retired keys (13)** — from `docs/reference/yaml_schema_reference.md`. A LIVE document teaching one
of these fails `test/test_docs_examples_avoid_removed_keys.jl`.

| removed | replacement |
|---|---|
| `zeeman:` (step-level) | unified `B:` block |
| `B_hat:` (step-level) | unified `B:` block (`:spherical` coord) or `B_direction` for rotating_basis |
| `interactions.c_lhy` | `lhy.c_lhy` |
| `ground_state.spinor_lhy` | `lhy.kind` |
| `phi_omega` / `phi_dot` (flat B_hat) | `B: {phi: <waveform>}` or `B_direction: {phi: {rate: ...}}` |
| `theta_const`, `theta_ramp`, `phi_chirp` (flat B_hat) | `B: {theta: <waveform>}` |
| `initial_state: ferromagnetic` | `m_plus_F` or `m_minus_F` |
| `kind: option_gamma` | `kind: rotating_basis` |
| `backend: cuda` | `backend: gpu` |
| `B: {level: <0 | 1 |
| `B: {magnitude: ...}` | `B: {B_mag: ...}` |
| `loss: {K3_per_m: ...}` | `loss: {K3_per_m_cubic: ...}` (or `K3_per_m_si`) |
| `photon_scattering: {gamma_sc: ...}` | `photon_scattering: {Gamma_sc: ...}` |

## Test tiers

File counts from `test/_tiers.jl`. Membership is explicit — no auto-discovery.

- `FAST_TESTS` — 234 files
- `CI_EXTRA` — 89 files
- `FULL_EXTRA` — 33 files
- `PHYSICS_TESTS` — 7 files

## Validation ladder — instruments present on disk

| level | instrument (located by walking `test/`) |
|---|---|
| 0 | `test/test_level0_gpu_cpu_consistency.jl` |
| 1 | `test/test_level1_scalar_exact.jl` |
| 2 | `test/test_level2_strang_convergence.jl` |
| 3 | `test/test_level3_zeeman_only.jl` |
| 4 | `test/test_level4_f1_phase_emergence.jl` |
| 4 | `test/test_level4_general_F_phase_emergence.jl` |
| 8 | `test/hamiltonian/test_lhy_level8_unit.jl` |
| 10 | `test/test_level10_hpsi_self_consistency.jl` |
| 11 | `test/test_level11_convergence_sweep.jl` |
| 12 | `test/test_level12_production_audit.jl` |

## What the code says about itself is unfinished

Files carrying `KNOWN-LIMIT` or an explicit not-implemented marker —
**8 files, 13 markers.** This is the
only enumeration of it in the tree; prose elsewhere goes stale (a
`KNOWN-LIMIT` in `contact.jl` contradicted the function twenty lines below
it until 2026-08-04).

- `src/validation/dumb_reference.jl` — 4
- `src/hamiltonian/terms/raman.jl` — 2
- `src/manuscript/figures.jl` — 2
- `src/analysis/phases/sign_pattern.jl` — 1
- `src/foundation/types/ddi_loss.jl` — 1
- `src/hamiltonian/terms/loss.jl` — 1
- `src/hamiltonian/terms/contact/contact.jl` — 1
- `src/workflow/experiments/pipeline/run_step_dynamics.jl` — 1

