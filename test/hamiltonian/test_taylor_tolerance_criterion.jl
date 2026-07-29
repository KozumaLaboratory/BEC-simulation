# Gate: the Taylor truncation error must stay negligible against the SPLITTING
# error — i.e. the tolerance is a consequence of the caller's `dt`, not a
# decision the caller is asked to make.
#
# `SPIN_TAYLOR_TOL` should not be a user-facing knob: setting it correctly needs
# a comparison against the integrator's own error, and demanding that knowledge
# per call site is a design failure. So the relationship is what is pinned here,
# not the number — someone who has never heard of 1e-13 still finds out when it
# stops holding.
#
# Measured at production scale (bench/taylor_tolerance_sweep.jl, Eu F=6, 32³,
# dt = 0.002): splitting error |E(dt) − E(dt/2)| = 7.6e-3 against a truncation
# error of 2.4e-13, a ratio of 3e-11 — and even at the loosest tolerance tested,
# 1e-5, the ratio is 3.3e-5. The config below is small and short so the gate is
# cheap; the RATIO is what travels between scales, not the absolute numbers.
#
# Lives in the ci tier, not fast: it runs `find_ground_state`, which the fast
# tier excludes by construction.

using Test
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_TOL

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
    psi0 = init_psi(grid, SpinSystem(2); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    DT, NST = 0.004, 30

    _energy(dt, n_steps) = find_ground_state(;
        grid, atom=Na23,
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

    # Positive control. Without it "truncation is negligible" could hold because
    # the comparison cannot fail, rather than because the tolerance is right: an
    # absurd tolerance must make the rotation the dominant error.
    @testset "an absurd tolerance DOES breach the criterion" begin
        old = SPIN_TAYLOR_TOL[]
        SPIN_TAYLOR_TOL[] = 0.3
        try
            e_bad = _with_taylor(true) do
                _energy(DT, NST)
            end
            @test abs(e_bad - e_exact) > 1e-3 * split_err
        finally
            SPIN_TAYLOR_TOL[] = old
        end
    end
end
