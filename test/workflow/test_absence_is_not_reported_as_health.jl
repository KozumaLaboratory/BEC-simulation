using Test
using SpinorBEC
using SpinorBEC: scratch_get!, scratch_clear!, SCRATCH_REGISTRY

# Scratch-registry eviction and reporting of unsupported VTK fields.
# The VTK exporter is in
# `ext/SpinorBECVTKExt` and needs WriteVTK, so it is asserted at source level
# only — on CODE lines, because a comment explaining the fix is not the fix.

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
