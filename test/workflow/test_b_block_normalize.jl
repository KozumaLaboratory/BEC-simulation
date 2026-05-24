# Unified `B:` block YAML normalization edge cases.
#
# `apply_B_block_normalize!` validates form mutual exclusion (Cartesian
# Bx/By/Bz vs spherical B_mag+theta+phi) and routes recognized keys into
# the internal `B` / `B_direction` dicts that pipeline_runner consumes.
# Each probe targets a single validation branch — a regression that
# weakens the guard points to the specific case.

using Test
using SpinorBEC
using SpinorBEC: apply_B_block_normalize!

@testset "B-block normalize edge cases" begin
    _wrap_step(step) = Dict{String, Any}(
        "pipeline" => Any[Dict{String, Any}("ground_state" => step)]
    )

    @testset "Cartesian + non-zero direction rejected" begin
        # Cartesian determines direction via components; specifying
        # theta/phi separately is contradictory.
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}("Bz" => "1 Gauss", "theta" => 0.5)
            ),
        )
        @test_throws ArgumentError apply_B_block_normalize!(cfg)

        cfg2 = _wrap_step(Dict{String, Any}(
            "B" => Dict{String, Any}("Bx" => 0.1, "phi" => 1.0)
        ))
        @test_throws ArgumentError apply_B_block_normalize!(cfg2)
    end

    @testset "Cartesian + theta=0/phi=0 sugar dropped silently" begin
        # `theta: 0` and `phi: 0` are default-aligned with ẑ — common in
        # ground_state and ignored to keep configs forgiving.
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}(
                    "Bz" => "1 Gauss",
                    "theta" => 0,
                    "phi" => 0,
                ),
            ),
        )
        apply_B_block_normalize!(cfg)
        gs = cfg["pipeline"][1]["ground_state"]
        @test haskey(gs, "B")
        @test !haskey(gs, "B_direction")  # theta/phi dropped, no direction split
        @test haskey(gs["B"], "Bz")
    end

    @testset "Both `B:` and step-level `zeeman:`/`B_hat:` rejected" begin
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}("Bz" => "1 Gauss"),
                "zeeman" => Dict{String, Any}("p" => 0.5),
            ),
        )
        @test_throws ArgumentError apply_B_block_normalize!(cfg)

        cfg2 = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}("Bz" => "1 Gauss"),
                "B_hat" => Dict{String, Any}("theta" => 0.5),
            ),
        )
        @test_throws ArgumentError apply_B_block_normalize!(cfg2)
    end

    @testset "Step-level zeeman / B_hat without B: also rejected" begin
        # Even without the unified `B:`, step-level zeeman/B_hat are
        # forbidden user-facing keys (post-2026 unification cleanup).
        cfg_z = _wrap_step(Dict{String, Any}(
            "zeeman" => Dict{String, Any}("p" => 0.5)
        ))
        @test_throws ArgumentError apply_B_block_normalize!(cfg_z)

        cfg_b = _wrap_step(Dict{String, Any}(
            "B_hat" => Dict{String, Any}("theta" => 0.5)
        ))
        @test_throws ArgumentError apply_B_block_normalize!(cfg_b)
    end

    @testset "B.magnitude alias removed (use B_mag)" begin
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}(
                    "magnitude" => "1 Gauss",
                    "theta" => 0.5,
                    "phi" => 0.0,
                ),
            ),
        )
        @test_throws ArgumentError apply_B_block_normalize!(cfg)
    end

    @testset "Unknown B key rejected with guiding message" begin
        cfg = _wrap_step(Dict{String, Any}(
            "B" => Dict{String, Any}("bogus_field" => 1.0)
        ))
        @test_throws ArgumentError apply_B_block_normalize!(cfg)
    end

    @testset "B: must be a Dict" begin
        cfg = _wrap_step(Dict{String, Any}("B" => 1.0))
        @test_throws ArgumentError apply_B_block_normalize!(cfg)

        cfg2 = _wrap_step(Dict{String, Any}("B" => "1 Gauss"))
        @test_throws ArgumentError apply_B_block_normalize!(cfg2)
    end

    @testset "Spherical form: B_mag + theta + phi routes correctly" begin
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}(
                    "B_mag" => "1 Gauss",
                    "theta" => 0.611,
                    "phi" => 1.5,
                ),
            ),
        )
        apply_B_block_normalize!(cfg)
        gs = cfg["pipeline"][1]["ground_state"]
        @test haskey(gs, "B")
        @test haskey(gs, "B_direction")
        @test gs["B"]["B_mag"] == "1 Gauss"
        @test gs["B_direction"]["theta"] == 0.611
        @test gs["B_direction"]["phi"] == 1.5
    end

    @testset "Cartesian form: Bz / Bx / By route to B dict" begin
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}(
                    "Bx" => "10 mG",
                    "By" => 0.0,
                    "Bz" => "1 Gauss",
                    "q" => 0.01,
                ),
            ),
        )
        apply_B_block_normalize!(cfg)
        gs = cfg["pipeline"][1]["ground_state"]
        @test haskey(gs, "B")
        @test !haskey(gs, "B_direction")
        @test gs["B"]["Bx"] == "10 mG"
        @test gs["B"]["Bz"] == "1 Gauss"
        @test gs["B"]["q"] == 0.01
    end

    @testset "Calibration lab-units (p_mv + coil_mode) route to B dict" begin
        cfg = _wrap_step(
            Dict{String, Any}(
                "B" => Dict{String, Any}(
                    "p_mv" => 2.5,
                    "coil_mode" => "strong",
                    "theta" => 0.611,
                    "phi" => 0.0,
                ),
            ),
        )
        apply_B_block_normalize!(cfg)
        gs = cfg["pipeline"][1]["ground_state"]
        @test haskey(gs, "B")
        @test haskey(gs, "B_direction")
        @test gs["B"]["p_mv"] == 2.5
        @test gs["B"]["coil_mode"] == "strong"
        @test gs["B_direction"]["theta"] == 0.611
    end
end
