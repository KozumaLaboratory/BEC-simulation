# Airtight guard: ONLY the allow-listed files may compute an odd (first) FFT
# derivative inline (`im * … .k[…]`), and those functions are behaviourally
# oracle-tested (test_fft_nyquist_null.jl) to null the Nyquist mode. Any NEW
# file with the pattern fails here — regardless of comments — forcing the author
# to either route through the nulling helpers or consciously extend the allow-list
# AND add a Nyquist oracle. Closes the token-comment loophole of a grep guard.

using SpinorBEC
using Test

@testset "odd FFT derivative: exact allow-list (Nyquist-null enforced)" begin
    srcdir = abspath(joinpath(@__DIR__, "..", "..", "src"))
    isdir(srcdir) || (srcdir = abspath(joinpath(@__DIR__, "..", "src")))

    odd_line(l) =
        occursin(r"im\s*\*[^\n]*\.k\[", l) &&
        !occursin("squared", l) && !occursin("^2", l) &&
        !occursin("k2", l) && !occursin("k_sq", l)

    # the ONLY files permitted to hand-roll ik·ψ_k; both are Nyquist-nulled and
    # covered by test_fft_nyquist_null.jl (behavioural oracle).
    allow = Set(["analysis/currents.jl", "foundation/fft_utils.jl"])

    sites = String[]
    for (root, _, files) in walkdir(srcdir), f in files
        endswith(f, ".jl") || continue
        path = joinpath(root, f)
        any(odd_line, readlines(path)) && push!(sites, relpath(path, srcdir))
    end

    unexpected = setdiff(Set(sites), allow)
    missing_expected = setdiff(allow, Set(sites))
    if !isempty(unexpected)
        @info "NEW inline ik·ψ_k derivative — null the Nyquist mode + extend allow-list + oracle" unexpected
    end
    @test isempty(unexpected)              # no un-vetted odd-derivative sites
    @test isempty(missing_expected)        # allow-list stays in sync with reality
end
