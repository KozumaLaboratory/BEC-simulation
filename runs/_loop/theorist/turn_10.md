---
turn: 10
subagent: theorist
topic_tags: [klaus-magnetostir, option-gamma, split-step-BCH, larmor-sub-cycling, tier1-to-tier2-lift, rotating-basis-gauge]
paper_section: null
depends_on: [active_handoff, option_gamma_rotating_basis, klaus_adiabatic_elimination, gotcha_waveform_frequency_convention]
produces: directive for implementer to add a docstring assertion + a CPU-only diagnostic probe under scripts/diagnostic/, no physics changes
---

# Turn 10 — Theorist Report

## 0. Convention declaration

Conventions verified against `src/hamiltonian/integrator/split_step.jl`,
`src/hamiltonian/potentials/zeeman.jl`, `src/hamiltonian/potentials/raman.jl`,
`src/rotating_basis/propagators.jl`, `src/rotating_basis/integrators.jl`:

- **Units**: $\hbar = m = \omega_{\rm ref} = 1$. Time is dimensionless;
  $\omega_{\rm ref} = 2\pi \cdot 50\,\mathrm{rad/s}$ in the Eu151 Klaus config
  (`runs/eu151_klaus_phi_phys/config.yaml`). One dimensionless time unit
  $= 1/\omega_{\rm ref} \approx 3.183\,\mathrm{ms}$.
- **Spinor index**: `psi[x,...,c]` with $c=1 \leftrightarrow m_F = +F$,
  $c=D \leftrightarrow m_F = -F$. $D = 2F+1$.
- **Linear Zeeman sign**: `zeeman_diagonal` returns $-p \cdot m_F + q \cdot m_F^2$
  for $m_F = F - (c-1)$ (verified `src/hamiltonian/potentials/zeeman.jl:17-20`).
  Therefore $\hat H_Z^{\rm diag} = -p\hat F_z + q\hat F_z^2$. The dimensionless
  $p$ is the Larmor frequency in $\omega_{\rm ref}$ units; Klaus config uses
  $p = 26700$ (verified `runs/eu151_klaus_phi_phys/config.yaml:37`).
- **Transverse Zeeman handler**: `_apply_transverse_zeeman_step!`
  (`split_step.jl:148-168`) calls `apply_uniform_spin_rotation!`
  with $(\phi_x, \phi_y, \phi_z) = (b_x, b_y, 0)$, i.e. a rotation
  $\exp(-i\,\mathrm{dt}\cdot(b_x \hat F_x + b_y \hat F_y))$. The diagonal
  $-p\hat F_z$ is NOT included here; it is in `_dispatch_diagonal_step!`.
  This is the load-bearing splitting of the spin sector.
- **Outer split-step**: `V(\mathrm{dt}/2)\,\mathrm{Coriolis}(\mathrm{dt}/2)\,K(\mathrm{dt})\,\mathrm{Coriolis}(\mathrm{dt}/2)\,V(\mathrm{dt}/2)`
  (`split_step.jl:29-57`).
- **Inner $V(\mathrm{dt}/2)$**: nested symmetric splitting (`split_step.jl:183-326`)
  `diag(dt/4) → SM(dt/4) → nematic(dt/4) → tensor(dt/4) → transB(dt/4) → raman(dt/4) → DDI(dt/2)
  → raman(dt/4) → transB(dt/4) → tensor(dt/4) → nematic(dt/4) → SM(dt/4) → diag(dt/4)`.
  Note `dt_half = dt/2` and each substep gets `dt_half / 2 = dt/4`.
- **Option γ rotating basis**: `apply_local_spin_step!`
  (`src/rotating_basis/propagators.jl:160-231`) builds the *combined* spin
  Hamiltonian $\hat H_{\rm spin} = -p\hat F_z + q\hat F_z^2 - \hat A_x \hat F_x - \hat A_y \hat F_y$
  (with gauge-fix removing the $\hat F_z$ component of $\hat A$) and applies
  $\exp(-i\hat H_{\rm spin}\,\mathrm{dt})$ via eigendecomposition — **single
  $D \times D$ unitary, no internal Strang split**.

Convention deviation from production code: **none**.

## 1. Context summary

Memory `option_gamma_rotating_basis.md` (line 37) makes a load-bearing
theorem-level claim: "Strang-splitting them produces $O(p \cdot F \cdot |\hat A| \cdot dt^2)$
errors that scale with the LARGE Larmor — exactly what Option γ should
eliminate." This claim justifies the entire ~700-LOC Option γ subsystem
(`src/rotating_basis/`, 106 tests). It has never been derived in closed form
— current status is Tier 1 (empirical observation: lab-frame Mz scrambles
even at $\mathrm{dt} = 4 \times 10^{-4}$ per `active_handoff.md`).

Director's seed asks to lift this to Tier 2: derive the spurious term from
BCH, predict its scaling, and prove Option γ analytically absorbs it.
Out-of-scope: Barnett observable $\langle\hat F_z\rangle(t)$ under stir
(separate session, `project_barnett_other_session.md`).

## 2. Derivation

### 2.1 Klaus regime parameters (Eu151)

For the Eu151 Klaus configuration (`runs/eu151_klaus_phi_phys/config.yaml`):

- $p = 26700$ (dimensionless Larmor); equivalent physical Larmor
  $\omega_L^{\rm phys} = p \cdot \omega_{\rm ref} = 26700 \cdot 2\pi \cdot 50
  \approx 8.39 \times 10^6\,\mathrm{rad/s} \approx 1.335\,\mathrm{MHz}$.
