---
turn: 107
subagent: critic
investigation_id: edh-eu151-vortex-vs-matsui-science-2026
stage_advancing_to: Update
verdict_token: INCONCLUSIVE
f1_central_falsifier_result: INCONCLUSIVE
tier_recommendation: 2.5
n_references_cited: 11
errata_count: 3
errata_load_bearing_count: 1
errata_advisory_count: 2
---

# Turn 107 — Critic Audit (edh-eu151-vortex-vs-matsui-science-2026, Update stage; F1 central falsifier re-test against `runs/eu151_edh_K3_long/`)

## 1. Independent context

The T76–T86 closure of `edh-eu151-vortex-vs-matsui-science-2026` rested on F3 (energy-self-consistency) alone; central falsifier F1 (ring-appears-correct-timescale) was tabled as `NOT_APPLICABLE_NO_RING` on the regressed `matsui_edh_baseline_9ca97308` config (no K3, no γ_dr, no noise seed). State.json `falsifiers[F1].tested_at_turn = null, result = null` confirms F1 has never been load-bearing-tested. T107's mandate per `runs/_loop/seed.md` lines 3–29 + `memory/feedback_use_existing_artifacts_first.md`: audit the K3_long artifact independently. I do NOT carry forward the T84 F1 NOT_APPLICABLE verdict — that audit was against a different (regressed) configuration.

## 2. Artifact triage

Files inspected (`runs/eu151_edh_K3_long/`): `config.yaml`, `_live_status.json`, `trajectory.csv` (502 data rows, header + 501 frames), `trajectory.png` (vision-read), `extract_trajectory.jl`. `result.jld2` and `point_001.jld2` exist but cannot be read without julia (per anti-pattern guard). `trajectory.csv` final frame (line 502): `frame=501, t=10.12 ω⁻¹ ≈ 14.67 ms, norm=0.9962, peak_density=1.097e-2, Fz=5.9422, pop_c1=0.9809, pop_c2=8.02e-3, pop_c3=7.84e-3, pop_c4=1.80e-3, ..., pop_c13=8.83e-19`. `_live_status.json` (step=100000, t=9.98, norm=0.99620, populations[13]) corroborates within rounding. PNG title: "Eu151 EdH long hold 32^3 × K_3 long (phase 2 = 10 ω⁻¹ = 14.5 ms) K3 = 1e-41 m^6/s (Dy-like) + γ_dr=0.02 + LHY scalar. Final norm=0.9962, peak n stable around 1.10e-02". Six panels: (a) total norm vs t; (b) peak max(n_tot) vs t (log); (c) Fz vs t; (d/e) per-m populations linear/log; (f) Δpop vs initial m=+F. **No spatial / azimuthal / radial slices in any PNG panel**; `extract_trajectory.jl` lines 22–31 confirm only integrated `times, norms, Fz, component_populations` plus `peak_n` are persisted to CSV.

Cascade timeline (CSV samples):

| t (ω⁻¹) | t (ms) | Fz | pop_c1 (m=+6) | pop_c2 (+5) | pop_c3 (+4) | pop_c4 (+3) | pop_c13 (−6) |
|---|---|---|---|---|---|---|---|
| 0.00 | 0.00 | 6.0000 | 0.99999 | 5.8e-6 | 3.9e-11 | — | 1.8e-33 |
| 1.40 | 2.03 | 5.8791 | 0.8953 | 0.0922 | 0.0113 | 0.0011 | 3.2e-19 |
| 2.00 | 2.90 | 5.7918 | 0.8311 | 0.1380 | 0.0266 | 0.0038 | 2.3e-17 |
| 2.50 | 3.63 | 5.7257 | 0.7891 | 0.1615 | 0.0413 | 0.0069 | 1.9e-16 |
| 3.60 | 5.22 | 5.6323 | 0.7458 | 0.1630 | 0.0794 | 0.0089 | 1.3e-15 |
| 4.20 | 6.09 | 5.6122 | 0.7449 | 0.1452 | 0.0991 | 0.0075 | 6.9e-15 |
| 5.08 | 7.37 | 5.6033 | 0.7615 | 0.1066 | 0.1186 | 0.0108 | 2.2e-13 |
| 6.10 | 8.85 | 5.6125 | 0.7723 | 0.1040 | 0.1023 | 0.0196 | 1.5e-12 |
| 8.10 | 11.75 | 5.7775 | 0.8358 | 0.1339 | 0.0241 | 0.0031 | 3.4e-11 |
| 10.00 | 14.50 | 5.9412 | 0.9799 | 0.0090 | 0.0075 | 0.0019 | 7.6e-10 |
| 10.12 | 14.67 | 5.9422 | 0.9809 | 0.0080 | 0.0078 | 0.0018 | 8.8e-19 |

