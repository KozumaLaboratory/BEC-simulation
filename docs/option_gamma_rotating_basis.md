# Option γ: Instantaneous Local Frame Spinor GPE

Design document for a rotating-basis formulation that handles
time-dependent magnetic-field polarization $\hat B(t)$ in spinor BECs.
Larmor oscillations are removed analytically while spin excitations are
preserved. Scalar eGPE (`src/scalar_egpe.jl`) is the adiabatic limit
($\tilde\psi_{m\neq -F}\to 0$) of this formulation and serves as the
validation reference for Phase II below.

Status: **design only**. Implementation pending. Estimated 700 LOC and
multi-session work.

## 1. Setup

- Spatial: $\vec r\in\mathbb{R}^3$
- Spin: $F$ (Eu151 $F=6$), $D=2F+1$ components
- Time-dependent polarization: $\vec B(t)=B(t)\hat B(t)$,
  $\hat B(t)=(\sin\theta\cos\phi,\sin\theta\sin\phi,\cos\theta)$

Lab-frame Hamiltonian:

$$\hat H_\text{lab}(t) = \hat T + \hat V_\text{trap} + \hat H_Z(t) + \hat H_\text{int}[\psi]$$

with

$$\hat H_Z(t) = -p(t)\,\hat{\vec F}\cdot\hat B(t) + q(t)\,(\hat{\vec F}\cdot\hat B(t))^2$$

$$\hat H_\text{int}[\psi] = c_0 n + c_1 \hat{\vec F}\cdot\langle\hat{\vec F}\rangle + \hat H_\text{DDI} + \hat H_\text{tensor}$$

Scale hierarchy (Klaus / Eu151): $\omega_L \equiv p \gg \omega_\text{rotation}, \omega_\text{trap}, \omega_\text{int}$.

Small parameter: $\varepsilon\equiv\omega_\text{rotation}/\omega_L \ll 1$.

## 2. Instantaneous-field eigenbasis

Define $|m\rangle_{\hat B(t)} = \hat U_B(t)|m\rangle_z$ with

$$\hat U_B(t) = e^{-i\phi(t)\hat F_z}\,e^{-i\theta(t)\hat F_y}$$

(z-y-z Euler with $\gamma=0$; $\gamma$ is the gauge degree of freedom — see §9.)

Key property:
$\hat U_B^\dagger(\hat{\vec F}\cdot\hat B)\hat U_B = \hat F_z$
— the projection along the magnetic-field axis becomes static $\hat F_z$.

Wavefunction transform: $\tilde\psi(\vec r,t) \equiv \hat U_B^\dagger(t)\psi^\text{lab}(\vec r,t)$.
In Klaus regime $\tilde\psi_{-F}$ is dominant, $\tilde\psi_{m\neq-F}$ are small spin excitations.

## 3. Transformed Schrödinger equation

Substituting $|\psi\rangle = \hat U_B|\tilde\psi\rangle$ into $i\hbar\partial_t|\psi\rangle=\hat H_\text{lab}|\psi\rangle$:

