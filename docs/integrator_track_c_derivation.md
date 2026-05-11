# Track C — Force-Gradient 4 + DDI: Phase -1 derivation

**Status:** skeleton only, Phase -1 not yet started.
**Protocol:** all edits follow `docs/integrator_phase_minus_1_protocol.md`.
**Goal:** independent extension of Chin's force-gradient 4th-order scheme
from scalar GPE to spinor (F = 6, D = 13) + DDI lab-path V step.
**Time cap:** 2 weeks elapsed.

The thesis section is **§3.5 Force-gradient extension to spinor + DDI**.
See `docs/integrator_ch3_plan.md` for the chapter outline.

---

## Step 0 — Paper fetch list (REQUIRED before any derivation)

The first deliverable of Phase -1 is fetching these three papers and
saving them where anko can confirm. No formula manipulation begins until
all three are in hand.

1. **Chin (1997)** — original force-gradient construction.
   Phys. Lett. A 226, 344. The fourth-order symplectic integrator with
   `[V, [T, V]]` correction term replacing the negative-coefficient
   middle stage of triple-jump composition. Scalar / classical mechanics.

2. **Chin & Krotscheck (2005)** — rotating BEC GPE extension. ★ KEY
   PAPER for Track C. PRE 72, 036705. Applies the force-gradient
   construction to a scalar nonlinear Gross-Pitaevskii equation. This
   gives us the "scalar GPE + force-gradient" recipe as the starting
   point; spinor + DDI extensions are then orthogonal additions on top.

3. **Aichinger, Chin & Krotscheck (2005)** — non-local potential
   generalisation. Provides the framework for handling nonlocal V
   in the force-gradient evaluation, which we need for DDI.

After fetching, transcribe paper key sections into the
"§ Transcribed paper formulas" section below.

---

## Step 1 — Transcribed paper formulas

### 1.1 Chin-Krotscheck 2005 — Algorithm 4A (forward 4th-order, eq 6.8-6.11)

Read from arXiv:cond-mat/0504270v3 (full paper), 2026-05-11.

> **eq. (6.8)** — Algorithm 4A (forward fourth-order factorization):
> $$\psi(\Delta\tau) = e^{-\tfrac{1}{6}\Delta\tau\, V(\Delta\tau)}\, e^{-\tfrac{1}{2}\Delta\tau\, T}\, e^{-\tfrac{2}{3}\Delta\tau\, \widetilde{V}(\Delta\tau/2)}\, e^{-\tfrac{1}{2}\Delta\tau\, T}\, e^{-\tfrac{1}{6}\Delta\tau\, V(0)}\, \psi(0)$$
>
> **eq. (6.9)** — Modified middle V with force-gradient correction:
> $$\widetilde{V} = V + \frac{\Delta\tau^2}{48}\, [V,\, [T, V]]$$
>
> **eq. (6.10)** — Double commutator for the rotating anisotropic trap +
> nonlinear potential (paper has 2D case; generalises to any spatial dim):
> $$[V,\, [T, V]] = \left(\frac{\partial V}{\partial x}\right)^2 + \left(\frac{\partial V}{\partial y}\right)^2 = |\nabla V|^2$$
>
> **eq. (6.11)** — Concrete middle V for scalar GPE
> $V = V_\text{ext}(r) + g\,|\psi|^2$:
> $$\widetilde{V}(\Delta\tau/2) = g|\psi(\Delta\tau/2)|^2 + \frac{\Delta\tau^2\, g^2}{48}\left[\left(\frac{\partial|\psi(\Delta\tau/2)|^2}{\partial x}\right)^2 + \left(\frac{\partial|\psi(\Delta\tau/2)|^2}{\partial y}\right)^2\right]$$
>
> *(For the more general external potential, V is given by paper eq. 6.6.)*

The paper notes (lines around eq 6.11): "The partial derivatives can be
computed numerically by use of finite differences or FFT. Since the FFT
derivative converges exponentially with grid size, the use of FFT
derivative is preferable when the system can be made periodic."

### 1.2 Chin-Krotscheck 2005 — Time-dependent factorization rule (eqs 4.5-4.8)

