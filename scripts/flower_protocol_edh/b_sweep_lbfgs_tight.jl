# scripts/flower_protocol_edh/b_sweep_lbfgs_tight.jl
# ===================================================
# Extended + tightened LBFGS B-sweep.
#
# Differences vs `b_sweep_lbfgs.jl`:
#  - Grid extended upward to 200 μG (filling the gap between the existing
#    65 μG cache and the 10 mG RTP start).
#  - Fine 2 μG spacing in 50 – 70 μG, where the DDI vs Zeeman crossover
#    rearranges the polarized GS.
#  - Tighter convergence target: LBFGS_TOL = 1e-4 (the 1e-7 in the original
#    sweep was a numerical-optimisation default that none of the existing
#    caches actually reached; grad-norm 0.05 – 0.17 at 1000 iter).
#  - Iteration cap 10000 (was 1000), LBFGS memory 15.
#  - Resume-friendly: a cache is skipped if it already meets the new bar
#    (i.e. recorded grad_norm ≤ 1.5 × LBFGS_TOL_RETIGHTEN).
#  - Outputs the SAME `lbfgs_<B>uG_final_psi.jld2` naming so downstream
#    plots / RTP scripts pick up the new ψ transparently.
#
# Cache target tol is recorded in metadata so subsequent runs can detect
# whether a file needs retightening.

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state_lbfgs,
                 CUDABackend, CPUBackend

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0

# Chain warm-start order. Each entry: (B_target [μG], seed_B [μG]).
# Seed must exist on disk (either from the original sweep or from a prior
# step of this script).
const B_SWEEP_PLAN = [
    # Upward from existing 65 μG anchor.
    (B_target=70,  seed=65),
    (B_target=80,  seed=70),
    (B_target=90,  seed=80),
    (B_target=100, seed=90),
    (B_target=120, seed=100),
    (B_target=150, seed=120),
    (B_target=200, seed=150),
    # Fine 2 μG step in 70 → 50, chained from 65 downward.
    (B_target=68,  seed=65),
    (B_target=66,  seed=68),
    (B_target=64,  seed=66),
    (B_target=62,  seed=64),
    (B_target=60,  seed=62),   # retighten (existing has |grad|=0.088)
    (B_target=58,  seed=60),
    (B_target=56,  seed=58),
    (B_target=54,  seed=56),
    (B_target=52,  seed=54),
    (B_target=50,  seed=52),   # retighten (existing has |grad|=0.125)
    # Below 50, retighten + add intermediate 5 μG step.
    (B_target=45,  seed=50),
    (B_target=40,  seed=45),   # retighten
    (B_target=35,  seed=40),
    (B_target=30,  seed=35),   # retighten
    (B_target=25,  seed=30),
    (B_target=20,  seed=25),   # retighten
    (B_target=15,  seed=20),
    (B_target=10,  seed=15),   # retighten
    (B_target=5,   seed=10),
    (B_target=0,   seed=5),    # retighten
    (B_target=-5,  seed=0),
    (B_target=-10, seed=-5),   # retighten
]

const LBFGS_N_STEPS       = 10_000
const LBFGS_TOL           = 1.0e-4
const LBFGS_M             = 15
const LBFGS_SOBOLEV_ALPHA = 0.5
# A cached ψ is reused (skip) only when this metadata bar is already met.
# Slightly looser than LBFGS_TOL so we don't churn on files that just barely
# converged.
const RETIGHTEN_BAR       = 1.5e-4

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
cache_path(B_uG::Int) = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_final_psi.jld2")

function cache_grad_norm(path::AbstractString)
    isfile(path) || return Inf
    try
        return jldopen(path, "r") do f
            haskey(f, "grad_norm") ? Float64(f["grad_norm"]) : Inf
        end
    catch
        return Inf
    end
end