$$i\hbar\partial_t|\tilde\psi\rangle = \bigl[\hat U_B^\dagger \hat H_\text{lab}\hat U_B - i\hbar\hat U_B^\dagger\partial_t\hat U_B\bigr]|\tilde\psi\rangle = [\hat H' - \hat A(t)]|\tilde\psi\rangle$$

The gauge-connection term $\hat A(t) = i\hbar\hat U_B^\dagger\partial_t\hat U_B$ is what absorbs the Larmor oscillation.

## 4. Term-by-term

### 4.1 Kinetic + trap (commute with $\hat U_B$)

$$\hat U_B^\dagger\hat T\hat U_B = \hat T,\qquad \hat U_B^\dagger\hat V_\text{trap}\hat U_B = \hat V_\text{trap}$$

### 4.2 Zeeman (★)

$$\hat U_B^\dagger\bigl[-p\hat{\vec F}\cdot\hat B + q(\hat{\vec F}\cdot\hat B)^2\bigr]\hat U_B = -p\hat F_z + q\hat F_z^2$$

**Static and diagonal**. Larmor scrambling eliminated.

### 4.3 Contact spin-spin

$c_0 n$ is invariant under $\hat U_B$ (norm preserved).
$c_1\hat{\vec F}\cdot\langle\hat{\vec F}\rangle$ is rotationally scalar and keeps the same form in the rotating basis.

### 4.4 DDI (★ careful)

$$\hat H_\text{DDI} = \tfrac{c_\text{dd}}{2}\int d^3r'\,Q_{ab}(\vec r-\vec r')\,\hat F_a(\vec r)\hat F_b(\vec r')\cdots$$

The lab-frame $Q_{ab}(\vec r) = \delta_{ab}-3\hat r_a\hat r_b$ is fixed; under $\hat U_B$:

$$\tilde Q_{cd}(\vec r;t) \equiv R_{ca}(t)R_{db}(t)Q_{ab}(\vec r) = \delta_{cd} - 3[R^\dagger\hat r]_c[R^\dagger\hat r]_d$$

where $R(t)\in SO(3)$ is the SO(3) rotation matrix corresponding to $\hat U_B$.

**Implementation**: existing DDI kernel is unchanged in $\vec r$-space — wrap with a uniform $D\times D$ spin rotation pre-/post-step (use `apply_uniform_spin_rotation!`). FFT path untouched.

### 4.5 Tensor interaction

$\sum_S g_S\hat P^{(S)}$ is rotationally invariant ⇒ unchanged in rotating basis.

## 5. Gauge connection $\hat A(t)$

$$\hat A(t) = \hbar\bigl[\dot\theta(t)\hat F_y + \dot\phi(t)\bigl(\cos\theta(t)\hat F_z - \sin\theta(t)\hat F_x\bigr)\bigr]$$

Derived from $\hat U_B = e^{-i\phi\hat F_z}e^{-i\theta\hat F_y}$ via chain rule.

Magnitude: $|\hat A| \sim \hbar|\dot{\hat B}| = \hbar\omega_\text{rotation}$.
For Klaus 226 Hz this is ≈ 1.4 kHz vs Larmor 1.4 MHz ⇒ **3 decades smaller**.
With $dt=2\times 10^{-3}$, $|\hat A|\,dt \sim 10^{-3}$ — Strang error well controlled.

## 6. Final rotating-basis spinor GP

$$i\hbar\partial_t\tilde\psi_m = \bigl[-\tfrac{\hbar^2\nabla^2}{2m_\text{atom}} + V_\text{trap} + (-pm + qm^2) + c_0 n\bigr]\tilde\psi_m + c_1[\hat{\vec F}\cdot\langle\hat{\vec F}\rangle\tilde\psi]_m + \tfrac{c_\text{dd}}{2}\int d^3r'\tilde Q_{cd}(\vec r-\vec r';t)\hat F_c\hat F_d\cdots + \sum_S g_S[\hat P^{(S)}\tilde\psi]_m - [\hat A(t)\tilde\psi]_m$$

## 7. Why this is more powerful than scalar eGPE

- **Spin excitations preserved**: $\tilde\psi_{m\neq-F}$ track FL phase, EdH spin texture, etc.
- **Larmor eliminated**: $\hat F_z$ is static; time scale is $|\hat A|\sim\omega_\text{rotation}$
- **B-1 FL phase scan available**: ITP in rotating basis finds nontrivial multi-component spin textures
- **EdH microscopic model**: $\hat A$ provides spin-orbit coupling between $\hat L_z$ and $\hat F_z$

## 8. Adiabatic limit ↔ scalar eGPE

If $\tilde\psi_m\approx 0$ for $m\neq-F$:

- $\langle-F|\hat A|-F\rangle = -F\hbar\dot\phi\cos\theta$ — Berry-phase-like global phase
- DDI reduces to scalar tilted-dipole (the kernel in `src/scalar_egpe.jl`)
- Equivalent to scalar eGPE, plus a global phase

⇒ **scalar eGPE is Option γ's adiabatic limit**. Strong field + slow stir should produce overlap ≥ 0.9999 between the two; this is Phase II validation.

## 9. Gauge freedom