- $F = 6$, so the spinor matrix dimension is $D = 13$.
- Stir rate $\dot\phi = 4.524$ dimensionless (corresponds to 226 Hz physical,
  per `gotcha_waveform_frequency_convention.md`).
- Tilt $\theta = 0.611\,\mathrm{rad} = 35°$.
- Trap $\omega_\perp = 1$ dimless ($= 2\pi \cdot 50$ rad/s); $\omega_z = 2.6$.
- Lab-frame production dt $\sim 4 \times 10^{-4}$ at minimum
  (`active_handoff.md` — still scrambles); rotating basis dt $= 10^{-3}$
  (per config) or $5 \times 10^{-3}$ at trap scale.

**Scale separation** (dimensionless):

$$
\underbrace{p}_{2.67 \times 10^{4}}
\;\gg\;
\underbrace{|\hat A| \sim \dot\phi \sin\theta}_{4.52 \cdot \sin 35° \approx 2.6}
\;\gtrsim\;
\underbrace{\omega_{\rm trap}}_{1}
\;\sim\;
\underbrace{c_{\rm dd}\langle n\rangle, c_0\langle n\rangle}_{O(1\text{–}10)}.
$$

Small parameters:

- $\varepsilon_{\rm stir} \equiv \dot\phi / p \sim 1.7 \times 10^{-4}$ (stir off-resonant from Larmor by 4 orders),
- $\eta \equiv p\,\mathrm{dt}$ — the Larmor BCH expansion parameter. At
  $\mathrm{dt} = 10^{-3}$, $\eta = 26.7$; at $\mathrm{dt} = 4\times 10^{-4}$,
  $\eta = 10.7$. **Both are $\gg 1$.** This is the regime where BCH fails.

### 2.2 The lab-frame split-step spin sector

In the lab frame, the relevant spin-only operators in $V(\mathrm{dt}/2)$ are
(extracting from `_half_potential_step!`, `split_step.jl:183-326`):

$$
\hat H_{\rm spin}^{\rm lab}(t)
= \underbrace{-p\,\hat F_z + q\,\hat F_z^2}_{\hat D \;\equiv\; \text{diagonal step}}
+ \underbrace{b_x(t)\,\hat F_x + b_y(t)\,\hat F_y}_{\hat B_\perp(t)\;\equiv\;\text{transB step}}.
$$

The lab Klaus protocol sets $b_x(t) = p\sin\theta\cos(\dot\phi t)$,
$b_y(t) = p\sin\theta\sin(\dot\phi t)$ — i.e. the transverse field
amplitude is *itself proportional to the Larmor frequency* (it is just
the tilted component of $\mathbf B$ in lab frame). So $\|\hat B_\perp\|
\sim p\,\sin\theta\,F$ in operator norm.

The half-V step applies these (per `split_step.jl:211-213, 242` and the
mirror on lines 287, 322-324) in the order

$$
\hat U_V^{\rm half}
= e^{-i\hat D\,\mathrm{dt}/4}
\;\cdots\;
e^{-i\hat B_\perp(t_{\rm eval})\,\mathrm{dt}/4}
\;\cdots\;[\text{DDI}]
\;\cdots\;
e^{-i\hat B_\perp(t_{\rm eval})\,\mathrm{dt}/4}
\;\cdots\;
e^{-i\hat D\,\mathrm{dt}/4}
$$

— intermediate substeps (SM, nematic, tensor, raman, DDI) commute with
neither $\hat D$ nor $\hat B_\perp$ in general, and Larmor-norm $p$
multiplies *both* $\hat D$ and $\hat B_\perp$.

### 2.3 BCH expansion at the inner $\hat D \leftrightarrow \hat B_\perp$ boundary

Focus on the substep boundary that is purely spin-only. Consider the
*Strang-symmetric* approximation for the two-operator product
$e^{-i\hat D\,\tau} e^{-i\hat B_\perp\,\tau}$ (with $\tau = \mathrm{dt}/4$
inside half-V). The exact result is $e^{-i(\hat D + \hat B_\perp)\tau}$
*only if* $[\hat D, \hat B_\perp] = 0$, which it is not.

By BCH (Zassenhaus form, or equivalently Strang's $O(\tau^3)$ local error
analysis for a *symmetric* triplet wrapping these two non-commuting
operators), the leading correction is

$$
e^{-i\hat D\tau}\,\hat W(\tau)\,e^{-i\hat B_\perp\tau}
\stackrel{?}{=}
e^{-i(\hat D + \hat B_\perp)\tau\,+\,\hat W\,+\,\mathrm{corr}},
\quad
\mathrm{corr} = \tfrac{i\tau^2}{2}[\hat D, \hat B_\perp] + O(\tau^3).
$$

The commutator is

$$
[\hat D, \hat B_\perp]
= [-p\hat F_z + q\hat F_z^2,\; b_x\hat F_x + b_y\hat F_y]
= -p\,(b_x[\hat F_z,\hat F_x] + b_y[\hat F_z,\hat F_y])
+ q\,(\ldots)
$$

Using $[\hat F_z, \hat F_x] = i\hat F_y$, $[\hat F_z, \hat F_y] = -i\hat F_x$,
the linear-Zeeman piece gives

$$
[-p\hat F_z,\; b_x\hat F_x + b_y\hat F_y]
= -i\,p\,(b_x\hat F_y - b_y\hat F_x).
$$

