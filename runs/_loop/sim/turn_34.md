---
turn: 34
subagent: implementer
topic_tags: [yan-li-saito-2026, design-corrective-redo, rotating-basis-atom-resolution, config-bug-fixes, potential-zero-trap, zeeman-key, resolve-atom, audit-scope-error, meta-critic-trigger]
paper_section: null
depends_on: [33, 32]
produces: "src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl (_resolve_atom_or_nothing helper +11 lines, if/else chain replaced -17 lines net); runs/yan_li_saito_f1_torus_gs/config.yaml (3 targeted edits: potential.type, zeeman key, lhy+fl_vortex cleanup); runs/_loop/sim/turn_34.md (this report)"
---

# Turn 34 — Implementer Report (Design Corrective REDO)

## 1. Context summary

T33 INCONCLUSIVE/data_gap: `run_yaml` threw `ArgumentError` before any ITP step due to 5 bugs found by static inspection. T34 dispatches 1 Julia source edit (BUG-2 atom resolution) + 3 YAML config edits (BUG-1 potential type, BUG-3 zeeman key, BUG-5+BUG-4 cleanup). No Julia execution this turn.

Patches applied:
1. **BUG-2 CODE FIX**: Added `_resolve_atom_or_nothing` helper to `run_step_rotating/ground_state.jl` that delegates to `SpinorBEC.resolve_atom(Symbol(...))` via the canonical ATOM_REGISTRY. Replaced the 17-line hard-coded `if atom_name == "Eu151" ... elseif ...` chain with a 3-line call to this helper. `Eu151_f1_effective` (and all 22 ATOM_REGISTRY entries) now resolve correctly.
2. **BUG-1 CONFIG FIX**: `potential: {type: none}` → `potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}`. Free space is implemented as zero-frequency harmonic (the only supported potential type in rotating_basis).
3. **BUG-3 CONFIG FIX**: `B: {p: 0.0}` → `zeeman: {p: 0.0, q: 0.0}`. Rotating_basis GS reads `p["zeeman"]::Dict` at line 131 of the patched file; `B:` key is not recognized and would cause `KeyError: zeeman`.
4. **BUG-5 + BUG-4 CONFIG CLEANUP**: Removed `lhy: {kind: scalar}` (silently ignored by rotating_basis, LHY auto-derives via auto_path when ε_dd > 0.5) and `initial_state: fl_vortex` + `init_state_params:` (rotating_basis only handles `from_jld2`). Added `init_m_idx: 1` + `init_sigma: 2.0` to set explicit Gaussian seed parameters.

## 2. Files edited

### 2a. `src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl` — Edit (2 hunks)

Absolute path: `/home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl`

**Hunk 1**: Added `_resolve_atom_or_nothing` helper at lines 1-11 (before `@noinline function _run_rotating_basis_ground_state_step`). Net +11 lines.

**Hunk 2**: Replaced 17-line `if/elseif/else` chain (old lines 49-72, 5 atoms + nothing fallback) with 5-line call block. Net -12 lines.

Total delta: -1 line net (11 added helper - 12 removed chain + 0 elsewhere).

Read-back verification (lines 1-11 of patched file):
```julia
# Resolve atom name to AtomSpecies via the canonical ATOM_REGISTRY (defined in
# src/workflow/initialization/atoms.jl). Returns nothing if unknown, which
# triggers the manual c0/c_dd interaction path below. Keeps type inference
# narrow: return type is Union{AtomSpecies, Nothing}.
@noinline function _resolve_atom_or_nothing(atom_name::AbstractString)::Union{AtomSpecies, Nothing}
    return try
        SpinorBEC.resolve_atom(Symbol(atom_name))::AtomSpecies
    catch err
        err isa ArgumentError ? nothing : rethrow()
    end
end
```

Read-back verification (call site at lines 61-66):
```julia
    atom_obj = if haskey(p, "atom")
        atom_name = string(p["atom"])::String
        _resolve_atom_or_nothing(atom_name)
    else
        nothing
    end
```

