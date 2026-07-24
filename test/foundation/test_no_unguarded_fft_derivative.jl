# Meta-guard: any src file that computes an ODD (first) FFT derivative
# (`im * … .k[…] * …`) MUST also contain a Nyquist-null guard, so a new
# hand-rolled derivative can't silently reintroduce the k=±N/2 checkerboard.
# Even-order operators (kinetic k², k_squared) use `k.^2`/`k_squared` and don't
# match the odd pattern.

using Test

@testset "no un-guarded Nyquist FFT first-derivative" begin
    srcdir = abspath(joinpath(@__DIR__, "..", "..", "src"))
    isdir(srcdir) || (srcdir = abspath(joinpath(@__DIR__, "..", "src")))

    # odd first-derivative: `im * … .k[…]` (multiply by ik), excluding squared forms
    odd_line(l) =
        occursin(r"im\s*\*[^\n]*\.k\[", l) &&
        !occursin("squared", l) && !occursin("^2", l) &&
        !occursin("k2", l) && !occursin("k_sq", l)
    has_guard(txt) = occursin("nyq", txt) || occursin("Nyquist", txt)

    offenders = String[]
    for (root, _, files) in walkdir(srcdir), f in files
        endswith(f, ".jl") || continue
        path = joinpath(root, f)
        lines = readlines(path)
        any(odd_line, lines) || continue
        txt = join(lines, "\n")
        has_guard(txt) || push!(offenders, relpath(path, srcdir))
    end

    if !isempty(offenders)
        @info "un-guarded odd FFT derivative files (add a Nyquist null!)" offenders
    end
    @test isempty(offenders)
end
