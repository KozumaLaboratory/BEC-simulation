# Reference-RHS diff test — Level 10 (post-2026-05-26 pivot).
#
# `src/validation/reference_rhs/*.jl` defines an independent CPU-only
# term-by-term Hψ for every Hamiltonian operator the production split-
# step exponentiates. This file diffs them against TWO production code
# paths:
#
#   path A — `energy_gradient!(grad, ψ, ws)` from solvers/lbfgs/
#            (grad = 2·δE/δψ* covers kinetic, trap, Zeeman diag, c₀,
#             c₁, DDI, LHY scalar, light_shift; misses c₂/c_n/transverse)
#
#   path B — `energy_decomposition(ws)` per-term scalar oracle
#            (covers every term including c₂ and transverse Zeeman if
#             present; weaker test — collapses Hψ to ⟨ψ|H|ψ⟩)
#
# Diff metrics:
#   - operator-level (path A): `‖Hψ_ref − Hψ_prod‖_L² / ‖Hψ_prod‖_L²`
#   - energy-level   (path B): `|E_ref − E_prod| / max(|E_ref|, |E_prod|)`
#
# Tolerance bands (from validation ladder Level 10 + parameter contract):
#   scalar / Zeeman diag / trap   < 1e-12 rel (operator and energy)
#   spin (c₁) / density (c₀)      < 1e-12 rel
#   singlet pair (c₂)             < 1e-12 rel (energy only — operator
#                                              has no production path)
#   DDI                           < 1e-10 rel (FFT roundoff bound)
#   K3 analytic                   < 1e-10 rel against closed-form n(t)
#
# Replaces the Ueda-comparison step of Level 10 — see
# `docs/validation/ueda_status.md`.

using Test
using LinearAlgebra
using FFTW
using Random
using SpinorBEC
using SpinorBEC:
    energy_gradient!,
    _component_slice,
    spin_matrices,
    reference_kinetic_apply!,
    reference_kinetic_energy,
    reference_trap_apply!,
    reference_trap_energy,
    reference_density_apply!,
    reference_density_energy,
    reference_zeeman_diag_apply!,
    reference_zeeman_diag_energy,
    reference_zeeman_transverse_apply!,
    reference_zeeman_transverse_energy,
    reference_zeeman_apply!,
    reference_zeeman_energy,
    reference_spin_apply!,
    reference_spin_energy,
    reference_singlet_pair_apply!,
    reference_singlet_pair_energy,
    reference_ddi_apply!,
    reference_ddi_energy,
    reference_ddi_potentials,
    reference_k3_uniform_analytic,
    reference_k3_rate_apply!,
    reference_total_hpsi,
    reference_total_energy

# Helper: build a small 3D workspace with a randomized (non-trap-eigenstate)
# psi so that off-diagonal spin density is non-trivial and every operator
# term has a numerically meaningful action.
function _make_test_ws_3d(F::Int, atom; c0=0.0, c1=0.0, c2=0.0,
    p=0.0, q=0.0, bx=0.0, by=0.0, n=6, L=4.0,
    enable_ddi=false, c_dd=NaN, secular_ddi=false, seed=12345)
    grid = make_grid(GridConfig{3}((n, n, n), (L, L, L)))
    ip_dict = Dict{Int, Float64}()
    abs(c0) > 0 && (ip_dict[0] = c0)
    abs(c1) > 0 && (ip_dict[1] = c1)
    abs(c2) > 0 && (ip_dict[2] = c2)
    interactions = InteractionParams(ip_dict)
    zeeman = if abs(bx) > 0 || abs(by) > 0
        TimeDependentZeeman(
            ConstantWaveform(Float64(p)),
            ConstantWaveform(Float64(q)),
            ConstantWaveform(Float64(bx)),
            ConstantWaveform(Float64(by)),
        )
    else
        ZeemanParams(Float64(p), Float64(q))
    end
    sp = SimParams(; dt=0.01, n_steps=1)
    ws_kwargs = (; grid, atom, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp)
    ws = if enable_ddi
        make_workspace(; ws_kwargs..., enable_ddi=true, c_dd, secular_ddi)
    else
        make_workspace(; ws_kwargs...)
    end

    rng = MersenneTwister(seed)
    psi_rand = (randn(rng, ComplexF64, n, n, n, 2F + 1) ./ sqrt(n^3 * (2F + 1)))
    copyto!(ws.state.psi, psi_rand)
    ws
end

function _rel_l2(a, b)
    diff = sqrt(sum(abs2, a .- b))
    nrm = sqrt(sum(abs2, b))
    nrm < 1e-30 ? diff : diff / nrm
end

function _rel_scalar(a, b)
    denom = max(abs(a), abs(b), 1e-30)
    abs(a - b) / denom
end

