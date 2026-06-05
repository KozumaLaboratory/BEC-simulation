# test/oracles/test_multistart_winner_selection.jl
#
# Closes (d) "winner selection logic" — the load-bearing contract that
# the M1 multi-start runner's `_select_winner` enforces:
#
#     stability filter PRECEDES E-ranking
#
# i.e. a lower-E saddle MUST NOT win over a higher-E true minimum.
# Without this ordering the runner would silently report saddles as the
# GS at degenerate-landscape cells (cyclic-saddle at Ω=0, etc.). The
# user-mandated failure mode the smoke (b)+(d) composition surfaces:
#
#     candidates = [..., (seed=:cyclic, E=0.5, stability=:saddle),
#                        (seed=:PCV,    E=1.0, stability=:stable)]
#     winner MUST be :PCV (NOT :cyclic — saddle excluded BEFORE argmin).
#
# A "pick lowest E" test alone would pass even if stability were ignored,
# because the lower-E candidate wouldn't have been marked saddle in any
# inadvertent collapse. The discriminator is `lower-E saddle + higher-E
# true min` — and that's the first @testset below.
#
# This test calls the runner's REAL `_select_winner` (not a copy) by
# including the script. The runner now guards `main()` with the
# `PROGRAM_FILE` idiom so include is side-effect-free.

using Test

# Include the runner script without running `main()`. Loads
# `_select_winner` into Main scope.
include(joinpath(@__DIR__, "..", "..", "scripts",
    "sprint5_M1_multistart_groundstate.jl"))

# Lightweight candidate constructor: only the fields _select_winner reads.
function _cand(seed::Symbol, E::Real;
    stability::Symbol=:stable, converged::Bool=true,
    grad_norm::Float64=1e-6)
    return (; seed, E=Float64(E), grad_norm, converged, stability,
        psi=zeros(ComplexF64, 1))
end

@testset "multi-start `_select_winner` contract" begin
    @testset "stability filter PRECEDES E-ranking (saddle-undercut)" begin
        # The mandated failure-mode case. `:cyclic` has the lowest E but
        # is a SADDLE; `:polar_core_vortex` is the lowest-E among STABLE.
        candidates = [
            _cand(:polar, 1.5; stability=:stable),
            _cand(:m_plus_F, 2.0; stability=:stable),
            _cand(:cyclic, 0.5; stability=:saddle),   # lower E, MUST be excluded
            _cand(:polar_core_vortex, 1.0; stability=:stable),   # true winner
        ]
        winner, competing, fallback = _select_winner(candidates)
        @test winner.seed === :polar_core_vortex
        @test winner.E == 1.0
        @test fallback === false
        # Competing must include the other two stable candidates,
        # and must NOT include the saddle.
        @test Set(c.seed for c in competing) == Set([:polar, :m_plus_F])
        # Sort order: ascending E.
        @test [c.E for c in competing] == sort([c.E for c in competing])
    end

    @testset "ambiguous excluded same as saddle" begin
        # Parallel guard: `:ambiguous` candidates must not win either.
        candidates = [
            _cand(:antiferromagnetic, 0.7; stability=:ambiguous), # lower E, ambiguous
            _cand(:polar_core_vortex, 1.0; stability=:stable),    # winner
        ]
        winner, competing, fallback = _select_winner(candidates)
        @test winner.seed === :polar_core_vortex
        @test fallback === false
        @test isempty(competing)  # AFM is ambiguous, not in competing-stable
    end

    @testset "unconverged excluded same as unstable" begin
        # `:stable` is insufficient — `converged` must also be true.
        candidates = [
            _cand(:polar_core_vortex, 0.5; stability=:stable, converged=false),
            _cand(:fl_vortex, 1.0; stability=:stable, converged=true),
        ]
        winner, competing, fallback = _select_winner(candidates)
        @test winner.seed === :fl_vortex
        @test fallback === false
    end

    @testset "all unstable → fallback uses full-set argmin" begin
        # When no candidate is `:stable && converged`, fall back to
        # lowest-E across the full set and signal it to the caller.
        candidates = [
            _cand(:cyclic, 0.5; stability=:saddle),
            _cand(:biaxial_nematic, 0.8; stability=:ambiguous),
            _cand(:spin_helix, 1.2; stability=:saddle),
        ]
        winner, competing, fallback = _select_winner(candidates)
        @test fallback === true
        @test winner.seed === :cyclic           # lowest E overall
        @test isempty(competing)                # no stable candidates exist
    end

    @testset "single stable candidate is the winner" begin
        candidates = [_cand(:fl_vortex, 0.42; stability=:stable)]
        winner, competing, fallback = _select_winner(candidates)
        @test winner.seed === :fl_vortex
        @test fallback === false
        @test isempty(competing)
    end

    @testset "tie on E — first-wins (Julia argmin convention)" begin
        # Documenting current behavior so a future refactor that changes
        # tie-breaking has to update this test consciously.
        candidates = [
            _cand(:polar, 1.0; stability=:stable),
            _cand(:polar_core_vortex, 1.0; stability=:stable),
        ]
        winner, competing, _ = _select_winner(candidates)
        @test winner.seed === :polar              # argmin returns first index
        @test length(competing) == 1
        @test competing[1].seed === :polar_core_vortex
    end

    @testset "empty candidate list throws (upstream programming error)" begin
        @test_throws ArgumentError _select_winner(NamedTuple[])
    end
end
