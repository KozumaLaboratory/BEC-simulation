# scripts/flower_protocol_edh/itp_rtp_60uG.jl
# ===========================================
# ITP (B=60 μG) → save final ψ → RTP (B=60 μG, 50 ms hold)
# Per RTP snapshot: orthogonal xy/xz slices + Goto tilted column densities
# at θ_q ∈ {-16°, 0°, +16°} + scalar (E, norm, Fz) for diagnostics.
#
# Output: /<root>/rtp_60uG.h5

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
                 find_ground_state_lbfgs,
                 CUDABackend, CPUBackend, make_workspace, run_simulation!,
                 SimulationCallbacks, total_energy, total_norm, SimParams,
                 magnetization, rotate_quantization_axis, SpinSystem

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0
const DX = L_BOX / NX

# ITP — strict convergence on BOTH energy and density.
# With c1/DDI Stage-3 bias fix (PR #18, 2026-06-15), the variational fixed
# point matches LBFGS exactly, so tight tolerances should now actually trip.
const ITP_N_STEPS = 100_000        # cap; expected to converge well before this
const ITP_DT      = 0.005
const ITP_TOL_DE  = 1.0e-10        # dE/|E| (relative energy change per save_every)
const ITP_TOL_DRHO = 1.0e-7        # max|Δρ|/max|ρ| (density change, gauge-invariant)

# LBFGS polish — driven to (near-)variational convergence.
# Sobolev preconditioner is the key to taming stiff spinor+DDI GP: without
# it, vanilla LBFGS crawls because the Hessian condition number explodes
# in the high-k spinor sectors. α=0.5 typically buys 10–100× iter speedup.
# tol=1e-7 is a realistic target on F=6/64³ (float64 floor ≈ 1e-9).
const LBFGS_N_STEPS = 500          # iterations PER RUN (additive when cache exists)
const LBFGS_TOL     = 1.0e-7       # ‖∇E‖ / dV target
const LBFGS_M       = 10           # quasi-Newton memory depth
const LBFGS_SOBOLEV_ALPHA = 0.5    # 0 = vanilla, >0 = Sobolev preconditioner
# Set LBFGS_CONTINUE=true to ADD `LBFGS_N_STEPS` more iterations starting
# from the cached ψ instead of reusing the cache as-is. Useful for
# incremental polish without losing previous work.
const LBFGS_CONTINUE = true

# RTP (constant B = 60 μG hold)
const RTP_DURATION = 13.823    # internal time ≈ 20 ms @ ω_ref = 2π·110
const RTP_DT       = 0.001     # 5× tighter than before — Strang O(dt²) → ~25× less drift
const RTP_SAVE_EVERY = 250     # ~55 frames (same physical resolution as dt=0.005, save_every=50)

const B_GAUSS  = 6.0e-5        # 60 μG
const THETA_Q_DEG = (-16.0, 0.0, +16.0)

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
const OUT     = joinpath(OUT_DIR, "rtp_60uG_dt0p001.h5")
const PSI_INIT_CACHE = joinpath(OUT_DIR, "itp_60uG_final_psi.jld2")

# Spin matrices
function spin_matrices_F6()
    Fz = zeros(ComplexF64, D, D); Fp = zeros(ComplexF64, D, D)
    for c in 1:D
        m = M_VALS[c]
        Fz[c, c] = m
        if c < D
            mn = M_VALS[c+1]
            Fp[c, c+1] = sqrt(F*(F+1) - mn*(mn+1))
        end
    end
    Fm = Fp'
    (Fp + Fm) / 2, (Fp - Fm) / (2im), Fz
end
const FX, FY, FZ = spin_matrices_F6()

