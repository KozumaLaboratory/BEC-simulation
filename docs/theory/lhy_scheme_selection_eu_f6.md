# Which ε_LHY to use for ¹⁵¹Eu F=6, and how big the remaining ambiguity is

Answers issue #337. **The premise the issue was opened on does not survive
measurement**: ε_LHY is not ill-posed for Eu F=6. The instability it names is
real and is entirely dipolar, but the ambiguity it creates in the *number* ε_LHY
is **at most ~1.3 %** across the whole range from zero dipole to the physical Eu
dipole, not O(1) — and above **B\* = 104.5 µG the instability is gone outright**,
so there the ambiguity is not small but *absent*. Both of those overturn the
previous verdict (`docs/validation/full_bdg_scheme_dependence_eu_f6.md`, "NOT
ANSWERABLE with the current machinery", now frozen).

> **All numbers here are POST-`7e6770c2`.** That commit (#361/#367, 2026-08-19)
> corrected `_bdg_ddi_matrices`: the DDI normal block of the homogeneous BdG had
> been built from the Hartree term, which is identically zero for a uniform
> condensate. It was 2× too large on a polarised state and **exactly zero on a
> polar one**, which is where the spin-roton lives. The first pass of this
> document was measured on that code and every `full_bdg`-derived figure in it
> was wrong — growth at B = 0 read 3.667/15.164 against 2.202/0.332, the scheme
> gap read ≤ 6 % against ≤ 1.3 %, and the field was reported as *not* an escape
> route when it is. The campaigns in `runs/eu_lhy_boundary_337/` were re-run in
> full rather than patched, so no cell here is pre-fix.

Everything below is measured at the campaign's own parameter point — ¹⁵¹Eu,
`c1_ratio = 1/36`, N = 50000, ω_ref = 2π × 110 Hz, peak density n = 3.7e-3,
32 propagation directions — by `bench/lhy_{scheme_probe,unstable_window,
growth_vs_field,state_dependence,texture_polarisation}.jl` and the two GPU
campaigns in `runs/eu_lhy_boundary_337/` (jobs 8440204 and 8440274, both GREEN).

## The decision, in five lines

0. **If you can run at B > 105 µG, the question does not arise** — the m = −F
   mean field is dynamically stable there and ε_LHY carries no scheme dependence
   at all. §2.1.
1. **Use `fm_dipolar`** for any state with |⟨F⟩|/F ≈ 1. It is the fully-polarised
   dipolar LHY the spinor-droplet literature uses, and it is *identical* to the
   SI-anchored `scalar` × Q₅ path here (gated to 6.6e-16). §4.
2. **Never give one ansatz's functional to a state of different |⟨F⟩|.** ε_LHY
   differs 2.7× between p = 1 and p = 0 at this coupling. §5, §7.
3. **For comparisons across different |⟨F⟩| use `:spatial`**, and quote ±1.3 %.
   It assumes no ansatz and it is what decides between the two schemes. §5.4.
4. **The residual ambiguity is ~1.3 %, not O(1)** — the issue's premise is too
   strong, and a beyond-mean-field result here *is* quotable with an error bar. §3.
5. **The mean-field FM/polar line at `c1_ratio ≈ 1/36` is not defensible.** LHY
   does not displace it, it *creates* it. §5.3.

---

## 1. The dipolar part of the problem does not exist at this atom

The known ambiguity in the *dipolar* LHY literature is that the Lima–Pelster
angular integral

$$Q_5(\varepsilon_{dd}) = \tfrac12\int_0^\pi d\theta\,\sin\theta\,
\bigl[1+\varepsilon_{dd}(3\cos^2\theta-1)\bigr]^{5/2}$$

goes complex once the bracket turns negative, which happens for
$\varepsilon_{dd} > 1$; the standard prescription is to keep the real part
([Lima & Pelster 2011](https://arxiv.org/abs/1103.4128); stated as a caveat in
the [Chomaz et al. review](https://arxiv.org/abs/2201.02672)). Note that
"keep the real part" and "zero the integrand where the bracket is negative" are
the *same* operation, since $(-x)^{5/2}$ is purely imaginary — which is what
`lima_pelster_Q5` implements.

At ¹⁵¹Eu, $\varepsilon_{dd} = a_{dd}/a_s = 0.54024$, so the bracket runs over
**[0.4598, 2.0805] and never changes sign**:

| | |
|---|---:|
| bracket at θ = π/2 (minimum) | 0.459758 |
| bracket at θ = 0 (maximum) | 2.080484 |
| $Q_5(\varepsilon_{dd})$ | 1.456350 |

**So the real-part prescription is vacuous here.** Nothing in the density
channel is ambiguous for Eu, and no citation is needed to license it. Whatever
#337 is about, it is not the dipolar LHY convention.

## 2. What is actually unstable is the spin channel, and it is a known theorem

Switching the DDI off makes the growth rate exactly zero — at every field from
0 to 100 µG and at every `c1_ratio ≥ 0` tested:

| state | c_dd = 0 | c_dd = Eu (over B = 0 … 1000 µG) |
|---|---:|---|
| FM, m = +F | **0** | 2.20 – 2.34, unstable at every field |
| FM, m = −F | **0** | 2.20 at B = 0, falling to **exactly 0 above 104.5 µG** |
| polar, m = 0 | **0** | 0.33 at B = 0, *rising* to 3.41 |

This is not a defect of the machinery and not specific to Eu. A uniformly
magnetised dipolar spinor condensate is dynamically unstable against
long-wavelength spin excitations — Kawaguchi, Saito, Kudo and Ueda,
[PRA 82, 043627 (2010)](https://arxiv.org/abs/0909.0565), where exactly this
Bogoliubov instability is what drives the spontaneous formation of magnetic
domains and spin textures. `full_bdg` is reproducing a published result.

The consequence for the LHY construction is structural: **the LDA reference
state — a uniform gas at the local density and the local spinor — has no
dynamically stable version in a dipolar spinor gas.** Every spinor LHY
functional in the literature ([Uchino, Kobayashi & Ueda,
PRA 81, 063632 (2010)](https://arxiv.org/abs/0912.0355), which is what
`full_bdg` implements) is built on that reference.

### 2.1 The field IS an escape route — the recorded verdict was wrong, and so were its numbers

Two separate errors compounded here, and the second hid the first.

**The numbers.** `full_bdg_scheme_dependence_eu_f6.md` dismissed `q` with a table
reading "50 µG ⇒ p = −7.40e-05, q = 3.23e-16". Both figures are wrong, by 10⁴ and
10⁸: `linear_zeeman_p` takes **tesla**, the campaign YAML writes
`Bz: "4.4e-5 Gauss"` = 4.4e-9 T, and `cli.jl inspect` resolves `p = −0.651`,
`q = +2.502e-08`. The row printed as "1 G" is in fact 100 µG, which is why its
numbers are the only ones that survive. Corrected in place there.

**The verdict.** With the corrected BdG the field does not merely fail to be
irrelevant — it *closes the instability*, and through `p`, not through `q`:

| B (µG) | p | q | m = +F | **m = −F** | polar |
|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 2.2024 | 2.2024 | 0.3322 |
| 44 | −0.651 | 2.50e-08 | 2.3374 | 1.8413 | 0.7031 |
| 100 | −1.480 | 1.29e-07 | 2.3263 | 0.5530 | 1.2708 |
| **104.5** | **−1.5458** | 1.41e-07 | 2.325 | **0** | 1.31 |
| 125 | −1.849 | 2.02e-07 | 2.2675 | **0** | 1.4933 |
| 1000 | −14.80 | 1.29e-05 | 2.3029 | **0** | 2.9145 |

`bench/lhy_stability_threshold_field.jl` bisects the threshold to

$$B^\* = 104.478\ \mu G \quad (p = -1.5458),\ \text{bracketed to } 5\times10^{-4}\ \mu G.$$

**Above `B*` no Bogoliubov branch of the m = −F uniform mean field is complex.**
The scheme dependence this whole document is about is then not small — it does
not exist. The warning's own advice, "pick a mean-field-stable (F, c₀, c₁, q)
point", turns out to be reachable, and the campaign's 50–80 µG sits under 2×
below it.

Three things make this a real route rather than an artefact:

- **m = −F is the physical branch.** `p < 0` for a g_F > 0 atom on +Bz, so m = −F
  IS the Zeeman ground state; the `m_plus_F` seed measurably relaxes to
  Mz = −5.89 in `config_smoke.yaml`.
- **m = +F is the control and stays unstable** at 2.20–2.34 across the entire
  sweep. A probe that had simply gone blind would have zeroed both.
- **The DDI is still what causes it.** With `c_dd = 0` every entry is exactly 0
  at every field, so this is a gap opening in a dipolar instability, not the
  absence of one.

Note the polar branch moves the *other* way — 0.33 → 3.41 as the field rises.
The field stabilises the state it favours and destabilises the one it does not,
which is what a Zeeman gap should do and is a second sign the mechanism is real.

A by-product worth separating from all of the above: **the VALUE of ε_LHY is
very nearly field-independent** — 2.08159e-3 at B = 0 against 2.07675e-3 at
100 µG for m = +F (−0.23 %), with m = −F moving +0.17 % the other way. So the
2026-07-30 defect in which `_build_spinor_lhy` never passed `zeeman` to the table
builder, while a genuine bug, moved no ε_LHY in this regime by more than a
quarter of a percent. What the field changes is `max Im ω`, and it changes that
all the way to zero.

## 3. How big the ambiguity is — measured, not asserted

The warning `full_bdg` emits names its own mechanism precisely: *"the zero-point
sum drops the complex branches while the counterterms still subtract all D of
them"*. That is a bookkeeping mismatch between how many branches are summed and
how many are counter-subtracted, and it can therefore be **repaired and the
difference measured**:

- **S1** — what `full_bdg` does: sum the branches of positive symplectic norm,
  subtract the full counterterms $D\varepsilon_k + \mathrm{tr}\,C - \|B\|^2/2\varepsilon_k$.
- **S3** — counterterm-consistent: same sum, counterterms scaled by
  $D_{\rm kept}/D$.

S3 ≡ S1 identically wherever the spectrum is real, so the `c_dd = 0` rows are a
negative control that the comparison *can* return zero.

| state | c_dd | unstable directions | k_unst | k_s | f_unst | **(S3−S1)/S1** |
|---|---|---:|---:|---:|---:|---:|
| FM m=+F | 0 | 0 / 1 | 0 | 5.89 | 0 | **0.000** |
| FM m=+F | Eu | 30 / 32 | 1.77 | 8.40 | 0.264 | **−0.013** |
| polar m=0 | 0 | 0 / 1 | 0 | 4.16 | 0 | **0.000** |
| polar m=0 | Eu | 32 / 32 | 1.27 | 5.65 | 0.190 | **−0.013** |

Two things to read here, and they point opposite ways:

- **The unstable band is confined to the infrared, but not far enough to dismiss.**
  It reaches only $k_{\rm unst} = 0.285\,k_s$ and carries 19–26 % of
  $\int|k^2 I(k)|\,dk$. But it is still 2.4–3.4 × above
  $k_{\rm box} = 2\pi/L$, so these modes do exist in the trapped, finite system —
  the "they are longer than the cloud, so drop them" argument is **not**
  available, it is merely less wrong than the pre-fix numbers made it look.
- **ε_LHY barely moves.** The complex pairs are essentially purely imaginary, so
  their real zero-point contribution is ≈ 0 under either convention, and what is
  left is the counterterm mismatch — worth −1.3 % on both states. At the worst k,
  2 of 13 branches are complex for the FM spinor and 1 of 13 for the polar one.

**Quote the maximum over the range, not the value at the point.** (In the pre-fix
data the FM gap crossed zero near the physical coupling, so the single-point
value was an accidental near-null; post-fix it is monotone in magnitude, but the
habit stands.)

| c_dd / c_dd(Eu) | FM k_unst | FM gap | polar k_unst | polar gap |
|---:|---:|---:|---:|---:|
| 0.00 | 0 | **0.0000** | 0 | **0.0000** |
| 0.10 | 0.288 | −0.0045 | 0 | **0.0000** |
| 0.25 | 0.882 | −0.0073 | 0 | −0.0000 |
| 0.50 | 1.234 | −0.0102 | 0 | −0.0000 |
| 0.75 | 1.513 | −0.0110 | 0 | 0.0000 |
| **1.00 (Eu)** | 1.766 | **−0.0126** | 1.268 | **−0.0130** |
| 1.50 | 2.135 | −0.0124 | 3.540 | −0.0021 |
| 2.00 | 2.238 | −0.0138 | 4.844 | +0.0371 |

The polar state is **dynamically stable up to 0.75 c_dd(Eu)** — the gap is
identically zero there, which is the negative control firing over six rows
rather than one.

So the number to carry is **|gap| ≤ 1.3 % for both states for
`0 ≤ c_dd ≤ c_dd(Eu)`**, rising to only 1.4–3.7 % at twice the Eu dipole. The sweep is also the continuity check — the gap
is exactly 0 where the spectrum is real and grows smoothly from there, which is
what says the two conventions are two readings of one quantity rather than two
different quantities.

An earlier attempt to measure this used "keep Re ω of the complex branches" as
the alternative convention and is recorded here because its failure is
instructive: it reported a 144 % gap on a row with **zero** unstable directions
(it was picking up *energetically* unstable branches, a different statement about
the mean field) and reported exactly **0 %** on the unstable polar rows (whose
complex pairs have Re ω = 0, so both conventions agree on them). Neither number
was about the ambiguity. A scheme comparison has to be null exactly where the
spectrum is real, or it is measuring something else.

**Scope of the claim.** This is the spread between the two natural conventions,
not a proof that every conceivable convention agrees to 5 %. It is a measured
statement that the specific mechanism the code's own warning names costs a few
percent.

## 4. The decision

**For a state with |⟨F⟩|/F ≈ 1 — use `fm_dipolar`.** This is the scheme the
spinor-dipolar droplet literature actually uses: the fully-polarised
single-component dipolar LHY, $\varepsilon = \tfrac{2}{5}\gamma_{QF}n^{5/2}$ with
$\chi(\varepsilon_{dd}) = \mathrm{Re}\,Q_5$, applied at the total density and
justified by checking that the cloud really is polarised. See the Saito group's
[spinor dipolar droplets with magnetic vortices](https://arxiv.org/abs/2402.18885)
— *"the spin state is almost fully polarized in the droplet, and we can use the
LHY correction for the fully polarized dipolar BEC"*, with |**f**|/ρ ≈ F checked
numerically — and [Yan, Li & Saito, arXiv:2605.11670](https://arxiv.org/abs/2605.11670),
which is the reference for #338.

In this codebase that scheme is `fm_dipolar`, and it is **the same number** as
the SI-anchored `scalar` path times $Q_5$. Under the Eu constraint
$g_{2F} = c_0 + 36c_1 = c_{\rm total}$, so the FM single-mode closed form and
scalar Lima–Pelster are algebraically identical; measured across the two
independent code paths at n = 3.7e-3:

```
fm_dipolar / N   = 0.001971506129
(2/5)·c_lhy·n^5/2 = 0.001971506129     relative gap 6.6e-16
```

Two implementations, one identity — a differential gate, not a coincidence.
`full_bdg` at the same FM spinor gives 2.119e-3, i.e. **7.5 % above** the closed
form; that gap is the spin-channel zero-point energy that the fully-polarised
scheme omits by construction.

**For comparing states of different |⟨F⟩| — one ansatz functional is not
allowed, and §5 measures what it costs to do it anyway (a factor 21 on the
boundary shift). The comparison is now quotable.** ε_LHY at the campaign
point is 2.119e-3 for FM and 5.456e-4 for polar, a factor **3.9**. That is
physics, not convention: applying the fully-polarised functional to a polar state
overestimates it ~4×. So an FM-vs-polar energy ordering must evaluate each state
in its own functional (`full_bdg`, or the matching closed form), and carry the
**±1.3 %** scheme band measured in §3. Which is a usable error bar — the previous
document declined the comparison because the band was unknown, not because it was
large.

**Precedent for a branch-selective LHY.** Dropping a soft/unstable Bogoliubov
branch from the zero-point sum and keeping the rest is exactly what
[Petrov, PRL 115, 155302 (2015)](https://arxiv.org/abs/1506.08419) does for the
collapsing Bose–Bose mixture, and it is the basis of the whole droplet
literature. The justification there is that the dropped branch's contribution is
parametrically small in its own coupling. **That argument is not available here**
— §3 shows the unstable band carries ~60 % of the integrand's weight — so the
licence for this scheme is not Petrov's argument but the direct measurement that
the two conventions differ by a few percent regardless.

### What NOT to do, restated with the reason

- **Do not re-enable `|λ_spin|` in `epsilon_LHY_F6_Ih` to get a real number at
  `c₁ < 0`.** That was closed 2026-07-30 and the measured error was 0.4 / 2.1 /
  11.0 % at c₁ = −0.05 / −0.1 / −0.2, growing with the instability. Note the
  flagship GS phase campaign runs at `c1_ratio = +1/36`, where `icosahedral` and
  `polar_contact` are both finite; the `c₁ < 0` refusal bites the
  `verification_suite` / `eu_k3_*` families (`c1_ratio = −0.005`), not the phase
  diagram.
- **Do not add a fourth closed form.** The gap between existing functionals is
  now measured; a new ansatz would add a fourth number to compare, not remove
  the comparison.

---

## 5. Criterion B — how much the phase boundary moves without LHY

Two campaigns, both at ¹⁵¹Eu, 32×32×64, box 12×12×24, κ = 1, LBFGS +
`newton_polish`, `tol = 1e-9` — the campaign's own precision recipe from
`config_c1_precise_B0k1.yaml`, differing from it only in the `lhy` block.
`runs/eu_lhy_boundary_337/config_arms.yaml` scans Bz at `c1_ratio = 1/36`;
`config_arms_c1.yaml` scans `c1_ratio` at B = 5 µG. Read by
`bench/lhy_boundary_report.jl`. Both were **re-run in full** after `7e6770c2`
(jobs 8442771 and 8442773, both GREEN, 81 + 99 solves).

A useful consistency check fell out of the re-run: the closed-form arms —
`none`, `fm_dipolar`, `polar_contact`, `scalar` — came back **bit-identical** to
the pre-fix pass, and only the `spatial` arm moved. They contain no DDI BdG
block, so that is exactly the set that should have been unaffected.

### 5.1 The gap shift, and the positive control

At `c1_ratio = 1/36`, B = 5 µG. ΔE = E(stretched seed) − E(polar seed); the two
branches are `cyclic` and `nematic` in every arm at this field, so the arms are
comparing the same pair of states:

| arm | E_LHY (stretched) | E_LHY (polar) | ΔE | **δ(ΔE) vs none** |
|---|---:|---:|---:|---:|
| `none` | 0 | 0 | −0.1195 | — |
| one functional (`fm_dipolar` both) | 0.3562 | 0.3485 | −0.1101 | **+0.0094** |
| own ansatz (`fm_dipolar` / `polar_contact`) | 0.3562 | 0.0717 | +0.1896 | **+0.3091** |
| `spatial` (texture-following) | 0.4143 | 0.1630 | +0.1547 | **+0.2742** |
| CONTROL, scalar ×10 | 1.8241 | 1.8099 | −0.0811 | **+0.0384** |

Three readings, in order of how much they matter:

1. **The scheme choice dominates the LHY magnitude by 33×.** Giving both
   branches the same fully-polarised functional shifts the gap by 0.0094 —
   because a common offset almost cancels in a difference. Giving each branch the
   functional its own spinor calls for shifts it by 0.3091. That is the 2.7×
   ε(FM)/ε(polar) ratio of §7.2 arriving in an actual solve.
2. **`spatial` independently confirms which of the two is physical.** It assumes
   no ansatz — it tabulates `e₁(p)` from the local spinors of the actual cloud —
   and it lands at +0.2742, within 11 % of the own-ansatz answer and 29× the
   single-functional one. So this is not a matter of taste between two
   conventions: the calculation that asks the cloud agrees with the per-state
   functional. (Its 0.4143 on the stretched branch runs ~16 % above
   `fm_dipolar`'s 0.3562, part method gap and part texture.)
3. **The control fires.** ×10 on the amplitude moves the gap 4.1× further than
   ×1 in the same single-functional configuration — sub-linear because the state
   relaxes against the added repulsion, but unambiguous. And no arm is
   bit-identical to `none`: the wiring check reports 1.07e-1, 3.10e-1, 3.28e-1
   and 5.99e-1 as the maximum |ΔE(arm) − ΔE(none)| over the scan. Nothing here
   is silently inert.

### 5.2 Why the field axis could not give the boundary, and what did

The Bz scan does not produce a baseline boundary: at `c1_ratio = 1/36` the
stretched branch is **already** below the polar one at B = 0 (ΔE = −0.085), so
the `none` crossing lies outside B ≥ 0 and only the two arms that push ΔE
positive have one to report (`own ansatz` at 15.6 µG, `spatial` at 16.4 µG).
That is itself a result — **at this coupling, including LHY per-state is what
creates a stretched↔polar boundary in accessible fields at all** — but it is not
a δB, so the boundary measurement moved to the `c1_ratio` axis, which is where
the campaign pins c1\* ≈ 0.028–0.029 and where every arm crosses.

One number from the field scan is reused below: the observed local slope
|∂ΔE/∂B| = 0.0311 per µG near the crossing (0.0236 for the `spatial` arm). That
is ~0.35× the 0.0888 the pure Zeeman argument predicts, because the stretched
branch is `cyclic` rather than fully polarised at these fields — which is exactly
why the slope has to be measured rather than derived.

**The Bz axis also fails its own pre-registered control threshold, so it is not
the axis this document quotes.** The ×10 control's gap shift converts to
−2.58 µG against the 5 µG written into `config_arms.yaml` before launch, and the
report REFUSES a verdict there. It is not that the instrument is blind — the
physics arms move 9.2 and 12.2 µG, far more than the control — it is that the
threshold was set from a pre-launch estimate that turned out optimistic, and
raising it after seeing the data would empty the criterion of content. The c1
axis, whose control passes at 4× its threshold, is the measurement.

### 5.3 The c1 axis — where every arm has a boundary, and the answer

`config_arms_c1.yaml`, 11 points of `c1_ratio` ∈ [0.022, 0.032] at B = 5 µG,
4000 LBFGS steps (job 8440274, GREEN, 11/11 tasks). B = 5 µG rather than 0
because at exactly zero field the stretched branch sits on a degenerate spin
manifold and the solver stalls — |∇E| = 5.7e-1 at B = 0 against 4.8e-6 at 5 µG,
same everything else — while the polar branch's energy is B-independent to 1e-9
across the whole 0–70 µG scan.

**The mean-field calculation has no FM→polar crossing on this axis.** ΔE(`none`)
runs −0.4117 → −0.0195 and never reaches zero; past `c1_ratio = 0.031` both seeds
land in the same phase (`nematic`), i.e. the stretched branch **merges** into the
polar one rather than crossing it. A ΔE drifting toward zero reads exactly like an
approaching boundary and is not one — that is the degeneracy-guard failure this
project has made before, so the report names the merged points and refuses to read
a crossing past them.

**Two of the LHY arms do have a crossing:**

| arm | crossing at `c1_ratio` | local ∂ΔE/∂c1 |
|---|---:|---:|
| `none` | — (merges instead) | 41.9 |
| one functional (`fm_dipolar` both) | — (merges instead) | 36.8 |
| **own ansatz per branch** | **0.02376** | 66.8 |
| **`spatial`** | **0.02444** | 51.3 |
| CONTROL scalar ×30 | — | 17.4 |

So at this coupling, **including ε_LHY per state does not merely displace the
FM/polar line — it creates one that mean field does not produce.** The Bz scan
said the same thing from the other axis (§5.2), which is two independent routes
to the same statement.

### 5.4 The number criterion B asks for

The gap shift is defined whether or not a crossing exists, so it is the readout
that survives the merge. At the reference point `c1_ratio = 0.027`, converted
through each arm's own median |∂ΔE/∂c1| — and through the field slope
0.0311 per µG measured in §5.2:

| arm | ΔE | **δ(ΔE)** | **δc1\*** | **δB (µG)** |
|---|---:|---:|---:|---:|
| `none` | −0.1524 | 0 | 0 | 0 |
| one functional (`fm_dipolar` both) | −0.1399 | **+0.0125** | **+3.4e-4** | **+0.40** |
| own ansatz per branch | +0.1557 | **+0.3081** | **+7.3e-3** | **+9.9** |
| `spatial` | +0.1222 | **+0.2746** | **+6.6e-3** | **+11.6** |
| CONTROL scalar ×30 | −0.0810 | +0.0714 | +4.1e-3 | — |

**The control passes**: ×30 on the amplitude moves the gap 5.7× further than ×1
and converts to 4.1e-3 in `c1_ratio`, four times the 1e-3 pre-launch threshold.
Sub-linear in the amplitude because the cloud relaxes against the added
repulsion, which is expected and is why a control has to be run rather than
assumed.

**The answer to criterion B, in one line: it depends entirely on the scheme, and
by a factor of 21.**

- Under **one common functional**, leaving LHY out costs **3.4e-4 in `c1_ratio`
  (0.4 µG)** — 1.2 % of `c1_ratio`'s own value. On that reading the mean-field
  phase diagram is defensible.
- Under **each branch in its own functional**, it costs **7.3e-3 (9.9 µG)** —
  26 % of `c1_ratio`, and it changes the *topology* of the diagram, not just the
  position of a line.
- **`spatial` decides between them.** It assumes no ansatz and lands with the
  per-state answer (6.6e-3 against 7.3e-3, a 10 % difference), not with the
  common-functional one (3.4e-4, a factor 19 away). So the defensible reading is the expensive one: **the mean-field
  FM/polar line at `c1_ratio ≈ 1/36` is NOT defensible**, and the campaign's
  `provisional / mean-field-only` self-labelling was right.

Scope, plainly: 32×32×64, one geometry, one field, `c1_ratio` axis only. No
convergence-in-resolution study was run, and the `converged` flag is false on
every cell because `tol = 1e-9` is below this problem's gradient floor — the
figures that matter are |∇E| ~ 1e-5 to 1e-8, which puts the energy error many
orders below the 0.01 shifts being read. Three cells sit at |∇E| ~ 1e-1 to 3e-2
(`fm_ctrl30` and `fm_spatial` at `c1_ratio = 0.028`, `fm_spatial` at 0.029) and
should not be leaned on individually.

## 6. Criterion C — the `SpatialLHY` residual in µG

**Two defects had to be fixed before this could be measured at all**, and both
were silent:

1. `spatial_lhy_residual` compared a table built with `n_atoms = N` against an
   **undivided** BdG reference, so it returned ≈ 1 − 1/N for every production
   config. On the converged Eu states it read exactly **1.0000** — a "100 %
   residual" that is entirely the missing factor and that would have been
   reported as the spatial approximation collapsing. Every existing test ran at
   the default `n_atoms = 1`, where the bug is invisible; the new case runs at
   50000 and asserts the residual is *invariant* under `n_atoms`, which a scale
   bug cannot satisfy.
2. Even fixed, that function is the wrong quantity for this question. It takes
   the worst case over voxels drawn **uniformly**, so it is dominated by the
   dilute edge, where the local spinor is furthest from its bin's representative
   and the density contributes essentially nothing. It reads 16–38 % where the
   error on the integrated energy is 3–7 %. `spatial_lhy_energy_residual`
   importance-samples ∝ `n^(5/2)` instead — the weight ε_LHY actually carries —
   and compares at each voxel's **own** density rather than at n = 1, which also
   folds in the `ε ∝ n^(5/2)` scaling the table assumes (exact only for
   degenerate Zeeman energies, and at 44 µG `p·F ≈ 3.9` against `c₀n ≈ 8.6`).

Measured on the converged states of the Bz campaign:

| B (µG) | signed | non-cancelling | worst weighted voxel | uniform worst (old) |
|---:|---:|---:|---:|---:|
| 0 | **0 (exact)** | — | — | — |
| 5 | −0.032 | 0.034 | 0.082 | 0.114 |
| 10 | **−0.035** | 0.045 | 0.096 | 0.147 |
| 15 | −0.033 | 0.046 | 0.073 | 0.137 |
| 20 | **+0.064** | 0.064 | 0.127 | 0.199 |
| 30 | +0.057 | 0.057 | 0.186 | 0.234 |
| 40 | +0.022 | 0.028 | 0.074 | 0.215 |
| 55, 70 | **0 (exact)** | — | — | — |

The **polar branch has no *spatial* residual at all**: its p spread is below
`min_spread`, so `compute_spatial_lhy` declines to build a table and falls back
to the single-spinor `full_bdg` one, which is exact for a state that has one
spinor shape. (Recording that as a missing row rather than as zero would have
dropped the branch out of the propagation and halved the answer.) It is zero for
*this* approximation only — that branch still carries the ±1.3 % scheme band of §3,
which is a different and larger error and is not double-counted here.

**Propagation.** The residual moves only the stretched branch, so the gap moves
by `signed × E_LHY` and the boundary by that over the measured slope:

| B (µG) | 5 | 10 | 15 | 20 | 30 | 40 |
|---|---:|---:|---:|---:|---:|---:|
| δ(ΔE) | −0.0133 | −0.0144 | −0.0132 | +0.0248 | +0.0205 | +0.0074 |
| **δB (µG)** | −0.43 | **−0.46** | −0.42 | **+0.80** | +0.66 | +0.24 |

**So the `SpatialLHY` residual is worth |δB| ≤ 0.8 µG on the boundary — an order
of magnitude below the ~10 µG the scheme choice is worth.** Quote it; do not lead
with it. Note the residual is ~3–6 %, not the 1–3 % the issue and `spatial.jl`
record; those came from `n_atoms = 1` test states and from the uniform-worst
statistic respectively.

## 7. Criterion D — which claims need ε_LHY at all

Measured by `bench/lhy_state_dependence.jl` and `bench/lhy_texture_polarisation.jl`.

### 7.1 The dependence is on |⟨F⟩|, not on its direction — with two caveats that were not recorded

Rotating the FM spinor through six Euler triples, at fixed p = 1:

| | contact | with DDI |
|---|---:|---:|
| B = 0, max relative deviation | **5.3e-7** | **2.45e-2** |
| B = 44 µG, max relative deviation | 7.6e-3 | 2.43e-2 |

The contact part is an SO(3) scalar and the B = 0 row confirms it to the
quadrature's own accuracy. Two things this repo records are wrong at Eu:

- **`CLAUDE.md` and `spatial.jl` say the DDI moves ε_LHY by 0.25 % under
  rotation, and conclude that "a pure direction texture is free".** That 0.25 %
  was measured at ε_dd ≈ 0.05. At Eu's ε_dd = 0.54 it is **2.45 %**, an order of
  magnitude larger. Direction textures are cheap, not free. (This one barely
  moved under the BdG correction — 2.63 % pre-fix — because it is a ratio of two
  values computed the same way.)
- **A magnetic field breaks the contact invariance too**, because it picks the
  z axis: 7.6e-3 at 44 µG against 5.3e-7 at zero field. Any statement of the
  form "rotating the spinor cannot change ε_LHY" is a zero-field statement.
  (My first run of this probe measured only the 44 µG case and would have
  reported the contact invariance as broken at the 1 % level — the B = 0 row is
  the control that separates the theory from the probe.)

### 7.2 The magnitude dependence is a factor 2.7, not "~20 %"

Along ζ(α) = cos α |m=+F⟩ + sin α |m=0⟩, which sweeps p from 1 to 0:

| p | 1.000 | 0.905 | 0.794 | 0.655 | 0.500 | 0.345 | 0.206 | 0.095 | 0.000 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ε (contact) ×10³ | 1.354 | 1.154 | 0.963 | 0.739 | 0.512 | 0.392 | 0.344 | 0.342 | 0.364 |
| ε (with DDI) ×10³ | 2.080 | 1.794 | 1.500 | 1.153 | 0.899 | 0.751 | 0.703 | 0.722 | 0.775 |

**ε(p=1)/ε(p=0) = 2.68 with the DDI, 3.72 contact-only** — not the ~20 % that
`spatial.jl` records. The knob it rides on is `c1_ratio`, which is why a number
measured near zero would have looked small:

| c1_ratio | 0 | 0.001 | 0.005 | 0.01 | 0.02 | **1/36** | 0.05 | 0.10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ε(p=1)/ε(p=0) | 1.38 | 1.47 | 1.80 | 2.16 | 2.59 | **2.68** | 2.60 | 2.27 |

At `c1_ratio = 0` every `g_S` collapses to `c₀` and the two contact closed forms
are identical — the residual 1.38 there is the DDI alone. So the spatial LHY is
doing considerably more work at the campaign's coupling than its own docstring
claims, and that matters for criterion C.

Note the contact column is untouched by the BdG correction (it has no DDI block)
while the DDI column moved from 3.88 to 2.68 — which is a useful check that the
correction landed where it should and nowhere else.

### 7.3 Which named states carry a p spread at all

`_lhy_texture_spread` — the same function `make_workspace` warns from —
evaluated on each seed at 32×32×64:

| seed | spread in p | p | single-spinor table |
|---|---:|---:|---|
| `m_plus_F`, `m_minus_F`, `flower`, `chiral_spin_vortex`, `radial_spin_vortex`, `axial_spin_texture`, `skyrmion`, `spin_helix`, `vortex_lattice` | 0.0000 | 1.00 | **exact** |
| `polar`, `polar_core_vortex`, `cyclic`, `biaxial_nematic` | 0.0000 | 0.00 | **exact** |
| `uniform`, `antiferromagnetic` | 0.0000 | 0.83 | **exact** |
| `magnetic_domain` | 0.0424 | 0.96 | ok |
| `domain_wall` | 0.6973 | 0.30 | **needs `:spatial`** |

"Exact" means *at that state's own p* — not at p = 1. `polar_core_vortex` is a
pure direction texture with p ≡ 0, so giving it the fully-polarised functional is
a 2.7× error, not a free choice. This is the seed, not the converged state; the
campaign's relaxed weak-field Eu states sit at spread ≈ 0.9.

### 7.4 The table

| claim | needs ε_LHY? | why |
|---|---|---|
| a p ≡ 1 texture (flower, CSV, skyrmion, vortex lattice) exists at these parameters | **no** | ε_LHY is a common offset; the table is exact at p = 1 |
| energy ORDERING between two p ≡ 1 textures | **no**, to 2.45 % of ε_LHY | only the DDI's rotational anisotropy survives — ~2.45 % of ~1.3 % of E |
| energy ordering between a p = 1 and a p = 0 state (FM vs polar, FM vs PCV) | **yes** | ε differs 2.7× between them |
| the stretched↔polar boundary B_c(κ) | **yes** — §5 quantifies it | it is the previous row's ordering, read as a crossing |
| discrete observables at fixed parameters (winding number, vortex count, ring count) | **no** | unless the boundary they sit next to moves past them — §5 |
| **#336** droplet self-binding | **yes, and it is the reason the object exists** | but the droplet is p ≈ 1, so `fm_dipolar` is both correct and sufficient |
| **#334** in-place nucleation, beyond mean field | **yes, and needs `:spatial`** | p varies across the cloud during nucleation |
| **#335** hysteresis numbers | **yes**, through the boundary position | §5 |
| anything at `c1_ratio = 0` | **weakly** | the p-dependence collapses to the DDI's 1.38× there |


---

## 8. What this changes for the blocked work

| issue | was blocked on | now |
|---|---|---|
| **#334** in-place nucleation, beyond mean field | "no usable ε_LHY" | **unblocked.** Use `:spatial` — p varies across the cloud during nucleation, so no fixed ansatz applies. Quote ±1.3 % (scheme) ⊕ the spatial residual of §6. |
| **#335** hysteresis numbers | "the boundary position is an LHY-free value" | **the concern is confirmed, not dismissed.** At `c1_ratio ≈ 1/36` the mean-field FM/polar line is not merely displaced but absent; any boundary-position number wants the `:spatial` arm. The discrete observables #335 settled on (occupied m_F count, spinodal field) are the right shape precisely because they do not ride on a boundary position. |
| **#336** Saito–Li torus / droplet | "the stabilising term is ill-posed" | **unblocked, and it was the easiest case all along.** A droplet is p ≈ 1, so `fm_dipolar` is exact for its ansatz and is what the Saito group itself uses. |
| `runs/eu_gs_phase_c1_B_kappa` (35 configs) | self-labelled `mean-field-only / provisional` | **the label was right and should stay** for the FM/polar line. It is not a caveat about missing compute — §5.4 measures the effect at 26 % of `c1_ratio`. |

## 9. What is NOT established

- **One geometry.** 32×32×64, box 12×12×24, κ = 1. No resolution-convergence
  study of the boundary shift was run.
- **Two conventions, not all conventions.** §3 measures the spread between
  `full_bdg`'s branch/counterterm bookkeeping and its counterterm-consistent
  repair. That is a measurement of the mechanism the code's own warning names,
  not a proof that every conceivable prescription agrees to 6 %.
- **No experimental anchor.** Everything here is verification type **A/B** in the
  repo's own taxonomy — code correctness and internal physics agreement. Nothing
  in this document is compared against published Eu data.
- **The `spatial` table's own second approximation is now measured but not
  removed.** `ε ∝ n^(5/2)` is exact only for degenerate Zeeman energies, and at
  44 µG the splitting is comparable to the interaction energy. §6 folds that into
  the residual; it does not fix it.
- **`c₁ < 0` was not measured here.** The `verification_suite` / `eu_k3_*`
  families run at `c1_ratio = −0.005`, where `icosahedral` and `polar_contact`
  refuse by construction. Those configs need `fm_dipolar` (their states are
  `m_minus_F`, i.e. p = 1, so it is the right functional) — but the boundary
  measurement above was done at `+1/36` and does not transfer.
