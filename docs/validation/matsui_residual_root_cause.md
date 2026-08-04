# Fig. 4B residual — their SIMULATION ran at N = 3.5×10⁴, 70 % of the experiment

**Resolved 2026-08-01 against their simulation; reframed 2026-08-02 after reading
the paper.** The residual was the atom number. Their published *simulation* ran
at `Ntot = 3.5×10⁴` — the value shipped in their `setup_parameters` — while the
published curves are normalised to 5×10⁴, which is what we had assumed. Given
that `N`, our code reproduces their Fig. 4B to **1 %**.

> **What this is NOT.** It is not a statement about the experiment's atom number.
> The paper (Matsui et al., *Science* **391**, 384 (2026); arXiv:2504.17357)
> states "The trap typically contained approximately **5×10⁴ atoms**, with a
> negligible thermal component." So their published theory curve was computed at
> **70 % of the experimental atom number** — an inconsistency inside their
> release (shipped `Ntot = 3.5d4` against 5×10⁴ in the text), not a property of
> the experiment.
>
> Everything below is a **code-to-code** comparison and is unaffected. The
> three-observable identification against `dataset_fig1/F.txt` — their own
> Fortran's 5 ms state — is what pins their simulation to 3.5×10⁴, and it stands.
>
> Attempts to fit the **experiment** made on 2026-08-02 are retracted in full:
> every premise was wrong and every one was in the paper. See
> `docs/validation/matsui_experiment_parameters.md`.

Both columns read from the final `psi`; widths on the matched window [−12, +9]
(see "the width DOES close" below for why the window has to be stated).

| | dip centre [nT] | half-depth width [nT] |
|---|---|---|
| ours, N = 5.0×10⁴ | −2.1381 | 13.813 |
| **ours, N = 3.5×10⁴** | **−2.5099** | **12.740** |
| Matsui | −2.5495 | 12.752 |

Centre gap **0.411 → 0.040 nT** (−90 %), width gap **1.061 → 0.012 nT** (−99 %).
Per-field, `N_{m=−6}` ours over theirs on the 41 fields where the two scans share
an abscissa:

| B [nT] | −12 | −10 | −6 | −4 | −2 | 0 | +2 | +5 | +9 |
|---|---|---|---|---|---|---|---|---|---|
| ratio | 1.020 | 1.025 | 1.004 | 0.995 | 0.991 | 0.989 | 0.989 | 1.000 | 1.002 |

**rms deviation 1.10 %, worst 2.57 %** (at −10 nT, on the left wing where we run
systematically high). At N = 5×10⁴ the same ratios ran 0.78–0.84.

UGE 8310846 task 15, commit `ec310fe2`+, exit 0, 45 points. Type C.

## Error budget for the last 0.039 nT — it is NOT our time step

> **Retracted 2026-08-01.** This section previously read "it is our time step"
> and reported that refining `dt` 4× moved the centre by −0.040 nT, landing on
> −2.550 against their −2.549. **That measurement was invalid.** The refined-`dt`
> run's `save.every` did not land on the final step, so its last saved series
> sample is at t = 3.348 against the baseline's 3.456 — a 3.1 % shorter
> evolution. The −0.040 nT was that 3.1 %, not the time step. Read from the
> saved final `psi` instead, both arms end at 5 ms and the answer changes sign
> and three orders of magnitude. The lesson is filed below.

Baseline: N = 3.5×10⁴ with our defaults, centre **−2.5099** against their
**−2.5495**. Each candidate turned on alone (UGE 8313740 / 8314269, all arms
exit 0, 45 points each). All figures read from the final `psi`, verified to be
at t = 5 ms; widths on the matched window [−12, +9]:

| arm | centre [nT] | width [nT] | Δcentre |
|---|---|---|---|
| baseline (`dt` = 1e-3) | −2.5099 | 12.740 | — |
| `dt` refined 4× | −2.5100 | 12.740 | **−0.0001** |
| ramp segment alone refined 4× | −2.5099 | 12.740 | −0.0000 |
| + their exponential ramp | −2.5865 | 12.753 | −0.0766 |
| + their exponential ramp, knots 4× finer | −2.5867 | 12.753 | −0.0768 |
| + grid (32³/box 16 → 64³) | — | — | −0.007 |
| + DDI kernel (cutoff on/off) | — | — | −0.002 |
| **Matsui** | **−2.5495** | **12.752** | **−0.0396 needed** |

**Our time step is converged.** Refining it 4× moves the per-field `m = −6`
populations by 8–9×10⁻⁵ and the centre by 0.0001 nT — 400× smaller than the
residual. Refining only the ramp segment, where the field moves fastest, does
nothing either. Adaptive stepping would buy nothing here.

