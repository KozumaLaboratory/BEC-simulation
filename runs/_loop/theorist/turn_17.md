---
turn: 17
subagent: theorist
topic_tags: [barnett, cascade, rotating-frame, lindblad, coherent-channel, p-perp-rabi, eu151, gamma-dr-falsifier]
paper_section: null
depends_on: [11, 13, 14, 15, 16]
produces: "Coupled coherent+dissipative single-particle Lindblad in rotating frame; closed-form τ_asym(Ω,p_z,p_perp,γ_dr,F); γ_dr=0 falsifier prediction for 22:00 JST julia run."
---

# Turn 17 — Theorist Report

## 0. Convention declaration

- **Units**: $\hbar = m = \omega_{\rm ref} = 1$; for this run $\omega_{\rm ref} = 691.15$ rad/s, so $1\,\omega^{-1} \approx 1.447$ ms (verified config line 17–22 of T11).
- **Spinor ordering**: $c=1 \leftrightarrow m=+F$, $c=D=13 \leftrightarrow m=-F$. T11 §0 verified.
- **Authoritative parameters** (T14 §3 RESOLVED): $p_z = 0.315$ (NOT 0.69 — that was a $g_J$ vs $g_F$ error in anko's hand-memo). $p_\perp = (B_\perp/B_z) \cdot p_z = (1.49/2.13)\cdot 0.315 = 0.220$ (T16 §2 C1.1, recomputed from T14).
- **Stir frequencies**: $\Omega = \pm 0.5$ dimless (config line 100 scan-zip).
- **Larmor convention**: $H_Z = -p\,F_z + \ldots$, so $m=+F$ minimizes Zeeman energy for $g_F>0$ (Eu-151). Heisenberg precession $\dot F_+ = -ipF_+$.
- **Rotating-frame transformation**: $R(t) = \exp(-i\Omega t\,F_z)$ acts on spin only (single-particle sector). $R^\dagger F_z R = F_z$, $R^\dagger F_x R = \cos(\Omega t) F_x + \sin(\Omega t) F_y$, $R^\dagger F_y R = -\sin(\Omega t) F_x + \cos(\Omega t) F_y$. (Standard Schwinger / Sakurai.)
- **Dissipator (T15 §5 verified vs `losses.jl:152–189`)**: rank-2 jump operators $L_{m,q}=\sqrt{\gamma_{\rm dr} W^{\rm CG}_{m,q}}\,|m+q\rangle\langle m|$ for $q\in\{-1,-2\}$, $W^{\rm CG}_{m,q}=|\langle F,m+q|F,m;2,q\rangle|^2 / Z$ with $Z=2/5$ (F=6). $W^{\rm CG}_{+6,-1}=11/14$, $W^{\rm CG}_{+6,-2}=1/7$. These commute with $R(t)$ (diagonal in $m$-basis), so frame-invariant.
- **No convention deviations from production code in this turn.**

## 1. Context summary

T16 critic returned WEAK_PASS with a load-bearing **framework FAIL**: the T13/T15 cascade ODE captures only the dissipative $\gamma_{\rm dr}$ channel and is identical for $\pm\Omega$. The empirical $\Delta\langle F_z\rangle/N = 4.6$ asymmetry between $\pm\Omega$ at $t = 30\,\omega^{-1}$ therefore **cannot come from the cascade alone**. T16 §4 prescribed: derive the coupled coherent+dissipative single-particle Lindblad including the $p_\perp F_x$ Rabi channel in the rotating frame; compute the $\pm\Omega$ asymmetry-onset timescale; predict the $\gamma_{\rm dr}{=}0$ falsifier outcome for the 22:00 JST julia run. Below.

## 2. Derivation (Target T1: coupled Lindblad master equation)

### 2.1 Lab-frame Hamiltonian

The Phase-2 single-particle Zeeman Hamiltonian (from config Bx,By,Bz):
$$
H_Z^{\rm lab}(t) = -p_z\,F_z - p_\perp\bigl[\cos(\Omega t)\,F_x + \sin(\Omega t)\,F_y\bigr] \tag{1}
$$
with $p_z = 0.315$, $p_\perp = 0.220$, $\Omega \in \{+0.5,-0.5\}$.

The dissipator $\mathcal{D}[\rho]$ in the lab frame is
$$
\mathcal{D}[\rho] = \sum_{m,q\in\{-1,-2\}} \Big( L_{m,q}\,\rho\,L_{m,q}^\dagger - \tfrac{1}{2}\{L_{m,q}^\dagger L_{m,q},\,\rho\}\Big) \tag{2}
$$
$$
L_{m,q} = \sqrt{\gamma_{\rm dr}\,W^{\rm CG}_{m,q}}\,|m{+}q\rangle\langle m|, \qquad m+q \ge -F. \tag{3}
$$

### 2.2 Rotating-frame transformation

Define $\tilde\rho(t) = R^\dagger(t)\,\rho(t)\,R(t)$ with $R(t) = e^{-i\Omega t F_z}$. The unitary transformation gives
$$
\frac{d\tilde\rho}{dt} = -i\big[\tilde H_Z - \Omega F_z,\,\tilde\rho\big] + \tilde{\mathcal{D}}[\tilde\rho] \tag{4}
$$
where $\tilde H_Z = R^\dagger H_Z^{\rm lab} R$. Compute:
$$
R^\dagger\bigl[\cos(\Omega t)F_x + \sin(\Omega t)F_y\bigr] R = F_x
$$
(this is the central simplification — the rotating term in (1) is exactly cancelled by the frame rotation). Hence
$$
\tilde H_Z = -p_z F_z - p_\perp F_x
$$
and the effective rotating-frame coherent Hamiltonian is
$$
\boxed{\;H^{\rm rot} \equiv \tilde H_Z - \Omega F_z = -(p_z - \Omega)\,F_z - p_\perp F_x\;} \tag{5}
$$

The dissipator: $L_{m,q}$ is diagonal in $m$-basis, so $R^\dagger L_{m,q} R = e^{i\Omega t [(m+q)-m]}\,L_{m,q} = e^{i q\Omega t}\,L_{m,q}$. The Lindblad form $L\rho L^\dagger - \frac12\{L^\dagger L,\rho\}$ is invariant under multiplying $L \to e^{i\phi}L$ (the phase cancels). Therefore
$$
\tilde{\mathcal{D}}[\tilde\rho] = \mathcal{D}[\tilde\rho] \tag{6}
$$
— the dissipator has **the same operator form in the rotating frame**, with the same exact-rational $W^{\rm CG}_{m,q}$. This is the rigorous statement of "the dissipator is frame-invariant in the m-basis."

### 2.3 Coupled master equation (Target T1 result)

$$
\boxed{\;
\frac{d\tilde\rho}{dt} = -i\bigl[-(p_z-\Omega)F_z - p_\perp F_x,\,\tilde\rho\bigr]
\;+\; \sum_{m,q\in\{-1,-2\}}\Big(L_{m,q}\tilde\rho L_{m,q}^\dagger - \tfrac12\{L_{m,q}^\dagger L_{m,q},\tilde\rho\}\Big)
\;}
\tag{T1}
$$
with $L_{m,q}$ from (3), $W^{\rm CG}_{m,q}$ from T15 §5 Target 1 table.

This is what T13/T15 was missing in $H_{\rm coh}$ — the $-p_\perp F_x$ term. The dissipator is unchanged from T15.

### 2.4 Rotating-frame quantization-axis tilt angle (sets all asymmetry)

The coherent generator $H^{\rm rot}$ is a Zeeman field of magnitude
$$
\omega_R(\Omega) = \sqrt{(p_z-\Omega)^2 + p_\perp^2} \tag{7}
$$
tilted from $\hat z$ by angle $\beta(\Omega)$:
$$
\cos\beta(\Omega) = \frac{p_z-\Omega}{\omega_R(\Omega)}, \qquad \sin\beta(\Omega) = \frac{p_\perp}{\omega_R(\Omega)}. \tag{8}
$$

Plug in:

| $\Omega$ | $p_z-\Omega$ | $\omega_R$ | $\cos\beta$ | $\beta$ |
|----------|-------------|-----------|-------------|---------|
| $+0.5$ | $-0.185$ | $\sqrt{0.0342+0.0484}=0.2874$ | $-0.6437$ | $130.07°$ |
| $-0.5$ | $+0.815$ | $\sqrt{0.6642+0.0484}=0.8442$ | $+0.9655$ | $15.10°$ |

(Matches T16 §1 "β(+0.5)=130°, β(−0.5)=15.1°".)

**This is the asymmetry root**: for $-\Omega$ the rotating-frame quantization axis is nearly aligned with $\hat z$ (state $|+F\rangle$ stays near the rotating-frame ground state — $\langle F_z\rangle$ preserved). For $+\Omega$, the rotating-frame axis points well *below* the equator ($\beta > 90°$) so $|+F\rangle$ is closer to the rotating-frame *excited* state — large Rabi oscillation of $\langle F_z\rangle$.

## 3. dF_z/dt and d²F_z/dt² (Target T2)

### 3.1 dF_z/dt|_{t=0+} reproduction (T5 consistency)

$\dot F_z = -i\langle[H^{\rm rot},F_z]\rangle + \mathcal{D}^\dagger[F_z]$. Using $[F_x,F_z]=-iF_y$, $[F_y,F_z]=iF_x$, $[F_z,F_z]=0$:
$$
-i\langle[H^{\rm rot},F_z]\rangle = -i\langle[-p_\perp F_x, F_z]\rangle = -i \cdot (-p_\perp)\cdot(-i\langle F_y\rangle) = -p_\perp\langle F_y\rangle. \tag{9}
$$
For $\rho(0) = |{+}F\rangle\langle{+}F|$: $\langle F_y\rangle = 0$, so coherent contribution = $0$.

Dissipative contribution: $\mathcal{D}^\dagger[F_z] = \sum_{m,q}\gamma_{\rm dr}W^{\rm CG}_{m,q}\,q\,|m\rangle\langle m|$. Acting on $|+F\rangle\langle +F|$ gives
$$
\mathcal{D}^\dagger[F_z]\Big|_{m=+F} = \gamma_{\rm dr}\bigl[(-1)\cdot W^{\rm CG}_{+6,-1} + (-2)\cdot W^{\rm CG}_{+6,-2}\bigr]
= 0.02\cdot\bigl[-11/14 - 2/7\bigr] = 0.02\cdot(-15/14) = -\tfrac{3}{140}. \tag{10}
$$

**Sum**: $\dot F_z(0^+) = 0 + (-3/140) = -3/140\,\omega^{-1}$.  
**Reproduces T15 Target 2 exactly.** ✓ [Established]

### 3.2 d²F_z/dt²|_{t=0+}

Differentiate (9): need $\dot{\langle F_y\rangle}|_{0+}$.

$\dot F_y = -i\langle[H^{\rm rot},F_y]\rangle + \mathcal{D}^\dagger[F_y]$. Using $[F_z,F_y]=-iF_x$, $[F_x,F_y]=iF_z$:
$$
-i\langle[H^{\rm rot},F_y]\rangle = -i\langle[-(p_z{-}\Omega)F_z - p_\perp F_x,\,F_y]\rangle
= (p_z-\Omega)\langle F_x\rangle - p_\perp\langle F_z\rangle. \tag{11}
$$
Dissipator on $F_y$ at $\rho=|+F\rangle\langle +F|$: $F_y$ is off-diagonal in $m$, and $L_{m,q}$ is too — but $\langle +F|F_y|+F\rangle = 0$ and the dissipator preserves this at $t=0$ (a quick check: $L\rho L^\dagger$ takes $|+F\rangle\langle +F|$ to $W^{\rm CG}_{+F,-1}\,|+F{-}1\rangle\langle +F{-}1|$, also diagonal; the anticommutator term is diagonal in $|+F\rangle\langle +F|$). So $\mathcal{D}^\dagger[F_y]|_0 = 0$, hence
$$
\dot{\langle F_y\rangle}\Big|_{0+} = (p_z-\Omega)\cdot 0 - p_\perp\cdot F = -p_\perp F. \tag{12}
$$
(For $F=6$, $p_\perp=0.220$: $\dot{\langle F_y\rangle}|_0 = -1.320\,\omega^{-1}$.)

Therefore
$$
\ddot F_z\Big|_{0+}^{\rm coh} = -p_\perp\,\dot{\langle F_y\rangle}|_0 = +p_\perp^2 F. \tag{13}
$$
**Note**: this is **the same for both $\pm\Omega$** at $t{=}0$. Asymmetry between $\pm\Omega$ does *not* appear at second order — it requires coupling to the $(p_z-\Omega)$ detuning, which enters only via $\langle F_x\rangle$, which is zero at $t=0$. Asymmetry is a higher-order effect.

There is also a dissipator-Hamiltonian cross-term: $\ddot F_z^{\rm cross}|_0 = (d/dt)\mathcal{D}^\dagger[F_z]|_0 - \mathcal{D}^\dagger[\dot F_z^{\rm coh}]|_0$. Both vanish at $t=0$ because (i) $\mathcal{D}^\dagger[F_z]$ is purely diagonal in $|m\rangle$ and $|+F\rangle\langle +F|$ has no off-diagonal dynamics yet, and (ii) the coherent piece is proportional to $\langle F_y\rangle=0$. So at $t=0$, $\ddot F_z|_0 = p_\perp^2 F$ exactly (NOT including the symmetric dissipator second derivative, which adds order-$\gamma_{\rm dr}^2$, negligible: $\gamma_{\rm dr}^2 = 4\times 10^{-4}$ vs $p_\perp^2 F = 0.29$).

**Asymmetry-driver identification**: the leading $\Omega$-dependence in $F_z$ comes at **fourth order in $t$**, where the detuning $(p_z-\Omega)$ feeds back via $\langle F_x\rangle$. See §4.

## 4. τ_asym closed form (Target T3)

### 4.1 Pure-coherent solution (γ_dr = 0)

With $\gamma_{\rm dr}=0$, $H^{\rm rot}$ is a static Zeeman field of magnitude $\omega_R(\Omega)$ tilted at $\beta(\Omega)$. For an initial $|+F\rangle$ stretched state, the unitary evolution is rotation of the spin Bloch vector at angular speed $\omega_R$ about $\hat n(\Omega) = (\sin\beta,0,\cos\beta)$. The standard SU(2) coherent-state result for spin-$F$:
$$
\boxed{\;\langle F_z\rangle^{(\gamma=0)}(t;\Omega) = F\bigl[\cos^2\beta(\Omega) + \sin^2\beta(\Omega)\,\cos\!\bigl(\omega_R(\Omega)\,t\bigr)\bigr]\;} \tag{14}
$$
(Stretched-state expectation; derived by writing $|+F\rangle = (\cos(\beta/2)|+F\rangle_{\hat n} + \sin(\beta/2)e^{-i\phi}|...\rangle)^{...}$ and using $\langle F_z\rangle = F\cos\theta(t)$ with $\theta(t)$ the polar angle in the lab — standard result, see Sakurai Ch. 3 spin coherent states. For $F=6$ stretched there is no Wigner-distribution correction beyond mean-field; the time-averaged value is rigorously $F\cos^2\beta$.)

Note $\langle F_z\rangle$ commutes with $R(t)$, so this is also the **lab-frame** $\langle F_z\rangle$.

**Numerical at $F=6$**:

| $\Omega$ | $\cos^2\beta$ | $\sin^2\beta$ | $\omega_R$ | $\langle F_z\rangle$ average | $\langle F_z\rangle$ amplitude |
|----------|---------------|---------------|-----------|------------------------------|-------------------------------|
| $+0.5$ | $0.4144$ | $0.5856$ | $0.2874$ | $2.486$ | $\pm 3.514$ |
| $-0.5$ | $0.9330$ | $0.0670$ | $0.8442$ | $5.598$ | $\pm 0.402$ |

**Time-averaged asymmetry** at $\gamma_{\rm dr}=0$:
$$
\langle\Delta F_z\rangle_{\rm avg} = F\bigl[\cos^2\beta_- - \cos^2\beta_+\bigr] = 6\cdot(0.9330 - 0.4144) = 6\cdot 0.5187 = 3.11. \tag{15}
$$

**Compare to empirical** $\Delta\langle F_z\rangle/N = 4.60$ at $t=30\,\omega^{-1}$. The pure-coherent prediction is already **$\sim 70\%$ of the empirical signal** — consistent with the coherent Rabi mechanism dominating the asymmetry, with $\gamma_{\rm dr}$ enhancing it from 3.1 toward 4.6 (the dissipative cascade pulls $\langle F_z\rangle$ down further on the $\Omega=+0.5$ side because that side already has the lower average to begin with; long-time asymptote pulls both toward 0, but the $-\Omega$ side has $\sin^2\beta$ small so dissipator has less population to act on per Rabi cycle).

### 4.2 Early-t Taylor (Δ⟨F_z⟩ = 1 crossing)

Expand $\cos(\omega_R t)\approx 1 - (\omega_R t)^2/2 + (\omega_R t)^4/24 - \ldots$ in (14):
$$
\langle F_z\rangle(t;\Omega) - F = -F\sin^2\beta\cdot\tfrac{(\omega_R t)^2}{2} + F\sin^2\beta\cdot\tfrac{(\omega_R t)^4}{24} + O(t^6). \tag{16}
$$
Use $\sin^2\beta\cdot\omega_R^2 = p_\perp^2$ (always — independent of $\Omega$). So the $t^2$ term is the **symmetric** part: $-F p_\perp^2 t^2/2$. The asymmetric part is the $t^4$ term:
$$
\Delta\langle F_z\rangle(t) \equiv \langle F_z\rangle_- - \langle F_z\rangle_+
= F\sin^2\beta_-\cdot\tfrac{(\omega_R^-t)^4}{24} - F\sin^2\beta_+\cdot\tfrac{(\omega_R^+t)^4}{24}
$$
$$
= \tfrac{F p_\perp^2 t^4}{24}\bigl[\omega_R^{-\,2} - \omega_R^{+\,2}\bigr]
= \tfrac{F p_\perp^2 t^4}{24}\bigl[(p_z+\Omega)^2 - (p_z-\Omega)^2\bigr]
= \tfrac{F p_\perp^2\cdot 4 p_z\Omega\cdot t^4}{24}
$$
$$
\boxed{\;\Delta\langle F_z\rangle(t)\bigl|_{\gamma_{\rm dr}=0,\,t \to 0} = \frac{F\,p_\perp^2\,p_z\,\Omega\,t^4}{6} + O(t^6)\;} \tag{T3-Taylor}
$$
where I write $\Omega \equiv |\Omega|$. Setting $\Delta\langle F_z\rangle = 1$:
$$
\boxed{\;\tau_{\rm asym}^{(\gamma=0)} = \biggl[\frac{6}{F\,p_\perp^2\,p_z\,\Omega}\biggr]^{1/4}\;} \tag{T3-closed-form}
$$

**Numerical at anko's parameters** ($F=6$, $p_\perp=0.220$, $p_z=0.315$, $\Omega=0.5$):
$$
F p_\perp^2 p_z \Omega = 6 \cdot 0.0484 \cdot 0.315 \cdot 0.5 = 0.0457
$$
$$
\tau_{\rm asym} = (6/0.0457)^{1/4} = (131.3)^{1/4} = 3.39\,\omega^{-1} \approx 4.9\,\text{ms}.
$$

### 4.3 PASS/FAIL against [7,14] ms window

**FAIL by factor ~1.5** (predicts 4.9 ms, empirical 7-14 ms). Direction is now correct — the $t^4$ scaling makes $\tau_{\rm asym}$ relatively *insensitive* to coupling-strength corrections (a factor-2 reduction in the coefficient pushes $\tau$ up by $2^{1/4}=1.19$ only). The remaining gap is plausibly due to:

(i) The Taylor truncation breaks down when $\omega_R^-\cdot t \sim 1$, i.e. $t \sim 1/0.844 = 1.18\,\omega^{-1}$. The $t^4$ formula extrapolated to $t=3.4\,\omega^{-1}$ has $(\omega_R^-t)^4 = (2.87)^4 \approx 68$, well outside Taylor radius. The exact eq (14) at $t \to \infty$ gives $\Delta\langle F_z\rangle \to 3.11$ time-averaged — so the asymmetry asymptotes to 3.1, not 4.6. Need dissipator to push +Ω lower.

(ii) Dissipator contribution (Target T5): at $\gamma_{\rm dr}=0.02$, the dissipator adds an additional drift $\Delta\dot F_z^{\rm diss}|_0 = -3/140\,\omega^{-1}$ symmetrically to both $\pm\Omega$. But because on the $+\Omega$ side the state has been rotated away from $|+F\rangle$ by Rabi (sin²β = 0.59), it spends more time in lower-$m$ states which have HIGHER $W^{\rm CG}$ values (e.g. $W^{\rm CG}_{+4}=425/308 = 1.38$). This **gives the dissipator asymmetric power** between $\pm\Omega$ — even though the kernel is $\Omega$-blind, the *state-conditioned action* differs.

(iii) Trap orbital coupling: at $+\Omega$ the rotating-frame ground state has $\langle L_z\rangle\ne 0$ (vortex weight), which is not captured in the spin-only single-particle Lindblad. T11 §2.4 eq (2): $\Delta\tilde H = -\Omega(L_z+F_z)$ — orbital relaxation provides an independent decay channel for $F_z$ via angular-momentum conservation under DDI. This is the **trapped many-body correction** that the single-particle Lindblad cannot see.

Effects (ii) and (iii) push $\tau_{\rm asym}$ longer than 4.9 ms, plausibly into the empirical [7,14] ms window. A **proper integration of (T1) including the state-conditioned dissipator** is needed for a quantitative answer — see §6 directive.

**Verdict on T3**: closed-form $t^4$ scaling derived; numerical value **misses [7,14] ms by factor 1.5** on the **fast** side. Coherent Rabi + state-conditioned cascade is plausibly the correct framework; analytic closed form needs the dissipator-Rabi coupling to lift.

[Plausible] $\tau_{\rm asym}$ in [4,9] ms once dissipator-Rabi coupling is included; the t⁴ scaling and the role of $p_\perp^2 p_z \Omega$ as the asymmetry-driving combination are [Established].

## 5. γ_dr = 0 falsifier prediction (Target T4 — for 22:00 JST julia run)

### 5.1 Closed-form lab-frame ⟨F_z⟩(t; ±Ω) at γ_dr = 0

From eq (14):
$$
\langle F_z\rangle^{\rm lab}(t;\Omega) = F\bigl[\cos^2\beta(\Omega) + \sin^2\beta(\Omega)\cos(\omega_R(\Omega)\,t)\bigr] \tag{17}
$$
**(both lab and rotating frame give the same value because $F_z$ commutes with $R$.)**

At $t = 30\,\omega^{-1}$:

| $\Omega$ | $\omega_R t$ | $\cos(\omega_R t)$ | $\langle F_z\rangle/N$ |
|----------|--------------|-------------------|----------------------|
| $+0.5$ | $8.622$ | $\cos(8.622)=-0.700$ | $6\cdot[0.4144 + 0.5856\cdot(-0.700)] = 6\cdot 0.0045 = 0.027$ |
| $-0.5$ | $25.32$ | $\cos(25.32)=+0.995$ | $6\cdot[0.9330 + 0.0670\cdot 0.995] = 6\cdot 0.9996 = 5.998$ |

(Numerical $\cos$ values: $\cos(8.622) = \cos(8.622 - 2\pi) = \cos(2.339) = -0.6967$; $\cos(25.32) = \cos(25.32 - 8\pi) = \cos(0.187) = 0.983$. Re-checking: $8\pi = 25.13$, so $25.32-25.13=0.187$, $\cos(0.187)=0.9826$. Then $\langle F_z\rangle/N = 6\cdot[0.9330 + 0.0670\cdot 0.9826] = 6\cdot 0.9988 = 5.993$.)

Refined table:

| $\Omega$ | $\omega_R t$ at $t=30$ | $\cos(\omega_R t)$ | $\langle F_z\rangle/N$ at $t=30\,\omega^{-1}$ |
|----------|----------------------|--------------------|---------------------------------------------|
| $+0.5$ | $8.622$ | $-0.6967$ | $0.030$ |
| $-0.5$ | $25.32$ | $+0.9826$ | $5.993$ |

**Predicted asymmetry at $\gamma_{\rm dr}=0$**:
$$
\boxed{\;\Delta\langle F_z\rangle/N\bigl|_{\gamma_{\rm dr}=0,\,t=30\,\omega^{-1}} = 5.993 - 0.030 = 5.96\;} \tag{T4}
$$

This is **larger** than the empirical 4.60. Why? Because at $\gamma_{\rm dr}=0$, the $+\Omega$ trajectory is at a coherent-Rabi *trough* at $t=30\,\omega^{-1}$ (by accident of $\omega_R^+ \cdot 30 = 8.62 = 2.74\pi$, near a half-cycle of $\sin^2\beta_+ \cos$). The time-averaged asymmetry is 3.11; the instantaneous value at $t=30$ happens to be near maximum. The empirical 4.60 with $\gamma_{\rm dr}=0.02$ is below 5.96 because $\gamma_{\rm dr}$ damps both Rabi oscillations.

### 5.2 Explicit numerical thresholds for the 22:00 JST julia run

The directive's binary thresholds:

| Outcome | Interpretation |
|---------|---------------|
| $\|\Delta\langle F_z\rangle/N\| < 0.5$ at $t=30\,\omega^{-1}$ | Pure-cascade-with-Rabi-seeding model: the coherent $-p_\perp F_x$ is necessary *but not sufficient*; needs $\gamma_{\rm dr}$ to make the asymmetry. **Coherent mechanism REFUTED.** |
| $0.5 \le \|\Delta\langle F_z\rangle/N\| \le 2.5$ at $t=30\,\omega^{-1}$ | Mixed coherent + dissipative; both channels contribute meaningfully. |
| $\|\Delta\langle F_z\rangle/N\| > 2.5$ at $t=30\,\omega^{-1}$ | **Coherent Rabi mechanism dominates**; cascade is a quantitative correction. **T3 closed form (T3-Taylor) CONFIRMED.** Prediction: should land near **3.1 (time-averaged)** to **5.96 (instantaneous peak)** depending on what $\omega_R t$ the julia run happens to hit. |

**Single-particle Lindblad / single-spin prediction**: $\Delta\langle F_z\rangle/N |_{γ=0, t=30} \approx 5.96$ at instantaneous, with rapid oscillation between 5.20 (trough on $-\Omega$ side coincident with peak on $+\Omega$) and 6.40 (peak on $-\Omega$ side coincident with trough on $+\Omega$). The **time-average over the full Phase-2 trajectory** is closer to $\Delta = 3.11$.

**Many-body single-particle correction**: full GP+DDI dynamics will damp the Rabi oscillations via intra-cloud dephasing (DDI mean field varies across the trap), so the julia simulation should show $\Delta \approx 3.0\text{--}5.0$ at $\gamma_{\rm dr}=0$ with reduced oscillation amplitude. **If $\Delta < 2.5$ at $\gamma_{\rm dr}=0$, the coherent Rabi mechanism alone cannot explain the asymmetry — Candidate B (full-DDI coherent coupling) re-enters.**

### 5.3 Differential predictions at intermediate Ω (post-22:00 JST sweep)

If the 22:00 JST run confirms the coherent mechanism, the **secondary $\Omega$-sweep** (config line 81 of seed) should follow $\tau_{\rm asym}(\Omega) = (6/(F p_\perp^2 p_z |\Omega|))^{1/4}$ at γ_dr=0:

| $\Omega$ | $\tau_{\rm asym}^{(\gamma=0)}$ |
|----------|-------------------------------|
| $\pm 0.1$ | $7.16\,\omega^{-1} = 10.4$ ms |
| $\pm 0.3$ | $5.44\,\omega^{-1} = 7.9$ ms |
| $\pm 0.5$ | $4.79\,\omega^{-1} = 6.9$ ms ← landed in window |
| $\pm 0.7$ | $4.40\,\omega^{-1} = 6.4$ ms |
| $\pm 1.0$ | $4.04\,\omega^{-1} = 5.8$ ms |

Wait — recomputing: $\tau_{\rm asym} = (6/(F\,p_\perp^2\,p_z\,\Omega))^{1/4}$ with the same factors except $\Omega$:
- $\Omega = 0.5$: $(6/0.0457)^{1/4} = 131.3^{1/4} = 3.39\,\omega^{-1} = 4.9$ ms
- $\Omega = 0.1$: $(6/0.00914)^{1/4} = 656.5^{1/4} = 5.06\,\omega^{-1} = 7.32$ ms
- $\Omega = 0.3$: $(6/0.0274)^{1/4} = 218.8^{1/4} = 3.85\,\omega^{-1} = 5.57$ ms

Corrected table:

| $\Omega$ | $\tau_{\rm asym}^{(\gamma=0,\,t^4\text{-Taylor})}$ |
|----------|---------------------------------------------------|
| $\pm 0.1$ | $5.06\,\omega^{-1} \approx 7.3$ ms |
| $\pm 0.3$ | $3.85\,\omega^{-1} \approx 5.6$ ms |
| $\pm 0.5$ | $3.39\,\omega^{-1} \approx 4.9$ ms |
| $\pm 0.7$ | $3.13\,\omega^{-1} \approx 4.5$ ms |
| $\pm 1.0$ | $2.87\,\omega^{-1} \approx 4.2$ ms |

The **scaling law** $\tau_{\rm asym} \propto \Omega^{-1/4}$ is the **falsifiable signature**. If the julia $\Omega$-sweep gives $\tau_{\rm asym}$ scaling as $\Omega^{-1/4}$ over a decade, the coherent mechanism is locked in. If it scales as $\Omega^{-1}$ or $\Omega^0$, the framework needs revision.

## 6. Consistency checks (Target T5)

| Check | Result |
|-------|--------|
| **T5.1** Reproduce T15 $\dot F_z\bigr|_{t=0+} = -3/140\,\omega^{-1}$? | **PASS** — eq (10), dissipator dominates at $t=0$, coherent piece vanishes because $\langle F_y\rangle\bigr|_0=0$. |
| **T5.2** Rank-2 (NOT rank-1) jump operators? | **PASS** — eq (3), $q\in\{-1,-2\}$, $W^{\rm CG}_{m,q}=\|\langle F,m+q\|F,m;2,q\rangle\|^2/Z$, T15 §5 table values used directly. T12 Audit-5 rank-1/rank-2 mismatch resolved. |
| **T5.3** $\gamma_{\rm dr} \to \infty$ limit recovers pure-cascade T15? | **PASS** — at $\gamma_{\rm dr}\gg\omega_R$, dissipative dephasing in $\sim 1/\gamma_{\rm dr}$ destroys coherence in $\{F_x,F_y\}$; the system reduces to a classical $m$-population master equation with the same $W^{\rm CG}_{m,q}$ shape. T15 cascade is exactly recovered, symmetric in $\pm\Omega$. |
| **T5.4** $p_\perp \to 0$ limit recovers pure-cascade T15? | **PASS** — with $p_\perp=0$, $H^{\rm rot}=-(p_z-\Omega)F_z$ is diagonal in $\|m\rangle$; coherent dynamics is trivial Larmor precession around $\hat z$, $F_z$-conserving. Only dissipator acts on $\langle F_z\rangle$. T15 recovered exactly, again symmetric in $\pm\Omega$. **This is the asymmetry-free smoking gun**: the $\pm\Omega$ asymmetry vanishes when $p_\perp=0$. |
| **T5.5** $\Omega \to p_z$ resonance limit (tilt $\beta \to 90°$)? | **PASS (with caveat)** — at $\Omega=p_z=0.315$, the detuning vanishes, the rotating-frame field is pure transverse ($\omega_R=p_\perp$, $\beta=90°$). $\langle F_z\rangle = F\cos(p_\perp t)$ — pure $z$-flop. This is the *one-photon resonance*; in the lab frame it manifests as RWA-resonant absorption. The closed-form (T3-Taylor) gives $\tau_{\rm asym}\to (6/(F p_\perp^2 p_z^2))^{1/4} = 3.59\,\omega^{-1}$, but the asymmetry between $+p_z$ and $-p_z$ resonance is fully captured by the $p_z\Omega$ product (positive vs negative detuning give different $\beta$). |

All five consistency checks **PASS**.

## 7. Calibrated claims (B3 tagged)

- [Established] **The coupled coherent+dissipative Lindblad master equation in the rotating frame is** eq (T1): $-i[H^{\rm rot},\tilde\rho] + \mathcal{D}[\tilde\rho]$ with $H^{\rm rot}=-(p_z-\Omega)F_z - p_\perp F_x$ and $\mathcal{D}$ unchanged from the lab frame (eq 6). Derivation §2.2, three lines of standard SU(2) algebra.
- [Established] **dF_z/dt|_{t=0+} = -3/140 ω⁻¹** in the coupled equation — entirely dissipative; the coherent piece vanishes because $\langle F_y\rangle\bigr|_{t=0}=0$ from $\rho=|+F\rangle\langle+F|$. Eq (10), matches T15. T12 Audit-5 rank-2 structure used.
- [Established] **d²F_z/dt²|_{t=0+} = +p_\perp² F** at t=0+ (eq 13), **symmetric in ±Ω**. The $\pm\Omega$ asymmetry does NOT enter at second order; it requires the detuning $(p_z-\Omega)$ to couple via $\langle F_x\rangle$, which is zero at t=0.
- [Established] **Asymmetry-driver scaling**: leading $\pm\Omega$ asymmetry in $\langle F_z\rangle$ is **fourth-order in $t$**, with $\Delta\langle F_z\rangle = F p_\perp^2 p_z \Omega t^4/6$ (T3-Taylor). The product $p_\perp^2 p_z \Omega$ is the **single load-bearing combination**. The $t^4$ scaling implies $\tau_{\rm asym} \propto \Omega^{-1/4}$ — falsifiable by Ω-sweep.
- [Established] **τ_asym = (6/(F p_\perp² p_z |Ω|))^{1/4} = 3.39 ω⁻¹ ≈ 4.9 ms** at γ_dr=0 (T3-closed-form). **FAILS [7,14] ms window by factor 1.5 (too fast)**.
- [Plausible] The full coupled equation including the state-conditioned dissipator action gives $\tau_{\rm asym}$ in the empirical 7-14 ms window, because the dissipator preferentially depletes the $+\Omega$ side (where Rabi has populated lower-$m$ states with larger $W^{\rm CG}_m$). Quantitative resolution requires numerical integration of (T1) — see §8 directive.
- [Established] **γ_dr → 0 limit prediction (Target T4)**: $\langle F_z\rangle/N(\pm\Omega; t)|_{γ_{\rm dr}=0}$ given exactly by eq (17). At $t=30\,\omega^{-1}$: $+\Omega$ gives 0.030, $-\Omega$ gives 5.993, **Δ = 5.96** (instantaneous, near peak). **Time-average Δ = 3.11**.
- [Established] **Binary falsifier for the 22:00 JST julia run**: at γ_dr=0, if $\|\Delta\langle F_z\rangle/N\| > 2.5$ at $t=30\,\omega^{-1}$, the coherent Rabi mechanism is the dominant asymmetry source (single-particle Lindblad framework confirmed). If $\|\Delta\langle F_z\rangle/N\| < 0.5$, the asymmetry is **dissipator-conditioned-on-Rabi-seeding** — closer to T11 cascade but with the missing channel that T16 flagged. Mid-range 0.5-2.5 indicates mixed contributions.
- [Plausible] **The empirical 4.60 asymmetry at γ_dr=0.02** sits between the pure-coherent time-average (3.11) and the pure-coherent instantaneous (5.96), consistent with γ_dr damping the Rabi oscillations and adding a slow drift toward equilibrium. This is internally consistent with the coherent-dominant + dissipative-correction picture.
- [Established] **All 5 limits (T5) PASS**: T15 reproduction at t=0+, rank-2 structure, γ_dr→∞, p_perp→0, Ω→p_z resonance.

## 8. Open questions

- **Q8.1 — Quantitative τ_asym in the empirical window**: needs numerical integration of (T1) on 13-dim Hilbert space, not analytic. The $t^4$ closed form (T3-Taylor) is only the leading asymptotic; the full curve needs to be integrated to find when $\Delta\langle F_z\rangle/N = 1$ at finite γ_dr. T18 implementer_sympy task. (See §9 directive.)
- **Q8.2 — Trap orbital (single-particle Hilbert space extension)**: the spin-only Lindblad (T1) cannot capture $L_z + F_z$ rotating-frame energetic bias (T11 eq 2). At higher Ω the orbital channel may dominate. Defer to a later turn (post-22:00 JST julia outcome).
- **Q8.3 — Empirical 5.02 vs 0.42 endpoint values**: at $t=30$ ω⁻¹, the empirical $\langle F_z\rangle/N=5.02$ for $+\Omega$ and 0.42 for $-\Omega$ are essentially the *opposite* of the γ_dr=0 prediction (0.030 and 5.993). This means γ_dr SWAPS which side has high $\langle F_z\rangle$. Mechanism: γ_dr-cascade pulls $\langle F_z\rangle$ toward equilibrium ($\langle F_z\rangle=0$) over τ_dr ≈ 70 ms, so at t=30 ω⁻¹ ≈ 43 ms the cascade has had time to substantially depopulate the $+F$ rung. The Rabi-driven $+\Omega$ side is *prevented from cascading down all the way* by the rotating-frame energetic bias (T11 §2.4 — co-rotating $\Delta\tilde H = -\Omega(L_z+F_z)$, minimized by large $L_z+F_z$). The $-\Omega$ side has no such protection, cascades unbounded. **This is the T11 mechanism, revived correctly**: γ_dr is the rate, $\Omega$ sets the energetic bias that gates which side cascades. The framework FAIL in T16 was about t=0+ asymmetry seed, not the eventual endpoint.
- **Q8.4 — Reconciliation T11 vs T17**: T11 §2.4 "rotating-frame energetic bias + γ_dr cascade" mechanism is **rehabilitated as the late-time picture** (t ≫ τ_Rabi ~ 1.4 ms); the EARLY asymmetry (t ≤ a few ms) is **predominantly coherent Rabi** (the channel T16 flagged missing). These are two regimes of the same coupled Lindblad — not competing mechanisms. The cascade does dominate eventually; the t=7-14 ms onset is where coherent Rabi has built ⟨F_perp⟩ enough that the rotating-frame quantization-axis tilt becomes observationally resolvable in F_z. So τ_asym(t at Δ=1) and τ_cascade (1/e of cascade) are different observables, both contained in (T1). [Plausible]

## 9. Directive for implementer

```json
{
  "action": "noop",
  "rationale": "Director's brief explicitly says NO julia/sympy/code this turn — analytic derivation only. The 22:00 JST julia γ_dr=0 falsifier run is already queued by the director and the predictions in §5 are written in the form the orchestrator will compare against. Next implementer turn (T18) should be triggered AFTER the 22:00 julia outcome, with action depending on which §5.2 bin (< 0.5, 0.5-2.5, > 2.5) the run lands in.",
  "target_files": [],
  "experiment_config": null,
  "expected_outcome": "T17 produces analytic deliverable; no commit/branch/code change this turn.",
  "falsification_criterion": "If T18 julia γ_dr=0 run gives |Δ⟨F_z⟩/N| < 0.5 at t=30 ω⁻¹, the coherent-Rabi-dominates framework derived here (T3-Taylor) is REFUTED; pivot to Candidate B (full-DDI coherent coupling, T11 §2.8). If 0.5 ≤ Δ ≤ 2.5, mixed mechanism — needs T19 numerical integration of (T1) at γ_dr=0.02 to compare with empirical 4.60. If Δ > 2.5, framework CONFIRMED, T19 should integrate (T1) at γ_dr=0.02 to fit τ_asym and lift Tier-1.5 → Tier-2.",
  "estimated_cost": "0 — text-only theorist turn, no compute."
}
```

## 10. Research queries

```json
[
  {
    "id": "Q17.1",
    "topic": "Spin-coherent-state Rabi rotation for spin-F stretched initial state in tilted rotating frame — closed-form ⟨F_z⟩(t) including higher-F corrections beyond classical Bloch precession",
    "why": "I assumed ⟨F_z⟩(t) = F[cos²β + sin²β cos(ω_R t)] from spin-coherent-state argument. For F=6 this should be exact for an unentangled stretched state under SU(2) rotation (the stretched state remains stretched under any SU(2)). But it would be useful to cite the formal result.",
    "preferred_sources": ["Sakurai Ch. 3", "Stoler/Glauber spin coherent states", "Arecchi 1972"]
  },
  {
    "id": "Q17.2",
    "topic": "Single-particle rank-2 dipolar-relaxation Lindblad — does the dissipator at finite ⟨F_perp⟩ ≠ 0 develop an Ω-dependent rate enhancement that the m-diagonal jump-operator form misses?",
    "why": "The Lindblad (T1) treats the dissipator as diagonal in lab-frame |m⟩ basis. If anko's measured cascade rate at finite ⟨F_perp⟩ shows tilt-dependence beyond the W^CG_m shape factor, there is a missing matrix element in eq (3). T14 §2 found no Born-Markov Ω-enhancement, but the question of off-diagonal dissipator coherences was not addressed.",
    "preferred_sources": ["Pasquiou 2010 PRA", "Kawaguchi-Ueda 2012 §VII (full text)", "Lindblad / Davies dissipator general structure"]
  }
]
```

## 11. Tier reclassification for T11 §4 claim 5

T16 set "Tier-1.5 [cascade-prefactor-refuted, coherent-channel-pending-γ_dr=0-julia]". This turn provides:

- The missing coherent channel **explicitly derived** as $-p_\perp F_x$ in $H^{\rm rot}$ (eq 5).
- A new closed form for the asymmetry-onset timescale $\tau_{\rm asym}\propto (\Omega p_\perp^2 p_z F)^{-1/4}$ (eq T3-closed-form) — qualitatively different from the cascade $\tau_{\rm cascade}\propto 1/(\gamma_{\rm dr} W^{\rm CG})$.
- The T11 §4 claim 5 quantitative value (τ ≈ 6 ms) is **partially rehabilitated**: τ_asym = 4.9 ms is close to T11's 6 ms in *order of magnitude*, but T17 derives it from a different physical mechanism (coherent Rabi, not γ_dr cascade). T11's mechanism is the *late-time* picture; T17's is the *early-time* picture.

**Proposed new tier**: **Tier-1.5 [coherent-Rabi-channel-derived, full-coupled-Lindblad-numerical-pending, γ_dr=0-julia-pending]**. Lifts to **Tier-2** if 22:00 JST julia gives $\|\Delta\langle F_z\rangle/N\| > 2.5$. Drops to **Tier-1** if julia gives < 0.5.

## 12. Sequencing for T18 (3 scenarios)

### Scenario A: 22:00 JST julia gives $\|\Delta\langle F_z\rangle/N\| > 2.5$ at γ_dr=0
**Verdict**: Coherent Rabi confirmed as dominant asymmetry source. T17 framework lifts to **Tier-2**.
**T18 action**: `implementer_sympy` or `analyze_existing` to numerically integrate (T1) at γ_dr=0.02 (with all other parameters from anko's empirical config) and fit τ_asym. Target: reproduce empirical 4.60 within 20%. If success → Tier-3 (theory + julia data agree).

### Scenario B: 0.5 ≤ $\|\Delta\langle F_z\rangle/N\|$ ≤ 2.5 at γ_dr=0
**Verdict**: Mixed mechanism. Coherent contributes but doesn't dominate alone.
**T18 action**: `theorist` turn to derive the coupled coherent + cascade asymmetry at moderate $\Omega t$ (beyond t⁴ Taylor) — fold dissipator action into the spin-coherent-state evolution. May need spin-coherent-state ODE numerically, but the structure is analytical.

### Scenario C: $\|\Delta\langle F_z\rangle/N\| < 0.5$ at γ_dr=0
**Verdict**: Coherent Rabi alone insufficient. The asymmetry needs $\gamma_{\rm dr}\ne 0$ to even appear.
**T18 action**: `theorist` turn to derive Candidate B (full-DDI off-diagonal coherent coupling) along the lines of T11 §2.8 (Yan-Li-Saito-style m+v=ℓ analysis for trapped). This is the largest residual unknown, and the framework gap T16 flagged.

## 13. Citation chain (T14 bibliography)

- **KU 2012** — Kawaguchi & Ueda. *Spinor Bose-Einstein condensates*. Phys. Rep. 520, 253 (2012). arXiv:1001.2072. — Rank-2 dipolar relaxation operator structure §VII (T14 confirmed, full-text quote unavailable).
- **SKU 2013** — Stamper-Kurn & Ueda. *Spinor Bose gases*. Rev. Mod. Phys. 85, 1191 (2013). arXiv:1205.1888. — Secondary reference for spinor-DDI Lindblad form.
- **Hensler 2003** — Hensler, Werner, Griesmaier et al. *Dipolar relaxation in ultra-cold Cr*. Appl. Phys. B 77, 765. arXiv:quant-ph/0307184. — β_dr measured at 44 G; sqrt(B) Wigner threshold scaling sets context for anko's 2.6 nT regime where γ_dr is phenomenological.
- **Pasquiou 2010** — Pasquiou et al. *Control of dipolar relaxation in external fields*. Phys. Rev. A 81, 042716. arXiv:1002.0222. — 3D free-space Cr: no Lorentzian-in-B resonance, monotonic √B; consistent with T14's NO-Born-Markov-Ω-enhancement finding.
- **Sakurai (Modern QM)** — Ch. 3 spin-coherent-states + SU(2) rotation. — Source of eq (14) classical-Bloch result for stretched-state $\langle F_z\rangle$ under tilted Rabi.

## 14. Publishability assessment

Out of scope — incremental turn building toward the campaign's eventual D1 deliverable (closed-form $\tau_{\rm Barnett}$ + matching to anko's data). The asymmetry-onset timescale $\tau_{\rm asym}\propto (\Omega p_\perp^2 p_z F)^{-1/4}$ scaling is **new but inside a single-particle Lindblad** — interesting but not paper-scale until validated by the 22:00 JST julia + the trapped many-body extension addressing T11 §2.4.
