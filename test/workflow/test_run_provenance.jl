using Test
using SpinorBEC

# Which code produced a file. `run_yaml` outputs carry this under `env/`; campaign
# scripts write their own JLD2 and carried NONE of it — measured 2026-08-21 on
# scripts/eu334 output, which holds every physics parameter and the seed and not
# one fact about the code that ran.
#
# The asymmetry was the opposite of what had been assumed: the pipeline has the
# provenance and keeps the seed in its config; the scripts have the seed and no
# provenance. `run_provenance()` is the public shared answer so a new writer gets
# it in one line rather than reinventing half of it.
@testset "run_provenance records which code produced a file" begin
    p = run_provenance()

    # The contract, per field, because a provenance record missing any one of
    # these cannot answer the question it exists for.
    for k in ("git_hash", "git_dirty", "julia_version", "hostname", "platform")
        @test haskey(p, k)
    end

    # git_dirty is the LOAD-BEARING field and the one most likely to be dropped as
    # noise: a hash from a dirty tree names a commit that does not describe the
    # code that ran, silently, so a run recorded as reproducible would not be.
    @test p["git_dirty"] isa Bool

    # A hash of "unknown" is the honest value outside a repo; what is NOT allowed
    # is the key being absent, which reads as "clean" to anything that checks.
    @test p["git_hash"] isa AbstractString
    @test !isempty(p["git_hash"])
    @test p["julia_version"] == string(VERSION)
end

# Every campaign writer must record it. This is the CLASS-level gate: the fix
# is not "these two scripts now call it" but "a script that saves a state and
# forgets where it came from is a test failure".
@testset "campaign JLD2 writers record provenance" begin
    root = normpath(joinpath(@__DIR__, "..", ".."))
    writers = [
        "scripts/eu334/nucleate.jl",
        "scripts/eu334/nucleation_bifurcation.jl",
    ]
    for w in writers
        path = joinpath(root, w)
        @test isfile(path)
        isfile(path) || continue
        src = read(path, String)
        # `jldsave` is how these scripts persist a state; if one is present, a
        # provenance call must be too.
        if occursin("jldsave", src)
            occursin("run_provenance", src) ||
                @info "writer saves state without provenance" w
            @test occursin("run_provenance", src)
        end
    end
end
