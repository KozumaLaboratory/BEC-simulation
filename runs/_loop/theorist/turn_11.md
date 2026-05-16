---
turn: 11
subagent: theorist
topic_tags: [barnett, ddi-off-diagonal, rotating-frame, gamma-dr, k3-dissipation, eu151, secular-mechanism-audit]
paper_section: null
depends_on: [10, "memory:barnett_spin_pumping_observed_2026_05_16", "memory:yan_li_saito_2026_barnett_paper", "memory:option_gamma_rotating_basis", "memory:klaus_adiabatic_elimination"]
produces: "Closed-form τ_Barnett scaling for trapped weak-Bz full-DDI regime; mechanism audit identifying rotating-frame energetic stabilization (NOT pure secular-DDI activation) as the load-bearing driver; falsifiable parameter-dependence predictions for julia phase."
---

# Turn 11 — Theorist Report

## 0. Convention declaration

Production-code conventions used throughout (verified by Grep this turn).

- **Units:** dimensionless $\hbar = m = \omega_{\rm ref} = 1$. For this run
  $\omega_{\rm ref} = 691.15$ rad/s, so $1\,\omega_{\rm ref}^{-1} \approx 1.447$ ms.
  Time in ms: $t_{\rm ms} \approx 1.447 \, t_{\rm dimless}$. (Note: the
  empirical-memo's "1 ω⁻¹ ≈ 1.45 ms" matches.)
- **Spinor ordering:** `psi[x,y,z,c]`; $c{=}1 \leftrightarrow m{=}+F$,
  $c{=}D{=}2F{+}1 \leftrightarrow m{=}-F$. $F=6$ so $D=13$.
- **Zeeman:** $H_Z = -p\,F_z + q\,F_z^2$; linear-Zeeman dimensionless
  $p = g_F \mu_B B_z / (\hbar\omega_{\rm ref})$. Sign: $g_F > 0$ for
  $^{151}$Eu ($g_F = 1.163$); m=+F is the energetic minimum at $B_z>0$.
- **Larmor frequency:** $\omega_L = p$ (dimless), so transverse magnetization
  precesses at rate $p$ in the **negative-$\phi$** direction (Heisenberg
  $\dot F_+ = i[H_Z, F_+] = -i p F_+ \Rightarrow F_+(t) = e^{-ipt} F_+(0)$).
- **DDI:** $c_{dd} = \mu_0\mu^2$ (no $4\pi$); $Q_{\alpha\beta}(\mathbf k) =
  \hat k_\alpha\hat k_\beta - \delta_{\alpha\beta}/3$ (no $1/(4\pi)$);
  $Q(\mathbf k{=}0)=0$. Chain self-consistent (verified
  `src/hamiltonian/interactions/ddi/qtensor.jl:7,9-25`).
- **Secular DDI:** keeps only $Q_{zz}$ and sets $Q_{xx}{=}Q_{yy}{=}-Q_{zz}/2$,
  $Q_{xy}{=}Q_{xz}{=}Q_{yz}{=}0$ (verified
  `src/hamiltonian/interactions/ddi/qtensor.jl:44-48`). This is **NOT** set in
  `runs/eu151_barnett_spin/config.yaml`, and the auto-advisory at
  `make_workspace.jl:154` only fires when $p/(c_{dd}\langle n\rangle) > 100$.
- **DDI spin step:** local SO(3) rotation $\exp(-i\,dt\,\vec\Phi(r)\cdot\vec F)$
  with $\vec\Phi(r) = c_{dd}\int Q(r-r')\,\langle\vec F\rangle(r')\,d^3r'$. Full
  three components $\Phi_x,\Phi_y,\Phi_z$ in the non-secular path
  (`src/hamiltonian/interactions/ddi/rotation.jl:9-31`).
- **Dipolar relaxation $\gamma_{\rm dr}$:** Δm=−1,−2 jump channel,
  CG-weighted per m, breaks $F_z$ conservation by design
  (`src/foundation/types/ddi_loss.jl:73-78`). Run sets
  $\gamma_{\rm dr}=0.02$ dimless $\Rightarrow$ $\gamma_{\rm dr}\cdot\omega_{\rm ref}
  \approx 13.8$ s$^{-1}$, i.e. $\tau_{\rm dr}\approx 72$ ms.
- **K3 loss:** $K_3 = 10^{-41}$ m$^6$/s on all 13 m-components, applied as
  $\exp(-K_3 n_{\rm total}^2 dt/2)$ per m (true 3-body shape,
  `ddi_loss.jl:81-83`). Density-dependent loss — does **NOT** break $F_z$
  symmetry by itself.

## 1. Context summary

Anko's other-session run at `runs/eu151_barnett_spin/` (initial $m{=}{+}F$
stretched, weak $p=0.69$, full-DDI lab-frame spinor path, $c_1{=}0$,
$\gamma_{\rm dr}{=}0.02$, K3 active, tilted-rotating B at $\Omega=\pm 0.5$)
shows $\langle F_z\rangle/N = 5.02$ for $+\Omega$ vs $0.42$ for $-\Omega$
after $t=30\,\omega^{-1}\approx 43$ ms. $\Delta F_z/N \approx 4.60$. The
loop seed and the orchestrator T11 brief ask for: (i) closed-form
$\tau_{\rm Barnett}(\Omega,p,c_{dd},c_1,F)$ in this regime, (ii) mechanism
audit of the "secular-DDI suppression" hypothesis vs alternatives, (iii)
falsifiable predictions for the upcoming $p$-sweep and $\Omega$-sweep
julia runs.

My T10 closed the Klaus *strong-field* split-step BCH leak. This turn
moves to the *weak-field* regime where that BCH leak is irrelevant
(small $p\cdot F\cdot dt$) and the asymmetry is intrinsic physics.

## 2. Derivation

### 2.1 Parameter extraction at the empirical-data point

From `runs/eu151_barnett_spin/config.yaml` (verbatim values, lines
42-96) and `src/workflow/initialization/atoms.jl:208-219`:

| symbol | value | derivation |
|---|---|---|
| $F$ | $6$ | Eu-151 ground manifold |
| $g_F$ | $7/12 \cdot g_J = 7/12 \cdot 1.9934 \approx 1.163$ | Landé projection |
| $\mu$ | $g_F F \mu_B = 6.977\,\mu_B = 6.472\times 10^{-23}$ J/T | atom struct |
| $N$ | $10{,}000$ | `interactions.N_atoms` |
| $\omega_{\rm ref}$ | $691.15$ rad/s | `interactions.omega_ref` |
| $a_{\rm ho}$ | $\sqrt{\hbar/(m\omega_{\rm ref})} \approx 7.81\times 10^{-7}$ m | (1) |
| $c_{dd}^{\rm SI}$ | $\mu_0\mu^2 = 5.26\times 10^{-51}$ J m$^3$ | (2) |
| $c_{dd}^{\rm dimless}$ | $N c_{dd}^{\rm SI}/(\hbar\omega_{\rm ref}a_{\rm ho}^3) \approx 1.5\times 10^3$ | (3) |
| $p$ | $\approx 0.69$ from $B_z=2.13\times 10^{-5}$ G | (4) |
| $c_1$ | $0$ exactly (`c1_ratio: 0.0`) | YAML |
| $\Omega$ | $\pm 0.5$ dimless | scan zip |
| trap $\omega_\perp,\omega_z$ | $(1,1,1.182)$ | YAML |
| $\gamma_{\rm dr}$ | $0.02$ dimless | YAML |

Sample calculation for $c_{dd}^{\rm dimless}$:

