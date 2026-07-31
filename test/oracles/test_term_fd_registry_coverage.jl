using Test
using SpinorBEC
using SpinorBEC: H_TERMS_CANONICAL_ORDER, build_h_terms_registry,
    energy_contribution, apply_operator!, cell_volume, LossTerm
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

# `apply_operator!` IS the derivative of `energy_contribution` — for every slot
# of the registry, not for the three that happened to get a test.
#
# `test_term_consistency.jl` opens with "For every HamTerm" and "Running this
# for every term in the HamTerm registry is the CI gate that makes the bug
# class structurally impossible". It runs Zeeman, Tensor and SpatialZeeman:
# 3 of 14. `test_term_properties.jl` adds Kinetic, DensityC0 and Raman as
# ε-valleys. The other eight slots — Trap, SpinC1, DDI, LHY, LightShift,
# Coriolis, MagneticGradient and the transverse Zeeman branch — have never had
# their energy face differenced against their gradient face.
#
# That is not the same claim as the master oracle's. `test_master_oracle.jl`
# does reach all fourteen, but it compares production against the dumb
# reference: it would pass with both sides carrying the same wrong gradient,
# because the dumb reference states the gradient too. Only the FD identity ties
# the gradient to the ENERGY, which is what the optimiser descends.
#
# The gate has two halves, and the second is the load-bearing one:
#
#   1. per (fixture, active term), the ε-scaling residual must be a healthy
#      valley or an exact floor — a plateau is an h-independent disagreement,
#      i.e. a real factor/sign bug (`fd_gradient.jl` §3);
#   2. the union of slots actually differenced must equal the canonical order
#      minus the declared exclusions. Without this, a fixture that quietly
#      stops activating a term takes its coverage with it and the suite stays
#      green — which is exactly how "for every HamTerm" came to mean three.
#
# One slot is excluded: `:loss`. `LossTerm` is non-Hermitian and declares both
# faces nil on purpose (`apply_operator!(out, ::LossTerm, …) = out`,
# `energy_contribution = 0.0`), so there is no variational gradient to
# difference. Non-unitarity is gated by `oracles/test_loss_nonunitarity.jl`, and
# the ratchet below keeps the exclusion honest.
#
# `:raman` was the other one when this file landed: it had an energy and a nil
# gradient, so L-BFGS descended a functional excluding the Raman term while
# `total_energy` reported one including it. The gradient landed 2026-07-31 and
# the slot is now differenced like every other.
const _FD_EXCLUDED = Set([:loss])

# A term is exercised here only if it actually acts on this fixture's ψ. The
# threshold is on ‖g‖ relative to ‖ψ‖, so it does not silently pass a term
# whose gradient is merely small.
function _fd_check_fixture(name, ws, psi; rng)
    dV = cell_volume(ws.grid)
    covered = Set{Symbol}()
    for (slot, term) in zip(H_TERMS_CANONICAL_ORDER, build_h_terms_registry(ws))
        slot in _FD_EXCLUDED && continue
        g = zero(psi)
        apply_operator!(g, term, ws, psi)
        rel = sqrt(sum(abs2, g)) / sqrt(sum(abs2, psi))
        rel > 1.0e-10 || continue          # inactive in this fixture
        δ, ref = aligned_direction(g, dV, psi; rng)
        E = ψ -> energy_contribution(term, ψ, ws)
        v = fd_valley(E, psi, δ, ref)
        @testset "$name / $slot" begin
            # A plateau is the bug signature: the disagreement does not shrink
            # with h, so it is not truncation. Its magnitude reads off the
            # defect (≈0.5 for a factor 2, ≈2 for a sign flip).
            @test v.kind in (:exact_floor, :valley)
            v.kind === :valley && @test v.min_err < 1.0e-7
        end
        push!(covered, slot)
    end
    return covered
end

@testset "energy ≡ ∂(gradient) for every registry slot" begin
    rng = MersenneTwister(20260731)
    covered = Set{Symbol}()

    @testset "fixture: full (3D, DDI + LHY + rotating frame)" begin
        ws, psi = oracle_full_ws()
        union!(covered, _fd_check_fixture("full", ws, psi; rng))
    end

    @testset "fixture: aux (1D, MG + light shift + Raman + c2)" begin
        ws, psi = aux_ws()
        union!(covered, _fd_check_fixture("aux", ws, psi; rng))
    end

    @testset "fixture: omega_R (1D, spin rotating frame, t ≠ 0)" begin
        ws, psi = omega_R_ws()
        union!(covered, _fd_check_fixture("omega_R", ws, psi; rng))
    end

    # Two fixtures the shared helpers do not provide (their own docstring
    # carries the TODO). Lifted from `test_term_consistency.jl`, which FD-checks
    # both but outside any coverage claim.
    @testset "fixture: tensor (F=6 Eu, higher-rank channels)" begin
        gr = make_grid(GridConfig((4, 4, 4), (4.0, 4.0, 4.0)))
        ws = make_workspace(;
            grid=gr, atom=Eu151,
            interactions=InteractionParams(
                Dict(0 => 1.0, 1 => 0.1, 4 => 0.2, 6 => 0.15, 10 => 0.1, 12 => 0.08)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
        )
        rng2 = MersenneTwister(7)
        psi = randn(rng2, ComplexF64, 4, 4, 4, 13)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(gr))
        union!(covered, _fd_check_fixture("tensor", ws, psi; rng))
    end

    @testset "fixture: spatial_zeeman (arbitrary B(r), all four components)" begin
        gr = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        field = spatial_zeeman_field(gr;
            bz=(x, y, z) -> 0.5 + 0.1x,
            bx=(x, y, z) -> 0.3 - 0.05y,
            by=(x, y, z) -> 0.05z,
            q=(x, y, z) -> 0.1 + 0.02x^2)
        ws = make_workspace(;
            grid=gr, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            spatial_zeeman=field,
        )
        rng2 = MersenneTwister(7)
        psi = randn(rng2, ComplexF64, 8, 8, 8, 3)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(gr))
        union!(covered, _fd_check_fixture("spatial_zeeman", ws, psi; rng))
    end

    # Ratchet on the excluded slot: nil on BOTH faces is what earns an
    # exclusion. A slot with an energy and no gradient does not — that was
    # `:raman` until its gradient landed.
    @testset "ratchet: :loss is nil on both faces" begin
        ws, psi = aux_ws()
        term = registry_term(ws, SpinorBEC.LossTerm)
        g = zero(psi)
        apply_operator!(g, term, ws, psi)
        @test sqrt(sum(abs2, g)) == 0.0
        @test energy_contribution(term, psi, ws) == 0.0
    end

    @testset "coverage: every slot differenced, or declared excluded" begin
        want = setdiff(Set(H_TERMS_CANONICAL_ORDER), _FD_EXCLUDED)
        missing_slots = sort(collect(setdiff(want, covered)))
        isempty(missing_slots) || @info(
            "slots with no ACTIVE fixture — the FD identity is unchecked for " *
                "them; add a fixture, do not add an exclusion",
            missing_slots
        )
        @test isempty(missing_slots)
        # And nothing outside the canonical order sneaks in.
        @test issubset(covered, Set(H_TERMS_CANONICAL_ORDER))
    end
end
