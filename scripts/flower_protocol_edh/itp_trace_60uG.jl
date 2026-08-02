# scripts/flower_protocol_edh/itp_trace_60uG.jl
# ============================================
# ITP imaginary-time-evolution trace at B = 60 μG, F=6 Eu151.
#
# Runs find_ground_state with an on_step callback that grabs a snapshot
# every SAVE_EVERY steps. For each snapshot we keep:
#   • n_m  (population per m channel, integrated)
#   • Fz, |F_perp|, Lz scalars
#   • E (total), drho (since last snap), dpsi (since last snap)
#   • n_m_xy slices (D, nx, ny)  — for per-m density GIF
#   • Fx_xy, Fy_xy, Fz_xy slices — for spin-arrow GIF
#   • arg(ψ_{m=-6})_xy slice    — for phase GIF
#
# Goal: visualise WHEN the ITP wavefunction drifts away from the true
#       minimum at 60 μG (drho minimum was step ~26500 then increased).
#
# Output: /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/itp_trace_60uG.h5

import CUDA
using SpinorBEC
using HDF5, LinearAlgebra, FFTW
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
                 CUDABackend, CPUBackend

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0
const DX = L_BOX / NX
const N_STEPS  = 50_000
const DT       = 0.005
const SAVE_EVERY = 100   # → 500 snapshots
const B_GAUSS  = 6.0e-5  # 60 μG

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
const OUT = joinpath(OUT_DIR, "itp_trace_60uG.h5")

# --- Spin matrices ---
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
    Fx = (Fp + Fm) / 2
    Fy = (Fp - Fm) / (2im)
    Fx, Fy, Fz
end
const FX, FY, FZ = spin_matrices_F6()

mutable struct SnapBuf
    step::Vector{Int}
    E::Vector{Float64}
    drho::Vector{Float64}
    dpsi::Vector{Float64}
    N_tot::Vector{Float64}
    Fz::Vector{Float64}
    Fperp::Vector{Float64}
    Lz::Vector{Float64}
    n_m::Vector{Vector{Float64}}      # per-snap (D,)
    n_xy::Vector{Array{Float32,3}}    # per-snap (D, nx, ny)
    n_xz::Vector{Array{Float32,3}}    # per-snap (D, nx, nz)
    Fx_xy::Vector{Matrix{Float32}}
    Fy_xy::Vector{Matrix{Float32}}
    Fz_xy::Vector{Matrix{Float32}}
    Fx_xz::Vector{Matrix{Float32}}
    Fy_xz::Vector{Matrix{Float32}}
    Fz_xz::Vector{Matrix{Float32}}
    arg_m6_xy::Vector{Matrix{Float32}}
    arg_m6_xz::Vector{Matrix{Float32}}
    psi_prev::Union{Nothing,Array{ComplexF64,4}}
    rho_prev::Union{Nothing,Array{Float64,3}}