The only candidate that moves the centre by the right order of magnitude is
**their exponential ramp**, and it **overshoots by about 2×**: −0.0766 against
the −0.0396 needed. Adopting their ramp shape swaps a +0.040 nT error for a
−0.037 nT one.

### The ramp's discretisation is excluded on both of its axes

Their Fortran evaluates `B(t)` in closed form every step; we encode it as a
piecewise-linear waveform. Two independent things could therefore go wrong, and
the dt sweep above only bounds one of them — a finer `dt` samples the *same*
piecewise-linear waveform more densely, it does not move that waveform closer to
the exponential.

The second axis is the knot spacing. A chord across a convex decaying exponential
lies above it everywhere, so `τ/6` knots run the field systematically high: the
excess time-integrated field over the 5 ms hold is 0.0848 nT·t.u., which is a
**+0.0245 nT DC-equivalent offset**, with a 3.6 nT peak instantaneous excess.
Refining to `τ/24` cuts both 12×.

**Prediction, recorded in the config before the run: the centre moves +0.0245 nT,
to about −2.562. It did not.**

| their exponential ramp | centre [nT] | width [nT] |
|---|---|---|
| knots `τ/6` | −2.5865 | 12.7530 |
| knots `τ/24` | **−2.5867** | 12.7529 |

−0.0002 nT — two orders below the prediction. UGE 8314874 task 21, commit
`b634f400`, clean tree, exit 0, 45 points.

So a 3.6 nT transient error during the 350 µs ramp is worth 0.0002 nT of
resonance position, and the DC-equivalent mapping that made it look like 0.0245
is simply wrong. **A time-averaged field is not the quantity the resonance
responds to** — the same lesson the campaign already learned when the mean
dipolar field over the ground state came out −0.65 nT while the dip sat at −2.1.
The resonance is set by conditions during the transfer.

Between them the two axes exclude ramp discretisation entirely, and with it any
gain from exact `∫B(t)dt` in the Zeeman exponent: the midpoint quadrature error
it would remove is O(dt³) and the dt sweep bounds it 64× below a null.

### What the ramp shape does settle: the width

| arm | centre [nT] | Δ vs Matsui | width [nT] | Δ vs Matsui |
|---|---|---|---|---|
| our linear 150 µs ramp | −2.5099 | **+0.0396** | 12.7400 | −0.0124 (0.10 %) |
| their exponential ramp | −2.5865 | −0.0370 | **12.7530** | **+0.0006 (0.005 %)** |
| Matsui | −2.5495 | — | 12.7524 | — |

Their ramp closes the width to 0.005 % — better than the linear stand-in by 20× —
while overshooting the centre by almost exactly what the linear ramp undershoots
it. The two observables therefore point at *different* arms, which is itself
information: whatever remains is not a single scalar in the ramp, or one arm
would win both.

**0.037–0.040 nT (1.5 %) of the centre remains unexplained**, bounded well inside
the ~1 nT field fluctuation the paper itself quotes, so it does not threaten the
reproduction; it is simply not accounted for.

**The ground-state DDI is excluded**, and by a wide margin. Their
`timeGP_3D_spin1_fix` carries `+cdd·INT0_n·MatSZ(im)` while **both calls that
would update `INT0` inside the CN iteration are commented out** (`initial.f90`),
so `INT0` is frozen at the value computed once from the Thomas-Fermi seed. That
looked like a live candidate — until measured. Turning our GS DDI fully off
moves the centre to **−3.205**, a bracket **0.695 nT** wide (positive control:
the GS shape goes 0.7786 → 1.3858, the bare-trap value being 1.3967). Matsui sit
**0.039 nT from the self-consistent end** and 0.656 from the other. Their frozen
field is effectively self-consistent, because the TF seed's dipolar field is
already close to the converged one.

So the centre's remaining 0.037–0.040 nT is not the time step, not the knot
spacing, not the grid, not the DDI kernel and not the ground-state DDI. It is
bounded, it is small, and it is open.

## The width DOES close — the 2 % was a window mismatch

> **Corrected 2026-08-01.** This section previously reported a 2 % width gap as
> open physics. It was an artefact of comparing the two curves over windows that
> were not actually the same.

`resonance_dip` sets the half-depth level from the **endpoints**, so `width` is
a property of the curve *and the window it is measured over*. On the Matsui
theory curve alone, one dataset:

| window [nT] | their width [nT] |
|---|---|
| [−20, +20] (their full scan) | 15.022 |
| [−13, +9] | 13.073 |
| [−10, +9] | 11.791 |

