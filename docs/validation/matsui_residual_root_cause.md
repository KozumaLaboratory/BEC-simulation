# Fig. 4B residual — everything that has been excluded, and what it means

Session S-A6, closed out 2026-07-31. Every number below is measured on TSUBAME
from a clean tree; UGE job ids given per row. Type A throughout (code-to-code)
unless marked.

## The two residuals

Against Matsui et al.'s published simulation, on the identical window and metric:

- **dip centre** ours −2.138 nT, theirs −2.549 — a **0.411 nT** gap
- **cascade progress** ours ~20 % further at every field — `N_{−6}` ratio
  0.78–0.84 across the dip, and the Fig. 2C depletion landmarks all at 0.81–0.84

## What has been excluded

| candidate | measurement | worth | job |
|---|---|---|---|
| DDI coupling `c_dd` | their expression reduced to our units vs `compute_c_dd_dimless` | **exact to 7 s.f.** (211.021419 / 211.021446) | static |
| contact `c_total`, `c₀`, `c₁` | same | **exact** (4687.2663) | static |
| DDI kernel treatment | both kernels applied to the SAME ground state | **0.0016 nT** (0.4 % of the gap) | static |
| bare periodic kernel (neither code uses it) | as above | 0.053 nT | static |
| grid resolution | 45 fields at `dx` 0.5 → 0.25 a_ho | **0.007 nT**, ≤0.06 % in `N` | 8307358.8 |
| **box size** | 16 / 24 / 32 a_ho at **fixed** `dx` | **1 part in 10⁶** | 8307989.11 |
| **their grid, exactly** | 128³, box 36.2 a_ho, `dx` = 0.4 aHO — theirs to the digit | **0.007 nT**, 3×10⁻⁵ in `N` | 8307989.10 |
| time step | `dt` 1e-3 → 2.5e-4 (2nd order ⇒ converged) | 0.031 nT, 1.3 % | 8307989.12 |
| ramp shape | their exact `exp(−t/50 µs)` vs our linear 150 µs | 0.070 nT, ~0 in `N` | 8307358.7 |
| three-body loss | `K₃` × {1, 3, 10} of the published value | ~0 (real loss is 0.2 %) | 8304841.5 |
| **their FD Laplacian** | run with `grid.k_squared` replaced by the FD symbol | **wrong sign**, 3.5–8.6 % | 8308423 |
| ground-state ambiguity | — | **does not exist**: polarised GS is degenerate in `c1_ratio` | — |
| 1 nT field jitter | Gaussian average over B | 0.05 nT | static |
| the experiment's 8–45 % atom deficit | their own Fig. S3 lifetime (1/e = 2.54 s ⇒ 0.20 % in 5 ms) | **not loss** — a counting systematic, corr(total, #components) = −0.935 | static |

Sum of everything that moves the centre: **~0.11 nT, about 26 %** of the gap.
Sum of everything that moves the transfer: **under 7 %** of the 20 %.

Three of these nulls carry an explicit positive control, because two earlier
nulls did not and were wrong: the box arms are demonstrably different grids
(saved ψ at 32³ / 48³ / 64³), the `N` arms demonstrably differ (0.195 vs 0.309),
and the 128³ run took **219 s per point against 5.2 s at 32³** — a factor 42 for
64× the cells, which only happens if it really ran at 128³.

**Running on their exact grid changes nothing**: centre −2.145 against our
−2.138, `N_{−6}` fraction 0.195195 against 0.195201. Grid, box and resolution are
now excluded together and independently.

## Their FD Laplacian: excluded, and with the wrong sign

On a periodic grid the 3-point FD Laplacian is diagonal in Fourier space with
eigenvalue `Σ_d (2/dx_d²)(1 − cos(k_d dx_d))`, so their operator is reproduced
**exactly** by substituting `grid.k_squared`. The substitution is surgical: the
DDI builds its own half-grid `k` from `grid.k` / `grid.dk` and never reads
`grid.k_squared`. Nothing knowingly-inexact enters the production Hamiltonian —
this lives in `scripts/validation/matsui_fd_laplacian_probe.jl`.

**Predicted first.** On their exact grid (128³, `dx` = 0.4 aHO), the FD kinetic
deficit measured from the saved 5 ms state runs from 0.234 ħω at `m = +6` down to
0.025 at `m = −6`; **differenced between adjacent components it is 0.0166 ħω =
0.112 nT** for `m = −5` against `m = −6`. The resonance sits where the Zeeman
splitting matches the rotational kinetic-energy difference, so a *smaller*
difference puts the resonance *closer to zero*. Their exact-Laplacian equivalent
would be **−2.661**, not −2.549, and the gap to ours would **widen** from 0.411
to 0.52 nT.

