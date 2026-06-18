# scripts/flower_protocol_edh/b_sweep_lbfgs_tight.jl
# ===================================================
# Extended + tightened LBFGS B-sweep, with OBSERVABLE PROGRESS.
#
# Differences vs `b_sweep_lbfgs.jl`:
#  - Grid extended upward to 200 μG (filling the gap between the existing
#    65 μG cache and the 10 mG RTP start).
#  - Fine 2 μG spacing in 50 – 70 μG, where the DDI vs Zeeman crossover
#    rearranges the polarized GS.
#  - Tighter convergence target: LBFGS_TOL = 1e-4 (the 1e-7 in the original
#    sweep was a numerical-optimisation default that none of the existing
#    caches actually reached; grad-norm 0.05 – 0.17 at 1000 iter).
#  - Resume-friendly: a cache is skipped if it already meets the new bar
#    (i.e. recorded grad_norm ≤ 1.5 × LBFGS_TOL_RETIGHTEN).
#  - Outputs the SAME `lbfgs_<B>uG_final_psi.jld2` naming so downstream
#    plots / RTP scripts pick up the new ψ transparently.
#
# **Monitoring**: LBFGS is run in CHUNK_STEPS-iteration chunks; after each
# chunk we (1) write the latest ψ + metadata to the cache file (mtime
# updates), (2) print a progress line and force-flush stdout. So an
# external observer can poll either `ls -lt lbfgs_*` or `tail -f log` and
# see updates every ~CHUNK_STEPS iterations (typically every minute or so
# on H100) instead of waiting for the whole point to finish silently.
# A `progress.json` file in OUT_DIR carries the same status in structured
# form for programmatic polling.

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates, Printf
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
                 find_ground_state_lbfgs, CUDABackend, CPUBackend

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0

# Chain warm-start order. Each entry: (B_target [μG], seed_B [μG]).
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
    (B_target=60,  seed=62),
    (B_target=58,  seed=60),
    (B_target=56,  seed=58),
    (B_target=54,  seed=56),
    (B_target=52,  seed=54),
    (B_target=50,  seed=52),
    # Below 50, retighten + add intermediate 5 μG step.
    (B_target=45,  seed=50),
    (B_target=40,  seed=45),
    (B_target=35,  seed=40),
    (B_target=30,  seed=35),
    (B_target=25,  seed=30),
    (B_target=20,  seed=25),
    (B_target=15,  seed=20),
    (B_target=10,  seed=15),
    (B_target=5,   seed=10),
    (B_target=0,   seed=5),
    (B_target=-5,  seed=0),
    (B_target=-10, seed=-5),
]

const LBFGS_TOL           = 5.0e-4
const LBFGS_M             = 15
const LBFGS_SOBOLEV_ALPHA = 0.5
const CHUNK_STEPS         = 100         # iters per LBFGS sub-call (= observable cadence)
const MAX_CHUNKS_PER_POINT = 25         # cap: 25 × 100 = 2500 iters per B point
const RETIGHTEN_BAR        = 7.5e-4     # skip cached file if its grad_norm ≤ this

# ITP preconditioning. For points with NO existing cache we run ITP from a
# polarized m=-F initial state to get a coarse but unbiased GS, then hand it
# to LBFGS for the precise polish. For retighten (cache present), we skip
# ITP and continue LBFGS from the cached ψ.
#
# Like LBFGS, ITP is also chunked so the user can watch progress: each
# ITP_CHUNK_STEPS we report E + drho and update progress.json. The first
# chunk pays JIT compile (~3-5 min on T4); subsequent chunks ~ITP_CHUNK_STEPS
# × dt actual.
const ITP_DT          = 0.01
const ITP_CHUNK_STEPS = 5_000
const ITP_TOTAL_STEPS = 30_000
const ITP_CHUNKS      = ITP_TOTAL_STEPS ÷ ITP_CHUNK_STEPS
const ITP_TOL_DE      = 1.0e-7
const ITP_TOL_DRHO    = 1.0e-5

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
cache_path(B_uG::Int) = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_final_psi.jld2")
const PROGRESS_PATH = joinpath(OUT_DIR, "b_sweep_tight_progress.json")

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

