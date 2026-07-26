# ¹⁵¹Eu finite-temperature trap-shape optimization

The definitive, finite-temperature version of the $T=0$ trap-shape study
(`eu_shape_optimization.md`). At $T>0$ the shape optimum is governed by a
competition the $T=0$ Gross–Pitaevskii picture cannot see, so we evolve the
**Stoof-form (full-Hamiltonian) Stochastic Projected Gross–Pitaevskii equation**.

Driver: `docs/guides/figures/eu_shape_finite_t.jl`. Runs on TSUBAME H100 via
`scripts/eu_shape/submit_finite_t.sh` (modes `probe | campaign | equilibrium | kcut | shape`).

## Physics

Three-body loss favours expansion (lower density $\Rightarrow$ less loss,
$\langle n^2\rangle\propto\bar\omega^{12/5}$). At finite $T$ the counter-force is
the condensate itself: $T_c\propto\hbar\bar\omega N^{1/3}$ drops as the trap
loosens, so at fixed $T$ the condensate melts. The resolution — and the reason
expansion still wins — is adiabaticity: an adiabatic expansion cools the gas
($T\propto\bar\omega$) in step with $T_c\propto\bar\omega$, so $T/T_c$ is
**preserved** and the condensate survives while the density (and loss) fall.

Model: a single stretched $|m=-6\rangle$ component (scalar-equivalent), physical
$K_3$ loss, and the SGPE dissipative + thermal sub-step
$\psi\leftarrow\psi-\gamma(\hat H[\psi]-\mu)\psi\,dt + \sqrt{2\gamma T\,dt/dV}\,\xi$,
which relaxes toward the interacting thermal state at $(\mu,T)$.

## Two normalization/physics points that must be right

**Norm-N.** The FDR noise amplitude $\sigma=\sqrt{2\gamma T\,dt/dV}$ assumes
$|\psi|^2$ is the *physical* density ($\int|\psi|^2=N$). The $T=0$ driver uses
norm-1 ($\int|\psi|^2=1$, with $N$ folded into $c_0=\tilde g N$); running the SGPE
there makes the noise $\sqrt N$ too large and the thermal cloud $\sim N\times$ too
heavy. The finite-T driver therefore runs **norm-N**: seed $\psi_N=\sqrt N\,\psi_1$
and use the bare couplings $c_0=\tilde g$, $K_3=\tilde K_3$. The mean field
$\tilde g|\psi_N|^2=\tilde g N|\psi_1|^2$ and the loss $n=|\psi_N|^2$ are then both
correct, and $\int|\psi|^2$ is the physical atom number.

**Closed-system ramp.** A fixed-$\mu$ Stoof bath is grand-canonical: when the trap
loosens, the GP fixed point at that $\mu$ holds more atoms, so the bath *pumps*
the condensate — unphysical for an atom-survival question. So the bath ($\gamma$,
noise) runs only during the **preparation** phase; the shape ramp is evolved as a
**closed system** ($\gamma=0$, loss on), where the gas cools adiabatically as it
expands.

**Condensate measure (bias-corrected).** The raw coherent estimator
$\int|\langle\psi\rangle|^2$ over-counts by the residual thermal variance $/M$
($M$ trajectories): $E[|\langle\psi\rangle|^2]=\phi^2+n_{th}/M$, so it depends on
$M$ (uncorrected: $M{=}3\to10260$, $M{=}8\to8035$ at $T/T_c{=}0.5$ — a fake 28 %
"physics"). The Penrose–Onsager-consistent correction
$n_c=|\langle\psi\rangle|^2-(\langle|\psi|^2\rangle-|\langle\psi\rangle|^2)/(M-1)$
subtracts it, making $N_0=\int n_c\,dV$ unbiased and $M$-independent ($M{=}3\to6448$,
$M{=}8\to6401$).

**Classical-field cutoff.** The noise populates every mode, so a projection at
$k_\mathrm{cut}$ with $\varepsilon(k_\mathrm{cut})-\mu\approx T$ (i.e.
$k_\mathrm{cut}=\sqrt{2(\mu+T)}$) defines the classical region; the grid must
resolve it ($k_\mathrm{max}=\pi/dx>k_\mathrm{cut}$, hence $\ge 48^3$).

**Single-component / $D$.** All atoms sit in the stretched state with $c_1=0$, so
the spin matrices never enter and any $F$ gives identical physics — only $D=2F+1$
(cost) changes. The runs use $F=1$ ($D=3$), $4.3\times$ cheaper than Eu's $D=13$;
the Eu units live in the explicit $c_0,K_3$.

## Validation (falsifiable, not hand-waved)

