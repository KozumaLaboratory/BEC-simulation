# Which ε_LHY to use for ¹⁵¹Eu F=6, and how big the remaining ambiguity is

Answers issue #337. **The premise the issue was opened on does not survive
measurement**: ε_LHY is not ill-posed for Eu F=6. The instability it names is
real, is entirely dipolar, and is not removable by any knob — but the ambiguity
it creates in the *number* ε_LHY is **at most ~6 %** across the
whole range from zero dipole to the physical Eu dipole, not O(1). That is small enough to quote a beyond-mean-field
result with an error bar, which is what the previous verdict
(`docs/validation/full_bdg_scheme_dependence_eu_f6.md`, "NOT ANSWERABLE with the
current machinery") said could not be done.

Everything below is measured at the campaign's own parameter point — ¹⁵¹Eu,
`c1_ratio = 1/36`, N = 50000, ω_ref = 2π × 110 Hz, peak density n = 3.7e-3,
32 propagation directions — by `bench/lhy_unstable_window.jl`,
`bench/lhy_growth_vs_field.jl` and `bench/lhy_scheme_probe.jl`.

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

| state | c_dd = 0 | c_dd = Eu |
|---|---:|---:|
| FM, m = +F | **0** | 3.67 – 4.13 |
| FM, m = −F | **0** | 3.66 – 4.66 |
| polar, m = 0 | **0** | 15.16 – 11.88 |

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

### 2.1 The field is not an escape route — but the recorded numbers for why were wrong

`full_bdg_scheme_dependence_eu_f6.md` dismisses `q` with a table reading
"50 µG ⇒ p = −7.40e-05, q = 3.23e-16". **Both figures are wrong**, by 10⁴ and
10⁸: `linear_zeeman_p` takes **tesla**, the campaign YAML writes
`Bz: "4.4e-5 Gauss"` = 4.4e-9 T, and `cli.jl inspect` on that config resolves
`p = −0.651`, `q = +2.502e-08`. The correct row for 50 µG is
`p = −0.7398`, `q = 3.231e-08`.

The conclusion survives the correction, and now for a measured reason rather
than an arithmetic one. Sweeping the real field:

| B (µG) | p | q | growth, FM m=+F | growth, polar |
|---:|---:|---:|---:|---:|
| 0 | 0 | 0 | 3.667 | 15.164 |
| 44 | −0.651 | 2.50e-08 | 3.883 | 15.142 |
| 100 | −1.480 | 1.29e-07 | 3.891 | 15.051 |
| 1000 | −14.80 | 1.29e-05 | 2.321 | 7.710 |

A linear Zeeman term shifts every branch and the chemical potential together, so
it does **not** gap the spin channel; the growth rate is flat to ~6 % over the
whole experimental range. Reaching stability would need kilogauss, which is not
this experiment. Same verdict, different (and this time correct) numbers.

A useful by-product: **ε_LHY itself is nearly field-independent here** —
2.1318e-3 at B = 0 against 2.0877e-3 at 100 µG for the FM spinor, i.e. −2 %.
So the 2026-07-30 defect in which `_build_spinor_lhy` never passed `zeeman` to
the table builder, while a genuine bug, moved no number in this regime by more
than that.

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
| FM m=+F | Eu | 32 / 32 | 6.02 | 12.0 | 0.594 | **+0.006** |
| polar m=0 | 0 | 0 / 1 | 0 | 4.16 | 0 | **0.000** |
| polar m=0 | Eu | 26 / 32 | 4.55 | 4.16 | 0.672 | **+0.054** |

Two things to read here, and they point opposite ways:

- **The unstable band is not an infrared artefact.** It reaches
  $k_{\rm unst} \approx k_s$, the stiffness momentum that sets the integrand, and
  carries 59–67 % of $\int|k^2 I(k)|\,dk$. It is also 9–12 × above
  $k_{\rm box} = 2\pi/L$, so these modes exist in the trapped, finite system —
  the "they are longer than the cloud, so drop them" argument is **not**
  available. At the worst k, 8 of 13 branches are complex for the FM spinor.
- **And yet ε_LHY barely moves.** The complex pairs are essentially purely
  imaginary, so their real zero-point contribution is ≈ 0 under either
  convention, and what is left is the counterterm mismatch — worth 0.6 % (FM)
  and 5.4 % (polar).

**A single point would have misled, and did.** The gap is not monotonic in the
dipolar strength — it starts negative, crosses zero near the physical coupling,
and grows positive beyond it. Quoting the FM value AT `c_dd = c_dd(Eu)` alone
(+0.6 %) would have been quoting an accidental zero crossing:

| c_dd / c_dd(Eu) | FM k_unst | FM gap | polar k_unst | polar gap |
|---:|---:|---:|---:|---:|
| 0.00 | 0 | **0.0000** | 0 | **0.0000** |
| 0.10 | 2.86 | −0.0125 | 1.39 | −0.0122 |
| 0.25 | 4.12 | −0.0330 | 2.18 | −0.0148 |
| 0.50 | 5.31 | **−0.0577** | 3.17 | −0.0031 |
| 0.75 | 4.99 | −0.0224 | 3.96 | +0.0212 |
| **1.00 (Eu)** | 6.02 | **+0.0064** | 4.55 | **+0.0540** |
| 1.50 | 7.56 | +0.0445 | 5.54 | +0.1192 |
| 2.00 | 8.02 | +0.1222 | 6.53 | +0.1526 |

So the number to carry is the **maximum over the range**, not the value at the
point: **|gap| ≤ 6 % for both states for `0 ≤ c_dd ≤ c_dd(Eu)`**, rising to
12–15 % at twice the Eu dipole. The sweep is also the continuity check — the gap
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
allowed, and the comparison is now quotable anyway.** ε_LHY at the campaign
point is 2.119e-3 for FM and 5.456e-4 for polar, a factor **3.9**. That is
physics, not convention: applying the fully-polarised functional to a polar state
overestimates it ~4×. So an FM-vs-polar energy ordering must evaluate each state
in its own functional (`full_bdg`, or the matching closed form), and carry the
**±6 %** scheme band measured in §3. Which is a usable error bar — the previous
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

*(measured in `runs/eu_lhy_boundary_337/`; see §5 below)*

## 6. Criterion C — the `SpatialLHY` residual in µG

## 7. Criterion D — which claims need ε_LHY at all

Measured by `bench/lhy_state_dependence.jl` and `bench/lhy_texture_polarisation.jl`.

### 7.1 The dependence is on |⟨F⟩|, not on its direction — with two caveats that were not recorded

Rotating the FM spinor through six Euler triples, at fixed p = 1:

| | contact | with DDI |
|---|---:|---:|
| B = 0, max relative deviation | **5.3e-7** | **2.6e-2** |
| B = 44 µG, max relative deviation | 7.6e-3 | 4.2e-2 |

The contact part is an SO(3) scalar and the B = 0 row confirms it to the
quadrature's own accuracy. Two things this repo records are wrong at Eu:

- **`CLAUDE.md` and `spatial.jl` say the DDI moves ε_LHY by 0.25 % under
  rotation, and conclude that "a pure direction texture is free".** That 0.25 %
  was measured at ε_dd ≈ 0.05. At Eu's ε_dd = 0.54 it is **2.6 %**, an order of
  magnitude larger. Direction textures are cheap, not free.
- **A magnetic field breaks the contact invariance too**, because it picks the
  z axis: 7.6e-3 at 44 µG against 5.3e-7 at zero field. Any statement of the
  form "rotating the spinor cannot change ε_LHY" is a zero-field statement.
  (My first run of this probe measured only the 44 µG case and would have
  reported the contact invariance as broken at the 1 % level — the B = 0 row is
  the control that separates the theory from the probe.)

### 7.2 The magnitude dependence is a factor 3.9, not "~20 %"

Along ζ(α) = cos α |m=+F⟩ + sin α |m=0⟩, which sweeps p from 1 to 0:

| p | 1.000 | 0.905 | 0.794 | 0.655 | 0.500 | 0.345 | 0.206 | 0.095 | 0.000 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ε (contact) ×10³ | 1.354 | 1.154 | 0.963 | 0.739 | 0.512 | 0.392 | 0.344 | 0.342 | 0.364 |
| ε (with DDI) ×10³ | 2.119 | 1.987 | 1.558 | 1.216 | 0.847 | 0.657 | 0.523 | 0.515 | 0.546 |

**ε(p=1)/ε(p=0) = 3.88 with the DDI, 3.72 contact-only** — not the ~20 % that
`spatial.jl` records. The knob it rides on is `c1_ratio`, which is why a number
measured near zero would have looked small:

| c1_ratio | 0 | 0.001 | 0.005 | 0.01 | 0.02 | **1/36** | 0.05 | 0.10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ε(p=1)/ε(p=0) | 1.50 | 1.61 | 2.09 | 2.71 | 3.56 | **3.88** | 4.04 | 3.49 |

At `c1_ratio = 0` every `g_S` collapses to `c₀` and the two contact closed forms
are identical — the residual 1.50 there is the DDI alone. So the spatial LHY is
doing considerably more work at the campaign's coupling than its own docstring
claims, and that matters for criterion C.

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
a 3.9× error, not a free choice. This is the seed, not the converged state; the
campaign's relaxed weak-field Eu states sit at spread ≈ 0.9.

### 7.4 The table

| claim | needs ε_LHY? | why |
|---|---|---|
| a p ≡ 1 texture (flower, CSV, skyrmion, vortex lattice) exists at these parameters | **no** | ε_LHY is a common offset; the table is exact at p = 1 |
| energy ORDERING between two p ≡ 1 textures | **no**, to 2.6 % of ε_LHY | only the DDI's rotational anisotropy survives — ~2.6 % of ~1.3 % of E |
| energy ordering between a p = 1 and a p = 0 state (FM vs polar, FM vs PCV) | **yes** | ε differs 3.9× between them |
| the stretched↔polar boundary B_c(κ) | **yes** — §5 quantifies it | it is the previous row's ordering, read as a crossing |
| discrete observables at fixed parameters (winding number, vortex count, ring count) | **no** | unless the boundary they sit next to moves past them — §5 |
| **#336** droplet self-binding | **yes, and it is the reason the object exists** | but the droplet is p ≈ 1, so `fm_dipolar` is both correct and sufficient |
| **#334** in-place nucleation, beyond mean field | **yes, and needs `:spatial`** | p varies across the cloud during nucleation |
| **#335** hysteresis numbers | **yes**, through the boundary position | §5 |
| anything at `c1_ratio = 0` | **weakly** | the p-dependence collapses to the DDI's 1.50× there |