A 21 % spread with no physics involved. Our scan runs [−13, +9] at 0.5 nT
throughout; theirs runs [−20, +20] at 0.5 nT **only inside ±10 nT** and 1 nT
outside. So "restrict both to [−12.5, +9]" left our outermost sample at −12.5 and
theirs — which has no −12.5 node — at −12. That half step is the whole reported
disagreement:

| common window | ours | Matsui | Δ |
|---|---|---|---|
| [−12.5, +9] (endpoints ½ step apart) | 12.885 | 12.752 | +1.04 % |
| **[−12, +9] (endpoints identical)** | **12.740** | **12.752** | **−0.10 %** |
| [−10, +9] | 11.828 | 11.791 | +0.31 % |

**On a genuinely matched window the widths agree to 0.1 %.** Centre and width
are therefore both closed to ~1.6 % and ~0.1 % respectively.

Two further traps this exposed, both now pinned by
`test/validation/test_matsui_fig4_dip.jl`:

- **`point_001` is not the state its field label claims.** Our B = −13 nT point
  reads exactly 1.000000 — the untouched ground state — against 0.7047 at the
  neighbouring −12.5 nT. Because that point is the *left endpoint*, it set the
  baseline, and every width we computed over the full [−13, +9] range was
  inflated to ~14.95. It is the known multi-point-scan defect; the campaign's
  own `matsui_ddi_operator_audit.jl` already skips `point_001` for this reason.
- The fixture's own theory-vs-experiment width consistency check was comparing
  [−20, +20] against [−17.5, +17.5]. Now trimmed to the common range.

`center` carries none of this — it is a parabolic vertex through the minimum and
its two neighbours, invariant under the window to 1e-6. That is why it is the
number this campaign quotes.

## How it was found, and why it took so long

Integrated populations alone cannot separate `N` from anything else that scales
the dipolar drive — that degeneracy is what produced the campaign's central
puzzle, that **no single coupling moved the centre and the transfer the same
way**. The lock was opened by `dataset_fig1/F.txt`, buried in the otherwise
image-only `dataset_raw.zip`: their Fortran's own output, identified as the 5 ms
state behind Fig. 2C (populations match to four digits). It carries the state's
**spatial** structure, and three observables at once break the degeneracy:

| at +2.5 nT, 5 ms | Matsui | ours N = 3.5×10⁴ | ours N = 5×10⁴ |
|---|---|---|---|
| `m = −6` fraction | 0.4273 | **0.4158** (2.7 %) | 0.2661 (38 %) |
| rms radius [a_ho] | 2.619 | **2.687** (2.6 %) | 2.849 |
| shape `⟨x²⟩/⟨z²⟩` | 0.899 | **0.877** (2.4 %) | 1.030 |

Size and shape respond to `N` differently from transfer, so requiring all three
at once fixes it uniquely. Nothing else tried in the campaign moved all three
together.

## A prediction that failed, and what it taught

Recorded in the run's own commit before it was launched: since
`c_dd·n_peak ∝ N^(2/5)`, a smaller `N` weakens the dipolar field and should pull
the resonance **toward zero**, away from their −2.549. It did the opposite —
−2.138 → −2.510, toward theirs.

So **the offset is not a density-weighted mean-field shift**. That also explains
an earlier oddity: the mean dipolar field over the polarised ground state is
−0.65 nT while the dip sits at −2.1. The resonance is set by conditions during
the transfer, not by the initial cloud's average field, and it responds to `N`
with the opposite sign to the naive scaling.

## What was excluded on the way (all of it innocent)

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
3. ~~Something in **our** transfer channel.~~ **EXCLUDED.** The production DDI
   operator agrees with `reference_rhs/ddi.jl` — an independent statement of the
   same operator — to **2.6×10⁻¹⁶** on a real textured 5 ms state, per component
   across all 13, with both positive controls firing (off-diagonal Q zeroed:
   0.66; `c_dd` × 1.2: exactly 0.200). `matsui_ddi_operator_audit.jl`.

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

## Where it ends

Every candidate in the table above was innocent. The residual was one input
number, and the campaign's own framing — "no single scalar moves both the centre
and the transfer the right way" — was true only because we were scanning around
the wrong `N` and reading a scaling law that does not hold.

`matsui_author_query_draft.md` is **no longer needed** and is retained only as a
record of what would have been asked.

**The honest headline: an independent implementation, with conventions declared
separately and couplings agreeing to seven significant figures, reproduces their
published Fig. 4B to 1 % once given the atom number their run actually used.**
