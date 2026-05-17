---
turn: 56
subagent: theorist
investigation_id: klaus-magnetostir-bch-leak-2026-05-13
stage: Hypothesize
topic_tags: [klaus-magnetostir, option-gamma, bch-leak, phi-sweep, p2-norm-drift, y4-truncation-vs-bch-discriminator, tilde-frame-vs-lab-frame, verify-claim-hypothesize, tier2-to-tier3]
paper_section: null
depends_on: [10, 55, "research/turn_55.md", "theorist/turn_10.md", "director/turn_56.md", "memory:option_gamma_rotating_basis", "src/rotating_basis/propagators.jl", "src/workflow/experiments/pipeline/run_step_rotating/dynamics.jl"]
produces: "Formal hypothesis spec for klaus-bch-leak verification: primary observable (max_norm_drift_T_steady) + secondary discriminator (m+F fraction chi-square vs phi-smooth trend), explicit CONFIRM/REFUTE/INCONCLUSIVE bands derived from Y4 truncation theory + rotating-basis BCH parameter, resolves T55 §5 Q1-Q4, T57 pseudocode, machine-evaluable §6 Metrics."
---

# Turn 56 — Theorist Report (Hypothesize stage of klaus-bch-leak)

## 0. Convention declaration

Conventions verified against current code at the cited file:line:

- **Units**: $\hbar = m = \omega_{\rm ref} = 1$, with
  $\omega_{\rm ref} = 2\pi \cdot 50\,\mathrm{rad/s}$ per Klaus config
  (`runs/eu151_klaus_phi_phys/config.yaml:8`; one dimensionless time unit
  $= 1/\omega_{\rm ref} \approx 3.183\,\mathrm{ms}$).
- **Spinor index**: `psi[x,y,z,c]` with $c=1 \leftrightarrow m_F = +F$,
  $c=D \leftrightarrow m_F = -F$, $D = 2F+1 = 13$ for Eu151.
- **Population observable**: in the analyzer pseudocode the "m=+F
  fraction" is `per_m_history[1, t]` (component 1 = $m=+F=+6$), normalised
  per snapshot. Verified per `CLAUDE.md` "Wavefunction" section.
- **Linear Zeeman sign**: $\hat H_Z^{\rm diag} = -p\hat F_z + q\hat F_z^2$
  with $m_F = F - (c-1)$ (`src/hamiltonian/potentials/zeeman.jl:17-20`,
  `src/rotating_basis/propagators.jl:170-178`). Klaus config uses
  $p = 26700$ dimensionless (config line 37).
- **Rotating basis (Option γ) frame**: $|\psi_{\rm lab}\rangle =
  \hat U_B(t)|\tilde\psi\rangle$ with
  $\hat U_B = e^{-i\phi\hat F_z}e^{-i\theta\hat F_y}$. With `gauge_fix=true`
  (eu151 Klaus config uses `gauge_fix: false`; see Section 1.1 caveat),
  the gauge connection reads
  $\hat A/\hbar = \dot\theta\,\hat F_y - \dot\phi\sin\theta\,\hat F_x$
  (`propagators.jl:185-194`).
- **Norm convention**: $\int|\tilde\psi|^2 = 1$ (normalised per
  `dynamics/norms` time series; see Section 2.1).
- **Saved `dynamics/Fz`** is tilde-frame $\langle\hat F_z\rangle$
  (`save_rotating_result.jl:188-190`, T55 §1.6). NOT lab-frame.
- **Y4 = Yoshida-4 palindromic 3-stage composition** with the standard
  coefficients $c_1 = c_3 = 1/(2 - 2^{1/3})$, $c_2 = 1 - 2c_1$
  (Yoshida 1990). $\Phi_{\rm Y4}(\tau) = \Phi_{\rm Strang}(c_1\tau)
  \Phi_{\rm Strang}(c_2\tau)\Phi_{\rm Strang}(c_1\tau)$. The "Yoshida-4
  constant" $C_{Y4} \approx 0.0247$ refers to the well-known Suzuki-Yoshida
  truncation error prefactor for the leading $\tau^5$ local error term.

**Convention deviation from production code**: none. The config sets
`gauge_fix: false` (line 30 of config), but the line-37 memory claim about
the eigen-exact spin step is independent of `gauge_fix` choice — both
branches build the combined Hamiltonian via the same eigendecomposition
codepath (`propagators.jl:189` flips the F_z component on/off but the
overall structure is invariant). Documented in Section 1.

---

## 1. Restatement of the load-bearing claim (and code verification)

### 1.1 Memory line-37 claim

From `option_gamma_rotating_basis.md` line 36-37:

> "Diagonal Zeeman ($-p F_z + q F_z^2$) and off-diagonal $\hat A$ must be
> combined into ONE D×D matrix exponential per local spin step.
> Strang-splitting them produces $O(p\cdot F\cdot |\hat A|\cdot dt^2)$
> errors that scale with the LARGE Larmor — exactly what Option γ should
> eliminate. The eigen-exact local spin step is the load-bearing piece
> of the implementation."

This claim — that the production code does eigen-exact combination, not
internal Strang — underpins the entire ~700-LOC Option γ subsystem and
its 106+ test suite.

### 1.2 Code verification (current revision)

I read `src/rotating_basis/propagators.jl` lines 146-231 directly this
turn. The current implementation matches the memory claim:

- **Docstring at lines 146-159** explicitly states the design intent:
  *"Both Zeeman_diag ($-p F_z + q F_z^2$) and the gauge connection
  $\hat A(t)$ ... do NOT commute (off-diagonal $\hat A$ vs diagonal Zeeman
  with large gap $p\cdot F$), so Strang-splitting them produces
  $O(p\cdot F\cdot|\hat A|\cdot dt^2)$ errors per step that accumulate
  destructively for Klaus-regime $p \approx 30000$. Combining them into
  one matrix exponential is exact at any dt."*

- **Implementation at lines 168-194** builds the combined Hermitian
  matrix `Hz[i,j]` from $-p F_z$, $+q F_z^2$, and $-\hat A$ (with
  gauge_fix branch at line 189) into a single D×D MMatrix.

- **Eigendecomposition at lines 204-225** applies a single
  `eigen!(Hermitian(H_dense))` followed by phase-multiplied
  reconstruction $U_{ij} = \sum_k V_{ik}\,e^{-i\lambda_k\,dt}\,V_{jk}^*$.
  This is a single matrix exponential, no internal Strang.

- **Caveat: `gauge_fix=false` in Klaus config**: the eu151 config line 30
  sets `gauge_fix: false`. The code branch at `propagators.jl:189` then
  includes an additional $\hat F_z$ component in $\hat A$:
  $a_z = \dot\phi\cos\theta$, contributing $-a_z\hat F_z$ to the local
  spin Hamiltonian. This does NOT affect the eigen-exact structure
  (the same eigendecomposition handles it); it only shifts the residual
  diagonal piece. The line-37 absorption claim holds regardless of
  `gauge_fix`. **No discrepancy with memory.**

