#!/usr/bin/env julia
"""
Build a compact HDF5 file for B-sweep 3D component/phase visualization.

Reads the cached per-B LBFGS final states and extracts downsampled 3D volumes
for m=-6, -5, -4 plus the spin field.
"""

using JLD2, HDF5, LinearAlgebra, Printf, Dates, Statistics

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)
const B_ALL_UG = [65, 60, 55, 50, 40, 30, 20, 10, 0, -10]

const ROOT = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
const OUT = joinpath(ROOT, "b_sweep_3d_components.h5")
const CACHE_PATH = B_uG -> joinpath(ROOT, "lbfgs_$(B_uG)uG_final_psi.jld2")
const VOL_STRIDE = parse(Int, get(ENV, "FPE_3D_VOL_STRIDE", "2"))

function spin_matrices_F6()
    Fz = zeros(ComplexF64, D, D)
    Fp = zeros(ComplexF64, D, D)
    for c in 1:D
        m = M_VALS[c]
        Fz[c, c] = m
        if c < D
            mn = M_VALS[c + 1]
            Fp[c, c + 1] = sqrt(F * (F + 1) - mn * (mn + 1))
        end
    end
    Fm = Fp'
    FX = (Fp + Fm) / 2
    FY = (Fp - Fm) / (2im)
    return FX, FY, Fz
end

const FX, FY, FZ = spin_matrices_F6()

function extract_3d_observables(psi, idxs)
    nv = length(idxs)
    n_total = zeros(Float32, nv, nv, nv)
    n_m6 = zeros(Float32, nv, nv, nv)
    n_m5 = zeros(Float32, nv, nv, nv)
    n_m4 = zeros(Float32, nv, nv, nv)
    arg_m6 = zeros(Float32, nv, nv, nv)
    arg_m5 = zeros(Float32, nv, nv, nv)
    arg_m4 = zeros(Float32, nv, nv, nv)
    Fx_3d = zeros(Float32, nv, nv, nv)
    Fy_3d = zeros(Float32, nv, nv, nv)
    Fz_3d = zeros(Float32, nv, nv, nv)

    @inbounds for (ii, i) in enumerate(idxs), (jj, j) in enumerate(idxs), (kk, k) in enumerate(idxs)
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

function main()
    isdir(ROOT) || error("ROOT not found: $ROOT")
    idxs = collect(1:VOL_STRIDE:64)
    nv = length(idxs)
    Nb = length(B_ALL_UG)
    println("[b_sweep_3d_components] ROOT=$ROOT  vol_stride=$VOL_STRIDE  grid=$nv^3")
    println("[b_sweep_3d_components] B values = $(B_ALL_UG)")

    for B_uG in B_ALL_UG
        path = CACHE_PATH(B_uG)
        isfile(path) || error("missing cache: $path")
    end

    B_uG = Float64[]
    E = Float64[]
    Fz = Float64[]
    n_total_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    n_m6_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    n_m5_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    n_m4_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    arg_m6_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    arg_m5_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    arg_m4_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    Fx_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    Fy_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)
    Fz_3d = Array{Float32,4}(undef, Nb, nv, nv, nv)

    for (i, Btarget) in enumerate(B_ALL_UG)
        path = CACHE_PATH(Btarget)
        println("[b_sweep_3d_components] loading $path")
        psi, Ei, grad = jldopen(path, "r") do f
            (f["psi"], f["E"], f["grad_norm"])
        end
        psi = Array{ComplexF64}(psi)
        vol = extract_3d_observables(psi, idxs)
        n_total_3d[i, :, :, :] .= vol.n_total
        n_m6_3d[i, :, :, :] .= vol.n_m6
        n_m5_3d[i, :, :, :] .= vol.n_m5
        n_m4_3d[i, :, :, :] .= vol.n_m4
        arg_m6_3d[i, :, :, :] .= vol.arg_m6
        arg_m5_3d[i, :, :, :] .= vol.arg_m5
        arg_m4_3d[i, :, :, :] .= vol.arg_m4
        Fx_3d[i, :, :, :] .= vol.Fx_3d
        Fy_3d[i, :, :, :] .= vol.Fy_3d
        Fz_3d[i, :, :, :] .= vol.Fz_3d
        push!(B_uG, Float64(Btarget))
        push!(E, Ei)
        push!(Fz, mean(vol.Fz_3d))
        @printf("  B=%+4d μG  E=%.6f  grad=%.3e\n", Btarget, Ei, grad)
    end

    h5open(OUT, "w") do h5
        h5["B_uG"] = B_uG
        h5["E"] = E
        h5["Fz"] = Fz
        h5["meta/F"] = F
        h5["meta/L_box"] = 18.0
        h5["meta/NX"] = 64
        h5["meta/vol_stride"] = VOL_STRIDE
        h5["meta/stored_3d_m_channels"] = [-6, -5, -4]
        h5["meta/created_utc"] = string(now())
        h5["n_total_3d"] = n_total_3d
        h5["n_m6_3d"] = n_m6_3d
        h5["n_m5_3d"] = n_m5_3d
        h5["n_m4_3d"] = n_m4_3d
        h5["arg_psi_m6_3d"] = arg_m6_3d
        h5["arg_psi_m5_3d"] = arg_m5_3d
        h5["arg_psi_m4_3d"] = arg_m4_3d
        h5["Fx_3d"] = Fx_3d
        h5["Fy_3d"] = Fy_3d
        h5["Fz_3d"] = Fz_3d
    end
    println("[b_sweep_3d_components] wrote $OUT")
end

main()
