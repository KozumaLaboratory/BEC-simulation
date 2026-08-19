# Nucleating the weak-field ¹⁵¹Eu flower texture in place — what a cooling trajectory can and cannot select

> **FROZEN 2026-08-19.** A record of what was measured on that date, not a
> maintained document. The measurements are reproducible from the runs named in
> §5 and the drivers in §4. Live sources: `CLAUDE.md`, `docs/index.md`, the code.
>
> §1–§4 were written **before** the SPGPE ensemble and are the pre-registration:
> the axes, the systematics, the rejection criteria. §5 is the measurements, each
> row naming the run that produced it. §6 is the answer.
>
> Predecessors: `docs/guides/eu_adiabatic_protocol.md` (FROZEN 2026-07-28) —
> which established that the state cannot be *transported* into the target and
> named this calculation as its successor — and
> `docs/guides/eu_kappa_hysteresis_loop.md` (FROZEN 2026-08-18), which measured
> the selection rule that closes the field route.

## 1. The question, and what is already closed

At $\kappa = 1.8$, $B = 20\ \mu$G the ¹⁵¹Eu ground state is the **flower**
texture, $\langle F_\perp\rangle = 5.137$, and the **polarised** state is a
distinct converged local minimum 0.133 $\hbar\omega_{\rm ref}$ per atom above it.
Two independent campaigns have measured that the flower cannot be reached by
transforming a state prepared somewhere else:

| route | why it fails | source |
|---|---|---|
| ramp $B$ | $B_zF_z$ commutes with $J_z$, and the two branches sit in different $J_z$ sectors at every field. No rate converts | `eu_kappa_hysteresis_loop.md` §5.4 |
| ramp $\kappa$ | axially symmetric, so $J_z$ is conserved again; the endpoint is the Einstein–de Haas member of the seed's sector, +0.32 above the ground state with a floor | `eu_adiabatic_protocol.md` |
| drive with a rotating transverse field | moves $J_z$ by more than enough, but does positive work: the energy minimum is at $t = 0$ on every trajectory | `eu_adiabatic_protocol.md` |

So the state has to be **nucleated in place**. #334 asks the question that
remains: *does a realistic cooling trajectory select the flower, or does it get
caught on the polarised branch?* That is the experiment's actual risk, and it is
not answered by knowing the flower is the ground state.

**What makes it answerable now.** #327 merged the full SPGPE — growth *and*
energy-damping reservoirs, with $\gamma$ and $\bar{\mathcal M}$ computed from
$(\mu, T, \epsilon_{\rm cut})$ rather than tuned — and it reproduces a published
Kibble–Zurek exponent to $0.05\sigma$ (`docs/validation/spgpe_kz_reproduction.md`).
A reservoir is also the only thing in the model that can lift the obstruction
above: SPGPE growth exchanges atoms with an unpolarised incoherent region at one
$\mu$, so it does **not** conserve $M_z$ or $J_z$. That is a physical statement,
not a numerical convenience — spin exchange with the thermal cloud is what lets a
cloud leave its $J_z$ sector — and it is why nucleation can work where transport
cannot.

## 2. What the target point costs, and what that forces

Three numbers decide what is representable. All three are cheap, all three were
measured before any trajectory (`scripts/eu334/window.jl`, §5.1), and each one
changed the design.

**µ = 14.90** on the flower branch (15.19 polarised). The SPGPE is undefined
unless the C region extends above the chemical potential — `spgpe_growth_rate`
throws otherwise — so $k_{\rm cut} > \sqrt{2\mu} = 5.46$ is a floor. The
campaign grid the reference states live on, 32³ at box 24, has
$k_{\max} = 4.19$. **There is no SPGPE at this point on that grid at all**, and
no choice of temperature rescues it.

**$\Delta E = 6626\ \hbar\omega_{\rm ref}$ between the branches** — 0.133 per atom
at $N = 5\times10^4$. Against $T_c \approx 42$ that is 157 $k_BT$, and against any
temperature a C region can hold it is worse. Two consequences: equilibrium
selection is **deterministic**, and thermal barrier crossing between the branches
is impossible at every representable temperature. Whatever selects the texture
does it while the condensate is small, not by a Boltzmann factor at the end.

**The C region's thermal energy is $10^3$–$10^4\times\Delta E$.** #334's
acceptance criterion "determine the branch by energy against the two reference
values" therefore cannot be applied to the c-field as written — the total energy
of $\psi$ is a thermometer. §4's classifier makes the same claim on a state where
it means something instead.

