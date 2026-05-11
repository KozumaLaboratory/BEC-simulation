# Two-component (binary) Gross-Pitaevskii — design note

Status: **scaffold / deferred** (Phase 4.7, Scenario #51).

The full two-component coupled GP solver is multi-session work (~500 lines across types, propagators, energy, solvers, YAML). This note pins down the interface and key decisions so the next session can pick up cleanly.

## Physics target

Two distinguishable spinor condensates A and B:

```
i ∂_t ψ_A = (-½∇² + V_A + g_AA |ψ_A|² + g_AB |ψ_B|² + …) ψ_A
i ∂_t ψ_B = (-½∇² + V_B + g_BB |ψ_B|² + g_AB |ψ_A|² + …) ψ_B
```

with optional inter-species coherent coupling Ω · ψ_B and spin-spin contact (a_AB^F per F) for spinor-spinor mixtures.

Use cases:
- Cr-Sr immiscibility studies
- ⁸⁷Rb |F=1⟩ × |F=2⟩ Ramsey
- Boson-boson droplet (Petrov)
- Spinor + scalar contaminant

## Proposed layout

```
src/foundation/
    binary_state.jl        — BinaryState{N,A1,A2} mutable struct
    binary_workspace.jl    — BinaryWorkspace bundling two SpinSystems

src/hamiltonian/
    binary_split_step.jl   — interleaved A/B half-steps via shared FFT
    binary_interactions.jl — g_AA, g_AB, g_BB tensors

src/solvers/
    binary_ground_state.jl — ITP for both species (joint Mz constraints)
    binary_simulation.jl   — coupled RTP

src/workflow/experiments/
    binary_pipeline.jl     — YAML schema with `species_A:` / `species_B:`
```

YAML sketch:

```yaml
pipeline:
  - ground_state:
      kind: binary
      species_A: {atom: Rb87, F: 1, ...}
      species_B: {atom: Rb87, F: 2, ...}
      interactions:
        g_AA: 100.4 a0
        g_BB: 95.6 a0
        g_AB: 98.0 a0
        omega_coupling: 0.1   # optional Rabi
      grid: {n: [64, 64, 64], box: [20, 20, 20]}
      ...
```

## Risks

- `Workspace` parameter explosion (already 23 type params) — `BinaryWorkspace` must NOT inflate further. Keep two separate Workspaces and a thin `BinaryCouplings` struct.
- DDI cross-species term needs new kernel.
- Mass mismatch (Cr-Sr) breaks the dimensionless ω_ref assumption — need per-species scales, OR force common ω_ref and document.

## Recommendation for next session

Start with **non-spinor binary** (F=0 each) at uniform mass — closes 80% of use cases and avoids the worst type explosions. Then layer spinor + DDI on top.
