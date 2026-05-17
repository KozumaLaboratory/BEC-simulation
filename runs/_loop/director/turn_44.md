---
turn: 44
subagent: director
investigation_id: yan-li-saito-2026-reproduction
stage_advancing_from: Update
stage_advancing_to: Hypothesize
topic_tags: [yan-li-saito-2026, r2-fl-vortex-retry, seed-topology-confounder, c1-zero-spin-freeze, joint-falsifier-design, m-populations-discriminator, jld2-k-pad-restart, critic-R2-routing]
paper_section: null
depends_on: [43, 42, 41, 40, 37, "runs/_loop/director/turn_43.md", "runs/_loop/judge/turn_43_critic_audit.md", "runs/_loop/judge/turn_43.json", "runs/_loop/sim/turn_43.md", "runs/_loop/theorist/turn_43.md", "runs/_loop/judge/turn_42_critic_audit.md", "runs/_loop/sim/turn_40.md", "runs/yan_li_saito_f1_grid_refinement/results_P0_pre.jld2", "runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2", "memory:yan_li_saito_2026_barnett_paper"]
produces: "Theorist Hypothesize+Design for T44 R2 fl_vortex retry: formal joint falsification criterion (n_max + m_populations + L_z), YAML deltas patched onto runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml swapping init to from_jld2 fl_vortex source, interpolate_psi_for_restart.jl 64^3→96^3 k-pad spec, observable manifest with Lz + m-population breakdown REQUIRED (no T20-class data gap), expected-outcome decision tree (R2_a / R2_b / R2_c per critic §E), cost budget."
---

# Turn 44 — Director Report

## 1. Investigation state snapshot