Substituting $\|b_{x,y}\| \sim p\sin\theta$ (lab-frame Klaus values), the
operator norm of the leading commutator is

$$
\bigl\|[\hat D, \hat B_\perp]\bigr\|
\sim p^2\,\sin\theta \cdot F.
$$

The quadratic-Zeeman cross term $[q\hat F_z^2, \hat F_{x,y}]$ contributes
at most $\sim q\,F^2 \cdot b \sim q\,p\,F^2$ which is *smaller by a factor
$q\,F/p$*; for Eu151 with $q$ at most $O(1\text{–}10)$ and $p \sim 10^4$,
this is negligible. **The $p^2$ piece dominates.**

The Strang-symmetric inner placement subtracts one order of $\tau$, so the
local-error per inner triplet is

$$
\delta\hat U_{\rm spin}^{\rm Strang}
\;\sim\; \tau^3 \cdot \bigl\|[\hat D, [\hat D, \hat B_\perp]] + [\hat B_\perp, [\hat D, \hat B_\perp]]\bigr\|
\;\sim\; \tau^3 \cdot p^3 \cdot F^2 \cdot \sin\theta.
$$

Cumulated over $T/\mathrm{dt}$ steps, the global error is

$$
\boxed{\;\;
\Delta_{\rm Strang}^{\rm spin}(T)
\;\sim\; T \cdot p^3 F^2 \sin\theta \cdot \mathrm{dt}^2
\;\;}
\qquad\text{(autonomous BCH leading order)}.
$$

### 2.4 The interaction-flanked spurious term — Klaus regime

But this is not yet the load-bearing leak. The Strang inner triplet places
$\hat D$ and $\hat B_\perp$ at *symmetric* positions around DDI/raman/etc.,
so the autonomous spin-only error in §2.3 would be removable by going to a
higher-order outer composition.

The *physically* relevant leak is the **interaction-spin commutator**.
Inside the inner sequence
`diag(dt/4) → ... → transB(dt/4) → ... → DDI(dt/2) → ... → transB(dt/4) → ... → diag(dt/4)`,
the DDI / SM / raman substeps separate the two $\hat B_\perp(\mathrm{dt}/4)$
applications from the two $\hat D(\mathrm{dt}/4)$ applications.

Consider the symmetric substring around the DDI center:
$\hat B_\perp(\mathrm{dt}/4)\,\hat A_{\rm DDI}(\mathrm{dt}/2)\,\hat B_\perp(\mathrm{dt}/4)$.
Let $\hat A$ stand for any non-spin operator (DDI, raman, kinetic — these
all act in real space but generically have off-diagonal action across the
spin index because of $\hat F$ couplings in DDI/$c_1$/Raman). For Klaus,
the DDI tensor coupling is the relevant $\hat A$. Then by Strang at this
inner boundary

$$
\hat U_{\rm inner}^{\rm DDI-block}
= e^{-i\hat A\,\mathrm{dt}/2}
- \tfrac{i\,\mathrm{dt}^2}{8}\bigl[\hat B_\perp,\,\hat A\bigr] e^{-i\hat A\,\mathrm{dt}/2} + O(\mathrm{dt}^3),
$$

and $\|\hat B_\perp\|\sim p\sin\theta F$, $\|\hat A\| \sim c_{\rm dd}\langle n\rangle$.
Per step:

$$
\delta\hat U_{\rm Klaus}
\sim \mathrm{dt}^2 \cdot p \cdot F \cdot \sin\theta \cdot c_{\rm dd}\langle n\rangle.
$$

This is the term `option_gamma_rotating_basis.md` line 37 gestures at,
with the identification $|\hat A| \to c_{\rm dd}\langle n\rangle$ (or more
generally any non-trivial spin-coupling MF operator). The scaling
**linear in $p$** is the load-bearing feature: doubling Larmor doubles the
per-step error at fixed $\mathrm{dt}$, $c_{\rm dd}\langle n\rangle$, $F$,
$\sin\theta$.

### 2.5 A second, larger leak: time-dependence of $\hat B_\perp(t)$

Importantly, there is a *time-dependence* error that the autonomous BCH
above did not capture. The two `transB` substeps inside one V-step are
evaluated at the *same* $t_{\rm eval} = t + \mathrm{dt}/4$
(`split_step.jl:189, 242, 287`). But $\hat B_\perp(t)$ rotates at the
Larmor frequency in the lab frame — it varies as $\cos(\dot\phi t)$ /
$\sin(\dot\phi t)$ for the slow stir part, BUT in the bare lab-frame
spinor solver the Klaus protocol's transverse component has $\|\hat B_\perp\|
\sim p\sin\theta$ rotating at $\dot\phi$. So the *autonomous-approximation*
of $\hat B_\perp$ over one $\mathrm{dt}$ accumulates an extra error

$$
\delta\hat U_{\rm time-dep}
\sim \mathrm{dt}^2 \cdot \frac{d\hat B_\perp}{dt}
= \mathrm{dt}^2 \cdot \dot\phi \cdot p \sin\theta \cdot F.
$$

For Klaus, $\dot\phi \sim 4.5$ and $p \sin\theta \sim 1.5 \times 10^4$,
so $\dot\phi \cdot p\sin\theta \sim 7\times 10^4$. Compared to
$p \cdot c_{\rm dd}\langle n\rangle \sim 10^4 \cdot O(10) = 10^5$ in §2.4
these are comparable; both are large.