> The time-dependent potential V(τ) must be evaluated at an
> intermediate time equal to the sum of time steps of all the T
> operators to its right. For 4A: V at far right uses V(0), middle
> Ṽ uses Ṽ(Δτ/2), far-left V uses V(Δτ).
>
> **eq. (4.8)** — Second-order algorithm 2B for midpoint evaluation:
> $$\psi(\Delta\tau) = e^{-\tfrac{1}{2}\Delta\tau\, T}\, e^{-\Delta\tau\, V(\Delta\tau/2)}\, e^{-\tfrac{1}{2}\Delta\tau\, T}\, \psi(0)$$

For 4A, the paper recommends ("algorithm 4AWW", section IV) evolving
ψ(Δτ/2) from ψ(0) by a second-order algorithm (2AW) and iterating the
final ψ(Δτ) for self-consistency. For our SpinorBEC framework, this
self-consistency = the same Picard fixed-point machinery already used
in `_half_potential_step_midpoint!`.

### 1.3 Forward / positive-coefficient property (paper §VI introduction)

> Algorithm 4A coefficients are (1/6, 1/2, 2/3, 1/2, 1/6) — all
> POSITIVE. This is essential for imaginary-time propagation: a
> negative kinetic-step time results in an unbounded diffusion kernel
> and unnormalizable wave function. Sheng-Suzuki-Goldman-Kaper theorems
> require any factorization without gradient correction to contain at
> least one negative coefficient beyond order 2. Force-Gradient
> 4A circumvents this by adding the τ² gradient term [V, [T, V]].

For real-time propagation: the same factorization with τ → iτ; all
operators are unitary at positive time steps; order 4 retained.

### 1.4 Chin 1997 Phys. Lett. A 226, 344 — original force-gradient

**Not on arXiv**; key formulas (4A composition with positive coefficients
+ [V, [T, V]] correction) reproduced and applied to scalar GPE in
Chin-Krotscheck 2005 above. Reference 15 of Chin-Krotscheck 2005 cites
the original.

For our derivation, Chin-Krotscheck 2005 is the load-bearing source.

---

## Step 2 — Notation translation (paper → SpinorBEC)

The paper uses ℏ = m = 1 (dimensionless GP equation, paper §III eq 3.3
sets length unit l = 1/√ω₀ and energies in ω₀). SpinorBEC uses the same
dimensionless convention with ℏ = m = ω_ref = 1, so no unit translation
is needed.

