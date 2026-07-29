# Gate: the Taylor spin rotation's truncation error stays negligible against the
# error the caller already accepted by choosing `dt`.
#
# Expressed through `ErrorBudget` / `NegligibleErrorSpec`
# (src/workflow/validation/error_budget.jl) rather than as hand-rolled
# assertions, so the thing being pinned is the RELATIONSHIP and the positive
# control is structurally mandatory: a control that fails to breach makes the
# verdict `:indeterminate`, never a green pass.
#
# Measured at production scale (bench/taylor_tolerance_sweep.jl, Eu F=6, 32³,
# dt = 0.002): baseline |E(dt) − E(dt/2)| = 7.6e-3, truncation 2.4e-13 — a ratio
# of 3e-11.
#
# FINDING THE CONTROL TOOK TWO WRONG GUESSES, AND THAT IS THE POINT.
#
#   1. Loosen `SPIN_TAYLOR_TOL`. Cannot breach: the degree is floored at 2, and
#      at production `R = |scale|·|v|·F ≈ 1e-5` the schedule returns 2 for every
#      tolerance over ten decades — the sweep measures the same mean degree 2.00
#      at tol 1e-5 and 1e-7.
#   2. Lower the degree floor to 1. Also cannot breach: an order-1 rotation is
#      still ~1e-8 relative, four orders inside the splitting error. So the
#      criterion is NOT held by the floor either, which is what I had claimed.
#
# What actually holds it is that `R` is tiny — the rotation is nowhere near the
# binding error at any order ≥ 1. The only control left is to REMOVE the
# operator: `SPIN_TAYLOR_DEGREE_CAP[] = 0` skips the Horner loop, leaving ψ
# untouched. That is also the honest general form of the question — show the
# observable moves when the operator is absent, or "negligible" meant nothing.
#
# Both wrong guesses would have shipped as green gates asserting nothing. They
# were caught because `NegligibleErrorSpec` returns `:indeterminate`, not
# `:pass`, when the control fails to breach.
#
# HOW FAR THE MARGIN REACHES. The ratio is not scale-free: the baseline falls as
# dt² while the truncation accumulates over ~1/dt rotations, so the ratio grows
# roughly as dt⁻³ — about three decades of margin per factor of ten in dt.
# Production dt is 1e-3–5e-3, so 3e-11 is comfortable; but the number belongs to
# the dt it was established at.
#
# Lives in the ci tier, not fast: it runs `find_ground_state`.

using Test

using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_RK_MAX, SPIN_TAYLOR_DEGREE_CAP,
    NegligibleErrorSpec, measure_error_budget, check, passed,
    _taylor_rot_schedule, _cpu_spin_rk

function _with_taylor(f, on::Bool)
    old = SPIN_TAYLOR_ENABLED[]
    SPIN_TAYLOR_ENABLED[] = on
    try
        f()
    finally
        SPIN_TAYLOR_ENABLED[] = old
    end
end

# Run `f` with the Horner degree clamped from above. `k = 0` removes the
# rotation entirely.
function _with_degree_cap(f, k::Int)
    old = SPIN_TAYLOR_DEGREE_CAP[]
    SPIN_TAYLOR_DEGREE_CAP[] = k
    try
        f()
    finally
        SPIN_TAYLOR_DEGREE_CAP[] = old
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

    budget = measure_error_budget(;
        label="Taylor spin rotation",
        # Both references use the EXACT rotation, so their difference is the
        # splitting error alone: what `dt` already costs.
        exact=() -> _with_taylor(false) do
            _energy(DT, NST)
        end,
        refined=() -> _with_taylor(false) do
            _energy(DT / 2, 2NST)
        end,
        approx=() -> _with_taylor(true) do
            _energy(DT, NST)
        end,
        # Same pipeline, same observable, operator removed. Two weaker
        # controls were tried first and neither could breach — see the header.
        control=() -> _with_taylor(true) do
            _with_degree_cap(0) do
                _energy(DT, NST)
            end
        end,
        baseline_label="splitting error, dt vs dt/2",
        approximation_label="Taylor truncation",
        control_label="rotation removed (degree cap 0)",
    )

    result = check(NegligibleErrorSpec(1e-3), budget)
    @info "error budget" summary = result.summary
    # `passed` is false for BOTH :fail and :indeterminate — a control that
    # cannot breach is not a green result here, it is a refusal to judge.
    @test passed(result)

    # The floor is not what holds the criterion, but it IS what makes `tol`
    # unable to degrade the rotation — the reason guess (1) failed. Pin it so
    # that fact stays true and the header stays honest.
    @testset "tol cannot drive the degree below 2" begin
        rk = _cpu_spin_rk(Float64, DT)
        for g in (0.0, 1e-8, 1.0, 1e4), tol in (1e-15, 1e-5, 1.0)
            _, _, kv = _taylor_rot_schedule(g, rk, SPIN_TAYLOR_RK_MAX, tol^2, 1.0)
            @test kv >= 2
        end
    end
end
