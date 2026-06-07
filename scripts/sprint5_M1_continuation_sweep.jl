#!/usr/bin/env julia
# scripts/sprint5_M1_continuation_sweep.jl
#
# Ω>0 Barnett map via CONTINUATION warm-start. The cold-start multistart
# sweep left 18/30 cells unconverged (‖∇E‖~1-4, the vortex-soft-mode
# conditioning floor); the Ω=0 column + the high-B/high-Ω corner DID
# converge. Per the forward note: warm-start each unconverged cell from
# a converged NEIGHBOUR (march Ω: 0 → 0.1 → 0.2 → 0.4 → 0.6 at fixed B,
# each step seeded by the previous Ω's result) — the conditioning floor
# is the "a converged neighbour gives a good initial guess" kind, so
# continuation is the cheap first move before rebuilding a preconditioner.
#
# Reuses `run_seed(B,Ω,seed; psi_warmstart=ψ)` from the multistart driver
# (skips ITP, LBFGS from the warm ψ, with stability check). Writes to a
# SEPARATE dir so the cold-start sweep is preserved; the gate-1/2/⟨L_z⟩
# audits then re-run over the union.
#
# HEAVY: ~20 min/cell on GPU (LBFGS n_steps=15000 + first-call JIT).
# ~18 cells ⇒ multi-hour. Background or TSUBAME (`docs/guides/tsubame.md`).
# Launch: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#           scripts/sprint5_M1_continuation_sweep.jl

import CUDA
include(joinpath(@__DIR__, "sprint5_M1_multistart_groundstate.jl"))  # run_seed, TW, consts
using JLD2
using Printf

const SRC_DIR = "runs/sprint5_M1_multistart_groundstate"
const CONT_DIR = "runs/sprint5_M1_continuation"

# the Ω=0 converged winner ψ per B is the chain seed; march up in Ω.
function continuation_chain(B_nT::Float64)
    mkpath(CONT_DIR)
    # seed: the converged Ω=0 cell's winner ψ
    base = JLD2.load(joinpath(SRC_DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B_nT)))
    ψ_prev = base["psi"]
    for Ω in OMEGAS[2:end]                      # 0.1, 0.2, 0.4, 0.6
        @info "continuation" B_nT Ω
        r = run_seed(B_nT, Ω, :continuation; psi_warmstart=ψ_prev)
        jldopen(joinpath(CONT_DIR, @sprintf("cell_B%.1f_Om%.2f.jld2", B_nT, Ω)), "w") do f
            f["psi"] = r.psi
            f["result"] = Dict(
                "B_nT" => B_nT, "omega" => Ω, "E" => r.E,
                "grad_norm" => r.grad_norm, "converged" => r.converged,
                "stability" => string(r.stability), "winner_seed" => "continuation",
            )
            f["all_candidates_summary"] = [("continuation", r.E, r.grad_norm, string(r.stability))]
            f["competing_candidates"] = Tuple{Any, Any, Any}[]
            f["anchor_step"] = false
        end
        @info "  done" Ω E = r.E grad_norm = r.grad_norm converged = r.converged
        # adiabatic: next Ω warm-starts from THIS converged result
        r.converged && (ψ_prev = r.psi)
        CUDA.reclaim()
    end
end

function main()
    for B in B_VALUES_NT
        continuation_chain(B)
    end
    @info "Continuation sweep complete." CONT_DIR
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
