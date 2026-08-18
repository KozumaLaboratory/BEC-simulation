using Test
using SpinorBEC
using SpinorBEC: scratch_get!, scratch_clear!, SCRATCH_REGISTRY
using SpinorBEC.Dashboard: invalidate_path!

# Four places where a thing that did not happen looked like a thing that was fine.
#
# This file gates the three that are checkable without a GPU or an HTTP server,
# plus the scratch-registry eviction they all depend on. The VTK one is in
# `ext/SpinorBECVTKExt` and needs WriteVTK, so it is asserted at source level
# only — on CODE lines, because a comment explaining the fix is not the fix.

const _QUEUE_ROUTE = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow",
        "io", "dashboard", "routes", "autopilot_queue.jl"),
)
const _VTK = normpath(joinpath(@__DIR__, "..", "..", "ext", "SpinorBECVTKExt",
    "vtk_export.jl"))
const _RUN_REGISTRY = normpath(
    joinpath(@__DIR__, "..", "..", "src", "workflow",
        "experiments", "pipeline", "run_registry.jl"),
)

codelines(p) = [l for l in eachline(p) if !startswith(strip(l), "#")]

@testset "absence is not reported as health" begin
    # ---- 1. the scratch registry can be emptied ----------------------------
    #
    # It holds STRONG references to keys and values by design — that is what
    # pins a host array against address reuse. The consequence is that a device
    # buffer parked there survives `GC.gc()`, and `CUDA.reclaim()` cannot return
    # its memory because reclaim only frees what the pool already considers
    # free. The scan loop drops the workspace and reclaims between points, and
    # its own comment names k² among the things it frees — but the device k²
    # copy lives in the registry, not on the workspace, so that sequence could
    # not reach it.
    @testset "scratch_clear! actually evicts" begin
        scratch_clear!()
        a, b = [1.0, 2.0], [3.0, 4.0]
        scratch_get!(() -> copy(a), :probe_a, a)
        scratch_get!(() -> copy(b), :probe_b, b)

        # CALIBRATION: the puts must have landed, or "it is empty afterwards"
        # is true of a registry that never stored anything.
        @test length(SCRATCH_REGISTRY) == 2
        @test length(SCRATCH_REGISTRY[:probe_a]) == 1

        scratch_clear!(:probe_a)
        @test isempty(SCRATCH_REGISTRY[:probe_a])
        @test length(SCRATCH_REGISTRY[:probe_b]) == 1   # selective, not global

        scratch_clear!()
        @test isempty(SCRATCH_REGISTRY)

        # and it must still be a cache afterwards
        v1 = scratch_get!(() -> copy(a), :probe_a, a)
        @test scratch_get!(() -> copy(a), :probe_a, a) === v1
        scratch_clear!()
    end

    @testset "the scan loop clears before it collects" begin
        code = codelines(_RUN_REGISTRY)
        i = findfirst(l -> occursin("scratch_clear!()", l), code)
        g = findfirst(l -> occursin("GC.gc()", l), code)
        r = findfirst(l -> occursin("_maybe_cuda_reclaim()", l), code)
        @test i !== nothing
        @test g !== nothing && r !== nothing
        # ordering is the whole point: clearing after the GC frees nothing
        @test i < g < r
    end

    # ---- 2. a queue read failure is reported, not rendered as "no jobs" ----
    @testset "the queue route reports an unreadable state" begin
        code = codelines(_QUEUE_ROUTE)
        # CALIBRATION: the route is being read and still has the catch we care
        # about, or the assertions below pass on an empty file.
        @test any(l -> occursin("list_queue(", l), code)
        @test any(l -> occursin("QueueEntry[]", l), code)

        # ANCHORED to the `list_queue` catch specifically. A first version took
        # `findfirst(occursin("catch"))` and landed on an unrelated one three
        # hundred lines earlier — a scan that finds *a* match rather than *the*
        # match reports on the wrong code and says nothing about it.
        li = findfirst(l -> occursin("list_queue(st", l), code)
        @test li !== nothing
        window = join(code[li:min(length(code), li + 4)], " ")
        @test occursin("catch e", window)
        @test occursin("push!(failed", window)
        # the old shape: a bare `catch` that discards the exception
        @test !occursin("catch\n", window)
        # ...and the response must carry the failure out
        @test any(l -> occursin("unreadable", l), code)
    end

    # ---- 3. invalidate_path! matches the keys it is given -------------------
    #
    # The `data_cache` loop asked whether the whole cache KEY is a substring of
    # the path. Keys are `"<run_name>#<live_count>"`, so the `#3` suffix is
    # never in a file path and the test could not match — the wrong-`occursin`-
    # argument class. The run name IS a path component.
    @testset "invalidate_path! drops the run it is asked about" begin
        fpath = "/data/runs/eu151_klaus_barnett/point_003.jld2"
        data = Dict{Any, Any}(
            "eu151_klaus_barnett#3" => "cached json",
            "eu151_klaus_barnett#7" => "cached json",
            "some_other_run#3" => "keep me",
        )
        psi = Dict{Any, Any}(
            "phase_bin:$(fpath)#snap=0#axis=z#slice=4" => [1.0],
            "phase_bin:/data/runs/other/point_001.jld2#snap=0" => [2.0],
        )

        invalidate_path!(data, psi, fpath)

        @test !haskey(data, "eu151_klaus_barnett#3")
        @test !haskey(data, "eu151_klaus_barnett#7")   # every live_count, not one
        @test haskey(data, "some_other_run#3")          # other runs preserved
        @test !haskey(psi, "phase_bin:$(fpath)#snap=0#axis=z#slice=4")
        @test haskey(psi, "phase_bin:/data/runs/other/point_001.jld2#snap=0")

        # NEGATIVE CONTROL: a path belonging to no cached run must delete
        # nothing, or the arm above would pass on an implementation that clears
        # everything — which is `clear_all_caches!`, a different function.
        data2 = Dict{Any, Any}("eu151_klaus_barnett#3" => "x")
        psi2 = Dict{Any, Any}("phase_bin:/nowhere/p.jld2#snap=0" => [1.0])
        invalidate_path!(data2, psi2, "/data/runs/unrelated_run/point_001.jld2")
        @test length(data2) == 1
        @test length(psi2) == 1
    end

    # ---- 4. the VTK series exporter says something about a name it cannot use
    @testset "export_vtk_series warns on an unknown field" begin
        code = codelines(_VTK)
        # CALIBRATION: both exporters are in this file and both have a dispatch
        # chain over `field`.
        @test count(l -> occursin("function SpinorBEC.export_vtk", l), code) >= 2
        @test count(l -> occursin("Unknown VTK field", l), code) == 2
        # the series form had no `else` at all; both must have one now
        @test count(l -> occursin("field === :component_densities", l), code) == 2
    end
end