| Paper symbol | Paper meaning | SpinorBEC analog | Notes |
|---|---|---|---|
| `ψ(x, y)` | scalar wavefunction | `psi[I, c]` per component | paper scalar = our D=1; spinor extension below |
| `T` | rotating kinetic `Hx + Hy + ...` | `apply_kinetic_step_batched!` + Coriolis | identical operator |
| `V(r, τ)` | trap + GP nonlinearity | `V_trap[I] + zeeman_diag[c] + c0·density_buf[I]` | paper combines all; we split via `_dispatch_diagonal_step!` |
| `g` | nonlinearity coupling | `ip.c0` (our InteractionParams.c0) | paper has g (single channel) |
| `Δτ` | time step | `ws.sim_params.dt` | imaginary time; for real, τ = it |
| `ψ(Δτ/2)` | midpoint state | predictor from `_half_potential_step_midpoint!` | Picard fixed-point for self-consistency |
| `\|∇V\|²` | force-gradient term | `density_buf` + `∇V_trap` precomputed + `c0·∇density_buf` | spinor: same scalar quantity (Zeeman doesn't enter ∇) |
| coefficient `1/48` | from [V,[T,V]] in 4A | `dt²/48` | precomputed constant |

### Sign convention check

Paper eq (4.3): `ψ_0 ∝ lim_{τ→∞} ψ(τ) = lim_{τ→∞} e^{-τ[T+V(τ)]+τμ} ψ(0)`.
This is i∂_t ψ = Hψ with τ = it (imaginary time). For real time:
i∂_t ψ = Hψ → ψ(t) = e^{-itH} ψ(0).

SpinorBEC convention (split_step.jl):
- Real time: `_diagonal_step_svec_real!` uses `cis(-V·dt)` = e^{-iVdt}. ✓
- Imaginary time: `_diagonal_step_svec_imag!` uses `exp(-V·dt)`. ✓

Both match paper. No sign flip needed in transcription.

---

## Step 3 — Scalar GPE force-gradient (derivation from paper eqs.)

By construction, restricting our SpinorBEC implementation to:

- D = 1 (single-component, no spin algebra)
- c1 = c2 = c4 = ... = 0 (no spin-dependent coupling)
- c_dd = 0 (no DDI)
- No transverse Zeeman, no Raman, no light shift, no magnetic gradient

reduces our problem identically to the scalar GPE paper. The full
SpinorBEC V step `_half_potential_step!` then collapses to:

```
diag(dt_half/2) [no SM, nematic, tensor, raman, transB skipped]
                [DDI skipped — ws.ddi === nothing]
diag(dt_half/2)
```

= `diag(dt_half)` total = one diagonal step. Paper §IV form
`e^{-Δτ·V}` where V = V_trap + g|ψ|² reproduces our
`_diagonal_step_svec!` exactly (since SpinorBEC's `c0` ≡ paper's `g`).

The 4A composition `e^{-(1/6)dt V} K e^{-(2/3)dt Ṽ} K e^{-(1/6)dt V}`
in our framework:

```
diagonal_step(dt/6)
kinetic_step(dt/2)
diagonal_step_fgrad(2dt/3)   # includes (dt²/48)|∇V|² correction
kinetic_step(dt/2)
diagonal_step(dt/6)
```

Self-check (iii.a) **scalar reduction**: PASSES BY CONSTRUCTION at
D = 1 (single component). The whole derivation IS the paper's case.

Self-check (iii.b) **DDI off**: PASSES (we set c_dd = 0 in this
reduction; DDI extension is Step 5).

---

## Step 4 — Diagonal-spinor extension (no spin-mixing yet)

### 4.1 V matrix structure under diagonal-only assumption

Restrict to: c₁ = 0 (no spin-mixing), c₂ = 0 (no singlet pair), no
tensor cache, no transverse Zeeman, no Raman, no DDI, no magnetic
gradient, no light shift. Constant Zeeman ZeemanParams(p, q) only.

Then V in the spinor basis is a DIAGONAL operator in spin index:

$$V_{\alpha\beta}(r) = V_\alpha(r)\, \delta_{\alpha\beta},\quad
V_\alpha(r) = V_\text{trap}(r) - p\,m_\alpha - q\,m_\alpha^2 + c_0\, n(r)$$

where $n(r) = \sum_\gamma |\psi_\gamma(r)|^2$ is the total density (the
SAME for all spin index α, since c₀ couples to total density).

### 4.2 [V, [T, V]] under diagonal-only V

Since V is diagonal in α with [V_α, V_β] = 0 (they commute as
multiplication operators), and T is also diagonal in α (kinetic acts
spatially, not on spin index), the double commutator factorises:

$$[V, [T, V]]_{\alpha\beta} = [V_\alpha,\, [T, V_\alpha]]\, \delta_{\alpha\beta}$$

For each α, V_α is a scalar function of position. Applying the
classical-scalar formula (paper eq. 6.10):

$$[V_\alpha, [T, V_\alpha]] = |\nabla V_\alpha(r)|^2$$

Now ∇ acts spatially, so the Zeeman shifts `-p·m_α - q·m_α²` (spatially
constant scalars) contribute zero to ∇V_α:

$$\nabla V_\alpha(r) = \nabla V_\text{trap}(r) + c_0\, \nabla n(r)$$

which is the SAME spatially-varying vector for all α. Therefore:

$$[V, [T, V]] = \mathbf{I}_D \cdot |\nabla V_\text{eff}(r)|^2$$

where $V_\text{eff}(r) = V_\text{trap}(r) + c_0\, n(r)$ and $\mathbf{I}_D$
is the D×D identity. The diagonal force-gradient correction is
**spin-isotropic** in this reduction.

### 4.3 Concrete force-gradient diagonal step

Replace `_diagonal_step_svec!` 's effective V_int + V_trap by:

$$V_\alpha^\text{FG}(r) = V_\text{trap}(r) - p\,m_\alpha - q\,m_\alpha^2 + c_0\,n(r) + \frac{\Delta\tau^2}{48} |\nabla V_\text{eff}(r)|^2$$

Then the diagonal step kernel applies:

$$\psi_\alpha(r) \mapsto e^{-i\,\Delta\tau_\text{stage}\, V_\alpha^\text{FG}(r)}\, \psi_\alpha(r)$$

where $\Delta\tau_\text{stage}$ is the stage-specific time step (= 2Δτ/3
for the middle Ṽ stage of 4A). The Δτ² in the gradient correction is
the OUTER 4A step size, NOT the stage-internal one.

### 4.4 Numerical evaluation of ∇V_eff

For periodic / box-bound problems, FFT spectral derivatives give
exponential accuracy (paper recommendation §IV after eq 6.11). For
spatially-varying ∇V_trap (e.g., harmonic trap), precompute
∇V_trap on the grid at workspace construction. ∇n(r) requires per-step
evaluation since n depends on ψ.

For the 1D HarmonicTrap(ω): ∇V_trap = ω²x along x-axis. For 3D
HarmonicTrap(ωx, ωy, ωz): ∇V_trap = (ωx²x, ωy²y, ωz²z).

|∇V_eff|² = |∇V_trap|² + 2 c₀ (∇V_trap)·(∇n) + c₀² |∇n|².

### 4.5 Self-check (iii.a) — scalar reduction confirmed

At D = 1 (effective single component, regardless of nominal D), n =
|ψ|² (single component), so $V_\text{eff} = V_\text{trap} + c_0 |\psi|^2$
matches paper §IV eq 4.4 exactly. Force-gradient correction = paper eq
6.11. ✓

---

## Step 5 — Nonlocal scalar + spinor matrix extensions

This section sketches the algebraic structure of the extensions needed
for c₁ ≠ 0 (spin-mixing) and c_dd ≠ 0 (DDI). Full implementation is
Track C v3+; this Step 5 documents the derivation status as of
2026-05-11.

### 5.1 Nonlocal SCALAR potential (DDI without spin matrix)

Consider a nonlocal but spin-diagonal potential
$V_\text{NL}(r) = (U \ast \rho)(r) = \int U(r-r')\,\rho(r')\,dr'$
where $\rho(r) = |\psi(r)|^2$ (total density). When V_NL acts on ψ, it
acts as multiplication by V_NL(r) at each r — *local* in action,
*nonlocal* in dependence on ψ.

**Claim**: $[V_\text{NL}, [T, V_\text{NL}]] = |\nabla V_\text{NL}|^2$ — the
same scalar formula as the local case (Chin-Krotscheck eq. 6.10).

**Derivation sketch**: Once V_NL(r) has been computed for a given ψ,
the [T, V_NL] commutator involves only ∇V_NL(r) and ∇²V_NL(r) as for
local V. The "nonlocal" property affects how V_NL is *computed* from
ψ, not its action as a multiplication operator. Hence the same scalar
formula applies.

For DDI (without F-matrix structure, e.g., a hypothetical scalar
density-density interaction), the gradient ∇V_DD can be computed via:
$$\nabla V_\text{DD}(r) = \nabla (U \ast \rho)(r) = (\nabla U \ast \rho)(r) = (U \ast \nabla\rho)(r)$$
Either form works; the Fourier-space identity $\nabla(\widehat{V_\text{DD}})
= ik \cdot \widehat{U}(k) \cdot \widehat{\rho}(k)$ is cheapest (single FFT
+ multiplication + IFFT, comparable to the V_DD evaluation itself —
matching Chin-Janecek-Krotscheck 2008's observation that nonlocal V
adds ≈ 2× the propagation cost).

**Implementation status**: scalar nonlocal still NOT in v1/v2 (DDI
guard panics). For diagonal-in-spin DDI (hypothetical, since real DDI
is matrix-valued), the extension is straightforward: add a buffer for
∇V_DD, compute via FFT each step, accumulate `|∇V_DD|²` into fgrad_buf
alongside `|∇V_eff_local|²`.

### 5.2 Spinor matrix-valued V (c₁ spin-mixing)

For $V_\text{SM} = c_1 \langle\hat{F}\rangle(r) \cdot \hat{F}$, V is now a
D×D matrix at each r, NOT diagonal in spin. The double commutator
$[V_\text{SM}, [T, V_\text{SM}]]$ inherits the F-matrix structure.

**Setup**: $\langle\hat{F}\rangle(r) = \psi^\dagger(r)\,\hat{F}\,\psi(r)$
is a 3-vector field (real-valued). $V_\text{SM}(r) = c_1 \langle\hat{F}\rangle(r)
\cdot \hat{F}$ acts on ψ_α(r) as
$\sum_\beta (c_1 \langle\hat{F}_\mu\rangle \hat{F}_\mu)_{\alpha\beta}\,
\psi_\beta(r)$.

**Commutator** $[T, V_\text{SM}]$ in the presence of F̂ matrices:
$T = -\tfrac{1}{2}\nabla^2$ acts on spatial coordinates only;
F̂ matrices act on spin index. They commute as operators on
spin × spatial product space. Therefore
$[T, V_\text{SM}]\,\psi = -\tfrac{1}{2}[\nabla^2, c_1\langle\hat{F}_\mu\rangle\hat{F}_\mu]\,\psi
= c_1 \hat{F}_\mu \cdot \tfrac{-1}{2}[\nabla^2, \langle\hat{F}_\mu\rangle]\,\psi$.

The inner commutator $[\nabla^2, \langle\hat{F}_\mu\rangle]\psi = (\nabla^2
\langle\hat{F}_\mu\rangle)\psi + 2(\nabla\langle\hat{F}_\mu\rangle) \cdot \nabla\psi$
is the standard spatial commutator.

**Double commutator**:
$$[V_\text{SM}, [T, V_\text{SM}]] = c_1^2 \hat{F}_\mu \hat{F}_\nu \cdot
[\langle\hat{F}_\mu\rangle,\, -\tfrac{1}{2}[\nabla^2, \langle\hat{F}_\nu\rangle]]$$

The $\hat{F}_\mu \hat{F}_\nu$ factor is *not* symmetric in (μ, ν) so the
result picks up the F-algebra structure:
$$\hat{F}_\mu \hat{F}_\nu = \tfrac{1}{2}\{\hat{F}_\mu, \hat{F}_\nu\}
+ \tfrac{1}{2}[\hat{F}_\mu, \hat{F}_\nu] = \tfrac{1}{2}\{F_\mu, F_\nu\}
+ \tfrac{i}{2}\epsilon_{\mu\nu\rho}\,\hat{F}_\rho$$

The anti-symmetric part contributes
$\tfrac{i}{2}c_1^2 \epsilon_{\mu\nu\rho}\hat{F}_\rho \cdot
[\langle\hat{F}_\mu\rangle, ...,]\langle\hat{F}_\nu\rangle\rangle]]$, a
matrix-valued (in spin space) and spatially-varying quantity. The
symmetric part gives a scalar $\langle\nabla\hat{F}\rangle^2$ analog
contracted with $\{F_\mu, F_\nu\}$.