### The axis that is actually available

At fixed field the couplings scale with the condensate: $c_0$, $c_1$ and $c_{dd}$
all carry $N_0$ and the Zeeman term does not. A growing condensate therefore
traverses a one-parameter family in

$$f \equiv N_0/N, \qquad B = 20\ \mu\text{G},\ \kappa = 1.8\ \text{held fixed},$$

and the texture transition on that family is what a cooling run crosses. This
replaces both of #334's literal starting points, and the replacement is forced
rather than convenient:

- *"start on the polarised side, $B > B_{eq}$"* — closed by #335: the field ramp
  is a $J_z$ slide, not a branch conversion.
- *"start thermally above $T_c$"* — at fixed $\mu$ the classical-field transition
  sits near $T \approx 110$ (`classical_field_equilibrium`, §5.1), needing
  $\epsilon_{\rm cut} \approx 125$, $k_{\rm cut} \approx 16$ and a 192³ grid at 13
  components. Not for an ensemble, and saying so with a number is better than
  discovering it after a week of queue.
- *below $f_{\rm sp}$, where the flower branch does not exist*, the condensate is
  polarised because there is nothing else to be. That **is** the disordered side
  of this transition, and it costs no thermal cloud to reach.

### Axes, and the settings held fixed

| axis | points | what it separates |
|---|---|---|
| growth rate $\tau$ | 3, spanning the reservoir-limited rate | kinetic trapping vs equilibrium selection — the verdict |
| temperature $T$ | 2 | whether the selection statistic is thermal at all |
| seed | ≥ 20 per cell | the statistic itself, with a binomial error |
| $\kappa$ | 1.8 and 0.9 | whether a selection statistic appears where #335 measured **one** branch |
| noise on/off | quiet SPGPE at one cell | the positive control |

Held fixed, and load-bearing:

- **64³, box 24.** The coarsest grid whose $k_{\max} = 8.38$ clears
  $k_{\rm cut} = \sqrt{2(\mu + n_T T)}$ over the ramp. `nucleate.jl` refuses to run
  when it does not, rather than clipping the cutoff and letting the *grid* define
  the C region.
- **$n_T = 1$** — the C region one thermal energy deep, the standard c-field
  criterion (occupation ≈ 1 at the cutoff). $n_T$ is a genuine free parameter of
  the method; §7 says what was and was not checked against a second value.
- **`split_step_midpoint!`**, dt = 0.002, **dealiasing off**, **unpadded DDI**,
  q = 0, **LHY off**, pin $\varepsilon = 0.002$ — every one of these matching
  #335, because the reference branch energies this campaign is measured against
  were converged under exactly them. A seed converged under a different kernel or
  pin is not stationary and the run would be measuring that transient.
- **$\gamma$ and $\bar{\mathcal M}$ derived, never pinned.** A fitted rate here is
  invisible: it breaks no conservation law and no oracle. `SPGPEReservoir` refuses
  a value more than 2× from the derived one unless the mismatch is typed out.

### Systematics, before residuals

- **The pin.** #335 §5.6 measured the transverse response *halving* when the pin
  went 0.068 → 0.135 µG, both far below any lab residual. Anything this campaign
  reports about transverse spin inherits that sensitivity; the discrete
  observables (§3.4) do not.
- **Unpadded DDI** carries a 2–5 % anisotropic field error, common-mode in the
  branch difference (#335 §2: $B_{eq}$ moves 0.33 %, $\langle F_\perp\rangle$ per
  state 0.3 %).
- **The reservoir is spin-unpolarised**: one $\mu$ for all 13 components, the
  scalar rates applied per component (`docs/guides/spgpe.md`, known limits). A
  laboratory thermal cloud in a magnetic field is polarised, so the real
  reservoir's ability to change $M_z$ is *smaller* than modelled here. Any
  positive selection result is therefore an upper bound on the real one — which is
  the safe direction for a negative result and the unsafe one for a positive.

## 3. Rejection criteria — fixed before launch

1. **Positive control first.** The quiet SPGPE (noise off) at the same
   $(\mu(t), \tau)$ must track the branch it started on and end within
   $10^{-3}$/atom of that branch's converged energy. *A solver that cannot hold a
   branch without noise produces selection statistics that are measuring the
   solver.* No ensemble number is reported until this passes.
