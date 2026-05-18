# Turn 70 — state.json patch spec (deferred from theorist Step 4)

**Purpose**: T70 theorist completed Steps 1 (verify), 2 (memory entry), 3
(theorist report). Step 4 (state.json edits) is deferred to T71 implementer_text
because the theorist agent's tool set does not include the `Edit` tool; the
state.json file is 2556 lines; a full-file Write via the `Write` tool is high-risk
(typo class) and high-cost (~80k+ output tokens) for purely-mechanical edits that
`Edit`-supporting agents handle cleanly.

Director T70 §6.failure_modes explicitly anticipates this case:
> "If Step 4 (state.json) skipped, T71 director writes the state.json edits
> before any other work (1-turn implementer_text)."

This file IS the deferred-step instruction packet for T71. The implementer can
apply each item below as a precise `Edit` call.

## Pre-flight check (T71 implementer)

Verify the survey investigation is still at `Research` stage (no other turn
modified it):

```python3
import json
s = json.load(open("runs/_loop/state.json"))
assert s["investigations"]["tier3-verification-pipeline-survey-2026-05-18"]["current_stage"] == "Research"
assert "edh-eu151-vortex-vs-matsui-science-2026" not in s["investigations"]
assert s["active_investigation_id"] == "tier3-verification-pipeline-survey-2026-05-18"
print("OK_T71_precondition: ready to apply T70 state.json patch")
```

## Patch 1 — Update `active_investigation_id` (line 1976)

```
Edit: runs/_loop/state.json
old_string: "active_investigation_id": "tier3-verification-pipeline-survey-2026-05-18",
new_string: "active_investigation_id": "edh-eu151-vortex-vs-matsui-science-2026",
```

## Patch 2 — Extend `investigations_index` (line 1986 area)

```
Edit: runs/_loop/state.json
old_string:     "tier3-verification-pipeline-survey-2026-05-18"
  ],
new_string:     "tier3-verification-pipeline-survey-2026-05-18",
    "edh-eu151-vortex-vs-matsui-science-2026"
  ],
```

## Patch 3 — Update survey investigation (lines 2528-2551)

```
Edit: runs/_loop/state.json
old_string:     "tier3-verification-pipeline-survey-2026-05-18": {
      "id": "tier3-verification-pipeline-survey-2026-05-18",
      "title": "Tier-3 verification pipeline candidate survey (post-pipeline-empty pipeline population)",
      "hypothesis": "Pipeline has zero open priority-1-3 physics investigations; researcher Research stage produces ranked candidate list for anko to ratify into seed.md",
      "flow_template": "survey",
      "current_stage": "Research",
      "stages_done": [
        "Research"
      ],
      "stages_at_turn": {
        "Research": [
          69,
          "researcher inventoried [Established] tags, produced 5 ranked candidates (edh-eu151-matsui top)"
        ]
      },
      "tier_current": 1,
      "tier_target": 1,
      "next_stage": "Synthesize",
      "next_stage_action": "Pending anko ratification of candidates into seed.md OR theorist Synthesize stage at T70 if anko silent",
      "blocked_on": "anko ratification of candidate priority",
      "priority": 10,
      "kind": "physics",
      "closing_note": null
    }
new_string:     "tier3-verification-pipeline-survey-2026-05-18": {
      "id": "tier3-verification-pipeline-survey-2026-05-18",
      "title": "Tier-3 verification pipeline candidate survey (post-pipeline-empty pipeline population)",
      "hypothesis": "Pipeline has zero open priority-1-3 physics investigations; researcher Research stage produces ranked candidate list for anko to ratify into seed.md",
      "flow_template": "survey",
      "current_stage": "Synthesize",
      "stages_done": [
        "Research",
        "Synthesize"
      ],
      "stages_at_turn": {
        "Research": [
          69,
          "researcher inventoried [Established] tags, produced 5 ranked candidates (edh-eu151-matsui top)"
        ],
        "Synthesize": [
          70,
          "theorist organized T69 menu, spawned child edh-eu151-vortex-vs-matsui-science-2026, recorded methodology in memory tier3_pipeline_survey_2026_05_18.md"
        ]
      },
      "tier_current": 1,
      "tier_target": 1,
      "next_stage": "Document",
      "next_stage_action": "Survey Document stage may be done at any steady-state turn (1-turn implementer_text closure); not blocking child investigation T71+ work",
      "blocked_on": null,
      "priority": 10,
      "kind": "physics",
      "closing_note": null
    },
    "edh-eu151-vortex-vs-matsui-science-2026": {
      "id": "edh-eu151-vortex-vs-matsui-science-2026",
      "title": "Einstein-de Haas Eu-151 vortex emergence — reproduction of Matsui et al. Science 391, 384-388 (2026)",
      "hypothesis": "SpinorBEC.jl spinor-DDI + split-step framework reproduces Matsui et al. Science 391, 384–388 (2026) [DOI:10.1126/science.adx2872; arXiv:2504.17357] within factor-2 of the experimental EdH timescale τ_EdH^exp and matches the ring-vortex topology (winding number ℓ consistent with F=6 angular-momentum balance) when fed the paper's published parameters (N, trap frequencies ω_{x,y,z}, B-quench waveform, a_s, c_dd).",
      "flow_template": "verify-claim",
      "current_stage": "Research",
      "stages_done": [],
      "stages_at_turn": {},
      "falsifiers": [
        {
          "id": "F1-ring-appears-correct-timescale",
          "description": "Reproduce Matsui near-zero-B-quench from m=+F FM state; measure t_ring where azimuthally-averaged |ψ_{c=c_flip}|^2 has local minimum at r=0 within ±20% depth + annulus aspect ratio >1.5. CORROBORATE if t_ring ∈ [0.5 τ_EdH^exp, 2.0 τ_EdH^exp]; INCONCLUSIVE if t_ring ∈ [0.2, 5.0] τ_EdH^exp; REFUTED if no ring at any t<10 τ_EdH^exp OR ring in wrong spin component. τ_EdH^exp extracted at T71 from paper PDF (NOT invented).",
          "tested_at_turn": null,
          "result": null
        },
        {
          "id": "F2-vortex-topology-l-matches-AM-conservation",
          "description": "Extract winding number ℓ_sim from ∮ ∇ arg(ψ_{c_flip}) · dℓ / (2π) around ring density minimum. CORROBORATE if |ℓ_sim - ℓ_paper| = 0; INCONCLUSIVE if |Δℓ| = 1; REFUTED if |Δℓ| ≥ 2 OR ℓ_sim = 0 (no quantized circulation). ℓ_paper extracted at T71 from paper PDF.",
          "tested_at_turn": null,
          "result": null
        },
        {
          "id": "F3-ground-state-energy-self-consistency",
          "description": "Pre-quench m=+F FM GS at Matsui's N, a_s, trap ω, c_dd. CORROBORATE if |E^sim/N - E_mf/N| / |E_mf/N| < 0.20 against dipolar GP mean-field E_mf/N ≈ (1/2)∑_iℏω_i + (c_0+36 c_1)⟨n⟩/2 + E_DDI/N. OPERATIONAL_GATE (closes at Tier 0.5) if discrepancy > 100% — wiring/unit-conversion bug, implicit Bug-4 contamination check.",
          "tested_at_turn": null,
          "result": null
        },
        {
          "id": "F4-DDI-zero-control-OPTIONAL",
          "description": "Re-run protocol with c_dd=0. CORROBORATE if no ring forms (DDI is the AM-transfer mechanism); REFUTES_INTERPRETATION (not framework) if ring still forms (mechanism is spin-mixing c_1 or LHY artifact, not DDI). Optional: doubles GPU cost; defer to T74+ if F1+F2+F3 on track.",
          "tested_at_turn": null,
          "result": null
        }
      ],
      "tier_current": 0,
      "tier_target": 3,
      "next_stage": "Research",
      "next_stage_action": "T71 director: dispatch researcher_deep to extract Matsui 2026 PDF parameters (N, trap ω_{x,y,z}, B-quench waveform, observed τ_EdH, vortex winding number ℓ). Researcher depth MUST be deep per director.md §F1 (tier_target=3 mandates ≥30 parallel queries + full-PDF mandatory).",
      "blocked_on": null,
      "priority": 1,
      "kind": "physics",
      "closing_note": null
    }
```

