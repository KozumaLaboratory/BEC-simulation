# Master oracle: dumb reference vs production registry, per term.
#
# The mechanism behind architectural commitment #3 (zero silent sign
# drift via day-0 gated redundancy): every slot of
# H_TERMS_CANONICAL_ORDER is compared — energy and RHS — between the
# production faces (energy_contribution / apply_operator!) and the
# independent dumb statements (src/validation/dumb_reference.jl), at
# identity-class tolerance on the same discrete mathematics.
#
# Gap discipline (arch doc §4 KNOWN-LIMIT row):
# - DUMB_DEFERRED_SLOTS (:ddi,) — dumb statement deferred to its own
#   unit; explicitly skipped, never silently.
# - PRODUCTION_RHS_GAPS (:raman, :tensor) — production apply_operator!
#   is declared-nil; the oracle asserts BOTH sides of the gap
#   (production ≡ 0 AND dumb ≠ 0 when active), so the gap closing or
#   widening is a test event either way.
#
# Set-equivalence meta-test: the dumb breakdown covers exactly the
# canonical slot list — a term added to the registry without a dumb
# statement (or vice versa) is a red, not a silent hole.

using Test
using SpinorBEC
using SpinorBEC: HamTerm, apply_operator!, energy_contribution,
    H_TERMS_CANONICAL_ORDER, build_h_terms_registry
using SpinorBEC: dumb_energy_breakdown, dumb_rhs_breakdown, DUMB_DEFERRED_SLOTS
using SpinorBEC: KineticTerm, TrapTerm, LinearZeemanZTerm, TransverseZeemanTerm,
    DensityC0Term, SpinC1Term, DDITerm, LHYTerm, TensorTerm, RamanTerm,
    LightShiftTerm, CoriolisTerm, MagneticGradientTerm, LossTerm
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

const SLOT_TERM = (;
    kinetic=KineticTerm, trap=TrapTerm, zeeman_z=LinearZeemanZTerm,
    zeeman_transverse=TransverseZeemanTerm, density_c0=DensityC0Term,
    spin_c1=SpinC1Term, ddi=DDITerm, lhy=LHYTerm, tensor=TensorTerm,
    raman=RamanTerm, light_shift=LightShiftTerm, coriolis=CoriolisTerm,
    magnetic_gradient=MagneticGradientTerm, loss=LossTerm,
)

const PRODUCTION_RHS_GAPS = (:raman, :tensor)

const E_RTOL = 1e-10
const E_ATOL = 1e-12
const G_RTOL = 1e-10
const G_ATOL = 1e-11

# `aux_ws` (the MG/light-shift/Raman/c2 fixture) lives in
# test/helpers/oracle_fixtures.jl — shared with the propagator
# reference suite.

function compare_all_slots(ws, ψ, label)
    Ed = dumb_energy_breakdown(ws, ψ)
    Gd = dumb_rhs_breakdown(ws, ψ)
    registry = build_h_terms_registry(ws)
    for slot in H_TERMS_CANONICAL_ORDER
        slot in DUMB_DEFERRED_SLOTS && continue
        T = getfield(SLOT_TERM, slot)
        term = nothing
        for t in registry
            t isa T && (term = t)
        end
        @testset "$label / $slot" begin
            @test term !== nothing
            # energy face
            Ef = energy_contribution(term, ψ, ws)
            @test isapprox(Ed[slot], Ef; rtol=E_RTOL, atol=E_ATOL)
            # RHS face
            g = similar(ψ)
            fill!(g, 0)
            apply_operator!(g, term, ws, ψ)
            if slot in PRODUCTION_RHS_GAPS
                @test sqrt(sum(abs2, g)) < 1e-12          # production declared-nil
                dumb_active = sqrt(sum(abs2, Gd[slot])) > 1e-10
                if abs(Ed[slot]) > 1e-12
                    @test dumb_active                      # dumb side sees the gap
                end
            else
                @test isapprox(g, Gd[slot]; rtol=G_RTOL, atol=G_ATOL)
            end
        end
    end
end

@testset "master oracle — dumb vs production, per term" begin
    @testset "set-equivalence meta-test" begin
        ws, psi = aux_ws()
        Ed = dumb_energy_breakdown(ws, psi)
        Gd = dumb_rhs_breakdown(ws, psi)
        @test Tuple(keys(Ed)) == H_TERMS_CANONICAL_ORDER
        @test Tuple(keys(Gd)) == H_TERMS_CANONICAL_ORDER
        @test DUMB_DEFERRED_SLOTS == (:ddi,)
        for s in DUMB_DEFERRED_SLOTS
            @test s in H_TERMS_CANONICAL_ORDER
        end
    end

    @testset "fixture A (3D, full): kinetic/trap/zeeman/c0/c1/lhy/coriolis" begin
        rng = MersenneTwister(2026)
        ws, psi = oracle_full_ws()
        compare_all_slots(ws, psi, "A:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "A:random")
    end

    @testset "fixture B (1D, aux): mg/light_shift/raman/c2-singlet" begin
        rng = MersenneTwister(7)
        ws, psi = aux_ws()
        compare_all_slots(ws, psi, "B:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "B:random")
    end

    # Dumb-internal variational identity: the dumb energy and dumb RHS
    # of one slot must satisfy dE/dh = 2·dV·Re⟨g, δ⟩ — the FD valley,
    # run against the DUMB side only. Notably includes the PAIRING term
    # (conjugate-linear RHS), which production cannot check (its RHS is
    # a declared gap).
    #
    # State choice: GENERIC (random off-manifold), not the coherent
    # fixture state — spin-coherent states are exactly singlet-free
    # (F=1: 2ψ₊ψ₋ − ψ₀² ≡ 0), so the pairing slot's g and dE/dh both
    # degenerate to roundoff there and the valley measures 0/0. The
    # signal precondition below turns that degeneracy into a loud
    # failure instead of a misleading plateau.
    @testset "dumb-internal FD valley (incl. pairing)" begin
        rng = MersenneTwister(31)
        ws, _ = aux_ws()
        dV = SpinorBEC.cell_volume(ws.grid)
        ψv = rand_offmanifold_state(ws; rng)
        for slot in (:density_c0, :raman, :tensor)
            Gd = dumb_rhs_breakdown(ws, ψv)
            g = Gd[slot]
            @testset "$slot" begin
                @test sqrt(sum(abs2, g)) > 1e-8   # slot active AND state non-degenerate
                δ, ref = aligned_direction(g, dV, ψv; rng)
                E = ψ -> dumb_energy_breakdown(ws, ψ)[slot]
                v = fd_valley(E, ψv, δ, ref)
                @test v.kind in (:valley, :exact_floor)
                @test v.min_err < 1e-7
            end
        end
    end
end
