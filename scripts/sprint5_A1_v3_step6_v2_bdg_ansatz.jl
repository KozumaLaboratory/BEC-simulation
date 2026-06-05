#!/usr/bin/env julia
# scripts/sprint5_A1_v3_step6_v2_bdg_ansatz.jl
#
# Step 6 v2 — BdG-prescribed ansatz sweep at Eu Matsui digital twin.
#
# Step 0 Bogoliubov found uniform-inert unstable; I_h unstable eigenmode
# is dominated by m=±1 (29%) + m=±4 secondary (9.8%). LBFGS endpoint
# however has m=0 + m=±1 + tiny m=±2, MISSING the BdG-predicted m=±4
# channel. Step 6 v2 tests the BdG-prescribed ansatz directly.
#
# Ansatz family (homotopy-induced + abelian baselines):
#   - PCV_basic: m=0 core (60%) + m=±1 winding ∓1 (20% each)
#                Approximates the LBFGS-PCV endpoint.
#   - PCV_BdG:   m=0 core (50%) + m=±1 winding ∓1 (25% each)
#                + m=±4 winding ∓4 (5% each), the BdG-prescribed
#                texture. If lower than PCV_basic → LBFGS got stuck.
#   - PCV_full:  m=0 core (40%) + windings ∓j on m=±j for j ∈ {1,4,5,6}
#                following the full BdG amplitudes — most ambitious.
#   - I_h_vortex: I_h spinor base × phase winding ∓5 on m=±5
#                (the I_h-OP × phase, user's polyhedral defect hint).
#
# For each: ITP warmup + LBFGS polish + grad-norm computed post-hoc.
# Verdict gate: ‖∇E‖/‖∇E_ref‖ < 0.01 × gap, not dE_final.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_step6_v2_bdg_ansatz.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const D = 2F + 1
const TW = eu151_preset()
const GRID_24 = TW.grid
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_ITP = 20000
const TOL_ITP = 1e-9
const N_LBFGS = 8000
const TOL_LBFGS = 1e-10
const SEED = 1

const OUT_DIR = "runs/sprint5_A1_v3_step6_v2"

m_to_c(m::Int) = F - m + 1

# Helper: build PCV-style ansatz with arbitrary (m_target → winding × weight) map
function build_pcv_with_channels(grid::Grid, sys::SpinSystem,
    channels::Dict{Int, Tuple{Int, Float64}})
    # channels[m] = (winding_w, sqrt_weight)
    # m=0 (polar core) is added separately with remaining weight
    psi = init_psi(grid, sys; state=:polar)  # polar profile (m=0 only)
    # m=0 envelope = the polar amplitude
    xs = grid.x[1];
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    side_total = sum(abs2.(v[2]) for v in values(channels))
    polar_weight = max(1.0 - side_total, 0.0)
    # Scale m=0 envelope to polar_weight^(1/2)
    for c in 1:D
        psi[:, :, :, c] .*= (c == m_to_c(0) ? sqrt(polar_weight) : 0.0)
    end
    # Now add side channels
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

function build_PCV_basic(grid, sys)
    build_pcv_with_channels(grid, sys, Dict(
        +1 => (-1, 0.30),
        -1 => (+1, 0.30),
    ))
end

function build_PCV_BdG(grid, sys)
    # BdG-prescribed: m=±1 dominant + m=±4 secondary
    # Amplitude scaling: from |u|²+|v|² weights, take sqrt for amplitudes
    # m=±1: 29.4% → amp ≈ √0.29 ≈ 0.54  (use 0.30 as side, leaves m=0 ≈ 64%)
    build_pcv_with_channels(
        grid, sys, Dict(
            +1 => (-1, 0.30),
            -1 => (+1, 0.30),
            +4 => (-4, 0.20),
            -4 => (+4, 0.20),
        )
    )
end

function build_PCV_full(grid, sys)
    # All BdG amplitudes
    build_pcv_with_channels(
        grid,
        sys,
        Dict(
            +1 => (-1, 0.30),
            -1 => (+1, 0.30),
            +4 => (-4, 0.20),
            -4 => (+4, 0.20),
            +5 => (-5, 0.12),
            -5 => (+5, 0.12),
            +6 => (-6, 0.12),
            -6 => (+6, 0.12),
        ),
    )
end

function build_Ih_vortex(grid, sys)
    ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
    psi = init_psi(grid, sys; state=:polar)
    xs = grid.x[1];
    ys = grid.x[2]
    nx, ny, nz = size(psi, 1), size(psi, 2), size(psi, 3)
    for kz in 1:nz, jy in 1:ny, ix in 1:nx
        envelope = sqrt(sum(abs2, view(psi, ix, jy, kz, :)))
        theta = atan(ys[jy], xs[ix])
        for c in 1:D
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

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= n
end

function compute_grad_norm(ws::Workspace, k_squared_dev=nothing)
    # Post-hoc projected gradient norm: ‖P∇E‖ where P removes normalisation direction
    psi = ws.state.psi
    grad = similar(psi)
    fill!(grad, 0.0)
    if k_squared_dev !== nothing
        SpinorBEC.energy_gradient!(grad, psi, ws; k_squared_dev=k_squared_dev)
    else
        SpinorBEC.energy_gradient!(grad, psi, ws)
    end
    dV = SpinorBEC.cell_volume(ws.grid)
    # Projection: grad ← grad - ⟨ψ|grad⟩ψ
    overlap = sum(conj.(psi) .* grad) * dV
    grad .-= overlap .* psi
    sqrt(real(sum(abs2, grad)) * dV)
end

