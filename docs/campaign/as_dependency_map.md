# What the $a_S$ measurement unblocks, and what it does not

¹⁵¹Eu's advantage is that its channel-resolved scattering lengths $a_S$ are
*determinable* — $L=0$ (⁸S₇/₂) keeps the Feshbach spectrum from going chaotic the
way Dy's and Er's do, so the Cr programme applies. Taking that spectrum is the
apparatus's job; this file is the repository's half, **which claims change when
those numbers arrive and which cannot**. Written for #342, which asked for one
table: §3 is the table, and everything around it is the input state the table
needs and the boundary it cannot see past.

The one-line answer is that the boundary is exact rather than a matter of degree.
Everything a **fully spin-polarized** Eu cloud does is already fixed by the one
measured channel; everything that depends on the spinor's *shape* is open. In the
excitation ladder above a polarized condensate the boundary sits between
$m = -F+1$ and $m = -F+2$.

## 1. The input state: one channel measured, six not

| | |
|---|---|
| measured | $a_{12} = 110(4)\,a_B$ — the **stretched** ($S = 2F$) channel |
| unmeasured | $S = 0, 2, 4, 6, 8, 10$ — **six** channels, with no measurement and no theoretical value to quote |
| in this tree | `Eu151.a_s = 110 a₀` (`src/workflow/initialization/atoms.jl:216`), a single scalar; the $\pm 4\,a_B$ is **not carried anywhere in code** |

Matsui et al. state the situation in their own words — "only one parameter is
experimentally known … $a_{12} = 110\,a_B$", harvested with the quote in
`docs/validation/matsui_experiment_parameters.md:22`.

The repository's constraint **is** that statement rather than a modelling choice.
From `_c0c1_to_gS` (`src/hamiltonian/coefficients.jl`) the channel couplings are
$g_S = c_0 + c_1\lambda_S$ with $\lambda_S = [S(S+1) - 2F(F+1)]/2$, and at
$S = 2F$ that weight is $\lambda_{2F} = F^2 = 36$, so the line everyone writes as
$c_0 + 36c_1 = c_\text{total}$ says

$$g_{12} = c_0 + 36c_1 = c_\text{total} = 4\pi\,\frac{a_{12}}{a_{ho}}N .$$

Holding $c_\text{total}$ fixed and sweeping `c1_ratio` $= r$ is therefore exactly
"hold the measured channel, vary the unmeasured ones", which is what makes $r$ a
usable proxy for the ignorance — and what limits it, in three ways that all bear
on how §3 should be read.

**$r$ is a line through a six-dimensional ignorance.** The $c_0/c_1$ truncation
has one free parameter and the real unknown has six, so every sensitivity below
measured against $r$ is a **lower bound** on the true $a_S$ sensitivity. The
general parameterisation is the channel basis directly,
`_make_tensor_cache_from_channels(F, Dict(S => g_S))`, or rank-keyed higher
channels via `interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)`.

**$r = 1/36$ is not a measurement.** It is Matsui's paper value, and their own
shipped code used $1/3600$ (`docs/validation/matsui_campaign_report.md` §2). The
production config comments `0.0277777778` as "physical Eu (1/36, AFM)"
(`runs/eu_gs_phase_c1_B_kappa/config.yaml:42`); read that as an assumption.

**One empirical bound on $r$ already exists here, and it is discrete.** The 5 ms
ring count in $m = -4$ against Matsui's Fig. 1E gives $0.0139 < r \le 0.0278$
with "no upper bound below $r = 1.0$", resolution-independent across 32³/64³/128³
(campaign report §3). It rejected their shipped $1/3600$ in a single run, while
twenty-four continuous-observable arms decided nothing.

### The normaliser: what the known input's own error bar does

Sensitivity to the unknown means nothing until the *known* input's uncertainty is
on the table, so every figure in §3 is quoted in units of the change that
$a_{12}$'s own $\pm 4\,a_B$ produces on the **same** observable. At
$N = 5\times10^4$ and $\bar\omega = 2\pi\cdot 116$ Hz (the Matsui round trap), that
$3.64\,\%$ propagates to

| quantity | move under $a_{12} \pm 1\sigma$ |
|---|---|
| $c_\text{total} = g_{12}$ | 3.64 % (linear) |
| Bogoliubov frequencies | **1.77 %** (measured; $\omega \propto \sqrt{g}$) |
| $\varepsilon_\text{LHY}$ | 9.1 % (since $\varepsilon \propto g^{5/2}$) |
| elastic cross-section $8\pi a_{12}^2$ | 7.3 % |

Anything the unmeasured channels move by less than one such unit is not worth
measuring them for, because the input already in hand is the limit.

## 2. The exact boundary, and why it is exact