Substantial m-cascade: 25.4 % of population leaves m=+F between t≈3 ms and t≈9 ms (Fz drops 6.000 → 5.603) with peak transfer to m=+5 (~16 %) and m=+4 (~12 %). Then **the cascade reverses** by t≈11.75 ms: Fz climbs back to 5.94, populations re-concentrate in m=+6. pop_c13 (m=−6) maxes at ~10⁻¹⁰ – not a unit-vector flip. The dynamics is a coherent 6 ms spin-mixing oscillation, not a one-way EdH cascade to m=−F.

## 3. K3_long config crosswalk vs Matsui Case A (Q2)

| Parameter | K3_long config | Matsui Case A (per T71 extraction + memory `edh_matsui_baseline_2026_05_18.md`) | Factor diff | In-band? |
|---|---|---|---|---|
| Atom | Eu-151 (a_s=110 a_B, μ=6.977 μ_B, g_F=1.163) | Eu-151 same | 1× | YES |
| N_atoms | 10,000 | ~30,000 | 3× low | OUT (factor-2 band) |
| ω_ref | 691.15 rad/s = 2π·110 Hz | 2π·100 Hz | 1.10× | YES |
| Trap aspect ω = (1, 1, 1.182) | mildly oblate | "near-isotropic" | minor | YES |
| Grid | 32³, box=20 a_ho | n.r. (experiment) | — | n/a |
| B_initial | 0.01 G = 1.0 μT | 1 μT | 1× | YES |
| B_final | 2.6e-5 G = 2.6 nT | "near-zero" (2.6 nT) | 1× | YES |
| Quench duration | 0.14 ω⁻¹ ≈ 0.20 ms | n.r. precise | — | n/a |
| Hold duration | 10 ω⁻¹ ≈ 14.5 ms | dynamics ≤ τ_EdH^exp × few | — | YES (covers 2.9 τ) |
| c1_ratio | 0.0 (pure contact+DDI; no spin-mixing) | n.r. — Matsui not parameterized this way | — | n/a |
| LHY | scalar (`lhy.kind: scalar`) | not modelled in Matsui | — | n/a |
| K3 | 1e-41 m⁶/s on all 13 channels (Dy164 proxy) | Eu K_3 not measured experimentally | proxy | UNAVOIDABLE PROXY |
| γ_dr (dipolar relaxation) | 0.02 dimless | n.r. (phenomenological) | — | order-of-magnitude reasonable |
| Noise seed | 42, amplitude 1e-6 coherent, k_cut=2.5 | "experimental imperfections" (unspecified) | — | qualitative match |
| Initial state | `m_plus_F` stretched | m=+F stretched | 1× | YES |

**Verdict on config anchoring**: factor-3 N-difference is outside the "within factor-2" band stated in §6 grounding. The factor-1.1 ω-difference is within band. The N-difference matters: contact and DDI mean-field scale with `c_0` and `c_dd · ⟨n⟩`, both proportional to N (with `c_0 + 36 c_1 = 4π (a_s/a_ho) N` per CLAUDE.md §¹⁵¹Eu). At N=10,000 vs 30,000, mean-field interaction energies are 3× lower, expected τ_EdH timescales likely 3× longer, peak density ~3× lower (since R_TF ∝ N^{1/5}, n_peak ∝ N^{2/5}, factor ≈ 1.55 lower). The K3_long is a **scaled-down analog of Matsui Case A, not a 1:1 reproduction**. Crosswalk verdict: `k3_long_config_matches_matsui_case_a_within_factor_2: false` (driven by N=10k vs 30k).