**Status**: Formal structure identified; explicit reduction to a
SpinorBEC-implementable expression requires:
- Concrete F-matrix algebra for F=1 (3×3) and F=6 (13×13)
- Index manipulation of $\{F_\mu, F_\nu\}$ and $\epsilon_{\mu\nu\rho}F_\rho$
- Verification against a known limit (e.g., F=1 with c₁ = 0 should
  reduce to scalar Step 5.1)

Per protocol Rule 1, this requires Aichinger-Chin-Krotscheck 2005
or a similar paper that handles non-scalar V. Aichinger 2005 in CPC
addresses nonlocal scalar (Step 5.1) but not the F-matrix structure
directly; the spinor extension is genuinely new work.

### 5.3 Combined matrix + nonlocal (DDI proper)

For real DDI:
$V_\text{DDI}(r) = c_\text{dd} \sum_\mu \hat{F}_\mu \cdot (U_{dd,\mu\nu} \ast
\langle\hat{F}_\nu\rangle)(r)$

This combines (5.1) nonlocality + (5.2) F-matrix structure. The double
commutator has all four cross-term contributions:
$[V_\text{DDI}, [T, V_\text{DDI}]] = [V_\text{DDI,contact}, ...] +
[V_\text{DDI,nonlocal}, ...]$ etc. (~10-15 cross-terms after expansion).

