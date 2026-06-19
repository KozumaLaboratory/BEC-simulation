# scripts/flower_protocol_edh/goto_protocol_10mG.jl
# =================================================
# ITP @ B=10 mG → LBFGS polish (3000+500=3500 iter Sobolev α=0.5) → RTP
# under Goto Ch.6 Flower protocol B(t) trajectory (Step 3 Phase 1+2 +
# Step 5 snap, 0 → 250 ms).
#
# Caches:
#   itp_10mG_final_psi.jld2     — ITP-converged ψ (reusable across reruns)
#   lbfgs_10mG_final_psi.jld2   — LBFGS-polished ψ + full metadata
#
# Output: rtp_10mG_goto.h5  (per-snapshot slices + tilted column densities)

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates
using SpinorBEC: Units, eu151_preset, ZeemanParams, TimeDependentZeeman,
                 PiecewiseLinearWaveform, ConstantWaveform,
                 find_ground_state, find_ground_state_lbfgs,
                 CUDABackend, CPUBackend, make_workspace, run_simulation!,
                 SimulationCallbacks, total_energy, total_norm, SimParams,
                 magnetization, rotate_quantization_axis, SpinSystem,
                 LossParams

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0
const DX = L_BOX / NX

# ITP @ B = 10 mG
const ITP_N_STEPS  = 100_000
const ITP_DT       = 0.005
const ITP_TOL_DE   = 1.0e-10
const ITP_TOL_DRHO = 1.0e-7

# LBFGS polish, Sobolev α=0.5; first run 3000, additive runs 500 (3500 total).
const LBFGS_INITIAL_STEPS = 3_000
const LBFGS_EXTRA_STEPS   = 500
const LBFGS_TOL           = 1.0e-7
const LBFGS_M             = 10
const LBFGS_SOBOLEV_ALPHA = 0.5

# RTP — Goto Ch.6 Flower protocol (units: internal time, B in Gauss)
#
# Trajectory mode is selectable via GOTO_MODE env var:
#   full_descend  Phase 1 (10 mG → 1 mG, 50 ms linear with smoothed junction)
#                 + Phase 2 (1 mG → 0 G, 267 ms parabola B(τ) = 1mG·(1-0.749τ)²
#                            τ ∈ [0, 1.335])
#                 + Phase 3 (B = 0 hold, 100 ms)
#                 Total ≈ 417 ms.  Output: rtp_10mG_goto.h5
#
#   hold_63ug     Phase 1 (10 mG → 1 mG, 50 ms with smoothed junction)
#                 + Phase 2 (1 mG → 63 μG, 200 ms parabola τ ∈ [0, 1])
#                 + Phase 3 (B = 63 μG hold, 167 ms — same total wall as full_descend
#                            so the two variants are directly comparable)
#                 Total ≈ 417 ms.  Output: rtp_10mG_goto_hold63ug.h5
#
# **Smoothed junction**: the Phase 1→2 corner at t = 50 ms had a 24× slope
# discontinuity in the old version (Phase 1 linear at -180 mG/s slamming into
# Phase 2 parabolic at -7.5 mG/s). This caused an abrupt dB/dt step that the
# atomic Larmor following would feel. Replace the last 10 ms of Phase 1
# (t ∈ [40, 50] ms) with a quadratic blend
#   B(t) = a·(t-50)² + b·(t-50) + 1 mG
# chosen so that B(40) = 2.8 mG matches the prior linear value AND
# dB/dt(50) = -7.49e-3 mG/ms matches Phase 2's tangent. C¹-continuous corner.
# PWL samples the blend at 2 ms cadence (t = 40, 42, 44, 46, 48, 50 ms).
const RTP_DT         = 0.005
const RTP_SAVE_EVERY = 250     # ~230 snapshots over the run

const GOTO_MODE = lowercase(get(ENV, "GOTO_MODE", "full_descend"))

# RTP-only three-body loss K_3 (SI units, m^6/s). Default 0 = K3 off
# (bit-identical to pre-Issue#26 behaviour). Matsui-aligned value ≈ 2.1e-40.
# Applied ONLY in Phase 3 RTP — K3 is non-Hermitian (loss.jl: "RT only").
# SI→dimless conversion follows parsing_blocks.jl:186-195:
#   a_ho = sqrt(ℏ / (m · ω_ref));  n0 = N / a_ho^3;  K3_dimless = K3_SI · n0² / ω_ref.
const K3_PER_M_SI = parse(Float64, get(ENV, "GOTO_K3_PER_M_SI", "0.0"))
const _K3_TAG = K3_PER_M_SI > 0 ? "_k3_$(string(K3_PER_M_SI))" : ""