grep_count `_resolve_atom_or_nothing` in file: **2** (definition line 5 + call site line 63). Criterion `>=2`: PASS.
grep_count `SpinorBEC.Eu151` (pattern: `SpinorBEC\.Eu151|SpinorBEC\.Dy164|SpinorBEC\.Dy162|SpinorBEC\.Cr52|SpinorBEC\.Rb87`) in file: **0**. Criterion `==0`: PASS.

### 2b. `runs/yan_li_saito_f1_torus_gs/config.yaml` — Edit (3 hunks)

Absolute path: `/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml`

**Edit 2a (BUG-1)** — line 36 (mixin block):
Old: `    potential: {type: none}`
New: `    potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}  # free space = zero-frequency harmonic (...)`

**Edit 2b (BUG-3)** — line 42 (pipeline step):
Old: `      B: {p: 0.0}`
New: `      zeeman: {p: 0.0, q: 0.0}              # B=0 paper setup; rotating_basis parses p["zeeman"] not p["B"]`

**Edit 2c (BUG-5+BUG-4)** — lines 44-46 (pipeline step):
Old:
```yaml
      lhy: {kind: scalar}
      initial_state: fl_vortex
      init_state_params: {winding: 1, theta: 1.5707963267948966}
```
New:
```yaml
      # lhy: auto-derived via atom_obj + auto_path branch (ε_dd=1.2 > 0.5)
      # initial_state: Gaussian seed (rotating_basis only supports `from_jld2`;
      # fl_vortex topology deferred — see sim/turn_34.md §9 for follow-up work item).
      init_m_idx: 1                          # m=+F polarized seed (F=1 effective → m=+1)
      init_sigma: 2.0                        # ~2 a_ho Gaussian width; ITP relaxes to droplet
```

Read-back verification (full patched config.yaml, key checks):

| Check | Line | Content | Result |
|-------|------|---------|--------|
| `type: harmonic` present | 36 | `potential: {type: harmonic, omega: [0.0, 0.0, 0.0]}` | PASS |
| `type: none` absent | — | grep count = 0 | PASS |
| `zeeman:` present | 42 | `zeeman: {p: 0.0, q: 0.0}` | PASS |
| `B:` at step level absent | — | grep -cP `^\s+B:\s` = 0 | PASS |
| `initial_state: fl_vortex` absent | — | grep count = 0 | PASS |
| `lhy:` (non-comment) absent | — | grep count = 0 | PASS |
| `init_m_idx` present | 47 | `init_m_idx: 1` | PASS |
| `init_sigma` present | 48 | `init_sigma: 2.0` | PASS |

Note: Two comment-only mentions of `fl_vortex` remain (line 23 in the header comment block, line 46 in the inline comment). These are YAML comments and do not affect parsing. `initial_state: fl_vortex` as an active key: 0 occurrences.

## 3. Dispatch-path trace

Full dispatch from `run_yaml("runs/yan_li_saito_f1_torus_gs/config.yaml")` to the actual `_run_step` method:

**Level 1**: `run_yaml(path)` at `src/workflow/experiments/runtime/runtime_io.jl:23` calls `load_config(path)` → returns `RunConfig` struct → calls `run_registry.jl:run_yaml_inner(cfg)` → calls `run_pipeline(steps, ...)`.

**Level 2**: `run_pipeline` at `src/workflow/experiments/pipeline/pipeline_runner.jl` iterates over pipeline steps. Each step's `kind` field determines dispatch.

**Level 3**: For `kind: rotating_basis` (set by `defaults: {kind: rotating_basis}`), the YAML parser creates a `RotatingBasisGroundStateStep` struct. `_run_step(::RotatingBasisGroundStateStep, ...)` at `src/workflow/experiments/pipeline/run_step_rotating/dispatch.jl` calls `_run_rotating_basis_ground_state_step(p; verbose)` — NOT `_run_ground_state_step` (which handles `kind: ground_state`, the standard path).

**Level 4**: `_run_rotating_basis_ground_state_step(p::Dict{String, Any}; verbose::Bool)` at `/home/suzume/workspace/BEC-simulation/src/workflow/experiments/pipeline/run_step_rotating/ground_state.jl`. This is the file we patched.

**Config key → parse location map** (line numbers are in the patched file):