function write_progress(B_uG::Int, chunk::Int, total_iter::Int, E::Float64,
                        grad_norm::Float64, wall_s::Float64, status::AbstractString)
    open(PROGRESS_PATH, "w") do io
        write(io, "{\n")
        write(io, "  \"B_uG\": $B_uG,\n")
        write(io, "  \"chunk\": $chunk,\n")
        write(io, "  \"total_iter\": $total_iter,\n")
        write(io, @sprintf("  \"E\": %.10g,\n", E))
        write(io, @sprintf("  \"grad_norm\": %.6e,\n", grad_norm))
        write(io, @sprintf("  \"wall_seconds\": %.2f,\n", wall_s))
        write(io, "  \"status\": \"$status\",\n")
        write(io, "  \"timestamp\": \"$(string(now()))\"\n")
        write(io, "}\n")
    end
end

function logprint(args...)
    println(args...)
    flush(stdout)
end

function solve_point!(preset, backend, B_uG::Int, seed_psi, target_path::AbstractString;
                      git_sha::AbstractString, B_seed_uG::Int, do_itp::Bool=false)
    B_target_g = B_uG * 1e-6
    p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
    zeeman_t = ZeemanParams(p_target, 0.0)

    psi_cur = seed_psi
    total_iter = 0
    grad_norm = Inf
    E = NaN
    converged = false
    t_start = time()

    # --- Optional ITP precondition (rough → precise) for fresh points ---
    # Chunked so the user can watch ITP progress between LBFGS chunks.
    if do_itp
        logprint("  [B=$(B_uG) μG] ITP precondition from m=-F init ($(ITP_TOTAL_STEPS) steps, $(ITP_CHUNKS) chunks of $(ITP_CHUNK_STEPS))")
        itp_t0 = time()
        psi_itp = nothing  # nothing on first chunk → start from :m_minus_F
        for ichunk in 1:ITP_CHUNKS
            gs_chunk = if psi_itp === nothing
                find_ground_state(;
                    grid=preset.grid, atom=preset.atom,
                    interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
                    dt=ITP_DT, n_steps=ITP_CHUNK_STEPS,
                    tol=0.0, tol_drho=0.0,           # disable early exit
                    save_every=ITP_CHUNK_STEPS,
                    initial_state=:m_minus_F,
                    enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
                    backend=backend, verbose=false,
                )
            else
                find_ground_state(;
                    grid=preset.grid, atom=preset.atom,
                    interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
                    dt=ITP_DT, n_steps=ITP_CHUNK_STEPS,
                    tol=0.0, tol_drho=0.0,
                    save_every=ITP_CHUNK_STEPS,
                    psi_init=psi_itp,
                    enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
                    backend=backend, verbose=false,
                )
            end
            psi_itp = Array{ComplexF64}(gs_chunk.workspace.state.psi)
            step_total = ichunk * ITP_CHUNK_STEPS
            wall = time() - itp_t0
            logprint(@sprintf("  [B=%4d μG] ITP chunk %d/%d  step=%5d  E=%+.6f  wall=%.1fs",
                              B_uG, ichunk, ITP_CHUNKS, step_total, gs_chunk.energy, wall))
            write_progress(B_uG, ichunk, step_total, gs_chunk.energy, NaN, wall,
                           "itp_running")
        end
        psi_cur = psi_itp
        logprint(@sprintf("  [B=%4d μG] ITP done.  total_wall=%.1fs  → LBFGS polish", B_uG, time() - itp_t0))
    end

    for chunk in 1:MAX_CHUNKS_PER_POINT
        gs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
            psi_init=psi_cur,
            n_steps=CHUNK_STEPS, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=false,
        )
        psi_cur = Array{ComplexF64}(gs.workspace.state.psi)
        grad_norm = gs.grad_norm
        E = gs.energy
        total_iter += CHUNK_STEPS
        wall = time() - t_start
        converged = grad_norm ≤ LBFGS_TOL

        # Persist after every chunk so an external observer sees progress.
        jldopen(target_path, "w") do f
            f["psi"]              = psi_cur
            f["E"]                = E
            f["grad_norm"]        = grad_norm
            f["lbfgs_iter_total"] = total_iter
            f["lbfgs_tol"]        = LBFGS_TOL
            f["lbfgs_m"]          = LBFGS_M
            f["sobolev_alpha"]    = LBFGS_SOBOLEV_ALPHA
            f["seed_from_B_uG"]   = B_seed_uG
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
            f["chunk_steps"]      = CHUNK_STEPS
            f["method"]           = "LBFGS-tight chunked ($(CHUNK_STEPS)/chunk, cap=$(CHUNK_STEPS*MAX_CHUNKS_PER_POINT), tol=$LBFGS_TOL, m=$LBFGS_M, α=$LBFGS_SOBOLEV_ALPHA)"
        end
        write_progress(B_uG, chunk, total_iter, E, grad_norm, wall,
                       converged ? "converged" : "running")
        logprint(@sprintf("  [B=%4d μG] chunk %2d/%2d  iter=%5d  E=%+.6f  |∇|=%.4e  wall=%6.1fs  %s",
                          B_uG, chunk, MAX_CHUNKS_PER_POINT, total_iter, E, grad_norm, wall,
                          converged ? "✓ converged" : ""))
        if converged
            break
        end
    end

    return (E=E, grad_norm=grad_norm, total_iter=total_iter, converged=converged,
            wall=time() - t_start)
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

    logprint("[b_sweep_tight] backend=$backend  c_dd=$(round(preset.c_dd; sigdigits=4))")
    logprint("[b_sweep_tight] target tol=$LBFGS_TOL  chunk=$CHUNK_STEPS  cap=$(CHUNK_STEPS*MAX_CHUNKS_PER_POINT)  m=$LBFGS_M  α=$LBFGS_SOBOLEV_ALPHA")
    logprint("[b_sweep_tight] progress file: $PROGRESS_PATH")

    anchor_path = cache_path(65)
    isfile(anchor_path) || error("Anchor cache missing: $anchor_path (run original b_sweep_lbfgs.jl first to seed 65 μG)")

    n_done = 0; n_skipped = 0; n_failed = 0

    for step in B_SWEEP_PLAN
        B_t = step.B_target
        B_s = step.seed
        path_t = cache_path(B_t)
        path_s = cache_path(B_s)

        # skip-if-converged
        if isfile(path_t)
            cached_gn = cache_grad_norm(path_t)
            if cached_gn ≤ RETIGHTEN_BAR
                logprint("[b_sweep_tight] B=$(B_t)μG already converged (|grad|=$(round(cached_gn; sigdigits=3))) — skip")
                n_skipped += 1
                continue
            else
                logprint("[b_sweep_tight] B=$(B_t)μG cache present but loose (|grad|=$(round(cached_gn; sigdigits=3))) — retighten")
            end
        end

        if !isfile(path_s)
            @warn "Seed cache missing for B=$(B_s)μG (expected at $path_s); cannot start B=$(B_t)μG, skipping"
            n_failed += 1
            continue
        end

        # Fresh point (no cache) → ITP→LBFGS pipeline (rough then precise).
        # Retighten (cache exists) → continue LBFGS from cached ψ, skip ITP.
        is_fresh = !isfile(path_t)
        seed_psi = if is_fresh
            logprint("[b_sweep_tight] target B=$(B_t)μG  FRESH (ITP→LBFGS) — warm-start ψ from B=$(B_s)μG as fallback if ITP disabled")
            jldopen(path_s, "r") do f; f["psi"]; end
        else
            logprint("[b_sweep_tight] target B=$(B_t)μG  RETIGHTEN — continue LBFGS from cached ψ")
            jldopen(path_t, "r") do f; f["psi"]; end
        end

        result = solve_point!(preset, backend, B_t, seed_psi, path_t;
                              git_sha=git_sha, B_seed_uG=B_s, do_itp=is_fresh)
        marker = result.converged ? "✓" : "△"
        logprint("  $marker  B=$(B_t)μG done.  E=$(result.E)  |∇|=$(round(result.grad_norm; sigdigits=4))  iter=$(result.total_iter)  wall=$(round(result.wall; digits=1))s")
        n_done += 1
    end

    logprint("[b_sweep_tight] summary: $n_done done, $n_skipped skipped, $n_failed failed-seed")
end

main()