function relax_polish(label::String, psi_init::Array{ComplexF64, 4}, grid::Grid;
    n_itp::Int=N_ITP, n_lbfgs::Int=N_LBFGS)
    sys = SpinSystem(F)
    apply_noise!(psi_init, 0.01, SEED, grid)

    @printf "\n--- %s @ %d³ ---\n" label size(grid.k_squared, 1)
    flush(stdout)

    t0 = time()
    ws_itp, conv_itp, E_itp, _, _ = find_ground_state(;
        grid=grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZEEMAN, potential=TW.potential,
        dt=DT_ITP, n_steps=n_itp, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend())
    psi_after_itp = Array(ws_itp.state.psi)
    @printf "  ITP   E=%.10f conv=%s (%.1f min)\n" E_itp (conv_itp ? "✓" : "✗") ((time() - t0) / 60)

    t1 = time()
    res = find_ground_state_lbfgs(;
        grid=grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=ZEEMAN, potential=TW.potential,
        n_steps=n_lbfgs, tol=TOL_LBFGS,
        initial_state=:polar, psi_init=psi_after_itp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        backend=CUDABackend(), verbose=false)
    t_lbfgs = time() - t1
    E_pol = res.energy
    ws = res.workspace
    b = energy_decomposition(ws)
    # Gradient norm post-hoc
    k_sq_dev = CUDA.CuArray(grid.k_squared)
    grad_norm = compute_grad_norm(ws, k_sq_dev)
    psi_pol = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi_pol, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))

    # Per-m population (LBFGS final state)
    m_dist = zeros(D)
    for c in 1:D
        m_dist[c] = sum(abs2, psi_pol[:, :, :, c])
    end
    m_dist ./= sum(m_dist)

    # Windings at r=4 in midplane
    function winding(c)
        pts = ComplexF64[]
        mid = div(size(psi_pol, 1), 2)
        for theta in range(0, 2π; length=33)[1:(end - 1)]
            i = round(Int, mid + 4 * cos(theta))
            j = round(Int, mid + 4 * sin(theta))
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

    @printf "  LBFGS E=%.10f conv=%s dE=%.3e ‖∇E‖=%.4e step=%d (%.1f min)\n" E_pol (
        res.converged ? "✓" : "✗"
    ) res.dE grad_norm res.last_step (t_lbfgs / 60)
    @printf "  E_ddi=%+.4e E_spin=%+.4e E_kin=%+.4e f_max=%.4f\n" b.ddi b.spin b.kinetic f_max
    print("  windings (r=4, z=mid): ")
    for j in 1:5
        @printf "j=%d:(%+.1f,%+.1f) " j windings[j][1] windings[j][2]
    end
    println()
    print("  m-population top 5: ")
    sorted_m = sortperm(m_dist; rev=true)
    for c in sorted_m[1:5]
        @printf "m=%+d:%.3f " (F-c+1) m_dist[c]
    end
    println()
    CUDA.reclaim()
    return (label=label, E_itp=E_itp, E_pol=E_pol, converged=res.converged,
        dE=res.dE, grad_norm=grad_norm, last_step=res.last_step,
        b=b, f_max=f_max, psi=psi_pol, windings=windings, m_dist=m_dist)
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== Step 6 v2 — BdG-prescribed ansatz at digital twin (24³, with grad_norm) ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    sys = SpinSystem(F)
    results_24 = []

    for (label, builder) in [
        ("PCV_basic", build_PCV_basic),
        ("PCV_BdG", build_PCV_BdG),
        ("PCV_full", build_PCV_full),
        ("I_h_vortex", build_Ih_vortex),
    ]
        psi = builder(GRID_24, sys)
        res = relax_polish(label, psi, GRID_24)
        push!(results_24, res)
    end

    println("\n\n=== 24³ rank (Step 6 v2) ===\n")
    sorted = sort(results_24; by=r -> r.E_pol)
    @printf "%-3s %-14s %-16s %-10s %-10s %-8s %-10s\n" "#" "ansatz" "E_pol" "dE" "‖∇E‖" "f_max" "windings(j=1..3)"
    for (i, r) in enumerate(sorted)
        ws_str = join(
            [@sprintf("(%+.0f,%+.0f)", r.windings[j][1], r.windings[j][2]) for j in 1:3], " "
        )
        @printf "%-3d %-14s %+.8e %.2e %.3e %.4f %s\n" i r.label r.E_pol r.dE r.grad_norm r.f_max ws_str
    end

    # Convergence gate using grad_norm
    println("\n--- Step 1 gate via grad_norm ---")
    a, b = sorted[1], sorted[2]
    gap = b.E_pol - a.E_pol
    max_grad = max(a.grad_norm, b.grad_norm)
    ratio = max_grad / abs(gap)
    @printf "Top-2 gap = %.4e (%.4f%%)\n" gap (100*gap / abs(a.E_pol))
    @printf "max(‖∇E‖) of top-2 = %.4e\n" max_grad
    @printf "Gate test: max ‖∇E‖ / gap = %.4e   (target < 0.01)\n" ratio
    if ratio < 0.01
        println("→ GATE PASSED. Rank safe (grad_norm tight enough).")
    else
        println("→ GATE not passed via grad_norm. Treat rank as preliminary.")
    end

    # Save
    snapshot = [
        Dict(
            "label" => r.label, "E_itp" => r.E_itp, "E_pol" => r.E_pol,
            "converged" => r.converged, "dE" => r.dE, "grad_norm" => r.grad_norm,
            "last_step" => r.last_step,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi,
            "m_dist" => r.m_dist,
            "windings" => Dict(string(j) => collect(r.windings[j]) for j in 1:5),
        ) for r in sorted
    ]
    @save joinpath(OUT_DIR, "step6_v2.jld2") snapshot
    @info "Saved Step 6 v2 result"

    println("\n=== Done (24³ phase) ===")
    println("Next: 32³ grid validity check on the 24³ winner (separate script).")
end

main()
