# --- Regression test for RTP DDI substep (Bug-4 RTP analogue, 2026-05-02) ---
#
# `_run_simulation_leapfrog!` (RTP) had two integration paths:
#   - need_split  (`_half_potential_step!(ws, dt/2, …)` close + reopen):
#     two DDI(dt/2) substeps per step. φ_{x,y,z} rebuilt between substeps.
#   - merged      (`_half_potential_step!(ws, dt, …)` once per step):
#     one DDI(dt) call. *Rate-correct* — DDI integrated for dt total —
#     but algebraically not equal to the two-substep form because DDI's
#     φ is functional of ψ.
#
# The merged form was a 2nd-order accuracy degradation, not a rate bug:
# a c_dd scan showed super-linear-then-saturating drift (consistent with
# substep-vs-merged accuracy compounding, NOT the linear scaling a rate
# bug would produce). Still, for stiff DDI (Eu c_dd ≈ 7647) the two
# branches gave ~30 % rel-Δψ between save_every=1 and save_every=100,
# so converged ψ depended on save_every. Fix: drop the merge, always
# close + reopen so DDI is always substepped. Same shape as the ITP
# fix in itp_loop.jl.
#
# This test pins both branches: same n_steps + dt, the same converged
# ψ regardless of `save_every`, with a c_dd = 0 control to distinguish
# the bug-class from generic numerical drift.

using SpinorBEC
using Test

@testset "RTP DDI substep (Bug-4 RTP analogue regression)" begin
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    n_steps = 200          # enough to surface the drift, fast to run

    function build_ws(save_every::Int; c_dd_val::Float64)
        grid = make_grid(GridConfig((12, 12, 6), (8.0, 8.0, 4.0)))
        psi0 = init_psi(grid, SpinSystem(F); state=:m_plus_F)
        sp = SimParams(;
            dt=0.005,
            n_steps,
            imaginary_time=false,
            normalize_every=0,
            save_every,
        )
        make_workspace(;
            grid, atom,
            interactions=InteractionParams(50.0, 0.5),
            potential=HarmonicTrap((1.0, 1.0, 2.0)),
            sim_params=sp,
            psi_init=psi0,
            enable_ddi=(c_dd_val > 0),
            c_dd=c_dd_val,
        )
    end

    @testset "DDI on: ψ independent of save_every" begin
        ws_a = build_ws(1; c_dd_val=2000.0)
        ws_b = build_ws(100; c_dd_val=2000.0)
        run_simulation!(ws_a)
        run_simulation!(ws_b)
        max_dev = maximum(abs.(ws_a.state.psi .- ws_b.state.psi))
        @test max_dev < 1.0e-10                          # bytewise post-fix
    end

    @testset "DDI off: control passes" begin
        ws_a = build_ws(1; c_dd_val=0.0)
        ws_b = build_ws(100; c_dd_val=0.0)
        run_simulation!(ws_a)
        run_simulation!(ws_b)
        max_dev = maximum(abs.(ws_a.state.psi .- ws_b.state.psi))
        @test max_dev < 1.0e-10
    end
end
