using Test
using SpinorBEC
using SpinorBEC: PULSE_EVENT_SCHEMA, PULSE_TARGETS, GS_SCHEMA, LHY_SCHEMA

# A schema enum must name what the implementation can actually do.
#
# `PULSE_EVENT_SCHEMA["apply"]` admitted "trap" while `PULSE_TARGETS` — the set
# `compile_pulse_sequence` dispatches on — did not. A config naming it VALIDATED
# and then compiled to nothing: the pulse parsed, grouped, and silently did not
# happen. `pulse_sequence.jl:15-18` says so in as many words ("documented in
# yaml_schema_reference.md but never implemented"), which is the shape worth
# gating: the implementation KNEW, and the validator did not ask it.
#
# An enum wider than the implementation is worse than one that is too narrow.
# Too narrow throws at load, in front of the user. Too wide accepts, runs, and
# omits the physics.

@testset "schema enums match their implementations" begin
    @testset "pulse `apply:` targets" begin
        schema = Set(Symbol.(PULSE_EVENT_SCHEMA["apply"].enum))
        impl = Set(PULSE_TARGETS)
        # Set equality, not subset: a target the compiler handles but the schema
        # rejects is a capability nobody can reach, which is also a defect.
        @test schema == impl
        # Named, so a failure says WHICH direction drifted.
        @test isempty(setdiff(schema, impl))   # validates but does nothing
        @test isempty(setdiff(impl, schema))   # implemented but unreachable
    end

    @testset "backend enum matches the backend resolver" begin
        # `:cuda` was removed 2026-05-24 and `_resolve_backend` throws on it.
        # Every name the schema admits must resolve.
        for b in GS_SCHEMA["backend"].enum
            @test SpinorBEC._resolve_backend(Symbol(b)) !== nothing
        end
        # POSITIVE CONTROL: a name outside the enum must NOT resolve, or the
        # loop above passes for a resolver that accepts anything.
        @test_throws Exception SpinorBEC._resolve_backend(:cuda)
    end

    @testset "lhy.kind enum is what the term builder dispatches on" begin
        # Every declared kind must be constructible; the enum is what users are
        # told they may write.
        kinds = LHY_SCHEMA["kind"].enum
        @test "none" in kinds
        @test "polar_two_channel" in kinds
        # `two_channel` was the spelling a live @warn recommended until
        # 2026-08-04 and it has never been in the enum.
        @test !("two_channel" in kinds)
        # …and no source file may recommend a spelling the enum rejects.
        root = normpath(joinpath(@__DIR__, "..", ".."))
        offenders = String[]
        for (dir, _, files) in walkdir(joinpath(root, "src")), f in files
            endswith(f, ".jl") || continue
            txt = read(joinpath(dir, f), String)
            for m in eachmatch(r"lhy:\s*\{\s*kind:\s*([a-z_]+)", txt)
                k = m.captures[1]
                k in kinds || push!(offenders, "$(relpath(joinpath(dir, f), root)): $k")
            end
        end
        isempty(offenders) ||
            println("  src recommends an lhy kind the enum rejects:\n    ",
                join(offenders, "\n    "))
        @test offenders == String[]
    end
end
