# The full SPGPE — growth + energy-damping reservoirs

The stochastic projected Gross–Pitaevskii equation of Rooney, Blakie & Bradley
(PRA **86**, 053634 (2012), [arXiv:1210.0952]), with **both** reservoir processes
and with the dissipation coefficients computed from the reservoir rather than
supplied by hand. Implementation: `src/solvers/spgpe.jl`; the evaporation bridge
is `src/solvers/evaporation/spgpe_reservoir.jl`.

## What it adds over the existing SGPE

The classical field occupies a low-energy **C region** ($\epsilon \le
\epsilon_\mathrm{cut}$); everything above is the **I region**, treated as a
reservoir at $(\mu, T)$. The two couple through two physically distinct
processes:

| process | mechanism | conserves | ensemble |
|---|---|---|---|
| **growth** (number damping) | two I atoms collide, one enters C | — | grand canonical |
| **scattering** (energy damping) | a C atom and an I atom exchange energy | $N_C$ **exactly** | canonical |

The existing `apply_sgpe_step!(…; full_hamiltonian=true)` **is** the growth term
(Rooney Eq. 21) — with $\gamma$ as a free knob. What was missing:

1. **$\gamma$ and $\bar{\mathcal M}$ from the reservoir.** Eq. (19) and Eq. (26)
   turn both coefficients into predicted numbers, so a run has a temperature and
   a chemical potential rather than a tuning parameter.
2. **The scattering term.** Number-conserving energy exchange, which the growth-
   only theory cannot represent at all. In the Eu evaporation regime it comes out
   *larger* than $\gamma$ ($\bar{\mathcal M}\approx3\times10^{-3}$ vs
   $\gamma\approx7\times10^{-4}$), so it is not a correction.
3. **A time-dependent reservoir**, which is what makes a second-scale evaporation
   ramp a thing you can drive rather than impose.

## The equations, in internal units

With $\hbar=m=\omega_\mathrm{ref}=1$, $T \equiv k_BT/\hbar\omega_\mathrm{ref}$,
lengths in $a_\mathrm{ho}$, both coefficients are dimensionless (Rooney Eq. 30).

**Growth** (Eq. 21), which is the Stoof-form SGPE step:

$$d\psi|_\gamma = \mathcal P\{\gamma(\mu - \mathcal L)\psi\,dt + dW_\gamma\},
\qquad \langle dW_\gamma^* dW_\gamma\rangle = 2\gamma T\,\delta_C\,dt$$

$$\gamma = \gamma_0\sum_{j=1}^{\infty}\frac{e^{\beta\mu(j+1)}}{e^{2\beta\epsilon_\mathrm{cut}j}}
\Phi\!\left[\frac{e^{\beta\mu}}{e^{\beta\epsilon_\mathrm{cut}}},1,j\right]^2,
\qquad \gamma_0 = \frac{8a_s^2}{\lambda_{dB}^2} = \frac{4a_s^2T}{\pi}$$

($\Phi$ = Lerch transcendent.) Implemented via the exact regrouping
$\gamma = \gamma_0\sum_j z^{1-j}\big(\sum_{n\ge j}x^n/n\big)^2$ with
$z=e^{\beta\mu}$, $x=e^{\beta(\mu-\epsilon_\mathrm{cut})}$ — the printed form
builds $e^{\beta\mu(j+1)}$ and $\Phi$ separately, both large where the product is
small. Terms fall off like $e^{\beta(\mu-2\epsilon_\mathrm{cut})}$.

**Scattering** (Eq. 27):

$$d\psi|_{\mathcal M} = \mathcal P\{-i V_{\mathcal M}\psi\,dt + i\psi\,dU\},
\qquad
V_{\mathcal M} = -\mathcal F^{-1}\!\left\{\frac{\bar{\mathcal M}}{|k|}\,
\mathcal F\{\nabla\!\cdot\!j\}\right\},
\qquad
\bar{\mathcal M} = \frac{16\pi a_s^2}{e^{(\epsilon_\mathrm{cut}-\mu)/T}-1}$$

