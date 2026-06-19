# scripts/flower_protocol_edh/b_sweep_all.jl
# ============================================
# Two-phase B-sweep over the chosen grid.
#
#   Phase 1 (ITP coarse):    fresh ITP from m=-F init for every B.
#                            Goal = consistent rough GS for ALL points
#                            before any one gets polished hard.
#                            Skip if existing cache already at |grad| ≤ 5e-2.
#
#   Phase 2 (LBFGS polish):  aggressive LBFGS on every B point, picking up
#                            from Phase 1 result. Goal = tight |grad| ≤ 5e-4.
#                            Floor-detection (windowed range ratio) moves on
#                            when oscillation indicates numerical floor.
#                            Skip if cache already at target.
#
# Cache file: `lbfgs_<B>uG_final_psi.jld2` (single file per B, refined
# in place — Phase 2 overwrites Phase 1 with tighter ψ).
#
# Progress bars printed after every chunk so `tail -f` of the qsub log
# shows live "Phase 1: 12/25 | current B=64 μG chunk 4/10 |grad|=1.2e-2".

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates, Printf
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
                 find_ground_state_lbfgs, CUDABackend, CPUBackend

const F = 6
const D = 2F + 1
const NX = 64
const L_BOX = 18.0

# B grid (μG). Sparse in low-B, dense around the DDI vs Zeeman crossover.
const B_LIST = [-10, 0, 10, 20, 30, 40,
                50, 52, 54, 55, 56, 58, 60, 62, 64, 65, 66, 68, 70,
                80, 90, 100, 120, 150, 200]

# Skip thresholds.
const PHASE1_SKIP_GN   = 5.0e-2   # if cache |grad| ≤ this, Phase 1 already done
const PHASE2_TARGET_GN = 5.0e-4   # Phase 2 target

# Phase 1 (ITP) configuration.
const ITP_DT          = 0.01
const ITP_CHUNK_STEPS = 5_000
const ITP_TOTAL_STEPS = 30_000
const ITP_CHUNKS      = ITP_TOTAL_STEPS ÷ ITP_CHUNK_STEPS

# Phase 2 (LBFGS) configuration.
const LBFGS_TOL           = 5.0e-4
const LBFGS_M             = 20
const LBFGS_SOBOLEV_ALPHA = 0.5
const LBFGS_CHUNK_STEPS   = 100
const LBFGS_MAX_CHUNKS    = 30           # cap: 3000 iters per point
const FLOOR_WINDOW        = 6
const FLOOR_RATIO         = 1.5

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
cache_path(B_uG::Int) = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_final_psi.jld2")
const PROGRESS_PATH = joinpath(OUT_DIR, "b_sweep_all_progress.json")

# --------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------

logprint(args...) = (println(args...); flush(stdout))

function progress_bar(done::Int, total::Int; width::Int=24)
    filled = total == 0 ? 0 : round(Int, done * width / total)
    return "[" * ("█" ^ filled) * ("░" ^ (width - filled)) * "]"
end

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

function write_progress(phase::AbstractString, B_uG::Int, chunk::Int,
                        total_iter::Int, E::Float64, grad_norm::Float64,
                        wall_s::Float64, p1_done::Int, p2_done::Int,
                        n_points::Int, status::AbstractString)
    open(PROGRESS_PATH, "w") do io
        write(io, "{\n")
        write(io, "  \"phase\": \"$phase\",\n")
        write(io, "  \"B_uG\": $B_uG,\n")
        write(io, "  \"chunk\": $chunk,\n")
        write(io, "  \"total_iter\": $total_iter,\n")
        write(io, @sprintf("  \"E\": %.10g,\n", E))
        write(io, @sprintf("  \"grad_norm\": %.6e,\n", grad_norm))
        write(io, @sprintf("  \"wall_seconds\": %.2f,\n", wall_s))
        write(io, "  \"phase1_done\": $p1_done,\n")
        write(io, "  \"phase2_done\": $p2_done,\n")
        write(io, "  \"n_points\": $n_points,\n")
        write(io, "  \"status\": \"$status\",\n")
        write(io, "  \"timestamp\": \"$(string(now()))\"\n")
        write(io, "}\n")
    end
end

function persist_cache(path, psi, E, grad_norm, total_iter, B_uG, preset,
                       method, converged, wall, git_sha)
    jldopen(path, "w") do f
        f["psi"]              = psi
        f["E"]                = E
        f["grad_norm"]        = grad_norm
        f["lbfgs_iter_total"] = total_iter
        f["lbfgs_tol"]        = LBFGS_TOL
        f["lbfgs_m"]          = LBFGS_M
        f["sobolev_alpha"]    = LBFGS_SOBOLEV_ALPHA
        f["B_gauss"]          = B_uG * 1e-6
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
        f["method"]           = method
    end
end

# --------------------------------------------------------------------
# Phase 1: ITP coarse pass
# --------------------------------------------------------------------