# Internal-time conversion factor: ω_ref = 691.1504 rad/s, so 1 ms = 0.6911504 internal.
const _IT(ms) = ms * 0.6911504

# Phase 1 (smoothed last 10 ms): blend coefficients computed from
#   B(50) = 1 mG,  dB/dt(50) = -7.49e-3 mG/ms,  B(40) = 2.8 mG (Phase-1 linear value)
# →  b = -7.49e-3,  c = 1,  a = (2.8 - 1 - 0.0749) / 100 = 0.017251
const _BLEND_A = 0.017251
const _BLEND_B = -0.00749
const _BLEND_C = 1.0  # mG at t=50ms
_blend_mG(t_ms) = _BLEND_A * (t_ms - 50.0)^2 + _BLEND_B * (t_ms - 50.0) + _BLEND_C

# Common segments (in milliseconds → values in Gauss).
# Phase 1 linear (0 ≤ t ≤ 40 ms): 10 mG → 2.8 mG
# Phase 1 smoothed corner (40 ≤ t ≤ 50 ms): blend down to 1 mG
const _SEG_PHASE1 = let
    samples_ms = [0.0, 10.0, 20.0, 30.0, 40.0,
                  42.0, 44.0, 46.0, 48.0, 50.0]
    pairs = [(_IT(ms), ms ≤ 40.0 ?
                          (10.0 - (10.0 - 2.8) * ms / 40.0) * 1e-3 :  # linear part
                          _blend_mG(ms) * 1e-3                          # blend part
            ) for ms in samples_ms]
    pairs
end

# Phase 2 parabola: 1 mG · (1 − 0.749 τ)², τ = (t − 50)/200 in ms.
function _parabola_pairs(tau_endpoints)
    [(_IT(50.0 + 200.0 * τ), 1e-3 * (1.0 - 0.749 * τ)^2) for τ in tau_endpoints]
end

const GOTO_TIMES_G, GOTO_VALUES_G = if GOTO_MODE == "full_descend"
    # Phase 2 τ ∈ [0.125, 0.25, ..., 1.0, 1.125, 1.25, 1.335]  (12 samples)
    parabola = _parabola_pairs([0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875,
                                1.0, 1.125, 1.25, 1.335])
    # Phase 3: hold at 0 for 100 ms → t_end = 317 + 100 = 417 ms
    hold = [(_IT(417.0), 0.0)]
    all_pairs = vcat(_SEG_PHASE1, parabola, hold)
    (first.(all_pairs), last.(all_pairs))
elseif GOTO_MODE == "hold_63ug"
    # Phase 2 τ ∈ [0.125, ..., 1.0]  (truncate at parabola endpoint = 63 μG)
    parabola = _parabola_pairs([0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0])
    # Phase 3: hold at 63 μG for 167 ms → t_end = 250 + 167 = 417 ms
    hold = [(_IT(417.0), 63.0e-6)]
    all_pairs = vcat(_SEG_PHASE1, parabola, hold)
    (first.(all_pairs), last.(all_pairs))
else
    error("Unknown GOTO_MODE='$GOTO_MODE' (expected full_descend or hold_63ug)")
end
const RTP_DURATION = GOTO_TIMES_G[end]

const THETA_Q_DEG = (-16.0, 0.0, +16.0)
const VOL_STRIDE = 2
const VOL_IDXS = collect(1:VOL_STRIDE:NX)
const NVOL = length(VOL_IDXS)
const STORED_3D_M = (-6, -5, -4)
const STORED_3D_COMPONENTS = ntuple(i -> Int(F - STORED_3D_M[i] + 1), length(STORED_3D_M))

