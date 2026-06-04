#!/usr/bin/env julia
# scripts/sprint5_M1_extend.jl
#
# Warm-restart unconverged cells of the M1 rotating-frame sweep.
# Reads `cell_B{B}_Om{Ω}.jld2` files in OUT_DIR (produced by the main
# `sprint5_M1_ITP_omega_sweep_converged.jl` sweep), and for each cell
# whose LBFGS did NOT pass the gate, reloads psi and runs additional
# LBFGS iterations from that state. Overwrites the cell file in place
# and accumulates `n_lbfgs_steps_so_far` so successive runs can keep
# extending.
#
# Skips cells that are already converged (no work to do) AND cells
# that have no `psi` entry (legacy partial.jld2-only state; those
# would need to be redone from scratch).
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_M1_extend.jl
#
# Optionally set N_EXTEND on the command line:
#   julia --project=. scripts/sprint5_M1_extend.jl --n-extend 10000
#
# After this script: rerun the dashboard golden export
#   julia --project=. scripts/m1_sweep_golden_export.jl
# to refresh viewspec.json from the updated cell scalars (the script
# rewrites the partial.jld2 mirror so the dashboard sees the new
# results without further surgery).

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()  # 24³, N=5×10⁴
const DT_ITP = 0.005
const N_ITP_NOOP = 0           # warm-start: skip ITP entirely
const TOL_ITP = 1e-7
const TOL_LBFGS = 1e-5
const SOBOLEV = 0.05
const OUT_DIR = "runs/sprint5_M1_ITP_omega_sweep_converged"

# Parse `--n-extend N` from ARGS; default 10× the original LBFGS budget.
function parse_n_extend(args)
    for (i, a) in enumerate(args)
        if a == "--n-extend" && i + 1 <= length(args)
            return parse(Int, args[i + 1])
        end
    end
    return 10000
end
const N_EXTEND = parse_n_extend(ARGS)

cell_path(B_nT, Ω) = joinpath(OUT_DIR,
    @sprintf("cell_B%.1f_Om%.2f.jld2", B_nT, Ω))

# Reconstruct a workspace at the saved psi by going through
# `find_ground_state` with `n_steps=0` — this builds the workspace
# (zeeman, interactions, FFT plans, etc.) and assigns psi without
# advancing ITP. Cleaner than reimplementing the workspace assembly.
function make_warm_workspace(B_nT::Float64, Ω::Float64, psi_cached::Array)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
    )
    # initial_state value here is unused when psi_init is supplied,
    # but the keyword is required by find_ground_state's API.
    r_noop = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT_ITP, n_steps=N_ITP_NOOP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=Ω,
        backend=CUDABackend())
    return r_noop.workspace
end

