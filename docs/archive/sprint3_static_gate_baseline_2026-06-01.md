<!-- promoted from agent memory `sprint3_static_gate_baseline_2026_06_01.md` on 2026-07-31; historical record, not an SSoT -->
<!-- "F=6 Eu static stretched GS Fisher gate (Sprint 3) yields 0/5 NEW c information — the one MEAS direction is the already-known a_12 prior constraint, the other 4 directions are null by construction. The c sensitivity actually lives in EdH dynamics (m=-6 cascade depolarization), which has not yet been Fisher-analyzed. Sprint 4 item 0 added: dynamic EdH Fisher before any new-protocol additions." -->

# Sprint 3 gate honest accounting: 0/5 NEW info, not 1/5

**Date 2026-06-01.** Run: `scripts/fisher_sprint3_eu_f6_gate.jl`. Engineering
validated — Fisher utilities, c basis, `_cn_to_gS` constraint mapping, SVD
recovered the F²=36 slope of the stretched-pair formula exactly, which is a
clean synthetic-truth-recovery analog. But the **gate interpretation** I
initially printed was wrong on two counts.

## What the gate actually showed

Forward: 1D 24-pt harmonic trap, F=6 Eu, p=2.0 (strong σ-Zeeman → m=+F stretched).
Five parameters (c_0, c_1, c_2, c_4, c_6). Static ground state, no dynamics.

Result:
```
measurable rank = 1 / 5
Dir 5 [MEAS] σ_post=6.76e-3 :  ∝ c_0 + 36·c_1 + (tiny c_2, c_4, c_6)
4 NULL directions orthogonal to it
```

## The 1 MEAS direction = prior, not data

c_0 + F²·c_1 (with F=6 → c_0 + 36·c_1) is **exactly g_{S=2F}**, the stretched
pair scattering at S=12, which is set by `a_12 = 110 a_B` (the single known
spin-6 Eu scattering length). This is **the hard constraint we put into the
SBI prior**, not an experimental observation.

So the honest accounting is:
- **Effective new c information: 0/5**
- 5 null directions
- The "MEAS" direction is the prior constraint itself rediscovered

## Why this happened (structural, not a bug)

Strongly stretched GS is a single product state ψ = (...,0,0,φ(r))ᵀ. Channel
projectors P_S applied to (stretched, stretched) project onto S=2F only. So
the energy and density of a perfectly stretched cloud feel **only g_{2F}**,
by construction. The other 4 c-combinations don't couple in. The gate ran
exactly what we asked: g_{2F} sensitivity only. That sensitivity says
nothing about EdH because we never depolarized.

## Where the c information actually lives

The Matsui Science 2026 paper itself notes that the m=−4 ring count
distinguishes c_1 sign:
- c_1 ≈ 0 (ferromagnetic side): **2 rings**
- c_1 ≈ (1/18) c_0 (antiferromagnetic side): **3 rings**, matches experiment

So **standard EdH dynamics already constrains c_1**. The depolarization
cascade m=−6 → −5 → −4 from MDDI Δm=±1 spin-flips creates the
non-stretched populations whose radial structure is c-dependent. Fisher of
**dynamic** observables — f_m(t) cascade fractions, m=−4/m=−5 ring radii
and counts, inter-ring relative phase — will not return rank 0.

## Why D (no 3D needed) still stands, with corrected reasoning

The (ρ, z) reduction is exact under EdH-imprinted winding (ψ_m = χ_m(ρ,z)
e^{i w_m φ}, w_m = −F − m). The depolarization cascade preserves
axisymmetry. So the dynamic c-sensitive observables are captured by the
2D (ρ,z) PDE — no 3D needed. Earlier wording "3D unnecessary because
stretched feels only g_{2F}" was wrong. Correct wording: "3D unnecessary
because the EdH cascade preserves axisymmetric winding structure, and
(ρ,z) ansatz is closed under MDDI selection rules."

## Sprint 4 item 0 (executed — same rank 1 as static gate)

Two earlier bugs masked the real result on first attempt:
1. **Codebase convention violation in display**: `psi[..., c=1]` is m=+F not
   m=−F (CLAUDE.md). My output labels were reversed; corrected via
   `reverse(n_by_component)` in summary_populations.
