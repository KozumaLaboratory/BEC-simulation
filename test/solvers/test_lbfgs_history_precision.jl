using Test
using SpinorBEC
using SpinorBEC:
    find_ground_state_lbfgs, _history_array_type, _history_copy,
    _lbfgs_direction, _realdot

# `history_precision = Float32` stores the L-BFGS s/y curvature history in
# single precision. It exists for one reason: the two-loop recursion reads each
# of the `2m` history arrays twice per direction, which at m = 20, 24³, D = 13
# is 230 MB of streaming traffic and measured 10.3 ms — one core's bandwidth,
# and the single largest item in a 32 ms iteration.
#
# What it must NOT do is change what the solver converges to. The history only
# steers the search DIRECTION; `grad`, `rho_hist`, the energy and the Armijo
# test all stay Float64, and a direction that is merely less well scaled costs
# iterations, not correctness. So this gates the boundary, not the arithmetic:
#
#   - the history really is stored in single precision (else everything below
#     is measuring Float64 twice),
#   - the direction it produces is still a DESCENT direction,
#   - the two solves land on the same energy,
#   - and it is refused, loudly, where it has not been measured.
#
# What it does NOT gate is that turning it on is a good idea, because that
# depends on the problem: measured at 24³ over three c1_ratio values it is
# −9 % wall on contact (same iteration count, 36 either way) and +3 to +21 %
# on +DDI (same −3.6 ms/iteration, but 16-36 % more iterations). Hence the
# Float64 default.

@testset "L-BFGS history precision" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    common = (;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.5)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        initial_state=:polar, verbose=false, n_steps=60, tol=1.0e-8,
        m_lbfgs=8,
    )

    @testset "the history is actually narrowed" begin
        psi = zeros(ComplexF64, 4, 4, 4, 3)
        @test _history_array_type(psi, Float64) === Array{ComplexF64, 4}
        @test _history_array_type(psi, Float32) === Array{ComplexF32, 4}
        # Never upcast: a Float32 iterate keeps a Float32 history whatever is
        # asked for, because a Float64 history of it stores precision that is
        # not there.
        psi32 = zeros(ComplexF32, 4, 4, 4, 3)
        @test _history_array_type(psi32, Float64) === Array{ComplexF32, 4}
        @test _history_array_type(psi32, Float32) === Array{ComplexF32, 4}
        @test_throws ArgumentError _history_array_type(psi, Float16)

        x = ComplexF64[1 + 2im, 3 - 4im]
        @test eltype(_history_copy(Array{ComplexF32, 1}, x)) === ComplexF32
        @test _history_copy(Array{ComplexF64, 1}, x) == x
        @test _history_copy(Array{ComplexF64, 1}, x) !== x     # a copy, not an alias
    end

    r64 = find_ground_state_lbfgs(; common..., history_precision=Float64)
    r32 = find_ground_state_lbfgs(; common..., history_precision=Float32)

    @testset "the run really used it" begin
        # Without this the agreement below could hold because the kwarg never
        # reached the history at all.
        #
        # Asserted on the CONTAINER's element type, not on `s[1]`. The first
        # version indexed, and it errored on main: the driver empties the
        # history on a line-search failure and `stop_at_floor` then breaks
        # immediately, so a run that ends at its gradient floor returns EMPTY
        # vectors. The container type is what the kwarg actually chose and it
        # survives that, so this gate no longer depends on how the solve
        # happened to stop.
        s64, y64, _ = r64.lbfgs_history
        s32, y32, _ = r32.lbfgs_history
        @test eltype(s64) === Array{ComplexF64, 4}
        @test eltype(y64) === Array{ComplexF64, 4}
        @test eltype(s32) === Array{ComplexF32, 4}
        @test eltype(y32) === Array{ComplexF32, 4}
    end

    @testset "the direction is still a descent direction" begin
        # Built from a SYNTHETIC curvature pair rather than from whatever the
        # solve happened to leave behind: a run that stops at its gradient
        # floor returns an empty history, and a two-loop over an empty history
        # is just steepest descent, which is trivially a descent direction.
        # That would be a gate that cannot fail.
        dV = 0.125
        n = (4, 4, 4, 3)
        g = ComplexF64[cis(0.3i) * (1 + 0.01i) for i in 1:prod(n)]
        g = reshape(g, n)
        s = ComplexF32.(reshape(ComplexF64[cis(0.7i) for i in 1:prod(n)], n))
        # ⟨s,y⟩ > 0 is the curvature condition the driver enforces before
        # storing a pair, so a valid history has it by construction.
        y = ComplexF32.(0.4f0 .* s)
        rho = [1.0 / (_realdot(s, y) * dV)]
        @test rho[1] > 0
        d = _lbfgs_direction(g, [s], [y], rho, dV)
        @test eltype(d) === ComplexF64          # F32 history, F64 direction
        @test _realdot(g, d) * dV < 0
    end

    @testset "same minimum" begin
        # A coarser curvature memory may cost iterations; it may not move the
        # answer. Bound it by the solver's own floor rather than a round number:
        # both runs stop on an energy comparison, so agreement to ~|grad| is all
        # that is on offer, and the loose factor is there for the iteration
        # count differing.
        @test isapprox(r32.energy, r64.energy; rtol=1.0e-6)
        @test r32.grad_norm < 1.0e-4
        # Whichever way each run stopped, it has to have taken real steps —
        # two solves that both did nothing would also agree.
        @test r64.last_step > 5
        @test r32.last_step > 5
    end

    @testset "refused where it has not been measured" begin
        # Not a style choice: the device `_realdot` is cuBLAS `dot`, which has
        # no mixed-precision form, so a Float32 history against a Float64
        # iterate would silently fall out to a generic reduction.
        #
        # A `SubArray` stands in for the device array here — it exercises the
        # same `psi isa Array` branch without this file needing CUDA. Stated
        # rather than implied, because it is a stand-in: what is gated is that
        # a non-`Array` iterate is refused, not anything CUDA-specific.
        nonarray = view(zeros(ComplexF64, 4, 4, 4, 3), :, :, :, :)
        @test !(nonarray isa Array)
        @test_throws ArgumentError _history_array_type(nonarray, Float32)
        @test _history_array_type(nonarray, Float64) === typeof(nonarray)
    end
end
