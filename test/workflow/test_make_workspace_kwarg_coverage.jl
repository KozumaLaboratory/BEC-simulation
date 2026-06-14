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

@testset "make_workspace rejects a psi_init mismatched with the atom's F" begin
    # The spinor dimension is set by the atom's F (D = 2F+1). A psi_init with the
    # wrong component count used to segfault in the diagonal step; it must now
    # throw a clear error instead.
    grid = make_grid(GridConfig{2}((8, 8), (4.0, 4.0)))
    sp = SimParams(; dt=0.01, n_steps=1)
    # Eu151 is F=6 (D=13); feed a D=3 (F=1) state.
    bad_components = zeros(ComplexF64, 8, 8, 3)
    @test_throws ArgumentError make_workspace(;
        grid, atom=Eu151, interactions=InteractionParams(Dict(0 => 1.0)),
        sim_params=sp, psi_init=bad_components)
    # wrong spatial shape
    bad_spatial = zeros(ComplexF64, 16, 16, 3)
    @test_throws ArgumentError make_workspace(;
        grid, atom=Rb87, interactions=InteractionParams(Dict(0 => 1.0)),
        sim_params=sp, psi_init=bad_spatial)
    # matching state builds fine
    ok = zeros(ComplexF64, 8, 8, 3)
    ok[:, :, 1] .= 1.0
    ws = make_workspace(;
        grid, atom=Rb87, interactions=InteractionParams(Dict(0 => 1.0)),
        sim_params=sp, psi_init=ok)
    @test ws.spin_matrices.system.n_components == 3
end
