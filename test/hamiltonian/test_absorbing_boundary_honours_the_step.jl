using Test
using SpinorBEC
using SpinorBEC: apply_rt_dissipation!

# The absorbing mask must absorb for the step it is applied to.
#
# `compute_absorbing_mask` bakes `exp(-strength·α(x)·dt)` at build time, using
# `sim_params.dt` because that is the only dt available then
# (`make_workspace.jl:442`). `apply_rt_dissipation!` then applied it verbatim,
# discarding its own `dt` argument. Fixed-dt drivers were right by construction;
# the adaptive ones — `_run_yoshida_adaptive!` and both loops in
# `solvers/adaptive.jl` — hand it a `dt_step` that changes every accepted step.
#
# MEASURED 2026-08-07, 32 points, width 2.0, strength 5.0, dt_build 1e-3;
# absorbed fraction per step against the correct value:
#
#     dt/dt_build   0.25    0.5     2.0     5.0
#     error        +299%   +100%   -50%    -80%
#
# The fix is exact rather than approximate: absorption is a pure exponential in
# dt, so `mask^(dt/dt_build)` IS the mask that `compute_absorbing_mask` would
# have built at `dt`. Verified bit-for-bit below.

const _AB = AbsorbingBoundary(; width=2.0, strength=5.0, power=2)
const _DT0 = 1.0e-3

grid32() = make_grid(GridConfig(32, 10.0))

@testset "the absorbing mask honours the step it is applied to" begin
    g = grid32()
    m0 = compute_absorbing_mask(g, _AB, _DT0, CPUBackend())

    # CALIBRATION. Every assertion below compares two masks. If the fixture
    # produced a mask of all ones — width outside the box, strength zero — they
    # would agree for every dt and the gate would pass while measuring nothing.
    @testset "the fixture actually absorbs" begin
        @test minimum(m0) < 0.999
        @test maximum(m0) ≈ 1.0            # the interior must be untouched
        @test count(<(1.0), m0) >= 4       # a real boundary region, not one cell
    end

    @testset "rescaling equals rebuilding, exactly" begin
        for f in (0.25, 0.5, 1.0, 2.0, 5.0)
            rebuilt = compute_absorbing_mask(g, _AB, f * _DT0, CPUBackend())
            psi = ones(ComplexF64, 32, 1)
            ref = ones(ComplexF64, 32, 1)
            apply_absorbing_boundary!(psi, m0, 1, 1; dt_ratio=f)
            apply_absorbing_boundary!(ref, rebuilt, 1, 1)
            @test maximum(abs, psi .- ref) < 1e-15
        end
    end

    # NEGATIVE CONTROL. `dt_ratio` must matter. Without this, an implementation
    # that ignored the keyword — the defect — would satisfy the arm above at
    # f = 1.0 and be caught nowhere else if the loop ever shrank.
    @testset "dt_ratio changes the result" begin
        a = ones(ComplexF64, 32, 1)
        b = ones(ComplexF64, 32, 1)
        apply_absorbing_boundary!(a, m0, 1, 1; dt_ratio=1.0)
        apply_absorbing_boundary!(b, m0, 1, 1; dt_ratio=5.0)
        @test maximum(abs, a .- b) > 1e-4
        # and in the physical direction: a longer step absorbs MORE
        @test minimum(abs, b) < minimum(abs, a)
    end

    # ACROSS THE BOUNDARY. The arms above call the mask routine directly; the
    # defect lived in the caller, which had the right dt and dropped it. Drive
    # `apply_rt_dissipation!` — the epilogue every real-time step runs — with a
    # dt that differs from the workspace's, which is exactly what the adaptive
    # loops do.
    @testset "apply_rt_dissipation! passes its own dt through" begin
        ws = make_workspace(;
            grid=grid32(), atom=resolve_atom(:Na23),
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            potential=HarmonicTrap((1.0,)),
            absorbing_boundary=_AB,
            sim_params=SimParams(; dt=_DT0, n_steps=1, save_every=1),
        )
        @test ws.absorbing_mask !== nothing
        @test ws.sim_params.dt == _DT0

        function absorbed(dt_step)
            fill!(ws.state.psi, 1.0 + 0im)
            apply_rt_dissipation!(ws, dt_step, size(ws.state.psi, 2), 1)
            1 - minimum(abs, ws.state.psi)
        end

        one_step = absorbed(_DT0)
        five_step = absorbed(5 * _DT0)
        quarter = absorbed(0.25 * _DT0)

        @test one_step > 1e-6                       # the fixture is live
        # the sizes must order correctly, which the old code could not do —
        # it returned `one_step` for all three
        @test five_step > one_step > quarter
        # and quantitatively: exp(-s·α·5dt) = (exp(-s·α·dt))^5
        @test (1 - five_step) ≈ (1 - one_step)^5 rtol = 1e-12
        @test (1 - quarter) ≈ (1 - one_step)^0.25 rtol = 1e-12
    end
end