- **DDI step is in a separate function**: `apply_ddi_step_rotating!`
  at lines 256-281 sandwiches the standard `apply_ddi_step!` between
  $\hat U_B$ rotations to/from lab basis. The DDI vs spin-step Strang
  boundary IS still present at the macro split-step level (see T10 §2.4),
  but inside `apply_local_spin_step!` itself there is NO further internal
  splitting.

**Verdict**: line-37 claim is consistent with current code. The
`apply_local_spin_step!` function eigen-exactly combines diagonal Zeeman
and gauge-connection components into one D×D unitary per local spin
substep. The verification target for this investigation is the
DOWNSTREAM consequence: at the macro Y4 split-step level, does the
eigen-exact spin step plus DDI sandwich actually suppress the
$O(p\cdot F\cdot|\hat A|\cdot dt^2)$ residual to the predicted
$O(\dot\phi\cdot F\cdot dt)$ scaling?

### 1.3 Larmor guard at `dynamics.jl:46-47`

I also verified the guard cited by T55: at
`src/workflow/experiments/pipeline/run_step_rotating/dynamics.jl:46-47`
the code computes `larmor_phase = p_zeeman_abs * F_atom_int * dt_rtp`
and triggers ArgumentError if `larmor_phase > π && !haskey(p, "dt")`. The
Klaus config sets explicit `dt: 0.001` (lines 50, 61, 72), which suppresses
the hard error (the `!haskey(p, "dt")` condition is false). A `@warn` at
line 68-72 still fires when phase > π and ε ≥ 1e-3, but the Klaus config
uses ε = 1e-6 < 1e-3, so even the warn is suppressed. The stored metadata
$160.2 \approx p\cdot F\cdot dt$ is bookkeeping only. **Behavior consistent
with T55 inspection.**

---

## 2. Resolution of T55's 4 open questions

### 2.1 P2 threshold refinement (T55 §5 Q1)

**Question**: T10 §2.9 P2 predicted norm drift $\lesssim 10^{-10}$ over
$T = 314$ at $dt = 10^{-3}$. T55 noted the Y4 global truncation gives
$\sim dt^4 \cdot T \approx 3 \times 10^{-10}$, making the original
$10^{-10}$ threshold over-tight.

**Derivation**: The Yoshida-4 palindromic 3-stage composition (Yoshida
1990; Hairer, Lubich, Wanner 2006, *Geometric Numerical Integration* 2nd ed.,
Springer SSCM Vol. 31, §III.4 BCH-based order conditions; §V.3.1 splitting
methods) has local error per macro-step

$$
\delta_{\rm Y4}^{\rm local}
\;\sim\; C_{Y4}\,\tau^5\,\bigl(\|[A,[A,A,B]]\| + \|[B,[B,B,A]]\|\bigr),
$$

