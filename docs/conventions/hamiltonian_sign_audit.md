# Hamiltonian sign convention audit

Source of truth for every Hamiltonian term used in `SpinorBEC.jl`,
the convention for each, the implementation paths that must agree, and
the directional sign test that pins each.

**Why this file exists.** Between 2026-06-02 and 2026-06-04 three
sign bugs of the same class appeared (Barnett shift cancellation,
Coriolis substep, transverse Zeeman). Each was a sign or
missing-term discrepancy between two implementation paths of the
same physical quantity, hidden because the existing tests (norm
preservation, no-op-at-zero, total-grad FD) all passed against
wrong-direction implementations. This file converts the per-bug
reactive audit into a single durable table covering every term ×
every path, with a regression test pinned to each.

**Discipline.** Every PR touching `src/hamiltonian/`,
`src/analysis/energy.jl`, `src/solvers/lbfgs/energy_gradient.jl`, or
`ext/SpinorBECCUDAExt/gpu_energy.jl` must:

1. Identify the term and path being changed.
2. Read the corresponding row of this table.
3. Verify the directional test still passes.
4. Update the "Last verified" column.

Adding a new term means adding a row + a directional test + updating
this table.

---

## Conventions (source of truth)

The single canonical Hamiltonian spec:

```
H_total = H_kinetic + H_trap + H_Zeeman + H_interaction
        + H_DDI + H_rotating_frame + H_drive + H_loss

H_Zeeman = -(g_F μ_B B · F) + q F_z²
           = -p·F_z - bx·F_x - by·F_y + q·F_z²

H_rotating_frame = -Ω·(L_z + F_z)
                  ≡ Coriolis (-Ω·L_z) + Barnett (-Ω·F_z, via p_eff = p+Ω)

H_DDI = (1/2) ∫ d³r d³r' (c_dd / |r-r'|³) [F(r) · F(r') - 3(F(r)·r̂)(F(r')·r̂)]
```

(Reference: `src/workflow/experiments/runtime/b_block_builders.jl:25-28`
for `H_Zeeman`. Rotating-frame convention in
`mistake_coriolis_substep_sign_2026_06_03.md`. DDI convention in
CLAUDE.md "Conventions (do NOT 'fix')".)

---

## Sign × path audit table

