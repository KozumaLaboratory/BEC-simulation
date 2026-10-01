using Test
using SpinorBEC
using JSON
using JLD2

@testset "Dashboard response strings survive JSON round-trip" begin
    for message in ["line one\nline two", "quote \" and slash \\",
        "tab\treturn\rcontrol\x01", "日本語と末尾の🙂"]
        response = JSON.parse(SpinorBEC.Dashboard._tag_err(message))
        @test response["ok"] === false
        @test response["error"] == message
        entry = QueueEntry("json_response"; run_dir="runs/json_response",
            spec_path="runs/json_response/config.yaml", kill_reason=message,
            enqueued_by=message)
        row = JSON.parse(SpinorBEC.Dashboard._entry_to_json(entry))
        @test row["kill_reason"] == message
        @test row["enqueued_by"] == message
    end
end

@testset "Column density API uses the cached density engine" begin
    mktempdir() do root
        run_dir = joinpath(root, "density")
        mkpath(run_dir)
        path = joinpath(run_dir, "point_001.jld2")
        psi = zeros(ComplexF64, 2, 3, 3)
        for c in 1:3
            psi[:, :, c] .= c
        end
        jldsave(path; psi, grid_box_size=[4.0, 6.0])
        cache = Dict{String, Any}()
        try
            status, content_type, body = SpinorBEC.Dashboard._route_density2d(
                "/api/density/density/point_001.jld2?axis=2", root, cache)
            @test status == 200
            @test content_type == "application/json"
            data = JSON.parse(body)
            @test data["shape"] == [2]
            @test data["total_density"] == [42.0, 42.0]
            @test data["densities"] == [[3.0, 3.0], [12.0, 12.0], [27.0, 27.0]]
        finally
            SpinorBEC.Dashboard.invalidate_path!(Dict{String, Any}(), cache, path)
        end
    end
end
