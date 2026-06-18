# scripts/flower_protocol_edh/b_sweep_polish.jl
# ================================================
# Polish pass — runs in parallel with the primary `b_sweep_lbfgs_tight.jl`.
#
# Goal: push already-converged-enough caches *further* toward the true GS
# using a more aggressive LBFGS configuration (more memory, tighter tol,
# bigger iter cap). Reads `lbfgs_<B>uG_final_psi.jld2`, writes a SEPARATE
# `lbfgs_<B>uG_polish_psi.jld2` so it cannot conflict with the primary job
# (no shared writes).
#
# Compared to b_sweep_lbfgs_tight.jl this script:
#  - Uses m_lbfgs = 30 (vs 15) — larger quasi-Newton history near minimum
#  - tol = 5e-5 (vs 5e-4) — push 10× harder against the LBFGS floor
#  - CHUNK_STEPS = 200 (vs 100) — fewer file writes per iter, less overhead
#  - MAX_CHUNKS = 50 → 10000 iter cap
#  - Skip-if-improved-by-less-than EPS: if a chunk fails to reduce |∇| by
#    > EPS, declare "floor reached" and move on. Avoids 70 μG-style burn.
#
# Resume-friendly: if `<B>_polish_psi.jld2` already exists and its
# grad_norm ≤ POLISH_TARGET, skip.

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates, Printf
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state_lbfgs,
                 CUDABackend, CPUBackend

const F = 6
const D = 2F + 1
const NX = 64
const L_BOX = 18.0

# B points to polish — must already have a `lbfgs_<B>uG_final_psi.jld2`
# input. We list everything that the primary job might produce + the
# pre-existing caches; the script will skip those with no input.
const POLISH_B = [-10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 52, 54,
                  55, 56, 58, 60, 62, 64, 65, 66, 68, 70, 80, 90, 100, 120,
                  150, 200]

const LBFGS_TOL           = 5.0e-5
const LBFGS_M             = 30
const LBFGS_SOBOLEV_ALPHA = 0.5
const CHUNK_STEPS         = 200
const MAX_CHUNKS_PER_POINT = 50            # cap: 10000 iters / point
const POLISH_TARGET       = 7.5e-5         # skip if already below this
const FLOOR_DETECT_EPS    = 1.0e-6         # chunk-to-chunk grad_norm improvement floor

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
input_cache(B_uG::Int)  = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_final_psi.jld2")
output_cache(B_uG::Int) = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_polish_psi.jld2")
const PROGRESS_PATH     = joinpath(OUT_DIR, "b_sweep_polish_progress.json")

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

logprint(args...) = (println(args...); flush(stdout))

function polish_point!(preset, backend, B_uG::Int, seed_psi, target_path::AbstractString;
                       git_sha::AbstractString, input_grad_norm::Float64)
    B_target_g = B_uG * 1e-6
    p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
    zeeman_t = ZeemanParams(p_target, 0.0)

    psi_cur = seed_psi
    grad_norm = input_grad_norm
    grad_prev = Inf
    E = NaN
    total_iter = 0
    floor_hits = 0
    converged = false
    t_start = time()

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
        improvement = grad_prev - grad_norm
        grad_prev = grad_norm
        converged = grad_norm ≤ LBFGS_TOL

        # Persist every chunk
        jldopen(target_path, "w") do f
            f["psi"]              = psi_cur
            f["E"]                = E
            f["grad_norm"]        = grad_norm
            f["lbfgs_iter_total"] = total_iter
            f["lbfgs_tol"]        = LBFGS_TOL
            f["lbfgs_m"]          = LBFGS_M
            f["sobolev_alpha"]    = LBFGS_SOBOLEV_ALPHA
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
            f["floor_hits"]       = floor_hits
            f["method"]           = "polish-LBFGS (chunk=$CHUNK_STEPS, cap=$(CHUNK_STEPS*MAX_CHUNKS_PER_POINT), tol=$LBFGS_TOL, m=$LBFGS_M, α=$LBFGS_SOBOLEV_ALPHA)"
        end
        write_progress(B_uG, chunk, total_iter, E, grad_norm, wall,
                       converged ? "converged" : "running")
        logprint(@sprintf("  [polish B=%4d μG] chunk %2d/%2d  iter=%5d  E=%+.8f  |∇|=%.4e  Δ|∇|=%+.2e  wall=%6.1fs  %s",
                          B_uG, chunk, MAX_CHUNKS_PER_POINT, total_iter, E, grad_norm,
                          improvement, wall,
                          converged ? "✓ converged" : ""))
        if converged
            break
        end
        # Floor detection: stop if chunks improve by less than EPS for 3 in a row
        if abs(improvement) < FLOOR_DETECT_EPS
            floor_hits += 1
            if floor_hits ≥ 3
                logprint("  [polish B=$(B_uG) μG] floor detected (Δ|∇| < $FLOOR_DETECT_EPS for $floor_hits chunks) — stop")
                break
            end
        else
            floor_hits = 0
        end
    end
    return (E=E, grad_norm=grad_norm, total_iter=total_iter, converged=converged,
            wall=time()-t_start, floor_hits=floor_hits)
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

    logprint("[polish] backend=$backend  c_dd=$(round(preset.c_dd; sigdigits=4))")
    logprint("[polish] tol=$LBFGS_TOL  chunk=$CHUNK_STEPS  cap=$(CHUNK_STEPS*MAX_CHUNKS_PER_POINT)  m=$LBFGS_M  α=$LBFGS_SOBOLEV_ALPHA")
    logprint("[polish] progress file: $PROGRESS_PATH")

    n_done = 0; n_skipped = 0; n_no_input = 0

    for B_t in POLISH_B
        path_in = input_cache(B_t)
        path_out = output_cache(B_t)

        if !isfile(path_in)
            logprint("[polish] B=$(B_t)μG no input cache (yet) — skip")
            n_no_input += 1
            continue
        end

        in_gn = cache_grad_norm(path_in)
        out_gn = isfile(path_out) ? cache_grad_norm(path_out) : Inf
        # If polish already at target, skip
        if out_gn ≤ POLISH_TARGET
            logprint("[polish] B=$(B_t)μG polish cache already at |grad|=$(round(out_gn; sigdigits=3)) ≤ $POLISH_TARGET — skip")
            n_skipped += 1
            continue
        end

        # Start from the better of input/polish ψ
        if isfile(path_out) && out_gn < in_gn
            logprint("[polish] B=$(B_t)μG continue from prior polish (|grad|=$(round(out_gn; sigdigits=3)))")
            psi_in = jldopen(path_out, "r") do f; f["psi"]; end
            start_gn = out_gn
        else
            logprint("[polish] B=$(B_t)μG start from primary cache (|grad|=$(round(in_gn; sigdigits=3)))")
            psi_in = jldopen(path_in, "r") do f; f["psi"]; end
            start_gn = in_gn
        end

        result = polish_point!(preset, backend, B_t, psi_in, path_out;
                               git_sha=git_sha, input_grad_norm=start_gn)
        marker = result.converged ? "✓" : "△"
        logprint("  $marker  polish B=$(B_t)μG done.  E=$(result.E)  |∇|=$(round(result.grad_norm; sigdigits=4))  iter=$(result.total_iter)  wall=$(round(result.wall; digits=1))s")
        n_done += 1
    end

    logprint("[polish] summary: $n_done polished, $n_skipped already-good, $n_no_input no-input")
end

main()
