using Test
using SpinorBEC

# Lightweight Experiment-shaped struct (real Experiment requires a CASStore
# and triggers I/O — we only need .spec for the inspector hot path).
struct _FakeExp
    spec::Dict{Any, Any}
end

const _BASE_YAML = """
Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "atom" => "Eu151",
            "dt" => 0.01,
            "grid" => Dict{String, Any}(
                "box" => [4.0, 4.0, 4.0],
                "n" => [8, 8, 8],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "omega_ref" => 691.1504,
            ),
            "n_steps" => 10,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
            ),
            "dt" => 0.01,
            "duration" => 1.0,
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "omega_ref" => 691.1504,
            ),
            "rotating_frame_omega" => 0.0,
        ),
    )],
)
"""

function _build_cells(rotating_omegas, dts)
    cells = _FakeExp[]
    for (rfo, dt) in zip(rotating_omegas, dts)
        d = SpinorBEC._julia_config_string(_BASE_YAML)
        d["pipeline"][2]["dynamics"]["rotating_frame_omega"] = rfo
        d["pipeline"][2]["dynamics"]["dt"] = dt
        push!(cells, _FakeExp(Dict{Any, Any}(d)))
    end
    cells
end

@testset "inspect_batch" begin
    @testset "declared axis varies as expected, no drift" begin
        cells = _build_cells([0.0, -0.1, -0.2], [0.01, 0.01, 0.01])
        batch = inspect_batch(cells;
            expected_axes=["pipeline[2].dynamics.rotating_frame_omega"])
        @test length(batch.inspections) == 3
        declared = filter(w -> w.kind === :sweep_axis_declared, batch.cross_cell)
        silent = filter(w -> w.kind === :sweep_axis_silent_drift, batch.cross_cell)
        @test length(declared) == 1
        @test isempty(silent)
    end

    @testset "undeclared drift detected" begin
        # Cell 3 accidentally varies dt.
        cells = _build_cells([0.0, -0.1, -0.2], [0.01, 0.01, 0.005])
        batch = inspect_batch(cells;
            expected_axes=["pipeline[2].dynamics.rotating_frame_omega"])
        silent = filter(w -> w.kind === :sweep_axis_silent_drift, batch.cross_cell)
        @test length(silent) == 1
        @test occursin("dt", silent[1].title)
        @test silent[1].severity === :warn
    end

    @testset "no expected_axes: drift reported as info" begin
        cells = _build_cells([0.0, -0.1], [0.01, 0.01])
        batch = inspect_batch(cells)
        drift = filter(w -> w.kind === :sweep_axis_silent_drift, batch.cross_cell)
        @test length(drift) == 1
        @test drift[1].severity === :info
    end

    @testset "single-cell batch: no cross-cell findings" begin
        cells = _build_cells([0.0], [0.01])
        batch = inspect_batch(cells)
        @test isempty(batch.cross_cell)
    end

    @testset "markdown_report formats" begin
        cells = _build_cells([0.0, -0.1, -0.2], [0.01, 0.01, 0.005])
        batch = inspect_batch(cells;
            expected_axes=["pipeline[2].dynamics.rotating_frame_omega"])
        md = markdown_report(batch; title="Test batch")
        @test occursin("# Test batch", md)
        @test occursin("Per-cell summary", md)
        @test occursin("Undeclared drift", md)
        @test occursin("pipeline[2].dynamics.dt", md)
        # Severity columns rendered.
        @test occursin("| info | warn | error | block |", md)
    end
end
