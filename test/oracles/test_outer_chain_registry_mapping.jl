using Test
using FFTW
using SpinorBEC
using SpinorBEC: OUTER_CHAIN, OUTER_CHAIN_TERMS, OUTER_CHAIN_EXTERNAL_TERMS,
    SPIN_CHAIN_FUSED_SUBSTEPS, SPIN_CHAIN_DECLINED_SUBSTEPS,
    H_TERMS_CANONICAL_ORDER, RamanCoupling,
    _outer_operators_fwd!, _outer_operators_bwd!

# The split-step outer chain is declared ONCE, and every registry term has a
# propagator.
#
# WHY THIS GATE EXISTS
#
# Two separate problems, both measured on 2026-08-19.
#
# 1. THE ORDER WAS WRITTEN THREE TIMES. `_outer_operators_fwd!`, its reversed
#    twin `_outer_operators_bwd!`, and a prose comment above them each carried
#    the substep list. The comment listed seven of nine from 2026-06-02 to
#    2026-08-05 (missing `spatial_lhy_spin`, `spatial_zeeman`), CLAUDE.md copied
#    the short list from the comment, and the two were then "corrected" from
#    each other rather than from the code. Both directions are now derived from
#    `OUTER_CHAIN`, and the Strang symmetry is `reverse` rather than care.
#
# 2. NOTHING CONNECTED THE CHAIN TO THE REGISTRY. `H_TERMS_CANONICAL_ORDER` has
#    14 slots and every one implements `apply_step!` — but production calls that
#    face for only THREE of them (kinetic, coriolis, loss). The propagator is
#    this chain, which FUSES four terms into `:diagonal` for speed. That fusion
#    is correct and worth keeping; what was missing is any statement of the map,
#    so "a new term whose energy and gradient are gated but which no propagator
#    applies" was invisible. It has happened: RK4IP dropped three-body loss and
#    the absorbing boundary; the absorbing boundary was dead on every RTP driver
#    for a month; RamanTerm had an energy and no gradient (#247).
#
# WHAT IS NOT CLAIMED. This gate does not check that a substep applies the
# physics its term declares — that is the FD/parity oracle suite's job
# (`test_term_fd_registry_coverage.jl`, `test_term_legacy_equivalence.jl`). It
# checks that the MAP IS TOTAL: no registry slot falls through the floor.

@testset "outer chain is declared once and covers the registry" begin
    @testset "OUTER_CHAIN and its term map have the same keys" begin
        @test length(OUTER_CHAIN) == length(keys(OUTER_CHAIN_TERMS))
        @test Set(OUTER_CHAIN) == Set(keys(OUTER_CHAIN_TERMS))
        # Order matters for a Strang sandwich, so the map is declared in chain
        # order too — a reader comparing them should not have to sort.
        @test collect(OUTER_CHAIN) == collect(keys(OUTER_CHAIN_TERMS))
        @test allunique(OUTER_CHAIN)
    end

    @testset "every substep has a method" begin
        for s in OUTER_CHAIN
            @test hasmethod(SpinorBEC._outer_substep!,
                Tuple{Val{s}, SpinorBEC.Workspace, SpinorBEC.OuterChainCtx})
        end
    end

    @testset "the map onto H_TERMS_CANONICAL_ORDER is TOTAL" begin
        in_chain = Set(Symbol[])
        for s in OUTER_CHAIN
            for t in getproperty(OUTER_CHAIN_TERMS, s)
                push!(in_chain, t)
            end
        end
        external = Set(keys(OUTER_CHAIN_EXTERNAL_TERMS))
        canonical = Set(H_TERMS_CANONICAL_ORDER)

        # No slot is propagated by nothing. THIS is the assertion that catches a
        # new HamTerm whose energy and gradient are gated but which the
        # propagator never applies.
        unpropagated = setdiff(canonical, union(in_chain, external))
        if !isempty(unpropagated)
            @info "registry terms with no propagator" terms=sort(collect(unpropagated))
        end
        @test isempty(unpropagated)

        # …and nothing is claimed that is not a registry slot, so the map cannot
        # be satisfied by inventing a name.
        invented = setdiff(union(in_chain, external), canonical)
        if !isempty(invented)
            @info "names in the map that are not registry slots" terms=sort(collect(invented))
        end
        @test isempty(invented)

        # A term is either in the chain or outside it, not silently both.
        @test isempty(intersect(in_chain, external))

        # Every external claim carries a non-empty reason naming where it runs.
        for (t, why) in pairs(OUTER_CHAIN_EXTERNAL_TERMS)
            @test why isa AbstractString
            @test !isempty(strip(why))
        end
    end

    @testset "the fused spin-chain classification partitions OUTER_CHAIN" begin
        fused = Set(SPIN_CHAIN_FUSED_SUBSTEPS)
        declined = Set(SPIN_CHAIN_DECLINED_SUBSTEPS)
        # Appending a substep to OUTER_CHAIN without classifying it here is the
        # failure `_spin_chain_reason` used to ask a human to prevent.
        @test isempty(intersect(fused, declined))
        missing_cls = setdiff(Set(OUTER_CHAIN), union(fused, declined))
        if !isempty(missing_cls)
            @info "substeps the fused V half-step has not classified" substeps = sort(
                collect(missing_cls))
        end
        @test isempty(missing_cls)
        @test isempty(setdiff(union(fused, declined), Set(OUTER_CHAIN)))
    end

    @testset "the derived reverse really is the inverse of the forward pass" begin
        # The point of deriving `_outer_operators_bwd!` from `reverse(OUTER_CHAIN)`
        # is that the mirror cannot drift. This is the numerical statement of
        # that: for a linear, time-independent chain, fwd(+dt) then bwd(-dt)
        # must return ψ. It fails if the reversal is wrong, if a substep is
        # applied in one direction only, or if a substep is not its own inverse
        # under dt → -dt.
        #
        # The active substeps here are chosen to exercise BOTH ends of the chain
        # (diagonal at one end, raman at the other) plus two interior ones, so a
        # reversal that dropped an end would not pass.
        grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        atom = Na23
        sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false)
        ws = make_workspace(;
            grid, atom,
            interactions=InteractionParams(Dict(0 => 0.7, 1 => -0.2)),
            zeeman=ZeemanParams(0.35, 0.11),
            potential=HarmonicTrap((1.0, 1.1, 0.9)),
            raman=RamanCoupling{3}(0.4, 0.15, (0.5, 0.0, 0.0)),
            sim_params=sp, fft_flags=FFTW.ESTIMATE,
        )
        psi0 = copy(ws.state.psi)
        @test any(!iszero, psi0)

        dt = 0.013
        ndim = 3
        # Freeze the mean field so the nonlinear substeps are linear operators
        # over this pair — otherwise fwd/bwd is not expected to invert.
        psi_mf = copy(psi0)
        _outer_operators_fwd!(ws, dt, ndim, false; psi_mf)
        moved = maximum(abs, ws.state.psi .- psi0)
        _outer_operators_bwd!(ws, -dt, ndim, false; psi_mf)
        back = maximum(abs, ws.state.psi .- psi0)

        # Positive control: the chain must actually have DONE something, or
        # "it inverted" is the trivially true statement of a no-op.
        @test moved > 1e-6
        @test back < 1e-12
    end
end
