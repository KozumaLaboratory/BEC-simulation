using SpinorBEC
using Test

# A `TabulatedLHY` holds host `Vector{Float64}` tables, so it cannot be captured
# into a GPU kernel. Broadcasting `_lhy_V` over a device array therefore dies:
#
#   KernelError: passing non-bitstype argument
#     .val is of type FullBdGLHY which is not isbits
#       .densities is of type Vector{Float64} which is not isbits
#
# `_lhy_potential_field` exists precisely to hide that: the CUDA extension
# overrides it for `TabulatedLHY` (uploads the table once per `objectid`, O(1)
# uniform-grid lookup), and its CPU method is the plain broadcast. Every site
# that materialises V_LHY as an array must go through it.
#
# Two sites did not — `apply_step!(::LHYTerm, …)` and `_grad_lhy!`, the latter
# being the L-BFGS gradient path. Nothing caught it because the failure needs
# THREE things at once (`method: lbfgs` + a tabulated `lhy:` kind +
# `backend: gpu`), and until #179 the L-BFGS path never built a table at all, so
# no kernel was ever asked to carry one. #179 fixing that exposed the latent gap:
# `config_texture_bscan_lhy_full_bdg.yaml` needs BOTH fixes to run.
#
# This gate is structural because the behavioural one only fires on a machine
# with a GPU. It runs everywhere and is cheap.

@testset "no bare `_lhy_V` broadcast can reach a device array" begin
    src = abspath(joinpath(@__DIR__, "..", "..", "src"))
    isdir(src) || (src = abspath(joinpath(@__DIR__, "..", "src")))

    # Strip `#` comments and `"""` docstrings: this file's own prose quotes the
    # forbidden pattern, and so do the comments explaining the fix.
    function code_of(path)
        body = replace(read(path, String), r"\"\"\"(?s).*?\"\"\"" => "")
        join((replace(l, r"#.*$" => "") for l in split(body, '\n')), "\n")
    end

    # `_lhy_V.(…)` — a dotted (broadcast) call, as opposed to the scalar
    # `_lhy_V(n, lhy)` the fused per-voxel kernels legitimately use.
    bcast = r"_lhy_V\s*\.\("

    # The ONLY place allowed to broadcast it is `_lhy_potential_field` itself,
    # which is the seam the CUDA extension replaces.
    allow = Set(["hamiltonian/integrator/propagators.jl"])

    sites = String[]
    for (root, _, files) in walkdir(src), f in files
        endswith(f, ".jl") || continue
        path = joinpath(root, f)
        occursin(bcast, code_of(path)) && push!(sites, relpath(path, src))
    end

    unexpected = setdiff(Set(sites), allow)
    if !isempty(unexpected)
        @info """A bare `_lhy_V.(…)` broadcast outside `_lhy_potential_field`. On a \
device array with a TabulatedLHY this is a KernelError, and on CPU it silently \
works — so it passes every CPU test. Route it through \
`_lhy_potential_field(lhy, density, RT)` instead.""" unexpected
    end
    @test isempty(unexpected)

    # Keep the allow-list honest: if `_lhy_potential_field` stops broadcasting
    # (e.g. someone rewrites it as a loop), this list is stale and the gate has
    # quietly stopped guarding anything.
    @test Set(sites) == allow

    # And the two repaired sites must still route through the seam, so a revert
    # is caught by name rather than only by the absence of the old pattern.
    term = read(joinpath(src, "hamiltonian/terms/lhy/lhy_term.jl"), String)
    @test count("_lhy_potential_field(lhy", term) >= 2
end
