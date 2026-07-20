# scripts/flower_protocol_edh/b_sweep_lbfgs.jl
# ============================================
# LBFGS B-sweep: chain-warm-start through B ∈ {65, 60, 55, 50, 40, 30,
# 20, 10, 0, -10} μG, polishing each to the variational GS at that B.
# Each step seeds from the previously-converged ψ at the nearest B — so
# LBFGS converges in a fraction of the iterations a fresh start would
# need.
#
# Caches:
#   lbfgs_<B>uG_final_psi.jld2  per B (metadata-rich; resumable across
#                                jobs — if a cache exists it is loaded
#                                and skipped).
# Output: b_sweep.h5  (slices + tilted column + scalars indexed by B)

import CUDA
using SpinorBEC
using HDF5, JLD2, LinearAlgebra, Dates
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state_lbfgs,
                 CUDABackend, CPUBackend, magnetization, rotate_quantization_axis,
                 SpinSystem

const F = 6
const D = 2F + 1
const M_VALS = collect(F:-1:-F)

const NX = 64
const L_BOX = 18.0
const DX = L_BOX / NX

# B sweep — chained warm-start order (nearest-neighbour from 60μG anchor).
# Pairs: (B_target_uG, seed_B_uG) — seed_B's cache provides ψ_init for B_target.
const B_SWEEP_PLAN = [
    (B_target=65,  seed=60),   # +5 from anchor
    (B_target=55,  seed=60),   # -5 from anchor
    (B_target=50,  seed=55),
    (B_target=40,  seed=50),
    (B_target=30,  seed=40),
    (B_target=20,  seed=30),
    (B_target=10,  seed=20),
    (B_target=0,   seed=10),
    (B_target=-10, seed=0),
]
# B=60μG is the anchor (already in `lbfgs_60uG_final_psi.jld2`, E=6.6447, 3500 iter)
const B_ALL_UG = sort([60; [p.B_target for p in B_SWEEP_PLAN]])

const LBFGS_N_STEPS = 1_000      # cap; warm start ⇒ early termination expected
const LBFGS_TOL     = 1.0e-7
const LBFGS_M       = 10
const LBFGS_SOBOLEV_ALPHA = 0.5

const THETA_Q_DEG = (-16.0, 0.0, +16.0)

const OUT_DIR = get(ENV, "FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")
const OUT     = joinpath(OUT_DIR, "b_sweep.h5")
cache_path(B_uG::Int) = joinpath(OUT_DIR, "lbfgs_$(B_uG)uG_final_psi.jld2")

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

function extract_slices(psi)
    nx, ny, nz, _ = size(psi)
    z_mid = nz ÷ 2 + 1
    y_mid = ny ÷ 2 + 1
    n_xy  = zeros(Float32, D, nx, ny)
    n_xz  = zeros(Float32, D, nx, nz)
    Fx_xy = zeros(Float32, nx, ny); Fy_xy = zeros(Float32, nx, ny); Fz_xy = zeros(Float32, nx, ny)
    Fx_xz = zeros(Float32, nx, nz); Fy_xz = zeros(Float32, nx, nz); Fz_xz = zeros(Float32, nx, nz)
    arg_xy = zeros(Float32, nx, ny); arg_xz = zeros(Float32, nx, nz)
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
            for j in 1:ny; s += abs2(psi_rot[i, j, k, D]); end
            out[ti, k, i] = Float32(s)
        end
    end
    out
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