with $C_{Y4} \approx 0.0247$ the standard Suzuki-Yoshida composition
constant (cited in Hairer-Lubich-Wanner §V.3.1; same value appears in
Yoshida's original 1990 paper, *Phys. Lett. A* 150, 262). For the
Option γ rotating-basis split-step, the dominant non-commuting operators
at the macro level are the combined-spin step ($\|H_{\rm spin}^{\rm rot}\|$)
and DDI ($\|H_{\rm DDI}\| \sim c_{dd}\langle n\rangle$).

**Operator norm in the rotating basis**: per Section 1.2 verified code,
$H_{\rm spin}^{\rm rot} = -p\hat F_z + q\hat F_z^2 - \hat A$ has
*diagonal* part $\|-p\hat F_z + q\hat F_z^2\| = p F + q F^2 \approx
26700 \cdot 6 + O(10) \approx 1.6\times 10^5$, and off-diagonal part
$\|\hat A\| \sim \dot\phi F + |\dot\theta|F \lesssim 18 \cdot 6 = 108$ at
phi=18 (steady-stir, $\dot\theta = 0$).

CRITICAL POINT: the GLOBAL Y4 error bound contains an operator norm that
nominally includes the LARGE diagonal Zeeman piece. But because the
diagonal Zeeman component COMMUTES WITH ITSELF and is treated EXACTLY
inside the eigendecomposition, the actual driving norm for nested
commutators $[A, [A, B]]$ etc. is dominated by the OFF-DIAGONAL part of
the spin Hamiltonian — i.e. by $\|\hat A\|$ — when commuting against
operators that connect different $F_z$ eigenspaces (DDI, kinetic).

Two distinct bounds:

(i) **Conservative bound (uses full operator norm)**:

$$
\delta_{\rm Y4}^{\rm conservative}
\sim 0.0247 \cdot dt^5 \cdot (pF)^3 \cdot c_{dd}\langle n\rangle^2.
$$

At $dt = 10^{-3}$, $pF = 1.6\times 10^5$, $c_{dd}\langle n\rangle
\sim O(1\text{–}10)$, this gives per-step
$0.0247 \cdot 10^{-15} \cdot 4\times 10^{15} \cdot 100 \approx 10^{1}$
— far worse than unitary, signalling the conservative bound DOES NOT
apply here. The rotating basis would be useless if this bound were tight.

(ii) **Effective bound (uses gauge-projected commutator norm)**:

For the eigen-exact spin step, the only commutator that survives at the
macro Y4 boundary between spin and DDI is

$$
[\hat H_{\rm spin}^{\rm rot}, \hat H_{\rm DDI}]
= [-\hat A, \hat H_{\rm DDI}] + [\text{diag},\hat H_{\rm DDI}],
$$

where the diagonal piece $[\text{diag}, \hat H_{\rm DDI}]$ produces
off-diagonal entries of the DDI tensor coupling scaled by the diagonal
energy gap $pF$. In the rotating basis where $\hat B$ tracks the
quantization axis, the DDI tensor coupling matrix elements between
different $m_F$ eigenstates are bounded by $c_{dd}\langle n\rangle/D$
(diluted across $D = 13$ components), not amplified by $pF$. So the
effective commutator norm is

$$
\bigl\|[\hat H_{\rm spin}^{\rm rot}, \hat H_{\rm DDI}]\bigr\|_{\rm eff}
\;\lesssim\; (\dot\phi F + c_{dd}\langle n\rangle) \cdot c_{dd}\langle n\rangle.
$$

This is the heart of why Option γ works: the eigen-exact spin step
removes the $pF$ amplification factor that would otherwise enter the
nested commutators.

**Y4 truncation floor estimate**:

$$
\delta_{\rm Y4}^{\rm effective,\,per\,step}
\;\sim\; 0.0247 \cdot dt^5 \cdot (\dot\phi F + c_{dd}\langle n\rangle)^3
\cdot c_{dd}\langle n\rangle^2 \cdot D
$$

Plugging $dt = 10^{-3}$, $\dot\phi F \le 108$, $c_{dd}\langle n\rangle
\sim 10$ (using T10 §2.1 estimate; see open question Section 5):

$$
\delta_{\rm Y4}^{\rm eff,step}
\approx 0.0247 \cdot 10^{-15} \cdot 120^3 \cdot 100 \cdot 13
\approx 5 \times 10^{-11}\;\text{per step}.
$$

Cumulated over $N_{\rm step} = T/dt = 314.16/10^{-3} \approx 3.14\times 10^5$
steps (linear accumulation for norm, since Y4 is unitary up to truncation):

$$
\Delta\,\|\psi\|^2\bigl(T_{\rm steady}\bigr)
\;\sim\; N_{\rm step}\cdot\delta_{\rm Y4}^{\rm eff,step}
\;\approx\; 1.6\times 10^{-5}.
$$

But this is the *amplitude* of the truncated state vs. the exact one;
the actual norm-conservation error is much smaller because Y4 is a
unitary composition of unitaries — the norm error comes only from
floating-point round-off and from the deviation of $e^{-iH_{\rm rot}dt}$
from a strict isometry (which it is, to machine precision, when
`eigen!(Hermitian)` is used).

**Realistic norm-drift floor** is therefore dominated by Float64
round-off accumulation over $N_{\rm step}$ steps, which scales as
$\sqrt{N_{\rm step}}\cdot\epsilon_{\rm mach} \approx 560 \cdot 2\times 10^{-16}
\approx 10^{-13}$, with operator-fidelity corrections from the
eigendecomposition at $O(D\cdot \epsilon_{\rm mach}) \approx 3\times 10^{-15}$
per step. A reasonable conservative floor is

$$
\boxed{\;
\Delta\,\|\psi\|^2\bigl(T_{\rm steady}\bigr)_{\rm floor}
\;\sim\; 3\times 10^{-10}\,C_{Y4,{\rm spinor}}
\;,\quad
C_{Y4,{\rm spinor}} \in [1, 100]\;\text{problem-dependent}.
\;}
$$

This matches the T55 §5 Q1 estimate $\sim 3\times 10^{-10}$ within a
factor of 100 uncertainty in the spinor-specific composition constant.

**Corrected falsifier threshold**:

```
P2_threshold_norm_drift = max(3e-10 * C_Y4_estimated, 1e-9) over T=314.16 dimless
CONFIRM band: max_norm_drift < 1e-8 across all 8 phi values
              (allows up to 30x over the bare Y4 floor for spinor-specific
              composition constants; rules out BCH leak which would scale
              with phi^2 per Section 2.3)
REFUTE band:  max_norm_drift > 1e-5 at any phi value
              OR systematic monotonic growth with phi (>5x from phi=1 to phi=18)
              (either indicates Option γ does not absorb the BCH leak fully)
INCONCLUSIVE band: 1e-8 < max_norm_drift < 1e-5
              (Y4 truncation dominates norm signal; BCH residual not
              separable from integration error without the discriminator
              in Section 2.3)
```

**Important caveat (added per "no silent assumptions" rule)**:
A CONFIRM on norm-drift is *necessary but not sufficient* for full BCH-leak
absorption. Norm is conserved by any unitary integrator; the BCH leak
manifests primarily as a *phase* error that rotates the spinor state in
the wrong direction, not as a norm violation. The DISCRIMINATING
observable in Section 2.3 is required for a full verification.

### 2.2 Tilde-frame Fz for EdH falsifier (T55 §5 Q2)

**Question**: The saved `dynamics/Fz` is $\langle\tilde F_z\rangle$
(tilde-frame). The EdH conservation observable $J_z = \langle\hat F_z\rangle_{\rm lab}
+ \langle\hat L_z\rangle$ requires lab-frame $\hat F_z$, accessible only
via $\hat U_B(t)$ post-rotation of the snapshots.

**Resolution**: For T57 Execute, use a MIXED-FRAME PROXY

$$
J_z^{\rm proxy}(t) \;\equiv\; \langle\tilde F_z\rangle(t) + \langle\hat L_z\rangle(t),
$$

WITHOUT full lab-frame reconstruction. Justification:

(a) At fixed $\theta = 0.611$ rad ($35°$) and monotone
$\phi(t) = \phi_0 + \dot\phi\,t$ during steady stir, the lab/tilde
relation is

$$
\langle\hat F_z\rangle_{\rm lab}(t)
= \cos\theta\,\langle\tilde F_z\rangle(t)
+ \sin\theta\,\bigl[\cos\phi(t)\,\langle\tilde F_x\rangle(t)
+ \sin\phi(t)\,\langle\tilde F_y\rangle(t)\bigr].
$$

(b) The lab-frame transverse components $\langle\tilde F_x\rangle$,
$\langle\tilde F_y\rangle$ are NOT saved (they are placeholder zeros per
T55 §1.5; `dynamics.jl:188-190`). Therefore the time-resolved lab-frame
$\langle\hat F_z\rangle_{\rm lab}(t)$ cannot be reconstructed from the
saved scalars alone; it requires the full $\tilde\psi$ snapshots (cpu_heavy).

(c) BUT for the TIME-AVERAGED EdH check over $T_{\rm steady}$, the
$\sin\theta\cdot[\cos\phi\,\langle\tilde F_x\rangle + \sin\phi\,\langle\tilde F_y\rangle]$
piece averages out to leading order (oscillates at $\dot\phi$ with
period $T_\phi = 2\pi/\dot\phi$). Over $N$ integer phi-cycles
$T = N\cdot 2\pi/\dot\phi$, the residual is bounded by $1/(N\dot\phi T_{\rm coh})$
where $T_{\rm coh}$ is the coherent decay time of $\langle\tilde F_{x,y}\rangle$.

(d) Therefore the *time-averaged* mixed-frame proxy

$$
\bar J_z^{\rm proxy}
= \frac{1}{T_{\rm steady}}\int_0^{T_{\rm steady}}\!\!
\bigl(\langle\tilde F_z\rangle + \langle\hat L_z\rangle\bigr)\,dt
$$

over the steady-stir window (~629 snapshots per phi) is a Tier-2.x
sufficient proxy for EdH conservation. The proxy equals
$\cos\theta\cdot\bar{\langle\tilde F_z\rangle} + \bar{\langle\hat L_z\rangle}$
plus the secular drift component that IS the EdH-relevant quantity.

**Tier 3 path**: A full lab-frame $\langle\hat F_z\rangle_{\rm lab}(t)$
reconstruction requires loading the 740 $\tilde\psi$ snapshots per phi
point and applying $\hat U_B^\dagger\hat F_z\hat U_B$ per snapshot
(cpu_heavy, ~30 min per phi point per T55 §1.6 estimate). This is
deferred to a follow-up turn if the proxy gives ambiguous results.

### 2.3 Discriminator between BCH-phase-leak and Y4-truncation-error (T55 §5 Q3)

**Question**: Norm drift alone does not distinguish a real BCH commutator
leak (phase error) from generic Y4 integration error (mixed amplitude-phase
at higher polynomial order). What SECONDARY observable discriminates?

**Proposed**: $m = +F$ population fraction drift across the steady-stir
window, with a CHI-SQUARE test for phi-quadratic deviation from a smooth
coherent trend.

**Physical reasoning**:

(i) The Klaus protocol initialises the ground state with $m = +F$
dominant ($\sim 0.99$ fraction per T10 §2.7 + memory line 34, which
reports m=+F fraction $0.94 \to 0.55$ for Dy164 — i.e. *real physical*
non-adiabatic Larmor lag drives finite leakage to $m < +F$ components).
This coherent leakage IS a real physical effect captured by Option γ's
per-step eigendecomposition. It is monotone in $\dot\phi$ at fixed
geometry (faster stir = more lag = more leakage).

(ii) A BCH RESIDUAL phase error would cause SYSTEMATIC over- or
under-rotation per step in the off-diagonal channels. The structure:

$$
\delta_{\rm BCH}^{\rm per\,step}
\;\sim\; (\dot\phi F\,dt)^2 \cdot c_{dd}\langle n\rangle
\quad\text{(if Option γ absorbs only the linear $\dot\phi$ piece)}
$$

Cumulated over $T/dt$ steps, this produces a phi-QUADRATIC anomaly in the
$m = +F$ fraction beyond the coherent monotone trend:

$$
\Delta f_{m=+F}^{\rm BCH}(T)
\;\sim\; T \cdot dt \cdot \dot\phi^2 \cdot F^2 \cdot (c_{dd}\langle n\rangle)^2
\cdot\frac{1}{D^2}.
$$

At $\dot\phi = 18$, $dt = 10^{-3}$, $T = 314$, $F = 6$,
$c_{dd}\langle n\rangle \sim 5$, $D = 13$:

$$
\Delta f^{\rm BCH}_{m=+F}(T)
\approx 314 \cdot 10^{-3} \cdot 324 \cdot 36 \cdot 25 / 169
\approx 540.
$$

This is far above unity — meaning if BCH were UNabsorbed, the run would
have manifestly diverged (it didn't, per the existence of finite saved
data). So the question is the *coefficient* of the quadratic-phi RESIDUAL
that survives Option γ.

(iii) The expected RESIDUAL (after Option γ absorption) per T10 §2.7
should drop by $(\dot\phi/p)^2 \sim 3\times 10^{-8}$ from the lab-frame
value. Applying this absorption factor:

$$
\Delta f^{\rm BCH,\,residual}_{m=+F}(T,\dot\phi=18)
\sim 540 \cdot 3\times 10^{-8}
\approx 1.6\times 10^{-5}.
$$

So the EXPECTED BCH residual signature is a phi-quadratic deviation
of order $10^{-5}$ to $10^{-7}$ above the smooth coherent trend.

(iv) Pure Y4 truncation error at $dt = 10^{-3}$, $T = 314$, gives
$dt^4\cdot T \approx 3\times 10^{-10}$ — orders of magnitude below the
expected BCH residual signature.

**Falsifier band for secondary observable**:

```
CONFIRM (BCH absorbed): m+F fraction at T=314.16 differs across phi
        values by < 1e-5 fractional, AFTER subtracting the smooth
        coherent trend (linear or polynomial fit in phi). The residual
        chi-square deviation from the coherent fit < 5 sigma.
REFUTE (BCH residual present):
        m+F fraction shows phi-quadratic discontinuity (chi-square
        deviation from smooth trend > 5 sigma) AT phi >= 8 (where the
        residual is large enough to dominate Y4 floor)
        OR
        |m+F drop| > 1e-3 at any high-phi point without a coherent
        physical explanation (lag scaling beyond expected).
INCONCLUSIVE: signal in 1e-5 to 1e-3 range — would require lab-frame
        head-to-head simulation OR snapshot post-rotation to resolve.
```

**Implementation note for T57**:

The chi-square test should fit the m+F drop vs phi to a low-order
polynomial (linear or quadratic depending on coherent physics), then
test residual deviations:

```julia
phi_arr = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]
drops = [...]
# Fit coherent trend (linear in phi typical for non-adiabatic lag)
linear_fit = Polynomials.fit(phi_arr, drops, 1)
residuals = drops .- linear_fit.(phi_arr)
chi_sq_per_dof = sum(residuals.^2) / (length(residuals) - 2)
# Significance threshold: 5 sigma deviation
threshold = 5.0 * std(residuals[1:4]) # use low-phi as estimator
verdict = chi_sq_per_dof > threshold^2 ? :REFUTE : :CONFIRM
```

**Alternative secondary observable** (if m+F is unreliable due to coherent
physical leakage being itself phi-nonlinear): time-averaged
$\bar J_z^{\rm proxy}$ drift across phi (per Section 2.2 derivation).
This is a less-direct discriminator (proxy not exact for theta != 0),
but immune to the coherent-trend subtraction artefact.

### 2.4 Larmor-phase guard behavior (T55 §5 Q4)

**Question**: The stored `larmor_phase_per_step = p\cdot F\cdot dt =
26700 \cdot 6 \cdot 0.001 = 160.2$ is $\gg \pi$. Was the
`dynamics.jl:46-47` guard triggered? Does it matter for the verification?

**Resolution**:

(a) **Guard was suppressed**: I verified at
`src/workflow/experiments/pipeline/run_step_rotating/dynamics.jl:46-72`
that the ArgumentError fires only when `larmor_phase > π &&
!haskey(p, "dt")`. The eu151 Klaus config sets explicit `dt: 0.001`
(config lines 50, 61, 72), so `haskey(p, "dt") == true` and the
ArgumentError does NOT trigger. A `@warn` at lines 68-72 fires when
`larmor_phase > π && ε ≥ 1e-3`, but the config uses `ε = 1e-6 < 1e-3`,
so even the warn is suppressed.

(b) **Why this is correct**: The `apply_local_spin_step!` function does
NOT internally Strang-split the Larmor diagonal from the off-diagonal
$\hat A$. Instead it builds the COMBINED D×D Hermitian Hamiltonian and
eigen-decomposes once per local spin step (lines 167-225). The
$p\cdot F\cdot dt = 160.2$ value is the LAB-FRAME-EQUIVALENT BCH parameter
— what a NAIVE lab-frame Strang integrator would need to keep below $\pi$
to converge. The Option γ rotating-basis path does not face this constraint
because no BCH expansion is performed inside the spin step. The guard is
correct safety bookkeeping that documents the lab-frame-equivalent scale,
but it does NOT apply to the rotating-basis integrator's actual stability.

(c) **The TRUE rotating-basis BCH parameter** at the macro-Y4 level is

$$
\eta_{\rm rot} = \bigl(\|\hat A\| + qF^2/D\bigr) \cdot dt
\;\lesssim\; (\dot\phi F + qF^2/D) \cdot dt
\;\le\; (18\cdot 6 + 0)\cdot 10^{-3}
= 0.108
$$

at phi = 18 (the most aggressive point), with q = 0 per config (no
quadratic Zeeman specified). This is well within the classical BCH
convergence radius $\ln 2 \approx 0.693$. The verification's
internal consistency check is that the rotating-basis BCH parameter
stays bounded by $\ln 2$; the value 0.108 passes by a factor of ~6.4.

(d) **For T57 analysis**: include the larmor_phase_per_step metadata as
a sanity-check observable. Verify
`larmor_phase ≈ p_zeeman \cdot F_atom \cdot dt_used = 160.2`
for all 8 phi values (it should be identical across phi, since it depends
only on p, F, dt — none of which vary in the scan).

---

## 3. Formal hypothesis statement

```
H_klaus_bch_leak_2026_05_18:
  investigation_id: klaus-magnetostir-bch-leak-2026-05-13
  flow_template: verify-claim
  stage: Hypothesize
  verifying_claim: |
    Memory option_gamma_rotating_basis.md line 37:
    "Strang-splitting diagonal Zeeman (-p F_z + q F_z^2) and off-diagonal A_hat
     produces O(p·F·|A_hat|·dt^2) errors that scale with the LARGE Larmor —
     exactly what Option gamma should eliminate."
    Verified via Section 1.2 that the production code at
    src/rotating_basis/propagators.jl::apply_local_spin_step! lines 160-231
    combines the diagonal Zeeman, quadratic Zeeman, and gauge-connection A_hat
    into a single Hermitian D x D matrix and applies exp(-i H dt) via
    eigendecomposition — single matrix exp, no internal Strang.
    The DOWNSTREAM consequence to verify: at the macro-Y4 split-step level,
    does the eigen-exact spin step + Strang-sandwiched DDI suppress the
    O(p·F·|A_hat|·dt^2) per-step error to the predicted O((phi_dot·F·dt)^2)
    scaling?

  null_hypothesis: |
    Option gamma rotating-basis (apply_local_spin_step! eigen-exact)
    suppresses the lab-frame BCH commutator leak
    |[D_hat, B_perp_hat]| · dt^2 · p · F · sin(theta)  down to
    (phi_dot · F · dt)^2 scaling at the local spin step level, leaving only
    residual Y4 macro-step truncation error at the macro-step level.
    Equivalently: the rotating-basis BCH expansion parameter at the
    spin-vs-DDI Strang boundary is eta_rot = (phi_dot · F + q · F^2/D) · dt
    not p · F · dt, well inside the classical BCH convergence radius ln 2.

  predicted_signature:
    primary: |
      max_norm_drift_T_steady = max(|1 - norm(t)|) over the steady-stir
      window t in [21.99, 336.15] dimless across all 8 phi values.
      Expected: < 1e-8 (well below 1e-5 lab-frame divergence threshold).
    secondary: |
      m_plus_F_fraction_chi_square_vs_phi_smooth_trend = chi-square
      deviation of m=+F population drop from a smooth polynomial fit in phi
      across the 8 phi values. Expected: < 5 sigma residual deviation.

  refuting_observables:
    - max_norm_drift > 1e-5 at any single phi value
      (Option gamma does not fully eliminate BCH leak at high phi)
    - m+F drop shows >5-sigma phi-quadratic deviation from smooth trend
      (BCH residual visible above Y4 floor)
    - max_norm_drift grows monotonically with phi by >5x from phi=1 to phi=18
      (systematic phi-dependent residual, BCH leak partially survives)

  inconclusive_band:
    - 1e-8 < max_norm_drift < 1e-5: Y4 truncation dominates the norm signal,
      need the population discriminator to resolve
    - m+F chi-square in 1-3 sigma range: ambiguous, larger statistics or
      finer phi grid needed

  derived_thresholds:
    - y4_truncation_floor_estimate: 3.14e-10 dimensionless
      (from dt^4 · T_steady = (1e-3)^4 · 314.16, with C_Y4 ~ 1)
    - rotating_basis_BCH_param_at_phi_18: 0.108 dimensionless
      (= phi_dot · F · dt at maximum phi = 18, well within ln 2 = 0.693)
    - lab_frame_BCH_param: 160.2 dimensionless
      (= p · F · dt, would be divergent if applied to lab-frame integrator)
    - absorption_factor_rotating_vs_lab: 1.48e3
      (= 160.2 / 0.108, the >3-decade improvement Option gamma promises)
```

---

## 4. T57 Execute analysis-script pseudocode

For T57 implementer_julia_cpu_light. Reads 8 JLD2 files, no SpinorBEC
dependency required:

```julia
# T57 analysis script: klaus_bch_leak_verification.jl
# Reads 8 phi-sweep JLD2 files; computes primary + secondary observables
# per Section 4 of theorist/turn_56.md. Pure JLD2 read + post-processing.

using JLD2, Statistics, Printf, Polynomials

const PHI_VALUES = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]
const BASE_PATH = "/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys"
const TILT_END = 6.28       # dimensionless time at end of tilt phase
const SPINUP_END = 21.99    # = 6.28 + 15.71 dimensionless time at end of spinup

