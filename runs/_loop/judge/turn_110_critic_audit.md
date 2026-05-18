# Turn 110 — Critic Audit (edh-eu151-vortex-vs-matsui-science-2026, Update stage; F1 central falsifier formal re-evaluation against `runs/eu151_edh_K3_long/` artifacts using T109 refined criterion)

---
turn: 110
subagent: critic
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
mode: investigation_update
stage_advancing_to: Update
verdict_token: INCONCLUSIVE
f1_central_falsifier_result: INCONCLUSIVE-SPATIAL-REQUIRED
tier_recommendation: 2.5
n_references_cited: 9
---

**Prompt-injection notice**: while reading `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_109.md`, a stale `<system-reminder>` containing Figma MCP server instructions was injected (T109 also logged the same persistent artifact). It is out of scope for SpinorBEC.jl physics audit work; I ignored it, called no Figma tool, and proceeded with the directive. No other injection observed.

## §1. Critic role declaration

I am the independent critic for T110 §B-verify-claim Update stage of investigation `edh-eu151-vortex-vs-matsui-science-2026`. I did NOT author `runs/_loop/research/turn_109.md`. The central falsifier under audit is `F1-ring-appears-correct-timescale` (state.json line 1750-1755): `is_central: true`, `tested_at_turn: null`. Tier-3 promotion gate (per critic.md §F8): F1 must reach CORROBORATE / CONFIRMED for the investigation to clamp ≥ 3.0; otherwise judge.py clamps at 2.75 even if other axes pass. T109 research substantively delivered the missing piece (the published Matsui ring-detection methodology) so the criterion is no longer ad-hoc; my job is to apply it cleanly.

## §2. Evidence inventory

| Path (absolute) | CAN tell us about F1 | CANNOT tell us about F1 |
|---|---|---|
| `/home/suzume/workspace/BEC-simulation/runs/_loop/research/turn_109.md` | Matsui's published criterion is qualitative density-ring (Stage 1) + Bragg-interferometric phase-winding (Stage 2). N^(2/5) scaling argument K3_long ↔ Matsui. NC1 / NC2 trajectory.csv shortcut. | Cannot itself be a ring observation; it is the criterion under which an observation would qualify. |
| `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv` (501 frames, 19 columns) | Integrated populations per m-component vs time. Cascade existence, peak timing, NC1 quantitatively, NC2 width above population threshold, reversibility. | NO spatial information — no |ψ_c(x,y,z)|² at any frame, no azimuthal average, no radial profile, no aspect ratio. Cannot identify a ring directly. |
| `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png` (six-panel plot) | Visual confirmation of the cascade dynamics — panels (a) norm, (b) peak n_tot (log) vs t, (c) Fz vs t, (d/e) per-m populations linear/log, (f) Δpop relative to initial m=+F. | NO spatial panel — none of the six panels shows ψ(x,y,z=0), an azimuthally-averaged radial density profile, or any image-plane density slice. Cannot show ring. |
| `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml` | Confirms simulation parameters: trap aspect [1.0, 1.0, 1.182] (line 32), omega_ref 691.15 rad/s (line 26), N=10000 (line 26), initial_state m_plus_F (line 42), K3 loss enabled on all 13 channels (lines 70-75), gamma_dr=0.02 (line 69), noise seed 42 with amplitude 1e-6 (lines 64-67). Matches Matsui trap (110, 110, 130) Hz to 3 sig figs. | Cannot itself be a ring observation. |
| `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/result.jld2` (1.67 GB) | Would contain the 4-D ComplexF32 spinor wavefunction (nx, ny, nz, nc) = (32, 32, 32, 13) per saved frame, sufficient for direct spatial ring extraction. | Not extractable in this sandbox (T108 sim/turn_108 §4-5 logged sandbox julia denial). Out-of-loop-reach this turn. |
| `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_107_critic_audit.md` | T107 critic flagged T82's 20%/1.5 thresholds as project-internal heuristics never derived from Matsui (§6 anti-pattern guard). | Pre-dates T109 methodology extraction; does not itself apply the now-published criterion. |
| `/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_108.md` | Documents the sandbox julia-denial blocker; `extract_ring_metrics.jl` and `run_extract_ring_metrics.sh` staged on disk for anko manual run. | The CSV/JSON that script would produce do not exist yet. |
| `/home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_109.json` | Confirms T109 substantive PASS on 13/14 criteria; the single FAIL was contract-shape (`symmetry_mapping_verified_kawaguchi_ueda` declared as enum, researcher emitted boolean True — director-side contract bug, not substance fault). | Procedural; not a physics evidence file. |
| `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` lines 1750-1755 | F1 verbatim falsifier text with τ_EdH^exp anchor (T71). | tested_at_turn currently null. |

