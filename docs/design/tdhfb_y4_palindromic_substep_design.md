# TDHFB Y4 Palindromic Substep Design — Post-修論 Task #86

> **FROZEN 2026-05-12.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

**Status**: design only. Multi-session implementation pending.
**Related code**: `src/hamiltonian/tdhfb/y4_midpoint_step.jl` (current Y4 wrapper, empirically order 2).
**Origin**: blocking factor identified in `y4_midpoint_step.jl` file header — the TDHFB Strang substep is not palindromic at O(dt²), preventing Yoshida composition from delivering order 4.

---

## 1. Problem statement

Yoshida-4 composition `S(w₁·dt) ∘ S(w₀·dt) ∘ S(w₁·dt)` with
$w_1 = 1/(2 - 2^{1/3}) \approx 1.351$, $w_0 = 1 - 2 w_1 \approx -1.702$
delivers order 4 **iff** the base sub-step $S$ is order 2 *and*
**palindromic** (= time-reversible at O(dt⁵)):

$$S(-dt) \circ S(dt) = \mathbf{I} + O(dt^5).$$

Direct measurement on the current TDHFB Strang substep
(`scripts/diagnostic/` reproducer; see also Section 2 below) shows the
palindromic residual scales as $O(dt^2)$, not $O(dt^5)$:

```
dt     |S(-dt) S(dt) - I|∞ (ρ component)
0.04   7.5e-6
0.02   1.9e-6   (4× smaller — O(dt²))
0.01   4.6e-7   (4× smaller — O(dt²))
0.005  1.2e-7   (4× smaller — O(dt²))
```

The asymmetry lives in the inner HF triple:

```
phi-substep(dt/2; ρ_a, κ_a)  →  R-substep(dt)  →  phi-substep(dt/2; ρ_b, κ_b)
```

The first $\phi$-step reads $(\rho, \kappa)$ **before** the R update;
the second reads them **after**. Under time reversal those tags swap,
which is fine for a true palindrome — but the BdG matrix exponential
applied as `(φ_new, conj(φ)_new) = top(exp(-iW^φ dt) · (φ, conj(φ)))`
is the upper half of a Nambu rotation, and
`conj(φ)_new ≠ conj(applied result lower half)` in general (only when
$\Delta^\phi \to 0$). So the $\phi$ subupdate is **not exactly the inverse**
of its negative-dt counterpart, leaving an $O(dt^2)$ palindrome remainder.

---

## 2. Diagnostic protocol

Before any implementation, build a reproducer:

```julia
# scripts/diagnostic/tdhfb_palindromic_gate.jl
using SpinorBEC, LinearAlgebra
F = 1; nx = 16
state0 = init_tdhfb_vacuum(random_phi(F, nx))
state0.rho .= random_hermitian_rho(...)
state0.kappa .= random_symmetric_kappa(...)
gS = Dict(0 => 0.5, 2 => 0.1); V_ext = zeros(nx, 2F+1)

@printf("dt          palindromic_resid    order\n")
prev = NaN
for dt in [0.04, 0.02, 0.01, 0.005, 0.0025]
    s = deepcopy(state0)
    tdhfb_strang_step!(s, F, gS, V_ext, dt)
    tdhfb_strang_step!(s, F, gS, V_ext, -dt)
    res = max(norm(s.phi - state0.phi),
              norm(s.rho - state0.rho),
              norm(s.kappa - state0.kappa))
    @printf("%-12.4f %-20.4e %s\n", dt, res,
            isnan(prev) ? "—" : @sprintf("%.2f", log2(prev/res)))
    prev = res
end
```

Expected current output: order = 2 (the documented failure mode).

---

## 3. Two candidate solutions

### 3.1 Option A — State-averaged midpoint Picard

A symmetric implicit-midpoint formulation for the coupled $(\phi, \rho, \kappa)$
substep:

$$\phi_{n+1} = \phi_n - i \Delta t \cdot H[\bar\phi, \bar\rho, \bar\kappa] \bar\phi$$
$$\bar\phi = \tfrac{1}{2}(\phi_n + \phi_{n+1}),\ \bar\rho = \tfrac{1}{2}(\rho_n + \rho_{n+1}),\ \bar\kappa = \tfrac{1}{2}(\kappa_n + \kappa_{n+1})$$

Solved by Picard iteration (3-5 iterations typically converge).

**Pros**: provably palindromic by construction (symmetric in $(\phi, \bar\phi)$).
**Cons**: explicitly identified in the prompt as the `§3.7.4.b AVF anti-pattern`
— breaks order through a different mechanism (cos(Hτ/2) §3.3.2 family) and
fails empirically per Ch.3 §3.7.4. So this option is **not viable** without
additional structural correction.