Two bosons in the stretched pair $|-F,-F\rangle$ carry $M = -2F$, and the only
**symmetric** two-body channel with that $M$ is $S = 2F$; one magnon on top,
$|-F,-F+1\rangle$ with $M = -2F+1$, spans a one-dimensional symmetric subspace
that is again pure $S = 2F$. From $m = -F+2$ upward a second channel opens and the
ignorance enters. Nothing about this is perturbative or truncation-dependent — it
is which channels exist.

Measured through the code at Eu $F=6$, holding $c_\text{total}$ and sweeping
$r \in \{0,\ 1/36,\ -1/72\}$ through `_bdg_contact_matrices`, which reads the same
$g_S$ the propagator does:

| object | value | under the sweep |
|---|---|---|
| contact energy, uniform stretched cloud | $\tfrac12 g_{12} n^2$ | `2.641950484596349e-02` at $r = 0,\ 1/36,\ 0.05$ — all sixteen digits |
| $h_{-6,-6}$, the condensate | $g_{12} = 4813.4036$ | invariant to $10^{-12}$ |
| $h_{-5,-5}$, the first magnon | $g_{12}/2 = 2406.7018$ | invariant to $10^{-12}$ |
| anomalous matrix | **exactly one** non-zero element, $M_{-6,-6} = g_{12}$ | invariant |
| $h_{-4,-4}$ | 2406.70 | $\to$ 2005.58 at $r=1/36$, $\to$ 3208.94 at $r=-1/72$: **4.6 and 9.2 normalised units** |
| phonon branch $\omega(k)$ | — | moves by $3.6\times10^{-15}$, against $1.77\times10^{-2}$ from $a_{12}$'s own $1\sigma$ |

`test/oracles/test_stretched_channel_invariance.jl` gates all of it, at $F=2$ as
well as $F=6$, and every invariance in it is paired with a control that moves —
an invariance whose knob does nothing anywhere is the degenerate-knob null this
repository has already published once.

The LHY closures split along the same line. $\varepsilon_\text{LHY}^\text{FM} =
(8/15\pi^2)(g_{2F}n)^{5/2}$ reads the measured channel and nothing else, giving
`5.488550501e+01` at both $r = 0$ and $r = 1/36$ to ten digits, while the polar
and icosahedral closed forms read the whole vector and fall by **73 %** and
**77 %** over those same two points — 8.0 and 8.5 normalised units. The separate
question of whether `full_bdg`'s $\varepsilon_\text{LHY}$ is scheme-dependent for
Eu textures (`docs/validation/full_bdg_scheme_dependence_eu_f6.md`) is a
different axis and is not touched by any of this.

## 3. The table

Live means a claim that the current documents, figures, registries or campaign
cite. The enumerable sources are `test/validation/test_type_c_claims.jl` (twelve
published comparisons, held by a ratchet), the figure registry in
`src/manuscript/figures.jl`, and `docs/campaign/CAMPAIGN.md` §11. The 392 uncited
stored summaries are deliberately not classified — per
`docs/validation/stored_results_vintage_audit.md` a stored claim costs a
re-derivation to place, so only what something cites is worth placing.

Sensitivity is two points, normalised as in §1; "recompute?" asks whether the
number changes when the six channels arrive.