2. **The classifier must pass its own calibration** — both references recovered
   from themselves, and recovered again after noise of the amplitude the
   trajectories actually arrive carrying. Recorded, not asserted:
   `classify.jl --calibrate` writes the table and refuses to classify otherwise.
3. **Three outcomes, not two.** `flower`, `polarised`, `excited`. A state above
   both branches by more than their separation is not on either — #335 measured
   exactly that for the adiabatic endpoints — and calling it a branch would repeat
   the error this campaign exists to avoid.
4. **One discrete observable beside every continuous one.** Per-component winding
   number with **per-component** thresholds (a minority component holding 0.3 % of
   the atoms is 2–3 orders below the global peak, and a global mask returns a
   spurious zero), reported with its charged-plaquette count so that a zero can be
   told from a masked read. Plus the Stern-Gerlach level count, which is what the
   experiment reads and carries no calibration.
5. **The selection fraction is reported with a binomial interval**, ≥ 20
   trajectories per cell, and a cell that did not finish 20 says so rather than
   quoting the fraction it got.
6. **A verdict of "the flower is never selected" requires the rate scan**, not one
   rate: 0/20 at every rate with the quiet control passing is a negative answer;
   0/20 at one rate is a rate.
7. **The κ = 0.9 control must not produce a selection statistic.** #335 measured
   one branch there statically — two continuations from opposite ends agreeing to
   6–7 digits. If the ensemble reports a branch split at κ = 0.9, the instrument
   is being measured and no κ = 1.8 number is reported.
8. **A cell may not be read if its C region moved outside the grid**, and it
   cannot: `nucleate.jl` refuses at both ends of the ramp. This is criterion 8
   rather than a footnote because it is the one that decides whether the numbers
   are physical or are a property of the box.

*(#334 asks for a κ = 0.8 control; κ = 0.9 is used instead. It is the same side of
the tricritical point — the crossover side, $\kappa_{tc} \approx 0.95$ — and it is
where #335 converged its seeds and measured the single-branch structure the
control is against. Using 0.8 would mean re-converging that structure to compare
against nothing.)*

## 4. Instruments

| what | where |
|---|---|
| the C-region window, µ, $\Delta E/k_BT$, the grid a temperature needs | `scripts/eu334/window.jl` |
| branch continuation in condensate fraction $f = N_0/N$ | `scripts/eu334/nucleation_bifurcation.jl` |
| one SPGPE trajectory across the family | `scripts/eu334/nucleate.jl` |
| branch assignment by quench-and-relax, with its calibration | `scripts/eu334/classify.jl` |
| TSUBAME submission | `scripts/eu334/{launch,submit_*}.sh`, `_preamble.sh` |

**Why the branch is not read off the c-field's energy.** §2 measured the C
region's thermal energy at $10^3$–$10^4\times$ the branch separation. So the field
is quenched — reservoir off — and relaxed to the nearest local minimum *at its own
condensate fraction*, and that state's energy is compared against the two
branches. The relaxed state answers exactly what the criterion is after (which
basin is the field in), it inherits the reference values instead of inventing a
threshold, and the whole procedure is calibratable, which reading a raw energy is
not.

Interpolating the branch table **at the run's own $f$** rather than at $f = 1$ is
deliberate: a growth ramp ends where its lag leaves it, and comparing a state at
$f = 0.8$ against the $f = 1$ branch energies would report the missing atoms as a
branch difference.

## 5. Results

*(Filled as the runs land. Each row names the run that produced it.)*

### 5.1 The window — measured before anything was launched

`figs/eu334/window/{branches,window}.csv`, from the #335 converged references at
32³.

| state | $E$/atom | µ | $\sqrt{2\mu}$ | $\langle F_\perp\rangle$ | $J_z$ | 99.99 % of $\|\psi\|^2$ below |
|---|---:|---:|---:|---:|---:|---:|
| flower | 10.731086 | **14.897** | 5.458 | 5.1376 | −1.0873 | $k = 3.87$ |
| polarised | 10.863614 | **15.193** | 5.512 | 0.0744 | −1.2587 | $k = 3.85$ |

The occupied band of the *state* fits the 32³ grid comfortably (3.87 against
$k_{\max} = 4.19$); it is the **reservoir** that does not fit, and the two are
different requirements. #335 §2 quotes the band as $\sqrt{2\mu} \approx 4.3$ from
a Thomas-Fermi estimate — the measured 99.99 % edge is 3.87, and the TF number is
better read as what the *cutoff* has to clear.