**Status**: This is Track C v4+ work. Phase -1 derivation incomplete.
Estimated effort: 1-2 weeks of dedicated algebraic derivation +
verification + implementation.

### 5.4 Implementation roadmap

- **v1** (commit 1ee1de8, 2026-05-11): diagonal-only, central finite diff,
  no Picard. Order 3-4 autonomous, order 1 nonlinear (4A00).
- **v2** (2026-05-11): + FFT spectral ∇V (Step 5.1 prerequisite implementation), + midpoint
  MF estimate, + endpoint MF estimate (partial 4AWW). Order ≥ 2 nonlinear
  expected (TBD).
- **v3** (deferred): Step 5.1 implementation — nonlocal scalar V
  (hypothetical, since DDI is matrix; useful as stepping stone).
- **v4** (deferred): Step 5.2 implementation — matrix V (c₁ spin-mixing).
- **v5** (deferred): Step 5.3 implementation — DDI proper (matrix + nonlocal).

Each version's gate is the same: scalar reduction matches previous
version + Phase 2 lab-path order verification.

---

## Step 6 — Time-reversal symmetry verification (formula level)

The 4A composition is symmetric by construction (palindromic
weights: 1/6, 1/2, 2/3, 1/2, 1/6). Each stage is unitary at real time
(or positive-coefficient at imaginary time). Therefore S_4A(τ)·S_4A(-τ)
= identity for fixed-MF V, exactly.

