# F=6 mean-field phase boundary scan in (g_10, g_12)

**Status**: scan complete 2026-05-07. Full data at `runs/F6_phase_diagram/result.json` (321 KB), reproduced via `scripts/phase_diagram/F6_phase_diagram_2D.jl`.

## Setup

Mean-field interaction energy density at unit density:

ε_MF(ζ; g_S) = (1/2) Σ_S g_S σ_S(ζ),     σ_S(ζ) = Σ_M | ⟨S, M | ζ ⊗ ζ⟩ |²

Four candidate spinors compared at every grid point of a 50×50 mesh in (g_10, g_12) ∈ [0.5, 1.5]² with g_0 = g_2 = g_4 = g_6 = g_8 = 1.0:

| Phase | Spinor (component order m=+F..−F) |
|---|---|
| polar | ζ = e_0 |
| FM | ζ = e_{+F} |
| cyclic | ζ = (e_{+F} + e^{i 2π/3} e_0 + e^{i 4π/3} e_{−F}) / √3 |
| I_h | (0, √7/5, 0, ..., 0, √11/5, 0, ..., 0, −√7/5, 0) (= `ZETA_F6_IH`) |

## Result

Coarse 10×10 sub-grid (full 50×50 lives in the JSON):

```
        0.50  0.60  0.70  0.81  0.91  1.01  1.11  1.21  1.32  1.42
0.50    F    F    F    I    I    I    I    I    I    I
0.60    F    F    F    F    I    I    I    I    I    I
0.70    F    F    F    F    I    I    I    I    I    I
0.81    F    F    F    F    F    I    I    I    I    I
0.91    F    F    F    F    F    I    I    I    I    I
1.01    F    F    F    F    F    C    I    I    I    I
1.11    F    F    F    F    F    F    C    C    I    I
1.21    F    F    F    F    F    F    C    C    C    C
1.32    F    F    F    F    F    F    C    C    C    C
1.42    F    F    F    F    F    F    C    C    C    C
```

P=polar, F=FM, C=cyclic, I=I_h. Rows: g_10, columns: g_12.

Polar does not win anywhere on this slice. The other three phases each take a distinct region:

* **FM** (left half): low g_10 favours the m=+F state; the FM state is insensitive to g_10 / g_12 because its single non-zero pair channel is S = 2F = 12, so its MF energy depends linearly only on g_12.
* **I_h** (top-right): high g_10 / g_12 region.
* **cyclic** (narrow middle band): a strip ~5 grid points wide between FM and I_h around (g_10 ≈ 1, g_12 ≈ 1).

## Linearised boundaries vs numerical scan

Parallel-session formulas (linearised around g_S = 1, all six even-S channels):

* I_h vs polar (δg_2 = δg_4 = δg_6 = δg_8 = 0 in this 2D slice): +(20433/96577) δg_10 + (−56/391) δg_12 = 0 → boundary slope δg_12 = +1.477 · δg_10
* I_h vs FM: +(147/391) δg_10 + (−4701/5681) δg_12 = 0 → boundary slope δg_12 = +0.454 · δg_10

The numerical FM↔I_h boundary in the diagram tracks ~+0.5 slope, consistent with the linearised +0.454 within the discretisation resolution.

The numerical I_h↔cyclic strip is curved (the cyclic state is not captured by the linearised I_h-vs-polar / I_h-vs-FM expansions — cyclic has its own boundary equation that the parallel session has not yet provided in the same closed form). A small but real region exists around the scalar limit where cyclic is the MF ground state.

## Eu reference (g_S ≡ 1)

All four candidate spinors share ε_MF = 1/2 exactly at the scalar point. This is the σ_S sum rule (Σ_S σ_S(ζ) = ⟨ζ⊗ζ|ζ⊗ζ⟩ = 1 for any normalised ζ), confirming the parallel-session observation that the phase boundaries are degenerate at first order and only split when the channel-specific g_S deviate from uniformity. The Eu point sits on the I_h / FM / cyclic triple-junction at this approximation; which phase actually wins requires either (a) Feshbach engineering of g_S away from uniform, or (b) including DDI / LHY corrections that lift the degeneracy at second order.

## Reproduction

```bash
julia --project=. scripts/phase_diagram/F6_phase_diagram_2D.jl
```

Output: text summary + `runs/F6_phase_diagram/result.json` containing `g_10_range`, `g_12_range`, `energies` (per-phase 50×50 matrix), `winner` (50×50 string matrix), and the linearised boundary coefficient dictionaries. Drop the JSON into any plotting tool.

## See also

* `src/hamiltonian/interactions/icosahedral_lhy.jl` — `ZETA_F6_IH` spinor + `compute_c0_lambda_F6_Ih` stiffness coefficients used here.
* `docs/theory/icosahedral_lhy.md` (pending) — full theory write-up.
