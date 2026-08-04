# SPGPE Kibble–Zurek: what is reproduced and what is not

Target: McDonald & Bradley, PRA **92**, 033616 (2015), [arXiv:1507.08357](https://arxiv.org/abs/1507.08357).
Toroidal SPGPE, chemical-potential quench, winding-number statistics.

Protocol in `docs/guides/figures/kz_toroidal_winding.jl`; the literature basis and
the reasoning for each choice in `docs/design/kz_spgpe_protocol.md`.

## Reproduced: the number-damping SPGPE

| quantity | measured | published | |
|---|---|---|---|
| `α` (freeze-out, `t̂ ∝ τ_Q^α`) | 0.46 – 0.51 | 0.5119 ± 0.0178 | threshold swept 2–20 % of `N_TF`, answer unchanged |
| `β` (`σ(W) ∝ τ_Q^(−β)`) | **0.1283 ± 0.0078** | 0.1236 ± 0.0098 | **0.37 σ** |

`β` is a combination of three independent runs and is invariant under the two
things that would expose it as a local slope rather than an exponent:

- **`γ` × 3** (0.03 → 0.1, same window in `t̂/τ_Q`): 0.1053 ± 0.0154 → 0.1362 ± 0.0113.
  `γ` sets `τ₀`, not the scaling, so a `β` that moved with it would not be an exponent.
- **`L` × 4** (200 → 800, `dx` fixed): 0.1362 ± 0.0113 → 0.1367 ± 0.0154, while
  `ξ̂/L` goes from 0.5 to 0.13. No finite-size bias.

Per-point sanity, every point: 100 % integer windings, `⟨W⟩` within 2σ of zero,
`N_final` at the Thomas–Fermi `μL/g₁`.

### The two things that made this work

**`τ_Q` must clear the freeze-out.** The measured `t̂ = 3.4√(τ_Q/γμ₀)` must be small
against the ramp. The first scan ran `τ_Q` = 7.4 … 2981 at `γ = 10⁻²`, where
`t̂/τ_Q` = 3.40, 2.06, 1.25, 0.76, 0.46, 0.28, 0.17 — four of seven points frozen
through the entire ramp, and `σ(W)` flat in consequence. The paper's `e²…e⁸` is in
units of the relaxation time `τ = ℏ/(γμ₀) = 100/ω_⊥`, not `1/ω_⊥`.

**The field must be scalar.** Running on an F=1 species gives three components and
the reservoir noise fills all of them, so the empty spin channels feed `c₀n` and
shift the effective `μ`. The tell is that windings came out non-integer (2.25); a
condensate winds by whole turns.

## NOT reproduced: the full SPGPE

Every full-SPGPE number is retracted — `β` = 0.0938 ± 0.0166 (`γ`=0.1),
0.0568 ± 0.0154 (`γ`=0.03), the combined 0.0739 ± 0.0113, and the 3.5σ separation
from the number-damping case. Two independent reasons:

**1. The equilibrium was wrong.** With energy damping on, the field equilibrated to
55 % of Thomas–Fermi at both `γ` = 0.1 and 0.01. Both reservoir processes satisfy
detailed balance with the same `(μ, T)`, so the stationary state cannot depend on
`ℳ̄`. Cause: the term multiplies by a phase, the caller projects the *state*, and
`P{}` in Eq. (4) applies to the *increment*. Band-limiting the kernel and the
noise to the C region (Eq. 15, which this implementation was missing) improved the
4000-step survival at `ℳ̄` = 0.1 by 600× and made the equilibrium `ℳ̄`-independent.

**2. The separation vanishes on a larger ring.** At `L` = 800 the full case gives
`β` = 0.1295 ± 0.0168 against the number-damping 0.1367 ± 0.0154 — indistinguishable.
At `L` = 200 the full case had `ξ̂ = L/(4σ²)` = 145–153 on a ring of 200, so a
single domain spanned it and `σ(W)` could not fall further, biasing `β` down.

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

A KZ run reaches `τ_Q` = 10⁵ time units, so even `ℳ̄` = 10⁻³ — 5 % lost over 200 —
loses everything. **The full SPGPE is therefore not usable for long runs as
implemented**, and since McDonald & Bradley run `ℳ̄` = 10⁻² over comparable times,
their scheme contains something this one does not. Reading PRE 89, 013302 §III in
full is the next step, not another guess at the update form: two increment forms
were already tried and discarded before consulting it.
