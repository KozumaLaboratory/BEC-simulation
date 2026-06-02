#!/usr/bin/env julia
# scripts/sprint5_A1_v3_step3b_grid40.jl
#
# Step 3b — 40³ in the resolution series 24³ → 32³ → 40³.
# Tests whether high-m windings continue to gain weight with refinement
# (G: grid-capping suppressing m=±4/±5 at coarse) or saturate (B: nonlinear
# endpoint genuinely at m=±2).
#
# Diagnostic: m-content weight for m=±2, m=±4, m=±5 (the contested channels)
# vs grid resolution. If weight rises 24→32→40 → G; if flat → B.
#
# Same digital twin geometry. Single ansatz (PCV_BdG, the BdG-prescribed one
# that should preserve m=±4 if it's physically real). Saves jld2 for series
# analysis.
#
# Compute estimate: 40³ has 1.95× more cells than 32³ → ~2.5× per ITP step.
# 20k ITP + 8k LBFGS at ~0.5 sec/step ≈ ~4 h.
#
# Run AFTER Step 3 32³ landed and reviewed.

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
const GRID_40 = make_grid(GridConfig((40, 40, 40), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_ITP = 40000          # 2× more than 32³ to compensate for finer grid
const TOL_ITP = 1e-9
const N_LBFGS = 12000         # 1.5× more LBFGS iterations
const TOL_LBFGS = 1e-10
const SOBOLEV_ALPHA = 0.02    # Sobolev preconditioning for fine 3D grid (40³ box=30, k_max² ≈ 11)
const SEED = 1

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const OUT_DIR = "runs/sprint5_A1_v3_step3b_grid40"

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

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== Step 3b — 40³ grid validity (PCV_BdG seed) ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    sys = SpinSystem(F)

    psi_init = build_PCV_BdG(GRID_40, sys)
    apply_noise!(psi_init, 0.01, SEED, GRID_40)

    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    t0 = time()
    ws_itp, _, E_itp, _, _ = find_ground_state(;
        grid=GRID_40, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        backend=CUDABackend())
    psi_after_itp = Array(ws_itp.state.psi)
    @printf "ITP   E=%.10f (%.1f min)\n" E_itp ((time() - t0) / 60)
    flush(stdout)

    t1 = time()
    res = find_ground_state_lbfgs(;
        grid=GRID_40, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        initial_state=:polar, psi_init=psi_after_itp,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        backend=CUDABackend(), verbose=false,
        sobolev_alpha=SOBOLEV_ALPHA)
    E_pol = res.energy
    ws = res.workspace
    b = energy_decomposition(ws)
    k_sq_dev = CUDA.CuArray(GRID_40.k_squared)
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

    @printf "LBFGS E=%.10f dE=%.3e ‖∇E‖=%.4e step=%d (%.1f min)\n" E_pol res.dE grad_norm res.last_step (
        (time() - t1) / 60
    )
    @printf "E_ddi=%+.4e E_spin=%+.4e f_max=%.4f\n" b.ddi b.spin f_max
    println("\nFull m-population (40³ PCV_BdG endpoint):")
    for c in 1:D
        m = F - c + 1
        @printf "  m=%+d  N_m/N = %.5f\n" m m_dist[c]
    end

    # G-vs-B discriminator: m=±4 weight at 24³, 32³, 40³ series
    println("\n--- m-content series (G vs B discriminator) ---")
    println("(values at 24³ and 32³ come from prior runs; 40³ is this run)")
    m4_40 = m_dist[m_to_c(+4)] + m_dist[m_to_c(-4)]
    m5_40 = m_dist[m_to_c(+5)] + m_dist[m_to_c(-5)]
    m2_40 = m_dist[m_to_c(+2)] + m_dist[m_to_c(-2)]
    println("  m=±4 total weight at 40³: $(round(m4_40; sigdigits=4))")
    println("  m=±5 total weight at 40³: $(round(m5_40; sigdigits=4))")
    println("  m=±2 total weight at 40³: $(round(m2_40; sigdigits=4))")
    println()
    println("Compare to 24³ PCV_BdG endpoint: m=±2 ≈ 0.052, m=±4/±5 ≈ 0")
    println("Compare to 32³ PCV_BdG endpoint: TBD (read step3 log)")

    save_path = joinpath(OUT_DIR, "step3b_grid40.jld2")
    dE_final = res.dE
    last_step = res.last_step
    @save save_path psi_pol m_dist b grad_norm E_pol dE_final last_step
    @info "Saved 40³ result to $save_path"

    println("\n=== Done ===")
end

main()
