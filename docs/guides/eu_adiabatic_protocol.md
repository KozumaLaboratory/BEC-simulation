# Adiabatic-passage protocol for the weak-field ¹⁵¹Eu ground-state transition

Design of a *ground-state* experiment for the weak-field F=6 Eu + DDI transition:
ramp $B_z$ through the transition in both directions at several rates and read the
result out with Stern-Gerlach. This is the static counterpart of the Einstein–de
Haas measurement — EdH is a quench (dynamics); this asks whether the
chiral/flower phase can be *prepared* as a ground state.

## What is being claimed, and what would falsify it

The transition **order is set by the trap oblateness** $\kappa = \omega_z/\omega_\perp$,
with a tricritical point at $\kappa_{tc} \approx 0.95$:

| $\kappa$ | behaviour | evidence |
|---|---|---|
| $\le 0.9$ | crossover — one branch, $\delta\langle F_\perp\rangle \approx 0$ | grad-gated up/down sweeps agree to $10^{-3}$ |
| $\ge 1.0$ | bistable — two converged branches | $\delta\langle F_\perp\rangle \sim 0.1$ at onset |
| $1.8$ | clean first order, $B_{eq} = 61.9\ \mu$G | $\Delta E(B)$ sign flip, $\delta\langle F_\perp\rangle = 1.7$ |

Two numbers that are easy to mis-quote: **58–60 µG is saturation, not a
transition** ($E$, $dE/dB$ smooth; $\chi = -dF_z/dB$ collapses $0.11 \to 0.002$),
and there is **no single universal transition field** — a protocol has to name its
$\kappa$. A spherical trap ramped through 40 µG measures a crossover and sees no
hysteresis by construction.

That $\kappa$ dependence is what makes the prediction falsifiable with existing
apparatus: **the same ramp at two trap aspect ratios must give a loop at
$\kappa \gtrsim 1$ and none at $\kappa \le 0.9$.**

## Why rate dependence, not a single ramp

A ramp shows a loop for three different reasons, and only the rate scan separates
them:

| observation | conclusion |
|---|---|
| loop width shrinks as $\tau$ grows, $\to 0$ | dynamical lag — the ramp was too fast |
| loop width **saturates** at large $\tau$ | bistability: the metastable branch survives to its spinodal |
| no loop at any $\tau$ | crossover |

Two converged minima with a barrier are bistability, *not* by themselves a
first-order transition (ferromagnet coercivity is the counter-example). The
saturated loop width is the mean-field spinodal separation; the static
$\delta\langle F_\perp\rangle$ from the ground-state library is its $\tau\to\infty$
target.

## Running it

Both scripts read the converged GS library (`figs/eu_gs_library/`, keyed
`(grid, κ, B, branch)`); run them from the repo root that holds it.

```bash
# 1. static window analysis — seconds. Where to ramp, and the Larmor bound.
AR_KAPPAS=1.8,1.4,1.0,0.8 julia --project=. scripts/eu_adiabatic_window.jl

# 2. smoke every code path first (≤ 2 min on GPU)
LD_LIBRARY_PATH=/usr/lib/wsl/lib AR_SMOKE=1 \
  julia --project=. scripts/eu_adiabatic_ramp_protocol.jl

# 3. production: κ = 1.8 (first order) then κ = 0.8 (control), ~2.5 h each
bash scripts/run_eu_adiabatic_ramp.sh          # → logs/eu_adiabatic_ramp.log

# 4. figures
python scripts/viz_eu_adiabatic_ramp.py
```

`eu_adiabatic_window.jl` reports, per $\kappa$: the energy crossing $B_{eq}$, the
field range over which the branches stay distinct, each branch's converged
extent, and the Larmor bound. It flags when the distinct-branch range is
**data-limited** — if the branches are still separated at the edge of the library
(they are at $\kappa = 1.8$, $\delta\langle F_\perp\rangle$ only falling
$1.83 \to 1.52$ across 60–64 µG), the spinodals lie outside the static data and
the ramp has to run past it. Dynamics can; ITP from a fixed anchor cannot.

Each ramp is seeded from the branch that is metastable in its own direction:

| leg | seed | ramp | probes |
|---|---|---|---|
| `rise` | flower (library branch `up`), low $B$ | $B$ up | upper spinodal |
| `fall` | polarised (branch `dn`), high $B$ | $B$ down | lower spinodal |

## Numerical settings that are load-bearing

- **`split_step_midpoint!`, not `run_simulation!`.** Plain Strang is *first order
  in time* whenever DDI is active (the mean field is frozen at the $V$-step
  boundary), which a long ramp accumulates. The driver runs its own loop over the
  midpoint stepper for that reason.
- **Orszag 2/3 dealiasing OFF at 32³ / box 24**, against the general Eu-DDI
  recommendation. The 2/3 cutoff there is $k_{cut} = 2.62$ while the occupied band
  reaches $k \approx \sqrt{2\mu} \approx 4.3$ — the filter removes physically
  occupied modes, and measurably: with it on, $|\psi|^2$ bleeds $\approx 3\times10^{-6}$
  per step with no front-loading ($\approx 17\%$ over a $\tau = 100$ ramp). The
  library seeds were converged without it too. With it off, $|\psi|^2$ drift is
  $5\times10^{-13}$ and $J_z$ drift $2\times10^{-6}$ over a test ramp. Re-enable
  (`AR_DEALIAS=1`) only on a grid whose 2/3 cutoff clears the occupied band.
- **$dt = 0.002$.** $\langle F_\perp\rangle$ at the end of a test ramp agrees to
  three digits between $dt = 0.004$ and $dt = 0.001$.
- **Seed/preset assertion.** The driver aborts if the stored
  $(c_0, c_1, c_{dd}, p)$ of a library state disagree with the preset it rebuilds.
  A silent mismatch would put one parameter epoch's state into another's
  Hamiltonian: the seed would not be stationary and the rate scan would be
  measuring that transient instead of the ramp.

## The Larmor bound is not the constraint

The Goldstone pin $b_x = \varepsilon$ is held at the value each seed was converged
with, so the seed is stationary at $t = 0$; physically it is the residual
transverse lab field. The field-following bound it implies (spin tracks the
tilting quantisation axis, $\omega_L \gg \dot\theta$, via
`adiabaticity_trajectory`) comes out at $\tau \gtrsim 8\ \mu$s at $\kappa = 1.8$
and $\lesssim 0.7$ ms at $\kappa = 0.8$ — three or more orders below any plausible
ramp. **Ramp-speed design is therefore set entirely by the collective texture
rearrangement timescale**, which has no closed form here and is what the rate scan
measures.

## Limits of the present run

- **Grid 32³** — the library's grid. 32³ and 64³ agreed to < 1 % on early-time Eu
  dynamics, but the loop width itself is not yet grid-checked.
- **Mean field at $T = 0$.** No thermal or technical noise, so the measured loop is
  the *upper bound* on what an experiment sees: noise and finite temperature
  nucleate the stable branch early and narrow the loop.
- **$\varepsilon$ is small.** The pin is 0.068 µG at $\kappa = 1.8$ and 0.135 µG at
  $\kappa = 0.8$ — *below* realistic transverse-field nulling. Scanning $\varepsilon$
  upward to the µG scale is the natural follow-up and is the same calculation as
  the magnetic-shielding specification (how well must $B_\perp$ be nulled for the
  loop to survive).
- **LHY** is off. The F=6 spinor LHY table is incomplete (`PolarTwoChannelLHY` is
  30–70 % off at F=6); the seeds were converged without it, so the protocol is
  internally consistent but inherits that model limitation.