| Term | Sign convention | Propagator path | Energy CPU | Energy GPU | Gradient | Directional test |
|---|---|---|---|---|---|---|
| **Kinetic** `+½k²` | universal | `apply_kinetic_step_batched!` (`split_step_kernels.jl`) | `_kinetic_energy` (`energy.jl:34`) | mirrors CPU (`gpu_energy.jl:110`) | `_grad_kinetic!` (`energy_gradient.jl:100`) | implicit via norm conservation |
| **Trap** `+V(r)` | universal | inside `_diagonal_step!` (`propagators.jl`) | `_trap_energy` (`energy.jl:35`) | mirrors CPU (`gpu_energy.jl:111`) | `_grad_trap!` (`energy_gradient.jl:144`) | none yet — TODO |
| **Linear z-Zeeman** `H = -p·F_z` | +p ⇒ +Bz ⇒ ⟨F_z⟩>0 | inside `_diagonal_step!` via `zeeman_diagonal` (`zeeman.jl:9`) | `_zeeman_energy` (`energy.jl:165`) | mirrors CPU (`gpu_energy.jl:113`) | `_grad_zeeman!` (`energy_gradient.jl:152`) | **✓** `test/oracles/test_hamiltonian_sign_oracles.jl:37` |
| **Quadratic z-Zeeman** `H = +q·F_z²` | +q ⇒ E ~ +m² ⇒ favors m=0 | as linear z | as linear z | as linear z | as linear z | none yet — TODO |
| **Transverse x-Zeeman** `H = -bx·F_x` | +bx ⇒ +Bx ⇒ ⟨F_x⟩>0 | `_apply_transverse_zeeman_step!` (`split_step.jl:154`) **uses `-bx`** | inside `_zeeman_energy` via `zeeman_at` (`energy.jl:165`) — currently CPU treats bx as part of zeeman vector; sign? **TODO verify** | mirrors CPU via `zeeman_at` (`gpu_energy.jl:112-113`) — **TODO verify** | `_grad_zeeman!` only handles diagonal; **does NOT include transverse — known gap, see notes** | **✓** `test/oracles/test_hamiltonian_sign_oracles.jl:64` (post-2026-06-04 fix) |
| **Transverse y-Zeeman** `H = -by·F_y` | as x | as x | as x | as x | as x | **✓** `test/oracles/test_hamiltonian_sign_oracles.jl:89` |
| **Coriolis (orbital)** `H = -Ω·L_z` | +Ω ⇒ descent on -L_z ⇒ ⟨L_z⟩>0 (vortex amplification in IT) | `_apply_coriolis_step!` (`split_step_kernels.jl:20`), 3-shear with `(tanh, -sinh, tanh)` / `(tan, -sin, tan)` post-2026-06-03 audit | `E_coriolis = -Ω·⟨L_z⟩` (`energy.jl:98`) | added 2026-06-04 fix (`gpu_energy.jl:170-181`) | `_grad_coriolis!` (`energy_gradient.jl:117`) | **✓** `test/solvers/test_simulation.jl:253` + `test/oracles/test_hamiltonian_sign_oracles.jl:117` |
| **Barnett (spin)** `H = -Ω·F_z`, via `p_eff = p+Ω` | +Ω ⇒ effective Zeeman stronger ⇒ ⟨F_z⟩>0 | `_shift_zeeman_for_rotating_frame` (`make_workspace.jl:372`) post-2026-06-02 fix | folds into `_zeeman_energy` via shifted p | folds into shifted p | `_grad_zeeman!` via shifted p | **✓** `test/rotating_basis/test_rotating_frame_regression.jl:60` + `test/oracles/test_hamiltonian_sign_oracles.jl:139` |
| **c0 density** `H = (c0/2)·n²` | universal positive coupling | inside `_diagonal_step!` | `_density_interaction_energy` (`energy.jl:40`) | mirrors CPU (`gpu_energy.jl:115-119`) | `_grad_c0_density!` (`energy_gradient.jl:162`) | none — c0>0 ⇒ no specific direction TODO add density profile test |
| **c1 spin** `H = (c1/2)·\|F\|²` | sign of c1 picks polar (>0) or FM (<0) | inside `_apply_spin_mixing_step!` | `_spin_interaction_energy` (`energy.jl:45`) | mirrors CPU (`gpu_energy.jl:121-126`) | `_grad_c1_spin!` (`energy_gradient.jl:183`) | partial: F=1 Rb87 (c1<0) → FM, F=1 Na23 (c1>0) → polar in `test_simulation.jl:6-50` — implicit oracle |
| **DDI** see CLAUDE.md "Conventions" | `Q_αβ(k=0) = 0`, `Q_αβ = k̂_αk̂_β - δ_αβ/3` | `apply_ddi_step!` (`interactions/ddi/`) | `_ddi_energy` (`energy.jl:50`) | `_ddi_energy_from_gpu` (`gpu_energy.jl:128`) | `_grad_ddi!` (`energy_gradient.jl:229`) | none — TODO add oblate dipole alignment direction |
| **LHY** `~ +c_lhy·n^(5/2)` | c_lhy>0 (repulsive) | inside `_diagonal_step!` | `_lhy_energy` (`energy.jl:63-69`) | mirrors CPU (`gpu_energy.jl:146-152`) | `_grad_lhy!` (`energy_gradient.jl:172`) | none — TODO repulsion direction |
| **Tensor (c2, c4, ...)** | per S-channel coupling | `_apply_singlet_pair_step!`, `_apply_tensor_step!` | `_singlet_pair_energy`, `_tensor_interaction_energy` (`energy.jl:71-79`) | mirrors CPU (`gpu_energy.jl:154-162`) | NOT covered in `energy_gradient!` (LBFGS falls back to ITP) | none — TODO |
| **Raman** depends on Ω_R, detuning δ | per `apply_raman_step!` | `apply_raman_step!` (`raman.jl`) | `_raman_energy` (`energy.jl:81-85`) | mirrors CPU (`gpu_energy.jl:164-168`) | not covered | none |
| **Light shift** `±ls_amp·\|ψ_m\|²·profile(r)` per m | per `apply_light_shift_step!` | inside `_diagonal_step_with_ls!` (`propagators.jl`) | `_light_shift_energy` (`energy.jl:87-91`) | added 2026-06-04 fix (`gpu_energy.jl:170-174`) | `_grad_light_shift!` (`energy_gradient.jl:206`) | none |
| **Magnetic gradient** `+g_F·grad·x_axis` to V | direct addition to V | inside `_apply_mg_to_V!` (`split_step.jl:130`) | folds into V_trap | folds into V_trap | folds into trap gradient | none |
| **Loss (K3)** non-Hermitian, RT only | per-m K3 rate | `apply_loss_step!` (`split_step.jl:65`) | not in energy (RT only) | n/a | n/a | none — TODO RT-only direction |