| Config key | Source | Parsed at line | Notes |
|-----------|--------|---------------|-------|
| `grid.n` | mixin `yan_li_saito_f1` | 21-22 | `Int.(grid_node["n"])` |
| `grid.box` | mixin | 23 | `Float64.(grid_node["box"])` |
| `dtype` | (absent, default f64) | 28 | `get(p, "dtype", "f64")` |
| `potential.type` | mixin | 34 | `get(pot_node, "type", "harmonic")` — now "harmonic", passes guard |
| `potential.omega` | mixin | 38 | `Float64.(pot_node["omega"])` — now `[0.0, 0.0, 0.0]` |
| `atom` | mixin | 61-63 | `haskey(p, "atom")` → `_resolve_atom_or_nothing("Eu151_f1_effective")` → `Eu151_f1_effective` |
| `F` | (absent, derived from atom) | 67-73 | `atom_obj.F == 1` |
| `interactions.N_atoms` | mixin | 79 | `get(inter, "N_atoms", ...)` → 15000 |
| `interactions.omega_ref` | mixin | 80 | `get(inter, "omega_ref", ...)` → 314.159 |
| `interactions.c1` | mixin | 107 | `Float64(get(inter, "c1", 0.0))` → 0.0 |
| `gauge_fix` | mixin | 138 | `Bool(get(p, "gauge_fix", true))` → false |
| `backend` | defaults | 141 | `get(p, "backend", "cpu")` → "gpu" → `CUDABackend()` |
| `zeeman.p` | step | 131-132 | `p["zeeman"]::Dict`; `Float64(get(zee, "p", 0.0))` → 0.0 |
| `zeeman.q` | step | 133 | `Float64(get(zee, "q", 0.0))` → 0.0 |
| `init_m_idx` | step | 157 | `Int(get(p, "init_m_idx", p_z > 0 ? 1 : D))` → 1 |
| `init_sigma` | step | 164-165 | `haskey(p, "init_sigma")` → `Float64(p["init_sigma"])` → 2.0 |
| `n_steps` | step | 221 | `Int(get(p, "n_steps", ...))` → 5000 |
| `dt` | step | 222 | `Float64(get(p, "dt", 0.005))` → 0.005 |
| `tol` | step | NOT PARSED | Silent-ignore — `find_ground_state_rotating!` has no tol kwarg; ITP runs exactly n_steps iterations. This is BUG-6 (new discovery, non-fatal). |
| `ddi` | step | NOT PARSED | Silent-ignore — c_dd flows via auto_path (atom_obj + N_atoms + omega_ref). The `ddi: {enabled: true}` block in the config is a no-op for the GS step; DDI is always computed when c_dd > 0. `ddi.enabled: false` semantics are NOT honored by rotating_basis GS. Documented in §9 deferred work items. |

**Auto-path activation**: `atom_obj = Eu151_f1_effective` (non-nothing) + `n_atoms_node = 15000` + `omega_ref_node = 314.159` → `auto_path = true`. This triggers:
- `c0_auto = compute_c_total(Eu151_f1_effective; N_atoms=15000, omega_ref=314.159)`
- `c_dd_auto = compute_c_dd_dimless(Eu151_f1_effective; N_atoms=15000, omega_ref=314.159)`
- `ε_dd_phys = compute_a_dd(Eu151_f1_effective) / Eu151_f1_effective.a_s` ≈ 1.2 → > 0.5 → `γ_auto = compute_gamma_lhy(...)` (nonzero LHY)

All 4 critical interaction parameters (c0, c_dd, γ_LHY, c1=0) are correctly set. DDI and LHY are active.

**Contrast with T32 audit scope error**: T32 audited `run_step_ground_state.jl` (standard path, activated by `kind: ground_state`). The config uses `defaults: {kind: rotating_basis}`, which routes to `_run_rotating_basis_ground_state_step`. These are entirely separate parsers. The `fl_vortex` and `lhy:` support in `run_step_ground_state.jl` that T32 cited does NOT apply to the rotating_basis path.

## 4. Atom resolution verification