| claim | where | inputs it consumes | sensitivity to the unmeasured channels | recompute? |
|---|---|---|---|---|
| $a_{dd}(\text{Er166}) = 65.5a_0$, $a_{dd}(\text{Dy164}) = 130.8a_0$ | type-C registry | $\mu$, $m$ | **0, structurally** — no interaction argument exists | **N** |
| supersolid is the ground state at $\varepsilon_{dd}=1.45$ and not at 1.30 | type-C registry, Roccuzzo 2019 | scalar $a_s$, $\varepsilon_{dd}$, geometry | **0** — spinless, so no channel structure exists | **N** |
| SPGPE reservoir coefficients $(\bar\gamma, \bar{\mathcal M})$ | type-C registry, Rooney 2012 | $(\mu, T, \epsilon_\text{cut})$ | **0** | **N** |
| Eu evaporation: $U/k_B = 350\,\mu$K, $n_0 = 3.3\times10^{13}$ cm⁻³, PSD $= 2.7\times10^{-4}$ | type-C registry, Miyazawa 2021 | polarized $\sigma_\text{el} = 8\pi a_{12}^2$, trap | **0** — a polarized gas scatters only in $S=2F$; the $\pm4a_B$ contributes 7.3 % and dominates | **N** |
| Eu condensation temperature $T_c \approx 410$ nK | type-C registry | ideal gas, finite size, mean-field shift | **0** | **N** |
| Klaus 2022 magnetostirring and vortex nucleation | type-C registry | Dy164, polarized dipolar | **0** | **N** |
| $q/h = 1.42$ kHz/G²; the ¹⁵³Eu factor-2.3 prediction | CAMPAIGN §11, #341 | $g_J$, $a_\text{hf}$, Breit-Rabi | **0, structurally** — `compute_quadratic_zeeman` takes no interaction argument, asserted on the method signature rather than by running it twice and finding two equal numbers | **N** |
| $\varepsilon_{dd} = 0.5402$, $a_{dd} = 59a_0$ | CAMPAIGN §11 | $\mu$, $a_{12}$ | **0** — built from the measured channel; 3.6 % from its own $1\sigma$ | **N** |
| Matsui Fig. 4B dip **width**, 12.740 vs 12.752 nT (0.10 %) | campaign report §1 | $c_1$, $N$, $q$, field axis | **bounded and small**: worse in *both* directions across a factor 8 in $r$, and the axis carries a $\pm10$ nT systematic, 250× the residual | **N** |
| Matsui Fig. 4B dip **centre** | campaign report §1 | as above | not a measurement at all — the $\pm10$ nT offset moves it | **N**, unquotable either way |
| $c_1/c_0$ itself: $0.0139 < r \le 0.0278$ | campaign report §3 | $m=-4$ ring count at 5 ms | this row **is** the constraint, and $a_S$ supersedes it | **Y** |
| $K_3 = 2.6\times10^{-28}$ cm⁶/s for $m \ne -6$ | campaign report §3 | total-number decay | **unmeasured** — the fit was made at fixed $r$ and no two-point in $r$ exists | **Y**, re-fit |
| Yan–Li–Saito Barnett: no self-bound droplet at the physical $\varepsilon_{dd} = 0.5402$, at any atom number | `runs/yls_barnett_f6/README.md` Q1 | $\varepsilon_{dd}$ alone (a theorem, confirmed by eGPE) | **0** — a negative result resting on the measured channel, and the strongest quotable Eu statement in the tree | **N** |
| F=6 critical number is $1.559\times$ the F=1 value at every $\varepsilon_{dd}$ | `runs/yls_barnett_f6/README.md` Q2 | spin algebra: $\langle S_z^2\rangle = F/2$ enters one term | **0** | **N** |
| paper1 FIG-1/2 and paper2 FIG-1/2: Majorana configurations, BdG block structure | figure registry, `analytical` / `symbolic` | representation theory | **0** — the decomposition follows from $H \subset SO(3)$, not from $g_S$ | **N** |
| paper3 Sign-Pattern Lemma 1 and the Universal Theorem | figure registry FIG-2/3 | $\beta_S$ as a *function* of $g_S$ | **0 as a theorem**; its Eu instantiation is a different claim | **N** / **Y** |
| paper2 FIG-3: ¹⁵¹Eu LHY-to-mean-field ratio vs trap $\omega$ | figure registry | all $g_S$, plus the state ansatz | **8.5 units** for the icosahedral closed form, 77 % over two points; only an FM arm is invariant | **Y** |
| F=6 phase diagram and polyhedral selection; "Eu sits on the FM–cyclic–$I_h$ triple junction" | CAMPAIGN §11, paper2 | the **channel spread itself** | maximal — at uniform $g_S$ the $\sigma_S$ sum rule makes polar, FM, cyclic and $I_h$ exactly degenerate, so the unknown is not a parameter of this claim, it **is** the claim | **Y** |
| #335 hysteresis: falling-leg occupied-$m_F$ count 6–7 vs 3–4 | project verdict | $\kappa = \omega_z/\omega_r$, $B$, $c_1$ | the $\kappa$ and $B$ axes are invariant, the $c_1$ axis is not; being a count, it survives calibration error | **Y** on the $c_1$ axis |
| `full_bdg` $\varepsilon_\text{LHY}$ scheme dependence for Eu F=6 | `full_bdg_scheme_dependence_eu_f6.md` | all $g_S$, and the scheme | **unmeasured in $r$** — those arms varied the scheme, not the channels | **Y** |
| paper4 FIG-2/3: $\sigma/\mu$ vs $N$, species universality | figure registry | truncated Wigner, $\varepsilon_{dd}$, spinor | **unmeasured** — no two-point exists, so do not read it as zero | **Y** until measured |

Three rows say *unmeasured* instead of a number, which is the honest entry:
absent is missing, never a default.

## 4. Observables invariant to $a_S$ — what can be taken now

Discrete observables come first, because a count carries no error bar and no
calibration, and the one instrument that decided anything in the Matsui campaign
was a ring count.