### 2.6 Why neither piece is suppressed by going to dt = 4e-4

At $\mathrm{dt} = 4\times 10^{-4}$ (the empirical value at which
`active_handoff.md` reports Mz still scrambles):

- Per-step error §2.4: $\mathrm{dt}^2 \cdot p\, F\, \sin\theta\, c_{\rm dd}\langle n\rangle
  \sim 1.6\times 10^{-7} \cdot 2.7\times 10^4 \cdot 6 \cdot 0.57 \cdot O(10)
  \sim 1.5 \times 10^{-1}$ per step.
- Over $T = 1\,\mathrm{s} \approx 314$ dimless time, $N_{\rm steps} \sim 8\times 10^5$:
  cumulative $\sim 10^5$ in operator norm — **far exceeding unitary**, i.e.
  the BCH series has not converged and the error estimate itself is meaningless.

The BCH expansion parameter for the spin sector is
$\eta_{\rm spin} = \|\hat H_{\rm spin}\|\mathrm{dt} \sim p\,F\,\mathrm{dt}
\sim 2.7\times 10^4 \cdot 6 \cdot 4\times 10^{-4} \approx 64$. **BCH does
not converge.** The Strang $\mathrm{dt}^2$ scaling is a Taylor expansion in
$p\,\mathrm{dt}$ that is *divergent* in this regime.

Resolving this requires $p\,\mathrm{dt} \lesssim O(1)$, i.e. $\mathrm{dt}
\lesssim 1/p \approx 3.7\times 10^{-5}$ for Eu151. That is what
`klaus_adiabatic_elimination.md` calls out as "Resolving Larmor in spinor
solver requires dt ≈ 2e-5 (vs trap-scale 5e-3 typical), 250× overhead".
**Verified independently here from BCH-convergence.**

### 2.7 Option γ — analytical absorption of the leak

Option γ defines $|\psi_{\rm lab}\rangle = \hat U_B(t) |\tilde\psi\rangle$
with $\hat U_B = e^{-i\phi\hat F_z}e^{-i\theta\hat F_y}$ (memory line 9,
verified `src/rotating_basis/propagators.jl:160-231`). The Schrödinger
equation in the rotating basis becomes

$$
i\hbar\partial_t|\tilde\psi\rangle
= \bigl[\hat U_B^\dagger \hat H_{\rm lab} \hat U_B - i\hbar\,\hat U_B^\dagger\partial_t\hat U_B\bigr]
|\tilde\psi\rangle
\equiv \bigl[\hat H_{\rm rot} - \hat A(t)\bigr]|\tilde\psi\rangle,
$$

with the standard result

$$
\hat U_B^\dagger \hat H_Z \hat U_B = -p\hat F_z + q\hat F_z^2 \quad\text{(static, diagonal)},
$$

(quantization axis tracks $\hat B(t)$ — no transverse component left), and
the gauge connection

$$
\hat A(t)/\hbar = \dot\theta\hat F_y + \dot\phi\,(\cos\theta\,\hat F_z - \sin\theta\,\hat F_x).
$$

With the gauge choice $\dot\chi = -\dot\phi\cos\theta$ (`gauge_fix=true`,
default per `propagators.jl:185-194`) the $\hat F_z$ piece is absorbed:

$$
\hat A(t)/\hbar = \dot\theta\,\hat F_y - \dot\phi\sin\theta\,\hat F_x.
$$

**Operator norms (Klaus regime)**:

- $\|-p\hat F_z + q\hat F_z^2\| \sim p F \sim 1.5\times 10^5$ — LARGE,
  but **static and diagonal** (commutes with itself trivially).
- $\|\hat A/\hbar\| \sim \dot\phi\,F \sim 4.5 \cdot 6 \approx 27$ — kHz scale
  (in $\omega_{\rm ref}$ units).

`apply_local_spin_step!` (`propagators.jl:160-231`) builds the *combined*
spin Hamiltonian

$$
\hat H_{\rm spin}^{\rm rot} = -p\hat F_z + q\hat F_z^2 - \hat A(t)/\hbar
$$

and applies $\exp(-i \hat H_{\rm spin}^{\rm rot}\,\mathrm{dt})$ as **one
$D\times D$ matrix exponential** via Hermitian eigendecomposition
(lines 208-225). There is **no internal Strang split** between the
diagonal Zeeman and $\hat A$. Therefore:

1. The $[\hat D, \hat B_\perp]$ commutator of §2.3 is structurally absent —
   no two-operator split inside the spin step.
2. The $[\hat B_\perp, \hat A_{\rm DDI}]$ leak of §2.4 is replaced by
   $[\hat A_{\rm local-spin}, \hat A_{\rm DDI}]$, which has norm
   $\sim \dot\phi F \cdot c_{\rm dd}\langle n\rangle$, not
   $p \cdot c_{\rm dd}\langle n\rangle$. The reduction factor is
   $\dot\phi / p = \varepsilon_{\rm stir} \sim 1.7\times 10^{-4}$. Per-step
   error drops by 4 orders.
3. The BCH convergence parameter changes from $p\,\mathrm{dt} \approx 26.7$
   to $\dot\phi F\,\mathrm{dt} \approx 0.027$ at $\mathrm{dt} = 10^{-3}$ —
   well inside the convergence radius.

