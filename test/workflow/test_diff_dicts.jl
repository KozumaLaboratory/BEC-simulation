using Test
using SpinorBEC
using SpinorBEC: diff_dicts, path_string, DictDiff, DiffEntry, flatten_diff

@testset "diff_dicts" begin
    @testset "identical dicts → no diff" begin
        a = Dict("x" => 1, "y" => Dict("z" => 2))
        b = deepcopy(a)
        d = diff_dicts(a, b)
        @test isempty(d.added)
        @test isempty(d.removed)
        @test isempty(d.changed)
    end

    @testset "added / removed / changed at root" begin
        a = Dict("x" => 1, "y" => 2)
        b = Dict("x" => 1, "z" => 3)
        d = diff_dicts(a, b)
        @test length(d.added) == 1
        @test d.added[1].path == Union{String, Int}["z"]
        @test length(d.removed) == 1
        @test d.removed[1].path == Union{String, Int}["y"]
        @test isempty(d.changed)
    end

    @testset "Symbol and String keys collapse" begin
        a = Dict(:x => 1)
        b = Dict("x" => 1)
        d = diff_dicts(a, b)
        @test isempty(d.added)
        @test isempty(d.removed)
        @test isempty(d.changed)
    end

    @testset "nested vector + dict mix" begin
        a = Dict("pipeline" => Any[Dict("ground_state" => Dict("dt" => 0.01))])
        b = Dict("pipeline" => Any[Dict("ground_state" => Dict("dt" => 0.005))])
        d = diff_dicts(a, b)
        @test length(d.changed) == 1
        e = d.changed[1]
        @test e.before == 0.01
        @test e.after == 0.005
        @test path_string(e.path) == "pipeline[1].ground_state.dt"
    end

    @testset "B-block split pattern" begin
        # Real pattern: user wrote theta in B, normalizer moved it to B_direction.
        raw = Dict(
            "pipeline" => Any[Dict(
                "dynamics" => Dict(
                    "B" => Dict("B_mag" => "0.01 Gauss", "theta" => 3.14)),
            )],
        )
        norm = Dict(
            "pipeline" => Any[Dict(
                "dynamics" => Dict(
                    "B" => Dict("B_mag" => "0.01 Gauss"),
                    "B_direction" => Dict("theta" => 3.14)),
            )],
        )
        d = diff_dicts(raw, norm)
        # theta moved → 1 added (B_direction subtree), 1 removed (B.theta).
        removed_paths = [path_string(e.path) for e in d.removed]
        @test "pipeline[1].dynamics.B.theta" in removed_paths
        added_paths = [path_string(e.path) for e in d.added]
        @test "pipeline[1].dynamics.B_direction" in added_paths
    end

    @testset "flatten_diff sorts by path" begin
        a = Dict("z" => 1, "a" => 2)
        b = Dict("z" => 99, "a" => 88)
        d = diff_dicts(a, b)
        flat = flatten_diff(d)
        @test length(flat) == 2
        @test path_string(flat[1].path) == "a"
        @test path_string(flat[2].path) == "z"
    end
end