end
SnapBuf() = SnapBuf(Int[], Float64[], Float64[], Float64[], Float64[],
    Float64[], Float64[], Float64[],
    Vector{Vector{Float64}}(),
    Vector{Array{Float32,3}}(), Vector{Array{Float32,3}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    Vector{Matrix{Float32}}(), Vector{Matrix{Float32}}(),
    nothing, nothing)

const KX = 2π / L_BOX .* FFTW.fftfreq(NX) .* NX

function take_snapshot!(buf::SnapBuf, ws, step::Int)
    psi = Array{ComplexF64}(ws.state.psi)   # to host
    nx, ny, nz, _ = size(psi)
    z_mid = nz ÷ 2 + 1
    y_mid = ny ÷ 2 + 1

    # scalar reductions
    N_tot = 0.0
    n_m = zeros(Float64, D)
    @inbounds for c in 1:D
        s = 0.0
        for k in 1:nz, j in 1:ny, i in 1:nx
            s += abs2(psi[i,j,k,c])
        end
        n_m[c] = s * DX^3
        N_tot += n_m[c]
    end
    Fxe = 0.0; Fye = 0.0; Fze = 0.0
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        ψ = @view psi[i,j,k,:]
        Fxe += real(ψ' * (FX * ψ)) * DX^3
        Fye += real(ψ' * (FY * ψ)) * DX^3
        Fze += real(ψ' * (FZ * ψ)) * DX^3
    end
    # L_z spectral
    Lz_e = 0.0
    @inbounds for c in 1:D
        ψc = view(psi, :, :, :, c)
        ddy = ifft(1im .* reshape(KX, 1, :, 1) .* fft(ψc, 2), 2)
        ddx = ifft(1im .* reshape(KX, :, 1, 1) .* fft(ψc, 1), 1)
        for k in 1:nz, j in 1:ny, i in 1:nx
            x = (-L_BOX/2) + DX*(i-1)
            y = (-L_BOX/2) + DX*(j-1)
            Lz_loc = -1im * (x * ddy[i,j,k] - y * ddx[i,j,k])
            Lz_e += real(conj(ψc[i,j,k]) * Lz_loc) * DX^3
        end
    end

    # slices xy z=mid, xz y=mid
    n_xy = zeros(Float32, D, nx, ny)
    n_xz = zeros(Float32, D, nx, nz)
    Fx_xy = zeros(Float32, nx, ny); Fy_xy = zeros(Float32, nx, ny); Fz_xy = zeros(Float32, nx, ny)
    Fx_xz = zeros(Float32, nx, nz); Fy_xz = zeros(Float32, nx, nz); Fz_xz = zeros(Float32, nx, nz)
    arg_m6_xy = zeros(Float32, nx, ny)
    arg_m6_xz = zeros(Float32, nx, nz)
    @inbounds for c in 1:D, j in 1:ny, i in 1:nx
        n_xy[c,i,j] = Float32(abs2(psi[i,j,z_mid,c]))
    end
    @inbounds for c in 1:D, k in 1:nz, i in 1:nx
        n_xz[c,i,k] = Float32(abs2(psi[i,y_mid,k,c]))
    end
    @inbounds for j in 1:ny, i in 1:nx
        ψ = @view psi[i,j,z_mid,:]
        Fx_xy[i,j] = Float32(real(ψ' * (FX * ψ)))
        Fy_xy[i,j] = Float32(real(ψ' * (FY * ψ)))
        Fz_xy[i,j] = Float32(real(ψ' * (FZ * ψ)))
        arg_m6_xy[i,j] = Float32(angle(psi[i,j,z_mid,D]))
    end
    @inbounds for k in 1:nz, i in 1:nx
        ψ = @view psi[i,y_mid,k,:]
        Fx_xz[i,k] = Float32(real(ψ' * (FX * ψ)))
        Fy_xz[i,k] = Float32(real(ψ' * (FY * ψ)))
        Fz_xz[i,k] = Float32(real(ψ' * (FZ * ψ)))
        arg_m6_xz[i,k] = Float32(angle(psi[i,y_mid,k,D]))
    end

    # rho_now (per-cell total density)
    rho_now = zeros(Float64, nx, ny, nz)
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        s = 0.0
        for c in 1:D; s += abs2(psi[i,j,k,c]); end
        rho_now[i,j,k] = s
    end

    drho = NaN; dpsi = NaN
    if buf.rho_prev !== nothing
        rho_max = maximum(rho_now)
        drho = rho_max > 0 ? maximum(abs.(rho_now .- buf.rho_prev)) / rho_max : 0.0
    end
    if buf.psi_prev !== nothing
        psi_max = maximum(abs, psi)
        dpsi = psi_max > 0 ? maximum(abs, psi .- buf.psi_prev) / psi_max : 0.0
    end

    push!(buf.step, step)
    push!(buf.E, SpinorBEC.total_energy(ws))
    push!(buf.drho, drho); push!(buf.dpsi, dpsi)
    push!(buf.N_tot, N_tot)
    push!(buf.Fz, Fze / N_tot)
    push!(buf.Fperp, sqrt(Fxe^2 + Fye^2) / N_tot)
    push!(buf.Lz, Lz_e / N_tot)
    push!(buf.n_m, n_m)
    push!(buf.n_xy, n_xy); push!(buf.n_xz, n_xz)
    push!(buf.Fx_xy, Fx_xy); push!(buf.Fy_xy, Fy_xy); push!(buf.Fz_xy, Fz_xy)
    push!(buf.Fx_xz, Fx_xz); push!(buf.Fy_xz, Fy_xz); push!(buf.Fz_xz, Fz_xz)
    push!(buf.arg_m6_xy, arg_m6_xy); push!(buf.arg_m6_xz, arg_m6_xz)

    buf.psi_prev = psi
    buf.rho_prev = rho_now

    println("  snap step=$step E=$(round(buf.E[end]; sigdigits=8)) ",
            "drho=$(round(drho; sigdigits=3)) dpsi=$(round(dpsi; sigdigits=3)) ",
            "Fz=$(round(buf.Fz[end]; sigdigits=4)) |F⊥|=$(round(buf.Fperp[end]; sigdigits=4))")
    flush(stdout)
end

function main()
    mkpath(OUT_DIR)
    println("[itp_trace_60uG] start  out=$OUT")
    println("  NX=$NX  L=$L_BOX  dt=$DT  n_steps=$N_STEPS  save_every=$SAVE_EVERY")

    preset = eu151_preset(
        n_atoms=50_000,
        n_pts=(NX, NX, NX),
        box=(L_BOX, L_BOX, L_BOX),
        trap_ratios=(1.0, 1.0, 1.181818),
        omega_ref=691.1504,
    )
    p = Units.bfield_to_p(B_GAUSS, preset.atom.g_F, preset.omega_ref)
    zeeman = ZeemanParams(p, 0.0)
    println("  B=$B_GAUSS G → p=$(round(p; sigdigits=4))  c_dd=$(round(preset.c_dd; sigdigits=4))")

    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    println("  backend=$backend")

    buf = SnapBuf()
    on_step = (ws, step, n_steps) -> begin
        if step == 1 || step % SAVE_EVERY == 0
            take_snapshot!(buf, ws, step)
        end
    end

    gs = find_ground_state(;
        grid=preset.grid,
        atom=preset.atom,
        interactions=preset.interactions,
        zeeman=zeeman,
        potential=preset.potential,
        dt=DT,
        n_steps=N_STEPS,
        tol=1.0e-9,        # essentially never trip; we want the full trace
        tol_drho=0.0,
        save_every=SAVE_EVERY,
        initial_state=:m_plus_F,
        enable_ddi=true,
        c_dd=preset.c_dd,
        secular_ddi=false,
        backend=backend,
        on_step=on_step,
        verbose=true,
    )

    # final snapshot (in case last step wasn't on the cadence)
    if isempty(buf.step) || buf.step[end] != gs.last_step
        take_snapshot!(buf, gs.workspace, gs.last_step)
    end

    Nf = length(buf.step)
    println("[itp_trace_60uG] writing $Nf snapshots to $OUT")
    n_m_mat = zeros(Float64, D, Nf)
    n_xy_arr = zeros(Float32, Nf, D, NX, NX)
    n_xz_arr = zeros(Float32, Nf, D, NX, NX)
    Fx_arr = zeros(Float32, Nf, NX, NX); Fy_arr = zeros(Float32, Nf, NX, NX); Fz_arr = zeros(Float32, Nf, NX, NX)
    Fx_xz_arr = zeros(Float32, Nf, NX, NX); Fy_xz_arr = zeros(Float32, Nf, NX, NX); Fz_xz_arr = zeros(Float32, Nf, NX, NX)
    arg_arr = zeros(Float32, Nf, NX, NX)
    arg_xz_arr = zeros(Float32, Nf, NX, NX)
    for k in 1:Nf
        n_m_mat[:, k] .= buf.n_m[k]
        n_xy_arr[k, :, :, :] .= buf.n_xy[k]
        n_xz_arr[k, :, :, :] .= buf.n_xz[k]
        Fx_arr[k, :, :]    .= buf.Fx_xy[k]
        Fy_arr[k, :, :]    .= buf.Fy_xy[k]
        Fz_arr[k, :, :]    .= buf.Fz_xy[k]
        Fx_xz_arr[k, :, :] .= buf.Fx_xz[k]
        Fy_xz_arr[k, :, :] .= buf.Fy_xz[k]
        Fz_xz_arr[k, :, :] .= buf.Fz_xz[k]
        arg_arr[k, :, :]    .= buf.arg_m6_xy[k]
        arg_xz_arr[k, :, :] .= buf.arg_m6_xz[k]
    end

    h5open(OUT, "w") do h5
        h5["meta/m_channels"] = collect(M_VALS)
        h5["meta/F"]    = F
        h5["meta/L_box"] = L_BOX
        h5["meta/NX"]   = NX
        h5["meta/dt"]   = DT
        h5["meta/save_every"] = SAVE_EVERY
        h5["meta/n_steps"]    = N_STEPS
        h5["meta/B_gauss"]    = B_GAUSS
        h5["step"]   = buf.step
        h5["tau"]    = buf.step .* DT
        h5["E"]      = buf.E
        h5["drho"]   = buf.drho
        h5["dpsi"]   = buf.dpsi
        h5["N_total"]= buf.N_tot
        h5["Fz"]     = buf.Fz
        h5["F_perp"] = buf.Fperp
        h5["Lz"]     = buf.Lz
        h5["n_m"]    = n_m_mat
        h5["n_m_xy"] = n_xy_arr
        h5["n_m_xz"] = n_xz_arr
        h5["Fx_xy"]  = Fx_arr
        h5["Fy_xy"]  = Fy_arr
        h5["Fz_xy"]  = Fz_arr
        h5["Fx_xz"]  = Fx_xz_arr
        h5["Fy_xz"]  = Fy_xz_arr
        h5["Fz_xz"]  = Fz_xz_arr
        h5["arg_psi_m6_xy"] = arg_arr
        h5["arg_psi_m6_xz"] = arg_xz_arr
    end
    println("[itp_trace_60uG] done.  converged=$(gs.converged)  last_step=$(gs.last_step)  E=$(gs.energy)")
end

main()