function extend_cell!(cp::String, cached::Dict)
    result = cached["result"]
    B_nT = Float64(result["B_nT"])
    Ω = Float64(result["omega"])
    grad_norm_old = Float64(result["grad_norm"])
    conv_old = Bool(result["conv_lbfgs"])
    if conv_old && grad_norm_old < TOL_LBFGS
        @printf "skip B=%.1f Ω=%.2f — already converged (‖∇E‖=%.3e)\n" B_nT Ω grad_norm_old
        return false
    end
    if !haskey(cached, "psi")
        @printf "skip B=%.1f Ω=%.2f — no psi cached (legacy)\n" B_nT Ω
        return false
    end
    psi_cached = cached["psi"]
    n_so_far = get(cached, "n_lbfgs_steps_so_far", 0)

    @printf "extend B=%.1f Ω=%.2f — old ‖∇E‖=%.3e (after %d LBFGS), running +%d more\n" B_nT Ω grad_norm_old n_so_far N_EXTEND

    t0 = time()
    ws = make_warm_workspace(B_nT, Ω, psi_cached)
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=ws,
        n_steps=N_EXTEND, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )
    t_lbfgs = time() - t0

    ws_out = r_lbfgs.workspace
    psi_new = Array(ws_out.state.psi)
    sm = ws_out.spin_matrices
    fx, fy, fz = spin_density_vector(psi_new, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(TW.grid)
    fz_total = sum(fz) * dV
    fx_total = sum(fx) * dV
    fy_total = sum(fy) * dV
    m_dist = zeros(TW.D)
    for c in 1:(TW.D)
        m_dist[c] = sum(abs2, psi_new[:, :, :, c]) * dV
    end
    Lz = orbital_angular_momentum(psi_new, ws_out.grid, ws_out.fft_plans)
    CUDA.reclaim()

    grad_norm_new = r_lbfgs.grad_norm
    @printf "  → new ‖∇E‖=%.3e  conv=%s  Δ⟨F_z⟩=%+.4f  (%.1f min)\n" grad_norm_new r_lbfgs.converged (fz_total - Float64(result["fz_total"])) (t_lbfgs/60)

    # Safety guard: warm-restart loses the L-BFGS history (s_hist/y_hist
    # start empty), so the first iteration falls back to steepest-descent
    # in the Sobolev metric. In degenerate cells (e.g. B=0/Ω=0 where the
    # ground-state manifold is wide) this can overshoot and drive ‖∇E‖
    # *higher* than the warm-start state. Reject the result whenever the
    # gradient norm did not improve — keeps the cached cell intact.
    if grad_norm_new >= grad_norm_old && !r_lbfgs.converged
        @printf "  ⚠ regression detected (new ≥ old, conv=false) — NOT overwriting cell file\n"
        return false
    end

    # In-place update of the cell file. Preserve `all_attempts_summaries`
    # (those came from the original multistart and don't change here).
    result_new = Dict(
        "omega" => Ω, "B_nT" => B_nT,
        "seed" => result["seed"],
        "E" => r_lbfgs.energy,
        "E_itp" => result["E_itp"],
        "conv_lbfgs" => r_lbfgs.converged,
        "grad_norm" => grad_norm_new,
        "fx_total" => fx_total, "fy_total" => fy_total,
        "fz_total" => fz_total, "Lz" => Lz, "f_max" => f_max,
        "m_dist" => m_dist,
        "time_itp_min" => Float64(result["time_itp_min"]),
        # Add to running LBFGS-time accumulator.
        "time_lbfgs_min" =>
            Float64(result["time_lbfgs_min"]) + t_lbfgs / 60,
    )
    JLD2.jldopen(cp, "w") do f
        f["psi"] = psi_new
        f["result"] = result_new
        f["all_attempts_summaries"] =
            get(cached, "all_attempts_summaries", [])
        f["n_lbfgs_steps_so_far"] = n_so_far + N_EXTEND
        # Provenance trail so a later reader can see this cell has been
        # extended (and how many times).
        f["extend_history"] = vcat(
            get(cached, "extend_history", String[]),
            string("extended by ", N_EXTEND,
                " steps at ", repr(time()), ": ",
                "‖∇E‖ ", grad_norm_old, " → ", grad_norm_new))
    end
    return true
end

function rewrite_partial!(cell_files)
    # Refresh partial.jld2 (the scalar mirror the dashboard reads) from
    # the current set of cell files. This keeps `m1_sweep_golden_export`
    # in sync after `_extend` mutates cells.
    partial = Vector{Dict{String, Any}}()
    for cp in cell_files
        d = JLD2.load(cp)
        r = d["result"]
        push!(partial, Dict(
            "omega" => r["omega"], "B_nT" => r["B_nT"],
            "seed" => r["seed"], "E" => r["E"], "E_itp" => r["E_itp"],
            "conv_lbfgs" => r["conv_lbfgs"], "grad_norm" => r["grad_norm"],
            "fx_total" => r["fx_total"], "fy_total" => r["fy_total"],
            "fz_total" => r["fz_total"], "Lz" => r["Lz"],
            "f_max" => r["f_max"], "m_dist" => r["m_dist"],
            "time_itp_min" => r["time_itp_min"],
            "time_lbfgs_min" => r["time_lbfgs_min"]))
    end
    partial_path = joinpath(OUT_DIR, "partial.jld2")
    JLD2.jldopen(partial_path, "w") do f
        f["partial"] = partial
        f["icell"] = length(partial)
        f["n_total"] = length(partial)
    end
    @printf "wrote refreshed partial.jld2 (%d cells)\n" length(partial)
end

function main()
    isdir(OUT_DIR) || error("OUT_DIR missing: $OUT_DIR")
    @printf "=== M1 extend — warm-restart unconverged cells ===\n"
    @printf "N_EXTEND = %d additional LBFGS steps per cell\n" N_EXTEND
    @printf "Tol = %.0e, Sobolev α = %.3f\n\n" TOL_LBFGS SOBOLEV
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    cell_files = filter(f -> startswith(basename(f), "cell_B") &&
                              endswith(f, ".jld2"),
                        readdir(OUT_DIR; join=true))
    isempty(cell_files) && error(
        "no cell_B*.jld2 files in $OUT_DIR. Run the main sweep first " *
        "with the cache-enabled version of sprint5_M1_ITP_omega_sweep_converged.jl.")
    @printf "found %d cell files\n\n" length(cell_files)

    n_extended = 0
    for cp in sort(cell_files)
        cached = JLD2.load(cp)
        if extend_cell!(cp, cached)
            n_extended += 1
        end
        flush(stdout)
    end

    println()
    rewrite_partial!(cell_files)
    @printf "\nextended %d / %d cells\n" n_extended length(cell_files)
    println("\n=== Done ===")
    println("Next: julia --project=. scripts/m1_sweep_golden_export.jl")
end

main()