function phase1_itp!(preset, backend, B_uG::Int, target_path::AbstractString;
                     git_sha::AbstractString, p1_done::Int, p2_done::Int, n_pts::Int)
    B_target_g = B_uG * 1e-6
    p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
    zeeman_t = ZeemanParams(p_target, 0.0)
    psi_cur = nothing  # nothing → first chunk uses :m_minus_F init
    E = NaN
    t_start = time()

    for ichunk in 1:ITP_CHUNKS
        gs = if psi_cur === nothing
            find_ground_state(;
                grid=preset.grid, atom=preset.atom,
                interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
                dt=ITP_DT, n_steps=ITP_CHUNK_STEPS,
                tol=0.0, tol_drho=0.0, save_every=ITP_CHUNK_STEPS,
                initial_state=:m_minus_F,
                enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
                backend=backend, verbose=false,
            )
        else
            find_ground_state(;
                grid=preset.grid, atom=preset.atom,
                interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
                dt=ITP_DT, n_steps=ITP_CHUNK_STEPS,
                tol=0.0, tol_drho=0.0, save_every=ITP_CHUNK_STEPS,
                psi_init=psi_cur,
                enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
                backend=backend, verbose=false,
            )
        end
        psi_cur = Array{ComplexF64}(gs.workspace.state.psi)
        E = gs.energy
        total_step = ichunk * ITP_CHUNK_STEPS
        wall = time() - t_start
        # Persist ψ. ITP doesn't expose a usable grad_norm, but writing NaN
        # made downstream readers (status grid, etc.) choke on `min(NaN, …)`.
        # Use Inf as a sentinel: "exists, but precision unmeasured / very loose".
        persist_cache(target_path, psi_cur, E, Inf, total_step, B_uG, preset,
                      "phase1-ITP ($(ITP_TOTAL_STEPS) steps, dt=$(ITP_DT))",
                      false, wall, git_sha)
        write_progress("phase1", B_uG, ichunk, total_step, E, NaN, wall,
                       p1_done, p2_done, n_pts, "running")
        bar_total = progress_bar(p1_done, n_pts)
        logprint(@sprintf("  Phase1 %s %d/%d | B=%4d μG ITP %2d/%2d step=%5d E=%+.6f wall=%.1fs",
                          bar_total, p1_done, n_pts, B_uG, ichunk, ITP_CHUNKS,
                          total_step, E, wall))
    end
    return (psi=psi_cur, E=E, wall=time() - t_start)
end

# --------------------------------------------------------------------
# Phase 2: LBFGS polish
# --------------------------------------------------------------------

function phase2_lbfgs!(preset, backend, B_uG::Int, target_path::AbstractString;
                       git_sha::AbstractString, p1_done::Int, p2_done::Int, n_pts::Int)
    B_target_g = B_uG * 1e-6
    p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
    zeeman_t = ZeemanParams(p_target, 0.0)

    psi_cur = jldopen(target_path, "r") do f; f["psi"]; end
    psi_cur = Array{ComplexF64}(psi_cur)
    grad_norm = Inf
    E = NaN
    total_iter = 0
    grad_window = Float64[]
    converged = false
    floor_detected = false
    t_start = time()

    for chunk in 1:LBFGS_MAX_CHUNKS
        gs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
            psi_init=psi_cur,
            n_steps=LBFGS_CHUNK_STEPS, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=false,
        )
        psi_cur = Array{ComplexF64}(gs.workspace.state.psi)
        grad_norm = gs.grad_norm
        E = gs.energy
        total_iter += LBFGS_CHUNK_STEPS
        wall = time() - t_start
        push!(grad_window, grad_norm)
        if length(grad_window) > FLOOR_WINDOW
            popfirst!(grad_window)
        end
        converged = grad_norm ≤ LBFGS_TOL

        persist_cache(target_path, psi_cur, E, grad_norm, total_iter, B_uG, preset,
                      "phase2-LBFGS chunked (cap=$(LBFGS_CHUNK_STEPS*LBFGS_MAX_CHUNKS), tol=$LBFGS_TOL, m=$LBFGS_M, α=$LBFGS_SOBOLEV_ALPHA)",
                      converged, wall, git_sha)

        ratio = if length(grad_window) == FLOOR_WINDOW
            maximum(grad_window) / max(minimum(grad_window), 1e-30)
        else
            NaN
        end
        if !isnan(ratio) && ratio < FLOOR_RATIO
            floor_detected = true
        end

        write_progress("phase2", B_uG, chunk, total_iter, E, grad_norm, wall,
                       p1_done, p2_done, n_pts,
                       converged ? "converged" : (floor_detected ? "floor" : "running"))
        bar_total = progress_bar(p2_done, n_pts)
        flag = converged ? "✓" : (floor_detected ? "△" : " ")
        logprint(@sprintf("  Phase2 %s %d/%d | B=%4d μG LBFGS %2d/%2d iter=%5d E=%+.8f |∇|=%.3e win=%s wall=%.1fs %s",
                          bar_total, p2_done, n_pts, B_uG, chunk, LBFGS_MAX_CHUNKS,
                          total_iter, E, grad_norm,
                          isnan(ratio) ? "—" : @sprintf("%.2f", ratio),
                          wall, flag))
        if converged || floor_detected
            break
        end
    end
    return (psi=psi_cur, E=E, grad_norm=grad_norm, total_iter=total_iter,
            converged=converged, floor=floor_detected, wall=time()-t_start)