## Post-application validation (T71 implementer)

```python3
import json
s = json.load(open("runs/_loop/state.json"))
inv = s["investigations"]
# Survey advanced
assert inv["tier3-verification-pipeline-survey-2026-05-18"]["current_stage"] == "Synthesize"
assert "Synthesize" in inv["tier3-verification-pipeline-survey-2026-05-18"]["stages_done"]
assert inv["tier3-verification-pipeline-survey-2026-05-18"]["blocked_on"] is None
# Child spawned
assert "edh-eu151-vortex-vs-matsui-science-2026" in inv
child = inv["edh-eu151-vortex-vs-matsui-science-2026"]
assert child["flow_template"] == "verify-claim"
assert child["current_stage"] == "Research"
assert child["tier_target"] == 3
assert child["tier_current"] == 0
assert len(child["falsifiers"]) >= 3
assert child["priority"] == 1
# Active id updated
assert s["active_investigation_id"] == "edh-eu151-vortex-vs-matsui-science-2026"
# Index appended
assert "edh-eu151-vortex-vs-matsui-science-2026" in s["investigations_index"]
print("OK_T71_state_patch_applied: all 4 T70 deferred edits in place")
```

If any assertion fails, the patch was applied incorrectly; revert the
state.json file (`git checkout runs/_loop/state.json`) and re-apply.

## Why this packet exists

The T70 theorist agent's tool roster (Read, Grep, Glob, WebFetch, Write,
WebSearch) does not include `Edit`. Mechanical multi-field JSON edits on a
2556-line file are best done with `Edit` (one precise `old_string` →
`new_string` per change, no full-file rewrite). T70 theorist completed the
content-generation work (verification, memory entry, theorist report) and
left this structured packet so T71 implementer_text (which has Edit access)
can apply the 3 atomic edits in ~1k tokens with zero invention risk.

The director T70 §6.failure_modes case "theorist exceeds 3M effective cap
before completing all 4 steps" applies here in the sense that Step 4 was
deferred for tool-availability reasons (not cost), but the triage matches
("If Step 4 skipped, T71 director writes the state.json edits before any
other work (1-turn implementer_text)").