const _H5_NAME = (GOTO_MODE == "full_descend" ? "rtp_10mG_goto" : "rtp_10mG_goto_$(GOTO_MODE)") * _K3_TAG * ".h5"
const OUT_DIR        = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
const OUT            = joinpath(OUT_DIR, _H5_NAME)
const PSI_ITP_CACHE  = joinpath(OUT_DIR, "itp_10mG_final_psi.jld2")
const PSI_LBFGS_CACHE = joinpath(OUT_DIR, "lbfgs_10mG_final_psi.jld2")
const REUSE_LBFGS_ONLY = lowercase(get(ENV, "FPE_REUSE_LBFGS_ONLY", "false")) in ("1", "true", "yes")

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

function extract_3d_observables(psi)
    n_total = zeros(Float32, NVOL, NVOL, NVOL)
    n_m6    = zeros(Float32, NVOL, NVOL, NVOL)
    n_m5    = zeros(Float32, NVOL, NVOL, NVOL)
    n_m4    = zeros(Float32, NVOL, NVOL, NVOL)
    arg_m6  = zeros(Float32, NVOL, NVOL, NVOL)
    arg_m5  = zeros(Float32, NVOL, NVOL, NVOL)
    arg_m4  = zeros(Float32, NVOL, NVOL, NVOL)
    Fx_3d   = zeros(Float32, NVOL, NVOL, NVOL)
    Fy_3d   = zeros(Float32, NVOL, NVOL, NVOL)
    Fz_3d   = zeros(Float32, NVOL, NVOL, NVOL)

    @inbounds for (ii, i) in enumerate(VOL_IDXS), (jj, j) in enumerate(VOL_IDXS), (kk, k) in enumerate(VOL_IDXS)
        ψ = @view psi[i, j, k, :]
        s = 0.0
        fx = 0.0 + 0.0im
        fy = 0.0 + 0.0im
        fz = 0.0 + 0.0im
        for a in 1:D
            ψa = ψ[a]
            s += abs2(ψa)
            cψa = conj(ψa)
            for b in 1:D
                ψb = ψ[b]
                fx += cψa * FX[a, b] * ψb
                fy += cψa * FY[a, b] * ψb
                fz += cψa * FZ[a, b] * ψb
            end
        end
        n_total[ii, jj, kk] = Float32(s)
        n_m6[ii, jj, kk] = Float32(abs2(ψ[D]))
        n_m5[ii, jj, kk] = Float32(abs2(ψ[D - 1]))
        n_m4[ii, jj, kk] = Float32(abs2(ψ[D - 2]))
        arg_m6[ii, jj, kk] = Float32(angle(ψ[D]))
        arg_m5[ii, jj, kk] = Float32(angle(ψ[D - 1]))
        arg_m4[ii, jj, kk] = Float32(angle(ψ[D - 2]))
        Fx_3d[ii, jj, kk] = Float32(real(fx))
        Fy_3d[ii, jj, kk] = Float32(real(fy))
        Fz_3d[ii, jj, kk] = Float32(real(fz))
    end

    (; n_total, n_m6, n_m5, n_m4, arg_m6, arg_m5, arg_m4, Fx_3d, Fy_3d, Fz_3d)
end

function scalar_Fz(psi)
    nx, ny, nz, _ = size(psi)
    N = 0.0; Fze = 0.0
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        s = 0.0
        for c in 1:D; s += abs2(psi[i,j,k,c]); end
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
    B_gauss::Vector{Float64}   # B(t) at each snapshot
    n_xy::Vector{Array{Float32,3}}
    n_xz::Vector{Array{Float32,3}}
    Fx_xy::Vector{Matrix{Float32}}; Fy_xy::Vector{Matrix{Float32}}; Fz_xy::Vector{Matrix{Float32}}
    Fx_xz::Vector{Matrix{Float32}}; Fy_xz::Vector{Matrix{Float32}}; Fz_xz::Vector{Matrix{Float32}}
    arg_xy::Vector{Matrix{Float32}}; arg_xz::Vector{Matrix{Float32}}
    tilt::Vector{Array{Float32,3}}
    n_total_3d::Vector{Array{Float32,3}}
    n_m6_3d::Vector{Array{Float32,3}}
    n_m5_3d::Vector{Array{Float32,3}}
    n_m4_3d::Vector{Array{Float32,3}}
    arg_m6_3d::Vector{Array{Float32,3}}
    arg_m5_3d::Vector{Array{Float32,3}}
    arg_m4_3d::Vector{Array{Float32,3}}
    Fx_3d::Vector{Array{Float32,3}}
    Fy_3d::Vector{Array{Float32,3}}
    Fz_3d::Vector{Array{Float32,3}}