What a temperature costs, at $n_T = 1$ (grid side needed at box 24 for
$k_{\max} \ge k_{\rm cut}$, and for a 1.5× margin):

| $T$ | 1 | 5 | 10 | 20 | 42 ($\approx T_c$) |
|---|---:|---:|---:|---:|---:|
| $\epsilon_{\rm cut}$ | 15.9 | 19.9 | 24.9 | 34.9 | 57.0 |
| $k_{\rm cut}$ | 5.64 | 6.31 | 7.06 | 8.35 | 10.68 |
| grid $n \ge$ | 44 (65) | 49 (73) | 54 (81) | 64 (96) | 82 (123) |
| $\gamma$ | 1.5e-5 | 7.5e-5 | 1.5e-4 | 3.0e-4 | 6.5e-4 |
| $1/(\gamma\mu)$ [ms] | 6515 | 1300 | 646 | 320 | 150 |
| $\Delta E/k_BT$ | 6630 | 1330 | 663 | 331 | 157 |

$\bar{\mathcal M} = 1.63\times10^{-3}$ throughout — it depends on the cutoff only
through $(\epsilon_{\rm cut}-\mu)/T$, which $n_T$ holds fixed.

**And at fixed µ the classical field does not cross anything until T ≈ 110.**
`classical_field_equilibrium` at $\mu = 14.897$, $c_0 = 0.0469$ (per-atom),
$\bar\omega = 1.216$: the condensate fraction runs 0.98 at $T = 10$, 0.61 at
$T = 40$, 0.08 at $T = 80$, and reaches zero between $T = 100$ and $T = 120$. The
central density stays pinned at 318 until it collapses. This is the number that
rules out the thermal route rather than an opinion about it: representing
$T \approx 110$ needs $k_{\rm cut} \approx 16.4$, i.e. $n \ge 126$ ($188$ with
margin), at 13 components.

### 5.2 The flower texture has a minimum atom number

`figs/eu334/bifurcation/flower_down.csv` (32³, ε = 0.002, unpadded, 25 cells
geometric over $f \in [0.02, 1]$, ε-ladder + second-polish certification on every
cell). Walking the flower branch **down** in condensate fraction:

| $f$ | 0.850 | 0.613 | 0.443 | 0.376 | **0.320** | **0.271** | 0.231 |
|---|---:|---:|---:|---:|---:|---:|---:|
| $N_0$ | 42480 | 30662 | 22132 | 18803 | **15975** | **13572** | 11531 |
| $\langle F_\perp\rangle$ | 5.010 | 4.671 | 4.182 | 3.870 | **3.500** | **0.122** | 0.130 |
| $J_z$ | −1.133 | −1.290 | −1.541 | −1.693 | **−1.860** | −2.197 | −2.357 |

**The flower branch ceases to exist between $f = 0.271$ and $f = 0.320$** —
$N_0^\ast \approx 1.4$–$1.6\times10^4$ atoms. Below it the continuation has fallen
onto the polarised branch ($\langle F_\perp\rangle \approx 0.12$ and falling
smoothly to 0.23 at $f = 0.02$), which is what a branch ending looks like from a
warm continuation.

This is the structural fact the rest of the campaign is about: **a condensate is
born polarised**, not because it is preferred but because below $N_0^\ast$ the
flower state does not exist to be selected.

*(The polarised walk upward, the energy crossing $f_{\rm eq}$, and whether the
polarised branch has any spinodal in $f$ — pending.)*

### 5.3 The ensemble

*(Pending.)*

## 6. The answer to #334

*(Pending.)*

## 7. Limits

- **LHY off.** #337 closed on 2026-08-19 with the ambiguity of $\varepsilon_{\rm
  LHY}$ at Eu F = 6 measured at ≤ 6 %, so this is no longer "unusable" — it is a
  deliberate choice to stay in the epoch the reference branches were converged in.
  Turning it on means re-converging every reference and the whole #335 branch
  structure with it.
- **The reservoir is spin-unpolarised** (§2). This is the assumption a positive
  result would rest on hardest.
- **$n_T$ is a free parameter of the method** and results read off a single value
  should be checked against a second.
- **The classical-field description is cutoff-dependent** in absolute $N_0$; the
  quantity here is a branch label, which is not.
- **32³ for the bifurcation, 64³ for the trajectories.** The bifurcation's own
  grid dependence is measured in §5 where the two overlap, and not assumed.
- **The parent campaign's phase labels are mean-field-only and provisional.**