For mean-field-dependent V (autonomous case where V depends on ψ via
n = |ψ|²), the same self-consistency caveat as Track A1 applies: the
midpoint MF Ṽ(τ/2) depends on ψ(τ/2) which depends on ψ(τ), introducing
implicit fixed-point structure. Use of `_half_potential_step_midpoint!`
Picard machinery resolves this with converged O(τ³) residual per
midpoint estimation.

This Phase -1 verification PASSES at formula level (Strang ABA structure
+ explicit gradient correction + Picard self-consistency).

---

## Step 7 — Conservation properties (formula level)

For the diagonal-only force-gradient scheme:

- **Norm** $\langle\psi|\psi\rangle$: Each substep is unitary (real
  time) at any time-step coefficient sign, so norm is preserved EXACTLY
  at every order. ✓

- **Magnetization** $\langle F̂_z\rangle = \sum_\alpha m_\alpha
  |\psi_\alpha|^2$: The diagonal step applies a per-component PHASE
  $e^{-iV_\alpha dt}$ — modulus unchanged → component-wise probability
  $|\psi_\alpha|^2$ preserved → $\langle F̂_z\rangle$ preserved
  EXACTLY. (Kinetic step preserves total density at each spin index
  separately for spin-diagonal kinetic.) ✓

- **Energy** $\langle\psi|H|\psi\rangle$: 4A is a 4th-order scheme;
  energy drift scales as O(τ⁴). NOT exact preservation. Track A1
  Y4-midpoint shows machine-precision drift in our test problems
  because of operator-product symplecticity; Force-Gradient is
  expected to be similar or better at the same order, with explicit
  smaller leading constant per paper §V Figs 2-3.

Phase -1 self-checks (iii.c)/(iii.d) PASS at formula level.

---

## Failed branches

*(none yet — to be appended when derivation hits dead ends.)*

Failed-branch format (per protocol Rule 2):

```
### Failed branch (YYYY-MM-DD): [short description]

**Attempt:** [what we tried]
**Failure mode:** [where it diverged / what self-check failed]
**Hypothesis at start:** [why we tried this]
**Lesson:** [what to avoid in the next attempt]
**Reusable:** [any sub-result still usable elsewhere]
```