2. **Wrong secular_ddi guard**: ran with `secular_ddi=true` which drops MDDI
   Δm=±1 off-diagonal terms — exactly the cascade channel. Eu EdH lives
   well below the codebase advisory threshold `ω_L/(c_dd·⟨n⟩) > 100`, so
   `secular_ddi=false` is the physical choice. Fixed.

Re-ran with grid 12³, T=0.5 ω_ref⁻¹ (~0.72 ms), N_steps=100, full DDI.
Cascade was clean: f[m=−6]=0.982, f[m=−5]=0.017, f[m=−4]=3.5e−4 — linear
FD regime (depolarisation 1.76%). 12.7 s per run, 116 s total Fisher.

**Result: measurable rank = 1, same direction as Sprint 3 static gate**.
The single MEAS eigenvector is (−0.028, −1.000, −0.007, −0.004, −0.001) in
the (c_0, c_1, c_2, c_4, c_6) basis — i.e. exactly the c_0+F²·c_1 = g_{2F}
direction. σ_post = 0.302 on the g_{2F} combination; 4 NULL directions
with eigenvalues 1e−9 → 1e−17 (totally degenerate).

## Stretched-EdH measurability theorem (2026-06-01, anko reframing)

This is not a measurement failure — it is **the data-driven proof that
stretched-EdH at linear order is structurally a 1-parameter probe**.

**Statement.** For any observable y (populations, radial moments, ring
radii, ring counts, …), any evolution time T, and any noise model, the
linearised Fisher information matrix of EdH dynamics from a pure
stretched m=±F initial state, parameterised in the spin-multipole basis
{c_0, c_1, c_2, c_4, c_6}, has rank ≤ 1. The single measurable direction
is g_{S=2F} = c_0 + F²·c_1.

**Proof sketch.** The relevant two-atom pair states reachable in the
linear cascade are:
- Initial:   (m=−F, m=−F)    → M = −2F
- First-order product: (m=−F, m=−F+1) → M = −2F+1

Bose symmetry restricts the pair channel to even S. The even-S channels
have max-|M| = 2F, 2F−2, 2F−4, …, so the highest |M| values −2F and
−2F+1 are **only** consistent with S = 2F. Both pair states are
therefore *pure* S = 2F. The channel projectors P_S for S ≠ 2F annihilate
them, so the energy and any dynamical matrix element depends only on
g_{2F} = Σ_n c_n × (eigenvalue of P_{2F})^n / normalisation. In the
{c_n} basis at S = 2F this evaluates to g_{2F} = c_0 + F²·c_1; all
other c_n combinations are orthogonal and unconstrained.

**Reading.** Linear Fisher rank from stretched EdH = 1, and that one
direction is the already-known a_12. This explains, from the inside,
why Matsui et al. were forced to read c_1/c_0 from **non-linear** ring
structure (the 2-ring-vs-3-ring m=−4 morphology) rather than from a
linear susceptibility, and why the remaining a_S were left unknown:
the linear susceptibility *doesn't have access*.

## Lever for new c information: regime, not observable

Items previously listed as separate — "multi-order cascade SBI" and
"spatial / ring observables" — are the same item. In the linear
regime, ∂(spatial moment)/∂c_n ∝ ∂(depolarisation)/∂c_n ⇒ collapses to
the same rank-1 g_{2F} direction. Ring-count discrimination is a
non-linear effect; it cannot be recovered by enriching the observable
set inside the linear regime. The lever is the **regime (linearity vs
non-linearity)**, not the observable.

## Sprint 4 item 1 v2 result (2026-06-01, cumulative-rank framing)

Static polar GS Fisher (24-pt 1D, q=−2 pinning polar as Zeeman GS, ITP
≈12 s/run). MEAS direction = (−0.984, 0, −0.097, −0.103, −0.112) — c_0
dominates, c_1 *exactly* zero (GP polar has ⟨F⟩=0 → spin_mixing step
identically no-op), c_2/c_4/c_6 contribute ~10× smaller via 6j-routed
tensor channels.

