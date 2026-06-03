#!/usr/bin/env julia
# scripts/m1_per_term_gradient_audit.jl
#
# Per-term gradient ↔ energy consistency audit at the B=0/Ω=0.4 plateau ψ.
#
# Context: at the stalled state, `Re⟨grad, P_⊥∇E⟩ = R² = 0.0476` to 16
# sig figs, but the direct FD slope `(E(ψ+ε·proj) − E(ψ))/ε` along the
# same direction is ~2.2e−4 — 220× smaller. For δψ=ψ and δψ=random the
# ratio is O(1). Conclusion: one or more terms in `energy_gradient!`
# disagree with their counterpart in `energy_decomposition` SPECIFICALLY
# along the projected-residual direction.
#
# This audit isolates per-term contributions. For each term T ∈
# {kinetic, trap, zeeman, density (c0), spin (c1), ddi, coriolis}:
#
#   inner_T   = Re⟨ 2·δE_T/δψ*, proj ⟩
#               (built by calling SpinorBEC._grad_T! on a fresh zero
#                buffer, then ×2 per the energy_gradient! convention)
#
#   fd_T(ε)   = (E_T(ψ + ε·proj) − E_T(ψ)) / ε
#               (read from `energy_decomposition(ws).T` after copying
#                the perturbed ψ into ws.state.psi)
#
# Taylor demands `inner_T == lim_{ε→0} fd_T(ε)` for each T. The term
# where they disagree is the bug.
#
# Cost: ~7 gradient calls + ~14 energy evaluations on the 24³×13 grid;
# under a minute on GPU.

import CUDA
using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const CACHED_PATH = "runs/sprint5_M1_basin_valley_B0.0_Om0.4.jld2"
const ε_FD = 1e-5

function main()
    println("=== M1 per-term gradient ↔ energy audit ===")
    println("Cell: B=0 nT, Ω=0.4, seed: :polar, backend: CUDA")
    println("ε for FD: $ε_FD\n")

    cached = JLD2.load(CACHED_PATH)
    psi_cached = cached["psi_polar"]
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(0.0), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)

    r_warm = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential, dt=0.005, n_steps=1, tol=0.0,
        initial_state=:polar, verbose=false, psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=0.4, backend=CUDABackend(),
    )
    ws = r_warm.workspace
    copyto!(ws.state.psi, psi_cached)
    psi_cpu = copy(psi_cached)
    psi_dev = copy(ws.state.psi)

    # --- Step 1: build the total gradient and the projection direction proj. ---
    k2_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    grad_dev = similar(ws.state.psi)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev=k2_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi_cpu) * dV
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / psi_norm²
    proj_cpu = grad_cpu .- μ .* psi_cpu
    R² = real(sum(abs2, proj_cpu)) * dV
    @printf "‖P_⊥∇E‖²_L² = %.6e\n" R²
    @printf "FD step ‖ε·proj‖ = %.3e (well below kinetic scale)\n\n" ε_FD * sqrt(R²)

    # --- Step 2: per-term grad and per-term FD ---
    # Construct each term's δE_T/δψ* contribution by zeroing a fresh
    # buffer and calling the appropriate helper. Each helper accumulates
    # into the passed grad; calling on a zero buffer gives JUST that term.
    n_pts = ntuple(d -> size(psi_dev, d), Val(3))
    D_eu = ws.spin_matrices.system.n_components

    function single_term_grad!(grad_buf, term::Symbol)
        fill!(grad_buf, 0)
        copyto!(ws.state.psi, psi_dev)
        # Build scratch buffers per term as needed (mirrors energy_gradient.jl).
        if term === :kinetic
            fft_buf = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_kinetic!(
                grad_buf, ws.state.psi, ws, fft_buf, k2_dev, n_pts, D_eu, Val(3)
            )
        elseif term === :trap
            SpinorBEC._grad_trap!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :zeeman
            SpinorBEC._grad_zeeman!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :density
            n_density = SpinorBEC.total_density(ws.state.psi, 3)
            SpinorBEC._grad_c0_density!(grad_buf, ws.state.psi, ws, n_density, n_pts, D_eu, Val(3))
        elseif term === :spin
            fx = similar(grad_buf, ComplexF64, n_pts...)
            fy = similar(grad_buf, ComplexF64, n_pts...)
            fz = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_c1_spin!(grad_buf, ws.state.psi, ws, fx, fy, fz, n_pts, D_eu, Val(3))
        elseif term === :ddi
            SpinorBEC._grad_ddi!(grad_buf, ws.state.psi, ws, n_pts, D_eu, Val(3))
        elseif term === :coriolis
            fft_buf = similar(grad_buf, ComplexF64, n_pts...)
            deriv_buf = similar(grad_buf, ComplexF64, n_pts...)
            SpinorBEC._grad_coriolis!(
                grad_buf, ws.state.psi, ws, fft_buf, deriv_buf, n_pts, D_eu, Val(3)
            )
        else
            error("unknown term $term")
        end
        # Apply the ×2 complex-convention scaling (per energy_gradient.jl:88).
        grad_buf .*= 2
    end

    function E_term_at(psi_arr, term::Symbol)
        copyto!(ws.state.psi, psi_arr)
        ed = SpinorBEC.energy_decomposition(ws)
        return ed[term]
    end

    terms = [:kinetic, :trap, :zeeman, :density, :spin, :ddi, :coriolis]
    grad_buf = similar(ws.state.psi)
    proj_dev = SpinorBEC._to_device(ws.backend, proj_cpu)
    psi_plus_dev = similar(ws.state.psi)

    println("--- Per-term Re⟨grad_T, proj⟩ vs FD ΔE_T/ε ---")
    @printf "%10s  %14s  %14s  %12s\n" "term" "Re⟨g_T,proj⟩" "FD ΔE_T/ε" "ratio FD/inner"
    inner_total = 0.0
    fd_total = 0.0
    for term in terms
        single_term_grad!(grad_buf, term)
        grad_term_cpu = Array(grad_buf)
        inner_T = real(sum(conj.(grad_term_cpu) .* proj_cpu)) * dV

        # FD: E_T at ψ vs ψ + ε·proj
        E_T_0 = E_term_at(psi_dev, term)
        psi_plus_dev .= psi_dev .+ ε_FD .* proj_dev
        E_T_eps = E_term_at(psi_plus_dev, term)
        fd_T = (E_T_eps - E_T_0) / ε_FD

        ratio = inner_T != 0 ? fd_T / inner_T : NaN
        @printf "%10s  %+.6e  %+.6e  %+.4e\n" string(term) inner_T fd_T ratio
        inner_total += inner_T
        fd_total += fd_T
    end
    println("-"^60)
    @printf "%10s  %+.6e  %+.6e  %+.4e\n" "TOTAL" inner_total fd_total (fd_total / inner_total)
    println()

    println("Interpretation:")
    println("  ratio ≈ 1   → term is FD-consistent at this state along proj")
    println("  ratio ≪ 1   → term's grad overstates dE/dε along proj")
    println("  ratio ≫ 1   → term's grad understates dE/dε along proj")
    println("  ratio < 0   → SIGN BUG (grad and energy point opposite ways)")
end

main()