end
RTPBuf() = RTPBuf(Float64[], Float64[], Float64[], Float64[], Float64[], Float64[],
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Array{Float32,3}}(),
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Array{Float32,3}}())

function _b_at(t::Float64)
    # PWL interpolation on (GOTO_TIMES_G, GOTO_VALUES_G)
    if t <= GOTO_TIMES_G[1]; return GOTO_VALUES_G[1]; end
    if t >= GOTO_TIMES_G[end]; return GOTO_VALUES_G[end]; end
    for i in 1:length(GOTO_TIMES_G)-1
        if GOTO_TIMES_G[i] <= t <= GOTO_TIMES_G[i+1]
            a = (t - GOTO_TIMES_G[i]) / (GOTO_TIMES_G[i+1] - GOTO_TIMES_G[i])
            return GOTO_VALUES_G[i] * (1 - a) + GOTO_VALUES_G[i+1] * a
        end
    end
    return 0.0
end

function record!(buf::RTPBuf, ws)
    psi = Array{ComplexF64}(ws.state.psi)
    sl = extract_slices(psi)
    tl = tilted_yint(psi)
    vol = extract_3d_observables(psi)
    push!(buf.t, ws.state.t)
    push!(buf.E, total_energy(ws))
    push!(buf.N, total_norm(ws.state.psi, ws.grid))
    push!(buf.Mz, magnetization(ws.state.psi, ws.grid, ws.spin_matrices.system))
    push!(buf.Fz, scalar_Fz(psi))
    push!(buf.B_gauss, _b_at(ws.state.t))
    push!(buf.n_xy, sl.n_xy);  push!(buf.n_xz, sl.n_xz)
    push!(buf.Fx_xy, sl.Fx_xy); push!(buf.Fy_xy, sl.Fy_xy); push!(buf.Fz_xy, sl.Fz_xy)
    push!(buf.Fx_xz, sl.Fx_xz); push!(buf.Fy_xz, sl.Fy_xz); push!(buf.Fz_xz, sl.Fz_xz)
    push!(buf.arg_xy, sl.arg_xy); push!(buf.arg_xz, sl.arg_xz)
    push!(buf.tilt, tl)
    push!(buf.n_total_3d, vol.n_total)
    push!(buf.n_m6_3d, vol.n_m6)
    push!(buf.n_m5_3d, vol.n_m5)
    push!(buf.n_m4_3d, vol.n_m4)
    push!(buf.arg_m6_3d, vol.arg_m6)
    push!(buf.arg_m5_3d, vol.arg_m5)
    push!(buf.arg_m4_3d, vol.arg_m4)
    push!(buf.Fx_3d, vol.Fx_3d)
    push!(buf.Fy_3d, vol.Fy_3d)
    push!(buf.Fz_3d, vol.Fz_3d)
    println("  RTP snap t=$(round(ws.state.t; digits=3)) B=$(round(buf.B_gauss[end]*1e3; sigdigits=3))mG  E=$(round(buf.E[end]; sigdigits=8))  N=$(round(buf.N[end]; sigdigits=8))  Fz=$(round(buf.Fz[end]; sigdigits=4))")
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
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()

    B_INIT_GAUSS = GOTO_VALUES_G[1]   # 0.01 G = 10 mG
    p_init = Units.bfield_to_p(B_INIT_GAUSS, preset.atom.g_F, preset.omega_ref)
    zeeman_static = ZeemanParams(p_init, 0.0)

    println("[goto_10mG] backend=$backend")
    println("[goto_10mG] ITP @ B=$(B_INIT_GAUSS*1e3) mG  p=$(round(p_init; sigdigits=4))  c_dd=$(round(preset.c_dd; sigdigits=4))")
    println("[goto_10mG] LBFGS Sobolev α=$(LBFGS_SOBOLEV_ALPHA)")
    println("[goto_10mG] RTP Goto trajectory  duration=$(RTP_DURATION) internal (≈$(round(RTP_DURATION/preset.omega_ref*1000; digits=2)) ms)  dt=$(RTP_DT)")

    # --- Phase 1: ITP at B=10mG ---
    psi_after_itp = if isfile(PSI_ITP_CACHE)
        println("[goto_10mG] reusing cached ITP ψ → $PSI_ITP_CACHE")
        jldopen(PSI_ITP_CACHE, "r") do f; f["psi"]; end
    else
        println("[goto_10mG] ITP start ...")
        gs = find_ground_state(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_static, potential=preset.potential,
            dt=ITP_DT, n_steps=ITP_N_STEPS, tol=ITP_TOL_DE, tol_drho=ITP_TOL_DRHO,
            save_every=500,
            initial_state=:m_plus_F,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        println("[goto_10mG] ITP done.  E=$(gs.energy)  last_step=$(gs.last_step)")
        psi_host = Array{ComplexF64}(gs.workspace.state.psi)
        try
            jldopen(PSI_ITP_CACHE, "w") do f; f["psi"] = psi_host; end
            println("  cached ITP ψ → $PSI_ITP_CACHE")
        catch e; @warn "could not cache ITP ψ: $e"; end
        psi_host
    end

    # --- Phase 2: LBFGS polish (initial 3000, or +500 continuation) ---
    lbfgs_present = isfile(PSI_LBFGS_CACHE)
    seed_psi, prev_meta = lbfgs_present ? jldopen(PSI_LBFGS_CACHE, "r") do f
        m = Dict{String,Any}()
        for k in keys(f); m[k] = f[k]; end
        (f["psi"], m)
    end : (psi_after_itp, Dict{String,Any}())

    lbfgs_steps_this = if REUSE_LBFGS_ONLY
        0
    elseif lbfgs_present
        LBFGS_EXTRA_STEPS
    else
        LBFGS_INITIAL_STEPS
    end
    action = if REUSE_LBFGS_ONLY
        "REUSE CACHED ψ"
    elseif lbfgs_present
        "CONTINUE (+$LBFGS_EXTRA_STEPS)"
    else
        "FRESH ($LBFGS_INITIAL_STEPS)"
    end
    println("[goto_10mG] LBFGS polish $action  tol=$LBFGS_TOL  m=$LBFGS_M  α=$LBFGS_SOBOLEV_ALPHA")
    psi_lbfgs_host = Array{ComplexF64}(seed_psi)
    lbfgs_energy = Float64(get(prev_meta, "E", NaN))
    lbfgs_grad_norm = Float64(get(prev_meta, "grad_norm", NaN))
    prev_iter = Int(get(prev_meta, "lbfgs_iter_total", 0))
    total_iter = prev_iter
    if !REUSE_LBFGS_ONLY
        gs_lbfgs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_static, potential=preset.potential,
            psi_init=seed_psi,
            n_steps=lbfgs_steps_this, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        println("[goto_10mG] LBFGS done.  E=$(gs_lbfgs.energy)  grad_norm=$(gs_lbfgs.grad_norm)")
        psi_lbfgs_host = Array{ComplexF64}(gs_lbfgs.workspace.state.psi)
        lbfgs_energy = gs_lbfgs.energy
        lbfgs_grad_norm = gs_lbfgs.grad_norm
        total_iter = prev_iter + lbfgs_steps_this
    elseif !lbfgs_present
        error("FPE_REUSE_LBFGS_ONLY=true but no LBFGS cache found at $PSI_LBFGS_CACHE")
    else
        println("[goto_10mG] reusing cached LBFGS ψ without extra optimization")
    end
    git_sha = try; strip(read(`git -C $(@__DIR__)/../.. rev-parse HEAD`, String)); catch; "unknown"; end

    if !REUSE_LBFGS_ONLY
        try
            jldopen(PSI_LBFGS_CACHE, "w") do f
                f["psi"]              = psi_lbfgs_host
                f["E"]                = lbfgs_energy
                f["grad_norm"]        = lbfgs_grad_norm
                f["lbfgs_iter_this"]  = lbfgs_steps_this
                f["lbfgs_iter_total"] = total_iter
                f["lbfgs_tol"]        = LBFGS_TOL
                f["lbfgs_m"]          = LBFGS_M
                f["sobolev_alpha"]    = LBFGS_SOBOLEV_ALPHA
                f["n_atoms"]          = 50_000
                f["B_gauss"]          = B_INIT_GAUSS
                f["c_dd"]             = preset.c_dd
                f["grid_n"]           = [NX, NX, NX]
                f["grid_box"]         = [L_BOX, L_BOX, L_BOX]
                f["atom"]             = "Eu151"
                f["F"]                = F
                f["secular_ddi"]      = false
                f["git_sha"]          = git_sha
                f["created_utc"]      = string(now())
                f["method"]           = "ITP 100k → LBFGS $(total_iter) (Sobolev α=$(LBFGS_SOBOLEV_ALPHA)) @ B=10mG"
            end
            println("  cached LBFGS ψ + metadata → $PSI_LBFGS_CACHE  (total iter=$total_iter)")
        catch e; @warn "could not cache LBFGS ψ: $e"; end
    end

    # --- Phase 3: RTP with Goto B(t) trajectory ---
    println("[goto_10mG] RTP build  (TimeDependentZeeman PWL across $(length(GOTO_TIMES_G)) control pts)")
    p_values = [Units.bfield_to_p(B, preset.atom.g_F, preset.omega_ref) for B in GOTO_VALUES_G]
    p_wf = PiecewiseLinearWaveform(GOTO_TIMES_G, p_values)
    q_wf = ConstantWaveform(0.0)
    zeeman_rt = TimeDependentZeeman(p_wf, q_wf)

    # Three-body loss K_3 (RT-only). See header comment on K3_PER_M_SI.
    loss_rt = if K3_PER_M_SI > 0
        a_ho = sqrt(Units.HBAR / (preset.atom.mass * preset.omega_ref))
        n0   = 50_000.0 / a_ho^3
        k3_dimless = K3_PER_M_SI * n0^2 / preset.omega_ref
        println("[goto_10mG] K_3 = $(K3_PER_M_SI) m^6/s  →  dimless = $(round(k3_dimless; sigdigits=4))  (n0=$(round(n0; sigdigits=4)) m^-3)")
        LossParams(K3_per_m_cubic = fill(k3_dimless, D))
    else
        nothing
    end

    n_steps_rtp = round(Int, RTP_DURATION / RTP_DT)
    sp_rtp = SimParams(; dt=RTP_DT, n_steps=n_steps_rtp,
                       imaginary_time=false,
                       normalize_every=0,
                       save_every=RTP_SAVE_EVERY,
                       rotating_frame_omega=0.0)
    ws = make_workspace(;
        grid=preset.grid, atom=preset.atom,
        interactions=preset.interactions, zeeman=zeeman_rt, potential=preset.potential,
        sim_params=sp_rtp,
        psi_init=psi_lbfgs_host,
        enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
        loss=loss_rt,
        backend=backend,
    )

    buf = RTPBuf()
    callbacks = SimulationCallbacks(
        on_snapshot = (ws, step, snap) -> record!(buf, ws),
    )

    println("[goto_10mG] RTP run  n_steps=$n_steps_rtp  save_every=$RTP_SAVE_EVERY")
    run_simulation!(ws; callbacks=callbacks, stream_snapshots=true)
    println("[goto_10mG] RTP done.  $(length(buf.t)) snapshots")

    # --- Write h5 ---
    Nf = length(buf.t)
    n_xy_arr = zeros(Float32, Nf, D, NX, NX)
    n_xz_arr = zeros(Float32, Nf, D, NX, NX)
    Fx_arr = zeros(Float32, Nf, NX, NX); Fy_arr = zeros(Float32, Nf, NX, NX); Fz_arr = zeros(Float32, Nf, NX, NX)
    Fx_xz_arr = zeros(Float32, Nf, NX, NX); Fy_xz_arr = zeros(Float32, Nf, NX, NX); Fz_xz_arr = zeros(Float32, Nf, NX, NX)
    arg_arr = zeros(Float32, Nf, NX, NX);   arg_xz_arr = zeros(Float32, Nf, NX, NX)
    tilt_arr = zeros(Float32, Nf, length(THETA_Q_DEG), NX, NX)
    n_total_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    n_m6_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    n_m5_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    n_m4_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    arg_m6_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    arg_m5_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    arg_m4_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    Fx_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    Fy_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    Fz_3d_arr = zeros(Float32, Nf, NVOL, NVOL, NVOL)
    for k in 1:Nf
        n_xy_arr[k, :, :, :] .= buf.n_xy[k]
        n_xz_arr[k, :, :, :] .= buf.n_xz[k]
        Fx_arr[k, :, :]   .= buf.Fx_xy[k]; Fy_arr[k, :, :] .= buf.Fy_xy[k]; Fz_arr[k, :, :] .= buf.Fz_xy[k]
        Fx_xz_arr[k, :, :] .= buf.Fx_xz[k]; Fy_xz_arr[k, :, :] .= buf.Fy_xz[k]; Fz_xz_arr[k, :, :] .= buf.Fz_xz[k]
        arg_arr[k, :, :]    .= buf.arg_xy[k]
        arg_xz_arr[k, :, :] .= buf.arg_xz[k]
        tilt_arr[k, :, :, :] .= buf.tilt[k]
        n_total_3d_arr[k, :, :, :] .= buf.n_total_3d[k]
        n_m6_3d_arr[k, :, :, :] .= buf.n_m6_3d[k]
        n_m5_3d_arr[k, :, :, :] .= buf.n_m5_3d[k]
        n_m4_3d_arr[k, :, :, :] .= buf.n_m4_3d[k]
        arg_m6_3d_arr[k, :, :, :] .= buf.arg_m6_3d[k]
        arg_m5_3d_arr[k, :, :, :] .= buf.arg_m5_3d[k]
        arg_m4_3d_arr[k, :, :, :] .= buf.arg_m4_3d[k]
        Fx_3d_arr[k, :, :, :] .= buf.Fx_3d[k]
        Fy_3d_arr[k, :, :, :] .= buf.Fy_3d[k]
        Fz_3d_arr[k, :, :, :] .= buf.Fz_3d[k]
    end

    h5open(OUT, "w") do h5
        h5["meta/m_channels"]   = collect(M_VALS)
        h5["meta/F"]            = F
        h5["meta/L_box"]        = L_BOX
        h5["meta/NX"]           = NX
        h5["meta/theta_q_deg"]  = collect(THETA_Q_DEG)
        h5["meta/omega_ref"]    = preset.omega_ref
        h5["meta/rtp_duration"] = RTP_DURATION
        h5["meta/rtp_dt"]       = RTP_DT
        h5["meta/goto_times"]   = GOTO_TIMES_G
        h5["meta/goto_b_values_gauss"] = GOTO_VALUES_G
        h5["meta/lbfgs_E"]      = lbfgs_energy
        h5["meta/lbfgs_grad_norm"] = lbfgs_grad_norm
        h5["meta/vol_stride"]   = VOL_STRIDE
        h5["meta/vol_sample_indices"] = VOL_IDXS
        h5["meta/stored_3d_m_channels"] = collect(STORED_3D_M)
        h5["t"]      = buf.t
        h5["E"]      = buf.E
        h5["N"]      = buf.N
        h5["Mz"]     = buf.Mz
        h5["Fz"]     = buf.Fz
        h5["B_gauss"] = buf.B_gauss
        h5["n_m_xy"] = n_xy_arr
        h5["n_m_xz"] = n_xz_arr
        h5["Fx_xy"]  = Fx_arr;    h5["Fy_xy"] = Fy_arr;    h5["Fz_xy"] = Fz_arr
        h5["Fx_xz"]  = Fx_xz_arr; h5["Fy_xz"] = Fy_xz_arr; h5["Fz_xz"] = Fz_xz_arr
        h5["arg_psi_m6_xy"] = arg_arr
        h5["arg_psi_m6_xz"] = arg_xz_arr
        h5["n_m6_tilted"]   = tilt_arr
        h5["n_total_3d"] = n_total_3d_arr
        h5["n_m6_3d"] = n_m6_3d_arr
        h5["n_m5_3d"] = n_m5_3d_arr
        h5["n_m4_3d"] = n_m4_3d_arr
        h5["arg_psi_m6_3d"] = arg_m6_3d_arr
        h5["arg_psi_m5_3d"] = arg_m5_3d_arr
        h5["arg_psi_m4_3d"] = arg_m4_3d_arr
        h5["Fx_3d"] = Fx_3d_arr
        h5["Fy_3d"] = Fy_3d_arr
        h5["Fz_3d"] = Fz_3d_arr
    end
    println("[goto_10mG] wrote $OUT")
end

main()