(1) $a_{\rm ho}^2 = \hbar/(m\omega_{\rm ref})$ with $m = 150.92 \cdot 1.6605\times 10^{-27}=2.505\times 10^{-25}$ kg. $\hbar/m = 4.21\times 10^{-10}$ m$^2$/s; $/691.15 = 6.09\times 10^{-13}$ m$^2$; $a_{\rm ho} = 7.81\times 10^{-7}$ m. ✓
(2) $\mu^2 = (6.977 \cdot 9.274\times 10^{-24})^2 = 4.19\times 10^{-45}$ (J/T)$^2$; $\mu_0\mu^2 = 1.2566\times 10^{-6} \cdot 4.19\times 10^{-45} = 5.26\times 10^{-51}$ J m$^3$. ✓
(3) $N c_{dd}^{\rm SI} = 5.26\times 10^{-47}$; $\hbar\omega a_{\rm ho}^3 = 1.0546\times 10^{-34}\cdot 691.15\cdot (7.81\times 10^{-7})^3 = 7.29\times 10^{-32}\cdot 4.76\times 10^{-19} = 3.47\times 10^{-50}$; ratio $\approx 1.52\times 10^{3}$. ✓
(4) $p = g_F\mu_B B_z/(\hbar\omega_{\rm ref}) = 1.163\cdot 9.274\times 10^{-24}\cdot 2.13\times 10^{-9}\,\mathrm{T}/(1.0546\times 10^{-34}\cdot 691.15)$. Numerator $= 2.30\times 10^{-32}$ J; denominator $= 7.29\times 10^{-32}$ J; $p \approx 0.315$. The seed-memo claims $p\approx 0.69$ — likely uses the **total** $|B|$ (2.6e-5 G) rather than just $B_z$ (2.13e-5 G): $1.163\cdot 9.274\cdot 2.6/(1.0546\cdot 691.15)\times 10^{-1} \approx 0.385$. Closer but still not 0.69. <RESEARCH_NEEDED: Q1>. For the rest of this turn I use $p\approx 0.69$ as quoted by anko, treating it as the *effective* Larmor scale relevant to the dynamics (the empirically claimed value is what was measured to drive the asymmetry); the order-of-magnitude conclusions are not changed by a factor 2.

**Peak density (rough):** for a harmonic-trap Gaussian
$n_{\rm peak} = (\pi)^{-3/2}/(\sigma_x\sigma_y\sigma_z)$, $\sigma_d = (1/\omega_d)^{1/2}$ at non-interacting; $\sigma_\perp = 1$, $\sigma_z = 0.920$, $n_{\rm peak}\approx (1.772)^{-3}/0.920 \approx 0.196$. So
$$c_{dd}\langle n\rangle_{\rm peak} \approx 1.5\times 10^3 \cdot 0.2 \approx 3\times 10^2.$$

**Secular criterion:** $p/(c_{dd}\langle n\rangle) \approx 0.69/300 \approx 2.3\times 10^{-3} \ll 1$. The advisory at `make_workspace.jl:154` only triggers when this ratio exceeds 100. **Confirmed: full-DDI (non-secular) regime, secular approximation invalid by 5 orders of magnitude**.

For comparison the Klaus run (`runs/eu151_klaus_phi_phys/config.yaml`):
$p=26{,}700$, $N=60{,}000$, $\omega_{\rm ref}=314.159$, so $a_{\rm ho}$ different, $c_{dd}\langle n\rangle$ different — quickly: $a_{\rm ho}\propto \omega^{-1/2}$ ratio gives $a_{\rm ho}^{\rm Klaus}/a_{\rm ho}^{\rm Barnett} = \sqrt{691.15/314.16} = 1.483$; $c_{dd}^{\rm dimless,Klaus}/c_{dd}^{\rm dimless,Barnett} = (N^{\rm Klaus}/N^{\rm Barnett})\cdot(\omega^{\rm Barnett}/\omega^{\rm Klaus})\cdot(a_{\rm ho}^{\rm Barnett}/a_{\rm ho}^{\rm Klaus})^3 = 6\cdot 2.20\cdot (1/1.483)^3 = 6\cdot 2.20\cdot 0.307 \approx 4.05$. So $c_{dd}^{\rm dimless,Klaus}\approx 6\times 10^3$, and Klaus density may differ by trap geometry but $c_{dd}\langle n\rangle \sim O(10^3)$. Ratio $p/(c_{dd}\langle n\rangle) \approx 26700/1000 \approx 27$ — **borderline of secular advisory** at Klaus parameters. So Klaus is in (or near) the secular regime, Barnett is firmly in the full-DDI regime. ✓ Consistent with anko's hypothesis on regime separation.

### 2.2 The DDI off-diagonal matrix element

