# Scan group redesign — 2026-04-29

Pain point identified by anko: 70+ `runs/<...>/config.yaml` files, many of which are 1-parameter sweeps (8 phi_omega, 6 Berry, 24 thesis batch). Currently:

- Each sweep point lives as its own dir with its own config.yaml.
- No machine-readable record of "these 8 dirs are one scan".
- Each analyzer (`analyze_phi_omega_scan.jl`, etc.) hard-codes the member list. Keep two analyzers in sync as scans evolve = drift.
- Dashboard shows one run at a time. Cross-run comparison requires tabbing between 8 entries and copying numbers by hand.

## What's already in the project

The YAML schema already supports a `scan:` block (CLAUDE.md):

```yaml
scan:
  zip:                              # 1D sweep
    pipeline.0.zeeman.p: [100, 10, 1]
  product:                          # Cartesian product
    pipeline.0.interactions.c1_ratio: [...]
  comparison_runs:                  # multiple recipes per point
    - name: fl_vortex
      override: {...}
```

`scan_continuation`, `comparison_runs`, `auto_rotate_psi` are wired into `run_yaml`. Used in `runs/eu151_mz_scan/` (gone), `runs/eu151_phase_pq/` (gone) etc — those each have ONE `config.yaml` with a `scan:` block.

Today's new scans (phi_omega, Berry crossover, thesis_batch) bypassed this and instead generated N separate dirs via Julia generator scripts. Cause: launching N parallel runs across 3-GPU chunks is easier when each run is its own shell call. But the result is duplicated YAML and orphan analyzers.

## Proposal

### 1. Single source of truth: `runs/<scan_name>/scan.yaml`

For every scan, ONE top-level YAML at the scan dir root:

```yaml
# runs/phi_omega_scan/scan.yaml
name: phi_omega_eu151
description: |
  Klaus magnetostir frequency optimisation on Eu151.
  Tests whether 226 Hz (= 4.524 dimless at ω_ref = 2π·50 Hz) is the
  optimal stir rate for the F=6 spinor regime.
parameter:
  key: phi_omega
  values: [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]
  unit: "(2π·50 Hz)"
  display_unit: "Hz"
  display_factor: 50.0
template: runs/klaus_eu151_v2_full/config.yaml
override_path: pipeline.3.dynamics.B_hat.phi_omega
extra_overrides:
  pipeline.2.dynamics.B_hat.phi_chirp.to: ${phi_omega}
runs_dir: ./   # subdirs auto-named eu151_phi1_0_500ms, etc.
```

Each scan point's `config.yaml` gets generated from `template + override_path → values[i]`. The scan.yaml is the authoritative record; the per-point YAMLs are derivable artefacts (could be `.gitignore`d, or kept for readability).

### 2. Dashboard `/api/scan_group/<name>` endpoint

Returns aggregated cross-run summary:

```json
{
  "name": "phi_omega_eu151",
  "parameter": {"key": "phi_omega", "unit": "Hz",
                "values_display": [50, 100, 150, ..., 900]},
  "runs": [
    {"value": 1.0, "physics_summary": {...full /api/physics_summary...}},
    {"value": 2.0, "physics_summary": {...}},
    ...
  ]
}
```

Frontend renders this as ONE comparison plot (Lz vs phi_omega, m=+F vs phi_omega, etc) instead of 8 separate panels. Built on top of the per-run `/api/physics_summary` (commit 1ea444e) — no recomputation per scan point.

### 3. Generator + launcher templates

```bash
# Generate per-point configs from scan.yaml
julia --project=. scripts/scan_expand.jl runs/phi_omega_scan/scan.yaml
# → writes runs/phi_omega_scan/eu151_phi*_500ms/config.yaml

# Launch all points (3-parallel by default, configurable in scan.yaml)
bash scripts/scan_launch.sh runs/phi_omega_scan/scan.yaml

# Aggregate + plot
julia --project=. scripts/scan_analyze.jl runs/phi_omega_scan/scan.yaml
```

`scripts/scan_*.jl` replace today's scattered `scripts/generate_phi_omega_scan_local.jl`, `scripts/run_phi_omega_scan.sh`, `scripts/analyze_phi_omega_scan.jl`, and the Berry crossover triplet, and the thesis_batch tetrad. One parameterised set of helpers, fed by N small `scan.yaml` files.

### 4. Migration

Backward-compatible: existing per-point configs keep working through the legacy launcher path. New scans MUST start with a `scan.yaml`. The thesis_batch / phi_omega / Berry crossover get a *retrofit* `scan.yaml` written from their existing N configs (one-shot script, ~30 min):

```bash
julia --project=. scripts/scan_retrofit.jl runs/phi_omega_scan/
# → creates runs/phi_omega_scan/scan.yaml from existing dirs
```

## What this fixes

| pain | fix |
|---|---|
| "70+ dirs, can't tell which is a scan member" | scan.yaml file at scan root |
| "analyzer hardcodes list, drifts" | analyzer reads scan.yaml |
| "dashboard shows one run, must tab" | `/api/scan_group/<name>` aggregates |
| "edit 8 YAMLs to change the protocol" | edit template once + scan.yaml |
| "what was the parameter axis again?" | scan.yaml.parameter.key/unit |

## What it doesn't fix (out of scope)

- Multi-axis scans (currently the project's `scan:` block already handles this with `product:`, but the dashboard view becomes harder — punt to a later iteration).
- Automated parameter discovery (e.g. "find all phi_omega-style scans"). That's a separate indexing problem.
- Cross-scan comparison (e.g. phi_omega scan vs Berry crossover on the same axes). Needs scan-of-scans concept; later.

## Implementation effort

Approximate, in priority order:

| step | effort | blocker? |
|---|---|---|
| `scan_expand.jl` + `scan_launch.sh` + retrofit script | 1 day | no |
| Dashboard `/api/scan_group/<name>` backend | half day | no |
| Frontend cross-run plot widget | 2 days | yes (can't test UI here) |
| Migrate phi_omega, Berry, thesis_batch to scan.yaml | half day | needs above |

**Total: ~3-4 days of focused work.** Doable post-thesis, or before the next scan campaign.

## Decision point

This is a real architectural improvement, not a thesis blocker. The question is timing:

- **Do now (next 2-3 days)**: cleaner thesis writing — one scan.yaml per figure instead of 8 YAML diffs to track.
- **Defer to post-thesis**: thesis figures don't need this for the defense — current analyzers work, just less ergonomic.

anko's call. If we go now, I'd recommend:
1. Build `scan_expand.jl` + `scan_launch.sh` first (1 day) — reusable immediately for any future scan
2. Retrofit phi_omega + Berry + thesis_batch (skim, ~2h)
3. Dashboard endpoint (half day)
4. Frontend widget — defer until anko has bandwidth to test in browser