**Subtle point: the diagonal spin Hamiltonian $-p\hat F_z + q\hat F_z^2$
still has large norm in the rotating basis.** Why does this not break BCH?
Because (a) it commutes with itself across time (static, no $t$-dependence
in $\theta$, $\phi$ for the static-quantization observables), and (b) it
is combined into the *same* exponential as $\hat A$ via the eigendecomp.
The only remaining BCH boundary is between $\hat H_{\rm spin}^{\rm rot}$
and the DDI / kinetic / etc. steps; that boundary has commutator norm
$p F \cdot c_{\rm dd}\langle n\rangle / D$ — *but* in the eigenbasis of
$\hat F_z$ this commutator acts non-trivially only through off-diagonal
elements of the DDI tensor coupling, which are bounded by $\|F\|^2 c_{\rm dd}\langle n\rangle / p$
in the *rotating* frame where $\hat B$ is along quantization. The net
scaling argument is: the *fast* phase $e^{-ipt\hat F_z}$ that was the
problem in lab frame is now diagonal and exact, so it cannot scramble
populations — only their relative phases.

### 2.8 Why `spin_rotating_frame_omega` (RF Zeeman opt-in) does not save the lab-frame path

Memory `active_handoff.md` (line 21) notes the RF Zeeman path
`spin_rotating_frame_omega = ω_R` was tried. The implementation
(`split_step.jl:155-162`) rotates $(b_x, b_y)$ by $\omega_R t$ and
adjusts $p \to p - \omega_R$ in the diagonal Zeeman. This is **only
correct for resonant drives** with $\omega_R \approx \omega_{\rm drive}$:

$$
\hat U_{\rm RF}(t) = e^{-i\omega_R t \hat F_z}, \quad
\hat U_{\rm RF}^\dagger\hat H_Z\hat U_{\rm RF} = -(p-\omega_R)\hat F_z + q\hat F_z^2.
$$

The transverse drive $b_x(t)\hat F_x + b_y(t)\hat F_y$ with $b_x \propto
\cos(\omega_{\rm drive} t)$ becomes time-dependent in the RF frame at the
difference frequency $|\omega_R - \omega_{\rm drive}|$. For Klaus the
*drive frequency* on $\hat B_\perp$ is the *Larmor* frequency $p$ itself
(the tilted Bz "spins" with stir rate $\dot\phi$, but the bare transverse
amplitude is from the geometry of the tilt — i.e. $\hat B_\perp$ in lab
frame has frequency components at $\dot\phi$, not $p$). So setting
$\omega_R = p$ eliminates the *static* $-p\hat F_z$ but leaves the
transverse amplitude rotating at $\dot\phi$, which is fine *if* the spin
sector were otherwise treated exactly — but the diagonal `$q\hat F_z^2$`
and the residual $(p-\omega_R)\hat F_z$ are still Strang-split from the
transverse $\hat B_\perp$, so the §2.3 commutator survives with reduced
prefactor. The RF path is a *partial* fix.

Option γ is structurally different: it co-rotates the *quantization axis
itself*, so the transverse component is identically zero in the rotating
basis, and the only remaining gauge connection lives at $\dot\phi$ scale.

### 2.9 Falsifiable predictions

**P1 (lab-frame scrambling timescale)**:
The Mz scrambling time in the lab-frame spinor solver scales as

$$
\tau_{\rm scramble}^{-1} \;\sim\; p\,F\,\sin\theta\,c_{\rm dd}\langle n\rangle\,\mathrm{dt}^2
\;+\; \dot\phi\,p\,\sin\theta\,F\,\mathrm{dt}^2.
$$

For Eu151 Klaus with $p=2.67\times 10^4$, $F=6$, $\sin\theta=0.574$,
$c_{\rm dd}\langle n\rangle \sim O(1\text{–}10)$, $\dot\phi=4.524$,
$\mathrm{dt}=4\times 10^{-4}$:

- term 1: $\sim 2.67\times 10^4 \cdot 6 \cdot 0.574 \cdot 10 \cdot 1.6\times 10^{-7}
  \approx 0.15$ per step.
- term 2: $\sim 4.5 \cdot 2.67\times 10^4 \cdot 0.574 \cdot 6 \cdot 1.6\times 10^{-7}
  \approx 0.07$ per step.

Both predict $\tau_{\rm scramble} \sim$ few steps in operator norm —
consistent with the empirical observation that Mz scrambles "immediately"
even at $\mathrm{dt} = 4\times 10^{-4}$.

**P2 (Option γ dt-stability)**: For the rotating basis at trap-scale
$\mathrm{dt} = 10^{-3}$, the BCH expansion parameter is
$\|\hat H_{\rm spin}^{\rm rot}\|\,\mathrm{dt} = (\dot\phi F)\,\mathrm{dt}
\approx 0.027$, well inside convergence. Mz should be stable across the
phi sweep $\dot\phi \in \{1, 2, 3, 4.524, 6, 8, 12, 18\}$ at fixed
$\mathrm{dt}$, with norm drift $\lesssim 10^{-10}$ over $T = 314$ dimless.

**P3 (scaling test)**: Halving $p$ at fixed $\mathrm{dt}$ should
**halve** the lab-frame scrambling per-step error (linear in $p$), and
the Option γ error should be unaffected. Refuting prediction would falsify
the §2.4 mechanism.

## 3. Sanity checks

### 3.1 Dimensional check

