# scripts/archive/

Klaus-era thesis-figure generators and Option γ correctness validators.
Not part of the live workflow, but kept here (rather than deleted) because
they may be revived once the corrected TSUBAME re-runs of
`runs/phi_omega_scan/` and `runs/klaus_baseline/` complete.

| File | Purpose | Revival trigger |
|---|---|---|
| `thesis_figures_klaus.jl` | Extract 修論 Fig 2-7 from a Klaus-magnetostir run's `result.jld2` | When a fresh Klaus run lands |
| `thesis_4run_comparison.jl` | Overlay the 4-corner DDI×stir matrix (full / no_ddi / no_stir / baseline) | After `run_mechanism_comparison.jl` produces all 4 runs |
| `run_mechanism_comparison.jl` | Driver for the 4-corner mechanism map (修論 Fig 7) | When mechanism analysis is needed again |
| `run_klaus_option_gamma.jl` | Klaus 2022 reproduction under rotating-basis Option γ | When validating against `phi_omega_scan` results |
| `validate_phase_ii_overlap.jl` | Adiabatic-limit: scalar eGPE density ≡ Option γ Σ_m \|ψ̃_m\|² | If Option γ infrastructure is changed |
| `validate_phase_iii_lab_vs_gamma.jl` | Lab-frame ≡ Option γ via ψ_lab = Û_B(t) ψ̃ at trap-scale dt | If Option γ infrastructure is changed |

If a script no longer makes sense after a future re-run (e.g. config
schema diverged too far), delete it rather than try to fix it — these
are reproductions, not load-bearing code.
