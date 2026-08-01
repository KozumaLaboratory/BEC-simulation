# RK4IP on GPU: correct to round-off, and worth taking only below ~1e-5

Measured 2026-08-02 on an H100 (UGE 8316108 / 8316433 / 8316492) and a local
RTX 5070 Ti. Commits `e6084559` … `9af38974`, clean `src`. Type A.

> **Two earlier framings in this branch were wrong and are retracted at the
> bottom.** The short version: accuracy and cost were collapsed into a single
> "net speedup" built from measurements taken on different problems.

## 1. Correctness transfers

One RK4IP step, GPU against CPU from the same start, Eu F=6 (D=13), DDI on and
zero-padded:

| n | total rel L2 | worst component |
|---|---|---|
| 16 | 5.5×10⁻¹⁶ | 5.9×10⁻¹⁶ |
| 32 | 6.9×10⁻¹⁶ | 7.2×10⁻¹⁶ |

Round-off in every one of the 13 channels, on both cards. RK4IP had never been
executed on a GPU before this, so it was not a given that every HamTerm's
`apply_operator!` face had a GPU path — they all do. Compared per component
because a term missing its GPU path can contribute nothing to the aggregate
while being wrong in one m channel.

## 2. The two axes, kept apart

### Axis 1 — same `dt`: RK4IP is more accurate and dearer

