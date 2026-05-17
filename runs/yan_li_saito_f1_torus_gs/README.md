# Yan-Li-Saito 2026 PRL — F1 falsifier (torus density peak)

**Investigation**: yan-li-saito-2026-reproduction (priority 1, tier 0.7 → 3 target).

**Reference**: arXiv:2605.11670, PRL 136 186502 (Yan-Li-Saito 2026).

## Setup

- Atom: `Eu151_f1_effective` (F=1 effective, a_s=21 a₀, μ=4.5 μ_B, g_F=4.5).
  Paper convention: g_F·F = 9/2 (effective spin-1 model of Eu-151 dipole moment).
- N=15000, ε_dd=1.2, B=0, free space (V_trap=none), DDI+LHY scalar.
- Grid: 64³, box 28.0 a_ho (≈ 2×L₀; L₀ ≈ 14.4 a_ho at these params).
- Initial state: flux-closure flower vortex (winding=1, θ=π/2), ITP relaxes to torus.

## F1 falsifier — acceptance criteria

- **PASS**: |n_max - 13000| / 13000 < 0.10 (n_max in D₀ = 1/(a_s³N²) units).
- **INCONCLUSIVE**: 10-50% deviation.
- **FALSIFIED**: > 0.50 deviation.
- F4 post-process (free): |E_LHY|/|E_ddi| ratio ∈ [2, 20].

## Known adjustments (Q2/Q4 from theorist T30)

- **Q2**: atom `Eu151_f1_effective` overrides g_F·F to paper's 9/2 convention.
  Without this, YAML would use full Eu-151 F=6 (g_F=1.163, μ=6.977 μ_B) → wrong ε_dd.
- **Q4**: `target_Jz` YAML plumbing is NOT wired (confirmed T31 §2 Q4 audit).
  F1 is unaffected (pure ITP, no L_z constraint). F2 (Barnett signature) requires a
  ~3-line patch to `run_step_ground_state.jl` — scope for T34 implementer_text.

## Tier-3 path

F1 (this run) → F4 (energy decomposition post-process, same output) →
F2 (Barnett signature, needs Q4 target_Jz plumbing, constrained-Jz ITP) →
F3 (Larmor slope, needs RTP scan over B_y values).