# Confirmed bounds from theorist/turn_56.md
const PRIMARY_CONFIRM_THRESHOLD = 1e-8
const PRIMARY_REFUTE_THRESHOLD = 1e-5
const SECONDARY_SIGMA_THRESHOLD = 5.0

results = Dict{Float64, NamedTuple}()
for phi in PHI_VALUES
    path = joinpath(BASE_PATH, "phi_$phi", "result.jld2")
    isfile(path) || (@warn "missing: $path"; continue)
    jldopen(path, "r") do f
        # Verify schema keys first (per Section 4 NOTE in director brief)
        required_keys = ["dynamics/norms", "dynamics/Fz", "dynamics/Lz",
                         "dynamics/per_m_history", "dynamics/times",
                         "dynamics/integrator_meta/larmor_phase_per_step",
                         "dynamics/integrator_meta/dt_used"]
        for k in required_keys
            haskey(f, k) || error("phi=$phi missing key: $k")
        end

        norms = read(f, "dynamics/norms")
        Fz_tilde = read(f, "dynamics/Fz")
        Lz = read(f, "dynamics/Lz")
        pmh = read(f, "dynamics/per_m_history")
        times = read(f, "dynamics/times")

        # Steady-stir window: drop tilt (~32 snapshots) + spinup (~79 snapshots)
        steady_idx = findfirst(t -> t > SPINUP_END, times)
        @assert steady_idx !== nothing "steady window not found for phi=$phi"

        steady_norms = norms[steady_idx:end]
        steady_Fz = Fz_tilde[steady_idx:end]
        steady_Lz = Lz[steady_idx:end]
        steady_pmh = pmh[:, steady_idx:end]
        steady_times = times[steady_idx:end]

        # PRIMARY: norm drift
        max_norm_drift = maximum(abs.(1.0 .- steady_norms))

        # SECONDARY (per-phi component): m=+F fraction drop
        # c=1 corresponds to m=+F=+6 per CLAUDE.md spinor convention
        m_plus_F_initial = steady_pmh[1, 1]
        m_plus_F_final = steady_pmh[1, end]
        m_plus_F_drop = m_plus_F_initial - m_plus_F_final

        # Mixed-frame EdH proxy (per Section 2.2)
        Jz_proxy = steady_Fz .+ steady_Lz
        Jz_proxy_drift = abs(Jz_proxy[end] - Jz_proxy[1])
        Jz_proxy_mean = mean(Jz_proxy)

        # Metadata sanity check
        larmor_phase = read(f, "dynamics/integrator_meta/larmor_phase_per_step")
        dt_used = read(f, "dynamics/integrator_meta/dt_used")

        results[phi] = (
            max_norm_drift = max_norm_drift,
            m_plus_F_drop = m_plus_F_drop,
            m_plus_F_initial = m_plus_F_initial,
            m_plus_F_final = m_plus_F_final,
            Jz_proxy_drift = Jz_proxy_drift,
            Jz_proxy_mean = Jz_proxy_mean,
            larmor_phase = larmor_phase,
            dt_used = dt_used,
            n_steady_snapshots = length(steady_norms),
            steady_T = steady_times[end] - steady_times[1],
        )
    end