**Cumulative rank framing (anko correction):** this is the CORRECT
metric, not the per-config "rank 1/5". Sprint 3 stretched MEAS was
(0.028, 1, 0, 0, 0) = g_{2F} = c_0 + 36·c_1 + small higher; combined
with item 1 v2 MEAS ≈ pure c_0, we get **2 linearly independent
constraints in c-space ⇒ cumulative rank = 2/5**. With the a_12 prior
fixing g_{2F}, polar adds c_0 independently, and c_1 = (g_{2F} − c_0)/36
falls out by subtraction. **One null direction broken cheaply in the
linear-solvable world.** Per-config rank stays 1 (GP single configuration
has one effective coupling per Fisher), but multi-config accumulation
breaks nulls.

## Sprint 4 handoff, revised again — multi-config accumulation, spatial probes, Bogoliubov for tensor

### Two failure modes to avoid

**Category error trap** (corrected 2026-06-01, anko): "scalar Fisher
rank = 1 ⇒ need beyond-GP (TWA/TDHFB)". This is wrong. Matsui's
c_1 ↔ m=−4 ring-count discrimination was reproduced numerically in GP —
the c-sensitivity lives in SPATIAL profile of cascade products, not in
beyond-mean-field fluctuations. TWA/TDHFB are tools for fluctuation-
driven physics (spontaneous SB, vortex nucleation statistics = ④/⑥),
not for deterministic ring c-dependence. Scalar Fisher rank=1 is an
observable-choice failure, not evidence for beyond-GP.

**Rank vs precision conflation**: cumulative rank from N configs can be
formally ≤ N (linear-independence of ∇_c E vectors), but per-direction
σ_post can be terrible. Item 1 v2 already has σ_post=1.42 on c_0
(loose), tensor channels c_2/c_4/c_6 will be ≫ 1 in any static-EOS
config (they enter at ~5-10% of c_0 weight). Real lab observables are
noisier than ideal E. The richer probe for tensor channels is
**Bogoliubov / collective-mode spectrum** (spin-mode frequencies depend
directly on spin-dependent g_S), not stacking more static configs.

### Item A result (2026-06-01): Bogoliubov full-rank — SBI no longer needed for c determination

Polar GS + Bogoliubov spin-mode Fisher at k=0.5, 26 modes as observables.
Eigenvalues: `[93.9, 2740, 12400, 15300, 5.4e7]` — minimum 93.9, all
**well above prior precision** (naturalness σ_prior ~ 50 ⇒ prior precision
~4e-4; all 5 Fisher eigenvalues >> that).

| Direction | dominant | σ_post (absolute) | script verdict |
|---|---|---|---|
| Dir 5 | **c_1** (pure axis) | 1.4e-4 | MEAS |
| Dir 4 | c_2 mix in (c_2,c_4,c_6) | 8.1e-3 | MEAS |
| Dir 3 | c_6 mix in (c_2,c_4,c_6) | 9.0e-3 | MEAS |
| Dir 2 | c_4 mix in (c_2,c_4,c_6) | 1.9e-2 | NULL (relative-cutoff artifact) |
| Dir 1 | c_0 | 0.10 | NULL (relative-cutoff artifact) |

Mode-by-mode: the spin-mixing modes at ω ≈ ±6.7 (modes 11/12/15/16) have
max|∂ω/∂c_1| = 3.67 — they dominate c_1 sensitivity by 100× over the
higher modes. The 3-D tensor subspace (c_2, c_4, c_6) is fully resolved
into 3 independent MEAS directions (after prior-conditioning out the
relative-cutoff verdict).

**Cumulative: all 5 c parameters are measurable in linear Fisher across
{Sprint 3 stretched + Item 1 v2 polar + Item A Bogoliubov}**, with
precisions ranging from c_1 σ=1.4e-4 (super-tight) to c_0 σ=0.1 (still
informative). **SBI is no longer needed for c determination**.

### Item A stretched companion (2026-06-01): full-rank result is GS-generic

To rule out "polar-specific" full-rank, ran the same Bogoliubov Fisher
around stretched (m=+F) GS pinned by strong linear Zeeman p=2.