$\hat U_B'(t) = \hat U_B(t)e^{-i\chi(t)\hat F_z}$ defines an alternative basis with the same magnetic-axis projection. Gauge transformation: $\hat A\to\hat A+\hbar\dot\chi\hat F_z$, $\tilde\psi\to e^{i\chi\hat F_z}\tilde\psi$.

Recommended: choose $\dot\chi=-\dot\phi\cos\theta$ so $\hat A$ has no $\hat F_z$ component (the Larmor-scale piece $\dot\phi\cos\theta$ is absorbed into the gauge). Result: $\hat A=\hbar(\dot\theta\hat F_y - \dot\phi\sin\theta\hat F_x)$ — purely rotation-rate-scale, no Larmor residue.

## 10. ITP under Option γ

In ITP $i\hbar\partial_t\to-\hbar\partial_\tau$. For B-1 phase scan ($\hat B$ static):
- $\hat A=0$ (no time dependence)
- $\hat F_z$ static and diagonal
- Multi-component textures emerge naturally if energetically favored
- Existing spinor ITP code works after only the basis transform — no algorithmic changes

## 11. Implementation sketch

```julia
# ext/RotatingBasisExt.jl (or src/rotating_basis_gpe.jl)

struct RotatingBasisWorkspace{F, ...}
    psi_tilde::Array{ComplexF64, 4}    # (Nx, Ny, Nz, D)
    B_hat_t::Function                   # t → (θ, φ)
    U_B_cache::Matrix{ComplexF64}       # D×D
    A_op_cache::Matrix{ComplexF64}      # D×D
    ...
end

function step!(ws::RotatingBasisWorkspace, t, dt)
    update_basis_operators!(ws, t + dt/2)

    # Strang split (most ops act on tilde basis directly)
    apply_kinetic!(ws.psi_tilde, dt/2)
    apply_diagonal!(ws.psi_tilde, dt/2)               # V_trap + c0 n + (-p F_z + q F_z²)
    apply_spin_mixing!(ws.psi_tilde, dt/2)            # c1 F·⟨F⟩ (rotation-scalar)
    apply_DDI_rotated!(ws.psi_tilde, ws.U_B_cache, dt/2)  # wrap existing DDI with U_B
    apply_tensor!(ws.psi_tilde, dt)                    # P^(S) rotation-invariant
    apply_DDI_rotated!(ws.psi_tilde, ws.U_B_cache, dt/2)
    apply_spin_mixing!(ws.psi_tilde, dt/2)
    apply_diagonal!(ws.psi_tilde, dt/2)
    apply_kinetic!(ws.psi_tilde, dt/2)

    apply_gauge_connection!(ws.psi_tilde, ws.A_op_cache, dt)
end
```

LOC estimate:
- Math layer (basis, gauge): ~200
- DDI rotation wrapper: ~100 (mostly reuses existing DDI)
- Gauge connection step: ~100 (reuses `apply_uniform_spin_rotation!`)
- ITP integration: ~100
- Tests: ~200
- **Total: ~700 LOC, ~1 week**

## 12. Validation strategy

**Phase I — static $\hat B$**: $\hat B$ = constant ⇒ $\hat A=0$. Rotating-basis spinor GP ≡ lab-frame spinor GP up to a global basis transform. All 254 existing physics-invariant tests must pass.

**Phase II — static tilted $\hat B$**: $\hat B = (\sin 35°, 0, \cos 35°)$ constant. Compare lab-frame spinor (dt = 2e-5) and rotating basis (dt = 2e-3). Overlap > 0.9999, energies match. Also confirm scalar eGPE adiabatic limit: $\tilde\psi_{m\neq-F}\to 0$ in strong-field limit, density matches `src/scalar_egpe.jl`.

**Phase II PASSED (2026-04-27)**: scalar-eGPE adiabatic-limit overlap = 0.999959 on 16³ grid with F=1, p=5000, ε_dd_eff=0.033, 30° tilt. Sweep across F={1,2,4} × p={500,5000,50000} all pass with overlap ≥ 0.9995 and m=+F fraction = 1.0 to machine precision. See `test/test_rotating_basis_phase_ii.jl` (10 tests) and `scripts/validate_phase_ii_overlap.jl`. **Caveat:** stability requires ε_dd_eff ≡ c_dd·F²/(3g) < 1, not ε_dd_naive = c_dd/(3g) — the F² factor enters both solvers' effective dipolar strength.