function main()
    mkpath(OUT_DIR)
    preset = eu151_preset(
        n_atoms=50_000,
        n_pts=(NX, NX, NX), box=(L_BOX, L_BOX, L_BOX),
        trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504,
    )
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    git_sha = try; strip(read(`git -C $(@__DIR__)/../.. rev-parse HEAD`, String)); catch; "unknown"; end

    println("[b_sweep_tight] backend=$backend  c_dd=$(round(preset.c_dd; sigdigits=4))")
    println("[b_sweep_tight] target tol=$(LBFGS_TOL)  cap=$(LBFGS_N_STEPS)  m=$(LBFGS_M)  α=$(LBFGS_SOBOLEV_ALPHA)")

    anchor_path = cache_path(65)
    isfile(anchor_path) || error("Anchor cache missing: $anchor_path (run original b_sweep_lbfgs.jl first to seed 65 μG)")

    n_done = 0
    n_skipped = 0
    n_failed = 0

    for step in B_SWEEP_PLAN
        B_t = step.B_target
        B_s = step.seed
        path_t = cache_path(B_t)
        path_s = cache_path(B_s)

        # skip-if-converged
        if isfile(path_t)
            cached_gn = cache_grad_norm(path_t)
            if cached_gn ≤ RETIGHTEN_BAR
                println("[b_sweep_tight] B=$(B_t)μG already converged (|grad|=$(round(cached_gn; sigdigits=3))) — skip")
                n_skipped += 1
                continue
            else
                println("[b_sweep_tight] B=$(B_t)μG cache present but loose (|grad|=$(round(cached_gn; sigdigits=3))) — retighten")
            end
        end

        if !isfile(path_s)
            @warn "Seed cache missing for B=$(B_s)μG (expected at $path_s); cannot start B=$(B_t)μG, skipping"
            n_failed += 1
            continue
        end

        seed_psi = jldopen(path_s, "r") do f; f["psi"]; end
        # If retightening, prefer the existing-target ψ over the seed (already closer).
        if isfile(path_t)
            seed_psi = jldopen(path_t, "r") do f; f["psi"]; end
            println("[b_sweep_tight] target B=$(B_t)μG  ← warm-start from PRIOR cache at same B")
        else
            println("[b_sweep_tight] target B=$(B_t)μG  ← warm-start from B=$(B_s)μG")
        end

        B_target_g = B_t * 1e-6
        p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
        zeeman_t = ZeemanParams(p_target, 0.0)

        t_start = time()
        gs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
            psi_init=seed_psi,
            n_steps=LBFGS_N_STEPS, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        wall = time() - t_start
        psi_t = Array{ComplexF64}(gs.workspace.state.psi)
        converged = gs.grad_norm ≤ LBFGS_TOL
        marker = converged ? "✓" : "△"
        println("  $marker  E=$(gs.energy)  |∇|=$(round(gs.grad_norm; sigdigits=4))  wall=$(round(wall; digits=1))s")

        jldopen(path_t, "w") do f
            f["psi"]              = psi_t
            f["E"]                = gs.energy
            f["grad_norm"]        = gs.grad_norm
            f["lbfgs_iter_total"] = LBFGS_N_STEPS
            f["lbfgs_tol"]        = LBFGS_TOL
            f["lbfgs_m"]          = LBFGS_M
            f["sobolev_alpha"]    = LBFGS_SOBOLEV_ALPHA
            f["seed_from_B_uG"]   = B_s
            f["B_gauss"]          = B_target_g
            f["n_atoms"]          = 50_000
            f["c_dd"]             = preset.c_dd
            f["grid_n"]           = [NX, NX, NX]
            f["grid_box"]         = [L_BOX, L_BOX, L_BOX]
            f["atom"]             = "Eu151"
            f["F"]                = F
            f["secular_ddi"]      = false
            f["git_sha"]          = git_sha
            f["created_utc"]      = string(now())
            f["wall_seconds"]     = wall
            f["converged"]        = converged
            f["method"]           = "LBFGS-tight (cap=$LBFGS_N_STEPS, tol=$LBFGS_TOL, m=$LBFGS_M, α=$LBFGS_SOBOLEV_ALPHA)"
        end
        println("  cached → $path_t")
        n_done += 1
    end

    println("[b_sweep_tight] summary: $n_done done, $n_skipped skipped (already converged), $n_failed skipped (missing seed)")
end

main()