Stretched eigenvalues: `[301, 1920, 3525, 13924, 2.9e8]` — also
absolute-full-rank against the same prior precision floor 4e-4. All 5
directions MEAS with σ_post:
- c_1 axis: 5.9e-5 (2.4× tighter than polar 1.4e-4)
- tensor c_2/c_4/c_6 sub-space: 8e-3 to 2e-2 (comparable to polar)
- c_0 axis: 5.8e-2 (better than polar 0.10)

Stretched is structurally similar (single-component spinor → BdG with
the same channel structure) and Bogoliubov modes around any
single-component GS carry the full channel discrimination. **Item A is
generic, not polar-specific.** Either polar (q<0 pin) or stretched
(strong p) works experimentally; the lab can pick whichever is easier
to prepare and probe.

### Item A k-sweep robustness (2026-06-01): full-rank at any k

To rule out "k=0.5 lucky choice", swept K_SAMPLE ∈ {0.1, 0.5, 1.0, 2.0}
around polar GS. Every k value gives 5/5 measurable rank under prior-
aware cutoff. c_1 σ_abs stays at 1.36e-4 ± 3% across the band. The
tensor sub-space eigenvalues (~2740, 12400, 15300) are k-INDEPENDENT
to <1% — these are spin-channel modes whose frequency depends on g_S
through the channel weights, not on kinetic energy. c_0 precision
*improves* with k (λ_min: 3.81 → 1400 from k=0.1 to k=2) because
kinetic energy adds to the mean-field calibration at higher momentum.

**Operator guidance**: any k in [0.1, 2.0] works for the c
determination. The experiment routinely scans multiple k in
collective-mode spectroscopy anyway, so the requirement is met for
free. No critical "right k" selection issue.

### a_S basis transform (2026-06-01): σ ~ 0.05 a_Bohr per channel

Pushing the Item A polar Fisher matrix through `c_to_g` (= c_0 + λ_S·c_1
+ 6j contributions from c_2/c_4/c_6) gives per-channel scattering length
precision:

| S | σ(a_S) [a_Bohr] |
|---|---|
| 0 | 0.042 |
| 2 | 0.042 |
| 4 | 0.045 |
| 6 | 0.050 |
| 8 | 0.058 |
| 10 | 0.067 |
| 12 | (a_12 = 110 a_B, prior-fixed) |

**Two-three orders of magnitude tighter than typical cold-atom scattering
length measurements (typically ~10 a_B).** Assumes σ_freq ~ 0.1 Hz mode
spectroscopy resolution (achievable with multi-second integration).
Script `scripts/fisher_sprint4_aS_basis_transform.jl` runs the transform
in <1s once Item A Fisher eigvals/eigvecs are supplied.

Jacobian recovers Casimir λ_S weights on c_1 column:
`{-42, -39, -32, -21, -6, 13, 36}` — physical consistency check.

This is the **experimentally actionable headline number** for next
session's lab handoff.

### Phase 1 ② loss model — calibrated (K_3 ≈ 50 dimensionless)

First sweep with K_3 ∈ [0, 0.1] saw 0% loss because |ψ|² is normalised
to 1 (not N), so peak density ~0.06 instead of the ~5 in lab units.
Pushing to K_3 ∈ [0, 200] dimensionless gives:

| K_3 | loss % at T=5 ω_ref⁻¹ |
|---|---|
| 0 | 0.0 |
| 1 | 0.1 |
| 10 | 1.3 |
| **50** | **6.3** ← matches Matsui-scaled target |
| 200 | 21.1 |

K_3 ≈ 50 reproduces Matsui's 40% over 40 ms scaling. m-dependent profile
encoding (`K3_per_m_cubic` with stretched immune, cascade products
enhanced) is the remaining piece — magnitudes are now calibrated.

### Matsui ring prediction test (T=14.5 ms, 16³): all 3 scenarios = 2 rings

