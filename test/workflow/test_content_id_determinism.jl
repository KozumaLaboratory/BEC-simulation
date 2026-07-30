# test/workflow/test_content_id_determinism.jl
#
# CLAUDE.md commitment #4: `Experiment(spec)` → `<store.root>/<content_id(spec)>/`,
# and "Same spec ⇒ same outdir, anywhere" — deterministic across dict-iteration
# order, Julia version and YAML round-trip.
#
# That commitment had NO test. Found by the mutation harness on 2026-07-30:
# reversing the key sort inside `_canonical_bytes!` — which changes the canonical
# bytes of every spec and therefore every outdir — was caught by nothing in
# `test/workflow/`. `content_id` appears in two other test files only as an opaque
# string passed between autopilot and catalog records, never computed from a spec.
#
# What is load-bearing and what is not, stated honestly:
#
#   * The REFERENCE ID below is a pin, and pins do not ground physics. It is the
#     right instrument here anyway, because the id is an INTERFACE: it names a
#     directory on disk. If it changes, every cached run is orphaned and every
#     `run!` recomputes silently. So the claim is "this must not change without
#     someone deciding to", and a pin is exactly that claim.
#   * The invariance rows are metamorphic and need no reference. They are weaker
#     than they look on CPython-style dicts: Julia's `Dict` iteration order is a
#     function of the key hashes, not of insertion order, so two specs built in
#     different orders already iterate identically (measured). They would still
#     catch an implementation keyed on insertion order, which is the failure the
#     sort exists to prevent — so they are kept, with that limit written down
#     rather than implied.

using Test
using SpinorBEC
using SpinorBEC: content_id

# A small, fixed, fully-specified spec. Deliberately not built from a template or
# a helper: the point is that THESE bytes map to THIS id.
_ref_spec() = Dict{String, Any}(
    "pipeline" => Any[Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "atom" => "Rb87", "dt" => 0.01, "n_steps" => 5,
            "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [4.0, 4.0, 4.0]),
            "interactions" => Dict{String, Any}("c0" => 20.0, "c1" => -0.4)))],
    "defaults" => Dict{String, Any}("kind" => "spinor"),
)

const _REF_ID = "d6c4ff5a501e607d"

@testset "content_id determinism" begin
    @testset "reference spec keeps its id (PIN — it is a directory name)" begin
        @test content_id(_ref_spec()) == _REF_ID
        # If this fails and the change is intended, every cached outdir under the
        # old id is orphaned. Re-baseline deliberately and say so in the commit.
    end

    @testset "invariant under key insertion order" begin
        a = _ref_spec()
        # Same content, every dict rebuilt by inserting keys in reverse.
        function rebuild_reversed(x)
            if x isa AbstractDict
                out = Dict{String, Any}()
                for k in reverse(sort!(collect(keys(x)); by=string))
                    out[string(k)] = rebuild_reversed(x[k])
                end
                out
            elseif x isa AbstractVector
                [rebuild_reversed(v) for v in x]
            else
                x
            end
        end
        @test content_id(rebuild_reversed(a)) == content_id(a)
    end

    @testset "invariant under a YAML round-trip" begin
        a = _ref_spec()
        io = IOBuffer()
        SpinorBEC.YAML.write(io, a)
        b = SpinorBEC.YAML.load(String(take!(io)))
        @test content_id(b) == content_id(a)
    end

    @testset "different specs get different ids (positive control)" begin
        # Without this the rows above could pass on a constant-returning stub.
        a = _ref_spec()
        b = _ref_spec()
        b["pipeline"][1]["ground_state"]["n_steps"] = 6
        @test content_id(a) != content_id(b)
        c = _ref_spec()
        c["pipeline"][1]["ground_state"]["grid"]["n"] = [8, 8, 9]
        @test content_id(a) != content_id(c)
        # Order inside a VECTOR is meaningful (pipeline steps are sequential), so
        # reversing it must change the id.
        d = Dict{String, Any}("pipeline" => Any[1, 2], "defaults" => a["defaults"])
        e = Dict{String, Any}("pipeline" => Any[2, 1], "defaults" => a["defaults"])
        @test content_id(d) != content_id(e)
    end
end
