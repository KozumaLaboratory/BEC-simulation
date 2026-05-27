# Eu robust factorial — production claim shape (post-pivot)

**Replaces the previous "match Ueda" gating** of the Eu production
claim. See `docs/validation/self_contained_validation_report.md`
"Production claim shape" and `docs/validation/ueda_status.md` for the
2026-05-26 pivot context.

## Design

8 YAML configs, factorial over:

| Axis | Off | On |
|---|---|---|
| K3 loss (true 3-body) | no loss block | `loss.K3_per_m_si = 1e-41 m⁶/s` per m (13 entries) |
| γ_dr (dipolar relaxation) | no loss block | `loss.gamma_dr = 0.02` |
| Scalar LHY | `lhy.kind: none` | `lhy.kind: scalar` |

Naming: `K{0,1}_gdr{0,1}_LHY{0,1}.yaml`. `K0_gdr0_LHY0.yaml` is the
canonical L4 Hamiltonian-only baseline (DDI on, every other model axis
off).

## Base parameters (matched to L4_eu_matsui_hamiltonian_only_32)

- atom: Eu151 (F=6, 13 components)
- N = 30000, ω_ref = 628.3 rad/s
- c1_ratio = -0.005 (placeholder; Eu's 7 channels are unknown)
- grid (32, 32, 32), box [12, 12, 12]
- isotropic harmonic trap ω = (1, 1, 1)
- DDI on (full kernel, secular = false)
- initial state: m=-F polarised
- Bz quench: 0.01 G → 2.6e-5 G (instant; outer step duration becomes
  ramp time per `gotcha_bz_ramp_duration_ignored`)
- t_evolution: 6.28 dimless ≈ 10 ms physical

## Loss parameter values

`gamma_dr = 0.02` (dimensionless) and `K3_per_m_si = 1.0e-41 m⁶/s`
(uniform across all 13 m components) are **Dy164 order-of-magnitude
proxies** — Eu has no measured K3 yet. The factorial is about
**whether the qualitative answer depends on them**, not about getting
the absolute number right.

## Acceptance criteria for "robust"

A conclusion is *robust* iff it holds across all 8 cells of this
factorial at the relative tolerance below.

| Observable | Robustness tolerance |
|---|---|
| ⟨F_z⟩(T) sign | invariant |
| ⟨F_z⟩(T) magnitude | 30% across factorial (loss axes can suppress but should not flip sign) |
| N(T) / N(0) | LHY column has < 1e-3 norm drift (Hamiltonian conserves); K3/γ_dr columns track analytic decay rate |
| peak_density(T) trend | K3-on cells should *clamp* peak density relative to K3-off; sign invariant |
| Texture class (winding number, polyhedral phase) | invariant across the K3, γ_dr axes; LHY axis may shift class |

If any of these fails, the *qualitative* claim is sensitive to a
model axis and must be reported as such — never "robust under all
conditions" without enumerating which.

## How to run

```bash
# Generate (idempotent):
julia --project=. scripts/validation/eu_robust_factorial_gen.jl

# Run one cell:
julia --project=. -e 'using SpinorBEC; run_yaml("runs/eu_robust_factorial/K0_gdr0_LHY0.yaml")'

# Run all 8 (sequential, ~30 min on GPU):
for f in runs/eu_robust_factorial/K*.yaml; do
  julia --project=. -e "using SpinorBEC; run_yaml(\"$f\")"
done

# Summarise:
julia --project=. scripts/validation/eu_robust_factorial_summary.jl
```

## Status

This directory is the *production-claim* infrastructure. The 8 configs
are validated to parse; smoke-tested for K0_gdr0_LHY0. The full sweep
is launched on demand — running all 8 at production grid size is
heavy (≥ 30 min wall time) and is not run on every commit.

## References

- `docs/validation/self_contained_validation_report.md` — full
  validation chain
- `docs/validation/ueda_status.md` — external comparison status
- `runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_32.yaml`
  — Hamiltonian-only baseline this factorial extends
- `memory:validation_ladder_2026_05_22` — Level 12 production criteria
- `memory:gotcha_bz_ramp_duration_ignored` — inner `duration: 0.0`
  is ignored, outer step duration becomes the ramp time
