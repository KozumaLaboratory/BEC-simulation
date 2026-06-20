# scripts/flower_protocol_edh/mass_current_analysis.jl
# =====================================================
# Post-hoc mass-current / vorticity / Mermin–Ho diagnostics for Issue #32.
#
# Reads the saved ψ snapshots from a Goto-protocol RTP h5, calls the
# audited functions in src/analysis/currents.jl + vorticity.jl, and writes
# the resulting fields (j, v, ∇×v, Berry curvature, …) back into the same
# h5 under a `mass_current/` group for downstream plotting.
#
# Usage:
#   julia --project=. scripts/flower_protocol_edh/mass_current_analysis.jl \
#       /path/to/rtp_quench_63uG_k3_1.0e-40.h5
#
# Both `flower` and `quench` runs are processed by invoking this script
# twice with different files.

using SpinorBEC
using SpinorBEC: Grid, GridConfig, make_grid, make_fft_plans, SpinSystem,
                 probability_current, superfluid_velocity, total_density,
                 spin_matrices, berry_curvature, spin_texture_charge
using HDF5, LinearAlgebra, FFTW

if length(ARGS) < 1
    error("usage: julia mass_current_analysis.jl <h5_path>")
end
const H5_PATH = ARGS[1]

println("[mca] reading $H5_PATH")

h5 = h5open(H5_PATH, "r+")
try
    if !haskey(h5, "psi_full_re")
        error("h5 has no `psi_full_re` dataset — old run without full ψ saves. Re-run with GOTO_PSI_SAVE_EVERY set.")
    end

    psi_re = read(h5["psi_full_re"])    # (Nf_psi, D, NVOL, NVOL, NVOL)
    psi_im = read(h5["psi_full_im"])
    t_psi  = read(h5["t_psi"])
    Bpsi   = read(h5["B_gauss_psi"])
    NVOL   = read(h5["meta/nvol"])
    F      = read(h5["meta/F"])
    L_BOX  = read(h5["meta/L_box"])
    Nf_psi = size(psi_re, 1)
    D = 2F + 1
    DX_sub = L_BOX / NVOL                    # cell size on the sub-sampled 3D grid

    println("[mca] Nf_psi=$Nf_psi  NVOL=$NVOL  D=$D  dx_sub=$DX_sub")

    # Build a minimal Grid + plans matching the sub-sampled saved ψ.
    # GridConfig signature: (n_points::NTuple, box_size::NTuple)
    config = GridConfig((NVOL, NVOL, NVOL), (Float64(L_BOX), Float64(L_BOX), Float64(L_BOX)))
    grid = make_grid(config)
    plans = make_fft_plans((NVOL, NVOL, NVOL); flags=FFTW.ESTIMATE)
    sys = SpinSystem(Int(F))
    sm = spin_matrices(Int(F))

    # Output buffers: j (3 components), v (3 components), |F_perp|, ∇·F proxy
    jx = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    jy = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    jz = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    vx = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    vy = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    vz = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    # Vorticity from finite-difference of v (curl_z in xy plane is the headline diagnostic)
    curl_v_z = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    # Mermin-Ho RHS: Berry curvature from the spin texture (Ω_z component).
    # If Mermin-Ho holds (Flower phase), curl_v_z ≈ −(ℏ F / m) · berry_z.
    # Big mismatch ⇒ vortex-dominated regime (EdH) where the texture-derived
    # prediction breaks down at the singular cores.
    berry_z = zeros(Float32, Nf_psi, NVOL, NVOL, NVOL)
    # Scalar diagnostics per frame
    n_max     = zeros(Float64, Nf_psi)
    j_mag_max = zeros(Float64, Nf_psi)
    circ_total = zeros(Float64, Nf_psi)   # ∫ ω_z dA on z=NVOL/2 midplane
    skyrmion_charge = zeros(Float64, Nf_psi)  # ∫ Ω · dA / 4π integer for textures

    for k in 1:Nf_psi
        # Reconstruct ψ: (D, NVOL, NVOL, NVOL) → (NVOL, NVOL, NVOL, D) for the
        # currents API which expects spinor index last.
        psi_DnX = ComplexF64.(psi_re[k, :, :, :, :]) .+ im .* ComplexF64.(psi_im[k, :, :, :, :])
        psi = permutedims(psi_DnX, (2, 3, 4, 1))

        # Mass current density (probability current; multiply by ℏ/m if SI units needed)
        j = probability_current(psi, grid, plans)
        v = superfluid_velocity(psi, grid, plans; density_cutoff=1e-12)

        jx[k, :, :, :] .= Float32.(j[1])
        jy[k, :, :, :] .= Float32.(j[2])
        jz[k, :, :, :] .= Float32.(j[3])
        vx[k, :, :, :] .= Float32.(v[1])
        vy[k, :, :, :] .= Float32.(v[2])
        vz[k, :, :, :] .= Float32.(v[3])

        # z-component of ∇ × v via centred differences
        @inbounds for kk in 1:NVOL, jj in 2:NVOL-1, ii in 2:NVOL-1
            dvy_dx = (v[2][ii+1, jj, kk] - v[2][ii-1, jj, kk]) / (2 * DX_sub)
            dvx_dy = (v[1][ii, jj+1, kk] - v[1][ii, jj-1, kk]) / (2 * DX_sub)
            curl_v_z[k, ii, jj, kk] = Float32(dvy_dx - dvx_dy)
        end

        # Berry curvature (Mermin-Ho RHS) — full 3D, take z component
        Ω = berry_curvature(psi, grid, plans, sm; density_cutoff=1e-12)
        berry_z[k, :, :, :] .= Float32.(Ω[3])

        # Skyrmion / pontryagin charge on z-midplane (Mermin–Ho LHS area-integral / 4π)
        midz = NVOL ÷ 2 + 1
        skyrmion_charge[k] = sum(Ω[3][:, :, midz]) * DX_sub^2 / (4π)

        n = total_density(psi, 3)
        n_max[k] = maximum(n)
        j_mag_max[k] = maximum(sqrt.(j[1].^2 .+ j[2].^2 .+ j[3].^2))
        circ_total[k] = sum(curl_v_z[k, :, :, midz]) * DX_sub^2

        println("  [$k/$Nf_psi]  t=$(round(t_psi[k]; digits=3))  B=$(round(Bpsi[k]*1e6; sigdigits=4)) µG  n_max=$(round(n_max[k]; sigdigits=4))  |j|_max=$(round(j_mag_max[k]; sigdigits=4))  ∫ω_z dA=$(round(circ_total[k]; sigdigits=4))  Q_sk=$(round(skyrmion_charge[k]; sigdigits=4))")
        flush(stdout)
    end

    # Write back into the h5 under mass_current/
    if haskey(h5, "mass_current")
        delete_object(h5, "mass_current")
    end
    grp = create_group(h5, "mass_current")
    grp["jx"] = jx; grp["jy"] = jy; grp["jz"] = jz
    grp["vx"] = vx; grp["vy"] = vy; grp["vz"] = vz
    grp["curl_v_z"] = curl_v_z
    grp["berry_z"] = berry_z
    grp["n_max"] = n_max
    grp["j_mag_max"] = j_mag_max
    grp["circulation_midz"] = circ_total
    grp["skyrmion_charge_midz"] = skyrmion_charge
    grp["dx_sub"] = DX_sub
    println("[mca] mass_current/ datasets written ($(Nf_psi) frames)")
finally
    close(h5)
end

println("[mca] done")
