using Test
using SpinorBEC
using SpinorBEC: _all_finite, _welford_update!, EnsembleResult

# One diverging member must not take the ensemble with it.
#
# `_welford_update!` is cumulative and in place — `mean[I] += delta / i` — so a
# single NaN anywhere in a trajectory's observables destroys the mean and the
# variance for every member AFTER it, with no recovery. Until 2026-08-04
# `grep isfinite src/solvers/twa.jl` returned nothing: a 200-member ensemble
# with one divergence returned an all-NaN answer while `n_trajectories` still
# read 200. 33 configs under `runs/` use `twa:`.
#
# Two defects, not one. The second is quieter and would have survived a fix to
# the first: the variance divided M2 by `n_traj` — the number REQUESTED — so
# rejecting members without changing the denominator inflates the sample count
# and biases the variance low.

@testset "TWA rejects diverged members" begin
    @testset "the finiteness guard sees what it must" begin
        ok = Dict(:a => [Float64[1.0, 2.0], Float64[3.0]],
            :b => [Float64[0.0]])
        @test _all_finite(ok)
        # …and each way a member can go bad
        for bad in (NaN, Inf, -Inf)
            d = Dict(:a => [Float64[1.0, bad]], :b => [Float64[0.0]])
            @test !_all_finite(d)
        end
        # a NaN in a LATER observable, not the first — the loop must not stop
        # at the first key
        @test !_all_finite(Dict(:a => [Float64[1.0]], :b => [Float64[NaN]]))
    end

    @testset "Welford weighting counts contributing samples" begin
        # The mean of 2 and 4 is 3 whether or not a third member was refused
        # between them. Passing the LOOP INDEX instead of the used count gives
        # the rejected slot a share of the weight and lands elsewhere.
        m = [2.0]
        M2 = [0.0]
        _welford_update!(m, M2, [4.0], 2)      # second CONTRIBUTING sample
        @test m[1] ≈ 3.0
        # the same pair weighted as if it were samples 1 and 3
        m2 = [2.0]
        M2b = [0.0]
        _welford_update!(m2, M2b, [4.0], 3)
        @test m2[1] ≉ 3.0                       # ...and it does not
    end

    @testset "the result records what was refused" begin
        # `rejected` is a vector, not a count: "none rejected" and "rejections
        # not tracked" must not look alike, and a caller should be able to name
        # the member.
        r = EnsembleResult([0.0], Dict{Symbol, Vector{Array{Float64}}}(),
            Dict{Symbol, Vector{Array{Float64}}}(), 3, [2], nothing, nothing)
        @test r.rejected == [2]
        @test r.n_trajectories == 3            # contributing, not requested
        # the back-compat constructor reads as "none rejected", which is true
        # of every caller written before the path existed
        old = EnsembleResult([0.0], Dict{Symbol, Vector{Array{Float64}}}(),
            Dict{Symbol, Vector{Array{Float64}}}(), 5, nothing)
        @test old.rejected == Int[]
    end

    # THE ARM THE FIRST VERSION OF THIS FILE LACKED. Everything above tests the
    # PIECES — the predicate, the weighting, the record — and every one of them
    # stayed green when the rejection branch itself was disabled (measured:
    # canary A, `if false && !_all_finite(...)`). Testing a guard's components
    # without testing that the caller CONSULTS it is the same shape as a gate
    # built from the thing under test: it never crosses into the code path where
    # the defect lives.
    #
    # `run_twa_ensemble` needs a full workspace, so this reads the SOURCE: the
    # loop must call the predicate and must skip on it. Cheap, and it fails for
    # the right reason if someone removes the branch.
    @testset "the ensemble loop actually consults the guard" begin
        src = read(joinpath(@__DIR__, "..", "..", "src", "solvers", "twa.jl"), String)
        # strip comments so the prose explaining the guard cannot satisfy it
        code = join((split(l, '#')[1] for l in split(src, '\n')), "\n")
        @test occursin("_all_finite(traj_obs)", code)
        @test occursin(r"if\s*!\s*_all_finite\(traj_obs\)", code)
        @test occursin(r"push!\(rejected,\s*i\)", code)
        @test occursin("continue", code)
        # the weighting and the denominator must use the used-count, not the
        # loop index or the requested count
        @test occursin(r"traj_obs\[sym\]\[t_idx\],\s*n_used", code)
        @test occursin(r"n_used\s*-\s*1", code)
        @test !occursin(r"m2\s*\./\s*\(n_traj\s*-\s*1\)", code)
    end

    # POSITIVE CONTROL on the whole argument: show that folding a NaN in
    # DOES destroy the running mean, so the guard is not defending against a
    # hypothetical.
    @testset "positive control: an unguarded NaN is unrecoverable" begin
        m = [1.0]
        M2 = [0.0]
        _welford_update!(m, M2, [NaN], 2)
        @test isnan(m[1])
        _welford_update!(m, M2, [1.0], 3)      # a healthy member afterwards
        @test isnan(m[1])                      # …cannot repair it
    end
end