---

## Coverage scoreboard (as of 2026-06-04)

- **Directional test present**: 5 / 16 terms
  - Linear z-Zeeman ✓
  - Transverse x-Zeeman ✓ (new, post-2026-06-04)
  - Transverse y-Zeeman ✓ (new)
  - Coriolis orbital ✓
  - Barnett spin ✓
- **Cross-path consistency verified** (CPU=GPU energy, gradient = ∂energy):
  - Linear z-Zeeman ✓
  - Transverse x/y-Zeeman: **partial** — propagator fixed, gradient gap remains (`_grad_zeeman!` only diagonal — `energy_gradient!` is wrong at non-zero bx/by). Marker `[GAP-1]`.
  - Coriolis orbital ✓ (per-cell FD audit)
  - Barnett spin ✓ (per-cell FD audit)
  - c0 / c1 / DDI / LHY ✓ (per-cell FD audit, post-fix)
  - Tensor (c2, c4) ✓ since 2026-06-09 — the anomalous gradient face is implemented and `energy_gradient!` is registry-only, so tensor-active configurations are optimised, not bounced to ITP. FD-gated in `test_term_consistency.jl`. (Was `[KNOWN-LIMIT]`.)
- **Directional test missing**: 11 / 16 terms (trap, q, c0, c1 directly, DDI, LHY, tensor, raman, light_shift, mag-grad, loss).
  Each is a future-bug opportunity if the term gets refactored.

### Known gaps requiring follow-up

- **[GAP-1] FIXED 2026-06-04 PM.** `_zeeman_energy` + `_grad_zeeman!`
  (CPU) and `_energy_decomposition_gpu` (GPU) now include the
  transverse contribution via the new `_transverse_zeeman_energy` helper
  and an inline call to `add_gradient!(TransverseZeeman(bx, by), ...)`.
  Bit-identity to the registry-based path verified at machine precision
  (`Δ = 0.0` for energy, `3.5e-15` for gradient on a random 8³ state
  with bx=0.3, by=0.2). Phase 3.1 + 3.2 of the sign-bug-proof
  architecture (`docs/conventions/sign_bug_proof_architecture.md`)
  added the registry path that *structurally* caught this. Blast
  radius retro: any past Eu LBFGS-polished run with non-zero
  transverse B (none in current M1/M2 work — all used Bz only).

### Phase 3 status (sign-bug-proof architecture)

- **All 14 H terms registered as `<: HamTerm`** in `src/hamiltonian/terms/`.
  Sign convention is declared in ONE line per term; propagator /
  energy / gradient methods derive from it.
- **`build_h_terms_registry(ws)`** returns an `NTuple{14, HamTerm}` —
  type-stable, zero-overhead iteration.
- **`total_energy_via_registry(ws)`** is bit-identical to
  `energy_decomposition(ws).total` (verified Δ = 0.0).
- **`add_gradient_via_registry!(grad, ws)`** is bit-identical to
  `energy_gradient!` body modulo Wirtinger ×2 (verified Δ = 3.5e-15).
- **`test/oracles/test_term_consistency.jl`** runs FD oracle + sign
  oracle per registered term. CI gate against regressions.

- **TODO: 11 missing directional tests** for terms whose sign was
  always universal (c0, c1, DDI, LHY, etc.) — lower priority since
  no historical bug there.

---

## How to add a new term

1. Decide the sign convention. State it in a comment block at the
   term's definition site. Refer to the canonical Hamiltonian spec
   in this file.
2. Implement consistently in: propagator substep, CPU energy, GPU
   energy, and gradient. Use the same sign across all four. A
   missing-term in ONE of these (esp. GPU energy, esp. gradient) is
   the bug class this audit prevents.
3. Add a row to the table above with all four implementation paths.
4. Add a directional test to `test/oracles/test_hamiltonian_sign_oracles.jl`.
5. Run the oracle suite + the per-term FD audit and verify the test
   passes.

## How to verify the audit is current

```
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e \
    'using SpinorBEC, Test, FFTW; include("test/oracles/test_hamiltonian_sign_oracles.jl")'
```

Should complete with ALL tests in the suite passing.