## 4. K3 routing post-fix confirmation (Q4)

`config.yaml` lines 9–13 cite commit `6bfe9d9` (2026-05-13) explicitly: "K3_per_m_si now flows into LossParams.K3_per_m_cubic (quadratic-in-n true 3-body loss), not the legacy linear-in-n L3_per_m field." Memory `gotcha_K3_routing_pre_2026_05_13.md` confirms commit 6bfe9d9 fixed the routing and that quadratic-in-n is the correct kernel shape. Self-citation in the config + memory cross-reference is consistent. The run timestamp (2026-05-13 per seed.md + memory) is on-or-after the fix date. **`k3_routing_post_fix_confirmed: true`** (accepting the config self-claim + memory anchor; no git log read available read-only without Bash).

## 5. τ_EdH^exp independent re-extraction (Q3)

I do NOT have WebFetch in my tool list (Read, Grep, Glob only). Independent extraction from the Matsui PDF is therefore not directly possible in this turn. I rely on the in-codebase prior extraction:

- T71 researcher_deep extraction (per state.json stages_at_turn.Research[71]; memory `edh_matsui_baseline_2026_05_18.md` line 23 + §3.4 of director T79 grounding lines 107 + 122–123): **τ_EdH^exp = 5 ms**, ℓ_paper extracted (specific winding value not reproduced in memory).
- T72 theorist closed-form prediction (memory line 62): predicted τ_DDI ≈ 0.14 ms post-E2-erratum, F1 t_ring band → [1.4, 14] ms.
- State.json F1 falsifier text (line 3216) keeps the τ_EdH^exp = 5 ms anchor.

**Limitation acknowledged**: I cannot, in this turn, independently re-extract τ_EdH^exp from arXiv:2504.17357 without WebFetch. Per §6 brief, this triggers fallback ("document the failure in §5 and recommend INCONCLUSIVE pending paper access at T108"). I record τ_EdH^exp = 5 ms as the inherited extraction with the caveat that I have not independently re-verified it this turn. `tau_edh_exp_extracted_independently_value_ms: null` (inherited from T71 = 5 ms; not re-extracted at T107).

## 6. F1 verdict on K3_long (Q1 + Q5)

Apply state.json F1 verbatim: "measure t_ring where azimuthally-averaged |ψ_{c=c_flip}|² has local minimum at r=0 within ±20 % depth + annulus aspect ratio > 1.5. CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp] = [2.5, 10] ms; INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp = [1, 25] ms; REFUTED if no ring at any t < 10 τ_EdH^exp = 50 ms OR ring in wrong spin component." τ_EdH^exp = 5 ms inherited from T71.

**Five separable findings**:

(F1.a) **Cascade IS present, and substantial.** Between t≈2 ms and t≈9 ms, 22–25 % of population transfers from m=+6 into m=+5 (~16 %) and m=+4 (~12 %); Fz drops 6.000 → 5.603. This refutes the regressed-config T84 verdict `NOT_APPLICABLE_NO_RING` for the K3_long artifact specifically — the K3+γ_dr+noise-seed combination is enough to seed cascade dynamics at the right order-of-magnitude timescale. So K3_long is NOT a re-statement of the regressed config; the F1 question is genuinely open here.

(F1.b) **The cascade reverses.** Fz minimum is 5.603 at t≈7 ms; by t=14.5 ms Fz has recovered to 5.94 and pop_c1 has re-concentrated to 0.98. This is **coherent spin-mixing oscillation**, not the irreversible EdH cascade to m=−F that Matsui's experimental signature implies. The wave does not deposit angular momentum into a stable lower-m configuration on the K3_long simulated timescale.

(F1.c) **pop_c13 (m=−6) never exceeds 10⁻¹⁰.** A literal "c_flip = m=−6" reading of the F1 criterion (unit-vector flip) yields no ring in pop_c13. Interpreting "c_flip" generously as "the first c with substantial population growth from cascade" (c=2 or c=3, m=+5 or m=+4) leaves the question open but unanswered.