Everything about a **fully stretched cloud** is in this class by §2: the
Thomas–Fermi profile, peak density, sound speed, the phonon and roton spectrum,
the critical velocity, droplet and supersolid thresholds, self-binding, and
$\varepsilon_\text{LHY}$ through the FM closed form. So is the **first magnon
branch** at $m = -F+1$, exactly. So are vortex number, winding number and the
presence or absence of a *density* symmetry — stripe, droplet lattice — in a
polarized dipolar cloud, which depend on geometry and $\varepsilon_{dd}$ only.
(Spin order parameters such as $Q_6$ are not in this class: on a stretched cloud
they are trivial, and everywhere else they read the channel spread.) So are the
**evaporation and thermodynamics** of
a polarized gas, which enter through $\sigma_\text{el} = 8\pi a_{12}^2$; and
$p$, $q$, $g_F$, $\mu$, $a_{dd}$, $\varepsilon_{dd}$ together with every
isotope-shift prediction built from $a_\text{hf}$ (#341). Finally the
representation-theoretic structure — Majorana configurations of the inert states,
the mod-5 BdG block decomposition at $F=6$, the sign-pattern theorems — is
invariant because it never reads $g_S$ at all.

The $m = -4$ ring count is the interesting exception: it is discrete and
resolution-independent, and it is *not* invariant, which is precisely why it is
the sharpest instrument here. Anything not in this section needs $r$ stated
alongside the result, and $r$ is an assumption.

## 5. The reverse direction, and an instrument for the measurement

Arriving with the channels: the $F=6$ phase diagram, where mean field cannot
select the phase at uniform $g_S$ because the selection *is* the spread; the
polar, icosahedral and spatial LHY numbers; the $K_3$ fit at $m \ne -6$; #335's
$c_1$ axis; and the whole type-C programme against spin-resolved Eu data.

The tree also already predicts how the channels could be read off one at a time.
Feeding the code unit channel vectors gives the map from $g_S$ to the Hartree
shift of an $m$-magnon on a stretched condensate, $h_{mm} = \sum_S A_{m,S}\,g_S$:

| $m$ | channels entering | coefficient of the newest channel | 10 % of $g_{12}$ in that channel moves the line by |
|---|---|---|---|
| $-6$ | $S=12$ | 1.0000 | — (this is the condensate) |
| $-5$ | $S=12$ | 0.5000 | — |
| $-4$ | $+\,S=10$ | 0.2609 | **96.5 Hz** |
| $-2$ | $+\,S=8$ | 0.0827 | 30.6 Hz |
| $0$ | $+\,S=6$ | 0.0341 | 12.6 Hz |
| $+2$ | $+\,S=4$ | 0.0204 | 7.5 Hz |
| $+4$ | $+\,S=2$ | 0.0220 | 8.1 Hz |
| $+6$ | $+\,S=0$ | 0.0769 | 28.5 Hz |

at peak density, where $n_0 g_{12} = 15.95\,\hbar\omega_\text{ref} = 1850$ Hz. Two
structural facts make this sharp. The map is **triangular**, admitting one new
channel every two rungs, so it inverts from the bottom: taking all seven rows at
once has $\text{cond} = 3.9\times10^4$, taking them in order does not. And the
**background is exactly zero**, because at uniform $g_S$ every row sums to
$\tfrac12$, so the radio-frequency ladder is exactly the Zeeman ladder and any
deviation from it *is* the channel spread — the same $\sigma_S$ sum rule that
produces the phase degeneracy in CAMPAIGN §11, reappearing in the magnon sector.

This is type B, derived here and not validated against an experiment. It is
zero-temperature and quoted at peak density, so a trapped cloud averages it
($\langle n\rangle = \tfrac47 n_0$ for a Thomas–Fermi profile, a factor $0.57$),
and a real proposal needs a local-density treatment and finite-temperature line
shapes. The invariant rungs are reproducible from
`test/oracles/test_stretched_channel_invariance.jl`; the coefficient table comes
from `_bdg_normal_matrix` under unit channel vectors.

## 6. What this table does not cover

Every sensitivity here is measured along `c1_ratio`, so the six-dimensional
ignorance is only sampled along a line and two channel vectors with the same $r$
are not the same physics. The 392 uncited stored summaries are outside scope by
choice. Invariance to $a_S$ is also only one axis of trust: a row marked **N**
here can still be disqualified by the fix-list ancestry gate in CAMPAIGN §2.

One consequence is worth stating in its own right, because it changes what a live
config's outputs mean. `runs/eu_gs_phase_c1_B_kappa/config.yaml:72-75` scans
$r \in \{-0.015,\ 0,\ +0.0278\}$, and the ring-count bound in §1 excludes the
first two for the physical atom. That is the right design for exploring an
unknown — it is a sensitivity study over $r$, not a set of Eu predictions, and its
outputs should not be quoted as if it were.
