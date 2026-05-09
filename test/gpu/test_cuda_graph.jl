using Test
using SpinorBEC

# CUDA Graph capture for split_step is currently experimental and falls
# back to plain split_step!. These tests verify that the stub path is
# functionally correct (matches split_step! exactly) so the API stays
# stable while the graph implementation is worked on.
@testset "split_step_captured! — stub fallback correctness" begin
    # CPU path: stub in main module
    cfg = GridConfig((16, 16, 16), (6.0, 6.0, 6.0))
    grid = make_grid(cfg)
    atom = AtomSpecies("Na23", 3.8e-26, 1, 52.0*5.29e-11, 54.3*5.29e-11, 0.0)
    ip = InteractionParams(30.0, 0.0)
    sp = SimParams(; dt=0.005, n_steps=1)
    ws_a = make_workspace(;
        grid, atom, interactions=ip, sim_params=sp,
        potential=HarmonicTrap(1.0, 1.0, 1.0), zeeman=ZeemanParams(),
    )
    ws_b = make_workspace(;
        grid, atom, interactions=ip, sim_params=sp,
        potential=HarmonicTrap(1.0, 1.0, 1.0), zeeman=ZeemanParams(),
    )

    # Run 10 steps each; captured path should match plain step-for-step
    for _ in 1:10
        SpinorBEC.split_step!(ws_a)
        SpinorBEC.split_step_captured!(ws_b)
    end
    # Wavefunctions agree to machine precision
    diff = sum(abs2, ws_a.state.psi .- ws_b.state.psi)
    @test diff < 1e-20

    # invalidate is a no-op on CPU
    invalidate_split_step_graph!(ws_a)
    @test true  # just asserting no error
end
