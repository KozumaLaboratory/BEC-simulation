#!/usr/bin/env julia
# scripts/sprint5_A1_v3_step6_richness_sweep.jl
#
# Step 6 of the rigor protocol: F=6 PCV-richness sweep + alternative
# F=6-specific texture ansatze. Tests whether the current "Full PCV"
# (w=∓1 on m=±1, w=∓2 on m=±2) is the actual GS, or whether richer
# PCV (w on m=±3, ±4, ±5, ±6) or I_h-OP-vortex beats it.
#
# Ansatz family:
#   PCV_k for k=1..6: polar (m=0) base × m=±j (j=1..k) admixture with
#                     phase winding ∓j on m=±j.
#   I_h_vortex:      I_h spinor (ZETA_F6_IH ∝ |0⟩+|+5⟩−|−5⟩) ×
#                    phase winding +5 on m=+5, -5 on m=-5.
#   KSU_F:           m=+F base + phase winding +1 on m=+F (FM axial vortex).
#
# Each ansatz gets ITP warmup + LBFGS polish on GPU at digital twin
# geometry. Same convergence accounting + sector tagging as Step 1.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_step6_richness_sweep.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const TW = eu151_preset()
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_ITP = 20000
const TOL_ITP = 1e-9
const N_LBFGS = 8000
const TOL_LBFGS = 1e-10
const SEED = 1

const OUT_DIR = "runs/sprint5_A1_v3_step6_richness"

# F=6 spinor index: c=1..13 corresponds to m=+F..-F. Helper:
m_to_c(m::Int) = F - m + 1   # c=1 for m=+F, c=13 for m=-F

# Build PCV_k ansatz: polar (m=0) Gaussian + small admixture on m=±j
# for j=1..k, each carrying phase winding ∓j on m=±j.
function build_pcv_k(grid::Grid, sys::SpinSystem, k::Int;
    polar_amp::Float64=1.0, side_amp::Float64=0.1)
    psi = init_psi(grid, sys; state=:polar)
    # psi currently has only m=0 populated (c=7 for F=6)
    xs = grid.x[1]
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    for j in 1:k
        c_plus = m_to_c(+j)
        c_minus = m_to_c(-j)
        # Use the m=0 amplitude as the radial envelope template
        for kz in 1:nz, jy in 1:ny, ix in 1:nx
            theta = atan(ys[jy], xs[ix])
            envelope = abs(psi[ix, jy, kz, m_to_c(0)])
            psi[ix, jy, kz, c_plus] += side_amp * envelope * exp(-im * j * theta)
            psi[ix, jy, kz, c_minus] += side_amp * envelope * exp(+im * j * theta)
        end
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    n > 0 && (psi ./= n)
    return psi
end

# I_h_vortex: ZETA_F6_IH × phase winding on m=±5
function build_Ih_vortex(grid::Grid, sys::SpinSystem)
    ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
    psi = init_psi(grid, sys; state=:polar)
    xs = grid.x[1];
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    for kz in 1:nz, jy in 1:ny, ix in 1:nx
        envelope = sqrt(sum(abs2, view(psi, ix, jy, kz, :)))
        theta = atan(ys[jy], xs[ix])
        # I_h spinor has m=0 (c=7), m=+5 (c=2), m=-5 (c=12)
        # Apply windings: m=+5 gets winding -5 (analogous to PCV's m=+1 → -1)
        for c in 1:size(psi, 4)
            m = F - c + 1
            base = envelope * ζ[c]
            if m == +5
                psi[ix, jy, kz, c] = base * exp(-im * 5 * theta)
            elseif m == -5
                psi[ix, jy, kz, c] = base * exp(+im * 5 * theta)
            else
                psi[ix, jy, kz, c] = base
            end
        end
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    n > 0 && (psi ./= n)
    return psi
end

# KSU(F): m=+F base × phase winding +1 on m=+F
function build_KSU_F(grid::Grid, sys::SpinSystem)
    psi = init_psi(grid, sys; state=:m_plus_F)
    xs = grid.x[1];
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    c_F = m_to_c(+F)
    for kz in 1:nz, jy in 1:ny, ix in 1:nx
        theta = atan(ys[jy], xs[ix])
        psi[ix, jy, kz, c_F] *= exp(im * theta)
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    n > 0 && (psi ./= n)
    return psi
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(TW.grid))
    psi ./= n
end

