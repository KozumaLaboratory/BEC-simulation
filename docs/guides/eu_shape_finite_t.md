# ¹⁵¹Eu finite-temperature trap-shape optimization

> **FROZEN 2026-07-28.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

The definitive, finite-temperature version of the $T=0$ trap-shape study
(`eu_shape_optimization.md`). At $T>0$ the shape optimum is governed by a
competition the $T=0$ Gross–Pitaevskii picture cannot see, so we evolve the
**Stoof-form (full-Hamiltonian) Stochastic Projected Gross–Pitaevskii equation**.

Driver: `docs/guides/figures/eu_shape_finite_t.jl`. Runs on TSUBAME H100 via
`scripts/eu_shape/submit_finite_t.sh` (modes `probe | campaign | equilibrium | kcut | shape`).

Data provenance: the repo carries only the figures (PNG) + code (driver, plot
scripts). Raw/derived CSVs backing the GPU-hour runs are archived on TSUBAME
persistent storage at `/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu_shape_optimization/data/`
(`t0/` for the $T=0$ trap-shape gate, `finite_t/` for the Stoof-SGPE runs);
re-fetch a CSV from there to re-run a plot script.

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
cutoff-dependent, and the equilibrium condensate $N_0$ does **NOT converge** with it.
A 64³/96³ TSUBAME scan (`eu_ft_cutoff_study.png`) shows $N_0$ falling monotonically
with $k_\mathrm{cut}$ AND, at fixed $k_\mathrm{cut}$, the 96³ curve lying *below* 64³ —
i.e. refining the grid does not flatten it. This is the grand-canonical classical-field
problem: at fixed $\mu$, enlarging the classical region adds Rayleigh–Jeans thermal
modes (unbounded) that dilute the coherent field, so the *equilibrium* $N_0$ is not a
converged absolute observable (earlier "$N_0$ robust, ~30%" was over the narrow
$k_\mathrm{cut}\in[4.6,8.0]$ window only). **Consequence:** trust the SGPE for the
loss-law ARBITER (the $N_0^{9/5}$ decay of a pure, cutoff-free condensate) and for
relative comparisons at FIXED $k_\mathrm{cut}$ — NOT for an absolute equilibrium $N_0$.
The ideal-Bose $1-(T/T_c)^3$ is drawn only for orientation, not a fit.

## Equilibrium is analytic; the SGPE is for the dynamics

A key clarification (the analytic curve in `eu_ft_equilibrium.png`, NO
simulation): the fixed-$N$ equilibrium is fixed by the atom + trap + $N$
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

**Equilibrium cross-check** (`eu_ft_equilibrium.png`): a single-axes plot of
condensate fraction $N_0/N$ vs $T/T_c$ overlaying the analytic $\mu$-pinned
bounded-thermal curve $N_0/N=1-(T/T_c)^3$, the ideal-quantum $1-(T/T_c)^3$ dashed
reference, and the SGPE points — so the analytic equilibrium and its SGPE
cross-check now live in this ONE figure. The (classical-field) SGPE condensate
$N_0$ melts $9502\to3100$ across $T/T_c=0.1\to0.9$ and $N_0/N\to0.95$ as $T\to0$ —
the right qualitative melting, with the SGPE points sitting BELOW the analytic
curve because the classical field is Rayleigh–Jeans over-populated, as expected.

**Cutoff sensitivity**: over the narrow $k_\mathrm{cut}\in[4.6,8.0]$ window the
$N_0$ spread is $30\%$ vs thermal $79\%$ — but that window is not convergence.
See "Honest cutoff limitation" above: on the wider $64^3$/$96^3$ scan $N_0$ falls
monotonically with $k_\mathrm{cut}$ and does not flatten under grid refinement, so
the absolute equilibrium $N_0$ is not a converged observable.

