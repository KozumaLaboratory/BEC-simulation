# Matsui Fig. 2C — reproduction, and what the atom number says

Type A (code correctness) for §1; type C (model fidelity) for §3–4.
Produced at `5b703994` on `research/matsui-fig2c`. Numbers in §1 come from a
run; §2–4 are read off the published fixtures and need no run.

Fixtures: `test/fixtures/matsui2025/dataset_fig2_{exp,theo}.csv`, extracted from
Zenodo 17303925 (CC-BY-4.0). Read them with a 14-column parser, **not**
`readdlm` — the headers contain embedded newlines, which shifts every column.

## 1. We reproduce their simulation across the whole time series

`runs/matsui_fit/fig2c_n35k.yaml`, N = 3.5e4, B = 2.6 nT, 40 ms, loss-free —
their conditions. Against `dataset_fig2_theo.csv`, sampled every 0.5 ms:

| component | mean | rms | max |
|---|---|---|---|
| m = −6 | +0.0008 | 0.0063 | 0.0142 |
| m = −5 | −0.0031 | 0.0093 | 0.0204 |
| m = −4 | +0.0025 | 0.0072 | 0.0205 |
| m = −3 | −0.0015 | 0.0078 | 0.0211 |
| m = −2 | +0.0015 | 0.0063 | 0.0207 |
| **all five** | | **0.0075** | |

The criterion was recorded in the config before launch: < 0.02 establishes the
reproduction, > 0.05 says the conditions are still mismatched. An earlier arm at
N = 5e4 sat at rms 0.109, so the entire gap was the atom number.

This is the third independent dataset to agree — Fig. 4B's 45-field dip at
per-field rms 1.1 %, the 5 ms column density on five observables at 0.3–4 %, and
now the 40 ms time series at 0.0075.

## 2. The published experimental data carries the atom number

`dataset_fig2_exp.csv` rows sum to 4.478e4 at t = 0 and 2.811e4 at t = 40 ms —
a 37.2 % decay, i.e. the paper's 38 %. The theory rows sum to exactly 5e4 at
every time, because that model is loss-free.

Normalising each row to its own sum, which is what a "population fraction"
comparison does, **divides that decay out**. Every discrepancy it then reports
is contaminated by it. The comparison in the first draft of this arc did exactly
that and manufactured its own headline result.

Three different atom numbers are in play and none of them is wrong:

| | value | what it is |
|---|---|---|
| shipped `setup_parameters` | 3.5e4 | the couplings their simulation actually ran |
| theory curve normalisation | 5.0e4 | what the published curve is scaled to |
| experiment, t = 0 row sum | 4.478e4 | the measured initial number |

## 3. In absolute number, m = −6 is the component that agrees best

Same data, same simulation; only the normalisation differs.

| m = −6, over 1–40 ms | rms | mean |
|---|---|---|
| as a fraction of the **surviving** atoms | 0.2633 | +0.2426 |
| as a fraction of the **initial** number | **0.0942** | +0.0709 |

The 0.263 that this arc set out to explain is 2.8× inflated by the choice of
denominator. What survives — the experiment retaining ~7 % more m = −6 than the
loss-free model — is real, and is the same sign as the Fig. 4B residual: the
simulation drives the cascade out of m = −6 harder than the experiment does.

## 4. The loss sits entirely outside m = −6

Simulation minus experiment at 40 ms, both as a fraction of their own initial
number. Positive = the experiment is missing atoms there.

| m | −6 | −5 | −4 | −3 | −2 | −1 |
|---|---|---|---|---|---|---|
| deficit | **−0.0236** | +0.0463 | +0.1632 | — | +0.1663 | +0.0509 |

Of the 0.4297 total deficit, **0.0 % is in m = −6** — the experiment has 0.0236
*more* m = −6 than the loss-free model, not less. 0.4267 of it is in m = −5,
−4, −2, −1.

That is the paper's own statement, made quantitative:

> the atoms were likely to be lost in three-body collisions involving atoms
> **not** in the m = −6 component

!!! warning "One arm of this is a tautology — do not quote it"
    Σ(sim − exp) over all 13 components equals the measured loss *identically*,
    because the simulation's row sums to 1 by construction and the experiment's
    sums to 1 − L. "The budget closes to 1.000 at every time" is arithmetic, not
    evidence. The evidence is the **breakdown** above: nothing forced the deficit
    to avoid m = −6, and it does.

## 5. The calibrated loss explains m = −4 and m = −2, and not m = −6

`runs/matsui_fit/fig2c_loss.yaml` — the §1 run with `K3 = 2.6e-28 cm^6/s` on the
twelve m ≠ −6 components, calibrated to the paper's 26 %/40 ms. No free
parameters. It delivers 20.0 % loss over 40 ms against that 26 % target (the
calibration was taken at a single field under different conditions); the
experiment lost 37.2 %.

rms against the experiment, in absolute number, 1–40 ms:

| component | loss-free | with loss | change |
|---|---|---|---|
| m = −6 | 0.0926 | 0.0986 | **−6 %** |
| m = −5 | 0.0473 | 0.0443 | +6 % |
| m = −4 | 0.1497 | 0.1148 | **+23 %** |
| m = −3 | 0.0497 | 0.0476 | +4 % |
| m = −2 | 0.1667 | 0.1153 | **+31 %** |
| all five | 0.1127 | 0.0899 | +20 % |

That is exactly the paper's split — m = −4 and m = −2 are the components it names
as loss-free casualties, and they are the two the loss moves. m = −6 gets
slightly worse.

!!! warning "The pre-recorded criterion was invalidated by §3, not by this run"
    It read: *pass if m = −6's rms falls below 0.10 while m = −5 and m = −3 stay
    below 0.08*. All three hold — but m = −6 was **already** at 0.0926 loss-free,
    so the threshold sits below the starting value and the test cannot fail. It
    was written when the m = −6 rms was believed to be 0.263. A criterion is only
    binding against the number the instrument actually reports, and that number
    changed between writing it and running.

### Why loss cannot close m = −6

In absolute number the experiment holds **more** m = −6 than the loss-free model
(+0.024 at 40 ms), and removing atoms from m ≠ −6 moves ours the wrong way:
0.350 → 0.318. Loss raises the m = −6 *fraction* (0.350 → 0.397) but not its
*count* — atoms leave m = −6 by transfer, and only become vulnerable afterwards.
A larger `K3` widens the gap rather than closing it.

So the residual is in the transfer, not the loss: the cascade out of m = −6 runs
faster in the simulation than in the experiment. Same statement, same sign, as
the Fig. 4B residual.

## What is left


The experiment retains ~7 % more m = −6 (of the initial number) than the
loss-free simulation, growing with time. Two candidate readings, not yet
separated:

- the cascade out of m = −6 is genuinely slower in the experiment, or
- three-body loss depletes the density, weakening the dipolar drive `c_dd·n`
  that pumps the cascade.

§5 measures the second and rejects it: the calibrated loss moves our m = −6
count *away* from the experiment. The first is what remains. Neither a pure
renormalisation nor a density-weakened drive accounts for it — under uniform
removal from m ≠ −6 the internal ratios of those components would be preserved,
and in the published data they are not (rms 0.178, larger than the raw
discrepancy it would have to explain).

Not yet tested: whether the transfer rate itself is over-driven, i.e. whether
`c1_ratio`, `q`, or the dipolar drive is set too strong for the experiment. That
is a different arm from anything run so far — every arm to date fixed those at
the values their simulation ships.
