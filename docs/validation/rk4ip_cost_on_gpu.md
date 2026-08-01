# RK4IP: the CPU cost result does not transfer to the GPU

Measured 2026-08-02. `scripts/validation/rk4ip_gpu_cost_probe.jl`, commit
`e6084559`, clean `src`. UGE 8316108 (H100) and a local RTX 5070 Ti. Type A.

## Correctness first

One RK4IP step, GPU against CPU from the same start, Eu F=6 (D=13), DDI on and
zero-padded:

| n | total rel L2 | worst component |
|---|---|---|
| 16 | 5.5×10⁻¹⁶ | 5.9×10⁻¹⁶ |
| 32 | 6.9×10⁻¹⁶ | 7.2×10⁻¹⁶ |

Round-off in every one of the 13 channels, on both cards. **Every HamTerm's
`apply_operator!` face already had a GPU path** — RK4IP had never been executed
on a GPU before this, so that was not a given. Compared per component because a
term missing its GPU path can contribute nothing to the aggregate while being
wrong in one m channel.

## Cost, and the reversal

ms/step, `split_step!` / `split_step_midpoint!` / `rk4ip_step!`:

| device | n | split_step! | midpoint | rk4ip | rk4ip vs split |
|---|---|---|---|---|---|
| CPU | 12 | 3.00 | 4.46 | **2.61** | **0.87×** |
| RTX 5070 Ti | 128 | 175.21 | 257.83 | 258.15 | 1.47× |
| H100 | 128 | 25.13 | 36.73 | 72.07 | **2.87×** |
| H100 | 64 | 2.77 | 4.04 | 9.16 | 3.30× |
| H100 | 32 | 0.62 | 0.92 | 4.63 | 7.44× |

**On CPU RK4IP is cheaper per step than the default; on the H100 it is 2.9×
dearer.** The sign of the comparison flips with the backend.

### Why

RK4IP applies `e^{K dt/2}` **four times per step** — `rk4ip.jl:143, 144, 162,
167` — where Strang applies `e^{K dt}` **once** (`split_step.jl:96`). Each is an
FFT pair.

On CPU the mean-field and DDI work dominates a step, and the default is itself
paying for a predictor-corrector (`split_step!` auto-dispatches to
`_half_potential_step_midpoint!` whenever DDI is active), so the 4× kinetic cost
is invisible and RK4IP wins. On a GPU the FFTs dominate and that 4× is the whole
story. The gap widens as `n` falls, which is the same effect: at 32³ the FFTs are
launch-bound and RK4IP is paying four launches to Strang's one.

## Net

Net speedup = the step RK4IP holds under a fixed error budget
(`rk4ip_step_size_probe.jl`) divided by the cost above.

| device / n | at 1e-4 (step 2.4×) | at 1e-5 (step 4.2×) |
|---|---|---|
| CPU 12³ | 2.7× | 4.9× |
| RTX 5070 Ti 128³ | 1.6× | 2.9× |
| **H100 128³** | **0.84× — a net loss** | **1.46×** |

The step ratios are CPU-measured. They are a property of the method and the
problem's stiffness rather than of the hardware, but they have not been
re-measured on GPU, so the H100 row is the cost measurement combined with a CPU
accuracy measurement and should be read as an estimate.

## Memory

Five full-state scratch buffers: 436 MB each at 128³ F64 D=13, so 2.2 GB
nominal. Measured allocator high-water across one step, which also carries the
padded DDI transforms the four registry passes each trigger:

| device | n | high-water | of total |
|---|---|---|---|
| H100 | 128 | 12.88 GiB | 14 % of 93.1 |
| RTX 5070 Ti | 128 | 4.78 GiB | **30 % of 15.9** |
| H100 | 64 | 2.56 GiB | — |

On the consumer card a single 128³ RK4IP step reserves nearly a third of the
device.

## Conclusions

- **Do not make RK4IP the default.** At ordinary tolerances on the production
  GPU it is slower than what it would replace.
- **Keep it opt-in** (`integrator: rk4ip`), and select it for tight tolerances
  (≲1e-5), for CPU work, or when 4th order is wanted for its own sake.
- The obvious optimisation is the kinetic count. Four half-exponentials is
  intrinsic to the standard RK4IP formulation; getting below it means a
  different scheme, not a tuning of this one.
- **The CPU/GPU reversal is the transferable lesson.** A cost ratio between two
  integrators is not a property of the integrators — it is a property of which
  part of the step dominates, and that changes with the backend. Any
  "integrator A is cheaper than B" claim needs the device attached.
