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

**What is and is not predicted.** Below $T_c$ the reservoir $\mu$ is pinned by
the condensate, so prescribing $\mu(t)$ from the 0-D $N_0$ ties the c-field's
*equilibrium* population to the 0-D answer by construction — the absolute $N_0$
is a consistency check, not an independent measurement. What is independent is
the **lag**: growth proceeds at finite $\gamma$, so a ramp faster than $1/\gamma$
leaves the condensate behind its quasi-static value. The 0-D model cannot produce
that gap at all, and it is what decides whether an "optimised" fast ramp actually
delivers atoms.

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

## Cost — why this is now affordable

Second-scale runs were previously written off as out of reach. The binding
constraint was not physics but the noise draw: `_sgpe_add_noise!` generated every
random number on the **host** and copied it across PCIe each step. Measured at
$48^3$/D=3 on an RTX 5070 Ti (parts reconciled to the whole within 1 %):

| | before | after |
|---|---|---|
| unitary `split_step!` | 0.45 ms | 0.45 ms |
| dissipative sub-step | **21.1 ms** (88 % of it host RNG) | **2.4 ms** — *and it now also does energy damping* |
| noise alone | 18.5 ms | 0.53 ms |

The fix is `_randn_fill!`, dispatched on the backend, with a CURAND
implementation in the CUDA extension (`ext/SpinorBECCUDAExt/gpu_rng.jl`). The CPU
path draws from `rng` in the same order as before, so existing seeded streams are
bit-identical; GPU reproducibility is **per trajectory**, seeded with
`seed_device_rng!`, not per step.

Budget: a full 1.5 s ramp at $64^3$ is ~0.55 h per trajectory with the reservoir
applied every 5 steps. The 0.714 s Eu window at $80^3$ is ~0.5 h per trajectory.

## Validation

`test/dynamics/test_spgpe.jl` (ci tier), `test/dynamics/test_spgpe_reservoir.jl`
(full tier), `test/gpu/test_spgpe_gpu_cpu_parity.jl` (ci tier).

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

Known limits, unchanged by this work:

- The classical field is **cutoff-dependent**; absolute equilibrium $N_0$ is not a
  converged observable (see [eu_shape_finite_t.md](eu_shape_finite_t.md)).
- Reservoir rates are the **scalar** (single-component) forms applied per spinor
  component. The spinor generalisation (Bradley & Blakie, [arXiv:1406.2029]) has
  component-resolved rates; for a single stretched state, which is what the Eu
  evaporation runs use, the distinction does not arise.
- $\gamma$ and $\bar{\mathcal M}$ are taken **spatially uniform**, as in Rooney
  §III D 1. A local-density $\gamma(r)$ is a straightforward extension.
