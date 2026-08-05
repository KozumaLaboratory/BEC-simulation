# SPGPE Kibble–Zurek: what is reproduced and what is not

Target: McDonald & Bradley, PRA **92**, 033616 (2015), [arXiv:1507.08357](https://arxiv.org/abs/1507.08357).
Toroidal SPGPE, chemical-potential quench, winding-number statistics.

Protocol in `docs/guides/figures/kz_toroidal_winding.jl`; the literature basis and
the reasoning for each choice in `docs/design/kz_spgpe_protocol.md`.

## Reproduced: both reservoir settings

`L` = 800, `γ` = 0.1, 320 trajectories per point, `τ_Q` = 10³ … 10⁵, all shards
sharing one provenance record (`head=ccf8a788 dirty=false`).

| quantity | measured | published | |
|---|---|---|---|
| `α` (freeze-out, `t̂ ∝ τ_Q^α`) | 0.46 – 0.51 | 0.5119 ± 0.0178 | threshold swept 2–20 % of `N_TF` |
| `β` number-damping | **0.1327 ± 0.0109** | 0.1236 ± 0.0098 | **0.6 σ** |
| `β` full SPGPE | **0.0960 ± 0.0109** | 0.0966 ± 0.0128 | **0.05 σ** |
| separation | 0.0367 ± 0.0154 | 0.027 ± 0.0161 | 2.4 σ |

So energy damping lowers `β`, which is the paper's result and the reason this
branch exists: the number-damping SPGPE has a non-conserved order parameter and no
conserved density (model A, `z = 2`), and the energy-damping reservoir supplies the
number-conserving coupling that defines model E/F.

### Why these are exponents and not window-averaged slopes

An earlier `β` = 0.0991 ± 0.0067 was retracted for landing on the published value
while its local slope drifted across the window. The checks it failed:

**Local slope, consecutive points, each ± 0.05:**

| `τ_Q` window | number-damping | full |
|---|---|---|
| 10³ → 3×10³ | 0.076 | 0.096 |
| 3×10³ → 10⁴ | 0.175 | 0.077 |
| 10⁴ → 3×10⁴ | 0.140 | 0.135 |
| 3×10⁴ → 10⁵ | 0.110 | 0.072 |

Scatter consistent with the errors and no trend, where the retracted fit ran
0.070 → 0.128 monotonically.

**Every point inside the scaling regime.** The measured freeze-out
`t̂ = 3.4√(τ_Q/γμ₀)` gives `t̂/τ_Q` = 0.34, 0.20, 0.11, 0.062, 0.034 — the ramp is
long against the freeze-out throughout. The retracted scan had four of seven points
above 1, frozen through the entire ramp.

**Invariant under `γ` × 3** (0.03 → 0.1 at fixed `t̂/τ_Q`): 1.6 σ for both settings.
`γ` sets `τ₀`, not the scaling, so a `β` that moved with it would not be an exponent.

**Invariant under `L` × 4** (200 → 800, `dx` fixed) for number damping, while
`ξ̂/L` goes 0.5 → 0.13. The full case is NOT invariant and must use `L` = 800: at
`L` = 200 it had `ξ̂ = L/(4σ²)` = 145–153 on a ring of 200, so one domain spanned
the ring, `σ(W)` could not fall further and `β` came out biased low (0.0739 ± 0.0113).

**Residual error below propagated error** (0.0082 and 0.0049 against 0.0109), so
the line is not drawn through scatter.

Per-point sanity, every point: 100 % integer windings, `⟨W⟩` within 1.7 σ of zero,
`N_final` at the Thomas–Fermi `μL/g₁`.

### The four things that had to be right

**`τ_Q` must clear the freeze-out.** The paper's `e²…e⁸` is in units of the
relaxation time `τ = ℏ/(γμ₀) = 100/ω_⊥`, not `1/ω_⊥`. Read the other way, most of
the scan sits frozen and `σ(W)` is flat in `τ_Q`.

**The field must be scalar.** An F=1 species gives three components and the
reservoir noise fills all of them, so the empty spin channels feed `c₀n` and shift
the effective `μ`. The tell was non-integer windings (2.25); a condensate winds by
whole turns.

**The energy-damping kernel and its noise must be band-limited to the C region**
(Eq. 15). Unrestricted, `1/|k|` puts out-of-band structure into a phase that
multiplies the field, and the projector removes the product every step — worth 4.3×
in the loss rate on a grid with headroom above the cutoff.

**Trajectory seeds must be separated by more than the step count**, since the
per-step draw is `seed + s`. Separated by 1, four "independent" runs were one noise
sequence shifted by a step, and gave `⟨W⟩` = 2.25 with every sign the same.

## Anchor for the spinor step: the c1 = 0 limit

Step 1 has no published number to check against. The literature splits either side
of it — the toroidal SPGPE winding work is scalar (McDonald & Bradley PRA 92,
033616), the spin-1 winding work is `T = 0` GPE (Uhlmann, Schützhold & Fischer;
Saito et al.), and the spin-1 SPGPE work is equilibrium BKT in 2D (Underwood &
Blakie). A spin-1 SPGPE thermal quench on a torus fitted for a winding exponent
appears to be unpublished, which puts step 1 in the same position as the retracted
`α = 0.93`: a measurement with no external check.

**The anchor is the `c1 = 0` limit, and it is not "the scalar case".** At `c1 = 0`
the three components still share the density mean field `c₀n` and the reservoir
noise still fills all of them, so the system is an SU(3)-symmetric three-component
mixture, not one scalar field. What survives the limit is the *universality class*
of a single component's phase transition: with the spin channel switched off, each
component's phase orders independently apart from the shared mean field, so `τ₀` and
the amplitude change but the exponent does not.

So the prediction, recorded before the run:

> `β` from the per-component winding at `c1 = 0`, three components, must agree with
> the scalar `β = 0.1327 ± 0.0109` — and the amplitude need not.

If it does, the spinor path is continuously connected to a reproduced published
number and a `c1 ≠ 0` result can be read as a departure from it. If it does not,
either the spinor plumbing changes something it should not, or the reasoning above
is wrong; both have to be settled before any `c1 ≠ 0` exponent is quoted.

Two further anchors exist and are cheaper than a new physics claim:

- **`σ(W) ∝ √L`** for spin vortices, which Uhlmann et al. establish at `T = 0`. The
  size-scan machinery already measured exactly this for the scalar case
  (`σ(W)` went 1.26 → 2.38 → 2.62 for `L` = 200 → 400 → 800 against a `√L`
  prediction of 1.26 → 1.78 → 2.52).
- **Two scaling regimes from magnetisation conservation** (Świsłocki, Witkowska,
  Dziarmaga & Matuszewski, PRL 110, 045303). Contact interactions conserve
  magnetisation, so this applies directly and predicts the exponent splits rather
  than shifting smoothly.

## Open: the residual number loss

Exact number conservation is not available in the projected scheme — the product
of two band-limited fields reaches `2k_cut`, and Rooney, Blakie & Bradley
(PRE **89**, 013302) state that conservation there is approximate. After
band-limiting, the loss rate is:

| `ℳ̄` | loss per unit time | 1/e time | survival over 200 |
|---|---|---|---|
| 0.1 | 0.0238 | 42 | 0.85 % |
| 0.01 | 0.00238 | 420 | 62 % |
| 0.001 | 0.000255 | 3900 | 95 % |

Measured `dt` = 0.05, 0.01, 0.002 at each `ℳ̄`: **the rate does not depend on `dt`**
(0.0238 / 0.0250 / 0.0243 at `ℳ̄` = 0.1, a 25× change in `dt`), while `φ_rms` falls
as `√dt`. So this is not a discretisation error and no step size removes it. The
rate is linear in `ℳ̄`.

Those rates are for `γ = 0`, where scattering is the only process and a leak
integrates without bound. **That is not the production configuration and reading it
as one was an error.** With `γ` = 0.1 the growth term pulls `N` back to the `(μ,T)`
equilibrium continuously, so a steady leak shifts a steady state instead of
accumulating — measured over the full duration a KZ run spans:

| `ℳ̄` | `N/N_TF` at `t` = 10³ | 10⁴ | 3×10⁴ | 10⁵ |
|---|---|---|---|---|
| 0 | 0.989 | 1.003 | 0.988 | 1.012 |
| 0.001 | 0.995 | 0.998 | 0.994 | 1.002 |
| 0.01 | 0.993 | 1.001 | 0.990 | 0.992 |
| 0.1 | 1.004 | 0.988 | 0.986 | 0.983 |

Within 2 % throughout, at every `ℳ̄`. Rooney, Blakie & Bradley carry only C-region
mode coefficients, so nothing leaks in their representation; on a full grid it does,
and with growth on it does not accumulate. What remains open is the precompile-cache
hole in provenance (`cached=` records it) and the twelve other drivers under
`docs/guides/figures/` that write CSVs without a stamp.
