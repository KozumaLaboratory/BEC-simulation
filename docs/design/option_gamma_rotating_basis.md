# Option γ: Instantaneous Local Frame Spinor GPE — derivation

> **FROZEN 2026-05-11.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Mathematical derivation behind `kind: rotating_basis`. **For how to use it (YAML, validation results, ε rule, gauge gotcha), read `guides/fast_larmor_regime.md` first.** This file is the term-by-term Hamiltonian transform — read it when you need to understand or extend the math.

Status: **production**. Phase II/III validation passed 2026-04-27 (see guide for the table). Scalar eGPE (`src/rotating_basis/scalar_egpe.jl`) is the adiabatic limit ($\tilde\psi_{m\neq -F}\to 0$) and serves as the Phase II reference.

## 1. Setup

- Spatial: $\vec r\in\mathbb{R}^3$
- Spin: $F$ (Eu151 $F=6$), $D=2F+1$ components
- Time-dependent polarization: $\vec B(t)=B(t)\hat B(t)$, $\hat B(t)=(\sin\theta\cos\phi,\sin\theta\sin\phi,\cos\theta)$

Lab-frame Hamiltonian:

$$\hat H_\text{lab}(t) = \hat T + \hat V_\text{trap} + \hat H_Z(t) + \hat H_\text{int}[\psi]$$

with

$$\hat H_Z(t) = -p(t)\,\hat{\vec F}\cdot\hat B(t) + q(t)\,(\hat{\vec F}\cdot\hat B(t))^2$$

$$\hat H_\text{int}[\psi] = c_0 n + c_1 \hat{\vec F}\cdot\langle\hat{\vec F}\rangle + \hat H_\text{DDI} + \hat H_\text{tensor}$$

Scale hierarchy (fast-Larmor, Eu151): $\omega_L \equiv p \gg \omega_\text{rotation}, \omega_\text{trap}, \omega_\text{int}$.

Small parameter: $\varepsilon\equiv\omega_\text{rotation}/\omega_L \ll 1$.

## 2. Instantaneous-field eigenbasis

Define $|m\rangle_{\hat B(t)} = \hat U_B(t)|m\rangle_z$ with

$$\hat U_B(t) = e^{-i\phi(t)\hat F_z}\,e^{-i\theta(t)\hat F_y}$$

(z-y-z Euler with $\gamma=0$; $\gamma$ is the gauge degree of freedom — see §9.)

Key property: $\hat U_B^\dagger(\hat{\vec F}\cdot\hat B)\hat U_B = \hat F_z$ — the projection along the magnetic-field axis becomes static $\hat F_z$.

Wavefunction transform: $\tilde\psi(\vec r,t) \equiv \hat U_B^\dagger(t)\psi^\text{lab}(\vec r,t)$. In the fast-Larmor regime $\tilde\psi_{-F}$ is dominant, $\tilde\psi_{m\neq-F}$ are small spin excitations.

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

$c_0 n$ is invariant under $\hat U_B$ (norm preserved). $c_1\hat{\vec F}\cdot\langle\hat{\vec F}\rangle$ is rotationally scalar and keeps the same form in the rotating basis.

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

Magnitude: $|\hat A| \sim \hbar|\dot{\hat B}| = \hbar\omega_\text{rotation}$. For a 226 Hz stir this is ≈ 1.4 kHz vs Larmor 1.4 MHz ⇒ **3 decades smaller**. With $dt=2\times 10^{-3}$, $|\hat A|\,dt \sim 10^{-3}$ — Strang error well controlled.

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
- DDI reduces to scalar tilted-dipole (the kernel in `src/rotating_basis/scalar_egpe.jl`)
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

## 12. Two physics insights worth recording separately

**Larmor sub-cycling is not solved by Option γ alone.** Naive lab-frame Strang splits Zeeman (transverse + diagonal) from DDI/SM, and that's what makes dt scale as 1/p. An eigen-exact spin step that combines all spin-only spatial-constant operators into one D×D unitary eliminates that constraint in BOTH lab-frame and rotating-basis (we have both solvers; they agree). So Option γ's actual advantage is **cleaner sparsity**: $\tilde H = -p F_z + q F_z² - Â$ stays sparse for arbitrary $\hat B(t)$, while $H_{\rm lab} = -p \hat F \cdot \hat B(t)$ is full.

**ε_dd_eff has an F² factor.** Stability requires `ε_dd_eff ≡ c_dd · F² / (3g) < 1`, not the naive `c_dd / (3g)`. The F² is in both solvers' effective dipolar strength.

## 13. Where this sits among solvers

| Aspect | Lab spinor | RF (`omega_R`) | scalar eGPE | Option γ |
|---|---|---|---|---|
| Larmor sub-cycling | required* | bypassed (resonant) | bypassed (adiabatic) | bypassed (basis) |
| Spin excitations | full | full | none | full |
| Off-resonant drives | works | breaks | works | works |
| Off-adiabatic dynamics | works | works | breaks | works |
| ITP for FL phase | works | works | trivial scalar | works |
| EdH microscopic | works | works | misses spin-orbit | works |

(*) lab spinor with eigen-exact spin step also bypasses sub-cycling (see §12); the table reflects the historical naive Strang split.