function main()
    mkpath(OUT_DIR)
    preset = eu151_preset(
        n_atoms=50_000,
        n_pts=(NX, NX, NX), box=(L_BOX, L_BOX, L_BOX),
        trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504,
    )
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    git_sha = try; strip(read(`git -C $(@__DIR__)/../.. rev-parse HEAD`, String)); catch; "unknown"; end

    println("[b_sweep] backend=$backend  c_dd=$(round(preset.c_dd; sigdigits=4))")
    println("[b_sweep] B values [μG]: $(B_ALL_UG)")

    # Verify anchor cache exists
    anchor_path = cache_path(60)
    isfile(anchor_path) || error("Anchor cache missing: $anchor_path  (need 60μG LBFGS result first)")

    # --- Process sweep plan ---
    for step in B_SWEEP_PLAN
        B_t = step.B_target
        B_s = step.seed
        path_t = cache_path(B_t)
        path_s = cache_path(B_s)

        if isfile(path_t)
            println("[b_sweep] cache present for B=$(B_t)μG → skip ($path_t)")
            continue
        end

        isfile(path_s) || error("Seed cache missing for B=$(B_s)μG (need $path_s before doing B=$(B_t)μG)")

        seed_psi = jldopen(path_s, "r") do f; f["psi"]; end
        println("[b_sweep] target B=$(B_t)μG  ← seed B=$(B_s)μG")

        B_target_g = B_t * 1e-6
        p_target = Units.bfield_to_p(B_target_g, preset.atom.g_F, preset.omega_ref)
        zeeman_t = ZeemanParams(p_target, 0.0)

        gs = find_ground_state_lbfgs(;
            grid=preset.grid, atom=preset.atom,
            interactions=preset.interactions, zeeman=zeeman_t, potential=preset.potential,
            psi_init=seed_psi,
            n_steps=LBFGS_N_STEPS, tol=LBFGS_TOL, m_lbfgs=LBFGS_M,
            sobolev_alpha=LBFGS_SOBOLEV_ALPHA,
            enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
            backend=backend, verbose=true,
        )
        psi_t = Array{ComplexF64}(gs.workspace.state.psi)
        println("  → E=$(gs.energy)  |∇|=$(gs.grad_norm)")

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
            f["method"]           = "LBFGS warm-start from B=$(B_s)μG, $LBFGS_N_STEPS iter Sobolev α=$LBFGS_SOBOLEV_ALPHA"
        end
        println("  cached → $path_t")
    end

    # --- Collect all sweep results into a single h5 for plotting ---
    Nb = length(B_ALL_UG)
    println("[b_sweep] assembling h5 with $Nb B values")
    n_xy_all = zeros(Float32, Nb, D, NX, NX)
    n_xz_all = zeros(Float32, Nb, D, NX, NX)
    Fx_xy_all = zeros(Float32, Nb, NX, NX); Fy_xy_all = zeros(Float32, Nb, NX, NX); Fz_xy_all = zeros(Float32, Nb, NX, NX)
    Fx_xz_all = zeros(Float32, Nb, NX, NX); Fy_xz_all = zeros(Float32, Nb, NX, NX); Fz_xz_all = zeros(Float32, Nb, NX, NX)
    arg_xy_all = zeros(Float32, Nb, NX, NX); arg_xz_all = zeros(Float32, Nb, NX, NX)
    tilt_all = zeros(Float32, Nb, length(THETA_Q_DEG), NX, NX)
    E_all     = zeros(Float64, Nb)
    grad_all  = zeros(Float64, Nb)
    Fz_all    = zeros(Float64, Nb)

    for (i, B_uG) in enumerate(B_ALL_UG)
        path = cache_path(B_uG)
        isfile(path) || error("Missing cache for B=$(B_uG)μG: $path")
        d = jldopen(path, "r") do f
            (psi=f["psi"], E=f["E"], grad=f["grad_norm"])
        end
        psi = d.psi
        sl  = extract_slices(psi)
        tl  = tilted_yint(psi)
        n_xy_all[i, :, :, :] .= sl.n_xy
        n_xz_all[i, :, :, :] .= sl.n_xz
        Fx_xy_all[i, :, :] .= sl.Fx_xy; Fy_xy_all[i, :, :] .= sl.Fy_xy; Fz_xy_all[i, :, :] .= sl.Fz_xy
        Fx_xz_all[i, :, :] .= sl.Fx_xz; Fy_xz_all[i, :, :] .= sl.Fy_xz; Fz_xz_all[i, :, :] .= sl.Fz_xz
        arg_xy_all[i, :, :] .= sl.arg_xy; arg_xz_all[i, :, :] .= sl.arg_xz
        tilt_all[i, :, :, :] .= tl
        E_all[i]    = d.E
        grad_all[i] = d.grad
        Fz_all[i]   = scalar_Fz(psi)
        println("  B=$(B_uG)μG  E=$(d.E)  |∇|=$(d.grad)  Fz=$(round(Fz_all[i]; sigdigits=4))")
    end

    h5open(OUT, "w") do h5
        h5["meta/m_channels"]  = collect(M_VALS)
        h5["meta/F"]           = F
        h5["meta/L_box"]       = L_BOX
        h5["meta/NX"]          = NX
        h5["meta/theta_q_deg"] = collect(THETA_Q_DEG)
        h5["meta/omega_ref"]   = preset.omega_ref
        h5["B_uG"]    = collect(B_ALL_UG)
        h5["E"]       = E_all
        h5["grad_norm"] = grad_all
        h5["Fz"]      = Fz_all
        h5["n_m_xy"]  = n_xy_all
        h5["n_m_xz"]  = n_xz_all
        h5["Fx_xy"]   = Fx_xy_all; h5["Fy_xy"] = Fy_xy_all; h5["Fz_xy"] = Fz_xy_all
        h5["Fx_xz"]   = Fx_xz_all; h5["Fy_xz"] = Fy_xz_all; h5["Fz_xz"] = Fz_xz_all
        h5["arg_psi_m6_xy"] = arg_xy_all
        h5["arg_psi_m6_xz"] = arg_xz_all
        h5["n_m6_tilted"]   = tilt_all
    end
    println("[b_sweep] wrote $OUT")
end

main()
