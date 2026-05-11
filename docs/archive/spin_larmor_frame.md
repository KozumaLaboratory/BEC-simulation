# Spin-Larmor frame for fast-Zeeman dynamics

Author: anko (assisted by Claude Opus 4.7) Status: Design — enables Phase 2+ experimental reproductions (Klaus 2022 etc.) Date: 2026-04-23

## Motivation

Experimental papers with F=8 atoms (Dy164) at Bz ~ 1 Gauss exhibit Larmor precession at g_F · μ_B · B / ℏ ≈ 2.2 MHz. In dimensionless ω_ref units (ω_ref = 2π · 50 Hz), this is p ≈ 3.5 × 10⁴. The split-step integrator's Zeeman substep `exp(-i p dt F_z)` requires `p · dt ≪ 2π`, i.e. `dt ≲ 10⁻⁴ / p ≈ 3 × 10⁻⁹` dimless — completely infeasible.

**Resolution**: transform to the co-rotating (Larmor) frame, where the fast Zeeman phase is absorbed into a unitary basis rotation. The residual dynamics happen on trap-timescale.

## Transformation

Define the Larmor unitary
```
U(t) = exp(+i p F_z t) = Diagonal(exp(+i p m t) for m = F, F-1, ..., -F)
```

The wavefunction transforms as `ψ_L = U(t) ψ_lab`. Under this transformation:

- `H_Zeeman^lab = -p F_z` → `H_Zeeman^L = 0` (the fast phase is gone).
- `H_kinetic` commutes with F_z → unchanged.
- Spin-conserving spatial potentials (trap, DDI-zz) → unchanged (they act on spatial coords, not spin).
- Spin-mixing interactions `c₁ F⁺ F⁻` → pick up factors of `exp(±i p t (Δm))`; however, spin-conserving terms (diagonal in F_z) still commute.
- Transverse Zeeman `bx F_x + by F_y` → becomes time-dep even if bx/by are constant in lab frame: `bx_L(t) = bx cos(p t) − by sin(p t)`, likewise by.
- Spin-raising / lowering tensor interactions (quadrupolar etc.) → pick up oscillating factors that **average out** over fast-rotation timescale if sampled at `dt > 1/p`. This is the core physical insight.

## Two implementation paths

### Path A: Full Larmor-frame solver (larger refactor, correct for generic F)

Modify `split_step.jl` to integrate in Larmor frame throughout:

1. **Initial condition**: transform ground-state `ψ_0 → U(0) ψ_0 = ψ_0` (U(0)=I trivial).
2. **At each substep**, replace every occurrence of `bx, by` (transverse Zeeman) with `bx_L(t), by_L(t)` computed from the lab-frame specs plus the current Larmor phase `p_ref · t`.
3. **For stir pattern `bx(t) = B_⊥ cos(Ω t), by(t) = B_⊥ sin(Ω t)`** in lab frame, the Larmor-transformed pattern is `bx_L(t) = B_⊥ cos((Ω − p_ref) t)`, `by_L(t) = B_⊥ sin((Ω − p_ref) t)`. When `Ω ≈ p_ref`, the transverse field becomes slowly varying (resonance).
4. **Observation**: compute `ψ_lab(t) = U†(t) ψ_L(t)` before any lab-frame observable (density is invariant, but magnetization has `exp(±i p t)` factors in the transverse components).
5. **Reference p_ref**: user-chosen, typically `p_ref = g_F μ_B Bz_lab / (ℏ ω_ref)` evaluated at the nominal static Bz. Stored as a workspace field.

**Effort**: ~200 lines in split_step + ~50 lines ground_state bootstrap + ~100 lines tests. Risk: tensor interactions for F>1 need careful tracking of phase factors on each (m, m') matrix element.

### Path B: Lab-frame solver with adaptive dt + no transverse Zeeman resonance exploration

Keep lab frame but use adaptive dt so that `p · dt < tol`. Works for steady-state / GS problems where we only need coarse-grained dynamics, but **fundamentally fails for stir experiments** — resonance phenomena require integrating through hundreds of Larmor cycles, which adaptive dt makes prohibitive.

**Verdict**: Path A is required for Klaus 2022 / any fast-stir experiment.

## Interface design

Add to `SimParams`:
```julia
struct SimParams
    ...
    larmor_frame_p::Float64    # dimensionless Larmor p (0 = lab frame, default)
end
```

YAML schema addition under `dynamics:`
```yaml
dynamics:
  duration: 1.0
  dt: 0.005
  larmor_frame:
    p_ref: "auto"      # derives from atom.g_F · μ_B · Bz / (ℏ ω_ref)
    # or p_ref: 28000  # explicit dimless
  zeeman:
    ...
```

"auto" resolves to the Level 1/2-derived p at the GS's static Bz.

## Scope for first implementation

Minimal viable:
- **F=8 Dy164 only** (skip general F tensor tracking)
- **Diagonal interactions only** (c₀·n²) — defer c₁ spin-mixing + tensor interactions to follow-up
- **Transverse Zeeman Bx/By/B_mag only** (the Klaus 2022 case) — skip exotic Raman coupling for now
- **CPU only** — GPU follows after correctness verified

This lets us reproduce Klaus 2022 vortex stripes without opening all cans of worms.

## Tests

1. Lab vs Larmor frame consistency on a **trivial case** (Bz only, no transverse) — Larmor frame should reproduce lab results exactly (modulo basis rotation) at long time.
2. Larmor frame with slow transverse drive (Ω ≪ p_ref) — should give same small-parameter response as lab frame with tiny dt.
3. Larmor frame at resonance (Ω = p_ref) — transverse field becomes DC, should drive Rabi-like oscillation on spin.
4. Larmor frame off-resonance (|Ω − p_ref| ≫ Rabi) — should leave spin nearly unchanged (rotating-wave approximation check).

## Follow-up: phase 2 stuff deferred

- Tensor interactions in Larmor frame (c_extra_4, c_extra_6 for Eu151)
- Raman coupling in Larmor frame (already counter-rotating in lab)
- GPU path

## Open questions

- Should the diagonal Zeeman **q-term** (quadratic) also be absorbed? q-term acts as `q · m²` — not a uniform phase, so cannot be absorbed by a single U(t). Typically q is small (hyperfine + 2nd-order Zeeman); we leave it as-is in Larmor frame (still integrated with lab-frame dt, which is safe because q · dt ≪ 1 for realistic q).
- Ground state itself: does ITP in Larmor frame converge to the same GS? Answer: yes, because U(t)=I at t=0 and during ITP (imaginary time is separate from real time). GS is computed in lab frame as before.
