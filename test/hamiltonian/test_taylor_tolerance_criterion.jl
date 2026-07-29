# Gate: the Taylor truncation error stays negligible against the SPLITTING error
# — the tolerance is a consequence of the caller's `dt`, not a decision the
# caller is asked to make.
#
# `SPIN_TAYLOR_TOL` should not be a user-facing knob: setting it correctly needs
# a comparison against the integrator's own error, and demanding that knowledge
# per call site is a design failure. So the relationship is what is pinned here.
#
# Measured at production scale (bench/taylor_tolerance_sweep.jl, Eu F=6, 32³,
# dt = 0.002): splitting error |E(dt) − E(dt/2)| = 7.6e-3 against a truncation
# error of 2.4e-13 — a ratio of 3e-11.
#
# WHY `tol` IS NOT THE POSITIVE CONTROL. The obvious control — loosen `tol` and
# watch the criterion break — does NOT work here, and finding that out is the
# point of insisting on one. The degree is floored at 2, so at production
# `R = dt·|v|·F ≈ 0.01–0.2` the schedule returns degree 2 for every tolerance
# from 1e-15 up to 1, and the sweep duly measures the same mean degree 2.00 at
# tol = 1e-5 and 1e-7. Even that floor puts the truncation at 3.3e-5 of the
# splitting error, which passes. So the criterion is held by the DEGREE FLOOR,
# not by the tolerance, and a control built on `tol` would be asserting
# something that cannot fail.
#
# The control below attacks the floor instead: an order-1 truncation of the same
# rotation must be materially worse. That makes the assertion above a statement
# about a property something could break, rather than a tautology.
#
# Lives in the ci tier, not fast: it runs `find_ground_state`.

using Test
using LinearAlgebra: norm
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_RK_MAX,
    _taylor_rot_schedule, _cpu_spin_rk, spin_tridiag_bands, spin_matrices,
    _apply_ddi_rotation!

function _with_taylor(f, on::Bool)
    old = SPIN_TAYLOR_ENABLED[]
    SPIN_TAYLOR_ENABLED[] = on
    try
        f()
    finally
        SPIN_TAYLOR_ENABLED[] = old
    end
end

@testset "Taylor truncation ≪ splitting error" begin
    grid = make_grid(GridConfig((10, 10, 10), (9.0, 9.0, 9.0)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    DT, NST = 0.004, 30

    _energy(dt, n_steps) = find_ground_state(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 8.0, 1 => -0.4)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)), psi_init=psi0,
        dt, n_steps, tol=0.0, save_every=n_steps,
        enable_ddi=true, c_dd=0.6, ddi_padding=true,
        verbose=false).energy

    # Both references use the EXACT rotation, so their difference is the
    # splitting error alone: what `dt` already costs, before any truncation.
    e_exact, e_half = _with_taylor(false) do
        (_energy(DT, NST), _energy(DT / 2, 2NST))
    end
    split_err = abs(e_half - e_exact)
    @test split_err > 0        # a degenerate reference would make this vacuous

    e_taylor = _with_taylor(true) do
        _energy(DT, NST)
    end
    @test abs(e_taylor - e_exact) < 1e-3 * split_err

    # The degree floor is what holds the criterion, so pin it directly.
    @testset "the schedule never returns a degree below 2" begin
        rk = _cpu_spin_rk(Float64, DT)
        for g in (0.0, 1e-8, 1.0, 1e4), tol in (1e-15, 1e-5, 1.0)
            _, _, kv = _taylor_rot_schedule(g, rk, SPIN_TAYLOR_RK_MAX, tol^2, 1.0)
            @test kv >= 2
        end
    end

    # Positive control, aimed at the floor rather than at `tol`.
    @testset "an order-1 truncation IS materially worse" begin
        F, D = 6, 13
        sm = spin_matrices(F)
        n = (4, 4, 4)
        Ns = prod(n)
        psi = reshape([ComplexF64(sin(3i), cos(2i)) for i in 1:(Ns * D)], n..., D)
        px = reshape([0.4sin(i) for i in 1:Ns], n)
        py = reshape([0.4cos(i) for i in 1:Ns], n)
        pz = reshape([0.4sin(2i) for i in 1:Ns], n)
        dt = 0.05

        exact = _with_taylor(false) do
            p = copy(psi)
            _apply_ddi_rotation!(p, px, py, pz, sm, dt, 3; imaginary_time=false)
            p
        end
        taylor = _with_taylor(true) do
            p = copy(psi)
            _apply_ddi_rotation!(p, px, py, pz, sm, dt, 3; imaginary_time=false)
            p
        end

        # Order-1: ψ + (−i·dt)·(v·F)ψ, built from the SAME bands the kernel uses,
        # so the comparison isolates the order and nothing else.
        mz, sxu, syu = spin_tridiag_bands(sm, Float64)
        P = reshape(copy(psi), Ns, D)
        out = similar(P)
        for i in 1:Ns
            vx, vy, vz = px[i], py[i], pz[i]
            for c in 1:D
                Aw = vz * mz[c] * P[i, c]
                c < D && (Aw += (vx * sxu[c] + vy * syu[c]) * P[i, c + 1])
                c > 1 && (Aw += conj(vx * sxu[c - 1] + vy * syu[c - 1]) * P[i, c - 1])
                out[i, c] = P[i, c] + (-im * dt) * Aw
            end
        end
        order1 = reshape(out, n..., D)

        err_taylor = norm(vec(taylor) .- vec(exact)) / norm(vec(exact))
        err_order1 = norm(vec(order1) .- vec(exact)) / norm(vec(exact))
        @test err_order1 > 1e4 * max(err_taylor, eps())
    end
end
