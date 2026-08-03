# seed_from: warm-start a GS step from a prior run's ψ, matched by resolved cell
# signature (c1/Bz/κ/initial_state) and spectrally upsampled to this grid.
# Guards the match logic (footgun-prone: wrong match → whole scan seeds wrong)
# and the loud-failure contract (no silent fallback to a Gaussian seed).

using Test
using SpinorBEC
using JLD2
using Random

@testset "seed_from warm-start" begin
    dir = mktempdir()
    # The "paired with point_001, not point_002" checks below discriminate by
    # NORM, so the two decoys must be distinguishable by construction rather
    # than by luck. Unscaled, `sum(abs2, randn(ComplexF64, 8,8,8,3))` is
    # 3072 ± 78 (1536 entries, 2.55 % relative sd), so two independent draws
    # land within the rtol=1e-3 of the negative assertions about 2.2 % of the
    # time — which is exactly how this file went red on main at 2f81f4f7, both
    # negative assertions failing together off one unlucky pair.
    #
    # Scaling psi_b puts the norms 9× apart, and the seed makes any future
    # failure reproducible instead of a 1-in-45 mystery.
    rng = MersenneTwister(20260729)
    psi_a = randn(rng, ComplexF64, 8, 8, 8, 3)     # F=1 → D=3, cubic even
    psi_b = 3.0 .* randn(rng, ComplexF64, 8, 8, 8, 3)
    # Pin the precondition: if someone drops the scaling, this fails loudly
    # rather than the file quietly becoming flaky again.
    @test !isapprox(sum(abs2, psi_a), sum(abs2, psi_b); rtol=0.5)
    jldopen(joinpath(dir, "point_001_stretched.jld2"), "w") do f
        f["psi"] = psi_a
        f["override"] = Dict{String, Any}(
            "pipeline.0.interactions.c1_ratio" => 0.0277777778,
            "pipeline.0.B.Bz" => "5.5e-5 Gauss",
            "pipeline.0.potential.omega.2" => 1.5,
            "pipeline.0.initial_state" => "m_plus_F")
    end
    jldopen(joinpath(dir, "point_002_polar.jld2"), "w") do f
        f["psi"] = psi_b
        f["override"] = Dict{String, Any}(
            "pipeline.0.interactions.c1_ratio" => -0.015,
            "pipeline.0.B.Bz" => "0.0 Gauss",
            "pipeline.0.potential.omega.2" => 1.0,
            "pipeline.0.initial_state" => "polar")
    end

    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    atom = AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0)

    p_match = Dict{String, Any}(
        "interactions" => Dict{String, Any}("c1_ratio" => 0.0277777778),
        "B" => Dict{String, Any}("Bz" => "5.5e-5 Gauss"),
        "potential" => Dict{String, Any}("omega" => [1.0, 1.0, 1.5]),
        "initial_state" => "m_plus_F")

    seed = SpinorBEC._resolve_seed_from(
        Dict{String, Any}("run" => dir, "upsample" => true), p_match, grid, atom)
    @test size(seed) == (16, 16, 16, 3)
    @test eltype(seed) == ComplexF64
    # spectral upsample holds ∫|ψ|² (box fixed) ⇒ mean|ψ|² · n³ invariant; and the
    # matched norm ties to point_001 (psi_a), NOT point_002 (psi_b), so it paired right.
    @test isapprox(sum(abs2, seed) / 16^3, sum(abs2, psi_a) / 8^3; rtol=1e-6)
    @test !isapprox(sum(abs2, seed) / 16^3, sum(abs2, psi_b) / 8^3; rtol=1e-3)

    # no matching cell → loud error (never a silent Gaussian fallback)
    p_nomatch = Dict{String, Any}(
        "interactions" => Dict{String, Any}("c1_ratio" => 0.999),
        "B" => Dict{String, Any}("Bz" => "0.0 Gauss"),
        "potential" => Dict{String, Any}("omega" => [1.0, 1.0, 1.0]),
        "initial_state" => "polar")
    @test_throws ArgumentError SpinorBEC._resolve_seed_from(
        Dict{String, Any}("run" => dir), p_nomatch, grid, atom)

    # size mismatch with upsample disabled → loud error
    @test_throws ArgumentError SpinorBEC._resolve_seed_from(
        Dict{String, Any}("run" => dir, "upsample" => false), p_match, grid, atom)

    # nearest: a brand-new (Bz, κ) with no exact match warm-starts off the
    # closest same-(c1, initial_state) point. Cell near point_001 (psi_a).
    p_near = Dict{String, Any}(
        "interactions" => Dict{String, Any}("c1_ratio" => 0.0277777778),
        "B" => Dict{String, Any}("Bz" => "6.0e-5 Gauss"),   # no exact point at 6e-5
        "potential" => Dict{String, Any}("omega" => [1.0, 1.0, 1.6]),
        "initial_state" => "m_plus_F")
    # exact would fail (no 6e-5/κ=1.6 point); nearest resolves to point_001 (psi_a)
    @test_throws ArgumentError SpinorBEC._resolve_seed_from(
        Dict{String, Any}("run" => dir), p_near, grid, atom)
    seed_n = SpinorBEC._resolve_seed_from(
        Dict{String, Any}("run" => dir, "upsample" => true, "nearest" => true),
        p_near, grid, atom)
    @test isapprox(sum(abs2, seed_n) / 16^3, sum(abs2, psi_a) / 8^3; rtol=1e-6)
    @test !isapprox(sum(abs2, seed_n) / 16^3, sum(abs2, psi_b) / 8^3; rtol=1e-3)
end

# `_resolve_pin_block(block, zeeman) -> (closure, eps)` was split by cutover
# step 3 into `_parse_pin_block(block) -> (kind, eps)` and
# `_pin_closure(kind, zeeman)`. `pin` selects a BRANCH of the weak-field soft
# manifold, so it is an input to the artifact id — and a closure cannot be
# hashed, so the pure parse had to become reachable on its own.
@testset "pin block resolution" begin
    z = SpinorBEC.ZeemanParams(0.7, 0.02)   # (p, q) dimensionless

    kind, eps = SpinorBEC._parse_pin_block(
        Dict{String, Any}("kind" => "transverse",
            "epsilon_ramp" => [2.0e-3, 5.0e-4]))
    @test eps == [2.0e-3, 5.0e-4]
    @test kind === :transverse
    pin = SpinorBEC._pin_closure(kind, z)
    @test pin isa Function
    ov = pin(1.0e-3)                      # ε -> (; zeeman=...)
    @test haskey(ov, :zeeman)             # pin injects a transverse-field zeeman

    # no pin block → inert, on both halves
    @test SpinorBEC._parse_pin_block(nothing) == (nothing, Float64[])
    @test SpinorBEC._pin_closure(nothing, z) === nothing
    # missing ramp → loud
    @test_throws ArgumentError SpinorBEC._parse_pin_block(
        Dict{String, Any}("kind" => "transverse"))
    # unsupported kind → loud
    @test_throws ArgumentError SpinorBEC._parse_pin_block(
        Dict{String, Any}("kind" => "trap", "epsilon_ramp" => [1.0e-3]))
end