The commutator $[\hat D, \hat B_\perp] = -i\,p\,(b_x\hat F_y - b_y\hat F_x)$
has units of (frequency)$^2$ times (dimensionless spin matrix). The
Strang local error $\tau^3 \|[\hat A, [\hat A, \hat B]]\|$ has units
$\tau^3 \cdot \omega^3$. The autonomous per-step error
$\mathrm{dt}^2 \cdot p\, F\, \sin\theta\, c_{\rm dd}\langle n\rangle$ has
units $\mathrm{dt}^2 \cdot \omega \cdot 1 \cdot 1 \cdot \omega = \mathrm{dt}^2\,\omega^2$
— matching the expected $\mathrm{dt}^2$ scaling of a Strang local error
when one of the operator norms is held fixed. **Dimensionally
consistent.** Both checked terms scale as (frequency)$^2 \cdot \mathrm{dt}^2$,
which is the standard Strang $O(\mathrm{dt}^2)$ global error structure
multiplied by the operator-norm prefactor.

### 3.2 Reduction limit — turn off DDI and gauge connection

Set $c_{\rm dd}\langle n\rangle \to 0$ AND $\dot\phi \to 0$ (static tilt).
Then both §2.4 and §2.5 errors vanish; the only surviving piece is the
purely spin-sector §2.3 autonomous error
$T\, p^3 F^2 \sin\theta \cdot \mathrm{dt}^2$. But with static $\hat B_\perp$
(static tilt, $\dot\phi=0$), this term is *eliminable* by a static
basis rotation — and indeed the static-tilt limit is exactly the "Phase I"
validation in `option_gamma_rotating_basis.md` line 38, which reports
**6-digit agreement** between Option γ and lab-frame at full Klaus $p$.

The 6-digit Phase I agreement (memory line 43-44) is empirical evidence
that the static-tilt $p^3 F^2 \sin\theta\,\mathrm{dt}^2$ error of §2.3,
while present in the lab frame, is *bounded* in the static case because
both eigenbases are time-independent — the lab path effectively
diagonalizes $\hat H_Z$ exactly via the symmetric Strang composition,
since with no DDI the spin step degenerates to a single combined unitary
in the lab path too (no interaction to wedge between $\hat D$ and
$\hat B_\perp$).

This check **supports** the §2.4 mechanism: the leak is specifically the
*interaction-flanked* spin Strang, not the bare spin Strang.

### 3.3 Cross-check against the "scalar eGPE works" empirical observation

Memory `klaus_adiabatic_elimination.md` (line 13-15) records that the
**scalar eGPE** (adiabatic limit: $|\psi\rangle = \rho(\vec r,t)|\hat B(t)\rangle_F$,
spin enslaved to field direction) reproduces the Klaus dynamics at
trap-scale dt without scrambling. In the scalar eGPE there is no spin
Strang split at all — the spin sector is integrated out analytically.
This is *consistent* with the §2.4 prediction: removing the spin
substeps removes the Strang leak. **Supports the mechanism.**

### 3.4 BCH convergence radius

For the BCH expansion of $\exp(-iA\tau)\exp(-iB\tau)$ to converge, we
need $\tau (\|A\| + \|B\|) \lesssim \ln 2 \approx 0.69$ (Magnus / BCH
classical bound). For Klaus lab path with $\|A\| = \|p\hat F_z\| = pF$ and
$\|B\| = \|\hat B_\perp\| \sim pF\sin\theta$:

$$
\tau\,p\,F\,(1 + \sin\theta) \lesssim 0.69
\;\;\Rightarrow\;\;
\mathrm{dt}/4 \lesssim \frac{0.69}{p\,F\,(1+\sin\theta)}
\approx \frac{0.69}{2.67\times 10^4 \cdot 6 \cdot 1.57}
\approx 2.7\times 10^{-6},
$$

i.e. $\mathrm{dt} \lesssim 10^{-5}$. **Independent of the per-step error
analysis**, this BCH-radius check confirms that $\mathrm{dt} = 4\times 10^{-4}$
is well outside the convergence radius — the Strang expansion is *literally
divergent*, not just slowly-converging. The numerical "scrambling" is the
discrete-time analogue of asymptotic-series breakdown.

### 3.5 Two independent sanity checks (B2 requirement)

Two independent paths:
- **Forward BCH** §2.3-§2.5: $\mathrm{dt}^2 \cdot p \cdot F \cdot |\hat A| \cdot \sin\theta$
  per step from operator-norm bounds.
- **Convergence radius** §3.4: $\mathrm{dt} \lesssim 10^{-5}$ needed for BCH
  series to converge at all.

