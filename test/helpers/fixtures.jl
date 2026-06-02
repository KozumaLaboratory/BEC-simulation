# test/helpers/fixtures.jl
#
# Shared test fixtures: standard small grids + the Rb87 / Eu151 reference
# workspaces that ~16 test files reproduce verbatim. Lets a future grid /
# atom-reference tweak land in one place instead of fanning out across
# the suite.
#
# Usage:
#
#     include(joinpath(@__DIR__, "..", "helpers", "fixtures.jl"))
#     grid = test_grid_2d()                              # 16² box=10
#     ws   = test_rb87_workspace_2d(grid; interactions=ip)
#
# The grid/box defaults are deliberately small so the suite runs fast;
# physics tests can override with e.g. `test_grid_2d(32, 16.0)`.

using SpinorBEC
using FFTW

"""
    test_grid_1d(n=128, box=20.0) → Grid{1, Float64}
"""
function test_grid_1d(n::Int=128, box::Float64=20.0)
    make_grid(GridConfig(n, box))
end

"""
    test_grid_2d(n=16, box=10.0) → Grid{2, Float64}

Standard 16² square test grid. Used by ~10 test files for split-step
order checks, ITP smoke tests, Bogoliubov scans, etc.
"""
function test_grid_2d(n::Int=16, box::Float64=10.0)
    make_grid(GridConfig((n, n), (box, box)))
end

"""
    test_grid_3d(n=16, box=10.0) → Grid{3, Float64}
"""
function test_grid_3d(n::Int=16, box::Float64=10.0)
    make_grid(GridConfig((n, n, n), (box, box, box)))
end

"""
    test_rb87_workspace_2d(grid; interactions, sim_params=…, kwargs...) → Workspace

Build the Rb87 reference workspace used as the "I just need a workspace
to run a step on" fixture across the suite. `sim_params` defaults to a
short ITP-mode sweep; pass overrides via `sim_params=` or any other
`make_workspace` kwarg.
"""
function test_rb87_workspace_2d(grid::Grid{2};
    interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
    sim_params=SimParams(; dt=0.01, n_steps=10, imaginary_time=true),
    fft_flags=FFTW.ESTIMATE, kwargs...)
    make_workspace(; grid, atom=Rb87, interactions, sim_params, fft_flags, kwargs...)
end
