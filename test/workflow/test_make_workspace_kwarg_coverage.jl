using Test
using SpinorBEC
using SpinorBEC: _MAKE_WORKSPACE_KWARGS, make_workspace

# Pin the kwarg list of `make_workspace` to the documented
# `_MAKE_WORKSPACE_KWARGS` tuple. The list is grouped semantically in
# the source (required core / optional physics / DDI bundle / quasi-2D
# bundle / LHY / runtime) so that adding a new physics term has one
# obvious landing spot.
#
# If `make_workspace` grows a kwarg that is not in the documented
# tuple — or the tuple lists a name no longer accepted — this test
# fails. Same class of guard as `test_lbfgs_forward_coverage.jl`.
@testset "make_workspace kwarg coverage matches documented list" begin
    m = first(methods(make_workspace))
    actual = Set(k for k in Base.kwarg_decl(m) if !endswith(string(k), "..."))
    documented = Set(_MAKE_WORKSPACE_KWARGS)

    missing_from_doc = setdiff(actual, documented)
    @test isempty(missing_from_doc)
    if !isempty(missing_from_doc)
        @info "kwargs accepted by `make_workspace` but missing from `_MAKE_WORKSPACE_KWARGS`" missing_from_doc
    end

    stale_in_doc = setdiff(documented, actual)
    @test isempty(stale_in_doc)
    if !isempty(stale_in_doc)
        @info "names in `_MAKE_WORKSPACE_KWARGS` no longer accepted by `make_workspace`" stale_in_doc
    end
end