function relax_and_polish(label::String, psi_init::Array{ComplexF64, 4})
    @printf "\n--- %s ---\n" label
    flush(stdout)
    t0 = time()
    apply_noise!(psi_init, 0.01, SEED)
    # ITP warm-up
    ws, conv_itp, E_itp, _, _ = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZEEMAN, potential=TW.potential,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend())
    psi_after_itp = Array(ws.state.psi)
    @printf "  ITP   E=%.10f conv=%s (%.1f min)\n" E_itp (conv_itp ? "✓" : "✗") ((time() - t0) / 60)
    # LBFGS polish on top of ITP
    t1 = time()
    res = find_ground_state_lbfgs(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZEEMAN, potential=TW.potential,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        initial_state=:polar, psi_init=psi_after_itp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend(), verbose=false)
    t_lbfgs = time() - t1
    E_pol = res.energy
    b = energy_decomposition(res.workspace)
    psi_pol = Array(res.workspace.state.psi)
    # Windings on m=±1..±5 at r=4, z=mid
    function winding(c)
        pts = ComplexF64[]
        for theta in range(0, 2π; length=33)[1:(end - 1)]
            i = round(Int, 12 + 4 * cos(theta))
            j = round(Int, 12 + 4 * sin(theta))
            push!(pts, psi_pol[i, j, 13, c])
        end
        w = 0.0
        for ki in 1:length(pts)
            knext = mod1(ki+1, length(pts))
            dphi = angle(pts[knext]) - angle(pts[ki])
            while dphi > π
                ;
                dphi -= 2π;
            end
            while dphi < -π
                ;
                dphi += 2π;
            end
            w += dphi
        end
        w / 2π
    end
    windings = Dict(j => (winding(m_to_c(+j)), winding(m_to_c(-j))) for j in 1:5)
    sm = res.workspace.spin_matrices
    fx, fy, fz = spin_density_vector(psi_pol, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))

    @printf "  LBFGS E=%.10f conv=%s dE=%.3e step=%d (%.1f min)\n" E_pol (res.converged ? "✓" : "✗") res.dE res.last_step (
        t_lbfgs / 60
    )
    @printf "  E_ddi=%+.4e E_spin=%+.4e E_kin=%+.4e f_max=%.4f\n" b.ddi b.spin b.kinetic f_max
    print("  windings on m=±j (r=4, z=mid): ")
    for j in 1:5
        @printf "j=%d:(%+.2f,%+.2f) " j windings[j][1] windings[j][2]
    end
    println()
    CUDA.reclaim()
    return (label=label, E_itp=E_itp, E_pol=E_pol, converged=res.converged,
        dE=res.dE, last_step=res.last_step, b=b, f_max=f_max,
        psi=psi_pol, windings=windings)
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== Step 6 — F=6 richness sweep at digital twin ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    @printf "%d-ansatz sweep at digital twin (24³, N=5×10⁴, aspect 1.1818)\n" 8
    sys = SpinSystem(F)

    results = []

    # PCV1..PCV6 ansatze
    for k in 1:6
        psi = build_pcv_k(TW.grid, sys, k; polar_amp=1.0, side_amp=0.1)
        res = relax_and_polish("PCV_$k", psi)
        push!(results, res)
    end

    # I_h vortex
    psi_Ih = build_Ih_vortex(TW.grid, sys)
    res = relax_and_polish("I_h_vortex", psi_Ih)
    push!(results, res)

    # KSU(F)
    psi_ksu = build_KSU_F(TW.grid, sys)
    res = relax_and_polish("KSU_F", psi_ksu)
    push!(results, res)

    println("\n\n=== Step 6 ranked ===\n")
    sorted = sort(results; by=r -> r.E_pol)
    @printf "%-3s %-14s %-16s %-10s %-8s %-10s\n" "#" "ansatz" "E_pol" "dE" "f_max" "windings(j=1..5)"
    for (i, r) in enumerate(sorted)
        ws_str = join(
            [@sprintf("(%+.1f,%+.1f)", r.windings[j][1], r.windings[j][2]) for j in 1:5], " "
        )
        @printf "%-3d %-14s %+.8e %.2e %.4f %s\n" i r.label r.E_pol r.dE r.f_max ws_str
    end

    println("\n--- vs original PCV winner ---\n")
    pcv_orig_E = 9.20645723
    @printf "Original Full PCV (Step 1 LBFGS v2): E=%.8f\n" pcv_orig_E
    for r in sorted[1:min(3, end)]
        de = r.E_pol - pcv_orig_E
        @printf "  %-14s: ΔE_vs_original = %+.4e (%.4f%% of |E|)\n" r.label de (
            100de / abs(pcv_orig_E)
        )
    end

    snapshot = [
        Dict(
            "label" => r.label, "E_itp" => r.E_itp, "E_pol" => r.E_pol,
            "converged" => r.converged, "dE" => r.dE, "last_step" => r.last_step,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi,
            "windings" => Dict(string(j) => collect(r.windings[j]) for j in 1:5),
        ) for r in sorted
    ]
    @save joinpath(OUT_DIR, "step6_sweep.jld2") snapshot
    @info "Saved Step 6 sweep" joinpath(OUT_DIR, "step6_sweep.jld2")
    println("\n=== Done ===")
end

main()