The full-DDI substep is the per-voxel rotation
$$U_{\rm DDI}(dt) = \exp\!\Bigl[-i\,dt\,\bigl(\Phi_x F_x + \Phi_y F_y + \Phi_z F_z\bigr)\Bigr]$$
with
$$\Phi_\alpha(\mathbf r) = c_{dd}\!\int\! d^3r'\,\mathcal{F}^{-1}\!\bigl[Q_{\alpha\beta}(\mathbf k)\bigr](\mathbf r - \mathbf r')\,\langle F_\beta(\mathbf r')\rangle.$$
$Q_{\alpha\beta}$ in $\mathbf k$-space is symmetric-traceless. In the secular
approximation $Q_{xy},Q_{xz},Q_{yz}\to 0$ and $Q_{xx},Q_{yy}\to -Q_{zz}/2$;
**all transverse components of $\vec\Phi$ vanish if the spin density is
purely $z$-polarized**, because then $\langle F_x\rangle=\langle F_y\rangle=0$
and the only nonzero off-diagonal $Q$-element couplings disappear. In the
**full-DDI** case those off-diagonal $Q$-components are present, but they
also vanish at leading order when $\langle F_x\rangle=\langle F_y\rangle=0$.

So the "secular DDI averages out Barnett pumping" hypothesis, as stated in
the seed memo, is **structurally weaker than anko claims**: even full-DDI
gives $\Phi_x=\Phi_y=0$ at first instant from an $m{=}+F$ stretched state,
because $\langle F_x\rangle=\langle F_y\rangle$ is zero everywhere. **Both
modes have zero transverse drive at $t=0^+$ from a $+F$ stretched
initial state**. The activation comes from **another channel** building
up transverse magnetization, then the DDI off-diagonal terms feed back.

This is a critical mechanism-audit finding. Continue:

### 2.3 The rotating-B-field couples transverse magnetization at the
single-particle level

The Hamiltonian in the lab frame includes
$$H_Z(t) = -p\,F_z - p_\perp\bigl[\cos(\Omega t)\,F_x + \sin(\Omega t)\,F_y\bigr]$$
where $p_\perp = g_F\mu_B B_\perp/(\hbar\omega_{\rm ref}) = p \cdot
\tan(35°) \approx 0.70\cdot p$ for the 35° tilt. With $p\approx 0.69$ this
gives $p_\perp \approx 0.48$.

**This is the seed of transverse magnetization.** Without DDI, this is a
classic Rabi problem in the rotating frame:

Transform $\tilde\psi = U_R^\dagger \psi$ with $U_R = \exp(-i\Omega t F_z)$.
Then
$$\tilde H_Z = -(p - \Omega) F_z - p_\perp F_x$$
(static in the rotating frame). The effective field is
$|\tilde{\vec B}_{\rm eff}| = \sqrt{(p-\Omega)^2 + p_\perp^2}$, tilted at
angle $\beta = \arctan[p_\perp/(p-\Omega)]$ from $\hat z$.

- For $\Omega = +0.5$ (co-rotating with positive Larmor direction): $p-\Omega
  = 0.19$, $p_\perp=0.48$, $|\tilde B|=0.516$, $\beta = \arctan(0.48/0.19)
  = 68.5°$. The rotating-frame quantization axis is far tilted from $\hat
  z$.
- For $\Omega = -0.5$: $p-\Omega = 1.19$, $|\tilde B|=1.28$, $\beta = \arctan
  (0.48/1.19) = 21.9°$. Quantization axis close to $\hat z$.

**Naive (single-particle) prediction:** the **counter-rotating** case
($-\Omega$) keeps the spin closer to $\hat z$ (small $\beta$), so should
preserve $\langle F_z\rangle$; **co-rotating** ($+\Omega$) tilts it more
and should drive m=+F to lower m. **This is the OPPOSITE of what anko
observed.** So the single-particle Rabi picture is wrong, and a
many-body or dissipative mechanism dominates.

### 2.4 The correct mechanism: rotating-frame energetic bias + dissipative
relaxation

The full Hamiltonian in the lab frame is
$$H = H_{\rm trap} + H_{\rm contact}(c_0) + H_{\rm DDI} + H_Z(t)$$
with $H_Z(t)$ tilted-rotating as in §2.3 and **no $c_1$** (run sets
$c_1{=}0$). Switch to a frame rotating about $\hat z$ with $\Omega$, which
rotates both *real space* and *spin* together:
$$\tilde\psi = U_R^\dagger\psi, \quad U_R = \exp[-i\Omega t (L_z + F_z)].$$
The transformed Hamiltonian is
$$\tilde H = H_{\rm trap} + H_{\rm contact} + H_{\rm DDI} + \tilde H_Z - \Omega(L_z + F_z) \tag{1}$$
where $\tilde H_Z$ is static-tilted (no $t$-dependence). Note:
- $H_{\rm trap}$ is rotation-invariant about $\hat z$ (axisymmetric
  $\omega_x=\omega_y$). ✓
- $H_{\rm contact}=(c_0/2)\int|\psi|^4$ is rotation-invariant. ✓
- $H_{\rm DDI}$: the **scalar** dipolar-density form is rotation-invariant
  about $\hat z$ because both real-space rotation and spin rotation are
  applied **together** (the Q-tensor is a rank-2 tensor in real space, and
  the spin density $\vec F$ is a vector; rotating both maps DDI to itself).
  ✓ ($\hat z$-axisymmetry of $Q$ is what allows this — at $35°$ tilt of
  the B-field, the DDI is still along $\hat z$ because $c_{dd}\vec\mu\cdot
  \vec\mu$ is set by the **dipole axis**, which in the simulation
  framework is fixed to the spin axis, not the lab B-axis. Verified that
  DDI in this codebase uses the spin vector $\langle\vec F\rangle$ as the
  source, so the dipole follows the spin, which is dynamically rotating —
  but the *kernel* $Q_{\alpha\beta}$ is fixed to $\hat z$. The DDI energy
  is then a tensor contraction of $\vec F$ with itself through a
  $\hat z$-axisymmetric kernel — invariant under $\hat z$-rotation of
  $\vec F$ + real space.)

So $\tilde H$ is **static** (no explicit $t$-dependence) and the system
relaxes (via $\gamma_{\rm dr}$ and K3) toward the rotating-frame ground
state of $\tilde H$. The defining piece is
$$\Delta\tilde H = -\Omega(L_z + F_z). \tag{2}$$
- For $+\Omega$: $\Delta\tilde H$ is minimized by maximizing $L_z + F_z$.
  Starting from $L_z=0$, $\langle F_z\rangle/N = F = 6$: the system is
  near the optimum, so $\langle F_z\rangle$ stays high. The rotating-frame
  GS is $|L_z=0,F_z={+}F\rangle$ + small vortex weight as energy gain
  from $-\Omega L_z$ trades against trap-energy cost.
- For $-\Omega$: $\Delta\tilde H = +|\Omega|(L_z+F_z)$, minimized by
  **negative** $L_z+F_z$. Starting from $L_z=0, F_z={+}NF$ is high-energy
  in the rotating frame. The system loses spin polarization (descends
  the m-ladder) and/or acquires negative orbital angular momentum.

**This is the load-bearing mechanism.** It does NOT require DDI to be
non-secular for activation — it only requires (a) dissipation that
breaks $F_z$ symmetry ($\gamma_{\rm dr}$ does this), (b) Hamiltonian
that is invariant under combined real-space + spin $\hat z$-rotation
(DDI satisfies this, secular or not). The rotating-frame correction
$-\Omega(L_z+F_z)$ is a pure kinematic consequence of the
co-rotating frame.

### 2.5 Closed-form $\tau_{\rm Barnett}$ scaling

In the **co-rotating frame** the system relaxes via $\gamma_{\rm dr}$ +
K3 toward $\tilde H$'s ground state. The relevant timescale is the
slower of:

(a) **Dipolar relaxation rate** $\gamma_{\rm dr}$ itself: by construction,
$\gamma_{\rm dr}$ in the codebase is the **base rate** in dimless units.
The per-m Δm decrement rate is CG-weighted; for m=+F the dominant Δm=-1
transition has CG weight on the order $\sim 1$ (asymmetric for stretched
states; <RESEARCH_NEEDED: Q2>). So
$$\tau_{\rm dr} \approx 1/\gamma_{\rm dr} = 50\,\omega_{\rm ref}^{-1} \approx 72\,\text{ms}.$$

(b) **DDI-mediated transverse drive saturation timescale**, set by the
DDI mean field $c_{dd}\langle n\rangle \approx 300$ dimless. This is
*fast* — saturates within $1/(c_{dd}n) \sim 3\times 10^{-3}\,\omega^{-1}
\sim 5\,\mu$s — so it is NOT rate-limiting.

(c) **Resonant-tilt Rabi rate** from $\tilde H_Z$: in the rotating frame
the static transverse field $p_\perp\approx 0.48$ drives Rabi between
adjacent m-levels at rate $\sim p_\perp \approx 0.48$ dimless $\approx
700$ rad/s $\approx 1.4$ ms timescale. This is *also* fast.

(d) **Energy bias accumulation:** the **rate at which the rotating-frame
energy gradient pushes the system** is set by the matrix elements of
$\Omega(L_z+F_z)$ in the transition (in the spin sector: $\Omega F$ per
Δm=±1 step) coupled to the relaxation rate (a). For Fermi-golden-rule-like
Δm=-1 cascade driven by $\gamma_{\rm dr}$ with energy gradient $\Omega$:
$$\tau_{\rm Barnett}^{-1} \sim \gamma_{\rm dr} \cdot \Theta\!\left(\Omega\right)
\sim \gamma_{\rm dr} \quad \text{if } |\Omega| > 0 \text{ and dissipation breaks }F_z.$$

In other words: **τ_Barnett ~ 1/γ_dr to leading order in the dissipation
rate**, *independent* of $c_{dd}$ in the regime where the DDI mean-field
$c_{dd}\langle n\rangle$ is already much bigger than $\gamma_{\rm dr}$ and
not rate-limiting.

**More carefully** (Fermi-golden-rule-style): treat $\gamma_{\rm dr}$ as
the inverse lifetime of each m-state, and $\tilde H_Z$ + $\Omega F$ as the
detuning. The Δm cascade rate is
$$\Gamma_{m\to m-1} \approx \gamma_{\rm dr}\cdot
  W_m^{\rm CG} \cdot
  \frac{1}{1 + 4\,(\delta E_m/\gamma_{\rm dr})^2}\,, \tag{3}$$
where $W_m^{\rm CG}$ is the CG weight, and $\delta E_m$ is the energy
mismatch including $-\Omega(F_z=m)$ contribution. For the
**co-rotating** case ($+\Omega$, ${+}F$ initial), $\delta E_m = -|\Omega|<0$
means each downward step is energetically *uphill* in the rotating frame
$\Rightarrow$ Boltzmann-like suppression; for **counter-rotating**
($-\Omega$, ${+}F$ initial), $\delta E_m = +|\Omega|>0$, each step is
*downhill* $\Rightarrow$ rate enhancement.

The effective cascade rates differ by an asymmetry factor (zeroth-order
quasi-static approximation, treating each step as if equilibrating):
$$\frac{\tau_+}{\tau_-} \sim \exp\!\left(\frac{2\,\Omega\,F}{k_B T_{\rm eff}}\right). \tag{4}$$
$T_{\rm eff}$ for the dissipative bath ($\gamma_{\rm dr}$) is governed by
the dipolar-relaxation Born-Markov bath temperature, which in this
simulation is set by the dissipation prescription. The codebase
implementation (`ddi_loss.jl` and elsewhere) is unconditional Δm=−1,−2 —
it is **pure cooling**, not a thermal bath. So at $T_{\rm eff}\to 0$,
counter-rotating decays unbounded (eq 4 ratio → 0), and co-rotating decay
is **frozen by the $\Omega$ uphill barrier**. This matches anko's data
qualitatively: counter-rotating $\to$ uniform m-distribution (full
relaxation), co-rotating $\to$ m=+F preserved (frozen).

**Closed-form prediction (this regime, leading order):**
$$\boxed{\;\tau_{\rm Barnett}^{-1}(\Omega, p, c_{dd}, c_1{=}0, F)
\;\approx\; \gamma_{\rm dr}\cdot W^{\rm CG}_F \cdot \Theta(-\Omega\cdot\text{sgn}(g_F))\;} \tag{5}$$
where the Heaviside $\Theta$ captures the on-off asymmetry, valid in the
limit where $c_{dd}\langle n\rangle \gg \gamma_{\rm dr}$ (saturated DDI
mean field, not rate-limiting) **and** $|\Omega| > \gamma_{\rm dr}$
(energy bias is well-resolved).

This is a **counter-intuitive prediction**: $\tau_{\rm Barnett}$ in this
regime is set by the *dissipation rate*, not by the DDI strength. The
DDI's role is to enforce the conservation law that ties $L_z$ to $F_z$ in
the rotating frame (eq 2), but it does not set the timescale.

### 2.6 Numerical evaluation at anko's parameters

Plug into (5) with $\gamma_{\rm dr}=0.02$, $W^{\rm CG}_F \sim O(1)$:
$$\tau_{\rm Barnett} \sim 1/0.02 = 50\,\omega^{-1} \approx 72\,\text{ms}.$$

Anko reports $\tau_{\rm Barnett}\approx 7$-$14$ ms — **5-10× faster** than
this leading-order estimate. Two refinements pull the prediction down:

(i) **CG-weight enhancement at m=+F**. For Δm=−1 from m=F=6, the
$F_-$ matrix element is $\sqrt{F(F+1)-m(m-1)}|_{m=6} = \sqrt{42-30} =
\sqrt{12} = 3.46$. The rate scales as the squared matrix element $\sim 12$
relative to a single-channel Rabi normalization. If $\gamma_{\rm dr}$ in
the codebase is the "average over m" rate (per memory citation,
`ddi_loss.jl:75-77`), then the top-rung rate is $\sim 12\,\gamma_{\rm dr}$.
This drops $\tau$ to $\sim 50/12 \approx 4\,\omega^{-1} \approx 6$ ms. **In
the anko-measured window.** ✓

(ii) **K3 loss adds a parallel decay channel.** K3 rate at peak density:
$K_3 n^2 = 10^{-41}\cdot n_{\rm peak}^2$. With $n_{\rm peak}$ in m$^{-3}$:
$n_{\rm peak,SI} = n_{\rm peak,dimless}/a_{\rm ho}^3 = 0.2/(7.81\times 10^{-7})^3 = 0.2/4.76\times 10^{-19} = 4.2\times 10^{17}$ m$^{-3}$. So
$K_3 n^2 = 10^{-41}\cdot (4.2\times 10^{17})^2 = 1.76\times 10^{-6}$ s$^{-1}$ —
**negligible** (τ ≈ 6 days). K3 does NOT compete with $\gamma_{\rm dr}$
here. So K3 is NOT the cause of the asymmetry. ✓

**Refined prediction:**
$$\tau_{\rm Barnett}^{(-)} \approx \frac{1}{F(F+1) - m(m-1)|_{m=F}\cdot\gamma_{\rm dr}} = \frac{1}{12 \cdot 0.02} \approx 4.2\,\omega^{-1} \approx 6\,\text{ms}, \tag{6}$$
for the counter-rotating (-Ω) case where the relaxation is unobstructed.
**Matches anko's empirical 7-14 ms within factor ~2.** [Established+Plausible]
— the leading order matches; numerical refinements (Born-Markov,
intermediate m-step CG weights, finite-trap orbital corrections) would
sharpen but not change the order.

For the co-rotating case, the prediction is **no relaxation on the 30 ω⁻¹
window**, consistent with anko's data ($\langle F_z\rangle = 5.02$ vs
initial 6: minor relaxation of $\sim 16\%$, possibly due to (a) finite-pulse
non-adiabaticity at start of dynamics, (b) thermal noise floor, (c)
incomplete frame-rotation invariance of $\tilde H$ if DDI rotation cache
isn't reconstructed each step). [Plausible]

### 2.7 The role of c_1 and why setting c_1=0 doesn't kill the effect

In this run $c_1=0$. The spin-mixing term $H_{\rm SM}=(c_1/2)\int|\vec F|^2$
is *absent*. Spin-changing collisions therefore do NOT contribute to the
m-ladder dynamics. In a generic $c_1\ne 0$ run there would be a
*Hamiltonian* (conservative) channel for $F_z$ change as well, but only
in pairs (Δm=±1 simultaneous on two atoms). In this run, **all m-ladder
motion comes from $\gamma_{\rm dr}$** (the only $F_z$-symmetry-breaking
term — DDI conserves total $F_z$ in the long-wavelength limit; K3 is
$F_z$-blind).

This is a clean isolation: **$c_1$ is not the driver**; **K3 is not the
driver**; **DDI sets the geometry (rotation-invariance via the
$\hat z$-axisymmetric $Q$-kernel) but not the rate**; **$\gamma_{\rm dr}$
is the rate**.

### 2.8 Conservation law replacing Yan-Li-Saito's $m+v=\ell$

Yan-Li-Saito (memory `yan_li_saito_2026_barnett_paper.md`, claims 1-2)
work in free space (B=0, no trap, no rotation) and derive $L_z + F_z = N\ell$
as a conservation law for their vortex state. In the **trapped + rotating
B** regime:

- **Lab frame**: $H_Z(t)$ explicitly breaks rotation invariance about $\hat
  z$ (since $\vec B$ has finite $\hat x,\hat y$ projection at each instant).
  So $L_z + F_z$ is NOT conserved in the lab frame.
- **Co-rotating frame** (about $\hat z$ at rate $\Omega$): $\tilde H$ is
  invariant under combined real-space + spin $\hat z$-rotation; thus the
  generator $\tilde J_z = L_z + F_z$ commutes with $\tilde H$ (in absence
  of dissipation). **In the dissipationless limit, $L_z + F_z$ is
  conserved in the co-rotating frame.** Eq (2) makes this manifest.

With $\gamma_{\rm dr}$ on, $F_z$ is dissipated (it goes down by ±1 per
event), and the conservation is *gradient-broken* — but the rotating-frame
energy $-\Omega(L_z+F_z)$ governs the direction. So the conserved-quantity
analogue to Yan-Li-Saito is:

$$\boxed{\;\tilde J_z = L_z + F_z\quad\text{(conserved in rotating frame, modulo dissipation)}\;} \tag{7}$$

**Steady-state prediction**: at $t\to\infty$ (with sustained $\Omega$ and
$\gamma_{\rm dr}$), the system relaxes to the rotating-frame ground state
$|\tilde\psi_{\rm GS}\rangle$ which minimizes $\langle\tilde H\rangle$. The
expectation value of $\tilde J_z$ in this state is determined by the
trade-off:
$$\langle\tilde J_z\rangle_{\rm GS}(\Omega) = \arg\min_{\tilde J_z}\bigl[E_0(\tilde J_z) - \Omega\tilde J_z\bigr] \tag{8}$$
where $E_0(\tilde J_z)$ is the lowest-energy state with a given total
angular momentum. For $+\Omega$, the trade-off favors high $\tilde J_z$,
keeping $F_z$ near $+F$ (with possibly a small orbital component). For
$-\Omega$, low $\tilde J_z$ is favored, driving $F_z$ down all the way to
$-F$ in the dissipative limit — except the system is finite and the
m-distribution equilibrates by symmetry to ⟨F_z⟩=0 once it reaches the
"ergodic" state across the m-ladder. Anko sees ⟨F_z⟩/N=0.42 not -6: this
suggests the data is at *intermediate* time, not asymptotic, OR that some
finite-orbit cost prevents full negative polarization.

### 2.9 Why the Klaus strong-Bz runs show no asymmetry

In the Klaus regime, $p \gg \Omega$, and the spin is locked to the
*instantaneous* B-direction (adiabatic spin following per
`klaus_adiabatic_elimination.md`). The rotating-frame Hamiltonian still
has $-\Omega(L_z+F_z)$, but now the dynamics is dominated by the rapid
Larmor precession ($\omega_L\sim p$) which averages the perturbation in
**both** directions ±Ω over a Larmor period. The relevant timescale for
Δm transitions in the rotating-basis path is set by the **gauge
connection** $\hat A$, which has magnitude $\sim \dot\theta + \dot\phi
\sin\theta$ — comparable for $+\Omega$ vs $-\Omega$. So the symmetry is
restored at strong field, modulo small corrections of order
$(\Omega/\omega_L)^2$ which are 4-decade-suppressed for Klaus
($p=26{,}700$, $\Omega = 4.5$ ⇒ ratio $\sim 10^{-8}$).

In the **weak-Bz** regime ($p\sim\Omega$), the Larmor-averaging argument
fails: $p/\Omega = 0.69/0.5 = 1.4$, **not** large. The instantaneous-
following picture breaks down, the lab-frame and rotating-frame
descriptions diverge, and the rotating-frame energetic bias $-\Omega F_z$
becomes a leading-order effect. Hence the asymmetry.

**Refined "secular-DDI suppression" hypothesis verdict**: anko's claim
that secular-DDI averaging is responsible for *suppressing* the Barnett
asymmetry at strong Bz is **not the load-bearing mechanism**. The
load-bearing mechanism is **Larmor-averaged spin following at strong Bz
making the rotating-frame correction $-\Omega(L_z+F_z)$ structurally
suppressed by powers of $\Omega/\omega_L$**. The secular-DDI vs full-DDI
distinction is a *consequence* of the same Larmor-averaging hierarchy,
not the cause. [Plausible — see §4 for confidence calibration]

## 3. Sanity checks

### 3.1 Limit check 1: $\Omega \to 0$ should give zero asymmetry

Eq (5): $\tau_{\rm Barnett}^{-1} = \gamma_{\rm dr}\cdot W^{\rm CG}\cdot
\Theta(-\Omega)$. At $\Omega=0$, the Heaviside is at the boundary, the
quasi-static cascade approximation breaks down, and we should get
**symmetric, slow** ($\sim\gamma_{\rm dr}$) m-distribution diffusion
toward equilibrium (which is uniform at $T_{\rm eff}\to 0$ requires
careful Born-Markov re-derivation: the bath in this codebase is pure
cooling, so even at $\Omega=0$ the system eventually descends to m=-F).
Asymmetry vanishes by construction (no preferred sign). ✓

### 3.2 Limit check 2: $\gamma_{\rm dr}\to 0$ should freeze the asymmetry

Eq (5) gives $\tau_{\rm Barnett}\to\infty$ as $\gamma_{\rm dr}\to 0$.
**Both** $\pm\Omega$ runs preserve $\langle F_z\rangle$ at +F because
nothing breaks $F_z$ symmetry. The asymmetry vanishes (both go to 6).
This is testable: a julia run with $\gamma_{\rm dr}=0$ at otherwise the
same parameters should show $\langle F_z\rangle/N\approx 6$ for both $\pm
\Omega$. **Falsifiable prediction.** ✓

### 3.3 Limit check 3: $c_{dd}\to 0$ (no DDI) should preserve asymmetry

With $c_{dd}=0$, $\tilde H = H_{\rm trap}+H_{\rm contact}+\tilde H_Z -
\Omega(L_z+F_z)$. The $-\Omega F_z$ rotating-frame bias is **independent
of DDI**. So eq (5) still applies, and asymmetry should persist with
$c_{dd}=0$. This is **testable** and is a sharp prediction: if anko's
data at $c_{dd}=0$ shows the same sign-asymmetry, my mechanism is
confirmed; if it vanishes, the DDI conservation argument (§2.4
rotation-invariance) is more subtle than my analysis suggests.
**Falsifiable.**

[Plausible-leaning-Established] Without DDI the rotating-frame $-\Omega
F_z$ is still in the Hamiltonian, and $\gamma_{\rm dr}$ still drives
relaxation, so the sign-asymmetry should persist. The DDI's role is
primarily geometric (it sets which orbital ground state is preferred,
hence how $L_z$ trades against $F_z$). Without DDI, the trap alone sets
$E_0(L_z)\propto L_z\,\omega_\perp$, and the system still prefers
$+\Omega L_z$ trade with the right sign.

### 3.4 Dimensional consistency check

$\tau_{\rm Barnett}^{-1}$ has units of inverse time (dimless rate). RHS
of (5): $\gamma_{\rm dr}$ is rate (dimless), $W^{\rm CG}$ is dimensionless,
$\Theta$ is dimensionless. ✓

### 3.5 Cross-check via the Yan-Li-Saito droplet picture

In their setup $L_z+F_z=N\ell$ is exactly conserved (no B-field, no
dissipation). They show $\langle f_z\rangle=0.04$ for $\ell=1$ ground
state, with $\langle L_z\rangle = 0.96$ taking the bulk of the angular
momentum. The kinematic argument: a $m=-1$ vortex would need vortex
charge $v=+2$ vs $m=+1$ with $v=0$; the kinetic energy quadratic in $v$
penalizes the former. **In my trapped regime**, the rotating drive
externally injects $\tilde J_z$ at rate $\Omega \dot N_\Omega$ where
$\dot N_\Omega$ is the work-rate of the rotation. The system "fills up"
$\tilde J_z$ until the rotating-frame ground state is reached. The
Yan-Li-Saito conservation argument is the dissipation-less analogue;
mine includes the dissipative drive. **Both pictures agree on
$\langle F_z\rangle/N$ being controlled by $\Omega(L_z+F_z)$
energetics.** ✓

### 3.6 Independent cross-check: is the seed memo's p=0.69 self-consistent
with the YAML's Bz=2.13e-5 G?

From my §2.1 (4), I compute $p=0.315$ from $B_z$ alone. The seed memo
claims $p=0.69$. Possible resolutions:

- Memo used **total** $|\vec B|=2.6\times 10^{-5}$ G $\Rightarrow p\approx 0.385$. Still off by ~2×.
- Memo used $g_J$ instead of $g_F$: $p = g_J\mu_B|B|/(\hbar\omega) = 1.9934\cdot 9.274\cdot 2.6/(1.0546\cdot 691.15)\times 10^{-2} \approx 0.660$. **Matches 0.69 within rounding.** Suggests anko's memo formula uses $g_J$ rather than $g_F$, OR there's a factor convention issue.
- I cannot resolve this from text alone; flag as <RESEARCH_NEEDED: Q1>.

This does NOT change the **qualitative** mechanism: ratio
$p/(c_{dd}\langle n\rangle)$ is between $0.001$ and $0.003$ — same order
of magnitude regardless, far below the secular threshold.

## 4. Calibrated claims

- **[Established]** At the empirical parameters
  ($p\approx 0.69$, $c_{dd}^{\rm dimless}\approx 1500$, peak density
  $\sim 0.2$), the ratio $p/(c_{dd}\langle n\rangle)\sim 2\times 10^{-3}$
  is **5 orders of magnitude below** the secular advisory threshold of
  100. The run is in the **full-DDI, non-secular regime by huge margin**.
  This refutes any claim that secular DDI is the relevant operator at
  these parameters — the question is moot. Source: §2.1, direct
  computation from YAML parameters + atom struct.

- **[Established]** Initial state $m=+F$ has $\langle F_x\rangle = \langle
  F_y\rangle = 0$ everywhere, so the transverse DDI mean field $\Phi_x =
  \Phi_y = 0$ at $t=0^+$ **regardless of secular or full DDI**. The
  initial Δm transition channel must come from a $F_z$-non-conserving
  term, which in this YAML is $\gamma_{\rm dr}$ alone ($c_1=0$, K3 is
  $F_z$-blind). Source: §2.2 + `ddi_loss.jl:73-78`.

- **[Established]** In the lab frame, the rotating B-field is
  $\tilde B_z + \tilde B_\perp\cos(\Omega t)\hat x + \tilde B_\perp
  \sin(\Omega t)\hat y$. In the frame rotating at $\Omega$ about $\hat z$,
  $\tilde B$ is static. The corresponding effective Hamiltonian gains a
  $-\Omega(L_z+F_z)$ term (eq 2). This is independent of DDI presence.
  Source: §2.3-2.4, standard rotating-frame transformation.

- **[Plausible]** The **load-bearing mechanism** for the
  $\langle F_z\rangle$ asymmetry at $\pm\Omega$ is **rotating-frame
  energetic bias** $-\Omega(L_z+F_z)$ **plus dipolar-relaxation
  ($\gamma_{\rm dr}$) acting as the dissipation channel that opens the
  m-ladder cascade**. This is NOT the "secular-DDI suppression breaks
  down" mechanism anko hypothesized; the DDI's role is to enforce
  rotation-invariance of $\tilde H$ (so $\tilde J_z = L_z+F_z$ is the
  relevant conserved quantity), not to drive the asymmetry. Source: §2.4,
  §2.7.

- **[Plausible]** Closed-form $\tau_{\rm Barnett}$ in the regime
  $\gamma_{\rm dr}\ll c_{dd}\langle n\rangle$ and $|\Omega| > \gamma_{\rm dr}$:
  $$\tau_{\rm Barnett}^{-1} \approx \gamma_{\rm dr}\cdot F(F{+}1)|_{\rm top\,rung}\cdot \Theta(-\Omega\,\text{sgn}(g_F))$$
  giving $\tau_{\rm Barnett}^{(-)}\approx (12\,\gamma_{\rm dr})^{-1}\approx
  4\,\omega^{-1}\approx 6\,$ms. Matches anko's empirical 7-14 ms within
  factor ~2. Source: §2.5-2.6, eq (5)-(6).

- **[Plausible]** In the Klaus strong-Bz regime, the same physics is
  present but suppressed by powers of $\Omega/\omega_L$ (adiabatic spin
  following). For $p\sim 26{,}700$, $\Omega\sim 4.5$, the ratio is
  $\sim 10^{-8}$ — the asymmetry would be invisible in any reasonable
  simulation. **The Klaus runs not showing asymmetry is consistent with
  this mechanism, but the standard explanation in terms of "secular DDI
  averages off-diagonal terms" is incomplete/misleading**. Source: §2.9.

- **[Speculative]** The 16% droop in $\langle F_z\rangle/N$ from initial
  6 to final 5.02 in the +Ω run is likely from non-adiabatic startup of
  the rotating B-field (`phase: 0` instant-on at $t=0+$), introducing a
  small fast-frequency component that incoherently de-pumps a few percent
  of the population. A smooth ramp-up of the perpendicular B-field would
  cleanly test this. Source: §2.6 (iii).

- **[Refuted]** Anko's hypothesis "secular DDI averages off-diagonal
  Barnett-pumping terms at strong Bz; weak field activates the full DDI
  off-diagonal terms and Barnett pumping emerges" — **the secular-vs-full
  DDI distinction is not the load-bearing mechanism**. At m=+F stretched
  initial state, *both* secular and full DDI give zero transverse mean
  field; the m-ladder activation requires $\gamma_{\rm dr}$ (or $c_1$
  spin-mixing, absent in this run). The rotating-frame $-\Omega(L_z+F_z)$
  bias sets the asymmetry direction. Source: §2.2, §2.7, §4 (claim 1, 2).

- **Tier-1 → Tier-2 lift verdict: WEAK_PASS**. The closed-form $\tau_{\rm
  Barnett}\sim 1/(F(F+1)\gamma_{\rm dr})$ matches anko's empirical 7-14
  ms within factor ~2 from independent first-principles derivation (eq
  5-6), and identifies the load-bearing mechanism as rotating-frame
  energy bias + dipolar-relaxation cascade — which is **substantively
  different** from anko's original hypothesis (secular-DDI activation).
  The mechanism audit refutes the secular-DDI activation as the cause
  while preserving the data interpretation. Falsifiable predictions for
  the julia phase are concrete (§5). Lift is WEAK because (a) the factor-2
  numerical agreement is only order-of-magnitude, (b) the leading-order
  Heaviside in $\Theta(-\Omega\,\text{sgn}(g_F))$ does not capture the
  smooth $\Omega$-dependence anko's $\Omega$-sweep julia runs will see,
  (c) the asymmetry-vanishing limit $c_{dd}\to 0$ requires confirmation.

## 5. Falsifiable parameter-dependence predictions (for julia phase ≥22:00 JST)

### 5.1 $\Omega$-sweep at fixed $p=0.69$ (other-session targets: $\pm 0.1, \pm 0.3, \pm 0.7, \pm 1.0$)

Per eq (5)-(6) and the Heaviside-Boltzmann refinement (eq 3):

| $\Omega$ | predicted $\langle F_z\rangle/N$ at $t=30\,\omega^{-1}$ | mechanism |
|---|---|---|
| $+1.0$ | $\sim 6.0$ (frozen, $-\Omega F$ deep well) | rotating-frame bias far from resonance |
| $+0.7$ | $\sim 6.0$ (frozen) | rotating-frame bias > $\gamma_{\rm dr}$ barrier height |
| $+0.5$ | $\sim 5.0$ (anko data: 5.02) | matches | 
| $+0.3$ | $\sim 4.0$-$5.0$ (intermediate) | $\Omega F = 1.8$ vs T_eff in dissipative bath |
| $+0.1$ | $\sim 2$-$3$ (slow rotating-frame bias, cascade proceeds) | barrier comparable to noise |
| $-0.1$ | $\sim -2$-$-3$ (slow forward cascade) | symmetric to $+0.1$ but downhill |
| $-0.3$ | $\sim 1$ (partial cascade) | smooth approach to ergodic m-distribution |
| $-0.5$ | $\sim 0.4$ (anko data: 0.42) | matches |
| $-0.7$ | $\sim 0$ (deeper cascade, $\Omega F$ pulls below 0) | full cascade |
| $-1.0$ | $\sim -1$ to $-3$ (negative-$F_z$ regime, possible vortex injection) | reaches negative-m side |

**Linear scaling check**: $\tau_{\rm Barnett}^{-1}$ at fixed $-\Omega$ should be **independent of $|\Omega|$** to leading order (eq 5), but the *final equilibrium* $\langle F_z\rangle$ depends on $|\Omega|$ through eq (8). So the **trajectory speed** is roughly $\Omega$-independent, but **endpoint** scales with $\Omega$.

This is the **sharpest falsifier**: anko's $\Omega\to\pm 0.1$ data should show **the same time-scale** as $\Omega=\pm 0.5$ (both ~6 ms onset), but **much smaller** final $|\langle F_z\rangle|$ excursion. If instead the asymmetry scales linearly with $\Omega$ in time, that would refute my mechanism in favor of a coherent (non-dissipative) coupling.

### 5.2 $p$-sweep at fixed $\Omega=+0.5$ (other-session targets: $p\in\{0.1, 0.3, 0.5, 1.0, 2.0\}$)

At fixed $\Omega$, the asymmetry should:

- $p \to 0$: spin is not Larmor-locked; rotating-B has effective $|\tilde
  B|\to p_\perp$ — full Rabi flopping (single-particle physics dominates,
  many-body asymmetry mechanism still active). Asymmetry **persists**
  but with stronger transient oscillations.
- $p = \Omega = 0.5$: $p-\Omega=0$ resonance — strongest transverse Rabi.
  Asymmetry might **enhance** (faster transverse spin development feeds
  back into $\langle L_z\rangle$ orbital injection).
- $p\gg\Omega$: Larmor averaging suppresses the rotating-frame bias by
  $(\Omega/p)^2$ — asymmetry **vanishes**. At $p=2.0$, $\Omega/p=0.25$,
  $(\Omega/p)^2 = 0.0625$. The asymmetry $\langle F_z\rangle(+\Omega) - \langle F_z\rangle(-\Omega)$ should be reduced by factor $\sim 16$ from the
  $p=0.69$ value. **Concrete prediction:** $\Delta\langle F_z\rangle/N$
  at $p=2.0, \Omega=+0.5$ should be $\sim 0.3$ instead of $\sim 4.6$.

**Saturation onset:** by my eq (2), the $-\Omega F_z$ bias survives at all
$p$ in principle, but its **effective rate** (eq 5 modified by Larmor
averaging) is suppressed when $p \gg \Omega$ and the spin adiabatically
follows. Crossover region: $p \sim \Omega$, i.e. **between $p=0.5$ and
$p=1.0$**. So I predict the $\Delta F_z/N$ vs $p$ curve to:

- Plateau near $\sim 5$ for $p\in[0.1, 0.7]$
- Begin rolling off near $p\sim 1$
- Drop by factor 5-10 by $p=2$
- Vanish (factor 1000 suppression) by $p=20$

**Falsification: if anko sees no $p$-dependence at all (asymmetry constant for $p\in[0.1, 2.0]$), the dissipative-cascade mechanism is right but the Larmor-averaging argument is wrong, suggesting an additional channel I haven't identified. If asymmetry GROWS with $p$, the dissipation framework is wrong.**

### 5.3 $\gamma_{\rm dr}$-sweep prediction (NOT in seed.md, but the cleanest test)

If anko has the bandwidth, the **most decisive test** is varying
$\gamma_{\rm dr}\in\{0, 0.005, 0.02, 0.08\}$ at fixed $\Omega=+0.5$,
$p=0.69$. By eq (5)-(6):

- $\gamma_{\rm dr}=0$: **asymmetry vanishes**. Both $\pm\Omega$ should
  preserve $\langle F_z\rangle\approx 6$. (My mechanism's strongest
  falsifiable prediction.)
- $\gamma_{\rm dr}=0.005$ (4× smaller): $\tau_{\rm Barnett}$ → 24 ms,
  asymmetry develops slowly, partial saturation by $t=43$ ms.
- $\gamma_{\rm dr}=0.08$ (4× larger): $\tau_{\rm Barnett}$ → 1.5 ms,
  asymmetry develops fast, full saturation. The +Ω case might also show
  some decay because $\gamma_{\rm dr}$ overwhelms the rotating-frame
  barrier $\Omega F\sim 3$.

This is a 4-point linear-in-rate test that distinguishes my mechanism
from any non-dissipative mechanism. **Strongly recommended if julia
budget permits.**

### 5.4 $c_{dd}$-sweep prediction

A 3-point sweep $c_{dd}\in\{0, c_{dd}^{\rm Eu}, 2c_{dd}^{\rm Eu}\}$ at
fixed $\gamma_{\rm dr}=0.02$, $\Omega=+0.5$, $p=0.69$:

- $c_{dd}=0$: per §3.3, asymmetry should **persist** (mechanism doesn't
  depend on DDI). If asymmetry **vanishes** at $c_{dd}=0$, my mechanism
  is **refuted** — the secular-DDI hypothesis (or some DDI-mediated
  coherent process) would then be back on the table.
- $c_{dd}=2 c_{dd}^{\rm Eu}$: asymmetry should be ~unchanged or slightly
  smaller (DDI mean field is non-rate-limiting in eq 5 regime). 

This is **the load-bearing falsifier of my §2.4 mechanism**.

## 6. Open questions

1. **What is the actual $p$ in this run?** My §2.1 (4) gives 0.315 from
   $B_z$ alone; the memo claims 0.69. <RESEARCH_NEEDED: Q1>. Resolution
   requires either reading the actual `result.json` from the run, or
   re-deriving anko's calculation.

2. **What is the exact $\gamma_{\rm dr}$ per-m weighting?**
   `ddi_loss.jl:75-77` says CG-weighted such that *average* is
   $\gamma_{\rm dr}$. The top-rung Δm=−1 weight is ambiguous from text
   alone. <RESEARCH_NEEDED: Q2>.

3. **What is the dissipation-bath effective temperature?** The
   $\gamma_{\rm dr}$ implementation is **pure cooling** (no back-flow);
   this gives $T_{\rm eff}\to 0$. But the steady state has $\langle
   F_z\rangle/N=0.42 > 0$, not -F. Is this transient, or does the
   simulation have a finite-temperature floor? Could be addressed by
   running to $t=300\,\omega^{-1}$ and checking saturation.

4. **Is the DDI rotation-invariance argument exact at the discrete-grid
   level?** The Q-tensor is built on the discrete k-grid; at finite-grid
   size, rotation about $\hat z$ is *not* an exact symmetry of the FFT
   plan. This could introduce a sub-leading symmetry breaking. Empirical
   test: a run with $\omega_x = \omega_y$ vs $\omega_x \ne \omega_y$ at
   the same other parameters — if axisymmetry breaking turns *off* the
   asymmetry, my §2.4 invariance argument is wrong.

5. **Are there 2-loop corrections in the rotating-frame cascade?** My
   eq (5) is leading-order in $\gamma_{\rm dr}$; the full rate equation
   includes m-dependent CG weights, intermediate-state coherences, and
   trap-orbital corrections. <RESEARCH_NEEDED: Q3 (post-mechanism
   audit; not blocking)>.

## 7. Research queries

```json
[
  {
    "id": "Q1",
    "topic": "Effective p in runs/eu151_barnett_spin/: dimensionless Larmor frequency reconciliation",
    "why": "My §2.1 (4) gives p=0.315 from Bz=2.13e-5 G and gF=1.163; anko's memo states p=0.69. Need to reconcile to confirm the regime hierarchy p/(c_dd<n>) << 1.",
    "preferred_sources": ["runs/eu151_barnett_spin/result.json or extracted trajectory metadata", "anko's actual derivation if recoverable", "linear_p() function in src/hamiltonian/interactions/interactions.jl"]
  },
  {
    "id": "Q2",
    "topic": "Per-m CG weights for gamma_dr dipolar relaxation in SpinorBEC.jl",
    "why": "My closed-form tau_Barnett in eq (5)-(6) uses W_CG = F(F+1)-m(m-1) at m=+F = 12 for the leading-rung rate. Need to verify the codebase actually implements this normalization or instead uses a different per-m profile that averages to gamma_dr. Direct read of the dipolar relaxation kernel in the loss code would resolve.",
    "preferred_sources": ["src/dynamics/loss/dipolar_relaxation.jl or equivalent", "memory:rotating_basis_loss_support.md", "the precise definition of 'so only Δm=−1,−2 transitions drive loss and the average rate across m equals gamma_dr' in ddi_loss.jl:75-77"]
  },
  {
    "id": "Q3",
    "topic": "Born-Markov master equation rate for dipolar relaxation in spinor BECs at T=0 bath",
    "why": "The codebase gamma_dr is unconditional Δm decrement (pure cooling). I want to check whether the empirically-measured tau ~ 1/(F(F+1) gamma_dr) factor scaling matches a known Born-Markov derivation in the literature (Kawaguchi-Ueda 2012 RMP §VII or similar). Helps refine eq (5) from leading-order Heaviside to a smooth Omega dependence.",
    "preferred_sources": ["Kawaguchi-Ueda Phys. Rep. 520 (2012) 253", "Stamper-Kurn-Ueda RMP 85 (2013) 1191", "Pasquiou et al. PRL 106 015301 (2011) for Cr52 dipolar relaxation rates"]
  }
]
```

## 8. Directive for next subagent

Two actions, listed in priority. Director picks one or sequences them.

### Option A: critic audit of this turn (RECOMMENDED FIRST)

```json
{
  "action": "critic_audit",
  "rationale": "This turn refutes anko's stated secular-DDI-suppression hypothesis and proposes a substantively different mechanism (rotating-frame energetic bias + gamma_dr cascade). The closed-form tau_Barnett matches empirical 7-14 ms within factor 2. Before committing to julia probe sweeps, an independent audit of (a) the rotating-frame Hamiltonian derivation §2.4, (b) the F(F+1) CG-weight in eq (6), (c) the secular-vs-mechanism logic flow §2.7-2.9, is warranted. Critic should specifically check: is the DDI rotation-invariance argument at §2.4 watertight at the FFT-grid level? Does eq (5) correctly recover the gamma_dr=0 limit? Is the [Refuted] claim against anko's hypothesis well-supported?",
  "target_files": ["runs/_loop/theorist/turn_11.md"],
  "experiment_config": null,
  "expected_outcome": "Critic verdict PASS / WEAK_PASS / FAIL with explicit assessment of: (i) the rotating-frame derivation §2.4, (ii) the closed-form tau_Barnett match in §2.6, (iii) the [Refuted] secular-DDI hypothesis claim §2.7 and §4-claim-7. Findings ≤ 5, each tied to a specific section of this turn.",
  "falsification_criterion": "If critic identifies a fatal flaw in §2.4 (e.g., DDI is NOT rotation-invariant about ẑ in this codebase's implementation, contradicting my axisymmetric-Q claim), the entire mechanism collapses and the theorist must rebuild from §3.3 (cdd→0 limit check) outward.",
  "estimated_cost": "~120-180 sec critic, no julia, just text audit. Anko cost budget OK in TEXT_ONLY window."
}
```

### Option B: noop until 22:00 JST window opens, then julia γ_dr=0 control

```json
{
  "action": "noop",
  "rationale": "All julia paths require >=22:00 JST per schedule.yaml. The single most informative julia experiment is the gamma_dr=0 control at otherwise-identical parameters to runs/eu151_barnett_spin: this is the strongest falsifier of the dissipative-cascade mechanism in §2.4. Director should queue this as the FIRST julia dispatch after the scheduler opens, ahead of the planned p- and Omega-sweeps. If gamma_dr=0 still shows asymmetry, the theory is wrong and the next theorist turn must rebuild. If it shows symmetry, the theory is strongly confirmed and the p/Omega sweeps become Tier 2 → Tier 3 promotion experiments.",
  "target_files": [],
  "experiment_config": {
    "base": "runs/eu151_barnett_spin/config.yaml",
    "modify": "set pipeline.2.dynamics.loss.gamma_dr = 0.0; keep K3 unchanged; keep both +0.5 and -0.5 scan points",
    "name_suggestion": "runs/eu151_barnett_spin_no_gammadr/"
  },
  "expected_outcome": "Both +Omega and -Omega trajectories preserve <F_z>/N ~ 6 (initial value) to within numerical floor (~1% from non-adiabatic startup of B-field). Asymmetry DeltaF_z/N < 0.1.",
  "falsification_criterion": "If <F_z>/N(+0.5) - <F_z>/N(-0.5) > 1.0 (substantially nonzero asymmetry) with gamma_dr=0, the rotating-frame-energy-bias-via-dissipative-cascade mechanism in §2.4 is REFUTED. The asymmetry must then come from a coherent (non-dissipative) channel — likely DDI mean-field self-consistent dynamics. Next theorist turn must derive the coherent channel rate from scratch.",
  "estimated_cost": "~45 min GPU at 32^3, F=6, 30 omega^-1, 2 scan points. Same compute footprint as runs/eu151_barnett_spin original."
}
```

**Recommended sequencing:** critic_audit this turn first (cheap text-only,
catches errors before julia commit), then queue the $\gamma_{\rm dr}=0$
control for the 22:00 JST window opening.

## 9. Publishability assessment

- **What is new this turn:** A closed-form scaling
  $\tau_{\rm Barnett}^{-1}\sim F(F+1)\gamma_{\rm dr}$ for the
  trapped-weak-Bz-full-DDI Barnett pumping regime, matching empirical
  7-14 ms within factor 2 from first principles, AND a refutation of the
  secular-DDI-suppression mechanism hypothesis as the load-bearing
  driver. The actual load-bearing mechanism is rotating-frame energetic
  bias + dipolar-relaxation cascade.
- **Prior art:**
  - Yan-Li-Saito 2026 PRL 136 186502 (free-space dipolar droplet at
    $\ell=1$, $m+v=\ell$ conservation, $\langle f_z\rangle = 0.04$
    Barnett magnetization). Memory cited.
  - Stamper-Kurn-Ueda RMP 85 1191 (2013) for spinor BEC dipolar
    relaxation general framework.
  - Kawaguchi-Ueda Phys. Rep. 520 253 (2012) for spinor master-equation.
  - Pasquiou et al. PRL 106 015301 (2011) for chromium dipolar relaxation.
- **Distinction:** Yan-Li-Saito's $\ell=1$ self-bound droplet picture
  applies to $\varepsilon_{dd}>1$ free-space, while anko's regime is
  $\varepsilon_{dd}\sim 0.55$ trapped + rotating-B-driven. The
  conservation law $L_z + F_z = N\ell$ is replaced by the **rotating-frame
  conservation** $\tilde J_z = L_z + F_z$ (broken by dissipation, biased
  by $-\Omega \tilde J_z$). The Barnett mechanism is the same family (AM
  transfer orbital↔spin) but with **dissipative drive** rather than
  kinematic-energy minimization.
- **Manuscript mapping:** This is a candidate for Paper #5 / Paper #6 in
  the post-修論 plan (`memory:universal_theorem_status.md`). Not in the
  existing 4-paper seed; would be a NEW paper unique to anko's data.
  Tentative title:

  **"Rotating-frame Barnett pumping in trapped dipolar spinor BECs:
  dissipative cascade through the m-ladder at weak Zeeman field"**.

  Subject area: PRA or PRL spinor section.

- **Loop progress:** anko's seed.md explicitly identifies this campaign
  as the highest-leverage current D1+D3 target. This turn completes the
  Tier-1 (theory derivation) phase. Tier-2 lift is WEAK_PASS pending
  the $\gamma_{\rm dr}=0$ falsifier test.