(F1.d) **trajectory.csv contains no spatial information.** The columns are `frame, t, norm, peak_density, Fz, pop_c1..pop_c13` (integrated over space per component); `extract_trajectory.jl` lines 22–25 confirm only `dynamics/times`, `dynamics/norms`, `dynamics/Fz`, `dynamics/component_populations` and per-frame `peak_n` are persisted to CSV. The azimuthally-averaged radial profile of |ψ_{c=c_flip}|² needed by F1 lives in `result.jld2 → dynamics/psi_snapshots_streamed/frame_NNNNN` (per the JLD2 keys referenced by the extract script), which is a 4-D ComplexF32 array (nx, ny, nz, nc) NOT extractable read-only without julia.

(F1.e) **trajectory.png shows no spatial slices.** I have viewed all six panels in `trajectory.png` (vision). They are: total norm vs t (panel a); peak max(n_tot) vs t in log scale (panel b — oscillates 9e-3 → 1.4e-2 → recovery, no collapse but no ring signature either); Fz vs t (panel c); per-m populations linear (panel d) and log (panel e); Δpop_m vs initial m=+F (panel f). **None of the six panels shows ψ(x, y, z) or any azimuthally-averaged radial density profile.** F1 cannot be evaluated from the PNG.

**Apply F1 criteria**:

- "CORROBORATE if t_ring ∈ [2.5, 10] ms"  → Requires ring observed. No spatial evidence accessible → cannot CORROBORATE.
- "INCONCLUSIVE if t_ring ∈ [1, 25] ms (criterion partially satisfied)"  → Requires spatial ring observation to land in that band at all. No spatial evidence accessible → cannot land in band.
- "REFUTED if no ring at any t < 50 ms OR ring in wrong spin component"  → Requires affirmative determination of "no ring". From integrated populations alone, ring presence/absence cannot be determined; the cascade is consistent with EITHER a small forming ring in pop_c2/pop_c3 OR uniform spin leakage with no ring at all. Cannot REFUTE on cascade-alone.

Per anti-pattern guard ("Do NOT inflate to CORROBORATE on cascade-alone. Matsui's F1 criterion is a SPATIAL ring with depth > 20% and aspect > 1.5. A 2% cascade integrated over space is consistent with EITHER 'small ring forming' OR 'uniform leakage'. Honesty over closure.") and per §6 ANTI-PATTERN GUARDS ("Do NOT claim a spatial ring exists without spatial evidence. ... If the spatial evidence is unavailable from the readable artifacts, the honest verdict is INCONCLUSIVE."): **F1 = INCONCLUSIVE** by data-gap on spatial structure.

**Additional caveat (F1.b)**: the integrated-population time series shows a coherent oscillation that reverses, which is mildly *adverse* to a stable EdH ring interpretation but does not refute it either (a forming-and-decaying ring is consistent with a coherent return to m=+F if angular momentum stays in the spin sector rather than transferring to orbit). Spatial extraction at the cascade-peak frames (t ∈ [5, 8] ms, frames ~250–400) is the load-bearing follow-up.

## 7. Errata (relative to T76–T86 closure narrative)

**[E5 LOAD-BEARING]** T84 memory `edh_matsui_baseline_2026_05_18.md` line 23 and state.json line 3250 closing_note declare F1 NOT_APPLICABLE_NO_RING for the investigation as a class, supporting Tier-3 closure on F3 alone. **Correction**: that verdict was specific to the `matsui_edh_baseline_9ca97308` config (no K3, no γ_dr, no noise seed). On the K3_long artifact, the cascade is substantial (24 % out of m=+F at peak, t ≈ 7 ms) and the F1 question is **open**, not foreclosed. The Tier-3 closure on F3-alone with F1 listed as "NOT_APPLICABLE_NO_RING ratified" is therefore tier-inflation per seed.md 2026-05-19 — confirmed by independent audit. Effect: investigation remains at Tier ≤ 2.5 until F1 is properly tested (spatial ring extraction from result.jld2).