**Then measured.**

| B [nT] | exact | FD | FD − exact |
|---|---|---|---|
| −3.0 | 0.215985 | 0.197494 | **−8.6 %** |
| −2.5 | 0.211028 | 0.197577 | −6.4 % |
| −2.0 | 0.208473 | 0.198779 | −4.7 % |
| −1.5 | 0.208546 | 0.201300 | −3.5 % |

FD *lowers* `N_{−6}`, i.e. transfers **more**. Matsui's curve is **higher**
(0.2475 against our 0.1952). So their Laplacian moves the disagreement in the
wrong direction, by 3.5–8.6 % on top of the 21 % already there. **Candidate 1 is
excluded.**

**Read the caveat.** The probe's positive control **failed**: the hand-built path
gives 0.208473 at −2.0 nT where the pipeline gives 0.195201, a 6.8 % difference,
most likely because the hand-built path applies the held field from `t = 0` and
omits the 150 µs ramp. So the *absolute* numbers in that table are not comparable
to the pipeline's, and only the **FD − exact differential**, measured on a
like-for-like pair inside one path, is quotable. The control is reported rather
than quietly dropped because two nulls in this campaign were wrong for want of
one.

## The structural finding

**No single global coupling can reach their published pair from ours, because the
centre and the transfer respond with opposite signs.** Measured directly by
scanning `N_atoms`, which scales `c_dd`, `c₀` and `c₁` together (8308087.13):

| | dip centre [nT] | `N_{−6}` fraction at −2 nT |
|---|---|---|
| ours, N = 5.0×10⁴ | −2.138 | 0.1952 |
| ours, N = 3.5×10⁴ | **−1.892** | **0.3094** |
| Matsui | **−2.549** | **0.2475** |

Lowering `N` moves the transfer *toward* theirs and the centre *away* from it.
Their point lies in neither direction. The same is true of `c_dd` and of the peak
density, since `c_dd·n_peak ∝ N^(2/5)` carries both.

The cascade *shape* is not the difference. At −2.5 nT, ours over theirs by
component: `m = −6` 0.799, `−5` 0.809, `−4` 1.012, everything above 1.175 — our
cascade has simply run ~20 % further along the same ladder.

## What this means

The residual is **not a parameter error on either side**. Every parameter agrees
to the digits, every numerical knob on our side is converged, and the one
parameter their release is inconsistent about (`Ntot`) cannot produce their
answer. What is left is a structural difference in the dynamics itself.

The surviving candidates, in order of what the evidence supports:

1. ~~**Their discretisation.**~~ **EXCLUDED** — see above. Both the analytic
   estimate and the direct run say their FD Laplacian moves the disagreement the
   wrong way. What remains untested from their numerics is Crank–Nicolson
   itself, but our own `dt` convergence makes an integrator explanation
   implausible: two 2nd-order schemes both converged in `dt` agree.
2. **A parameter in their published run that is not in the shipped code.** We
   already know `Ntot` is one such; `cc0_eff` / `cc1_eff` / the trap could be
   others. This is not falsifiable from what they released.
3. Something in **our** transfer channel that all of the above tests are blind
   to — none of them varies the spin structure, only the scale.

## The honest bottom line

We reproduce the phenomenon, the sign, and the scale of the resonant EdH offset
from an independent implementation with independently declared conventions, and
we agree with their model's couplings exactly. We do not reproduce their curve to
better than ~20 % in transfer and ~0.4 nT in centre, and after this campaign the
disagreement is **located but not resolved**: it is in the dynamics, not the
parameters, and it cannot be closed by scaling anything.

The experiment does not adjudicate. Its field axis carries a stated offset error
of up to 10 nT — four times the effect — so −2.14, −2.55 and the measured −3.20
are all consistent with it. The one measured quantity immune to that systematic
is the dip width, and there their simulation tracks their experiment better than
ours does (+1.8 % against +9.6 %), which is the single piece of evidence pointing
at our side rather than theirs.

## Next, if this is picked up again

- Implement a 3-point FD Laplacian as a **diagnostic**, not a production mode,
  and run one field. If it moves the transfer 20 %, candidate 1 is the answer.
- Ask the authors for the `setup_parameters` behind the published figures. Two
  parameters in the release are already known not to be the ones used.