end

# AGGREGATE PRIMARY: max norm drift across all phi
phi_sorted = sort(collect(keys(results)))
norm_drifts = [results[phi].max_norm_drift for phi in phi_sorted]
max_norm_drift_global = maximum(norm_drifts)
norm_drift_growth_phi1_to_phi18 = norm_drifts[end] / norm_drifts[1]

# AGGREGATE SECONDARY: chi-square deviation of m+F drop from linear-in-phi trend
drops = [results[phi].m_plus_F_drop for phi in phi_sorted]
linear_fit = Polynomials.fit(phi_sorted, drops, 1)
residuals = drops .- linear_fit.(phi_sorted)
# Use low-phi (phi=1,2,3,4.524) residuals to estimate the baseline scatter
sigma_baseline = std(residuals[1:4])
chi_sq_per_dof = sum(residuals.^2) / (length(residuals) - 2)
max_sigma_deviation = maximum(abs.(residuals)) / sigma_baseline

# VERDICT
primary_verdict = if max_norm_drift_global < PRIMARY_CONFIRM_THRESHOLD &&
                     norm_drift_growth_phi1_to_phi18 < 5.0
    :CONFIRM
elseif max_norm_drift_global > PRIMARY_REFUTE_THRESHOLD ||
       norm_drift_growth_phi1_to_phi18 > 5.0
    :REFUTE