**New helper definition** (lines 1-11 of patched `ground_state.jl`):
```julia
@noinline function _resolve_atom_or_nothing(atom_name::AbstractString)::Union{AtomSpecies, Nothing}
    return try
        SpinorBEC.resolve_atom(Symbol(atom_name))::AtomSpecies
    catch err
        err isa ArgumentError ? nothing : rethrow()
    end
end
```

**Call site** (lines 61-66):
```julia
    atom_obj = if haskey(p, "atom")
        atom_name = string(p["atom"])::String
        _resolve_atom_or_nothing(atom_name)
    else
        nothing
    end
```

**Static cross-check**: `SpinorBEC.resolve_atom(:Eu151_f1_effective)`:
- `resolve_atom` defined at `src/workflow/initialization/atoms.jl:313-316`
- Exported from `atoms.jl` at line 5: `export ATOM_REGISTRY, resolve_atom`
- `atoms.jl` is loaded by `workflow/initialization.jl` which is `include`d by `SpinorBEC.jl:40`
- `ATOM_REGISTRY[:Eu151_f1_effective]` → `Eu151_f1_effective` at `atoms.jl:302`
- Return type: `AtomSpecies` struct — confirmed by `resolve_atom` body: `ATOM_REGISTRY[name]` where all registry values are `AtomSpecies` instances
- `::AtomSpecies` type assertion in the helper is satisfied (no Union — pure concrete type)
- Return type of helper: `Union{AtomSpecies, Nothing}` — Union{concrete, Nothing} is the same type as the old if/else chain returned

**`_resolve_atom_or_nothing` is in scope**: `ground_state.jl` is `include`d by `run_step_rotating.jl:57` which is `include`d by `experiments.jl:44` which is `include`d by `SpinorBEC.jl:44`. The helper is defined at file-scope (not inside any function), so it is in the `SpinorBEC` module namespace. `SpinorBEC.resolve_atom` is called with the qualified name — no ambiguity.

**Unknown atom fallback**: if `atom_name` is not in `ATOM_REGISTRY`, `resolve_atom` throws `ArgumentError("Unknown atom: ...")`. The `catch err isa ArgumentError ? nothing : rethrow()` returns `nothing`, which triggers `auto_path = false` and falls through to the manual c0/c_dd path. The pre-existing warn message at lines 120-129 fires. Backward compatible.

## 5. Precondition check for T35 Execute

T35 implementer_julia_gpu MUST run this chain FIRST, before any ITP:

```bash
# Step 1: disk-truth check (exit 0 required)
test -f /home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml || { echo "FAIL: config missing"; exit 1; }

# Step 2: YAML parse + mixin expansion + atom resolution (exit 0 required)
LD_LIBRARY_PATH=/usr/lib/wsl/lib \
  /home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia \
  --project=/home/suzume/workspace/BEC-simulation -e '
using SpinorBEC
cfg = load_config("/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml")
println("Config loaded: ", length(cfg.steps), " steps")
atom = SpinorBEC.resolve_atom(:Eu151_f1_effective)
@assert atom.F == 1 "Expected F=1, got $(atom.F)"
println("Atom resolved: ", atom.name, " F=", atom.F, " a_s=", atom.a_s, " mu=", atom.mu_mag)
println("PRECONDITION OK")
'
```

Expected output:
```
Config loaded: 1 steps
Atom resolved: 151Eu_f1eff F=1 a_s=<value> mu=<value>
PRECONDITION OK
```

If `load_config` throws: indicates mixin expansion or YAML schema error — abort, report as BUG-7, Director dispatches Design redo #3.
If `@assert atom.F == 1` fails: `Eu151_f1_effective` was registered with wrong F — abort, report as data corruption.
If precondition exits 0: proceed to `run_yaml(...)` with full 5000-step ITP.

## 6. What T35 director should do

**§3 dispatch trace: CLEAN** — every config key is accounted for in the rotating_basis GS parser. Two silent-ignore keys found (`tol` and `ddi`), both non-fatal (documented as BUG-6 and a known gap). No 6th crash-level bug.

**§4 atom resolution: VERIFIED** — `SpinorBEC.resolve_atom(:Eu151_f1_effective)` is statically confirmed to return `Eu151_f1_effective::AtomSpecies` via ATOM_REGISTRY. Helper is in scope, return type is correct.