with $\langle dU\,dU\rangle = 2T\varepsilon(r-r')dt$, i.e. white noise coloured by
$\sqrt{2T\bar{\mathcal M}/|k|}$.

Three properties make this cheap and exact where it matters:

- **No current is needed.** $\nabla\!\cdot\!j = \mathrm{Im}(\partial_d\psi^*\partial_d\psi)
  + \mathrm{Im}(\psi^*\partial_d^2\psi)$ and the first term is real, so
  $\nabla\!\cdot\!j = \sum_c \mathrm{Im}(\psi_c^*\nabla^2\psi_c)$ — one Laplacian
  per component instead of $N$ gradients plus a divergence.
- **Both terms are one real phase**: $\psi \leftarrow \psi\exp(i(dU - V_{\mathcal M}dt))$.
  This is the *exact* Stratonovich solution of $dX = iX\circ dU$, not an $O(dt)$
  approximation, and it conserves $\int|\psi|^2$ to machine precision.
- The $k=0$ component of both kernels is zeroed: $\nabla\!\cdot\!j$ has no $k=0$
  content for a localised field, and a $k=0$ noise is an unobservable global
  phase with divergent variance.

## Usage

```julia
res = SPGPEReservoir(; T=5.0, mu=2.0, a_s=0.015, k_cut=6.0)   # ϵ_cut = ½k_cut² by default
spgpe_rates(res, 0.0)          # (; T, mu, eps_cut, gamma, M)

# compose with the unitary split-step
cb = spgpe_callback(res, dt; every=5)
run_simulation!(ws; callbacks=SimulationCallbacks(on_step=cb))
```

A ramped reservoir takes `Waveform`s:

```julia
res = SPGPEReservoir(;
    T  = PiecewiseLinearWaveform(t_internal, T_of_t),
    mu = PiecewiseLinearWaveform(t_internal, mu_of_t),
    a_s = a_s / a_ho, k_cut = 10.6)
```

Sub-stepping the reservoir (`every=5`) is safe because $\gamma\,dt_\mathrm{eff}$ and
$\bar{\mathcal M}\,dt_\mathrm{eff}$ are both $\lesssim10^{-5}$; it is worth a
factor of ~2.3 in wall time.

`number_damping=false` / `energy_damping=false` select the scattering-only and
growth-only sub-theories. `gamma=` / `M=` override the reservoir formulas — used
for the strongest available check, that equilibria are **independent** of both
coefficients (Rooney §III D 3, §III E 3).

## Driving a physical, second-scale evaporation

`spgpe_reservoir(evap_result, trap, ramp; omega_ref, a_s, k_cut, t_start)` maps a
two-component 0-D trajectory ([`run_evaporation_bec`](evaporation_model.md)) onto
$(T(t), \mu(t))$ in internal time. Above $T_c$, $\mu$ comes from the ideal-Bose
phase-space density ($\mathrm{Li}_3(z) = N(\hbar\bar\omega/k_BT)^3$); below, it is
pinned by the condensate, $\mu = \tfrac12\hbar\bar\omega(15N_0a_s/a_\mathrm{ho})^{2/5}$.
The branches meet continuously at $N_0\to0$.

**Why this replaces the energy knife.** A closed c-field cannot evaporate —
something has to remove the hot atoms. Doing that with a mechanical knife forces
the sweep into ~25 ms of internal time to stay affordable, ~60× faster than the
real Eu evaporation, which is non-adiabatic spilling rather than evaporation. With
the reservoir, the thermal cloud is not simulated at all; it is the I region, and
the 0-D model already describes it on the experimental timescale.

**What is and is not predicted.** Prescribing $\mu(t)$ **prescribes $N_0$** — see
the euv3 section below; this is a property of the grand-canonical ensemble, not of
how $\mu$ is derived. The absolute condensate number is therefore an input, and
"does a BEC form" is not a question this configuration answers. What is
independent is the **lag**: growth proceeds at finite $\gamma$, so a ramp faster
than $1/\gamma$ leaves the condensate behind its quasi-static value. The 0-D model
cannot produce that gap at all, and it is what decides whether an "optimised"
fast ramp actually delivers atoms.

### The window a c-field can represent

The C region must contain the thermal cloud, so $\epsilon_\mathrm{cut}\gtrsim\mu+T$.
At the 50 µK start of the euv3 ramp $T\approx3.7\times10^3$ and $k_\mathrm{cut}\approx86$
— no grid resolves that. The c-field description becomes affordable only near
degeneracy. On the euv3 ramp (BEC onset at 1.70 s):

| window | real duration | internal units | grid | steps @ dt=0.002 |
|---|---|---|---|---|
| $T\le1.05\,T_c$ | **0.714 s** | 1288 | $80^3$ | $6.4\times10^5$ |
| $T\le1.20\,T_c$ | 0.770 s | 1442 | $94^3$ | $7.2\times10^5$ |
| $T\le1.50\,T_c$ | 0.934 s | 1911 | $118^3$ | $9.6\times10^5$ |

The driver refuses to run when the grid cannot resolve $k_\mathrm{cut}$, rather
than quietly lowering it — a lowered cutoff would let the *grid* define the C
region and would push $\epsilon_\mathrm{cut}$ below $\mu$, where the reservoir
formulas are undefined.

### The euv3 ramp: a diagnostic, NOT a physics result

![second-scale SPGPE evaporation](../../figs/eu_evaporation_optimization/eu_evap_spgpe.png)

Run it and no condensate forms. **Do not read that as a statement about ¹⁵¹Eu.**
It is a statement about the reservoir trajectory that was fed in, and it fails two
independence tests.

**It does not survive the $K_3$ systematic.** $\mu = \mu_\mathrm{TF}(N_0)$ follows the
0-D condensate down as three-body loss eats it, so the verdict tracks a
one-parameter fit:

| $K_3$/fit | 0-D final $N_0$ | vs measured | $\mu$ peak@ | $G_\mathrm{eff}$ | verdict |
|---|---|---|---|---|---|
| 1 | 1789 | **0.04** | 7.4 % | 4.5 | SHORT |
| 0.25 | 7200 | 0.14 | 10.4 % | 15.3 | FORMS |
| 0.02 | $6.1\times10^4$ | 1.21 | 19.5 % | 60.8 | FORMS |

The fitted $K_3$ leaves 4 % of the **measured** $5.02\times10^4$ (PRL 129, 223401).
Reproducing the measurement takes $K_3\approx$ fit/50 — near the independent
BEC-fit estimate — and there the budget clears by $8.8\times$. The verdict flips at
$K_3/\mathrm{fit}\approx0.3$. Tuning $K_3$ until a condensate appears would be
fitting the input to the desired answer, so it is not done here.

**And the deeper problem is the ensemble, not the fit.** In a grand-canonical
SPGPE, $\mu$ below $\varepsilon_0$ forbids a condensate and $\mu$ above it *sets* the
equilibrium size via $\mu = \varepsilon_0 + c_0n_0$. **Prescribing $\mu$ is
prescribing $N_0$**, whatever $\mu$ is derived from. Taking $\mu$ from the I region
instead (`mu_branch=:thermal`) does not escape it — an ideal Bose gas caps $\mu$ at
$0$ while $\varepsilon_0 = \tfrac32\bar\omega \ge 0.62$, so the drive is negative at
**all 447** trajectory points and $N_0 \equiv 0$ is imposed rather than predicted.

So this configuration cannot answer "does Eu form a BEC, and how many atoms".
What it does answer:

- **The lag.** For a *given* $(T(t),\mu(t))$, finite $\gamma$ decides whether the
  c-field tracks. Here $\mu$ peaks 95 of 1288 internal units in — 0.053 s of a
  0.714 s window — and falls for the rest; only the rising phase can build
  anything, and it carries $G_\mathrm{eff}=4.5$ against 6.9 needed, with 77 % of the
  budget landing after the turnover where damping *removes* condensate. That the
  0-D quasi-static assumption breaks here is a real finding about the handoff.
- **That the solver condenses when the reservoir allows it** — 82 % of
  $N_\mathrm{TF}$ at fixed $\mu=5$, $T=2$, still rising.

Answering the atom-number question needs a **number-conserving** formulation, with
$\mu(t)$ solved so that $N_C+N_I$ matches a measured total. That is not
implemented.

## Validation

`test/dynamics/test_spgpe.jl` (**ci** tier), `test/dynamics/test_spgpe_reservoir.jl`
(**full** tier), `test/gpu/test_spgpe_gpu_cpu_parity.jl` (**full** tier — placed
alongside `test_projected_gp_parity.jl`, which gates the same host-array-broadcast
bug class).

| gate | what it pins | type |
|---|---|---|
| **published coefficients** | $\gamma$ and $\bar{\mathcal M}$ reproduce Rooney Fig. 2's own $(\bar\gamma,\bar{\mathcal M})=(1.5,2.7)\times10^{-4}$ for their Rb-87 example, at a single consistent $\epsilon_\mathrm{cut}-\mu\approx0.35\,k_BT$ — one parameter constrained by two independent numbers | **C** |
| $\gamma_0$ asymptote | $\gamma/\gamma_0\to e^{2(\mu-\epsilon_\mathrm{cut})/T}$, with the tolerance tracking the known $O(x)$ correction so a wrong *prefactor* still fails | B |
| $\nabla\!\cdot\!j$ identity | equals the divergence of the independently-coded `probability_current`, converging with resolution | A |
| **number conservation** | energy damping changes $\int|\psi|^2$ by $<10^{-13}$ — a real phase cannot | A |
| **energy monotonicity** | quiet scattering never heats, and matches $dE_C/dt = -\bar{\mathcal M}\int d^3k\,|k\cdot\tilde j|^2/|k|$ (Eq. 29) to 5 % | B |
| inert on stationary states | $\nabla\!\cdot\!j=0 \Rightarrow$ exactly no effect; flowing state $\Rightarrow$ effect | A |
| growth direction | $N_C$ grows for $\mu>\tilde\mu$ and decays for $\mu<\tilde\mu$ (Eq. 23) | A |
| GPU = CPU | quiet step agrees to $10^{-11}$; three host k-space arrays broadcast against device buffers | A (Level 0) |
| timescale | the bridge carries a $>0.5$ s ramp into $>10^3$ internal units | A |
| **condensation** | $N_0$ reaches $[0.3,1.5]\,N_\mathrm{TF}$ and stays below $N_C$ — the gate for the thing the solver exists to do | B |
| **Rayleigh–Jeans total** | free field: $N_C$ equals $\sum_{\|k\|<k_\mathrm{cut}}T/(\epsilon_k-\mu)$ to 4 % | B |

### The projected step's number loss: ONE-OFF without noise, a RATE with it

> **This section has been wrong in both directions on 2026-08-20. Read the split
> before quoting any part of it.**
>
> It first said the projected scattering step loses number "at the same order as
> the growth rate", so a growth problem must run `energy_damping=false`; #334's
> ensemble was designed on that. It was then RETRACTED here and, independently, in
> PR #351, on the strength of a **noise-off** measurement showing a one-off.
>
> **The retraction was too broad.** The noise-off result is correct and is
> reproduced below; it simply does not describe production, which runs with noise.
> With the noise on, the loss **is** a rate — measured, ratio 4.04 for 4× the
> steps. So the original operational advice was right about production even though
> the evidence originally offered for it (flatness in resolution) never supported
> it.
>
> | condition | behaviour | evidence |
> |---|---|---|
> | noise **off** | one-off, equal to the seed's out-of-C weight | tables below |
> | noise **on** | **a rate** | ratio 4.04 at 4× steps, $\gamma = 0$ |
> | flatness in resolution | supports **neither** — a one-off is flat too | — |

The term is a real phase and cannot change $\int|\psi|^2$; production calls
`apply_spgpe_step!`, which also projects, and there $\psi e^{i\phi}$ can carry
weight past $k_\mathrm{cut}$ for the projector to remove. The question is whether
that removal is a **rate** (paid every step, so it competes with growth) or a
**one-off** (paid once, on whatever the seed had outside the C region).

Those two look identical at a single endpoint. They are separated by attacking the
mechanism rather than matching the symptom: **start from a pre-projected seed**,
$\mathcal P\psi_0 = \psi_0$, and vary the seed's out-of-C weight.

Measured 2026-08-20, 48³ box 18, $k_\mathrm{cut} = 5.5$ (so
$k_\mathrm{max}/k_\mathrm{cut} = 1.52$, #334's own ratio), $\bar{\mathcal M} =
1.63\times10^{-3}$, $T = 5$, **noise off**, 400 steps:

| seed | out-of-C weight | first step $\Delta N/N$ | per step after | total |
|---|---:|---:|---:|---:|
| **pre-projected** | $6\times10^{-32}$ | $1.9\times10^{-16}$ | $2.7\times10^{-16}$ | $\mathbf{1.1\times10^{-13}}$ |
| small out-of-C | $1.0\times10^{-4}$ | $\mathbf{1.0\times10^{-4}}$ | $2.6\times10^{-16}$ | $1.0\times10^{-4}$ |
| large out-of-C | $9.9\times10^{-3}$ | $\mathbf{9.9\times10^{-3}}$ | $2.6\times10^{-16}$ | $9.9\times10^{-3}$ |
| large, $2\,dt$, half the steps | $9.9\times10^{-3}$ | $9.9\times10^{-3}$ | $2.6\times10^{-16}$ | $9.9\times10^{-3}$ |

Three independent readings, all one-off:

- **Pre-projecting the seed removes the loss entirely** — $10^{-13}$ over 400
  steps, i.e. rounding. That is causal, not a coincidence of symptoms.
- **The step is equal to the seed's out-of-C weight**, to three digits, across two
  decades of it.
- **The cumulative loss saturates at step 1** and does not move through step 400;
  doubling $dt$ changes nothing.

The steady residual after the first step is $2.6\times10^{-16}$ per step — machine
precision, not a small rate.

**Why it was read as a rate.** The earlier measurement went through
`apply_spgpe_step!` with a `tracking_cutoff`, which by design moves every step. A
moving cutoff **creates fresh out-of-C content each step**, so the one-off is paid
again and again and the cumulative curve is a straight line. The flatness in
resolution that was taken as evidence of a scheme property is what a one-off does
too. #351 reached the same retraction independently and stated the general form:
*flatness is what a one-off necessarily shows*.

#### With the noise on, it is a rate

Everything above is the **noise-off** sub-case. Production runs with noise, so the
question has to be asked there too, and the earlier version of this section never
did — it turned the noise off for a good reason (it makes a single endpoint a
random variable) and then generalised past the condition it had measured.

The arm that settles it starts from a **pre-projected** seed, so the one-off is
already paid and cannot be mistaken for what follows, sets $\gamma = 0$ so nothing
physical can move $N$, and compares two durations, averaged over seeds:

| steps | $\Delta N/N$ |
|---:|---:|
| 50 | $1.0853\times10^{-4}$ |
| 200 | $4.3821\times10^{-4}$ |
| **ratio** | **4.04** (exact proportionality would give 4.00) |

A one-off returns the same number at both durations. This scales with them.

**Consequences.** A growth problem with noise on **does** pay a continuing number
loss through the projector, so `energy_damping=false` remains the conservative
choice for one — #334's ensemble is not invalidated. The measured stall is
consistent with it: the full theory on #334's own ramp holds $N_C$ flat at
$f = 0.065$ where growth-only reaches $0.37$, and **pinning the cutoff does not
restore the growth** (3266 against 3271 at matched simulated time), which rules
out cutoff motion as the mechanism and leaves the noise channel.

Independently of the noise, a run still needs a seed inside its own C region —
project it once before starting — and, if `tracking_cutoff` is used, awareness
that each cutoff change bills the band it swept past. That is a physical outflow
(`cutoff_outflow` reports it separately from `noise_truncated`) and not a defect,
but it is not free.

Gated by `test/dynamics/test_spgpe.jl`, which asserts the CLASSIFICATION in both
sub-cases — noise off: step proportional to out-of-C weight, tail at rounding,
pre-projected seed flat; noise on: the duration ratio above 3 — rather than
pinning the numbers.

Known limits, unchanged by this work:

- The classical field is **cutoff-dependent**; absolute equilibrium $N_0$ is not a
  converged observable (see [eu_shape_finite_t.md](eu_shape_finite_t.md)).
- Reservoir rates are the **scalar** (single-component) forms applied per spinor
  component. The spinor generalisation (Bradley & Blakie, [arXiv:1406.2029]) has
  component-resolved rates; for a single stretched state, which is what the Eu
  evaporation runs use, the distinction does not arise.
- $\gamma$ and $\bar{\mathcal M}$ are taken **spatially uniform**, as in Rooney
  §III D 1. A local-density $\gamma(r)$ is a straightforward extension.
- **Measure $N_0$ as an overlap with the condensate mode**, not as the occupation
  of the largest single $k$-mode. A trapped condensate spreads over
  $|k|\lesssim1/R_\mathrm{TF}$, several grid modes wide; the peak mode understated
  $N_0$ by $22\times$ here and turned a working solver into a reported failure.
- The growth budget's efficiency $\eta\approx1/3$ is calibrated on one static
  test. It is an order-of-magnitude gate, not a predictor — treat $G_\mathrm{eff}$
  as "this window cannot possibly work" when short, not as a guarantee when large.
- **Grand-canonical: $\mu$ is an input and it fixes $N_0$.** Below $\varepsilon_0$ no
  condensate is possible; above it the equilibrium size follows from
  $\mu=\varepsilon_0+c_0n_0$. `mu_branch=:thermal` does not escape this — it caps
  $\mu$ at $0<\varepsilon_0$ and forbids condensation outright. Atom-number questions
  need a number-conserving formulation, which is not implemented.