**[E6 ADVISORY]** Director §1 grounding line 60 lists `edh-matsui T86 (on F3 only — being re-audited)` among "6 Tier-3 closures". This count is currently load-bearing-stale: the re-audit at T107 finds F1 still untested, F3 alone is insufficient for Tier-3 per §F8 (central falsifier gate), and `judge.py auto-clamps to 2.75`. Project Tier-3 count should be cited as "5 closed Tier-3 plus 1 contested" or "5 fully Tier-3 + edh-matsui at Tier 2.5", not "6" without qualification, until F1 resolves.

**[E7 ADVISORY]** §6 brief of T107 director: "Cascade is mild (~2 % out of m=+F)" referring to t_final. This understates the *peak* cascade: at t ≈ 5–7 ms, ~24 % is in m=+5/+4 (verifiable from trajectory.csv frames ~175–250). The cascade reverses by t=14.5 ms back to ~2 % out — so both numbers are correct for their respective times, but the brief used the final-frame value to reason about whether a ring could be detectable, which is misleading. Future critic-audit briefs should cite the peak cascade time as well as the final.

## 8. Verdict + tier recommendation

**F1 central falsifier = INCONCLUSIVE** by spatial-evidence data gap (cascade present at correct timescale [2–9 ms] with ~24 % peak transfer, but azimuthal/radial structure of pop_c_flip lives in `result.jld2` which requires julia to read). The trajectory.csv + trajectory.png + _live_status.json triple is **insufficient evidence to either confirm or refute** a spatial ring under Matsui's depth-and-aspect criteria.

**Tier recommendation**: hold at **tier 2.5**. Do NOT promote to 3.0 (no spatial ring evidence yet). Do NOT demote to 2.0 (no refutation: the K3_long cascade is order-of-magnitude consistent with EdH at τ_EdH^exp ≈ 5 ms; this is not a clean REFUTED). The previous Tier-3 closure (T86 line 3250 closing_note) over-promoted on F3 alone and that residual inflation should be carried as a contested-Tier-3 footnote until F1 is properly resolved by spatial extraction.

## 9. Routing recommendation for T108

**Highest-leverage single move**: T108 implementer_julia_cpu_light dispatch with directive "extract azimuthally-averaged |ψ_c(r)|² radial profiles from `runs/eu151_edh_K3_long/result.jld2` at frames near the cascade peak (t ∈ [3, 9] ms, i.e. frames ~150–400) for each c ∈ {2, 3, 4} (m=+5/+4/+3 — the populated cascade products); plus c=1 (m=+6, background); plus c=13 (m=−6, unit-flip target). Compute (a) r=0 density depth relative to off-axis maximum, (b) annulus aspect ratio (outer-radius / inner-radius of FWHM ring), (c) time-of-formation t_ring if any of (a), (b) cross threshold (>20 % depth, >1.5 aspect) at any frame. Persist results to a new CSV `spatial_profiles.csv` columns: frame, t, c, depth_pct, aspect, ring_present. Approx cost ~1.5–2 M effective; ~10 min CPU wall (read JLD2 + 13 × 250 azimuthal-averages, no propagation). NO new simulation."

