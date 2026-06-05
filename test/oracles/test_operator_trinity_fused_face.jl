# test/oracles/test_operator_trinity_fused_face.jl
#
# Fused-step propagator face — closes the SECOND historical bug location
# that the per-term Δt→0 oracle in test_operator_trinity_propagator_face.jl
# does NOT cover.
#
# Background: the 2026-06-04 sign cascade (transverse Zeeman / Coriolis /
# GPU energy_decomposition) lived in PRODUCTION CODE PATHS that FUSE
# multiple terms into one exp call:
#
#   `_diagonal_step_svec!`  fuses (V_trap + c0·n + c_lhy·n^(3/2)
#                                  + zeeman_diag + LightShift_diag) into
#                                  ONE per-voxel exp.
#
# A per-term Δt→0 check that decomposes the exp BACK into individual
# operators would PASS even if the production fused code is buggy —
# because the per-term test reconstructs the operator from the term's
# `apply_step!` (which uses a different code path than the fused one).
#
# To close this, we directly test the FUSED step:
#
#   (fused_step!(Δt, ψ) − ψ) / (−i·Δt)  ≈  Σ_term apply_operator!(term, ψ)
#
# at small Δt, where the sum runs over all terms folded into the fused
# step. This is the load-bearing oracle for production correctness.

using Test
using SpinorBEC
using SpinorBEC: apply_operator!, _diagonal_step_svec!
using SpinorBEC:
    TrapTerm, LinearZeemanZTerm, DensityC0Term, LHYTerm, LightShiftTerm
using LinearAlgebra
using StaticArrays
using Random

@testset "Fused diagonal step ↔ Σ term operators (Δt → 0)" begin
    @testset "c0 + c_lhy + zeeman_z (3-way fusion, no light_shift)" begin
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.5, 1 => 0.0); c_lhy=0.3)
        zeeman = ZeemanParams(0.2, 0.05)
        sp = SimParams(; dt=1e-4, n_steps=1, imaginary_time=false,
            normalize_every=0)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
        dV = SpinorBEC.cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)

        # Build sum-of-operators reference:
        # H_fused = V_trap + c0·n + c_lhy·n^(3/2) + LinearZeemanZ
        Hpsi_sum = zero(psi)
        buf = similar(psi)
        for term in (TrapTerm(), DensityC0Term(0.5), LHYTerm(),
            LinearZeemanZTerm(0.2, 0.05))
            fill!(buf, 0)
            apply_operator!(buf, term, ws, psi)
            Hpsi_sum .+= buf
        end

        # Apply the fused diagonal step. Signature follows
        # _diagonal_step_svec!(::Val{N}, psi, V_trap, zeeman_diag::SVector,
        #                      c0, c_lhy, dt_frac, density_buf, imaginary_time)
        psi_evolved = copy(psi)
        # Build zeeman_diag SVector. zeeman_z gives diag entries -p·m + q·m².
        F = 1
        D = 2F + 1
        z_diag = SVector{D, Float64}(
            ntuple(c -> -0.2 * (F - (c - 1)) + 0.05 * (F - (c - 1))^2, Val(D)))
        # c_lhy from interactions
        c_lhy = ws.interactions.c_lhy
        density_buf = zeros(Float64, 8)
        dt = 1e-4
        _diagonal_step_svec!(
            Val(1), psi_evolved, ws.potential_values, z_diag,
            ws.interactions[0], c_lhy, dt, density_buf, false)

        # Δt → 0 limit: (psi_evolved − psi) / (−i·dt) ≈ H·ψ
        deriv = (psi_evolved .- psi) ./ (-im * dt)
        residual = sqrt(sum(abs2, deriv .- Hpsi_sum) * dV)
        ref = sqrt(sum(abs2, Hpsi_sum) * dV)
        rel = residual / max(ref, 1e-30)
        @test rel < 1e-2  # O(dt) truncation at dt=1e-4 ⇒ ~1e-4 residual
    end

    @testset "Same fused step at imaginary_time = true" begin
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.5, 1 => 0.0); c_lhy=0.3)
        zeeman = ZeemanParams(0.2, 0.05)
        sp = SimParams(; dt=1e-4, n_steps=1, imaginary_time=true,
            normalize_every=0)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
        dV = SpinorBEC.cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)

        Hpsi_sum = zero(psi)
        buf = similar(psi)
        for term in (TrapTerm(), DensityC0Term(0.5), LHYTerm(),
            LinearZeemanZTerm(0.2, 0.05))
            fill!(buf, 0)
            apply_operator!(buf, term, ws, psi)
            Hpsi_sum .+= buf
        end

        psi_evolved = copy(psi)
        F = 1;
        D = 2F + 1
        z_diag = SVector{D, Float64}(
            ntuple(c -> -0.2 * (F - (c - 1)) + 0.05 * (F - (c - 1))^2, Val(D)))
        density_buf = zeros(Float64, 8)
        dt = 1e-4
        _diagonal_step_svec!(
            Val(1), psi_evolved, ws.potential_values, z_diag,
            ws.interactions[0], ws.interactions.c_lhy, dt, density_buf, true)

        # ITP limit: (psi_evolved − psi) / (−dt) ≈ H·ψ
        # NOTE: the IT diagonal step uses an overflow shift (subtracts
        # min(zeeman_diag) from the per-component coef). Compare residual
        # in the shifted frame: actual H acts as `diag − shift`. We test
        # the residual relative to the SHIFTED reference (subtract the
        # uniform-on-spin shift from Hpsi_sum's zeeman piece).
        shift = minimum(z_diag)
        # Build shifted reference by re-summing with shifted Zeeman:
        Hpsi_shifted = zero(psi)
        for term in (TrapTerm(), DensityC0Term(0.5), LHYTerm())
            fill!(buf, 0)
            apply_operator!(buf, term, ws, psi)
            Hpsi_shifted .+= buf
        end
        # Shifted zeeman_z action
        for c in 1:D
            coef = -0.2 * (F - (c - 1)) + 0.05 * (F - (c - 1))^2 - shift
            view(Hpsi_shifted, :, c) .+= coef .* view(psi, :, c)
        end

        deriv = (psi_evolved .- psi) ./ (-dt)
        residual = sqrt(sum(abs2, deriv .- Hpsi_shifted) * dV)
        ref = sqrt(sum(abs2, Hpsi_shifted) * dV)
        rel = residual / max(ref, 1e-30)
        @test rel < 1e-2
    end
end
