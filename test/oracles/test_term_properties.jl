# Consolidated term property suite — docs/design/term_oracle_bootstrap.md.
#
# Week-1 item 1: step0 (FD trust bootstrap, ε-scaling valley, §3) on one
# representative per energy-nonlinearity class, plus a harness canary
# proving the valley detects a planted bug:
#
#   KineticTerm      — quadratic E: central FD exact ⇒ :exact_floor
#   LinearZeemanZ    — quadratic E with nontrivial spin structure
#   DensityC0Term    — quartic E: genuine truncation valley, slope ≈ +2
#
# The Pairing class (singlet c2) has no step0 pair — its gradient face
# is KNOWN-LIMIT nil — and enters at step2 via second-variation
# symmetry (§5). LHY joins at week-1 item 3, where the known defects
# trip (that is the gate working, not a detour).
#
# Growth path (§10–§11): step1 across the registry, step2 by operator
# class, symmetry declarations (§6), canary mutants (§7), collapse gate
# (§9), meta_completeness (§8). This file absorbs
# test_operator_trinity_per_term / four_step_chain /
# test_term_consistency / test_magnetic_gradient_gap as each property
# lands — every absorbed property deletes its old statement in the same
# commit.

using Test
using SpinorBEC
using SpinorBEC: HamTerm, apply_operator!, energy_contribution
using SpinorBEC: KineticTerm, LinearZeemanZTerm, DensityC0Term
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

const VALLEY_MIN = 1e-7        # §3 primary oracle: valley floor reached
const SLOPE_BAND = (1.5, 2.5)  # §3 diagnostic: central-difference order ≈ 2

"""Run the §3 valley for one registry-built term against its own
canonical projection. Returns the `fd_valley` NamedTuple plus (δ, ref)
for reuse by harness canaries."""
function step0_valley(term::HamTerm, ws, psi; rng)
    dV = SpinorBEC.cell_volume(ws.grid)
    g = similar(psi)
    fill!(g, 0)
    apply_operator!(g, term, ws, psi)
    δ, ref = aligned_direction(g, dV, psi; rng)
    E = ψ -> energy_contribution(term, ψ, ws)
    v = fd_valley(E, psi, δ, ref)
    return v, δ, ref
end

@testset "term properties — step0 FD trust bootstrap (§3)" begin
    rng = MersenneTwister(2026)
    ws, psi = oracle_full_ws()

    @testset "KineticTerm (quadratic ⇒ exact floor)" begin
        v, _, _ = step0_valley(registry_term(ws, KineticTerm), ws, psi; rng)
        @test v.kind in (:exact_floor, :valley)
        @test v.min_err < VALLEY_MIN
        v.kind === :valley && @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "LinearZeemanZTerm (quadratic, spin-diagonal)" begin
        v, _, _ = step0_valley(registry_term(ws, LinearZeemanZTerm), ws, psi; rng)
        @test v.kind in (:exact_floor, :valley)
        @test v.min_err < VALLEY_MIN
        v.kind === :valley && @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "DensityC0Term (quartic ⇒ truncation valley, slope ≈ +2)" begin
        v, _, _ = step0_valley(registry_term(ws, DensityC0Term), ws, psi; rng)
        @test v.kind === :valley
        @test v.min_err < VALLEY_MIN
        @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "harness canary: valley detects a planted factor-2 plateau" begin
        # Coherent-mutation surrogate (§7 table, row `coefficient ×2`):
        # feed the valley a reference twice the true projection. A
        # healthy harness must classify this as :plateau at rel ≈ 0.5 —
        # a harness that still reports a valley is a no-op oracle.
        term = registry_term(ws, DensityC0Term)
        dV = SpinorBEC.cell_volume(ws.grid)
        g = similar(psi)
        fill!(g, 0)
        apply_operator!(g, term, ws, psi)
        δ, ref = aligned_direction(g, dV, psi; rng)
        E = ψ -> energy_contribution(term, ψ, ws)
        v = fd_valley(E, psi, δ, 2 * ref)
        @test v.kind === :plateau
        @test v.min_err > 0.3   # plateau height ≈ |1 − 1/2| = 0.5
    end

    @testset "harness canary: sign flip ⇒ plateau at ≈ 2" begin
        term = registry_term(ws, KineticTerm)
        dV = SpinorBEC.cell_volume(ws.grid)
        g = similar(psi)
        fill!(g, 0)
        apply_operator!(g, term, ws, psi)
        δ, ref = aligned_direction(g, dV, psi; rng)
        E = ψ -> energy_contribution(term, ψ, ws)
        v = fd_valley(E, psi, δ, -ref)
        @test v.kind === :plateau
        @test v.min_err > 1.0   # plateau height ≈ |1 − (−1)| = 2
    end
end

@testset "canonical pin — driver ×2 and dV clause (§1, week-1 item 2)" begin
    # The LBFGS driver contract (energy_gradient.jl:67-69): the returned
    # grad is 2·g (Wirtinger ×2), making δE = Re⟨grad, δψ⟩·dV in the
    # standard real inner product. The FD valley measures dE
    # independently: a driver that forgot the ×2 plateaus at 2, a
    # double-applied ×2 plateaus at 0.5. The ×2 is pinned HERE, at the
    # driver — never inside a term face.
    @testset "driver ×2 (energy_gradient!)" begin
        rng = MersenneTwister(7)
        ws, psi = oracle_full_ws()
        dV = SpinorBEC.cell_volume(ws.grid)
        grad = similar(psi)
        SpinorBEC.energy_gradient!(grad, psi, ws)
        δ, _ = aligned_direction(grad, dV, psi; rng)
        # Driver convention prediction (×1 on grad — the 2 lives inside):
        ref_driver = dV * real(sum(conj.(grad) .* δ))
        Efull = ψ -> begin
            copyto!(ws.state.psi, ψ)
            SpinorBEC.energy_decomposition(ws).total
        end
        v = fd_valley(Efull, psi, δ, ref_driver)
        @test v.kind in (:valley, :exact_floor)
        @test v.min_err < VALLEY_MIN
        copyto!(ws.state.psi, psi)   # restore fixture state
    end

    # The dV clause (§1) must be exercised on grids with dV on BOTH
    # sides of 1 — a dropped dV, or a dV in the wrong power, cannot
    # pass both (plateau at dV ratio ≈ 0.296 / 3.375 respectively).
    # Guards against a future "simplification" to a unit-dV fixture
    # silently weakening every valley in this file.
    @testset "dV ≠ 1, both sides (DensityC0 valley)" begin
        rng = MersenneTwister(13)
        for (box, side) in ((4.0, :below), (9.0, :above))
            ws, psi = oracle_full_ws(; box)
            dV = SpinorBEC.cell_volume(ws.grid)
            side === :below && @test dV < 0.5
            side === :above && @test dV > 2.0
            term = registry_term(ws, DensityC0Term)
            g = similar(psi)
            fill!(g, 0)
            apply_operator!(g, term, ws, psi)
            δ, ref = aligned_direction(g, dV, psi; rng)
            E = ψ -> energy_contribution(term, ψ, ws)
            v = fd_valley(E, psi, δ, ref)
            @test v.kind === :valley
            @test v.min_err < VALLEY_MIN
        end
    end
end