**Decision**: T35 = Execute (implementer_julia_gpu) with the same brief structure as T33:
1. Run precondition check (§5 above). Exit nonzero → abort with reason.
2. Run `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e 'using CUDA, SpinorBEC; run_yaml("runs/yan_li_saito_f1_torus_gs/config.yaml")'`. Capture stdout + JLD2.
3. Post-process: extract n_max (peak density), E_kin, E_s, E_ddi, E_lhy from result.jld2. Compute |E_LHY|/|E_ddi| ratio.
4. Evaluate F1 (n_max vs 13000 D₀ ±10%) and F4 (ratio in [2, 20]).
5. Write sim/turn_35.md.

Expected wall: 5-15 min ITP + 4 min JIT precompile. Total: ~10-20 min.

**If §3 trace reveals BUG-7** (a 6th crash-level bug from the precondition check): T35 = Design redo #3 (final allowed redo before critic Cross-check escalation).

## 7. Risk register hits

**Risks CLOSED by this patch:**
- BUG-1 (FATAL: `potential: {type: none}` → ArgumentError): CLOSED. Patched to `type: harmonic, omega: [0.0, 0.0, 0.0]`.
- BUG-2 (CRITICAL: atom_obj=nothing → c0=c_dd=γ=0 non-interacting gas): CLOSED. `_resolve_atom_or_nothing` delegates to `resolve_atom(Symbol(...))` via ATOM_REGISTRY. `Eu151_f1_effective` returns the correct `AtomSpecies`, enabling auto_path.
- BUG-3 (FAIL: `B: {p: 0.0}` → KeyError: zeeman): CLOSED. Config now uses `zeeman: {p: 0.0, q: 0.0}`.
- BUG-5 (SILENT: `lhy: {kind: scalar}` silently ignored): CLOSED. Block removed; LHY auto-derives via auto_path at ε_dd=1.2 > 0.5.

**Risk OPEN (deferred):**
- BUG-4 (SILENT: `initial_state: fl_vortex` silently ignored → Gaussian seed substituted): Deferred to T36+. Risk: ITP may relax Gaussian seed to a non-torus local minimum, missing the torus topology of the paper's droplet GS. Impact on F1: density magnitude check may still pass (droplet forms regardless of topology); impact on F2/F3 (mechanical rotation): higher if topology matters for Barnett effect strength. Mitigation: if T35 F1 INCONCLUSIVE due to high n_max deviation AND diagnosis points to topology-trapping, implement fl_vortex init in rotating_basis GS (~20 lines).

**New risks from this patch:**
- `_resolve_atom_or_nothing` in scope: VERIFIED statically. Helper is at module-scope inside `SpinorBEC`, same as all other `_run_*` helpers. Risk level: low.
- `V_trap.omega` latent bug (line 171 in original, now line 183 in patched file): `V_trap` is a plain `Array`, which has no `.omega` field. The auto-derive branch for `init_sigma` (when `init_sigma` is NOT in config) would crash. Since our config supplies `init_sigma: 2.0`, this branch is skipped and the bug is not triggered. Risk: medium if this config is reused without `init_sigma`. Not fixing this turn (out of scope per directive; note in §9).
- `tol: 1.0e-9` silently ignored (BUG-6, new discovery): `find_ground_state_rotating!` runs exactly n_steps=5000 ITP iterations; there is no convergence-based early stop. The GS may not be fully converged at 5000 steps. If n_max deviates by >10% from paper, consider increasing n_steps rather than reducing dt.

## 8. Cost estimate for T35 Execute