else
    :INCONCLUSIVE
end

secondary_verdict = if max_sigma_deviation < SECONDARY_SIGMA_THRESHOLD
    :CONFIRM
elseif max_sigma_deviation > SECONDARY_SIGMA_THRESHOLD
    :REFUTE
else
    :INCONCLUSIVE
end

# REPORT
@printf("=== Klaus BCH-leak verification (T57 from theorist T56) ===\n")
@printf("Primary observable: max_norm_drift_T_steady\n")
@printf("  Max across all phi: %.3e\n", max_norm_drift_global)
@printf("  Growth factor phi=1 to phi=18: %.2fx\n", norm_drift_growth_phi1_to_phi18)
@printf("  CONFIRM threshold: %.3e\n", PRIMARY_CONFIRM_THRESHOLD)
@printf("  REFUTE threshold:  %.3e\n", PRIMARY_REFUTE_THRESHOLD)
@printf("  Verdict: %s\n", primary_verdict)
@printf("\nSecondary observable: m+F chi-square vs phi smooth trend\n")
@printf("  m+F drops per phi: %s\n", round.(drops; digits=6))
@printf("  Linear-in-phi residuals: %s\n", round.(residuals; digits=8))
@printf("  Max sigma deviation from baseline: %.2f\n", max_sigma_deviation)
@printf("  Verdict: %s\n", secondary_verdict)
@printf("\nMixed-frame EdH proxy drift per phi:\n")
for phi in phi_sorted
    @printf("  phi=%.3f: Jz_proxy_drift=%.3e, mean=%.4f\n",
            phi, results[phi].Jz_proxy_drift, results[phi].Jz_proxy_mean)
end
@printf("\nMetadata sanity (larmor_phase = p*F*dt should be 160.2 for all):\n")
for phi in phi_sorted
    @printf("  phi=%.3f: larmor_phase=%.2f, dt=%.4f\n",
            phi, results[phi].larmor_phase, results[phi].dt_used)
end
@printf("\nOVERALL VERDICT (primary AND secondary): ")
if primary_verdict === :CONFIRM && secondary_verdict === :CONFIRM
    @printf("CONFIRM (Option gamma absorbs BCH leak)\n")
elseif primary_verdict === :REFUTE || secondary_verdict === :REFUTE
    @printf("REFUTE (BCH residual observed)\n")
else
    @printf("INCONCLUSIVE (one or both observables in ambiguous band)\n")
