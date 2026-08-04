# Matsui Fig. 2C — reproduction, and what the atom number says

> **FROZEN 2026-08-04.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

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

## 6. The transfer rate: `c1_ratio` is excluded, `q` dominates

Four arms, two points per parameter around their shipped values — a sensitivity
table, not a scan (`runs/matsui_fit/xfer_*.yaml`, tasks 50–53). rms against the
experiment in absolute number, 1–40 ms; the number to move is m = −6's 0.0926.

| arm | c₀ / c₁ | m = −6 | m = −5 | m = −4 | m = −3 | m = −2 |
|---|---|---|---|---|---|---|
| **baseline** r = 1/36, q = 1 Hz | 1640.5 / 45.57 | **0.0926** | 0.0473 | 0.1497 | 0.0497 | 0.1667 |
| r = 1/72 | 2187.4 / 30.38 | 0.1408 | 0.0710 | 0.1630 | 0.0573 | 0.0408 |
| r = 1/9 | 656.2 / 72.91 | 0.1292 | 0.1563 | 0.1462 | 0.0509 | 0.0377 |
| q = 0 | 1640.5 / 45.57 | **0.0726** | 0.0531 | 0.2238 | 0.0467 | 0.0653 |
| q = 10 Hz | 1640.5 / 45.57 | 0.3105 | 0.0387 | 0.1916 | 0.1136 | 0.1151 |

`c₀` and `c₁` are not independent — `a_s` fixes both through
`c₀ + 36c₁ = c_total` — so both are quoted. The `r = −1/36` singularity is far
from every candidate.

**`c1_ratio` is excluded.** It makes m = −6 worse in *both* directions, by +0.048
and +0.037 across a factor of 8 in `r`. Their 1/36 is a local optimum for this
observable, and no value of `c1_ratio` brings m = −6 to the experiment. That is
consistent with the independent ring-count bound (0.0139 < r ≤ 0.0278) and with
the earlier finding that `c1_ratio` does not move the Fig. 4B dip either.

**`q` dominates.** 0 → 10 Hz moves m = −6's rms from 0.073 to 0.311 monotonically,
and the depolarisation runs 1.4–1.8× faster at 10 Hz at every time sampled. Their
code supplies `ZeemanQ = 1.0 Hz` as a **literal**, where B = 2.6 nT implies
q/h ~ 10⁻⁶ Hz. That discrepancy was already on the books; this is the first
measurement of what it costs.

!!! warning "The `q` arms confound rate with detuning"
    `q` also moves the resonance **position** — q/h = 1 Hz shifts the m = −6 → −5
    spacing by 11 Hz out of 42.3, i.e. 0.68 nT of resonance position. Held at
    B = 2.6 nT, these two arms changed the detuning as well as the rate. So
    *"q is the sensitive knob"* is established and *"the transfer is over-driven
    because q is wrong"* is not.

    `xfer_q0_b{m,p}` bracket the shift without assuming its sign: q = 0 at
    B = 1.92 and 3.28 nT. Criterion recorded before launch — the better of the two
    landing near 0.073 makes the improvement a rate effect, near 0.093 makes it a
    detuning effect and clears `q`.

    Also recorded there: the effective field comes from the **scan override**
    `pipeline.1.B.Bz.to`, and the inline pipeline `to:` is overwritten. The first
    draft of those two configs patched only the inline value, which would have run
    both arms at 2.6 nT.

## 7. And none of it is resolvable — the field systematic dominates

`xfer_q0_b{m,p}` bracket q = 0 across ±0.68 nT, the shift q/h = 1 Hz imparts to
the resonance. m = −6's rms, over 1.36 nT of field at fixed q = 0:

| B [nT] | 1.92 | 2.60 | 3.28 |
|---|---|---|---|
| m = −6 rms | 0.1142 | **0.0726** | 0.1080 |

The observable moves **0.0416 over 1.36 nT**. The effect of `q` that this arm set
out to interpret — 0.0926 at their 1 Hz vs 0.0726 at 0 — is **0.0200, i.e. 48 % of
that**. And the paper quotes up to **10 nT of offset error** on the field axis
(Fig. 4 caption), 7.4× the range just scanned.

So the pre-recorded criterion resolves, but not to either branch it anticipated:
the better bracket point is 0.1080, neither the 0.073 that would have made the
improvement a rate effect nor the 0.093 that would have made it detuning. The
reading is the third possibility — **a single-field time series cannot constrain
any of these parameters**, because the observable's dependence on the field
within the quoted systematic exceeds every parameter effect measured.

That is gate 3 of `CLAUDE.md` arriving one step late: the systematic was written
down for the Fig. 4B *dip* comparison, where it is handled correctly (a dip
*width* is invariant under an offset; a dip *centre* is not, which is why the
centre was never quoted as agreement). A single-field cut through that dip
inherits the offset with nothing to average it out.

**What this closes and what it does not.** The transfer-rate line of attack is
closed at this observable: `c1_ratio` is excluded on its own merits (worse in
both directions, §6), and `q` cannot be assessed here at all. What remains sound
is the dip-shape comparison, which is offset-invariant: our width and theirs
agree to 0.10 %, and both miss the experiment's by 14–15σ with the two residual
patterns correlated at 0.9705. That is a statement about their model against
their experiment, and no parameter of ours enters it.

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
