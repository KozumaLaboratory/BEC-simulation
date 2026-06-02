#!/usr/bin/env julia
# scripts/sprint5_A1_v3_step3_grid32.jl
#
# Step 3 grid validity — re-relax PCV_basic ansatz at 32³ box=(30, 30, 26)
# at Eu Matsui digital twin. Tests whether the 24³ Step 6 v2 result
# (LBFGS-PCV at E=9.20646) is grid-converged or coarse-grid artifact.
#
# Comparison:
#   24³ dx_perp=1.25, dx_z=1.083 → vortex core fits in ~1 cell (the
#   user-flagged concern that 24³ artificially favours winding states)
#   32³ dx_perp=0.94, dx_z=0.81 → finer resolution; core spans more cells
#
# If 32³ E and m-content match 24³ → grid-converged, PCV is robust.
# If 32³ E lower or m-content shifts (e.g. m=±4 survives) → 24³ was
# undersampled; revisit interpretation B.
#
# Also run PCV_BdG seed at 32³ to test whether m=±4 channel survives
# at finer resolution.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_step3_grid32.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const D = 2F + 1
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15

# 32³ at same box dimensions as 24³ digital twin
const GRID_32 = make_grid(GridConfig((32, 32, 32), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_ITP = 20000
const TOL_ITP = 1e-9
const N_LBFGS = 8000
const TOL_LBFGS = 1e-10
const SEED = 1

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const OUT_DIR = "runs/sprint5_A1_v3_step3_grid32"

m_to_c(m::Int) = F - m + 1

function build_pcv_with_channels(grid::Grid, sys::SpinSystem,
    channels::Dict{Int, Tuple{Int, Float64}})
    psi = init_psi(grid, sys; state=:polar)
    xs = grid.x[1];
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    side_total = sum(abs2.(v[2]) for v in values(channels))
    polar_weight = max(1.0 - side_total, 0.0)
    for c in 1:D
        psi[:, :, :, c] .*= (c == m_to_c(0) ? sqrt(polar_weight) : 0.0)
    end
    for (m, (w, amp)) in channels
        c_target = m_to_c(m)
        for kz in 1:nz, jy in 1:ny, ix in 1:nx
            theta = atan(ys[jy], xs[ix])
            envelope = abs(psi[ix, jy, kz, m_to_c(0)]) / max(sqrt(polar_weight), 1e-30)
            psi[ix, jy, kz, c_target] = amp * envelope * exp(im * w * theta)
        end
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    n > 0 && (psi ./= n)
    return psi
end

build_PCV_basic(grid, sys) = build_pcv_with_channels(grid, sys, Dict(
    +1 => (-1, 0.30), -1 => (+1, 0.30)))

build_PCV_BdG(grid, sys) = build_pcv_with_channels(
    grid, sys, Dict(
        +1 => (-1, 0.30), -1 => (+1, 0.30),
        +4 => (-4, 0.20), -4 => (+4, 0.20))
)

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= n
end

function compute_grad_norm(ws::Workspace, k_squared_dev)
    psi = ws.state.psi
    grad = similar(psi)
    fill!(grad, 0.0)
    SpinorBEC.energy_gradient!(grad, psi, ws; k_squared_dev=k_squared_dev)
    dV = SpinorBEC.cell_volume(ws.grid)
    overlap = sum(conj.(psi) .* grad) * dV
    grad .-= overlap .* psi
    sqrt(real(sum(abs2, grad)) * dV)
end

function relax_polish(label::String, psi_init::Array{ComplexF64, 4}, grid::Grid)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    apply_noise!(psi_init, 0.01, SEED, grid)

    nx = size(grid.k_squared, 1)
    @printf "\n--- %s @ %d³ ---\n" label nx
    flush(stdout)

    t0 = time()
    ws_itp, _, E_itp, _, _ = find_ground_state(;
        grid=grid, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        backend=CUDABackend())
    psi_after = Array(ws_itp.state.psi)
    @printf "  ITP   E=%.10f (%.1f min)\n" E_itp ((time() - t0) / 60)

    t1 = time()
    res = find_ground_state_lbfgs(;
        grid=grid, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        initial_state=:polar, psi_init=psi_after,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        backend=CUDABackend(), verbose=false)
    E_pol = res.energy
    ws = res.workspace
    b = energy_decomposition(ws)
    k_sq_dev = CUDA.CuArray(grid.k_squared)
    grad_norm = compute_grad_norm(ws, k_sq_dev)
    psi_pol = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi_pol, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))

    m_dist = zeros(D)
    for c in 1:D
        m_dist[c] = sum(abs2, psi_pol[:, :, :, c])
    end
    m_dist ./= sum(m_dist)

    function winding(c)
        pts = ComplexF64[]
        mid = div(size(psi_pol, 1), 2)
        for theta in range(0, 2π; length=33)[1:(end - 1)]
            i = round(Int, mid + 5 * cos(theta))   # r=5 at 32³ ≈ r=4 at 24³ same physical distance
            j = round(Int, mid + 5 * sin(theta))
            push!(pts, psi_pol[i, j, div(size(psi_pol, 3), 2), c])
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

    @printf "  LBFGS E=%.10f dE=%.3e ‖∇E‖=%.4e step=%d (%.1f min)\n" E_pol res.dE grad_norm res.last_step (
        (time() - t1) / 60
    )
    @printf "  E_ddi=%+.4e E_spin=%+.4e f_max=%.4f\n" b.ddi b.spin f_max
    print("  windings (r=5, mid): ")
    for j in 1:5
        @printf "j=%d:(%+.1f,%+.1f) " j windings[j][1] windings[j][2]
    end
    println()
    print("  m-pop top 5: ")
    sorted_m = sortperm(m_dist; rev=true)
    for c in sorted_m[1:5]
        @printf "m=%+d:%.3f " (F-c+1) m_dist[c]
    end
    println()
    CUDA.reclaim()
    return (label=label, E_pol=E_pol, dE=res.dE, grad_norm=grad_norm,
        b=b, f_max=f_max, m_dist=m_dist, windings=windings, psi=psi_pol)
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== Step 3 — 32³ grid validity check ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    println("Reference (24³ Step 6 v2):")
    println("  PCV_basic E=9.20645724, m-pop m=0:0.549 m=±1:0.198 m=±2:0.026")
    println("  PCV_BdG   E=9.20645724 (same)")
    println()
    sys = SpinSystem(F)
    results = []
    for (label, builder) in [
        ("PCV_basic_32", build_PCV_basic),
        ("PCV_BdG_32", build_PCV_BdG),
    ]
        psi = builder(GRID_32, sys)
        res = relax_polish(label, psi, GRID_32)
        push!(results, res)
    end

    println("\n\n=== 32³ rank ===\n")
    sorted = sort(results; by=r -> r.E_pol)
    @printf "%-3s %-18s %-16s %-10s %-10s %-8s\n" "#" "ansatz" "E_pol" "dE" "‖∇E‖" "f_max"
    for (i, r) in enumerate(sorted)
        @printf "%-3d %-18s %+.8e %.2e %.3e %.4f\n" i r.label r.E_pol r.dE r.grad_norm r.f_max
    end

    println("\n--- 32³ vs 24³ comparison ---")
    E_24 = 9.20645724
    for r in sorted
        de = r.E_pol - E_24
        @printf "  %s: E_32 - E_24 = %+.4e (%.4f%% of |E|)\n" r.label de (100de / abs(E_24))
    end

    println("\n--- Grid convergence verdict ---")
    a, b_ = sorted[1], sorted[2]
    gap_32 = b_.E_pol - a.E_pol
    @printf "  Top-2 gap at 32³: %.4e\n" gap_32
    @printf "  24³ gap was: ≈ 0 (4 ansatze degenerate)\n"
    max_de = maximum(abs.([r.E_pol - E_24 for r in sorted]))
    @printf "  Max |E_32 - E_24| / |E| = %.4e\n" (max_de / abs(E_24))
    if max_de / abs(E_24) < 1e-4
        println("  → GRID-CONVERGED at the 1e-4 relative level.")
        println("    24³ result is the actual nonlinear endpoint.")
    else
        println("  → NOT grid-converged. 32³ shifted by > 1e-4 relative.")
        println("    24³ was undersampled; 32³ is the better answer; consider 48³ check.")
    end

    snapshot = [
        Dict(
            "label" => r.label, "E_pol" => r.E_pol, "dE" => r.dE,
            "grad_norm" => r.grad_norm,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi,
            "m_dist" => r.m_dist,
            "windings" => Dict(string(j) => collect(r.windings[j]) for j in 1:5),
        ) for r in sorted
    ]
    @save joinpath(OUT_DIR, "step3_grid32.jld2") snapshot
    @info "Saved Step 3 32³ results"
    println("\n=== Done ===")
end

main()
