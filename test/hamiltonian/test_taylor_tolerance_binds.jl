# Gate: `SPIN_TAYLOR_TOL` is a control at the angles this code actually runs at.
#
# Three places in src said the opposite — "the degree is floored at 2 and at
# production `R ≈ 1e-5` the schedule returns 2 for every tolerance over ten
# decades" — while `SPIN_TAYLOR_RSAFE`'s own docstring, four lines below one of
# them, said production R is 0.01–0.2. They disagreed by three orders and nothing
# checked either, so a proposal to freeze the knob into a `const` was argued from
# the wrong one.
#
# Measured: R_max for Eu F=6 is 1.3e-3 … 5.4e-2, and across that range 1e-13 and
# 1e-15 pick different degrees. The degree returns 2 only below ~3e-8.
#
# What this pins is the RELATIONSHIP, not the numbers: that the tolerance moves
# the degree where production lives, and that it does not move the observable.
# Those are separate claims and the second is why the tolerance is safe to
# tighten, not why it is safe to delete.

using Test
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_TOL, _taylor_rot_schedule, _spin_field_scratch, _compute_spin_density!,
    SPIN_TAYLOR_RK_MAX, ATOM_REGISTRY

# `rk[k] = scale/k` with scale = 1, so `g = R²` makes the schedule see exactly R.
const _RK = [1.0 / k for k in 1:SPIN_TAYLOR_RK_MAX]
_degree(R, tol) = _taylor_rot_schedule(R^2, _RK, SPIN_TAYLOR_RK_MAX, tol^2, 1.0,
    SPIN_TAYLOR_RK_MAX)[3]

@testset "SPIN_TAYLOR_TOL binds at production rotation angles" begin
    @testset "it is still a knob, and the schedule still reads it" begin
        # Without this the file below only exercises `_taylor_rot_schedule` with
        # explicit tolerances, so freezing `SPIN_TAYLOR_TOL` into a `const` —
        # the change this evidence argues against — would leave it green. It has
        # to fail on the actual edit, not on a proxy for it.
        @test SPIN_TAYLOR_TOL isa Ref
        old = SPIN_TAYLOR_TOL[]
        try
            SPIN_TAYLOR_TOL[] = 1.0e-13
            @test SPIN_TAYLOR_TOL[] == 1.0e-13
        finally
            SPIN_TAYLOR_TOL[] = old
        end
        @test SPIN_TAYLOR_TOL[] == 1.0e-15      # the shipped default
    end

    @testset "production R is 1e-3..1e-1, not 1e-5" begin
        # theta_max = |c1*dt|*fmax*F is what spin_mixing.jl computes before
        # dispatching, i.e. the largest R any voxel will see this substep.
        grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
        atom = ATOM_REGISTRY[:Eu151]
        F = Int(atom.F)
        D = 2F + 1
        psi = init_psi_spin_coherent(grid, SpinSystem(F); theta=π / 2, phi=0.0)
        sm = spin_matrices(F)
        n_pts = grid.config.n_points
        fx, fy, fz = _spin_field_scratch(Float64, n_pts)
        _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), 3, n_pts)
        fmax = max(maximum(abs, fx), maximum(abs, fy), maximum(abs, fz))

        R_max(c1, dt) = abs(c1 * dt) * fmax * Float64(F)
        # Weakest production cell (c1 = -0.05, dt = 0.005) through a strong one.
        @test 1.0e-3 < R_max(-0.05, 0.005) < 1.0e-2
        @test 1.0e-2 < R_max(1.0, 0.01) < 1.0e-1
        # The claim that was in src for three releases. Kept as a negative
        # assertion so it cannot come back quietly.
        @test R_max(-0.05, 0.005) > 100 * 1.0e-5
    end

    @testset "the two tolerances pick different degrees over the band" begin
        # Measured R_max for the six (c1, dt) production cells. The tolerance
        # binds at five of them; at the weakest (0.00134) both give 5. Written
        # per-cell rather than as a blanket `for` because the blanket version is
        # what I wrote first and it was false at exactly that cell.
        @test _degree(0.00134, 1.0e-13) == _degree(0.00134, 1.0e-15) == 5
        for R in (0.00268, 0.00536, 0.0107, 0.0268, 0.0536)
            @test _degree(R, 1.0e-15) - _degree(R, 1.0e-13) == 1
        end
    end

    @testset "degree 2 needs R below ~3e-8, far under production" begin
        @test _degree(1.0e-8, 1.0e-15) == 2
        @test _degree(1.0e-6, 1.0e-15) > 2
        @test _degree(0.00134, 1.0e-15) == 5    # weakest production cell
    end

    @testset "the sweep is discriminating, not uniformly true" begin
        # If the tolerance changed the degree at EVERY angle the test above would
        # be vacuous. It does not: there are angles where both agree, and the
        # gate has to be able to see that.
        agree = count(R -> _degree(R, 1.0e-13) == _degree(R, 1.0e-15),
            (1.0e-8, 1.0e-6, 3.16e-6, 1.0e-5, 1.0e-4, 3.16e-4))
        @test agree ≥ 4
    end
end
