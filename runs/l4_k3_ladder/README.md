# L4 K3 collapse-arrest ladder (Task #14)

Push Eu Hamiltonian-only into the high-resolution collapse regime and
test whether **K3**, **γ_dr**, **LHY** arrest it. This is the load-
bearing physics judgement the 32³ Eu robust factorial could not
deliver (the factorial confirmed `Fz/N≈-2.69` is robust at short
time but did not reach collapse).

## Matrix

| Grid | Cells |
|---|---|
| 64³ | HamOnly, K3, gdr, K3+gdr, K3+LHY |
| 96³ | HamOnly, K3, gdr, K3+gdr, K3+LHY |
| 128³ | HamOnly, K3 (collapse-vs-arrest decisive comparison) |

Total: 12 cells. Configs auto-generated via
`scripts/validation/l4_k3_ladder_gen.jl`.

## Parameters

Identical to L4 Matsui Hamiltonian-only baseline
(`runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_64.yaml`)
except:

- `t_evolution = 20.0` dimless (~32 ms physical, 3.2 × τ_EdH) — longer
  than the 10 ms baseline to give collapse onset time to develop.
- `dealias: {enabled: true, k_cut: 16.0, auto_dt: true}` — per the
  validated L4 cross-grid recipe (memory `validation_ladder_2026_05_22`).
- `loss:` block populated per cell (K3_per_m_si = 1.0e-41 m⁶/s, γ_dr =
  0.02 when enabled — Dy164 order-of-magnitude proxies, not measured
  for Eu).
- `lhy: {kind: scalar}` when LHY axis is on; otherwise `kind: none`.
  Explicit in both `ground_state` and `dynamics` steps (post-2026-05-26
  silent-zero defense).

## How to run

```bash
# Generate (idempotent):
julia --project=. scripts/validation/l4_k3_ladder_gen.jl

# Subset (64³ only, ~40 min GPU):
julia --project=. scripts/validation/l4_k3_ladder_gen.jl --grid 64
/tmp/run_l4_k3_64.sh           # or hand-loop, see below

# Full ladder (overnight ~5 h GPU):
for f in runs/l4_k3_ladder/*.yaml; do
  LD_LIBRARY_PATH=/usr/lib/wsl/lib \
    julia --project=. -e "import CUDA; using SpinorBEC; run_yaml(\"$f\")"
done

# Summarise (handles partial sets):
julia --project=. scripts/validation/l4_k3_ladder_summary.jl
```

## Acceptance / decision matrix

After summary, the per-cell observables drive a four-way case split
(anko's framing, 2026-05-26):

```
Case A — K3 on で high-res collapse arrest される
  → Eu は loss-arrested EdH/collapse dynamics として進む

Case B — K3 on でも collapse する
  → K3 係数 / density scale / grid-dt / missing physics 再検討

Case C — K3 は density 抑えるが texture は変わらない
  → K3 = density arrest; texture selection は Hamiltonian/DDI 主導

Case D — LHY は弱い (前回 32³ では 0.5%)
  → scalar LHY は主役ではない、と validation-backed に言える
```

## Observables (per cell)

Written into `runs/l4_k3_ladder/summary.json`:

- `collapse_onset_time` — first save where peak_density > 2 × initial
- `loss_onset_time` — first save where N(t)/N(0) < 0.999
- `peak_density_max` over the trajectory
- `final_N_fraction` — N(T)/N(0)
- `final_Fz_per_N` — ⟨F_z⟩/N at t = T_evolution
- `ΔFz` — F_z(T) − F_z(0) per atom
- `max_Jz_drift` — max|J_z(t) − J_z(0)| (Jz conservation check)
- `texture_class` — from `phase_classify` analyzer output (when present)

## Status

12 configs generated. 64³ subset (5 cells) is queued for the next
GPU window via `/tmp/run_l4_k3_64.sh`. 96³ + 128³ are documented as
ready-to-run; cost is overnight.

## References

- `docs/validation/self_contained_validation_report.md` → Production
  claim shape
- `runs/eu_robust_factorial/README.md` — the short-time 32³ predecessor
  this ladder extends
- `memory:validation_ladder_2026_05_22` — Level 9 (Eu Ham-only
  cross-grid converged at ΔF_z = 0.00886) is the precondition; this
  ladder builds on it
- `memory:dynamics_lhy_plumbing_bug_2026_05_26` — the LHY dispatch
  fix that unblocks the explicit `dynamics.lhy:` block used here