# Slice extractors (host ψ in)
function extract_slices(psi)
    nx, ny, nz, _ = size(psi)
    z_mid = nz ÷ 2 + 1
    y_mid = ny ÷ 2 + 1
    n_xy  = zeros(Float32, D, nx, ny)
    n_xz  = zeros(Float32, D, nx, nz)
    Fx_xy = zeros(Float32, nx, ny); Fy_xy = zeros(Float32, nx, ny); Fz_xy = zeros(Float32, nx, ny)
    Fx_xz = zeros(Float32, nx, nz); Fy_xz = zeros(Float32, nx, nz); Fz_xz = zeros(Float32, nx, nz)
    arg_xy = zeros(Float32, nx, ny)
    arg_xz = zeros(Float32, nx, nz)
    @inbounds for c in 1:D, j in 1:ny, i in 1:nx
        n_xy[c, i, j] = Float32(abs2(psi[i, j, z_mid, c]))
    end
    @inbounds for c in 1:D, k in 1:nz, i in 1:nx
        n_xz[c, i, k] = Float32(abs2(psi[i, y_mid, k, c]))
    end
    @inbounds for j in 1:ny, i in 1:nx
        ψ = @view psi[i, j, z_mid, :]
        Fx_xy[i, j] = Float32(real(ψ' * (FX * ψ)))
        Fy_xy[i, j] = Float32(real(ψ' * (FY * ψ)))
        Fz_xy[i, j] = Float32(real(ψ' * (FZ * ψ)))
        arg_xy[i, j] = Float32(angle(psi[i, j, z_mid, D]))
    end
    @inbounds for k in 1:nz, i in 1:nx
        ψ = @view psi[i, y_mid, k, :]
        Fx_xz[i, k] = Float32(real(ψ' * (FX * ψ)))
        Fy_xz[i, k] = Float32(real(ψ' * (FY * ψ)))
        Fz_xz[i, k] = Float32(real(ψ' * (FZ * ψ)))
        arg_xz[i, k] = Float32(angle(psi[i, y_mid, k, D]))
    end
    (; n_xy, n_xz, Fx_xy, Fy_xy, Fz_xy, Fx_xz, Fy_xz, Fz_xz, arg_xy, arg_xz)
end

"Goto tilted column-density: y-integrated |ψ_{m=-F}|² after rotating
 the quantization axis by θ around y."
function tilted_yint(psi)
    nx, ny, nz, _ = size(psi)
    out = zeros(Float32, length(THETA_Q_DEG), nz, nx)
    @inbounds for (ti, td) in enumerate(THETA_Q_DEG)
        psi_rot = rotate_quantization_axis(psi, F, -deg2rad(td), 0.0, 0.0)
        for k in 1:nz, i in 1:nx
            s = 0.0
            for j in 1:ny
                s += abs2(psi_rot[i, j, k, D])
            end
            out[ti, k, i] = Float32(s)
        end
    end
    out
end

# Scalar Fz expectation (per atom)
function scalar_Fz(psi)
    nx, ny, nz, _ = size(psi)
    N = 0.0; Fze = 0.0
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        s = 0.0
        for c in 1:D
            s += abs2(psi[i,j,k,c])
        end
        N += s * DX^3
    end
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        ψ = @view psi[i,j,k,:]
        Fze += real(ψ' * (FZ * ψ)) * DX^3
    end
    Fze / N
end

mutable struct RTPBuf
    t::Vector{Float64}
    E::Vector{Float64}
    N::Vector{Float64}
    Mz::Vector{Float64}
    Fz::Vector{Float64}
    n_xy::Vector{Array{Float32,3}}
    n_xz::Vector{Array{Float32,3}}
    Fx_xy::Vector{Matrix{Float32}}; Fy_xy::Vector{Matrix{Float32}}; Fz_xy::Vector{Matrix{Float32}}
    Fx_xz::Vector{Matrix{Float32}}; Fy_xz::Vector{Matrix{Float32}}; Fz_xz::Vector{Matrix{Float32}}
    arg_xy::Vector{Matrix{Float32}}; arg_xz::Vector{Matrix{Float32}}
    tilt::Vector{Array{Float32,3}}     # (Nθ, NZ, NX)
end
RTPBuf() = RTPBuf(Float64[], Float64[], Float64[], Float64[], Float64[],
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Array{Float32,3}}())

function record!(buf::RTPBuf, ws)
    psi = Array{ComplexF64}(ws.state.psi)
    sl = extract_slices(psi)
    tl = tilted_yint(psi)
    push!(buf.t, ws.state.t)
    push!(buf.E, total_energy(ws))
    push!(buf.N, total_norm(ws.state.psi, ws.grid))
    push!(buf.Mz, magnetization(ws.state.psi, ws.grid, ws.spin_matrices.system))
    push!(buf.Fz, scalar_Fz(psi))
    push!(buf.n_xy,  sl.n_xy);  push!(buf.n_xz,  sl.n_xz)
    push!(buf.Fx_xy, sl.Fx_xy); push!(buf.Fy_xy, sl.Fy_xy); push!(buf.Fz_xy, sl.Fz_xy)
    push!(buf.Fx_xz, sl.Fx_xz); push!(buf.Fy_xz, sl.Fy_xz); push!(buf.Fz_xz, sl.Fz_xz)
    push!(buf.arg_xy, sl.arg_xy); push!(buf.arg_xz, sl.arg_xz)
    push!(buf.tilt, tl)
    println("  RTP snap t=$(round(ws.state.t; digits=3))  E=$(round(buf.E[end]; sigdigits=8))  N=$(round(buf.N[end]; sigdigits=8))  Fz=$(round(buf.Fz[end]; sigdigits=4))")
    flush(stdout)
end

function main()
    mkpath(OUT_DIR)
    preset = eu151_preset(
        n_atoms=50_000,
        n_pts=(NX, NX, NX),
        box=(L_BOX, L_BOX, L_BOX),
        trap_ratios=(1.0, 1.0, 1.181818),
        omega_ref=691.1504,
    )
    p = Units.bfield_to_p(B_GAUSS, preset.atom.g_F, preset.omega_ref)
    zeeman = ZeemanParams(p, 0.0)
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    println("[itp_rtp_60uG] backend=$backend  p=$(round(p; sigdigits=4))  c_dd=$(round(preset.c_dd; sigdigits=4))")
    println("[itp_rtp_60uG] B=$B_GAUSS G   ITP $(ITP_N_STEPS) steps dt=$(ITP_DT)   RTP $(RTP_DURATION) (≈50ms) dt=$(RTP_DT)")

    # --- ITP (skip if cache exists; cache is content-equivalent across runs
    #     with the same ITP params) ---
    psi_init_rtp = nothing
    if isfile(PSI_INIT_CACHE)
        println("[itp_rtp_60uG] reusing cached ITP ψ → $PSI_INIT_CACHE")
        psi_init_rtp = jldopen(PSI_INIT_CACHE, "r") do f; f["psi"]; end
        println("  loaded ψ size=$(size(psi_init_rtp))")
    else
        println("[itp_rtp_60uG] ITP start ...")
        gs = find_ground_state(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman, potential=preset.potential,
            dt=ITP_DT, n_steps=ITP_N_STEPS, tol=ITP_TOL_DE, tol_drho=ITP_TOL_DRHO,
            save_every=500,  # frequent enough to trip strict gates promptly
            initial_state=:m_plus_F,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        println("[itp_rtp_60uG] ITP done.  E=$(gs.energy)  last_step=$(gs.last_step)")
        psi_init_rtp = Array{ComplexF64}(gs.workspace.state.psi)
        try
            jldopen(PSI_INIT_CACHE, "w") do f
                f["psi"] = psi_init_rtp
            end
            println("  cached ITP-final ψ → $PSI_INIT_CACHE")
        catch e
            @warn "could not cache ITP ψ: $e"
        end
    end

    # --- LBFGS polish — drives ψ from ITP-near-GS to the true variational
    #     minimum via direct minimisation of the GP energy functional.
    #     Cache behavior:
    #       LBFGS_CONTINUE=true  + cache exists  → load + run more iterations
    #       LBFGS_CONTINUE=false + cache exists  → load + skip LBFGS
    #       cache absent                         → fresh run
    # ---
    LBFGS_CACHE = joinpath(OUT_DIR, "lbfgs_60uG_final_psi.jld2")
    cache_present = isfile(LBFGS_CACHE)

    seed_psi, prev_meta = if cache_present
        println("[itp_rtp_60uG] LBFGS cache present → $LBFGS_CACHE")
        jldopen(LBFGS_CACHE, "r") do f
            psi = f["psi"]
            meta = Dict{String,Any}()
            for k in keys(f); meta[k] = f[k]; end
            (psi, meta)
        end
    else
        (psi_init_rtp, Dict{String,Any}())
    end

    run_lbfgs = !cache_present || LBFGS_CONTINUE

    psi_init_rtp_lbfgs = if run_lbfgs
        action = cache_present ? "CONTINUE (+$(LBFGS_N_STEPS) iter)" : "FRESH ($(LBFGS_N_STEPS) iter)"
        println("[itp_rtp_60uG] LBFGS polish $action — tol=$LBFGS_TOL  m=$LBFGS_M  α=$LBFGS_SOBOLEV_ALPHA")
        gs_lbfgs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman, potential=preset.potential,
            psi_init=seed_psi,
            n_steps=LBFGS_N_STEPS, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        println("[itp_rtp_60uG] LBFGS done.  E=$(gs_lbfgs.energy)  grad_norm=$(gs_lbfgs.grad_norm)")
        psi_lbfgs_host = Array{ComplexF64}(gs_lbfgs.workspace.state.psi)

        # Accumulated iter count across resumes (provenance).
        prev_iter = Int(get(prev_meta, "lbfgs_iter_total", 0))
        total_iter = prev_iter + LBFGS_N_STEPS

        git_sha = try
            strip(read(`git -C $(@__DIR__)/../.. rev-parse HEAD`, String))
        catch
            "unknown"
        end

        try
            jldopen(LBFGS_CACHE, "w") do f
                f["psi"]               = psi_lbfgs_host
                f["E"]                 = gs_lbfgs.energy
                f["grad_norm"]         = gs_lbfgs.grad_norm
                f["lbfgs_iter_this"]   = LBFGS_N_STEPS
                f["lbfgs_iter_total"]  = total_iter
                f["lbfgs_tol"]         = LBFGS_TOL
                f["lbfgs_m"]           = LBFGS_M
                f["sobolev_alpha"]     = LBFGS_SOBOLEV_ALPHA
                f["n_atoms"]           = 50_000
                f["B_gauss"]           = B_GAUSS
                f["c_dd"]              = preset.c_dd
                f["grid_n"]            = collect(NX for _ in 1:3)
                f["grid_box"]          = collect(L_BOX for _ in 1:3)
                f["atom"]              = "Eu151"
                f["F"]                 = F
                f["secular_ddi"]       = false
                f["git_sha"]           = git_sha
                f["created_utc"]       = string(now())
                f["method"]            = "ITP 100k → LBFGS $(total_iter) (Sobolev α=$(LBFGS_SOBOLEV_ALPHA))"
            end
            println("  cached LBFGS ψ + metadata → $LBFGS_CACHE  (total iter=$total_iter)")
        catch e
            @warn "could not cache LBFGS ψ: $e"
        end
        psi_lbfgs_host
    else
        prev_E = get(prev_meta, "E", NaN)
        prev_g = get(prev_meta, "grad_norm", NaN)
        println("[itp_rtp_60uG] reusing cached LBFGS ψ (E=$prev_E  |∇|=$prev_g)")
        seed_psi
    end
    psi_init_rtp = psi_init_rtp_lbfgs

    # --- RTP: rebuild workspace with imaginary_time=false, seed with LBFGS-polished ψ ---
    println("[itp_rtp_60uG] RTP build ...")
    n_steps_rtp = round(Int, RTP_DURATION / RTP_DT)
    sp_rtp = SimParams(; dt=RTP_DT, n_steps=n_steps_rtp,
                       imaginary_time=false,
                       normalize_every=0,
                       save_every=RTP_SAVE_EVERY,
                       rotating_frame_omega=0.0)
    ws = make_workspace(;
        grid=preset.grid, atom=preset.atom,
        interactions=preset.interactions, zeeman=zeeman, potential=preset.potential,
        sim_params=sp_rtp,
        psi_init=psi_init_rtp,
        enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
        backend=backend,
    )

    buf = RTPBuf()
    callbacks = SimulationCallbacks(
        on_snapshot = (ws, step, snap) -> record!(buf, ws),
    )

    println("[itp_rtp_60uG] RTP run  n_steps=$(n_steps_rtp)  save_every=$(RTP_SAVE_EVERY)")
    run_simulation!(ws; callbacks=callbacks, stream_snapshots=true)
    println("[itp_rtp_60uG] RTP done.  $(length(buf.t)) snapshots")

    # --- Write h5 ---
    Nf = length(buf.t)
    n_xy_arr = zeros(Float32, Nf, D, NX, NX)
    n_xz_arr = zeros(Float32, Nf, D, NX, NX)
    Fx_arr = zeros(Float32, Nf, NX, NX); Fy_arr = zeros(Float32, Nf, NX, NX); Fz_arr = zeros(Float32, Nf, NX, NX)
    Fx_xz_arr = zeros(Float32, Nf, NX, NX); Fy_xz_arr = zeros(Float32, Nf, NX, NX); Fz_xz_arr = zeros(Float32, Nf, NX, NX)
    arg_arr = zeros(Float32, Nf, NX, NX);   arg_xz_arr = zeros(Float32, Nf, NX, NX)
    tilt_arr = zeros(Float32, Nf, length(THETA_Q_DEG), NX, NX)
    for k in 1:Nf
        n_xy_arr[k, :, :, :] .= buf.n_xy[k]
        n_xz_arr[k, :, :, :] .= buf.n_xz[k]
        Fx_arr[k, :, :]   .= buf.Fx_xy[k]; Fy_arr[k, :, :] .= buf.Fy_xy[k]; Fz_arr[k, :, :] .= buf.Fz_xy[k]
        Fx_xz_arr[k, :, :] .= buf.Fx_xz[k]; Fy_xz_arr[k, :, :] .= buf.Fy_xz[k]; Fz_xz_arr[k, :, :] .= buf.Fz_xz[k]
        arg_arr[k, :, :]    .= buf.arg_xy[k]
        arg_xz_arr[k, :, :] .= buf.arg_xz[k]
        tilt_arr[k, :, :, :] .= buf.tilt[k]
    end

    h5open(OUT, "w") do h5
        h5["meta/m_channels"]   = collect(M_VALS)
        h5["meta/F"]            = F
        h5["meta/L_box"]        = L_BOX
        h5["meta/NX"]           = NX
        h5["meta/B_gauss"]      = B_GAUSS
        h5["meta/theta_q_deg"]  = collect(THETA_Q_DEG)
        h5["meta/omega_ref"]    = preset.omega_ref
        h5["meta/rtp_duration"] = RTP_DURATION
        h5["meta/rtp_dt"]       = RTP_DT
        h5["t"]      = buf.t
        h5["E"]      = buf.E
        h5["N"]      = buf.N
        h5["Mz"]     = buf.Mz
        h5["Fz"]     = buf.Fz
        h5["n_m_xy"] = n_xy_arr
        h5["n_m_xz"] = n_xz_arr
        h5["Fx_xy"]  = Fx_arr;    h5["Fy_xy"] = Fy_arr;    h5["Fz_xy"] = Fz_arr
        h5["Fx_xz"]  = Fx_xz_arr; h5["Fy_xz"] = Fy_xz_arr; h5["Fz_xz"] = Fz_xz_arr
        h5["arg_psi_m6_xy"] = arg_arr
        h5["arg_psi_m6_xz"] = arg_xz_arr
        h5["n_m6_tilted"]   = tilt_arr
    end
    println("[itp_rtp_60uG] wrote $OUT")
end

main()