| Check | What | Result |
|---|---|---|
| **V-FDR** | Rayleigh–Jeans $\langle|\hat\psi(k)|^2\rangle=T/(\tfrac12k^2-\mu)$ | existing `test_sgpe_fdr.jl` ✓ |
| **V-Stoof** | $T\to0$ → interacting GP ground state | existing `test_sgpe_stoof.jl` ✓ |
| **V-T0** | $N_0/N\to1$ as $T\to0$ | $0.95$ at $T/T_c{=}0.1$ ✓ |
| **V-mono** | condensate $N_0$ melts monotonically | $9502\to3100$ over $T/T_c{=}0.1\!\to\!0.9$ ✓ |
| **estimator** | $N_0$ independent of trajectory count $M$ | $M{=}3\to6448$, $M{=}8\to6401$ ✓ |

**Honest cutoff limitation (not hand-waved).** The classical field IS
cutoff-dependent. Over $k_\mathrm{cut}\in[4.6,8.0]$ the thermal cloud spreads
$\sim79\%$ while the condensate $N_0$ moves $\sim30\%$: $N_0$ is the *more robust*
of the two but NOT cutoff-free. So absolute $N_0$ is quoted at the physical cutoff
$\varepsilon-\mu\approx T$, and only comparisons at FIXED $k_\mathrm{cut}$ (the
shape result) are cutoff-clean. The ideal-Bose $1-(T/T_c)^3$ is drawn only for
orientation — the classical (Rayleigh–Jeans) thermal over-populates, so $N_0/N$
sits below it; it is not a fit.

## Equilibrium is analytic; the SGPE is for the dynamics

A key clarification (`eu_ft_equilibrium_analytic.png`, `ft_equilibrium_analytic`,
NO simulation): the fixed-$N$ equilibrium is fixed by the atom + trap + $N$
properties, because the *quantum* thermal cloud is **bounded**,
$N_{th}=\zeta(3)(k_BT/\hbar\bar\omega)^3=N(T/T_c)^3$, giving $N_0=N[1-(T/T_c)^3]$ and a
chemical potential pinned by the condensate,
$\mu(T)=\mu_\mathrm{GP}(N_0/N)^{2/5}$, $\mu_\mathrm{GP}=\tfrac12\hbar\bar\omega(15N
a_s/a_\mathrm{ho})^{2/5}=11.76\,\hbar\omega_\mathrm{ref}$ (matching the numerical GS
$11.93$). The classical-field SGPE, by contrast, over-populates the thermal cloud
(Rayleigh–Jeans: each classical mode carries $\sim k_BT$), so at fixed $\mu$ its
total atom number grows with $T$ and its $N_0/N$ sits below the physical curve — a
method artefact, not physics. **So the equilibrium $\mu(T)$, $T_c$, and condensate
fraction are taken analytically; the SGPE earns its keep only in the DYNAMICS
(shape ramp, breathing, sudden-quench dephasing) that no closed form can give.**

## SGPE dynamics results (48³, $D{=}3$, TSUBAME H100)

**Equilibrium cross-check** (`eu_ft_equilibrium.png`): the (classical-field) SGPE
condensate $N_0$ melts $9502\to3100$ across $T/T_c=0.1\to0.9$ and $N_0/N\to0.95$ as
$T\to0$ — the right qualitative melting, below the analytic curve as expected.

**Cutoff sensitivity** (`eu_ft_kcut.png`): $N_0$ spread $30\%$ vs thermal $79\%$
over the $k_\mathrm{cut}$ range — the condensate is the robust observable.

**Shape trade-off** (`eu_ft_shape.png`, prep SGPE at $T/T_c=0.5$ → closed ramp +
$K_3$, all at fixed $k_\mathrm{cut}$, four protocols):

| protocol | final $N_0$ | final total $N$ |
|---|---|---|
| HOLD (tight) | 7653 | 19050 |
| DECOMPRESS ($\omega:1\to\tfrac12$) | **8171** | 19340 |
| BOX — sudden release | 1152 | **19690** |
| BOX — adiabatic morph | 7898 | 19390 |

Total-atom loss follows density (BOX $<$ DECOMPRESS $<$ HOLD — the density lever
works). For the *condensate*, **adiabaticity dominates**: a **sudden** box release
cuts total loss the most yet **shatters the BEC** ($N_0\!\to\!1152$; violent
post-quench breathing dephases the coherent field), whereas the **adiabatic** box
morph ($V=(1{-}s)V_\mathrm{harm}+sV_\mathrm{box}$) **preserves it** ($7898$, above
HOLD). Gradual decompression is the robust winner. The finite-$T$ lesson refines
the $T=0$ levers: the expansion must be **adiabatic** — the dynamical confirmation
of "adiabatic expansion preserves $T/T_c$" from the theory note.

### 0-D reservoir calibration — grounding in the real experiment

