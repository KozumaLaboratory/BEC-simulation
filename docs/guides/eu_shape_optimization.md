# ¹⁵¹Eu dynamic trap-shape optimization

> **FROZEN 2026-07-27.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Extends the power-ramp evaporation study (issue #75) to the trap **geometry**
$V(r,t)$: expand or box the trap as the BEC forms to cut three-body loss and
keep more condensate. Physics derivation: `docs/theory/eu_evaporation_three_body_theory.md`.

Driver: `docs/guides/figures/eu_shape_optimization.jl`. Plot scripts alongside.
Raw/derived CSVs are archived on TSUBAME at
`/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu_shape_optimization/data/t0/`; the repo
carries only figures + code.

## Model

Scalar-equivalent Gross–Pitaevskii: the Eu151 $F=6$ spinor with all atoms in the
stretched $|m=-6\rangle$ component and $c_1=0$, so no spin mixing occurs and the
cloud stays single-component. Physical three-body loss $dn/dt = -K_3 n^3$ via
`LossParams(K3_cubic=...)`. This reuses the confirmed spinor machinery
(`make_workspace` + `run_simulation!` + `LossParams`); the `scalar_egpe.jl`
skeleton has neither loss nor a time-dependent trap.

## Units (internal $\hbar=m=\omega_\mathrm{ref}=1$)

$\omega_\mathrm{ref}$ is the tight **formation** trap ($2\pi\cdot 420$ Hz here, so
$\omega=1$ internal). With $a_{ho}=\sqrt{\hbar/m\omega_\mathrm{ref}}$:

- scalar contact, norm-1 convention: $c_0 = 4\pi (a_s/a_{ho})\,N$ (Eu $a_s=135\,a_0$).
- three-body: $\tilde K_3 = K_3/(a_{ho}^6\,\omega_\mathrm{ref})$, $K_3=10^{-41}\,\mathrm{m^6/s}$.

**Norm/density convention (the load-bearing detail).** `find_ground_state`
normalizes $\int|\psi|^2=1$, so $|\psi|^2$ is $N$-fold below the physical density
$n=N|\psi|^2$. The loss kernel reads $|\psi|^2$ directly, so the coefficient must
absorb the $N^2$:

$$\texttt{K3\_cubic} = \tilde K_3\,N^2 .$$

Surviving atoms are $N\!\int|\psi|^2(t)$; physical peak density is $N\max|\psi|^2/a_{ho}^3$.
Getting this wrong (using $\tilde K_3$ directly) makes the loss $\sim 0$ — the
original smoke bug.

**Trap-shape driving.** `TimeDependentTrap` is *not* re-evaluated by the runner
during dynamics (its `t_eval` path drives only interactions/Zeeman). The shape is
driven by an `on_step` callback overwriting `ws.potential_values` from
`evaluate_potential(HarmonicTrap(ω(t)) | BoxPotential(L(t)), grid)`.

## Results

### Validation gate — units are correct

At fixed $N$ a Thomas–Fermi condensate has $n_0\propto\bar\omega^{6/5}$ and
$\langle n^2\rangle\propto\bar\omega^{12/5}$ (the loss-rate scaling behind the
$N_0\propto\bar\omega^{-3}$ attractor). Fitted **1.22 / 2.46** vs theory
**1.20 / 2.40** — PASS. `julia --project=. docs/guides/figures/eu_shape_optimization.jl validate`.

### Box lever — the geometric knob

A flat box holds a uniform bulk $n\approx N/V$, so $\langle n^2\rangle=(N/V)^2$ is
set freely by $V$ ($\propto V^{-2}$; fitted slope $-1.89$). At a matched footprint
the uniform profile carries a lower $\langle n^2\rangle$ (loss rate) than the
peaked harmonic condensate, and growing $V$ pushes it down by orders of magnitude.
`... boxlever` → `eu_shape_box_lever.png`. (Residual $\langle n^2\rangle/(N/V)^2$
drift $1.4\!\to\!1.9$ across the scan is finite-box geometry + fixed-step ITP
convergence; the scaling and lever are the point.)

### Dynamic ramp optimization — an interior optimum

Decompressing $\omega:1\to\tfrac12$ over a ramp duration $\tau$ (then holding)
gives an **interior maximum** in surviving $N(\tau)$: too slow spends time at high
density; too fast excites a breathing mode whose re-compression overshoots
density. The GP breathing dynamics supplies this adiabaticity trade-off with no
ad-hoc penalty. Over a $45\,\mathrm{ms}$ hold: HOLD loses $10.5\%$, the optimal
ramp ($\tau\approx4\,\mathrm{ms}$) loses $2.5\%$ — a $\sim 4\times$ reduction.
`... optramp`. (First-pass at $32^3$; the quantitative
$\tau^\ast$ and the shallow instant-vs-optimum margin warrant a finer-grid / GPU
confirmation.) This $T=0$ decompression result is superseded by the finite-$T$
refinement in `eu_shape_finite_t.md` (`eu_ft_decompress_refine.png`).

## Status and next

Tasks #9 (driver + units + bug fix + smoke) and #10 (validation gate) and #11
(box lever + ramp optimization + figures) are done at the $T=0$ GP level. The
**definitive** version is finite-temperature (evaporation efficiency
$\gamma_{el}\propto n$, spilling, $T/T_c$ preservation set the real constraints)
via Stoof-SGPE at Eu resolution ($128^3$+) on TSUBAME — task #12.
