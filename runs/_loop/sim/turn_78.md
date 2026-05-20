---
turn: 78
subagent: implementer
workload_class: implementer_text
directive_action: modify_code
directive_label: edh-matsui-prereq-class-fix-haskey-B-yaml-bz-sign
topic_tags: [d1-verification-depth, edh-eu151-matsui-science-2026, haskey-zeeman-vs-B-class-fix, latent-reproducibility-bug, sed-class-mechanical, yaml-bz-sign-flip-option-a, prerequisite-for-t79-r1]
depends_on: [77, 76, 75, director/turn_78, critic/turn_77]
produces: "3-line src fix + 1-line YAML fix + class-extension grep verification + single git commit on main (5814dba). Prereq for T79 R1 Execute-retry."
---

# Turn 78 — Implementer modify_code: EdH-Matsui prerequisite class-fix

## 1. Brief recap

T77 critic identified two issues blocking reliable matsui_edh_baseline execution:

1. **Latent B-block consumption bug** (NEW RED FLAG §5.1): `run_step_ground_state.jl` read `p["zeeman"]` but `_split_B_block!` (B_block.jl:165) post-normalize writes `step["B"]` and `_reject_unknown_step_keys!` raises on `step["zeeman"]`. The key `"zeeman"` was never present in the normalized dict, so `haskey(p, "zeeman")` always fell through to the `ws_prev` branch — silently dropping the user-specified B-block in GS steps. The fix T76 applied on branch `auto/turn_76` (commit 72c5b0f) never merged to main.

2. **Bz sign mismatch** (§7.2 Option A): `matsui_edh_baseline.yaml` had `Bz: "0.01 Gauss"` (positive), but `initial_state: m_minus_F` seeds the ITP in the m_F=-6 stretched state. At positive Bz, the Zeeman term energetically penalizes m_F=-6 relative to m_F=+6, creating a conflict. Flip to `-0.01 Gauss` aligns field with seed.

Both are mechanical text changes (implementer_text class). No Julia execution.

## 2. Edits applied (per director §6 brief)

### 2.1 Edit 1: run_step_ground_state.jl:118-124 (haskey "zeeman" → "B" in main branch)

File: `src/workflow/experiments/pipeline/run_step_ground_state.jl`

Before:
```julia
    zeeman = if haskey(p, "zeeman")
        _build_zeeman_dispatched(p["zeeman"], duration, atom, p)
    elseif ws_prev !== nothing
        ws_prev.zeeman
    else
        _parse_zeeman(Dict(), duration)
    end
```

After:
```julia
    zeeman = if haskey(p, "B")
        _build_zeeman_dispatched(p["B"], duration, atom, p)
    elseif ws_prev !== nothing
        ws_prev.zeeman
    else
        _parse_zeeman(Dict(), duration)
    end
```

Mirrors `run_step_dynamics.jl:93-97` pattern exactly.

### 2.2 Edit 2: run_step_ground_state.jl:273 (same key fix in LBFGS reuse guard)

Before:
```julia
            !haskey(p, "potential") && !haskey(p, "zeeman")
```

After:
```julia
            !haskey(p, "potential") && !haskey(p, "B")
```

This guard controls whether LBFGS reuses `ws_prev` or rebuilds. With the old key it always reused (no `"zeeman"` key post-normalize), ignoring any B override in the YAML.

### 2.3 Edit 3: matsui_edh_baseline.yaml:94 (Bz sign flip per critic Option A)

File: `runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml`

Before:
```yaml
        Bz: "0.01 Gauss"                 # 1.0 μT FM-stabilising field during ITP (matches eu151_edh precedent)
```

After:
```yaml
        Bz: "-0.01 Gauss"                # 1.0 μT FM-stabilising field; negative sign for m_minus_F initial_state per T77 critic §7.2 Option A (ITP at p_dimless<0 energetically prefers m_F=-F)
```

Magnitude unchanged (1.0 μT = 0.01 Gauss). Sign flipped to align quadratic Zeeman p_dimless < 0, energetically preferring m_F = -F ground state consistent with the seed.

## 3. Class-extension grep verification

**Grep 1** — remaining `haskey(p, "zeeman")` anywhere in `src/`:

```
Pattern: haskey\(p,\s*["']zeeman["']\)
Path: src/
Result: No matches found
```

ZERO matches. The two lines fixed in Edit 1+2 were the only instances.

**Grep 2** — remaining `"zeeman"` string in `src/workflow/experiments/pipeline/`:

```
Pattern: "zeeman"
Path: src/workflow/experiments/pipeline/
Result: No matches found
```

ZERO matches. All consumers in the pipeline subdirectory now read `"B"`.

Both greps confirm the class-fix is complete with no remaining instances. No scope extension required.

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "edits_applied": 3,
  "files_modified": [
    "src/workflow/experiments/pipeline/run_step_ground_state.jl",
    "runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml"
  ],
  "haskey_zeeman_remaining_in_src_jl": 0,
  "zeeman_string_in_pipeline_subdir_remaining": 0,
  "yaml_bz_sign_flipped": true,
  "git_commit_applied": true,
  "git_commit_sha": "5814dba",
  "git_branch_at_commit": "main",
  "tests_passed": null,
  "wall_time_sec": 45,
  "peak_memory_gb": null,
  "physical_red_flags": [],
  "warnings": [],
  "falsification_result": "CODE_CHANGE_APPLIED",
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 9731752,
    "total": 9731752,
    "effective_full_rate": 1430373,
    "breakdown": {
      "input_fresh": 10568,
      "cache_creation": 311860,
      "cache_read": 9391151,
      "output": 18173
    },
    "n_messages": 71,
    "n_message_starts": 71
  }
}
```

## 5. Self-review checklist

- [x] On branch `main` before editing (confirmed via `git status`).
- [x] Edit 1 applied: `haskey(p, "zeeman")` → `haskey(p, "B")` at line 118, `p["zeeman"]` → `p["B"]` at line 119.
- [x] Edit 2 applied: `!haskey(p, "zeeman")` → `!haskey(p, "B")` at line 273.
- [x] Edit 3 applied: `Bz: "0.01 Gauss"` → `Bz: "-0.01 Gauss"` with updated inline comment.
- [x] Grep 1 returns 0 hits — no remaining `haskey(p, "zeeman")` in src/.
- [x] Grep 2 returns 0 hits — no remaining `"zeeman"` in pipeline/ subdirectory.
- [x] Commit message uses Conventional Commits format, `Assisted-by:` trailer (no `Co-Authored-By:`).
- [x] gitleaks pre-commit hook passed (0 leaks found).
- [x] No Julia execution performed (workload class implementer_text respected).
- [x] No Pkg.test() invoked.
- [x] No files outside the 2 specified src/config targets were modified.
- [x] No new files created.
- [x] `runs/_loop/critic/turn_77.md` and `state.json` untouched.
- [x] No auto/turn_75 or auto/turn_76 branch touches.