The evaporative cooling (seconds) is quasi-static relative to the SGPE dynamics
(ms), so the 0-D two-component model supplies the physically-calibrated
$(\bar\omega, N, T/T_c)$ at BEC formation rather than ad-hoc values
(`ft_reservoir_calibration`, via `run_evaporation`+`bec_handoff` on the researched
euv3 ramp): **BEC onset at $\bar\omega=2\pi\cdot284$ Hz, $N_\mathrm{BEC}=6.6\times10^4$,
$T/T_c=1.00$** (matching the measured $\sim5\times10^4$). Running the shape study at
those calibrated units (`eu_ft_shape_cal.png`, $64^3$, $N=6.6\times10^4$,
$T/T_c=0.6$) reproduces the same ordering — **decompress $>$ hold $>$ box(adiabatic)
$>$ box(sudden)** for the condensate, sudden-box worst — confirming the conclusion
at the real Eu formation conditions, not just the model point. The box's uniform-
density (total-loss) advantage does not convert into a condensate gain here; a
larger / slower box is the remaining lever to probe.

## Harmonic decompression recipe (no box — the experimentally usable lever)

With no box trap available, the deliverable is the best **harmonic** protocol:
lower the ODT power. `ft_decompress_optimize` sweeps $(\omega_\mathrm{final},\tau)$
of the closed-system decompression at the 0-D-calibrated formation conditions
($\bar\omega=2\pi\cdot284$ Hz, $N=6.6\times10^4$, $T/T_c=0.5$, $34$ ms window);
`eu_ft_decompress_opt.png` is the $N_0$ heatmap (colour $=N_0/N_0^\mathrm{hold}$,
$N_0^\mathrm{hold}=44656$).

Two clean features:
- **Faster is better** ($\tau=0$ wins every row): unlike the box, a harmonic→weaker-
  harmonic quench is mild (the ground state stays a parabola), so a sudden
  decompression reaches low density fastest without shattering the BEC. The gentler
  $\tau\approx7$ ms is within a few % and avoids exciting a breathing mode — the
  practical choice.
- **Interior optimum in $\omega_\mathrm{final}$**: the refined sweep at $\tau=0$
  (`eu_ft_decompress_refine.png`) pins a broad peak at
  $\omega_\mathrm{final}\approx0.55$–$0.60$ — **optimum $0.60$, $N_0=51689$, $+15.9\%$
  over HOLD** ($44612$). Loosening cuts three-body loss, but over-loosening drops
  $T_c\propto\bar\omega$ and melts the condensate; the finite-$T$ trade-off, pinned.

## Optimizing the evaporation ramp too (0-D, before the decompression)

The FORT power schedule that forms the BEC is itself optimizable
(`ft_evap_ramp_optimize`, `eu_ft_evap_ramp.png`): a Bayesian search over the
researched euv3 ramp (duration / final-power / time-warp transform), with the bounds
widened, lifts the condensate at BEC onset from $N_\mathrm{BEC}=6.56\times10^4$ to
$8.69\times10^4$ (**$+32.4\%$**, interior optimum $[0.56,0.19,0.71]$), reaching BEC
faster ($t_\mathrm{BEC}$ $1.70\to1.05$ s) via a steeper ramp.

**Parameter landscapes** (`eu_ft_evap_scan.png`) show what is really going on:
- **duration is monotone** — shorter/faster is always better ($N_\mathrm{BEC}$ rises
  to $\sim9.3\times10^4$, $+42\%$, at the shortest duration that still reaches BEC,
  $\approx0.39$), because a faster ramp spends less time bleeding to three-body loss.
  The only hard limit is BEC-reachability (too fast → no condensation). This is a
  knife-edge, and it is exactly where the 0-D truncated-Boltzmann model's quasi-static
  assumption weakens (real non-equilibrium heating, unmodeled here) — so the practical
  recommendation is a *moderate* speedup, not the edge.
- **final-power is irrelevant** — BEC onset occurs before the ramp ends, so the ramp
  endpoint is never reached.
- **time-warp has a genuine interior optimum** $\gamma\approx0.7$ — the robust lever.

**Two-stage recipe.** Optimize the evaporation ramp (a faster, $\gamma\!\approx\!0.7$
warped power drop; $+30$–$40\%$ BEC at formation, with the higher end a knife-edge),
then decompress the ODT to $\bar\omega\approx0.6\,\bar\omega_\mathrm{form}$, fast
($+16\%$ condensate) — both experimentally available with the harmonic trap alone.

## Next
Realistic cooling trajectory $T(t),\mu(t)$ fed from `run_evaporation_bec`; widen the
evaporation-ramp bounds; an adiabatic (ramped) box if a box trap becomes available.