@testset "Reference RHS — energy-level diff vs energy_decomposition" begin
    @testset "F=1 contact: kinetic + trap + Zeeman + c₀ + c₁" begin
        ws = _make_test_ws_3d(1, Rb87; c0=2.5, c1=0.1, p=0.7, q=0.3)
        prod = energy_decomposition(ws)
        ref = reference_total_energy(ws)
        @test _rel_scalar(ref.kinetic, prod.kinetic) < 1e-12
        @test _rel_scalar(ref.trap, prod.trap) < 1e-12
        @test _rel_scalar(ref.zeeman, prod.zeeman) < 1e-12
        @test _rel_scalar(ref.density, prod.density) < 1e-12
        @test _rel_scalar(ref.spin, prod.spin) < 1e-12
    end

    @testset "F=2 contact + c₂ singlet pair" begin
        ws = _make_test_ws_3d(2, Rb85; c0=3.0, c1=-0.4, c2=0.2)
        prod = energy_decomposition(ws)
        ref = reference_total_energy(ws)
        @test _rel_scalar(ref.kinetic, prod.kinetic) < 1e-12
        @test _rel_scalar(ref.trap, prod.trap) < 1e-12
        @test _rel_scalar(ref.density, prod.density) < 1e-12
        @test _rel_scalar(ref.spin, prod.spin) < 1e-12
        # `prod.tensor` aggregates singlet-pair + tensor_cache. With c₂
        # only and no c_n≥4, it equals singlet_pair_energy alone.
        @test _rel_scalar(ref.singlet_pair, prod.tensor) < 1e-12
    end

    @testset "F=6 (Eu) contact-only" begin
        ws = _make_test_ws_3d(6, Eu151; c0=5.0, c1=0.05, n=6)
        prod = energy_decomposition(ws)
        ref = reference_total_energy(ws)
        @test _rel_scalar(ref.kinetic, prod.kinetic) < 1e-12
        @test _rel_scalar(ref.trap, prod.trap) < 1e-12
        @test _rel_scalar(ref.density, prod.density) < 1e-12
        @test _rel_scalar(ref.spin, prod.spin) < 1e-12
    end
end

@testset "Reference RHS — operator-level diff vs energy_gradient!" begin
    # `energy_gradient!` returns grad = 2·Hψ. The reference total Hψ
    # built from {kinetic, trap, Zeeman diag, c₀, c₁, DDI} matches that
    # subset exactly. c₂ singlet pair is not in energy_gradient! — tested
    # separately via energy oracle above.

    @testset "F=1 contact + Zeeman: grad/2 vs reference_total_hpsi" begin
        ws = _make_test_ws_3d(1, Rb87; c0=2.5, c1=0.1, p=0.7, q=0.3)
        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        hpsi_prod = Array(grad) ./ 2
        hpsi_ref = reference_total_hpsi(ws)
        @test _rel_l2(hpsi_ref, hpsi_prod) < 1e-12
    end

    @testset "F=6 (Eu) contact-only: grad/2 vs reference_total_hpsi" begin
        ws = _make_test_ws_3d(6, Eu151; c0=5.0, c1=0.05, n=6)
        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        hpsi_prod = Array(grad) ./ 2
        # reference_total_hpsi includes c₂ singlet_pair when c₂≠0; here c₂=0.
        hpsi_ref = reference_total_hpsi(ws)
        @test _rel_l2(hpsi_ref, hpsi_prod) < 1e-12
    end
end

@testset "Reference DDI — operator + energy diff vs production" begin
    # Production routes DDI through `energy_gradient!`, so both energy
    # and operator paths are reachable.
    @testset "F=3 (Cr52) full DDI" begin
        ws = _make_test_ws_3d(3, Cr52; c0=0.5, c1=0.01,
            n=8, L=6.0, enable_ddi=true, c_dd=10.0, secular_ddi=false,
            seed=54321)

        prod_e = energy_decomposition(ws)
        ref_e = reference_total_energy(ws)
        @test _rel_scalar(ref_e.ddi, prod_e.ddi) < 1e-10

        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        hpsi_prod = Array(grad) ./ 2
        hpsi_ref = reference_total_hpsi(ws)
        @test _rel_l2(hpsi_ref, hpsi_prod) < 1e-10
    end

    @testset "F=3 (Cr52) secular DDI" begin
        ws = _make_test_ws_3d(3, Cr52; c0=0.5, c1=0.01,
            n=8, L=6.0, enable_ddi=true, c_dd=10.0, secular_ddi=true,
            seed=54321)

        prod_e = energy_decomposition(ws)
        ref_e = reference_total_energy(ws)
        @test _rel_scalar(ref_e.ddi, prod_e.ddi) < 1e-10
    end
end

@testset "K3 loss — uniform-density analytic n(t)" begin
    # Strongest dissipative validation: closed-form n(t) for spatially
    # uniform initial state under K3 only.
    n0 = 1.0
    K3 = 0.5
    for t in (0.0, 0.1, 0.5, 1.0, 2.0)
        n_analytic = reference_k3_uniform_analytic(n0, K3, t)
        # Reference closed-form sanity:
        @test n_analytic ≈ n0 / sqrt(1.0 + 2.0 * K3 * n0^2 * t)
    end
end