### 3.2 Option B — Full BdG-Nambu rotation (recommended)

Evolve the doublet $(\phi, \mathrm{conj}(\phi))$ **as the upper half of a
$(\phi, \rho, \kappa)$-coupled rotation** that exactly preserves the Nambu
conjugation constraint at the discrete level. Equivalent to writing the
TDHFB EOMs in the full HFB-doubled basis $(\phi_1, \phi_2, \ldots)$ where
$\phi_i$ are the Bogoliubov quasi-particle amplitudes, and matrix-
exponentiating the whole $(2D + 2D^2) \times (2D + 2D^2)$ generator per
voxel.

The $\phi$, $\rho$, $\kappa$ are then **derived quantities** from the
$\phi_i$ amplitudes via the standard Bogoliubov transformation; the
Nambu conjugation constraint is preserved by construction (each $\phi_i$
has a "negative-energy" counterpart $\bar\phi_i$ with the right
transformation under $t \to -t$).

**Pros**: structurally palindromic.
**Cons**: per-voxel cost rises from $O((2D)^3)$ matrix exp to
$O((2D + 2D^2)^3) \approx O((26)^3) \to O((26 + 2 \cdot 13^2)^3) \approx O(364^3)$
for F=6 — roughly $360^3 / 26^3 \approx 2700\times$ more expensive per voxel.
Total wall would jump from current 1.56 s/step (F=6 16³) to ~70 min/step.
**GPU port (Phase 5) is mandatory** before this is practical for production.

---

## 4. Recommended approach: Option B with GPU

The clean path is:

1. **Phase 5 GPU port FIRST** (`docs/design/tdhfb_gpu_port_design.md`).
2. **Implement Option B Bogoliubov-amplitude basis**:
   - Diagonalize the BdG matrix once per substep on GPU (cuSOLVER)
   - Evolve amplitudes via diag(exp(-i λ_k dt))
   - Compress back to (φ, ρ, κ) via Bogoliubov transformation
3. **Palindromic gate verify** on F=1 16³ (smallest case)
4. **Y4 composition** of the new palindromic substep → confirm order 4
5. **Y6** as bonus from same composition framework

---

## 5. Alternative: accept order 2 for production

If the GPU port is not feasible on the post-修論 timeline, the
operational alternative is:

- Keep Y4-mid wrapper as a documented order-2 method with better
  prefactor (commit `dc88a93` already lands this).
- Use smaller `dt` (factor 2-4 reduction) to compensate for the lower
  order in production runs.
- Document this clearly in Ch.5 §5.11.4 as the working-state choice.

---

## 6. Acceptance criteria for #86 completion

When implementation is done:

- [ ] Palindromic gate `‖S(-dt) S(dt) - I‖∞ ≤ O(dt⁵)` measured on F=1 16³.
- [ ] Y4 composition order = 4 (not 2) on lab-path bench.
- [ ] All 1142+ TDHFB tests pass with new substep.
- [ ] C4 energy drift ≤ Strang truncation floor (~10⁻⁶ at our test
      parameters with corrected EOM).
- [ ] Wall-time benchmark on F=6 16³ documented (target: ≤ 10× current
      Strang on GPU, or accept CPU cost as #86's known limit).

---

## 7. Open research questions

The Option B approach raises:

- **Bogoliubov-amplitude regularization**: λ_k can become arbitrarily
  small near Goldstone modes; the exp(-i λ_k dt) factors are stiff.
  May need Padé-2 regularization or projection of Goldstone modes
  out of the dynamic evolution.
- **Particle-conserving form**: standard Bogoliubov breaks U(1); we
  use Castin-Dum particle-conserving Bogoliubov which has explicit
  Goldstone projection — needs careful discretization to preserve
  this at numerical level.
- **Symplectic / unitary discretization**: BdG matrix exp must be
  computed in a way that preserves the pseudo-unitary structure
  (η-Hermiticity, where η = diag(I, -I)). cuSOLVER's general eigen
  doesn't guarantee this.

---

## 8. Cross-references

- File header in `src/hamiltonian/tdhfb/y4_midpoint_step.jl` (lines 1-72)
- `docs/design/tdhfb_gpu_port_design.md` (Phase 5 prereq)
- Memory: `memory/tdhfb_perf_findings.md` (round-1 through round-5 audit
  history including the EOM convention bug we partially fixed)
- Master thesis Ch.5 §5.11.4 (TDHFB Phase 3-6 status)
- Castin-Dum 1998 PRA 57, 3008 (particle-conserving Bogoliubov)
- Stoof 1999 JLTP 114, 11 (HFB formulation we use)

---

**Last update**: 2026-05-12 (initial design doc; post-修論 implementation
deferred per `docs/manuscript/submission_packaging.md` timeline).