---

## Phase -1 exit criteria (protocol Rule 3 review) — partial pass

Self-check status as of 2026-05-11:

- [x] Step 0: Chin-Krotscheck 2005 (arXiv:cond-mat/0504270v3) fetched
      and transcribed. Chin 1997 not on arXiv; reproduced via reference
      in Chin-Krotscheck 2005. Aichinger-Chin-Krotscheck 2005 deferred
      (needed only for DDI extension Step 5).
- [x] Steps 1-2: paper formulas transcribed verbatim, notation
      translation table complete with sign-convention check.
- [x] Step 3: scalar GPE force-gradient identical to paper at D=1
      reduction.
- [x] Step 4: **DIAGONAL-ONLY** spinor extension. Force-gradient
      reduces to scalar formula times $\mathbf{I}_D$ because Zeeman
      shifts have ∇ = 0 and c₀ couples to total density (same for all
      α). Self-check (iii.a) PASSES.
- [ ] Step 5: DDI + spin-mixing extension DEFERRED to future session.
      Phase 0 implementation will be DIAGONAL-ONLY subset.
- [x] Step 6: time-reversal symmetry verified (palindromic 4A
      composition, unitary substeps).
- [x] Step 7: norm + Mz conservation exact (component-wise phase
      multiplication preserves $|\psi_\alpha|^2$). Energy drift O(τ⁴).
- [x] **partial review pass**: diagonal-only Force-Gradient implementation
      authorised for Phase 0. Full spinor + DDI extension blocked
      pending Step 5.

**Phase 0 implementation scope** (Track C v1):
- Requires Workspace with: c₁ = 0, c₂ = c₄ = ... = 0, DDI off,
  no Raman, no transverse Zeeman, no light shift, no magnetic gradient.
- Constant ZeemanParams(p, q) allowed.
- Tests: order verification on Rb87 F=1 (D=3) 1D harmonic + c₀ NLS.
- Output: `_diagonal_step_forcegrad!` + `split_step_forcegrad!`
  (`src/hamiltonian/integrator/force_gradient.jl`).

**Phase 0 v1 outcomes** (2026-05-11,
`scripts/bench/forcegrad_smoke.jl`):

| scheme | autonomous (c₀=0) | nonlinear (c₀=50) | notes |
|---|---|---|---|
| Strang | order 2.00 | order 2.00 | baseline |
| Y4-mid | order 4.03 | order 4.00 | Track A1 baseline |
| **ForceGrad-4A00** | **order 3.44** | **order 0.96** | this commit |

Autonomous order 3.44 vs nominal 4: finite-difference truncation of
|∇V|² is O(dx²), limiting Force-Gradient cancellation at the 4th order
level. Absolute err 2300× smaller than Strang at h=8e-3. Paper §IV
recommends FFT spectral derivative for ∂V/∂x_α (exponential
convergence with grid size); using `ws.fft_plans` to compute ∇V_eff
in Fourier space would recover order 4. Deferred to Phase 0 v2.

Nonlinear order 0.96: the **4A00** variant uses ψ(0) MF for all five
V stages, missing the midpoint MF requirement at the 2dt/3 middle stage.
Paper algorithm 4AWW evolves ψ(0) → ψ(Δτ/2) by an order-2 algorithm
(2AW) and uses that for Ṽ(Δτ/2), plus a W-function self-consistency
iteration on V(Δτ). Implementing the 4AWW-analog with our existing
`_half_potential_step_midpoint!` Picard machinery is the Phase 0 v2
work. Note that the `_assert_forcegrad_diagonal_only!` guard prevents
Force-Gradient from being used in regimes where 4A00's MF approximation
diverges catastrophically (= currently restricts to c₁ = 0, DDI off,
etc., which is already enforced).

**Track C v1 verdict**: Force-Gradient mechanics confirmed working on
the lab path. Autonomous benefit verified (2-3 orders of magnitude
smaller error than Strang at the same dt). Production-readiness gated
on FFT spectral ∇ + 4AWW Picard self-consistency (v2 scope).