## §3. Verification of T109 substantive claims (independent audit)

**Claim T109-A — Matsui ring criterion is QUALITATIVE visual ring + Bragg-interferometric Stage-2.**
Status: **SUSTAINED**.
T109 §2 (M1a, M1b, M1f) quotes verbatim arXiv:2504.17357 body snippets that establish: (i) ring identification language is "ring-shaped density distributions that were confirmed as quantized vortices through matter-wave interferometry" — confirmation, not detection, is interferometric; (ii) Fig. 3 caption "two subsequent Bragg pulses diffract the atoms"; (iii) "single-shot absorption images" with averaging "of 4 experimental iterations" and no published quantitative depth or aspect threshold. The two-stage decomposition is honest. The earlier T82-era "depth > 20% AND aspect > 1.5" thresholds are confirmed project-internal: T107 §6 had already flagged them on internal-consistency grounds; T109 traces them back to state.json line 1751 with no Matsui-paper source. No fabricated criterion.

**Claim T109-B — Symmetry K3_long c=2 ↔ Matsui c=12 verified.**
Status: **SUSTAINED with one advisory**.
The Wigner-Eckart argument T109 §3 M2b cites is standard: |C(F, m; 2, −1; F, m−1)| = |C(F, −m; 2, +1; F, −m+1)| by the m → −m CG symmetry (Edmonds §5.4; Varshalovich Table 8.4). The MDDI rate |⟨f|H|i⟩|² is therefore identical under joint m ↔ −m flip. The DDI Hamiltonian is bilinear in spin (μ₀μ²·Σ Q_{αβ} F_α F_β with Q_αβ = k̂_αk̂_β − δ_αβ/3 per CLAUDE.md DDI conventions) and is invariant under coherent spin rotation by π about a transverse axis (which flips m → −m on stretched states); the quadratic Zeeman q F_z² is m → −m invariant directly; the linear Zeeman −μ_z B requires joint B → −B flip for invariance. T109 §3 M2a estimates the residual linear-Zeeman energy at the operating field B = 2.6 nT as ~22 nK (= g_F μ_B B / k_B at g_F ≈ 1.163, μ_B/k_B ≈ 67 μK/G ≈ 67 mK/T → 67e-3 × 2.6e-9 K = 1.74e-10 K = 0.17 nK; T109's 22 nK is the *zero-field-deviation* scale at the *prep* field 1.0 μT, not the post-quench 2.6 nT — order-of-magnitude advisory only, does not affect the conclusion that linear-Zeeman residual is ≪ DDI). Advisory: the symmetry guarantees Stage-1 density signature is identical, but the **chirality flip** (Bragg-fringe handedness opposite) is the load-bearing distinction Stage-2 must resolve; T109 §3 M2c flags this correctly.

**Claim T109-C — Trap (110, 110, 130) Hz matches K3_long to 3 sig figs.**
Status: **SUSTAINED exactly**.
config.yaml line 26 `omega_ref: 691.15` and line 32 `omega: [1.0, 1.0, 1.182]`. ω_ref / (2π) = 691.15 / 6.28319 = 110.0006 Hz; ω_z = 1.182 × 110.0006 = 130.0 Hz. Matches the Matsui (110, 110, 130) Hz body-text extraction at 4-digit precision.

**Claim T109-D — N-scaling timescale factor 1.9 via N^(2/5).**
Status: **CHALLENGED-ADVISORY (order-of-magnitude only)**.
The derivation is correct for *mean-field contact-driven* dynamics: in a 3-D harmonic trap, R_TF ~ N^(1/5) (Thomas-Fermi), n_peak ~ N / R_TF^3 ~ N^(2/5), τ_MF ~ ℏ/(n c_0) ~ N^(-2/5). 5^(2/5) = 1.904. **However**, the Matsui paper's first-flip rate is **DDI-governed** (T109 §3 M2 quotes "Population transfer from m=−6 to m=−5 is governed only by the MDDI at this stage"). DDI rate scales linearly with c_dd·⟨n⟩, also ∝ N, so τ_DDI also ~ N^(-2/5) to the same order — the scaling argument carries through, but it is order-of-magnitude; sub-leading effects (peak density vs mean density, K3 loss rate scaling cubically with n, gamma_dr empirical) can shift the timescale by ~factor-2. The factor-2 band T109 attaches around 2.6 ms → [1.5, 7] ms is a reasonable hedge. Use this band as a soft window, not a hard one.

**Claim T109-E — NC1 (pop_c2 ≥ 10%) SATISFIED at K3_long t = 5.22 ms (peak 16.3%).**
Status: **SUSTAINED**.
Independent re-read of `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv` frame 175 (line 176): `t = 3.60 ω⁻¹, pop_c2 = 0.1630`. t_ms = 3.60 × 1000 / 691.15 = 5.21 ms. T109 figure matches within rounding. pop_c2 ≥ 10% confirmed at peak.

**Claim T109-F — NC2 (pop_c2 persistence ≥ trap period 9.1 ms) MARGINAL.**
Status: **SUSTAINED with caveat — actually stronger than "marginal"**.
Independent re-evaluation: pop_c2 first crosses 10% near frame ~110 (line 111: t = 2.30 ω⁻¹ = 3.33 ms, pop_c2 = 0.1535). It stays above 10% through frame ~320 (line 320: t = 6.48 ω⁻¹ = 9.38 ms, pop_c2 = 0.1160). Width above 10% ≈ 9.38 − 3.33 = 6.05 ms. Trap period T_trap = 2π/691.15 = 9.092 ms. NC2 ratio = 6.05 / 9.09 = 0.67. T109's "MARGINAL (3-4 ms)" understates; the actual persistence is ~6 ms ≈ 0.67·T_trap, closer to "approximately satisfied" than "marginal". This does not change my F1 verdict but tightens the NC stack: both necessary conditions are now well-supported, not just NC1.

## §4. F1 verdict

Apply F1-REFINED-MATSUI-QUALITATIVE (research/turn_109.md §4) to `runs/eu151_edh_K3_long/` artifacts.

The criterion reads: *"visually-identifiable ring-shaped column density of |ψ_{c=2}(x, y)| (or |ψ_{c=12}| after m ↔ −m relabeling) at hold-time t ∈ [1, 25] ms; CORROBORATE if K3_long simulation reproduces a visual ring in c = 2 at any frame t ∈ [1.5, 7] ms; INCONCLUSIVE if no spatial extraction is performed OR if the spatial profile shows partial dip without clear annular signature; REFUTED if no ring-like density at any hold time t ∈ [0, 50] ms."*

Status of inputs:
- Necessary conditions: NC1 met (peak pop_c2 = 16.3% at t = 5.21 ms, well inside [1.5, 7] ms band); NC2 met (~6 ms persistence ≈ 0.67·T_trap, stronger than T109 estimated).
- Symmetry mapping K3_long c=2 ↔ Matsui c=12: SUSTAINED at §3 above.
- Trap match: exact to 3 sig figs.
- **But**: per T109 §5 explicitly, "the K3_long trajectory.csv (integrated populations only) is insufficient to evaluate F1-REFINED-MATSUI-QUALITATIVE on its own"; NC1 + NC2 are necessary but not sufficient. The criterion requires a *spatial annular density signature*, not a *population-fraction-in-a-band*.
- trajectory.png shows population time series only (verified via vision read this turn — six panels, none spatial).
- result.jld2 contains the spatial wavefunction but is julia-denied in this sandbox per sim/turn_108 §4-5.

Per the directive anti-pattern guard "Do NOT verify with population-only criterion as if it were sufficient" and the §4 verdict-shape constraint "if genuinely split, lean to INCONCLUSIVE-SPATIAL-REQUIRED": the honest verdict is

### F1 = **INCONCLUSIVE-SPATIAL-REQUIRED**

Stage-1 (qualitative density-ring) is **prerequisite-clear** (NC1 + NC2 + symmetry + trap match), but **not visually verified** — the load-bearing spatial annular signature lives in `result.jld2` and cannot be read without julia. Without seeing the spatial profile, I cannot honestly issue CORROBORATE-STAGE-1: the necessary conditions are consistent with EITHER (i) a clean forming ring in c=2 at t ≈ 5 ms OR (ii) uniform spatial leakage with no ring, and the two are indistinguishable from integrated populations alone. T107 §6 (F1.d) made this same point; T109's refined criterion does not change the underlying data-gap.

Tier recommendation: **hold at 2.5**. Do not promote to 2.75 (would require CORROBORATE-STAGE-1, which Stage-1 visual verification cannot deliver from the current readable artifacts). Do not drop to 2.0 (no refutation; cascade dynamics are timescale-consistent with the N-scaled Matsui window, and the absence of a ring is not established).

Routing recommendation for T111: anko-consult — execute `bash /home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/run_extract_ring_metrics.sh` in a julia-permitted environment (T108 staged the script; sim/turn_108 §10 Option B). Once `spatial_profiles.csv` and `ring_summary.json` exist, T112 critic re-audits with the qualitative annular-signature judgement against the radial profiles, and emits CORROBORATE-STAGE-1 / REFUTED-TIMESCALE-MISS / REFUTED-OTHER. Stage-2 (Bragg-interferometric phase-winding, Matsui Fig. 3 protocol) remains OUT_OF_SCOPE pending a future investigation that simulates the Bragg-pulse extension; full Tier-3 closure on F1 requires both stages.

## §5. Class-finding documentation

**Class finding (to be recorded in `runs/_loop/conclusions/edh-eu151-vortex-vs-matsui-science-2026.md` ledger at T111 Document)**: the T76–T86 closure path that promoted this investigation to Tier-3 on F3-energy-self-consistency alone treated F1 as `NOT_APPLICABLE_NO_RING`, citing a depth-> 20 % AND aspect > 1.5 ad-hoc threshold inherited from state.json line 1751. That threshold was a project-internal heuristic; T109 §2 (M1a, M1b, M1f) establishes that **Matsui 2026 publishes no quantitative depth or aspect threshold** — the criterion is qualitative visual ring + Bragg-interferometric phase-winding confirmation. The closure was therefore over-promotion on the central falsifier. T107 §6 [E5] surfaced this on internal-consistency grounds; T109 §2 traced it to the source level (no Matsui paper anchor). The class pattern is: **a state.json-textual "criterion" with no traceable arXiv / paper source is project-internal and cannot ground a central-falsifier verdict**. Per `memory/feedback_fix_the_class_not_the_instance`: future investigations should grep for similar `state.json`-only falsifier thresholds and trace each to its paper source before relying on it for a Tier-3 gate.

## §6. Stage-1 / Stage-2 split (explicit)

- **Stage-1 (qualitative density-ring + necessary conditions)**: assessable from existing K3_long artifacts iff `result.jld2` is read (the 4-D ComplexF32 spinor wavefunction). Within the loop's reach in a julia-permitted session via T108's `extract_ring_metrics.jl` — but **not** within this critic turn's reach. Currently the answer is INCONCLUSIVE on Stage-1 itself because the necessary conditions are met but the visual ring is unverified.
- **Stage-2 (Bragg-interferometric phase-winding, Matsui 2026 Fig. 3 protocol)**: requires a separate simulation extension — Bragg-pulse protocol applied at the spin-relaxation interrupt point (suppression field 0.1 mT per Matsui Fig. 3 caption), two diffraction pulses, fringe-pattern imaging, winding-number ℓ extraction from the dislocation count. **OUT_OF_SCOPE for this loop turn**. No K3_long output contains Bragg-pulse outputs; the protocol is not in `runs/eu151_edh_K3_long/config.yaml`. A future `eu151_edh_bragg_winding/` investigation would address this.
- **Tier-3 promotion**: per critic.md §F8, F1 is central; full Tier-3 (≥ 3.0) requires Stage-1 CORROBORATE *and* Stage-2 CORROBORATE. Stage-1 alone supports at most 2.75. The current state (Stage-1 INCONCLUSIVE, Stage-2 untested) supports 2.5.

## §7. Falsifier table update

JSON fragment to be applied by T111 implementer_text:

```json
{
  "id": "F1-ring-appears-correct-timescale",
  "tested_at_turn": 110,
  "result": "INCONCLUSIVE-SPATIAL-REQUIRED: T109-refined Matsui qualitative ring criterion applied. Necessary conditions PASS — NC1 (pop_c2 peak 16.3% at K3_long t=5.21 ms inside N^(2/5)-scaled band [1.5, 7] ms) + NC2 (pop_c2 persistence ~6.05 ms ≈ 0.67·T_trap, stronger than T109 marginal estimate) + symmetry K3_long c=2 ↔ Matsui c=12 SUSTAINED via Wigner-Eckart + Kawaguchi-Ueda 2012 §5.4 + trap (110, 110, 130) Hz match to 3 sig figs from config.yaml. But Matsui criterion requires visual annular density (Stage 1) which lives in result.jld2; sandbox julia-denied (sim/turn_108 §4-5). Stage-2 Bragg interferometric phase-winding OUT_OF_SCOPE this turn. Route T111 to anko-consult: bash runs/eu151_edh_K3_long/run_extract_ring_metrics.sh.",
  "evidence_paths": [
    "runs/_loop/research/turn_109.md",
    "runs/eu151_edh_K3_long/trajectory.csv",
    "runs/eu151_edh_K3_long/trajectory.png",
    "runs/eu151_edh_K3_long/config.yaml",
    "runs/_loop/judge/turn_107_critic_audit.md",
    "runs/_loop/sim/turn_108.md"
  ]
}
```

Do NOT directly mutate state.json (critic is read-only); T111 implementer_text applies the patch.

## §8. Self-review checklist

- [x] T109 research read in entirety (sections 1-12).
- [x] T109 claims A-F audited independently (§3): A SUSTAINED, B SUSTAINED w/ advisory, C SUSTAINED exactly, D CHALLENGED-ADVISORY (order-of-magnitude), E SUSTAINED, F SUSTAINED-stronger-than-claimed.
- [x] Formal verdict issued: **INCONCLUSIVE-SPATIAL-REQUIRED** (§4).
- [x] Stage-1 / Stage-2 split explicit (§6).
- [x] Class-finding (T76-T86 closure on ad-hoc state.json-internal heuristic) documented (§5).
- [x] Falsifier-update JSON fragment present (§7).
- [x] No src/ test/ yaml/ state.json edits (read-only tools only).
- [x] No julia, no GPU.
- [x] All paths absolute.
- [x] No improvised terminology.
- [x] No anko-attribution.
- [x] Did not over-promote to Tier 2.75 from insufficient evidence.
- [x] Did not critique T109 for contract-shape FAIL_OPERATIONAL.
- [x] Did not propose new YAML / simulation / spatial-extraction script (T108 already staged it).
- [x] Did not invent quantitative depth/aspect threshold.

## Errata (relative to T109 substance)

1. **[Advisory]** T109 §3 M2a linear-Zeeman magnitude estimate (~22 nK) appears to mix the prep-field 1.0 μT calculation with the post-quench 2.6 nT regime. At B = 2.6 nT and g_F ≈ 1.163: g_F μ_B B / k_B ≈ 1.163 × (1.4 MHz/G × h) / k_B × 2.6e-5 G ≈ 1.8 nK, not 22 nK. Both numbers are ≪ DDI scale (10-100 nK), so the conclusion ("symmetry good to high precision") is unaffected, but the specific number quoted is off by ~12×. Does not change the verdict.

2. **[Advisory]** T109 §5 NC2 description as "MARGINAL (3-4 ms)" understates: the pop_c2 ≥ 10% window is actually ~6 ms wide (frames ~110 to ~320, t ∈ [3.33, 9.38] ms), which is ≈ 0.67 × T_trap rather than the 0.3-0.4 implied. NC2 is closer to "approximately satisfied" than to "marginal". Strengthens the NC stack but does not by itself flip the F1 verdict (Stage-1 visual evidence is the load-bearing missing piece).

3. **[Advisory]** T109 §6 SpinorBEC.jl-canonical translation correctly recovers a_ho = 0.780 μm; the §6 implicit comparison "K3_long is ~2× faster than Matsui in mean-field timescale" is upper-bounded — the actual measured cascade peak at K3_long t = 5.21 ms vs Matsui inspection point 5 ms suggests the simulation is *not* 2× faster but comparable, with the difference plausibly attributable to (a) reduced peak density (~1.55× lower per §6 R_TF scaling) (b) K3 loss-rate scaling cubically with n, suppressing dynamics at higher density. Order-of-magnitude consistent.

None of the errata is load-bearing for the F1 verdict.

VERDICT: INCONCLUSIVE