**Alternative T108**: theorist refinement — sharpen F1 detection algorithm to explicitly handle the partial-cascade case (where c_flip is ambiguous between m=−6 unit-flip and m=+5/+4 partial-flip; Matsui's experimental signature interpretation in the paper should be the anchor).

**NOT recommended**: new EdH simulation at N=30,000 (Matsui Case A 1:1) — would address the N-factor-3 mismatch (§3) but seed.md forbids new sims this round, and the cheaper move is to first extract spatial structure from the existing artifact. After T108 spatial extraction, if and only if no ring is found AND the analysis is theoretically sound, then propose a Matsui-N=30k follow-up.

**If T108 spatial extraction finds a ring** with depth > 20 % and aspect > 1.5 at t ∈ [2.5, 10] ms → T109 critic Update CORROBORATE → T110 Document tier 2.5 → 3.0. Project Tier-3 count moves from "5 + 1 contested" to "6 fully Tier-3".

**If T108 spatial extraction finds no ring at any frame** → T109 critic Update REFUTED for the K3_long parameter set specifically → T110 Document REFUTED-CLEAN (tier 2.5 → 2.0) OR theorist branching to either (a) Matsui-N=30k follow-up or (b) re-interpret Matsui's experimental ring criterion at N=10k scaled parameters.

## 10. Metrics block (FORM-A + FORM-B inputs for judge.py §F8)

```json
{
  "experiment_kind": "text_only_critic_audit",
  "investigation_kind": "physics",
  "investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
  "stage_advancing_to": "Update",
  "flow_template": "verify-claim",
  "verdict_token": "INCONCLUSIVE",
  "f1_central_falsifier_result": "INCONCLUSIVE",
  "tier_recommendation": 2.5,
  "n_references_cited": 11,
  "errata_count": 3,
  "errata_load_bearing_count": 1,
  "errata_advisory_count": 2,
  "k3_long_config_matches_matsui_case_a_within_factor_2": false,
  "k3_routing_post_fix_confirmed": true,
  "tau_edh_exp_extracted_independently_value_ms": null,
  "cascade_fraction_at_t_final": 0.0191,
  "cascade_fraction_at_t_peak": 0.2542,
  "t_peak_cascade_ms": 7.37,
  "fz_min": 5.6033,
  "fz_min_t_ms": 7.37,
  "pop_c13_max": 1.0e-10,
  "spatial_ring_observed_via_artifact": null,
  "trajectory_csv_read": true,
  "trajectory_png_read": true,
  "config_yaml_read": true,
  "_live_status_json_read": true,
  "matsui_paper_fetched": false,
  "src_edited": false,
  "julia_executed": false,
  "manuscript_edited": false,
  "new_simulations_proposed": false
}
```

Note on `cascade_fraction_at_t_final`: §6 contract pre-fills this at 0.0192; CSV-final read at row 502 (t=10.12 ω⁻¹) gives `1 − pop_c1 = 1 − 0.9809 = 0.0191`. Equivalent within rounding. The `cascade_fraction_at_t_peak` (0.254 at t≈7.37 ms) is the load-bearing number for F1 reasoning.

Note on `matsui_paper_fetched: false`: critic agent has no WebFetch in its tool list (Read, Grep, Glob only). Relied on the T71 researcher_deep extraction (τ_EdH^exp = 5 ms) cached in state.json + memory. Per "REPORTING DISCIPLINE — If the Matsui paper WebFetch fails after 2 retries, document the failure in §5 and recommend INCONCLUSIVE pending paper access at T108", this contributes to the INCONCLUSIVE verdict; tau_EdH inheritance does not flip the verdict from CORROBORATE to INCONCLUSIVE on its own (the spatial-evidence gap is the dominant driver), but it does contribute one independent reason to defer Tier-3 promotion to T108.

---

**Files inspected** (absolute paths, for orchestrator audit):

- `/home/suzume/workspace/BEC-simulation/runs/_loop/seed.md` (lines 1–35)
- `/home/suzume/workspace/BEC-simulation/runs/_loop/director/turn_107.md` (full)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/config.yaml` (77 lines, full)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.csv` (sampled rows 1–101, 120–134, 175–184, 200–209, 250–259, 300–309, 400–409, 490–502; total 502 rows confirmed via Grep count)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/trajectory.png` (vision)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/_live_status.json` (full)
- `/home/suzume/workspace/BEC-simulation/runs/eu151_edh_K3_long/extract_trajectory.jl` (full; confirms only integrated quantities + per-frame peak_n persisted to CSV)
- `/home/suzume/workspace/BEC-simulation/runs/_loop/state.json` (lines 2585–2620 + 3178–3262 + grep results for F1, τ_EdH, edh-eu151-matsui)
- `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/edh_matsui_baseline_2026_05_18.md` (full)
- `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/feedback_use_existing_artifacts_first.md` (full)
- `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/gotcha_K3_routing_pre_2026_05_13.md` (full)

VERDICT: INCONCLUSIVE