H100, 64³, at `dt = 7.81×10⁻⁴` (the sampled step nearest production's 1e-3):

- **7090× more accurate** (1.25×10⁻¹⁰ against 8.88×10⁻⁷ relative L2 over T = 0.05)
- **3.28× the cost per step**

If the extra accuracy is not needed, that is the whole story and it is a loss.
For the Fig. 4B observable it is not needed: `dt = 1e-3` is converged there to
0.0001 nT (`matsui_residual_root_cause.md`), so every one of those 7090× is
unspendable.

### Axis 2 — same accuracy: time to solution

Both halves measured at 64³ on the H100, every row a genuine two-sided
interpolation:

| error budget | rk4ip `dt` | split_step! `dt` | step ratio | **time ratio** |
|---|---|---|---|---|
| 1e-3 | 4.23×10⁻² | 2.62×10⁻² | 1.62 | **0.49×** |
| 1e-4 | 2.34×10⁻² | 8.29×10⁻³ | 2.82 | **0.86×** |
| 1e-5 | 1.31×10⁻² | 2.62×10⁻³ | 5.00 | **1.53×** |
| 1e-6 | 7.38×10⁻³ | 8.29×10⁻⁴ | 8.90 | 2.71× |
| 1e-7 | 4.15×10⁻³ | 2.62×10⁻⁴ | 15.84 | 4.83× |

**Break-even sits between 1e-4 and 1e-5.** Above it — looser tolerances — RK4IP
costs more wall-clock for the same answer.

## 3. What depends on `n`, and what does not

**Accuracy does not.** The error columns at 64³ and 128³ agree to the digits
printed:

| `dt` | split_step! @64³ | split_step! @128³ |
|---|---|---|
| 3.91×10⁻⁴ | 2.220×10⁻⁷ | 2.220×10⁻⁷ |
| 7.81×10⁻⁴ | 8.878×10⁻⁷ | 8.878×10⁻⁷ |
| 1.56×10⁻³ | 3.551×10⁻⁶ | 3.551×10⁻⁶ |

Refining the grid at fixed box does not change the time-discretisation error
here, because the state is smooth and the added high-`k` modes are empty. (The
plausible-sounding argument that Strang's `[K,[K,V]]` grows with `k_max²` and so
the step ratio must move with `n` is therefore **not** what happens for this
problem. It was the stated reason for re-measuring; it did not survive.)

**Cost does.** ms/step, `split_step!` / `split_step_midpoint!` / `rk4ip_step!`:

| device | n | split_step! | midpoint | rk4ip | rk4ip vs split |
|---|---|---|---|---|---|
| CPU | 12 | 3.00 | 4.46 | **2.61** | **0.87×** |
| H100 | 32 | 0.62 | 0.92 | 4.63 | 7.44× |
| H100 | 64 | 2.75 | 4.04 | 9.05 | 3.28× |
| H100 | 128 | 25.10 | 36.73 | 72.04 | 2.87× |
| RTX 5070 Ti | 128 | 175.21 | 257.83 | 258.15 | 1.47× |

**On CPU RK4IP is cheaper per step; on the H100 it is 2.9–7.4× dearer.** The
mechanism is the interaction picture: RK4IP applies `e^{K dt/2}` **four times per
step** (`rk4ip.jl:143, 144, 162, 167`) where Strang applies `e^{K dt}` **once**
(`split_step.jl:96`), and each is an FFT pair. On CPU the mean-field and DDI work
dominates — and the default is itself paying for a predictor-corrector, since
`split_step!` auto-dispatches to `_half_potential_step_midpoint!` whenever DDI is
active — so the 4× hides. On GPU the FFTs dominate and it is the whole cost. The
gap *widens* as `n` falls because the FFTs go launch-bound: four launches to one.

Because accuracy is `n`-independent and cost is not, the break-even budget moves
with grid size. Composing the measured 64³ step ratios with each measured cost
ratio:

| budget | 32³ | 64³ | 128³ |
|---|---|---|---|
| 1e-4 | 0.38× | 0.86× | 0.98× |
| 1e-5 | 0.67× | **1.53×** | **1.74×** |
| 1e-6 | **1.20×** | 2.71× | 3.10× |

Break-even ≈ 1e-6 at 32³, ≈ 2×10⁻⁵ at 64³, ≈ 1×10⁻⁴ at 128³.

## 4. Memory

Five full-state scratch buffers, 436 MB each at 128³ F64 D=13. Measured
allocator high-water for one step, which also carries the padded DDI transforms
each of the four registry passes triggers:

| device | n | high-water | of total |
|---|---|---|---|
| H100 | 128 | 12.88 GiB | 14 % of 93.1 |
| RTX 5070 Ti | 128 | 4.78 GiB | **30 % of 15.9** |
| H100 | 64 | 2.56 GiB | — |

## 5. Conclusions

- **Not a default.** Production runs at roughly the 1e-4 accumulated-error scale,
  which is on the losing side of break-even at every grid size measured.
- **Keep it opt-in** (`integrator: rk4ip`) and select it when the tolerance is
  tight — below ~1e-5 at 64³ and above — or on CPU, where it is cheaper per step
  outright.
- The lever is the kinetic count. Four half-exponentials is intrinsic to the
  standard RK4IP formulation; going below it means a different scheme.

## 6. Retracted

**"Order 2 → 4 at equal cost."** From counting mean-field evaluations on CPU. The
count was right and irrelevant: on GPU the kinetic FFTs dominate and RK4IP does
four of them per step.

**"Net 2.7× at a 1e-4 budget, 4.9× at 1e-5."** Built by dividing a step ratio
measured on a **12³ CPU** config by a cost ratio measured on a **128³ GPU**
config. Those do not compose — the cost ratio is strongly `n`-dependent. The
measured 128³ figures are 0.98× and 1.74×.

**"The step ratio is strongly size-dependent, which is why this had to be
re-measured."** Argued from `[K,[K,V]] ~ k_max²`. Measured: the error columns at
64³ and 128³ are identical. The re-measurement was still necessary, but for the
cost ratio, not the step ratio.

**A capped crossing reported as a measurement.** The first 64³ run's sweep did
not go coarse enough for either integrator to leave a 1e-3 or 1e-4 budget, and
`crossing` returned the coarsest sample — printing "we did not look far enough"
as a number. The script now tags each row `measured` / `LOWER BOUND` and the
sweep was extended two octaves.