**Phase III — dynamic $\hat B$ (Klaus)**: full magnetostir. Lab-frame spinor (dt = 2e-5, ~50 hours) vs rotating basis (dt = 2e-3, ~5 min). Final $L_z$, vortex count, density profile must match.

**Phase III PASSED (2026-04-27)**: implemented an in-tree eigen-exact lab-frame solver (`split_step_lab!`, `apply_lab_spin_step!`) that uses the SAME spin-step technology as Option γ. Compared at identical trap-scale dt:

| p (Larmor scale) | coherent overlap | density overlap |
|---|---|---|
| 100  | 1.000000 | 1.000000 |
| 1000 | 0.999964 | 1.000000 |
| **28428 (full Klaus)** | **0.999999** | 1.000000 |

dt convergence at p=20: 0.999987 (dt=0.04) → 1.000000 (dt=0.005). **Mathematical equivalence proven**: Option γ ⇄ lab-frame at trap-scale dt when both spin steps are eigen-exact.

**Important gauge note**: This equivalence requires `gauge_fix=false`. With `gauge_fix=true` the dynamics are still correct (just in a different gauge), but ψ_lab(T) ≠ Û_B(T) ψ̃(T) directly — a residual exp(+iχ F_z) needs to be applied to recover lab state. See `test/test_rotating_basis_phase_iii.jl` and `scripts/validate_phase_iii_lab_vs_gamma.jl`.

**The "Larmor sub-cycling" insight**: The original spinor solver's dt constraint at large Larmor stems from the NAIVE Strang split between Zeeman (transverse + diagonal) and DDI/SM. An eigen-exact spin step (combining all spin-only spatial-constant operators into one D×D unitary) eliminates that constraint in BOTH lab-frame and rotating-basis. Option γ's primary advantage is therefore not "dt budget" but **preservation of spin-excitation structure with cleaner eigen-exact decomposition** (the rotating-basis H_tilde = -p F_z + q F_z² - Â is sparser than H_lab = -p F·B̂(t) for arbitrary B̂(t)).

If Phase III passes, Option γ is production-ready and B-1 phase scan can use it.

## 13. Publication potential

This is publishable work:
1. F=6 spinor BEC + DDI + time-dependent polarization rotating-basis formulation (F=1 polar/ferromagnetic exists; F=6 only sketched in KU §10)
2. Berry connection $\hat A$ as microscopic origin of EdH spin-orbit coupling
3. Numerical demonstration of scalar eGPE as the adiabatic limit (Klaus reproduction)
4. Efficient B-1 phase scan computation (dt at trap scale)

Working title: *Local-frame spinor Gross-Pitaevskii formulation for time-dependent polarization in dipolar Bose-Einstein condensates*.

## 14. Relationship to existing code

- **`src/scalar_egpe.jl`**: adiabatic limit; serves as Phase II reference
- **Existing spinor split-step (`src/hamiltonian/split_step.jl`)**: lab-frame; Phase I/II/III ground truth at high resolution dt
- **`spin_rotating_frame_omega` SimParams**: opt-in RF for resonant drives only; Option γ subsumes it (no resonance assumption needed)
- **`zeeman_diagonal_quadratic_only`**: dead scaffolding from A.1 attempt; can be repurposed as the `-p F_z + q F_z²` static block in Option γ's diagonal step

## 15. Summary

| Aspect | Lab spinor | RF (`omega_R`) | scalar eGPE | Option γ |
|---|---|---|---|---|
| Larmor sub-cycling | required | bypassed (resonant) | bypassed (adiabatic) | bypassed (basis) |
| Spin excitations | full | full | none | full |
| Off-resonant drives | works | breaks | works | works |
| Off-adiabatic dynamics | works | works | breaks | works |
| ITP for FL phase | works | works | trivial scalar | works |
| EdH microscopic | works | works | misses spin-orbit | works |
| Implementation status | done | done (`09cb688`) | skeleton (`scalar_egpe.jl`) | design only |

Option γ is the unique formulation that handles all four regimes correctly with a single time-step budget.