- **Active investigation**: `yan-li-saito-2026-reproduction` (priority 1, tier_current 0.8 → 0.75 per T43 critic §F). Continuing the T37→T43 cascade.
- **Stage transition**: **Update → Hypothesize** per §F1 verify-claim. T43 critic Update produced VERDICT: PASS with §C CONFOUNDER-CONFIRMED + §E R2 (fl_vortex retry) routing. REFUTED-with-confounder ≠ refute-of-parent-hypothesis; per §B3 mapping ("REFUTED scientific → jump to Update") followed by Update PASS → re-enter the loop at Hypothesize to formalize the next-iteration design with the confounder addressed.
- **Tier**: 0.8 → 0.75 (per critic recommendation; reflects that the easy win at spherical-seed-dx=0.125 did not land, but parent grid+topology joint hypothesis is alive).
- **Falsifiers tested/refuted**:
  - `f1-direct-reproduction` T37 FALSIFIED.
  - T40 5-pt seed-basin REFUTED (b) density-basin + (a2) topology-axis (at coarse grid).
  - T41 Research closed (c) paper-data gap.
  - T42 critic CORROBORATEd grid-resolution + closed DDI bit-equal.
  - T43 Design committed Form (B) sharp dx_crit=0.20 with spherical seed.
  - T43 Execute measured n_max=2.00 D₀ at dx=0.125 → numerically REFUTES Form (B) with spherical seed.
  - T43 critic Update: REFUTE is CONFOUNDED by c1=0 + uniform-m=+1 seed (DDI off-diagonal mixing rate 2.4e-5/t_ho is too slow to reach paper's required m=0.5/0.5 mix in any finite budget); cannot uniquely distinguish "Form B wrong" from "Form B right but seed blocks basin". New falsifier `dx-refinement-fl-vortex-seed` to be spawned by T44 theorist.
- **Other in-flight investigations**:
  - `barnett-mechanism-2026-05-16`: closed Tier 3.0.
  - `klaus-magnetostir-bch-leak-2026-05-13` (priority 3, blocked on julia P3 validation): could unblock but yan-li-saito priority 1 cascade still mid-flight.
  - `fullbdg-f6-polar-3000x` (priority 99, dormant): contained.
  - `meta-critic-placement-2026-05-17` (priority 50, kind=meta, Observe): T43 critic explicitly noted new evidence ("judge.py strict 1e-8 norm gate fires spuriously on F32 ITP — recommend workload-aware effective tolerance"). This is a real meta data-point. §B2 interleaving rule: don't pile multiple meta turns; let this cascade complete first.
  - `meta-internal-b-unification-2026-05-18` (priority 5): CLOSED.

## 2. Recent-turn audit (last 3 turns OF THIS INVESTIGATION)

| Turn | Stage | Verdict | What happened |
|---|---|---|---|
| T42 | Update (critic) | CRITIC_PASS / CORROBORATE-grid + CLOSED-DDI-bit-equal | Sections A+B CORROBORATEd dx-ratio (30.36×) + droplet-cell-count chain (3.2 vs 97). Tier 0.6 → 0.8. R1 routing to grid-refinement Design. |
| T43-Design (theorist) | Hypothesize+Design | THEORIST_PASS / Form-(B) committed | Form (B) sharp dx_crit=0.20 a_ho, β=3. P0_pre 96³ box=12 F32 σ=0.7 spherical Gaussian m=+1 seed. Sharp discriminator §2.8 (≥3000 → B; ≈800 → C; ≤10 → A). |
| T43-Execute (implementer) | Execute | FAIL_NUMERICAL (operational) / REFUTED (scientific Form-B) | n_max = 2.00 D₀ (in ≤10 → Form A branch). norm_drift=2.2e-7 (F32 floor), m_populations=[0.9994, 1.1e-6, 0.0006]. Implementer §7 explicit REFUTE → routes to T44 Hypothesize alt-causes. |
| T43-Update (critic) | Update | CRITIC PASS / CONFOUNDER-CONFIRMED + R2 routing | §A ACCEPT-as-framework-limitation (norm_drift 3.5e-11/step << F32 floor). §B PARTIAL-CLOSE (dx=0.125 closes spherical-Form-B-at-dx_crit=0.20 but leaves finer dx_crit and topology-corrected seed alive). §C CONFOUNDER-CONFIRMED (LOAD-BEARING: c1=0 + uniform-m=+1 seed cannot reach paper's m=0.5/0.5 flux-closure-torus basin via ITP at DDI-off-diagonal leak rate 2.4e-5/t_ho → need ~21000 t_ho vs executed 25 t_ho). §D Form A volumetric ceiling CONFIRMED quantitative (1.73 vs observed 2.0 D₀). §E R2 (fl_vortex retry at same grid, ~3M + ~2 min GPU). §F tier 0.8 → 0.75. |

**Note on judge INCONCLUSIVE classification at T43-Update**: judge/turn_43.json shows judge re-evaluated against sim/turn_43.md Execute metrics (not critic/turn_43.md) — the critic memo `runs/_loop/judge/turn_43_critic_audit.md` itself contains the full audit with VERDICT: PASS and all required success-criteria metrics in its §5 block. This is a judge-classifier infrastructure quirk (same pattern as T20: substantive content intact inside operational-flag firing), not a science issue. T44 honors the critic's substantive PASS verdict.

## 3. Flow template recall

- **Template**: `verify-claim` (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed).
- **Stage transition rule** per §B3: Last verdict (substantive) = REFUTED-with-confounder (critic identified a load-bearing confounder requiring a re-test). Critic explicitly recommended **R2 (CONFOUNDER-RETRY)** — same grid, swap seed. This is **NOT** "Form B refuted, retract" (would be R1 → Hypothesize alt-causes); it IS "Form B not fairly tested → re-test with confounder eliminated". Per §F1 the correct stage after Update with confounder finding is **Hypothesize** to formalize the next-iteration design that addresses the confounder.
- **Role for stage Hypothesize**: **theorist** (§F1 Hypothesize row: "formal claim + predicted signature + falsifier list").
- **Why this stage now (vs other options)**:
  - **Why not Execute (jump straight to implementer R2 retry)**: critic's R2 spec is high-level ("swap seed for fl_vortex JLD2 interpolated 64³→96³"). The implementer needs a formal falsification criterion. Critic §3 explicitly recommended joint falsifier (n_max ≥ 100 D₀ AND m_populations within (0.4, 0.6) for m=+1 AND L_z within (-0.05, 0.05)). Theorist must formalize this AND verify the JLD2 source spinor structure (T40 P4 saved F=1 3-component or F=6 13-component?) AND verify interpolate_psi_for_restart.jl handles the 64³→96³ k-pad direction (existing T43 helper was 96³→128³ for forward refinement; same k-pad logic but director should NOT assume bidirectional without theorist check). Skipping theorist would repeat the T20 contract-mistake class (lz-missing) because the m_populations + Lz observables are the LOAD-BEARING signals here, not just n_max.
  - **Why not Design (treat critic's R2 as the Hypothesize, jump to Design)**: per §F1 Hypothesize and Design are separate stages; the critic identified an alternative hypothesis (seed-topology required) but did NOT formalize it as a falsifiable prediction. Theorist's job is to commit to: "given fl_vortex seed at dx=0.125, predicted n_max ≥ X D₀ within Y t_ho ITP" with quantitative bounds the implementer can check. This IS hypothesis work, distinct from YAML-deltas-and-stop-rule design work.
  - **Why not Document REFUTED (close investigation)**: parent hypothesis (SpinorBEC.jl can reproduce paper Fig 1c) is still open per critic §F. Closing now would discard the confounder finding's information.
  - **Why not switch to klaus-bch-leak (priority 3)**: yan-li-saito priority 1, mid-cascade with explicit next step.
  - **Why not switch to meta-critic-placement (priority 50)**: §B2 interleaving rule — mid-cascade is wrong moment. The meta is actively accumulating evidence from this cascade (judge gate tuning observation just landed). Let cascade complete to a clean tier-checkpoint (R2 result) before pivoting meta.
  - **Why not run audit-class-scan (AUDIT_DUE advisory flagged 2 turns running)**: legitimate advisory but yan-li-saito tier-3 candidate cascade is at a decision point where every turn matters; defer audit-class-scan to T46+ after R2 result lands. Note this deferral so it doesn't slip indefinitely.
  - **Why not noop**: clear high-leverage actionable directive with quantitative joint falsifier specification.

## 4. Research grounding (§A6)

**External references for this theorist Hypothesize+Design dispatch**:

1. **`runs/_loop/judge/turn_43_critic_audit.md` §C(2) + §3** (the LOAD-BEARING input): critic's quantitative argument that DDI off-diagonal mixing rate ≈ 2.4e-5/t_ho means uniform-m=+1 seed needs ~21000 t_ho to reach m=0.5/0.5 — vs T43 executed 25 t_ho. Theorist commits to whether fl_vortex seed (which starts AT m=0.5/0.5 mixed-population distribution per its construction) bypasses this kinetic bottleneck.

2. **`runs/_loop/sim/turn_40.md` §4 P4 row** (fl_vortex baseline at coarse grid): n_max ≈ 0.62 D₀, f_z=2.7e-16 at ring (topology preserved). Calibration anchor for what "topology-correct seed at coarse grid" looks like. The retry test isolates: same topology-correct seed at fine grid — does density rise?

3. **`runs/yan_li_saito_f1_grid_refinement/point_P0_pre_psi.jld2`** + **`runs/yan_li_saito_f1_torus_gs/`** (existing JLD2 outputs): theorist verifies (a) whether T40 P4 saved the fl_vortex 3-component F=1 spinor or 13-component F=6 (T40 used F=1 per memory line 35), (b) JLD2 layout matches `from_jld2` loader expectations.

4. **`runs/_loop/theorist/turn_43.md` §9.1**: theorist's own prior note about `interpolate_psi_for_restart.jl` helper. Implementer §3 of T43 sim confirmed the helper exists for the forward (96³→128³) direction. T44 theorist must verify whether the same k-pad logic works in the inverse direction (64³→96³) — k-pad is symmetric in principle (truncate or zero-pad), but theorist should confirm no normalization subtlety.

5. **Memory `yan_li_saito_2026_barnett_paper.md` lines 104-110** (locally-FM-globally-zero phase classification): paper's GS m-populations distribute spatially such that ⟨f⟩=0 globally with |f|=1 locally. For a flux-closure-torus, this requires the spin direction to rotate as one traverses the torus → integrated m-populations are roughly equal across the three m-channels (or roughly equal among +1/-1 with m=0 minor). The fl_vortex seed should approximate this initial distribution.

6. **Memory `yan_li_saito_2026_barnett_paper.md` lines 76-82** (anchor numbers): paper torus density ~13000 D₀, ⟨L_z⟩=0 at GS. Both are observable predictions the fl_vortex retry should approach IF the seed-topology hypothesis is correct.

7. **Memory `state_zoo_yaml_integration_wip.md` + CLAUDE.md `state zoo: 22 named builders`**: confirms `init_psi_fl_vortex` or analogous flux-closure builder may exist as a fallback if the T40 P4 JLD2 is incompatible (e.g., wrong F). Theorist surveys.

8. **Memory `barnett_mechanism_2026_05_16` cascade T20**: precedent for the m_populations + L_z observable manifest pattern. T20's lz-missing data-gap class (state.json:2270) was the canonical mistake; T44 theorist must declare Lz REQUIRED in the observable manifest.

9. **director.md §G "Grounded autonomous research (arXiv:2604.12198)" pattern + LATS critic-as-Reflect**: T43 critic's R2 recommendation IS the Reflect+Backprop output; T44 theorist's job is the next Expand step in the search tree (formalize the alternative hypothesis as a testable claim).

10. **`feedback_decision_style.md`**: theorist must commit to ONE quantitative prediction; no hedging across R2_a/R2_b/R2_c branches. The decision tree is for the IMPLEMENTER's stop-rule, not the THEORIST's hypothesis.

11. **`feedback_fix_the_class_not_the_instance.md`**: seed-topology + c1=0 spin-freezing is potentially a CLASS-LEVEL issue for future paper-reproduction attempts (any paper requiring spatially-varying spin texture with c1≈0 framework). Theorist should note this as a candidate `patterns.yaml` entry to surface at next audit-class-scan (T46+).

12. **CLAUDE.md "TwoChannelLHY is polar-only, exact at F=1"** + memory `lhy_refactor_2026_05_12.md`: F=1 paper case has special LHY structure. Theorist verifies our `:scalar` LHY at F=1 is the correct framework choice (paper uses scalar single-component since spin is fully polarized; we use scalar; bit-equal at T42).

13. **`feedback_no_improvised_terminology.md`**: theorist uses standard physics terminology (flux-closure-torus, m-population distribution, ITP basin) — no novel labels.

**Why these inform the dispatch**: refs 1-2 anchor the critic's confounder argument that theorist must quantitatively address; refs 3-4 are the file-level inputs theorist must verify; refs 5-7 are physics-substance inputs for the joint falsifier; ref 8 is the contract-mistake-class precedent; refs 9-13 are methodological discipline.

## 5. Calibrated progress check

- **D-axis this turn advances**: **D1 PRIMARY** (verify existing physics — framework reproducibility of a Tier-3 paper). The R2 retry directly tests whether the parent hypothesis (SpinorBEC.jl can reproduce paper Fig 1c) holds with seed-topology corrected; this is the most direct verification path remaining.
- **D3 SECONDARY**: theorist's c1=0-spin-freezing-class analysis is lit-grounded (paper Fig 1c is explicitly topologically-non-trivial; framework-class understanding of when ITP can/cannot reach a target basin is new theory).
- **D2 NOT advanced this turn**.
- **Tier ladder position**: 0.8 → 0.75 (per T43 critic). Post-T44+T45 R2 result: 0.85 (R2_a fl_vortex succeeds, Form B alive) / 0.6 (R2_b refute robust, retreat to Form A or framework analysis).
- **Manuscript NOT in scope** per `feedback_manuscript_is_not_the_essence`.

## 6. Dispatch decision (declarative contract)

```json
{
  "investigation_id": "yan-li-saito-2026-reproduction",
  "stage_advancing_to": "Hypothesize",
  "subagent_type": "theorist",
  "rationale": "T43 critic Update (judge/turn_43_critic_audit.md) verdict PASS with §C CONFOUNDER-CONFIRMED + §E R2 routing. Critic's load-bearing finding: T43 Execute's REFUTE of Form (B) is confounded by c1=0 + uniform-m=+1 spherical Gaussian seed (DDI off-diagonal mixing rate ~2.4e-5/t_ho means ~21000 t_ho needed to reach paper's required m=0.5/0.5 mixed-population state vs executed 25 t_ho — kinetically unreachable). T44 theorist's job is to (a) formalize the alternative hypothesis 'fl_vortex seed at fine grid nucleates the paper droplet because it starts at m=0.5/0.5 mixed populations bypassing the kinetic bottleneck', (b) commit to a quantitative joint falsifier (n_max ≥ X D₀ AND m_populations within (0.4, 0.6) for m=+1 AND L_z within (-0.05, 0.05) — three independent signals), (c) produce YAML deltas patched onto runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml swapping init to from_jld2 fl_vortex source, (d) specify k-pad interpolate_psi_for_restart.jl invocation for 64^3→96^3 INVERSE direction (existing helper is 96^3→128^3 forward; theorist must verify or extend), (e) confirm JLD2 source spinor format (T40 P4 saved F=1 3-component per memory line 35; need to verify on disk via JLD2 inspect step BEFORE committing the from_jld2 plumbing), (f) state observable manifest with m_populations + L_z + n_max ALL REQUIRED (Lz was the canonical T20 contract-mistake — DO NOT repeat), (g) cost budget. This theorist Hypothesize is high-leverage at ~2.5M effective: it gates a ~3-5M GPU R2 retry that will resolve the tier 0.85 vs 0.6 ambiguity in one turn.",
  "brief": "## ROLE\n\nYou are the theorist subagent. Hypothesize+Design stage for the R2 fl_vortex retry per T43 critic recommendation.\n\nDeliverable: `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_44.md`.\n\n## CONTEXT\n\nT43 Execute measured n_max = 2.00 D₀ at P0_pre (96³ box=12 F32 dx=0.125, σ=0.7 spherical Gaussian m=+1 seed) — far below Form (B) prediction [3000, 13000]. T43 critic Update (judge/turn_43_critic_audit.md) concluded:\n- §C verdict CONFOUNDER-CONFIRMED: c1=0 + uniform-m=+1 seed cannot reach paper's flux-closure-torus basin (m≈0.5/0.5 mixed) via ITP because DDI off-diagonal mixing rate is ~2.4e-5/t_ho — would need ~21000 t_ho vs the 25 t_ho executed.\n- §E routing: R2 (fl_vortex retry at SAME grid).\n- §3.3 critic recommended joint falsifier: PASS iff (n_max ≥ 100 D₀) AND (m_populations within (0.4, 0.6) for m=+1) AND (L_z within (-0.05, 0.05)).\n- §F tier 0.8 → 0.75.\n\nYour job is to formalize this into a Hypothesize+Design memo with quantitative predictions, YAML deltas, falsification criteria, and observable manifest.\n\n## REQUIRED READING\n\n1. `runs/_loop/judge/turn_43_critic_audit.md` end-to-end (this is the critic's full audit; §C and §3 are load-bearing).\n2. `runs/_loop/sim/turn_43.md` §4 metrics + §5 observations + §7 falsification table (the data that was refuted).\n3. `runs/_loop/theorist/turn_43.md` §2 (Form B commit) + §2.5 (the dismissed seed-topology argument that critic refuted) + §9.1 (JLD2 grid resample helper note).\n4. `runs/_loop/sim/turn_40.md` §4 P4 row (fl_vortex coarse-grid result: n_max ≈ 0.62 D₀, f_z=2.7e-16 at ring → topology preserved but density flat at dx=0.4375).\n5. `runs/_loop/judge/turn_42_critic_audit.md` §A (grid-resolution CORROBORATE) and §B (DDI bit-equal closure) — these are CLOSED, do NOT reopen.\n6. Memory `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md` lines 17-25 (paper torus GS) + lines 76-82 (anchor numbers: torus density ~13000 D₀, ⟨L_z⟩=0) + lines 104-110 (locally-FM-globally-zero phase classification).\n7. Inspect `runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml` (the existing T43 config that you will patch) AND if accessible, the T40 P4 JLD2 source path — your Design must point at a specific JLD2 file that EXISTS on disk.\n8. CLAUDE.md DDI conventions (CLOSED per T42 §B — DO NOT reopen).\n9. State.json yan-li-saito-2026-reproduction block (for last_advanced_turn=42 history + falsifiers list).\n10. Memory `state_zoo_yaml_integration_wip.md` — verify whether `init_psi_fl_vortex` exists as a FALLBACK if T40 P4 JLD2 is incompatible.\n\n## HYPOTHESIZE TASKS\n\n### H1. Commit to ONE formal hypothesis statement\n\nFormat: 'At dx = 0.125 a_ho (96³ box=12 F32), ITP from a fl_vortex seed [with m-populations approximately (0.45, 0.10, 0.45) per the flux-closure topology] converges to the paper's torus GS with n_max ≥ X D₀, m_populations within (Y_lo, Y_hi) for m=+1, and ⟨L_z⟩ within (-Z, +Z) per atom, within Y t_ho of ITP evolution.'\n\nYou commit to ONE quantitative X, Y, Z. Suggestions from the critic's bounds:\n- X = 100 D₀ (critic §3.3 lower bound; partial nucleation from interpolated-from-coarse seed is plausible — full saturation to 13000 D₀ requires P1 dx=0.0625).\n- Y_lo = 0.40, Y_hi = 0.60 (critic §3.3; the flux-closure topology m-distribution).\n- Z = 0.05 (critic §3.3).\nYou may adjust based on independent derivation; document your choice.\n\n### H2. Address the DDI-off-diagonal-mixing-rate quantitative chain\n\nCritic §C(2) measured 0.06% leak per 25 t_ho from a uniform-m=+1 seed. For the fl_vortex seed, the initial m-population is already mixed (roughly 0.45/0.10/0.45 per the flux-closure topology). So the question is: does the ITP from this mixed start CONVERGE to the paper's basin (n_max rises to ≥ 100 D₀), or does it RELAX toward delocalized (n_max stays ~ 2 D₀)?\n\nCommit to a prediction with a one-paragraph physics argument. The expected answer is that the kinetic-bottleneck argument no longer applies (starting populations are already in the right ballpark), so if the grid resolution AND seed topology are jointly required AND sufficient, n_max should rise. If n_max stays ~ 2 D₀, the parent hypothesis (grid + topology jointly sufficient) is REFUTED and theorist must propose what's missing (e.g., L_z conservation explicitly required, or a c0/c1 framework issue).\n\n### H3. Note alternative outcomes for implementer stop-rule\n\nProduce a 3-row table:\n- R2_a (n_max ≥ 100 D₀ AND m_pops in band AND |L_z| < 0.05): seed-topology REQUIRED; Form (B) + topology-correct seed = joint hypothesis CORROBORATED at this grid; T45 = P1 retry with same topology-correct seed interpolated to 128³ to test full saturation.\n- R2_b (n_max < 10 D₀ regardless of m_pops/L_z): seed-topology NOT sufficient at this grid; T45 = either R3 (finer dx with topology-correct seed) OR R4 (theorist analytical re-derivation of LP self-bound minimum existence in our framework).\n- R2_c (n_max in [10, 100) D₀ OR m_pops outside band): partial nucleation; T45 = extend ITP steps and re-evaluate.\n\n## DESIGN TASKS\n\n### D1. Identify the T40 P4 JLD2 source on disk\n\nFile-system check (you have Read tools):\n- Glob `runs/yan_li_saito_*/` and `runs/yan_li_saito_2026_*/` to find T40 P4's saved psi.jld2.\n- Check field structure (you can describe what you'd expect; implementer will verify at run-time).\n- Confirm F=1 (3-component) vs F=6 (13-component). Memory line 35 says paper uses F=1; T37/T40 used `Eu151_f1_effective` per T43 sim §1 implementer log so it should be 3-component F=1.\n- If the JLD2 is NOT findable or NOT 3-component F=1, your Design MUST use the fallback path: `state_zoo init_psi_fl_vortex` builder (or analogous) at runtime instead of from_jld2.\n\n### D2. Specify the YAML delta patch\n\nProduce a YAML diff against `runs/yan_li_saito_f1_grid_refinement/config_P0_pre.yaml`. Minimal changes:\n- Replace `init_m_idx: 1` + `init_sigma: 0.7` with `initial_state: from_jld2` + `from_jld2_path: <verified-T40-P4-source>` + `from_jld2_interpolate: true` (or `from_jld2_grid_n: [64, 64, 64]` + `from_jld2_grid_box: [28.0, 28.0, 28.0]` if helper needs source-grid spec).\n- Keep grid (96³), box (12.0), dt (0.004), n_steps (6250), F32, GPU, rotating_basis, all DDI/LHY/c0/c_dd values IDENTICAL to T43 P0_pre. This isolates seed as the ONLY changed variable.\n- Add to observables manifest: `m_populations`, `L_z`, `L_z_per_N`, `F_z_per_N`, `n_max_dimless`, `n_max_D0` (all REQUIRED, no optional).\n\nIf the T40 P4 JLD2 source uses a DIFFERENT box (28.0 vs 12.0), the k-pad helper must also REBOX the spatial range. Document this explicitly — it may require a 2-step (k-pad + spatial-window) operation. If implementer doesn't have this helper, your Design may need to FALL BACK to runtime state_zoo construction at the target grid directly.\n\n### D3. Specify interpolate_psi_for_restart.jl helper requirement\n\nState explicitly:\n- Source: 64³ N=15000 fl_vortex JLD2 (T40 P4, box=28).\n- Target: 96³ N=15000 fl_vortex psi on box=12.\n- Helper steps: (i) FFT-shift to k-space, (ii) crop k-range to fit smaller box (since target box=12 < source box=28, target k_max = π/dx_target = π/0.125 = 25.13 > source k_max = π/0.4375 = 7.18 → padding, NOT cropping, in k-space — careful), (iii) IFFT back to spatial, (iv) re-normalize.\n- If existing helper does 96³→128³ same-box (just k-zero-pad), it does NOT directly apply to this 64³ box=28 → 96³ box=12 case. **State explicitly** whether implementer needs to write a NEW helper or extend existing.\n- Alternative simpler path: since T40 P4 was on box=28 and we want box=12, just sub-sample on the spatial domain — extract the central 12-unit window from the 28-unit source, then resample on the 96³ grid. May be simpler than k-pad and avoids the cross-box subtlety.\n\nIf the cross-box interpolation looks hard, **prefer the state_zoo runtime-construction fallback** for simplicity: just build the fl_vortex on the target 96³ box=12 grid at runtime via state_zoo builder. This is mathematically equivalent (initial state shape, not exact bit-equality to T40 P4) and avoids the k-pad subtlety.\n\n### D4. Observable manifest (LOAD-BEARING — DO NOT REPEAT T20 LZ-MISSING)\n\nProduce a YAML observables block. REQUIRED observables (each must be saved AT FINAL STATE at minimum):\n- `n_max_dimless`, `n_max_D0`\n- `m_populations` (3-element vector for F=1)\n- `F_z_per_N`\n- `L_z_per_N` (CANONICAL T20 MISTAKE — must be present)\n- `norm_drift_max`, `norm_final`\n- `mu_final`, `converged` (n_steps_completed implied)\n- `E_kinetic_per_N`, `E_contact_per_N`, `E_LHY_per_N`, `E_DDI_per_N` (T43 BUG-9 analog: E_DDI was missing; this is a NICE-TO-HAVE; explicitly mark optional if framework-blocked)\n- `wall_time_sec`, `density_profile_radial` (saved to JLD2)\n- `D0_factor_used`, `c0`, `c_dd`, `gamma_lhy`, `eps_dd_phys` (constants from run; for cross-comparison vs T43)\n\nOPTIONAL: `density_profile_axial`, `density_profile_3d_jld2_path`.\n\n### D5. Joint falsifier criterion (machine-evaluable)\n\nUsing the H1 commitment, produce a falsifier YAML block:\n```yaml\nfalsification_criterion:\n  pass_iff:\n    - n_max_D0 >= 100\n    - m_population_m_plus_1 in [0.40, 0.60]\n    - abs(L_z_per_N) <= 0.05\n    - norm_drift_max < 0.01\n  partial_iff:\n    - n_max_D0 in [10, 100)\n  refute_iff:\n    - n_max_D0 < 10\n    - m_population_m_plus_1 > 0.90 (still uniform-FM despite topology-correct start → ITP relaxed AWAY from torus basin)\n```\n\nNote: critic §3.3 used 'within (0.4, 0.6)' for m=+1; I extended to [0.40, 0.60] inclusive. Theorist may tighten if independent derivation suggests narrower band.\n\n### D6. Cost budget\n\n- Estimated GPU wall: ~60-90 s (same as T43 P0_pre).\n- Estimated effective tokens (implementer): ~3-4M.\n- T44 theorist self-budget: ~2.5M effective.\n\n## METRICS BLOCK (required at end of memo, for judge.py to parse)\n\n```json\n{\n  \"hypothesis_commit\": \"<single-sentence formal statement>\",\n  \"hypothesis_n_max_lower_bound_D0\": <float>,\n  \"hypothesis_m_population_band_lo\": <float>,\n  \"hypothesis_m_population_band_hi\": <float>,\n  \"hypothesis_lz_per_n_abs_bound\": <float>,\n  \"hypothesis_itp_t_ho_required\": <float>,\n  \"design_yaml_path\": \"runs/yan_li_saito_f1_grid_refinement/config_P0_pre_fl_vortex.yaml\",\n  \"design_seed_source\": \"from_jld2_path\" | \"state_zoo_fl_vortex_runtime\" | \"unspecified\",\n  \"design_jld2_source_verified\": true | false | \"unverified-implementer-must-check\",\n  \"design_jld2_source_path_or_state_zoo_name\": \"<path or builder name>\",\n  \"design_kpad_helper_extension_needed\": true | false | \"fallback-to-state-zoo\",\n  \"observable_manifest_n_required\": <integer>,\n  \"observable_manifest_includes_Lz\": true,\n  \"observable_manifest_includes_m_populations\": true,\n  \"falsifier_pass_iff_n_clauses\": <integer>,\n  \"falsifier_refute_iff_n_clauses\": <integer>,\n  \"stop_rule_branches\": [\"R2_a\", \"R2_b\", \"R2_c\"],\n  \"cost_budget_gpu_wall_sec_estimate\": <float>,\n  \"cost_budget_implementer_effective_estimate\": <float>,\n  \"theorist_md_on_disk\": true,\n  \"sources_cited\": <integer>\n}\n```\n\n## STYLE\n\n- Use [Established] / [Plausible] / [Speculative] / [Unknown] calibration tags.\n- Per `feedback_no_improvised_terminology`: standard physics vocabulary (flux-closure-torus, m-population distribution, ITP, k-space zero-pad, DDI off-diagonal, etc.).\n- Per `feedback_decision_style`: commit to ONE hypothesis statement in H1; no hedging.\n- Per `feedback_mechanical_vs_investigation_threshold`: do not treat the JLD2 source verification as a sub-investigation — it's a 1-line jldopen() check at implementer turn. Just specify what to check.\n- Budget ~2.5M effective. Text + light file inspection only; no julia, no sympy.\n- Do NOT reopen DDI conventions (T42 §B closed) or grid-resolution hypothesis (T42 §A CORROBORATE — your hypothesis BUILDS ON T42, does not retest it).\n\n## DELIVERABLE\n\nWrite `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_44.md` with sections H1-H3 and D1-D6. End with the metrics JSON block.",
  "observable_manifest": {
    "required": [
      "theorist_md_on_disk",
      "hypothesis_commit",
      "hypothesis_n_max_lower_bound_D0",
      "hypothesis_m_population_band_lo",
      "hypothesis_m_population_band_hi",
      "hypothesis_lz_per_n_abs_bound",
      "design_yaml_path",
      "design_seed_source",
      "design_jld2_source_path_or_state_zoo_name",
      "observable_manifest_includes_Lz",
      "observable_manifest_includes_m_populations",
      "falsifier_pass_iff_n_clauses",
      "cost_budget_gpu_wall_sec_estimate",
      "sources_cited"
    ],
    "optional": [
      "hypothesis_itp_t_ho_required",
      "design_jld2_source_verified",
      "design_kpad_helper_extension_needed",
      "observable_manifest_n_required",
      "falsifier_refute_iff_n_clauses",
      "stop_rule_branches",
      "cost_budget_implementer_effective_estimate"
    ],
    "precondition_check": "test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_43_critic_audit.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_43.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_43.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_40.md && test -f /home/suzume/workspace/BEC-simulation/runs/_loop/judge/turn_42_critic_audit.md && test -f /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/yan_li_saito_2026_barnett_paper.md && test -d /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_grid_refinement && test -f /home/suzume/workspace/BEC-simulation/CLAUDE.md && echo 'precondition OK: T43 critic + T43 sim/theorist + T40 sim + T42 critic + memory + grid_refinement dir + CLAUDE all present'"
  },
  "success_criteria": [
    {
      "id": "theorist_md_on_disk",
      "metric": "theorist_md_on_disk",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Audit trail required; theorist must Write to runs/_loop/theorist/turn_44.md."
    },
    {
      "id": "hypothesis_committed",
      "metric": "hypothesis_commit",
      "operator": "!=",
      "value": "",
      "tolerance": null,
      "rationale": "Theorist must commit to a non-empty single-sentence formal hypothesis statement."
    },
    {
      "id": "hypothesis_n_max_bound_quantitative",
      "metric": "hypothesis_n_max_lower_bound_D0",
      "operator": ">=",
      "value": 10,
      "tolerance": null,
      "rationale": "Pass threshold ≥ 10 D₀ (critic's R2_c lower bound). Theorist may commit higher (e.g., 100 per critic §3.3) but must be at least 10 to discriminate against Form (A) volumetric ceiling (~1.73 D₀)."
    },
    {
      "id": "hypothesis_m_band_present",
      "metric": "hypothesis_m_population_band_lo",
      "operator": ">=",
      "value": 0.20,
      "tolerance": null,
      "rationale": "m_population lower band ≥ 0.20 — i.e., theorist commits to non-trivial mixing requirement (paper's flux-closure-torus needs roughly equal m-populations)."
    },
    {
      "id": "hypothesis_m_band_upper_present",
      "metric": "hypothesis_m_population_band_hi",
      "operator": "<=",
      "value": 0.80,
      "tolerance": null,
      "rationale": "m_population upper band ≤ 0.80 — i.e., not uniform-FM (which would refute the topology-required claim)."
    },
    {
      "id": "lz_bound_present",
      "metric": "hypothesis_lz_per_n_abs_bound",
      "operator": "<=",
      "value": 0.20,
      "tolerance": null,
      "rationale": "L_z bound ≤ 0.20 per atom (paper's GS has ⟨L_z⟩=0; reasonable tolerance for finite-grid ITP)."
    },
    {
      "id": "lz_observable_present",
      "metric": "observable_manifest_includes_Lz",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "Lz observable MUST be in manifest — this is the canonical T20 contract-mistake-class (state.json:2270 lz-buildup-presence INCONCLUSIVE due to missing Lz). T44 must not repeat."
    },
    {
      "id": "m_pop_observable_present",
      "metric": "observable_manifest_includes_m_populations",
      "operator": "==",
      "value": true,
      "tolerance": null,
      "rationale": "m_populations is the LOAD-BEARING signal for whether ITP reached the topology-correct basin (critic §C: paper requires m≈0.5/0.5 mixed)."
    },
    {
      "id": "seed_source_specified",
      "metric": "design_seed_source",
      "operator": "in",
      "value": ["from_jld2_path", "state_zoo_fl_vortex_runtime"],
      "tolerance": null,
      "rationale": "Theorist must specify which seed-construction path (JLD2 load + interpolate OR runtime state_zoo build) — not 'unspecified', so implementer knows what to plumb."
    },
    {
      "id": "falsifier_pass_clauses_minimum",
      "metric": "falsifier_pass_iff_n_clauses",
      "operator": ">=",
      "value": 3,
      "tolerance": null,
      "rationale": "Joint falsifier must have ≥ 3 clauses (n_max + m_populations + L_z minimum per critic §3.3). Single-metric falsifier would be the T43 mistake repeated."
    },
    {
      "id": "cost_budget_realistic",
      "metric": "cost_budget_gpu_wall_sec_estimate",
      "operator": "<=",
      "value": 300,
      "tolerance": null,
      "rationale": "GPU wall estimate ≤ 5 min (T43 P0_pre was 58s; same grid + F32 → same magnitude; ≤ 300s leaves headroom for warm-up + cold-cache penalty)."
    },
    {
      "id": "sources_minimum",
      "metric": "sources_cited",
      "operator": ">=",
      "value": 5,
      "tolerance": null,
      "rationale": "T43 critic + T43 sim + T43 theorist + T40 sim + memory paper minimum (5)."
    }
  ],
  "failure_modes": [
    {
      "if": "theorist_md_on_disk failed",
      "category": "operational",
      "next_action": "T45 = re-dispatch theorist with stricter file-path enforcement. If 2nd attempt fails, escalate to anko."
    },
    {
      "if": "design_jld2_source_verified == false OR design_jld2_source_path_or_state_zoo_name unfindable",
      "category": "data_gap",
      "next_action": "T45 = implementer side-quest to inspect runs/yan_li_saito_*/ JLD2 files OR state_zoo builders to identify a valid fl_vortex source. ~500k effective. Then return to T46 Execute with verified source."
    },
    {
      "if": "design_seed_source == 'state_zoo_fl_vortex_runtime' AND state_zoo builder not located",
      "category": "data_gap",
      "next_action": "T45 = implementer side-quest to scan src/workflow/initialization/state_zoo.jl for `init_psi_fl_vortex` or analogous flux-closure builder; if absent, theorist proposes minimal new builder spec OR director routes to direct phase-imprint via post-load runtime code. ~500k-1M effective."
    },
    {
      "if": "All criteria pass AND design_seed_source specified AND falsifier_pass_iff_n_clauses >= 3",
      "category": "scientific_advance",
      "next_action": "T45 = implementer_julia_gpu Execute the R2 retry per theorist's YAML delta. Budget ~3-5M effective + ~60-300s GPU wall. T46 = judge + critic Update on result. Decision tree per stop_rule_branches: R2_a → P1 retry with topology-correct seed (tier 0.85); R2_b → R4 theorist analytical re-derivation of LP self-bound minimum (tier 0.6); R2_c → extend ITP and re-evaluate."
    },
    {
      "if": "hypothesis_n_max_lower_bound_D0 < 10",
      "category": "scope_violation",
      "next_action": "REJECT. Theorist must commit to a meaningful threshold that discriminates against Form A volumetric ceiling (~1.73 D₀). Lower bound 10 D₀ is the minimum useful discriminator. Re-dispatch with explicit constraint."
    },
    {
      "if": "observable_manifest_includes_Lz != true OR observable_manifest_includes_m_populations != true",
      "category": "scope_violation_class",
      "next_action": "REJECT. Repeats T20 lz-missing class mistake. Re-dispatch with explicit observable manifest requirement. Escalate to anko if 2nd attempt also omits."
    },
    {
      "if": "theorist attempts to reopen DDI prefactor algebra (T42 §B closure) OR grid-resolution narrative (T42 §A closure)",
      "category": "scope_violation",
      "next_action": "REJECT. Both are closed at T42. Theorist's job is the NEXT hypothesis (seed-topology), not re-litigating closed sub-questions."
    },
    {
      "if": "cost > 3.5M effective",
      "category": "operational",
      "next_action": "Acceptable up to per-turn 6M cap; if exceeds 3.5M warn anko; if exceeds 6M escalate."
    }
  ],
  "tolerance_overrides": {
    "cost_cap_effective": 3000000
  },
  "budget": {
    "expected_cost_eff": 2500000,
    "expected_wall_time_sec": 1500,
    "split_by_subtask": {
      "read_t43_critic_sim_theorist_artifacts": 500000,
      "read_t40_sim_t42_critic_memory_paper": 400000,
      "h1_h2_h3_hypothesize_commit": 500000,
      "d1_jld2_source_filesystem_check": 200000,
      "d2_d3_yaml_delta_kpad_helper_spec": 500000,
      "d4_observable_manifest": 200000,
      "d5_d6_falsifier_cost_metrics_block": 200000
    }
  },
  "investigation_update": {
    "if_success_advance_to_stage": "Design",
    "if_success_tier_becomes": 0.75,
    "if_success_falsifier_update": "T44 theorist Hypothesize+Design for R2 fl_vortex retry. Spawns falsifier `dx-refinement-fl-vortex-seed-at-fine-grid` with joint clauses (n_max ≥ 10-100 D₀ AND m_populations within (0.4, 0.6) for m=+1 AND |L_z|/N ≤ 0.05). YAML delta patched onto config_P0_pre.yaml (96³ box=12 F32 dx=0.125 IDENTICAL to T43 except seed). Observable manifest REQUIRES Lz + m_populations (T20 contract-mistake class avoided). Cost ~3-5M + ~60-300s GPU at T45 Execute.",
    "if_refuted_advance_to_stage": "Hypothesize (theorist proposes R4 alternative: analytical LP self-bound minimum check)",
    "if_refuted_tier_becomes": 0.6,
    "next_falsifier_to_test_after": "dx-refinement-fl-vortex-seed-at-fine-grid (T45 Execute). On R2_a (n_max ≥ 100 + m_pops + Lz all pass) → next falsifier spawns: `dx-refinement-fl-vortex-128-cubed-saturation` at P1 128³ box=8 dx=0.0625. On R2_b (refute robust) → falsifier `lp-scalar-droplet-self-bound-minimum-exists` (R4 theorist analytical). Meta-critic-placement (priority 50): T43-Update critic recommended workload-aware F32 effective tolerance for judge.py — file as second meta data point alongside the original 4 contract-level mistakes baseline. AUDIT_DUE patterns.yaml: defer to T46+ after R2 result lands."
  },
  "consumed_seed_md": false
}
```

## 7. Self-review checklist

- [x] Read `runs/_loop/_local/scheduler_44.json` (policy=JULIA_GPU_OK; theorist in allowed_workloads; window 1198029s ≈ 333 hours left; VRAM 12958 MB free / GPU 1% util — comfortable for cheap theorist + potential T45 GPU follow-up).
- [x] Read `runs/_loop/state.json` lines 2200-2444 (investigations.yan-li-saito-2026-reproduction full block: current_stage=Hypothesize per state, tier_current=0.8, last_advanced_turn=42, history note T42 critic CORROBORATE) + history tail (T42 Execute, T43 critic_audit at INCONCLUSIVE per judge classifier infrastructure quirk).
- [x] Read `runs/_loop/seed.md` end-to-end (yan-li-saito priority 1, Tier-3 candidate; cost cap 100M rolling / 6M per-turn).
- [x] Read `runs/_loop/director/turn_43.md` (the prior director dispatch — informs the cascade context, R1/R2/R3/R4 routing space, the precondition-check pattern).
- [x] Read `runs/_loop/judge/turn_43_critic_audit.md` end-to-end (the LOAD-BEARING input — critic's §C CONFOUNDER-CONFIRMED + §E R2 routing + §3 joint-falsifier spec).
- [x] Read `runs/_loop/sim/turn_43.md` §1 (directive) — verified implementer §7 routes to T45 Hypothesize alt-causes (which the critic refined to R2-CONFOUNDER-RETRY at T43-Update).
- [x] Read `runs/_loop/theorist/turn_43.md` §0-§2 (verified the Form B commit + the dismissed seed-topology argument that critic refuted in §2.5).
- [x] Read `runs/_loop/judge/turn_43.json` (verified INCONCLUSIVE classification is judge-infrastructure quirk evaluating sim metrics not critic memo; metrics block at line 84 carries `falsification_result: REFUTED`).
- [x] Read memory `yan_li_saito_2026_barnett_paper.md` lines 1-130 (paper anchor numbers, phase classification, hamiltonian, normalization conventions — all referenced in §4).
- [x] investigation_id 'yan-li-saito-2026-reproduction' valid in state.investigations.
- [x] stage_advancing_to 'Hypothesize' is the next stage per §F1 (Update REFUTED-with-confounder → re-enter at Hypothesize to formalize next-iteration design with confounder addressed).
- [x] subagent_type 'theorist' matches role_per_stage[Hypothesize] in §F1.
- [x] success_criteria are machine-evaluable (judge.py can parse JSON metrics block against operators).
- [x] failure_modes cover the 5-7 most likely failures: file-write fail, jld2-source-missing, state_zoo-fallback-not-found, success-advance, scope-violation-thresholds, observable-manifest-class-violation, DDI/grid-reopening-attempt, cost-cap.
- [x] observable_manifest precondition_check is concrete bash (8 file/dir checks + echo).
- [x] budget 2.5M effective fits within scheduler window (1198029s left; per-turn 6M cap; tolerance_override 3M).
- [x] §A6 research-first citation present (13 references in §4, anchored on critic memo + sim/theorist artifacts + memory + standard methodological feedback).
- [x] §A5 D1 articulated (yan-li-saito Tier-3 candidate verification); manuscript NOT primary (explicit in §5).
- [x] Investigation update field updates current_stage to Hypothesize (success) AND tier_current to 0.75 (per T43 critic §F). On refuted-of-this-Hypothesize → re-Hypothesize for R4 path; tier 0.6.
- [x] Considered switching investigations: klaus-bch-leak (priority 3, lower priority + needs julia P3 specific config); meta-critic-placement (priority 50, interleaving rule defers to post-cascade); audit-class-scan (legitimate but defer one turn to keep cascade momentum).
- [x] Considered alternate routings: skip-to-Execute (rejected — theorist must formalize joint falsifier + verify JLD2 source); skip-to-R4-theorist-analytical (rejected — critic explicitly recommended R2 first because it's the cheapest direct confounder test; R4 is the right move IF R2_b lands). R2 path strictly dominates per critic §E.