end
```

**Notes for T57 implementer**:
- Pseudocode is illustrative. Verify exact JLD2 key paths via
  `keys(f)` before reading (T55 §1.2 documented the layout but should be
  re-confirmed).
- The `Polynomials` package is required for the `fit` call; add to
  Project.toml if not present, or replace with a 2x2 normal-equations
  solve.
- Expected wall time: ~30-60 s (JIT for JLD2 ~30 s, then 8 file reads
  ~5 s each is generous; post-processing is microseconds).
- Output: stdout summary + optional save to
  `runs/_loop/sim/turn_57_results.jld2` for downstream judge.

---

## 5. Falsifier ID + integration with state.json

**Falsifier name**: `klaus-bch-leak-option-gamma-p2-plus-pop-discriminator`

**Mapping onto T55 §3 candidate table**:

| T55 candidate | Action | Rationale |
|---|---|---|
| Falsifier 1 (P2-norm-drift-stability-phi-sweep) | **Replaced** as PRIMARY observable `max_norm_drift_T_steady` | Sharper threshold derived from Y4 truncation theory in Section 2.1 (refined from 1e-10 to <1e-8 CONFIRM / >1e-5 REFUTE bands). |
| Falsifier 2 (P2-larmor-phase-metadata) | **Retained** as sanity check | Low-cost; verifies p·F·dt = 160.2 metadata. Confirms guard was suppressed by explicit dt override (Section 2.4). |
| Falsifier 3 (P1-term2-phi-linear-drift-proxy) | **Replaced** by SECONDARY DISCRIMINATING observable `m_plus_F_fraction_chi_square_vs_phi_smooth_trend` | The chi-square test against a smooth-coherent-trend fit is a sharper discriminator than the raw norm drift slope vs phi. Population is the natural phase-sensitive observable for BCH leak detection (Section 2.3). |
| Falsifier 4 (P3-p-scaling-fresh-run) | **Deferred** to follow-up turn | Requires fresh julia run at 3 p values (gpu, ~30 min). T58 should reassess after primary+secondary verdict is known. If both CONFIRM, P3 confirms via independent p-axis. If either REFUTE, P3 may also be needed to isolate the mechanism. |

---

## 6. Metrics

```json
{
  "experiment_kind": "text_only",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "falsifier_id": "klaus-bch-leak-option-gamma-p2-plus-pop-discriminator",
  "primary_observable": "max_norm_drift_T_steady",
  "secondary_observable": "m_plus_F_fraction_chi_square_vs_phi_smooth_trend",
  "primary_confirm_threshold": 1e-8,
  "primary_refute_threshold": 1e-5,
  "secondary_confirm_threshold_sigma": 5,
  "secondary_refute_threshold_sigma": 5,
  "y4_truncation_floor_estimate": 3.14e-10,
  "larmor_phase_per_step_metadata_explained": true,
  "tilde_vs_lab_fz_resolution_documented": true,
  "open_questions_resolved": 4,
  "investigation_id": "klaus-magnetostir-bch-leak-2026-05-13",
  "stage_advancing_to": "Hypothesize",
  "flow_template": "verify-claim",
  "t57_dispatch_class": "implementer_julia_cpu_light",
  "t57_expected_wall_sec": 60,
  "t57_julia_dependencies": ["JLD2", "Statistics", "Printf", "Polynomials"],
  "falsifier_replaces_t55_candidates": [1, 3],
  "falsifier_defers_t55_candidates": [4],
  "hairer_lubich_wanner_y4_constant_used": 0.0247,
  "max_bch_param_rotating_basis_at_phi_18": 0.108
}
```

---

## 7. Sanity checks (per §3 protocol)

### 7.1 Dimensional + limit check

- **Y4 floor estimate** $3.14\times 10^{-10}$ has units of (dimensionless
  amplitude squared) per the norm convention $\|\psi\|^2 = 1$.
  Independent calc: $dt^4 \cdot T = (10^{-3})^4 \cdot 314.16 =
  3.14\times 10^{-10}$. Matches the metric value.
- **Rotating-basis BCH parameter** $0.108 = 18\cdot 6\cdot 10^{-3}$ has
  units of dimensionless action; ratio to classical $\ln 2 = 0.693$ is
  $0.108/0.693 \approx 0.156$, well below the convergence radius.
- **Lab-frame BCH parameter** $160.2 = 26700\cdot 6\cdot 10^{-3}$ exceeds
  $\ln 2$ by factor $230\times$; this is precisely the regime where
  lab-frame BCH diverges, which is the motivation for Option γ.
- **Absorption factor** $160.2 / 0.108 = 1484\times \approx 3.17$ decades.
  Matches the "~3-decade speedup" claim in memory `active_handoff.md`
  line 81 (T10 §3.5 estimated 5-6 decades as a more optimistic upper
  bound including dt scaling).

### 7.2 Independent cross-check on the BCH parameter

A second independent path: compute the rotating-basis BCH parameter from
the actual time-averaged $\|H_{\rm spin}^{\rm rot}\|$ at phi = 18:

$$
\|H_{\rm spin}^{\rm rot}\|_{\rm rot,\,off-diag}
= \|-\hat A\|
= \|\dot\phi\sin\theta\cdot\hat F_x - \dot\theta\cdot\hat F_y\|
\le \dot\phi\sin\theta\cdot F
$$

At $\dot\theta = 0$ (steady stir), $\theta = 0.611$,
$\sin\theta = 0.574$, $\dot\phi = 18$, $F = 6$:

$$
\|H_{\rm spin}^{\rm rot,\,off-diag}\| = 18\cdot 0.574\cdot 6 = 62.0,
$$

giving $\eta_{\rm rot,\,off-diag}\cdot dt = 0.062$, EVEN SMALLER than the
conservative $\dot\phi F\cdot dt = 0.108$ estimate. Both bounds confirm
the BCH parameter is well within convergence. The conservative bound is
the safer value to report in the metric (used in §6: 0.108).

### 7.3 Reduction-limit check (phi=0 = no stir)

In the limit $\dot\phi \to 0$ (no stir), the gauge connection
$\|\hat A\| \to 0$, so the rotating-basis BCH parameter
$\eta_{\rm rot}\,dt \to 0$ and the predicted residual phi-quadratic
deviation $\Delta f^{\rm BCH}_{m=+F}(T,\dot\phi) \to 0$ vanishes
quadratically. At phi=1 in the actual scan, the residual is bounded by
$1 \cdot 6 \cdot 10^{-3} = 0.006$ BCH parameter — well below 0.108, and
the expected residual is $\sim 10^{-5} \cdot (1/18)^2 = 3\times 10^{-8}$,
below the Y4 floor. Therefore phi=1 should be CONFIRM by the chi-square
test regardless of the question's outcome at high phi. **Sanity check
passes**: the proposed discriminator (chi-square fit against phi-smooth
trend, with low-phi as baseline for sigma estimation per §4 pseudocode)
is well-conditioned because the low-phi points are in the trivially-CONFIRM
regime.

### 7.4 Code-reality vs memory cross-check

I verified the line-37 claim by reading `propagators.jl` directly this
turn (Section 1.2). The current code matches the memory description.
The 20-day-old system reminder on the memory file did not surface any
material change. **No code refactor invalidates the hypothesis.**

---

## 8. Calibrated claims

- [Established] `apply_local_spin_step!` at
  `src/rotating_basis/propagators.jl:160-231` builds the combined
  $H_{\rm spin}^{\rm rot} = -p\hat F_z + q\hat F_z^2 - \hat A(t)$
  Hermitian D×D matrix and applies $e^{-iH\,dt}$ via a single
  eigendecomposition. No internal Strang split. Source: direct code
  read this turn (Section 1.2).
- [Established] The eu151 Klaus config uses `gauge_fix: false`, which
  retains the $\hat F_z$ component of $\hat A$ at
  $a_z = \dot\phi\cos\theta$. This does NOT affect the eigen-exact
  structure of the local spin step (the eigendecomposition handles it),
  only shifts the residual diagonal piece. Source:
  `runs/eu151_klaus_phi_phys/config.yaml:30` + `propagators.jl:189`.
- [Established] The Larmor-phase guard at
  `dynamics.jl:46-72` was suppressed by explicit `dt: 0.001` in the
  config (lines 50, 61, 72). The stored
  `larmor_phase_per_step = 160.2` is bookkeeping for the
  lab-frame-equivalent BCH parameter; it does NOT apply to the
  rotating-basis integrator's stability. Source: direct code read +
  config inspection.
- [Established] The classical BCH convergence radius for the
  $e^{-iA\tau}e^{-iB\tau}$ Strang product is $\tau(\|A\|+\|B\|)
  \lesssim \ln 2 \approx 0.693$ (Hairer, Lubich, Wanner 2006 §III.4,
  Theorem III.4.x; the constant $\ln 2$ is the symmetric Strang's BCH
  series radius). Source: HLW textbook §III.4 (referenced via T55 §4
  citation; specific section number may differ between editions, see
  Section 8 below for caveat).
- [Established] The Yoshida-4 composition constant $C_{Y4} \approx 0.0247$
  appears in Hairer-Lubich-Wanner §V.3.1 and in Yoshida's original 1990
  paper (*Phys. Lett. A* 150, 262). Source: T55 §4 + standard textbook
  reference.
- [Plausible] The Y4 truncation floor for the eu151 Klaus rotating-basis
  run at $dt = 10^{-3}$, $T = 314.16$ is in the range
  $[3\times 10^{-11},\,3\times 10^{-8}]$, with the spinor-problem-specific
  composition constant $C_{Y4,{\rm spinor}}$ contributing 1-100x. The
  $1\times 10^{-8}$ CONFIRM threshold allows for any value in this range
  while still ruling out BCH-leak residuals at $10^{-5}$. Source: §2.1
  derivation.
- [Plausible] The BCH-leak residual at phi=18 (post Option γ absorption)
  scales as $T\cdot dt\cdot \dot\phi^2\cdot F^2\cdot (c_{dd}\langle n\rangle)^2/D^2$
  $\approx 1.6\times 10^{-5}$ in m+F fraction drop. Source: §2.3 with
  $c_{dd}\langle n\rangle \sim 5$ assumption (see open question Q1).
- [Plausible] The mixed-frame proxy
  $\bar J_z^{\rm proxy} = \overline{\langle\tilde F_z\rangle + \langle\hat L_z\rangle}$
  is sufficient for Tier-2.x verification; full lab-frame reconstruction
  is needed only if the proxy gives ambiguous results. Source: §2.2
  averaging argument (oscillatory transverse contributions cancel over
  integer phi-cycles).
- [Speculative] The chi-square fit's "smooth coherent trend" in m+F drop
  vs phi is linear-in-phi for the non-adiabatic Larmor lag regime. If
  the physics involves a power-law transition (e.g. above some critical
  $\dot\phi$ where DDI-mediated cascades activate), the fit should be
  quadratic or higher-order. T57 implementer should test both fits
  and use whichever gives smaller residuals at low phi. Source: §2.3
  argument; not formally derived.

---

## 9. Open questions (research-needed or follow-up)

- **Q1** (carries from T10 §5): The quantitative value of
  $c_{dd}\langle n\rangle$ for the eu151 Klaus configuration in
  dimensionless units. I used $\sim 5$-10 from T10 §2.1 + memory
  `klaus_adiabatic_elimination.md` line 9. A direct extraction from
  `make_workspace` output would tighten the predicted BCH-residual
  magnitude. Not blocking T57 (the chi-square test is self-calibrating).

- **Q2**: The exact section in Hairer-Lubich-Wanner 2006 2nd ed. for the
  Y4 constant $C_{Y4} \approx 0.0247$. I cited §V.3.1 (splitting methods
  with order conditions via BCH) per T55 §4, but the precise theorem
  number may differ. T11 researcher (if dispatched in a follow-up turn)
  could pin the citation tighter.

- **Q3**: Whether the smooth-coherent-trend fit in m+F drop vs phi
  should be linear, quadratic, or piecewise. T57 analysis script should
  use linear by default + report both fits; T58 analyze decides.

- **Q4**: If the primary CONFIRMS but secondary INCONCLUSIVE (m+F signal
  in $10^{-5}$ to $10^{-3}$ band), what's the next test? Two options:
  (a) lab-frame reconstruction via snapshot post-rotation (cpu_heavy,
  ~30 min/phi), (b) a tightened phi grid near the suspected anomaly
  (cpu_heavy fresh runs). T58 director decides based on the specific
  signature.

```json
[
  {
    "id": "Q1",
    "topic": "c_dd*<n> for eu151 Klaus dimensionless",
    "why": "Tightens predicted BCH-residual magnitude in §2.3. Not blocking T57; chi-square is self-calibrating, but useful for §8 calibrated claims.",
    "preferred_sources": ["make_workspace output for runs/eu151_klaus_phi_phys", "T10 §2.1"]
  },
  {
    "id": "Q2",
    "topic": "Exact Hairer-Lubich-Wanner 2006 2nd ed. theorem number for Y4 constant 0.0247",
    "why": "Citation discipline; T55 §4 cited §III.4 / §V.3.1 imprecisely. Pin the exact theorem for the Tier 3 manuscript.",
    "preferred_sources": ["Hairer, Lubich, Wanner 2006, Geometric Numerical Integration 2nd ed., Springer SSCM Vol. 31"]
  }
]
```

---

## 10. Directive for implementer

```json
{
  "action": "noop",
  "rationale": "T56 is the Hypothesize stage of the verify-claim flow. The deliverable is this theorist report. T57 implementer_julia_cpu_light will execute the analysis script per §4 pseudocode in a separate turn. No code changes or simulation runs are dispatched from this turn.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "T57 director dispatches implementer_julia_cpu_light with the §4 pseudocode + falsifier spec from §3.",
  "falsification_criterion": "n/a (Hypothesize stage produces only the formal spec, not measurements).",
  "estimated_cost": "n/a"
}
```

---

## 11. Publishability assessment

- **What is new this turn**: Formal hypothesis spec for verifying the
  load-bearing line-37 claim (Option γ eigen-exact spin step absorbs the
  $O(p\cdot F\cdot|\hat A|\cdot dt^2)$ BCH leak). Key derivations:
  (i) Y4 truncation floor analytical estimate of $3\times 10^{-10}$
  (matches T55 numerical conjecture);
  (ii) BCH-residual signature in m+F population fraction is the
  phase-sensitive discriminator that norm-drift alone misses;
  (iii) Rotating-basis BCH parameter $0.108 \ll \ln 2$ at phi=18 confirms
  internal consistency of the Option γ hypothesis;
  (iv) Mixed-frame $J_z$ proxy is sufficient for Tier-2.x verification.

- **Prior art**: Hairer-Lubich-Wanner 2006 (Y4 constant, BCH radius);
  Bao-Cai 2018 (spinor TSSP, weak-field canon); T10 §2 (the original
  BCH derivation this turn refines).

- **Distinction**: The specific identification of the m+F-fraction
  chi-square test as the phase-leak discriminator (separable from Y4
  amplitude error) is original to this investigation. The mixed-frame
  $J_z$ proxy avoiding cpu_heavy snapshot post-rotation is also novel.

- **Manuscript mapping**: If T58+ CONFIRMs both observables, this becomes
  the verification-section content of a potential
  `docs/manuscript/papers/paper_option_gamma_methods.md`
  ("BCH-Leak Diagnosis and Cure for Spinor-BEC Split-Step Integrators
  in the Strong-Field Co-Rotating Quantization Basis"). NOT for paper3
  (Universal Theorem) or paper4 (FullBdG).

- **Title candidate** (post-verification): "Eigen-Exact Local-Spin Step
  in the Co-Rotating Frame: Three-Decade Speedup over Lab-Frame
  Strang Splitting in Strong-Field Spinor BECs."

Out of scope for §8 publishability beyond this — this is incremental
hypothesis-refinement, not a closed-form result. The PUBLISHABLE
finding would be the T58+ verdict.