- GPU JIT precompile (first time SpinorBEC + CUDA load): ~4 min
- 5000 ITP steps at 64³ on GPU (F=1, D=3, DDI+LHY): estimated 5-15 min depending on GPU throughput
- Post-process (extract metrics from JLD2): < 1 min
- Total wall: ~10-20 min
- Effective tokens: ~3M (same order as T33, which was 9.98M effective including heavy static-audit reading)
- Budget note: within scheduler `cost_cap_per_turn_effective = 6M`

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "norm_initial": null,
  "norm_final": null,
  "norm_drift": null,
  "energy_initial": null,
  "energy_final": null,
  "energy_monotonic": null,
  "mz_target": null,
  "mz_final": null,
  "fitted_order": null,
  "fit_dt_range": null,
  "fit_r_squared": null,
  "wall_time_sec": 180,
  "peak_memory_gb": null,
  "tests_passed": null,
  "julia_invocation_count": 0,
  "ground_state_jl_has_resolve_atom_helper": true,
  "ground_state_jl_atom_obj_calls_helper": true,
  "config_yaml_potential_type_is_harmonic": true,
  "config_yaml_zeeman_key_present": true,
  "config_yaml_B_key_absent": true,
  "config_yaml_lhy_block_absent": true,
  "config_yaml_initial_state_fl_vortex_absent": true,
  "config_yaml_init_m_idx_present": true,
  "sim_turn_34_md_exists_on_disk": true,
  "sim_turn_34_dispatch_trace_section_complete": true,
  "grep_count_resolve_atom_or_nothing_in_run_step_rotating_ground_state_jl": 2,
  "grep_count_SpinorBEC_Eu151_in_run_step_rotating_ground_state_jl": 0,
  "grep_count_potential_type_harmonic_in_config_yaml": 1,
  "grep_count_potential_type_none_in_config_yaml": 0,
  "grep_count_zeeman_p_in_config_yaml": 1,
  "grep_count_lone_B_colon_at_indent_in_config_yaml": 0,
  "grep_count_initial_state_fl_vortex_in_config_yaml": 0,
  "grep_count_init_m_idx_in_config_yaml": 1,
  "file_exists_runs_loop_sim_turn_34_md": true,
  "grep_count_section_dispatch_path_trace_in_sim_turn_34_md": 1,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 9804190,
    "total": 9804190,
    "effective_full_rate": 1490783,
    "breakdown": {
      "input_fresh": 13630,
      "cache_creation": 359590,
      "cache_read": 9413711,
      "output": 17259
    },
    "n_messages": 81,
    "n_message_starts": 81
  },
  "warnings": [
    "BUG-6 NEW (silent-ignore, non-fatal): tol: 1.0e-9 in config is NOT parsed by _run_rotating_basis_ground_state_step; find_ground_state_rotating! has no tol kwarg and runs exactly n_steps iterations. If GS is not converged at 5000 steps, increase n_steps.",
    "BUG-7 POTENTIAL (latent, non-triggered): V_trap.omega field access at patched file line 183 would crash if init_sigma were absent from config \u2014 V_trap is a plain Array with no .omega field. Config supplies init_sigma: 2.0 so this branch is skipped. Risk for configs that omit init_sigma with omega=0 axes.",
    "ddi: {enabled: true} block in config is a no-op for rotating_basis GS step \u2014 c_dd is set via auto_path, not via the ddi: block. ddi.enabled: false would NOT zero c_dd in rotating_basis GS. Documented as known gap."
  ],
  "physical_red_flags": [],
  "falsification_result": "INCONCLUSIVE"
}
```

## 9. Deferred work items (T36+ scope)

1. **BUG-4 fl_vortex initial state** in rotating_basis GS: ~20-line addition to `_run_rotating_basis_ground_state_step` reading `initial_state` key and dispatching to `init_psi(grid, SpinSystem(F_atom); state=:fl_vortex, init_state_params...)` on CPU then `copyto!(ws.psi_tilde, host)`. Only needed if T35 F1 PASS fails AND diagnosis points to topology-trapping in Gaussian seed. Defer until T35 result is known.
2. **`ddi.enabled: false` semantics**: rotating_basis GS always uses c_dd from auto_path; the `ddi:` block is a no-op. If `ddi.enabled: false` should zero c_dd, this requires explicit parsing of `ddi.enabled` and conditional zeroing of `c_dd`. Separate Design turn.
3. **`tol:` passthrough to ITP**: `find_ground_state_rotating!` does not support convergence-based early stop. Implementing a tol-based halt would require modifying `src/rotating_basis/integrators.jl:find_ground_state_rotating!` to track energy convergence and break when `|dE/E| < tol`. Moderate scope (~10 lines). Separate turn.
4. **`V_trap.omega` latent bug** (line 183 of patched file): the auto-derive `init_sigma` path accesses `V_trap.omega` which does not exist on `Array`. Fix: replace with `ω_vec` (already in scope at the function level). 1-line fix. Can be done in a future Design turn when the auto-derive path is needed.
5. **F2 design** (constrained-J_z Barnett signature): requires `target_Jz` YAML plumbing patch to rotating_basis GS per sim/turn_32.md §27. Separate Design turn, after T35 F1 verdict.
6. **F3 design** (Larmor slope dω_L/dB_y = γ ±5%): requires RTP scan setup. Larger turn.

## 10. Meta-loop observation (three concrete data points)

Three contract-level mistakes the loop has experienced, for meta-critic-placement-2026-05-17 Hypothesize stage:

**Data point 1: T31 phantom-PASS** (commit block masked by judge metrics)

Turn 31 reported Design PASS on yan-li-saito-2026-reproduction. The judge accepted the implementer's self-reported `file_exists: true` metrics. In reality, 1Password SSH-signing blocked the git commit and the staged delta (atoms.jl + config.yaml + README.md) was lost. The orchestrator's file-system snapshot did not capture the changes because the commit hook failed silently. Lesson: `file_exists` metrics must be verified by the judge via `precondition_check` (a real shell command), not by reading the implementer's self-report. The T32 Design redo corrected this by using Write/Edit tools without a git commit — the orchestrator's snapshot captured the delta via file-system diff, not git state.

**Data point 2: T32 audit-scope error** (Design audited the wrong dispatch path)

Turn 32 Design read `run_step_ground_state.jl` (standard path, activated by `kind: ground_state`) to validate config keys. The config used `defaults: {kind: rotating_basis}`, routing to `_run_rotating_basis_ground_state_step` in `run_step_rotating/ground_state.jl`. These two files have entirely different parameter parsers. All 5 bugs found by T33 stem from this single routing-path error: BUG-1/3/5 are YAML keys that the standard GS path handles but rotating_basis path does not; BUG-2 is an atom-name chain that only the rotating_basis path has; BUG-4 is a feature supported by standard path but absent from rotating_basis. Lesson: Design must trace the FULL dispatch path for the config's `kind:` value — confirmed by reading the dispatch.jl file that handles `_run_step(::RotatingBasisGroundStateStep, ...)` — not the path that looks most natural by name. This is analogous to the K_3 routing bug (memory `gotcha_K3_routing_pre_2026_05_13.md`): a value that passes type checking but flows to the wrong handler, producing silently wrong behavior.

**Data point 3: T33 judge `operator: in` semantics** (probable judge.py bug)

Turn 33 judge marked the criterion `f1_verdict=INCONCLUSIVE in ['PASS', 'INCONCLUSIVE', 'FALSIFIED'] → False` even though `INCONCLUSIVE` IS in the list. The `operator: "in"` membership test appears to have a string-comparison or deserialization bug in judge.py. The actual INCONCLUSIVE verdict was correct (run_yaml threw before ITP; no physics data produced). The judge's False result on this criterion is a contract-level false negative — the loop did the right thing (reported INCONCLUSIVE) but the judge penalized it. This is the same class of "plausible-value, wrong-dispatch" error as BUG-2 and the K_3 routing bug: the value (`"INCONCLUSIVE"`) is correct, but the comparison operator misidentifies it. NOT fixing this turn; flagging for meta investigation.

These three observations together support the meta-investigation hypothesis: "Inserting a Design-after-critic stage before expensive Execute reduces contract-level mistakes by ≥75%." All three could have been caught by a 1-turn critic audit before Execute:
- T31: critic would verify disk state independently before PASS.
- T32: critic would trace the actual dispatch path for `kind: rotating_basis`.
- T33: critic would audit the judge.py `operator: in` implementation.

## 11. Falsification check

`falsification_result: "INCONCLUSIVE"` — this is a Design corrective turn. No physics simulation was executed. No density or energy data was produced. The relevant check is whether the 3 config + 1 Julia patches landed on disk correctly and are internally consistent. Static verification via Read + grep confirms all 8 observable_manifest items are satisfied.