**Shape trade-off** (prep SGPE at $T/T_c=0.5$ → closed ramp +
$K_3$, all at fixed $k_\mathrm{cut}$, four protocols at the model point):

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
($\bar\omega=2\pi\cdot284$ Hz, $N=6.6\times10^4$, $T/T_c=0.5$, $34$ ms window;
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
(`ft_evap_ramp_optimize`): a Bayesian search over the
researched euv3 ramp (duration / final-power / time-warp transform), with the bounds
widened, lifts the condensate at BEC onset from $N_\mathrm{BEC}=6.56\times10^4$ to
$8.69\times10^4$ (**$+32.4\%$**, interior optimum $[0.56,0.19,0.71]$), reaching BEC
faster ($t_\mathrm{BEC}$ $1.70\to1.05$ s) via a steeper ramp.

**Parameter landscapes** show what is really going on:
- **duration is monotone** — shorter/faster is always better ($N_\mathrm{BEC}$ rises
  to $\sim9.3\times10^4$, $+42\%$, at the shortest duration that still reaches BEC,
  $\approx0.4$), because a faster ramp spends less time bleeding to three-body loss.
  The only hard limit is BEC-reachability — a knife-edge, and exactly where the 0-D
  quasi-static assumption weakens (resolved below).
- **final-power is irrelevant** — BEC onset occurs before the ramp ends, so the ramp
  endpoint is never reached.
- **time-warp has a genuine interior optimum** $\gamma\approx0.7$ — the robust lever.

**Physically resolving the duration knife-edge** (`eu_ft_evap_noneq.png`, now THE
single evaporation-ramp figure — $N_\mathrm{BEC}$ vs ramp-duration with the
finite-rate penalty off = quasi-static monotone knife-edge, and on = physical
interior optimum). The
"faster is always better" duration is an artefact of the model's quasi-static
assumption. We added a first-principles **finite-evaporation-rate penalty** to the
0-D model (`EvapParams.noneq_scale`, off by default): when the trap depth is lowered
faster than atoms can *evaporate* ($\gamma_\mathrm{ev}=\gamma_\mathrm{el}\cdot
\mathrm{evap\_factor}(\eta)$, small at large $\eta$), the newly-exposed atoms leave by
fast, non-selective **spilling** (carrying the threshold energy $\eta k_BT$, cooling
law $(\eta-3)/3$) instead of by selective evaporation ($\bar\varepsilon$, cooling
$L$); the cooling law is blended by $\xi=\gamma_\mathrm{ev}/(\gamma_\mathrm{ev}+
\mathrm{noneq\_scale}\cdot|d\ln U/dt|)$. With the penalty on, the knife-edge becomes a
**real interior optimum at a moderate duration $\approx0.6\times$** ($+22\%$ over the
same-model baseline), and ramps faster than $\sim0.4\times$ **fail to reach BEC**
(spilling kills the cooling) — the honest, physical answer, versus the unphysical
$+42\%$ knife-edge. (`noneq_scale=0` preserves the validated model; the evaporation
test suite passes unchanged.)

**Two-stage recipe** (`eu_ft_recipe.png` says it in one figure — *moderate on both knobs; the extremes break the BEC*). Optimize the evaporation ramp (a faster, $\gamma\!\approx\!0.7$
warped power drop; $+30$–$40\%$ BEC at formation, with the higher end a knife-edge),
then decompress the ODT to $\bar\omega\approx0.6\,\bar\omega_\mathrm{form}$, fast
($+16\%$ condensate) — both experimentally available with the harmonic trap alone.

## Number-conserving evaporation SGPE (ab-initio arbiter)

The 0-D model's absolute $N_0$ carries a $\sim2\times$ systematic (issue #75): it
reproduces the measured lifetime but forms the BEC while the trap is still tight,
so it is three-body-limited before decompression. To check that ab-initio without
the grand-canonical pumping artifact of a fixed-$\mu$ reservoir (which pumps atoms
into the condensate as the trap opens), we run a **closed-system evaporation SGPE**
(Blakie PGPE evaporative cooling, PRA 72 063608): a hot thermal cloud is seeded by
an SGPE prep, then evolved with the $\mu$-bath OFF ($\gamma=0$, so atom number is
set by physics), cooled by a radial energy-knife that removes $|r|>R(t)$ (in
$V=\tfrac12 r^2$, energy $>\tfrac12 R(t)^2$ — a shrinking $R(t)$ is the lowering trap
depth) plus $K_3$. The two loss channels are tracked separately, so the closed atom
budget $N_\mathrm{end}+\Delta N_\mathrm{evap}+\Delta N_{K_3}=N_\mathrm{start}$ is the
number-conservation check (driver modes `evap_sgpe`, `evap_sgpe_cal`, `evap_k3law`).

**Calibrated evaporation — ILLUSTRATIVE ONLY** (`eu_ft_evap_sgpe_cal.png`, $48^3$/$D{=}3$
GPU, seeded at the 0-D formation handoff $\bar\omega=2\pi\cdot284$ Hz,
$N_\mathrm{BEC}=6.6\times10^4$, $T/T_c=1.0$): the atom budget closes to machine precision
($\Delta\sim10^{-13}$), and evaporation drives the cloud to a pure BEC (condensate
fraction $0.42\to1.00$). **Do not read the numbers quantitatively.** The knife ramps over
$\sim25$ ms ($1/\omega_\mathrm{ref}=0.56$ ms/unit), whereas the real evaporation is
$\sim1$–$2$ s — this run is $\sim60\times$ too fast (the s-vs-ms infeasibility: a physical
$\sim1$ s ramp is $\sim2000$ internal units $\times$ ensemble, out of reach). At $60\times$
the removal outruns rethermalisation, so this is non-adiabatic spilling, not quasi-static
evaporation; it only *illustrates* the qualitative point — a tight trap $K_3$-erodes the
condensate (diluting would preserve it) — not a calibrated evaporation outcome.

**Same-physics arbiter** (`eu_ft_evap_k3law.png`): a pure condensate at the same
$(\bar\omega,N)$ decays under $K_3$ only (closed, no evaporation). The 0-D attractor
law predicts $-\dot N_0\propto N_0^{9/5}$ ($\langle n^2\rangle=\tfrac{8}{21}n_0^2$,
$n_0\propto N_0^{2/5}$). The ab-initio 3D decay fits **$N_0^{1.796}$ vs the 0-D
$N_0^{1.800}$** (48³/D=3), and the closed form $[N_0(0)^{-4/5}+\tfrac45\gamma t]^{-5/4}$
overlays the SGPE data. Unlike the evaporation above, this is a genuine physical
timescale: the $K_3$ decay is itself a ms-scale process, so the $\sim45$ ms window is
physical, and the RATE $\gamma$ (not just the exponent) is the 0-D's by construction —
the run uses the identical `k3_bare` as the 0-D and the ab-initio 3D density, and a TF
condensate has $\langle n^2\rangle=\tfrac{8}{21}n_0^2$ (verified in PR #80), which the
exponent match confirms. (The decay is $\sim7\times$ faster than the thesis $1.4$ s BEC
lifetime because $N=6.6\times10^4$ at $\bar\omega=2\pi\cdot284$ Hz is denser than the
thesis lifetime conditions — a conditions difference, not a discrepancy.) So the 0-D
*static* three-body loss law is correct ab-initio, which pins the $\sim2\times$ systematic
to the formation **dynamics**, not the loss law — an independent confirmation of the
issue-#75 diagnosis.

Honest limits **of this closed-field run**: the evaporation timescale is not physical
— it is $\sim60\times$ too fast — so this number-conserving SGPE is an arbiter for the
**fast physics** (three-body decay, the $N_0^{9/5}$ law) and only *illustrative* for the
slow evaporation itself. The c-field is also cutoff-dependent. The s-scale ramp is
now reachable with the full SPGPE (growth + energy-damping reservoirs,
Rooney/Blakie/Bradley arXiv:1210.0952) — see the section below and
[spgpe.md](spgpe.md).

**Finite-depth FORT spill** (`eu_ft_evap_fort.png`, driver mode `evap_fort`): the
radial energy-knife is replaced by a physical finite-depth Gaussian FORT
$V(r)=U_0(t)(1-e^{-V_h/U_0(t)})$ (central $\omega=1$, depth $U_0$); lowering $U_0(t)$
lets atoms above the barrier climb out and be removed by a box-edge CAP absorbing
boundary — a physical spill, not an ad-hoc threshold. 48³/D=3 GPU: budget exact
($\Delta\sim10^{-13}$), condensate fraction $0.44\to0.97$, $N_0$ $50\text{k}\to62\text{k}$
(the thermal cloud condenses as it is spilled). Same timescale caveat as above.

## Superseded for the evaporation ramp: the full SPGPE

The timescale limit above was a **cost** limit, not a physics one, and it has been
removed — see [spgpe.md](spgpe.md). Two changes:

- The dissipative sub-step drew every random number on the host and copied it over
  PCIe, which was 88 % of its cost (18.5 ms of a 21.1 ms step at $48^3$/D=3).
  Drawing on the device cuts the step to 2.4 ms *while also* adding the
  energy-damping term. A 1.5 s ramp is now ~0.5 h per trajectory.
- With the growth reservoir there is no knife to sweep. The thermal cloud is not
  simulated — it is the I region, supplied by the 0-D model at $(T(t),\mu(t))$ on
  the experimental timescale — so the condensate forms because the reservoir got
  cold, at the physical rate.

The $\sim60\times$-too-fast caveat on `eu_ft_evap_sgpe_cal.png` stands for **that
figure**; it is not a limit of the method. The $K_3$-law arbiter is unaffected
either way (ms-scale physics, physical window).

## Next
The $64^3$–$96^3$ cutoff-convergence study of the evaporation SGPE is running on
TSUBAME; an adiabatic (ramped) box if a box trap becomes available.