Quick check at T_evolve = 14.5 ms (vs Matsui's 40 ms) on 16×16×12 grid
across c_1/c_0 ∈ {0, 1/36, 1/18}: all three scenarios returned ring
count = 2 in the m=−4 radial profile. The 2↔3 bifurcation that Matsui
saw at 40 ms needs (a) full T=40 ms, (b) finer radial grid to resolve
a third ring, (c) m-dependent K_3 loss to reshape m=−4 distribution.

Dynamics runs cleanly (~10 min per scenario on 16³ T=14.5 ms). Next
session should target T=28 ω_ref⁻¹ on at least 24³ grid with the
calibrated K_3 ≈ 50 above. Estimated compute: 24³ × 28/14.5 ≈ 5× the
present cost ≈ 50 min per scenario.

**This is not a refutation of Item A**; rather, it bounds the
dynamics-fidelity budget needed for direct ring-count comparison.

### Joint Fisher (polar + stretched, 52 obs) result + magnetic-jitter reality check (2026-06-02)

Joint Fisher run gave eigenvalues `[900, 5710, 16830, 30180, 3.4e8]`
with prior-aware rank 5/5 and per-axis σ_post: c_1 = 5.4e-5, c_2 = 5.8e-3,
c_6 = 7.7e-3, c_4 = 1.3e-2, c_0 = 3.3e-2. The c_1 figure beats Item A
polar alone (1.36e-4) by 2.5×; the tightening comes from stretched.

**Important caveat**: stretched Bogoliubov modes have dω/dB up to
195 Hz/nT (sprint5_bogoliubov_dB_sensitivity.jl). At σ_B = 1 nT
residual, the effective σ_freq for stretched modes is 50-200 Hz, NOT
0.1 Hz. With realistic σ_y, the stretched modes are noise-saturated
and contribute nothing to the joint Fisher.

**Realistic joint Fisher ≈ polar Fisher alone** (since stretched modes
are effectively dropped). Headline σ(a_S) ≈ 0.05 a_B uses polar config
ONLY; the joint tightening reported by the naive joint script is an
artefact of the σ_y = 1e-3 assumption applied uniformly across all
modes. A "realistic-σ joint Fisher" would re-weight stretched modes
with their per-mode dω/dB; expected outcome ≈ polar Fisher with at
most marginal stretched contribution from B-insensitive Δm=0 modes
(if any exist around stretched, none were found in the dB sweep).

For the lab handoff: **single-config polar Bogoliubov spectroscopy is
the right protocol; the joint Fisher number reported elsewhere should
be ignored or rederived with realistic σ_y**.

### Phase 1 ② loss model — infrastructure present, calibration pending

The codebase has `LossParams.K3_per_m_cubic::Vector{Float64}` ready
(`src/foundation/types/ddi_loss.jl`). Phase 1 of the original SBI
roadmap turned out to be a calibration exercise, not new
implementation. `scripts/sprint4_phase1_loss_demo.jl` demonstrates the
API-level path (3 configs: no loss, uniform K_3, m-dependent K_3) but
the K_3 magnitudes I picked (0.003-0.005 dimensionless) give 0% loss
at T=0.5 ω_ref⁻¹ — Matsui's 40% over 40 ms (T=28 ω_ref⁻¹) implies
~0.7% over my T=0.5, below measurement precision.

**Action for next session**: tune K_3 against Matsui's measured loss
profile (40% at 40 ms, m-resolved if their imaging allows). The
infrastructure is in place; the values are an inverse-problem of
their own, separate from c determination.

### `identifiable_directions` now supports prior-aware classification

After the relative-cutoff trap appeared in items 4 v0 and A as
"rank=1/3 verdicts" that contradicted the absolute Fisher precision,
patched `src/analysis/fisher.jl::identifiable_directions` to accept an
optional `cutoff_absolute::Real` argument. Set to `1/σ_prior²` for
physics applications. With it active, classification fires on either
relative-OR-absolute cutoff (default 0.0 = backward-compatible). Tests
in `test/analysis/test_fisher.jl` exercise both paths (29/29 pass).
**All future Fisher analyses in this project should pass
`cutoff_absolute=PRIOR_PRECISION` to avoid the trap.**

### What SBI is actually for (re-scoped)

After Item A, SBI's remaining role is narrowed to:
- **c_1 sign discrimination via the m=−4 ring-count BIFURCATION** (2↔3
  rings). This is a discrete topological observable whose c_1
  dependence is non-analytic across the bifurcation; linear Fisher
  doesn't apply. Whether SBI is strictly needed depends on whether
  the c_1 *value* from Item A's σ=1.4e-4 already determines the sign
  unambiguously — likely yes, given a c_1 of order O(few) and σ=1.4e-4.
  In that case **SBI is not needed for c-determination at all**.
- **Spontaneous symmetry breaking statistics + vortex nucleation** —
  these are ④ / ⑥ science questions, the genuine domain of
  TWA / TDHFB / SGPE (fluctuation-driven physics). SBI on long-T data
  would feed the observable side of those analyses, not the c side.

### Levers, in priority order (anko correction 2026-06-01: A → SBI, B dropped)

| Item | Lever | Status | Adds |
|---|---|---|---|
| 1 v2 | static polar GS Fisher | DONE | c_0 ⊥ g_{2F} → cumulative 2/5 (c_0 + c_1) |
| 4 v0 | dynamic cascade + spatial moments (Matsui regime) | DONE | **null filled**: c_2/c_4/c_6 → physically coupled (eigvals 1e-5 to 1e-3, post-prior σ thin but finite). SBI commitment **justified** |
| **A = 1'** | **Bogoliubov spin-mode spectrum** around polar/stretched GS | **NEXT (linear, cheap)** | **tensor c_2/c_4/c_6 individually separable** via Δm-branch frequency dependence on spin-dep g |
| ~~B~~ | ~~full radial profile linear Fisher~~ | **DROPPED** | 2↔3 ring is a bifurcation; linear Fisher breaks at the discontinuity. Real answer = SBI |
| SBI | non-linear SBI (SNPE/SNRE) on long-T cascade, radial profile feature vector + NN embedding | After A | c_1 sign through the bifurcation; remaining residuals A leaves |
| 2 | microwave Feshbach | CONTINGENT (lab capability) | direct a_S response |

**Why A before B/SBI:** Bogoliubov spin-modes (magnons) around either polar or
stretched GS have frequencies ω_n = ω_n(c_0, c_1, c_2, c_4, c_6) where the
spin-dependent channels enter through the spin-rotation generator of each
mode. Different Δm branches carry *different* channel weights, so a
multi-branch frequency observable is naturally rich enough to break the
tensor null. The codebase already exposes a bogoliubov analyzer
(`_analyze_bogoliubov`); a Fisher driver on top of it is a small wrapper.
Experimentally, collective-mode spectroscopy is a routine technique.

**Caveat:** avoid mode-softening points where ω → 0 (non-analytic, Fisher
linearization breaks). Choose nominal c well inside a single phase region.

**Why B is dropped:** Matsui's c_1 sign appears as a *bifurcation* in m=−4
ring count (2 ↔ 3) — this is a topological transition, c_1 enters
non-analytically as the discontinuity location parameter. Local linear
Fisher on radial profile across the bifurcation diverges or vanishes. The
*correct* analysis there is the SBI itself, where the discrete observable
is naturally encoded and the bifurcation is captured by the
posterior multi-modality. B as a separate linear gate would just defer
the SBI without adding information.

(Subsumed: former item 3 interferometric phase ⊂ item 4 spatial / item 1'
Bogoliubov.)

### Item 4 v0 design rules (anko corrections)

1. **Spatial observables**: ⟨ρ⟩_m, ⟨ρ²⟩_m on cascade components m=−F+1,
   m=−F+2. NOT scalar populations alone.
2. **Realistic depolarisation**: T pushed to ~20-30% (Matsui regime),
   not 1.76% linear regime. At linear regime, ∂(ring)/∂c_1 ∝
   depolarisation fraction → c_1 structurally invisible.
3. **Local Fisher caveat**: at tens-of-percent depolarisation, the
   FD perturbation around nominal is still small (delta_frac=1e-3 ⇒
   0.1% c shift ≪ depolarisation), so Fisher is mathematically valid,
   but interpretation is "does c_1 lift, qualitatively" — not a
   precision quantification. Treat as **heuristic gate** for moving
   to non-linear SBI proper, not as a measurement.
4. **GP + MDDI + secular_ddi=false** (same as item 0 v2).

### Item 4 v0 result, correctly framed (anko correction 2026-06-01)

Result: depolarisation 14.6%, Fisher eigenvalues
`[1.09e-5, 1.13e-3, 4.06e-3, 2.95e-2, 884]`. The script verdict printed
"measurable rank = 1 / 5" via λ_4/λ_5 < 1e-4 cutoff. **That verdict is
misleading and would self-sabotage SBI commitment if taken at face value.**

The correct reading:

(a) **Full-rank Fisher, anisotropic.** Compare to the same Fisher in
    the linear regime (Sprint 4 v2 with scalar populations at T=0.5):
    4 null eigenvalues were `1e-9 … 1e-17` — *structural zeros at
    machine precision* corresponding to c_2/c_4/c_6 directions that
    do not couple at first-order cascade. Item 4 v0 lifted those same
    directions to `1e-5 … 1e-3` — a qualitative transition from
    *structurally invisible* to *physically coupled*. Third-order
    cascade reaches all even-S channels and the spatial moments
    detect the channel-specific radial structure. **This is the
    primary justification for SBI investment.**

(b) **The "rank=1" verdict is the relative-cutoff artifact of double
    counting with the a_12 prior.** λ_5=884 is the g_{2F} direction
    which is already pinned by a_12 prior; dividing the other
    eigenvalues by 884 measures "info beyond what the prior gives"
    against a redundant baseline. The MEAS eigenvector
    `(−0.030, −1.000, −0.006, −0.004, −0.002)` is only 1.6° from
    pure ∇g_{2F}, but the orthogonal subspace eigenvalues are
    *physically non-zero*, not zero — meaning the response is *not*
    pure-g_{2F}-dependent.

(c) **Correct accounting: condition out g_{2F} with the a_12 prior
    first, then evaluate the residual 4-D subspace against the
    *naturalness* prior precision** (not against λ_5). σ_post on c_0
    in the residual subspace ≈ 5.8 (loose but non-trivial info beyond
    naturalness); tensor c_2/c_4/c_6 are thinner but explicitly
    non-zero.

(d) **What the spatial moments capture vs miss.** Continuous moments
    ⟨ρ⟩, ⟨ρ²⟩ engage c-dependent ring *amplitude/spread* (signal
    40× the population signal), but smear the m=−4 *ring count*
    topological invariant (2 vs 3 rings) that Matsui used for c_1
    sign. The 2↔3 ring transition is a **bifurcation** — c_1 is
    non-analytic there, so any local linear Fisher breaks down at
    the bifurcation regardless of observable choice. That c_1-sign
    discrimination is the genuine non-linear-SBI domain.

The theorem rules out adding new c information via observable choice
alone inside the stretched + linear regime. There are only two real
levers, plus one lab-contingent and one long-budget item.

**Lever A — Item 1: non-stretched prep (m=0 polar) + linear Fisher**
(this session)

m=0 polar pair has M=0 → reaches **all** even-S channels including
S=0 (singlet a_0, unreachable from stretched M=−2F). c_1, c_2, c_4,
c_6 enter at first order; rank > 1 is physically allowed.

Feasibility caveat: polar is unstable to symmetric spin-mixing
m=0 + m=0 → m=+1 + m=−1 at rate ~ c_1·n in the weak-Bz EdH regime.
Script `scripts/fisher_sprint4_item1_polar_prep.jl` reports
f[m=0](T) as a survival diagnostic alongside the Fisher numbers, so
the operator can judge whether the protocol is sterile (rapid
collapse), marginal, in linear-departure regime, or dormant (need
longer T). The Fisher gives the information *ceiling* assuming the
state survives; if it doesn't, the protocol is sterile.

**Lever B — Item 4 (= former items 1-cascade + 2-spatial merged):
nonlinear SBI on long-T cascade**
(weeks, separate compute budget)

Matsui's c_1 sign discrimination via m=−4 ring count (2 vs 3 rings)
operates at second-order cascade where m=−5 atoms interact with
m=−6 atoms via c_1 spin-mixing on the non-stretched pair. Outside
linear Fisher. Recovery requires SNPE/SNRE on long-T cascade dynamics
with spatial/ring observables — this is the only path to read the
c_1 sign from stretched-prep EdH itself.

**Contingent — Item 2: microwave-Feshbach shifted effective c**
(deferred pending lab capability)

Li-Saito 2019 present microwave-induced Feshbach as a possibility,
not as demonstrated routine. Probes a_S response curve directly if
available. Defer until confirmed available in the lab.

**Subsumed — former Item 3 (interferometric continuous-phase fringes)**

In linear regime under stretched prep, phase observables are still
linear functionals of ψ and inherit the rank-1 collapse: the
cascade-product relative phase is set by the time-integrated energy
gap, which depends on g_{2F} only. Genuine interferometric
information lives either (a) on item 1 prep with non-stretched pair
states, where it adds to the same linear Fisher already captured by
population observables, or (b) inside item 4 where ring-structure
phase is non-linear in cascade order. **Not an independent item**.

**Recommended next step**: run item 1 (current). If verdict is OK or
MARGINAL with rank > 1, scope item 4 budget against the new null
directions item 1 leaves. If verdict is STERILE / DORMANT, item 4
becomes the only lever for c sensitivity beyond a_12.

**Recommended next step**: item 1 first. Cheapest, breaks the most
nulls in the linear regime if feasible, and the feasibility check is
itself a small experiment that scopes item 4 (if polar is unstable in
weak Bz, item 4 also can't sit there long enough to discriminate
rings, so the same answer addresses both).

## Sprint 4 item 0 closure and revised handoff

**Item 0 finding (confirmed, both static and dynamic linear Fisher):**
The (ρ,z)-axisymmetric ring-stage at any T in the linear cascade regime,
with any moments-of-populations summary, returns rank 1 = g_{2F} = the
a_12 prior. **No NEW c information from item 0**.

Revised Sprint 4 order:
1. **Item 1**: non-stretched prep (m=0 polar) — different channel projection
   at t=0, cascade products carry c_2 dependence
2. **Item 2**: microwave Feshbach shifted effective c — probes the
   off-resonant a_S response curve
3. **Item 3**: interferometric continuous-phase fringes — extracts
   coherences sensitive to c through evolution-phase patterns
4. **(Beyond linear Fisher / full SBI)**: SNPE/SNRE on long-T cascade
   dynamics where second-order m=−5/m=−6 mixed-pair interactions resolve
   c_1 sign per Matsui's ring-count result

The decision-tree pivot from Sprint-3-only to "items 1+2+3 in parallel,
plus full SBI for the ring-count regime" is now data-driven.

## What's still validated

Engineering remains validated as before; Sprint 4 v2 also recovered the
F²=36 stretched-pair slope (eigenvector ratio 0.028:1.000 matches
1:36/√(1+36²) ≈ 0.0277:0.9996). Sprint 1+2 utilities + Sprint 3 static
gate + Sprint 4 item 0 dynamic gate together form a coherent baseline
demonstration that the **stretched-cascade subspace is fundamentally
1-dimensional in c-space at linear order**.

## Item 1+ from Sprint 4 handoff stand, but order changes

Re-prioritization for Sprint 4:
1. **Item 0** (new): dynamic EdH Fisher (this note)
2. Item 1 (old): non-stretched (m=0 polar) prep + EdH Fisher
3. Item 2: microwave-Feshbach-shifted effective c Fisher
4. Item 3: interferometric continuous-phase Fisher
5. (② loss model, ⑤ B(r,t) — separate workstreams, can run in parallel)

The decision tree "do we need item 1+?" is now data-driven by item 0
results.

## Engineering remains validated

- `fisher_jacobian` / `fisher_information` / `identifiable_directions` —
  produced internally consistent SVD that recovered the textbook F²=36
  slope to ≪ 1% precision via FD around nominal (this *is* the
  synthetic-truth-recovery check for the Sprint 1+2+3 utility stack)
- 233 new tests across the batch all green
- Sprint 1 (G1+G2+G3+G4) observation operator chain, `memory/gotcha_constraint_helper_c_extra_basis.md`
  c-vs-channel basis warning, Sprint 2 utilities — all stand

## Related memories
- `memory/gotcha_constraint_helper_c_extra_basis.md` — c-basis hybrid + SBI must use {a_S}
- `memory/next_session_priorities_2026_05_25.md` — Step 6 (Eu SBI) absorbed Sprint 4 into pipeline
- `docs/research_notes/validation_ladder_2026-05-22.md` — Level 13 (Eu phase prediction) sits on top of this