end

# --------------------------------------------------------------------
# main
# --------------------------------------------------------------------

function main()
    mkpath(OUT_DIR)
    preset = eu151_preset(
        n_atoms=50_000,
        n_pts=(NX, NX, NX), box=(L_BOX, L_BOX, L_BOX),
        trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504,
    )
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    git_sha = try; strip(read(`git -C $(@__DIR__)/../.. rev-parse HEAD`, String)); catch; "unknown"; end
    n_pts = length(B_LIST)
    logprint("[b_sweep_all] backend=$backend  c_dd=$(round(preset.c_dd; sigdigits=4))")
    logprint("[b_sweep_all] grid ($n_pts pts): $B_LIST")
    logprint("[b_sweep_all] Phase 1 ITP: dt=$ITP_DT, steps=$ITP_TOTAL_STEPS, skip if cache |grad|≤$PHASE1_SKIP_GN")
    logprint("[b_sweep_all] Phase 2 LBFGS: chunk=$LBFGS_CHUNK_STEPS, cap=$(LBFGS_CHUNK_STEPS*LBFGS_MAX_CHUNKS), tol=$LBFGS_TOL, target |grad|≤$PHASE2_TARGET_GN")

    # ====== PHASE 1: ITP for all B ======
    p1_done_initial = count(b -> cache_grad_norm(cache_path(b)) ≤ PHASE1_SKIP_GN, B_LIST)
    logprint("\n[b_sweep_all] === PHASE 1 (ITP) === ($(p1_done_initial)/$n_pts already past Phase 1 quality)")
    p1_done = p1_done_initial
    for B_t in B_LIST
        path_t = cache_path(B_t)
        existing_gn = cache_grad_norm(path_t)
        if existing_gn ≤ PHASE1_SKIP_GN
            logprint("  Phase1 $(progress_bar(p1_done, n_pts)) | B=$(B_t)μG SKIP (cache |∇|=$(round(existing_gn; sigdigits=3)) already past Phase 1)")
            continue
        end
        result = phase1_itp!(preset, backend, B_t, path_t;
                             git_sha=git_sha, p1_done=p1_done, p2_done=0, n_pts=n_pts)
        p1_done += 1
        logprint(@sprintf("  Phase1 %s %d/%d | B=%4d μG ITP done E=%+.6f wall=%.1fs",
                          progress_bar(p1_done, n_pts), p1_done, n_pts, B_t,
                          result.E, result.wall))
    end
    logprint("[b_sweep_all] PHASE 1 complete: $(p1_done)/$n_pts done")

    # ====== PHASE 2: LBFGS polish for all B ======
    p2_done_initial = count(b -> cache_grad_norm(cache_path(b)) ≤ PHASE2_TARGET_GN, B_LIST)
    logprint("\n[b_sweep_all] === PHASE 2 (LBFGS polish) === ($(p2_done_initial)/$n_pts already at target)")
    p2_done = p2_done_initial
    for B_t in B_LIST
        path_t = cache_path(B_t)
        existing_gn = cache_grad_norm(path_t)
        if existing_gn ≤ PHASE2_TARGET_GN
            logprint("  Phase2 $(progress_bar(p2_done, n_pts)) | B=$(B_t)μG SKIP (cache |∇|=$(round(existing_gn; sigdigits=3)) already at target)")
            continue
        end
        if !isfile(path_t)
            logprint("  Phase2 | B=$(B_t)μG SKIP (no Phase 1 cache — failed earlier?)")
            continue
        end
        result = phase2_lbfgs!(preset, backend, B_t, path_t;
                               git_sha=git_sha, p1_done=p1_done,
                               p2_done=p2_done, n_pts=n_pts)
        if result.converged
            p2_done += 1
        end
        marker = result.converged ? "✓" : (result.floor ? "△ floor" : "△ cap")
        logprint(@sprintf("  Phase2 %s %d/%d | B=%4d μG LBFGS done E=%+.6f |∇|=%.3e iter=%d wall=%.1fs %s",
                          progress_bar(p2_done, n_pts), p2_done, n_pts, B_t,
                          result.E, result.grad_norm, result.total_iter, result.wall, marker))
    end
    logprint("[b_sweep_all] PHASE 2 complete: $(p2_done)/$n_pts converged")
    logprint("[b_sweep_all] === ALL DONE ===")
end

main()
