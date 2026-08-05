using Test
using SpinorBEC
using SpinorBEC: _line_search_energy_decrease, gradient_only!, energy_gradient!,
    _project_constraints!, _lbfgs_scratch

# The line search can evaluate its FIRST trial with `energy_gradient!` instead
# of `total_energy`, and hand the caller the gradient it formed on the way.
#
# On the GPU that gradient is free — `energy_gradient!` 1.383 ms against
# `gradient_only!` 1.382 at 24³ D=13, because both are the same fused kernel —
# so the driver skips its own gradient pass and saves a whole `total_energy`
# (1.306 ms of a 5.83 ms iteration, on the ~85 % of iterations where α=1 is
# accepted). On the CPU `energy_gradient!` traverses the term registry twice
# (12.80 ms vs 6.57 + 6.11 separately), so the driver does NOT pass it there.
#
# The MECHANISM is backend-agnostic, though; only the decision to use it is
# gated on the backend. So the contract is testable without a GPU, and that is
# what this file does:
#
#   - passing `grad_out` does not change which step is accepted, or its energy;
#   - the gradient handed back is the one `gradient_only!` would have computed
#     at the accepted iterate — the whole point, since the driver stops
#     computing it;
#   - `grad_valid` is FALSE whenever the accepted point is not the point the
#     gradient was taken at (backtracking, and the steepest-descent expansion),
#     because reusing it there would silently descend the wrong gradient.

function _ls_fixture()
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.5)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.005, n_steps=1),
    )
    psi = copy(ws.state.psi)
    dV = cell_volume(grid)
    g = similar(psi)
    fill!(g, zero(eltype(g)))
    E0 = energy_gradient!(g, psi, ws; k_squared_dev=grid.k_squared)
    _project_constraints!(g, psi, grid, nothing, 1)
    direction = -g
    slope = -sum(abs2, g) * dV
    (; psi, direction, E0, ws, grid, dV, slope, k2=grid.k_squared)
end

@testset "line search: fused first-trial gradient" begin
    f = _ls_fixture()
    common = (f.psi, f.direction, f.E0, f.ws, f.grid, f.dV, nothing, 1)

    @testset "accepted at α_init: same step, and the gradient is reusable" begin
        # α small enough that the first trial is accepted — asserted, not
        # assumed, since every claim below is about that branch.
        αi = 1.0e-3
        a0, E0_, _, n0, v0 = _line_search_energy_decrease(
            common...; slope=f.slope, α_init=αi)
        @test n0 == 1          # first trial accepted; positive control
        @test v0 == false      # no `grad_out` ⇒ nothing to reuse

        gbuf = similar(f.psi)
        fill!(gbuf, zero(eltype(gbuf)))
        a1, E1, psi_acc, n1, v1 = _line_search_energy_decrease(
            common...; slope=f.slope, α_init=αi, grad_out=gbuf, k_squared_dev=f.k2)

        # Passing the buffer must not change the SEARCH: the same step is
        # accepted after the same number of evaluations.
        @test a1 == a0
        @test n1 == n0
        # The energy does move, in the last ulps, and that is the mechanism
        # rather than a defect: with the buffer the first trial is evaluated by
        # `energy_gradient!`, which reads each term's energy off the operator
        # accumulation, and without it by `total_energy`, which sums
        # `energy_decomposition`. Different summation order, same quantity.
        # Bounded by what reads it — the Armijo test, floor ~1e-7 relative —
        # with five orders of margin.
        @test isapprox(E1, E0_; rtol=1.0e-12)
        @test v1 == true

        # And the buffer holds the gradient the driver no longer computes.
        ref = similar(f.psi)
        fill!(ref, zero(eltype(ref)))
        gradient_only!(ref, psi_acc, f.ws)
        @test maximum(abs, gbuf .- ref) == 0.0
        @test maximum(abs, ref) > 0        # not vacuous
    end

    @testset "backtracked: the gradient is NOT offered" begin
        # A step far too long, so the first trial is rejected and the accepted
        # point is somewhere the gradient was never evaluated.
        gbuf = similar(f.psi)
        fill!(gbuf, zero(eltype(gbuf)))
        α, _, psi_acc, n, v = _line_search_energy_decrease(
            common...; slope=f.slope, α_init=1.0e6, grad_out=gbuf, k_squared_dev=f.k2)
        @test n > 1            # it really backtracked; positive control
        @test v == false
        # The buffer was written at α_init, and that is exactly why it must not
        # be reused: it does NOT match the accepted iterate.
        if α > 0
            ref = similar(f.psi)
            fill!(ref, zero(eltype(ref)))
            gradient_only!(ref, psi_acc, f.ws)
            @test maximum(abs, gbuf .- ref) > 0
        end
    end

    @testset "steepest-descent expansion: the gradient is NOT offered" begin
        # `expand=true` walks past the point it evaluated the gradient at.
        gbuf = similar(f.psi)
        fill!(gbuf, zero(eltype(gbuf)))
        α, _, _, n, v = _line_search_energy_decrease(
            common...; slope=f.slope, α_init=1.0e-6, expand=true,
            grad_out=gbuf, k_squared_dev=f.k2)
        @test n > 1            # the expansion phase ran; positive control
        @test v == false
        @test α > 1.0e-6       # and it did move
    end
end