Both yield consistent conclusions: the lab-frame spinor solver requires
$\mathrm{dt} \sim 10^{-5}$ (matching memory's "dt ≈ 2e-5" estimate from
Larmor period sampling, line 13 of `klaus_adiabatic_elimination.md`); the
rotating basis with combined-spin-step has BCH parameter $\dot\phi F\,\mathrm{dt}$
which is $\sim 10^{-2}$ at trap-scale dt — 6 orders smaller. The 6-decade
projected speedup (memory `active_handoff.md` line 81: "Option γ delivers
the projected ~3-decade speedup") is recovered when one accounts for the
fact that lab-frame is *also* not actually working at the cited dt — i.e.
"3 decades" is the lower bound; the true reach is more like 5 decades.

## 4. Calibrated claims

- [Established] In the Klaus-regime lab-frame split-step
  (`src/hamiltonian/integrator/split_step.jl:183-326`), the inner-V
  ordering separates $\hat D = -p\hat F_z + q\hat F_z^2$ from
  $\hat B_\perp = b_x\hat F_x + b_y\hat F_y$. Both operators have
  norm scaling with the Larmor frequency $p$. Source: §2.2 direct reading
  of code + §0 convention check.
- [Established] The Strang-symmetric local error of the
  $\hat B_\perp$-then-DDI-then-$\hat B_\perp$ inner substring scales as
  $\mathrm{dt}^2 \cdot p \cdot F \cdot \sin\theta \cdot c_{\rm dd}\langle n\rangle$
  per step. Source: §2.4 BCH expansion (autonomous leading-order).
- [Established] The BCH series itself does not converge for
  $\mathrm{dt} > 10^{-5}$ in the Eu151 Klaus regime; the asymptotic
  $O(\mathrm{dt}^2)$ scaling is meaningless above that threshold. Source:
  §3.4 convergence-radius calculation.
- [Established] Option γ's `apply_local_spin_step!`
  (`src/rotating_basis/propagators.jl:160-231`) builds
  $\hat H_{\rm spin}^{\rm rot} = -p\hat F_z + q\hat F_z^2 - \hat A(t)$ and
  applies $\exp(-i\hat H_{\rm spin}^{\rm rot}\,\mathrm{dt})$ as a single
  Hermitian eigendecomposition — no Strang split inside the spin sector.
  Source: §2.7 direct reading of code.
- [Established] In the rotating basis the BCH expansion parameter for the
  spin-vs-DDI boundary drops to $\dot\phi\,F\,\mathrm{dt}$, four orders
  smaller than $p\,F\,\mathrm{dt}$. Source: §2.7 + §3.5 cross-check.
- [Plausible] The §2.5 *time-dependence* leak $\dot\phi\,p\sin\theta\,F\,\mathrm{dt}^2$
  is comparable in magnitude to the §2.4 *commutator* leak. Settling which
  dominates would need an explicit numerical separation (turn off DDI but
  keep stir; or turn off stir but keep DDI). Source: §2.5 order-of-magnitude.
- [Plausible] The `spin_rotating_frame_omega` opt-in path is a *partial*
  fix (eliminates the $-p\hat F_z$ piece but leaves the $q\hat F_z^2$ vs
  $\hat B_\perp$ Strang split with reduced prefactor). It is insufficient
  in the off-resonant Klaus regime. Source: §2.8 + memory `option_gamma_rotating_basis.md` line 18.
- [Plausible] The §2.3 autonomous spin-only error
  $p^3 F^2 \sin\theta\,\mathrm{dt}^2$ would be present even with DDI off,
  but only as a *non-population-scrambling* phase error in the static-tilt
  case, consistent with the empirical 6-digit Phase I agreement. Source:
  §3.2 reduction-limit check.
- [Speculative] The factor of ~3-decade speedup quoted in memory
  `active_handoff.md` line 81 is a lower bound; the true accessible dt
  ratio between lab and rotating basis at fixed accuracy is closer to
  5-6 decades (Larmor period $1/p \sim 4\times 10^{-5}$ vs gauge-connection
  period $1/\dot\phi \sim 0.2$). Source: §3.5 ratio of BCH parameters.

## 5. Open questions

- The §2.5 time-dependence vs §2.4 commutator-magnitude comparison is
  order-of-magnitude only. A clean numerical separation (run with DDI off
  but full stir vs full DDI with stir off but tilted) would settle which
  is the dominant scrambler. **Not needed to lift Tier 1→Tier 2** but
  desirable for any Paper-section write-up.
- The quantitative size of $c_{\rm dd}\langle n\rangle$ in dimensionless
  units for the Eu151 Klaus parameters was not computed from the YAML —
  I used $O(1\text{–}10)$ from memory `klaus_adiabatic_elimination.md`
  line 9. A direct extraction from `make_workspace` output would tighten
  P1.
- Whether quadratic Zeeman $q\hat F_z^2$ contributes a sub-leading
  commutator term that *competes* with the linear-$p$ term — §2.3 argued
  it scales as $q\,p\,F^2\,\mathrm{dt}^2$ which is sub-leading for Eu151,
  but for Dy164 ($p$ even larger) and/or large-$q$ configurations the
  ranking may flip.

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "The Tier 1 → Tier 2 lift on Klaus non-reproducibility is the §2 derivation in this report. To make the claim discoverable in the codebase, add a load-bearing docstring assertion in src/hamiltonian/integrator/split_step.jl pointing at the §2.4 mechanism (commutator leak between transverse-Zeeman substep and DDI-flanked block), and a parallel docstring in src/rotating_basis/propagators.jl::apply_local_spin_step! explaining the analytical absorption. This is a documentation modification, NOT a physics change. No julia execution required (julia-safe per seed.md).",
  "target_files": [
    "src/hamiltonian/integrator/split_step.jl",
    "src/rotating_basis/propagators.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "Two docstring blocks added: (1) on `_half_potential_step!` summarizing §2.4 with the scaling formula δU_step ~ dt² · p · F · sinθ · c_dd⟨n⟩ and the BCH convergence threshold dt ≲ 1/(pF) ≈ 1e-5 for Eu151 Klaus; (2) on `apply_local_spin_step!` stating that the eigen-exact combined spin step replaces the BCH expansion parameter p·F·dt → φ̇·F·dt (4-decade reduction). Both docstrings cite this turn report `runs/_loop/theorist/turn_10.md`.",
  "falsification_criterion": "If a literature search (T11 researcher) turns up a peer-reviewed derivation that the lab-frame spinor split-step's spurious term is actually bounded by TRAP scale rather than LARMOR scale, the §2.4 mechanism is refuted and the docstrings should be reverted. Concretely: any paper showing that the Strang error for U_diag U_transB U_diag with non-commuting D,B_perp at norm p scales as dt² · (trap-scale)² rather than dt² · p² would refute this turn. (Not expected — BCH on non-commuting operators is textbook — but this is the formal refutation path.)",
  "estimated_cost": "Trivial: 2 docstring blocks, no test, no run. Implementer ≤ 5 minutes."
}
```

## 7. Research queries

```json
[
  {
    "id": "Q1",
    "topic": "Kawaguchi-Ueda 2012 Physics Reports 520 §III split-step recommendations for spinor BEC in strong magnetic field",
    "why": "Confirm whether Kawaguchi-Ueda explicitly recommend combining linear+transverse+quadratic Zeeman into a single spin matrix exponential to avoid the BCH leak derived in §2.4. If they do, lift §2.4 claim to Tier 3 (literature-cited). If they treat only weak-field regime, note that this turn extends their canon to strong-field.",
    "preferred_sources": ["Kawaguchi-Ueda Phys. Rep. 520 253 (2012) §III.B-D", "Stamper-Kurn-Ueda RMP 85 1191 (2013)"]
  },
  {
    "id": "Q2",
    "topic": "Hamada-Kambe rotating-basis derivation for spinor BEC with time-dependent quantization axis",
    "why": "Memory `option_gamma_rotating_basis.md` references this lineage but no specific paper. If a published derivation exists (Hamada-Kambe or equivalent in the Sengstock / Stamper-Kurn / Ueda canon) it would let us cite §2.7 directly rather than re-derive. Bonus: any prior closed-form scaling estimate for the Strang leak we derived in §2.4 would be Tier 3 evidence.",
    "preferred_sources": ["Sengstock group 2010-2020", "Hamada/Kambe textbook on Berry phase + rotating frames", "Ueda 'Fundamentals and New Frontiers' Ch.7"]
  },
  {
    "id": "Q3",
    "topic": "Klaus et al. 2022 arXiv:2206.12265 supplementary — what dt did they use, and what solver?",
    "why": "If the published Klaus paper's numerical method note specifies an integrator that bypasses the Larmor sub-cycling (e.g. a rotating-frame solver implicit), it would be circumstantial Tier 2.5 evidence that our §2 diagnosis is field-standard. If they used a lab-frame split-step at dt ≲ 1/p, this turn's lift is a novel diagnostic.",
    "preferred_sources": ["arXiv:2206.12265 supplementary material §C 'numerical methods'", "Innsbruck dipolar group 2020-2024 numerical method notes"]
  }
]
```

## 8. Publishability assessment

- **What is new this turn**: Closed-form BCH derivation showing that the
  spinor split-step's Larmor sub-cycling failure in the strong-field
  rotating-quantization-axis regime is a `dt² · p · F · sinθ · c_dd⟨n⟩`
  commutator leak between the transverse-Zeeman substep and the
  DDI-flanked interaction substring — *linear* in the LARGE Larmor
  frequency, not bounded by trap or interaction scale. Cross-checked by a
  BCH convergence-radius calculation that *independently* recovers the
  same $\mathrm{dt} \sim 1/p$ threshold the memory only quoted from
  Larmor-period sampling. Also a clean analytical proof that the
  Option γ combined-spin-step replaces the BCH parameter $p F\,\mathrm{dt}
  \to \dot\phi F\,\mathrm{dt}$.
- **Prior art**:
  - Kawaguchi-Ueda 2012 §III (spinor BEC numerics; weak-field canon).
  - Stamper-Kurn-Ueda RMP 85 (2013) (rotating-frame spinor formalism).
  - Klaus et al. 2022 (the experiment whose simulation broke).
  - Hess-Ueda / Barnett canon for rotating-frame spin dynamics.
  - (Unknown — see Q1-Q3) whether the specific Strang-leak scaling
    has been written down before.
- **Distinction**: The novelty is *isolating which substep boundary*
  carries the Larmor-linear leak — not a generic "BCH fails at strong
  field" remark. The specific identification of $[\hat B_\perp, \hat A_{\rm DDI}]$
  as the load-bearing commutator gives a quantitative prediction (P1) and
  a structural prescription (P2: combine all spin-sector operators into
  one matrix exponential per step). Prior art on rotating-frame spinor
  numerics typically motivates the rotating frame via *physical*
  arguments (Berry phase, gauge invariance) rather than *numerical*
  arguments (BCH leak structure). This turn's contribution is
  bridging the numerical-analysis and physical motivations.
- **Manuscript mapping**: This is the *theoretical justification* for the
  Option γ subsystem (`src/rotating_basis/`, 700 LOC). Natural target:
  a `docs/manuscript/papers/paper_option_gamma_methods.md` (currently
  not in the manuscript tree). Could also feed a methods-section paragraph
  in any Paper #5/6/7 that uses the rotating-basis path (per memory
  `universal_theorem_status.md`). NOT for paper3 (Universal Theorem) or
  paper4 (FullBdG) directly.
- **Title candidate**: "BCH-Leak Diagnosis of Larmor Sub-cycling in
  Spinor BEC Split-Step Integrators — and an Analytical Cure via
  Co-rotating Quantization Basis."
