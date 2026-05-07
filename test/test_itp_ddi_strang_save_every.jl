# --- Regression test for Bug-4 (ITP merged-loop DDI half-rate, 2026-05-02) ---
#
# Pre-fix `_run_itp_loop!` had two integration paths:
#   - need_split (taken when step % save_every == 0): correct, integrates
#     DDI for `dt` per step (close + reopen, two `_ddi_step!(dt/2)` calls).
#   - merged    (taken otherwise): incorrect, integrated DDI for `dt/2`
#     per step (a single `_ddi_step!(dt/2)` between outer_fwd(dt/2) and
#     outer_bwd(dt/2)). The outer parts were correctly merged to dt total
#     per step, but DDI was halved.
#
# Symptom: the converged ground state depended on `save_every` whenever
# DDI was active. With c_dd ≠ 0, save_every=1 vs save_every=100 gave
# different ψ and energies (~7 % shift in a small Eu-class test). With
# c_dd = 0 the bug was invisible (no DDI to mis-rate).
#
# This test pins both branches: with the same n_steps, dt, and tol the
# ITP loop must converge to the same ψ regardless of `save_every`. It
# only matters when DDI is on; the c_dd = 0 control is included to
# distinguish the bug from generic numerical drift.

using SpinorBEC
using SpinorBEC: _run_itp_loop!
using Test

@testset "ITP Strang DDI rate (Bug-4 regression)" begin
    F = 1
    atom = AtomSpecies("test", 2.5e-25, F, 50e-10, 60e-10, 6.977e-23)
    n_steps = 800   # enough to see the drift, short enough to keep the test fast

    function build_ws(save_every::Int; c_dd_val::Float64)
        grid = make_grid(GridConfig((12, 12, 6), (8.0, 8.0, 4.0)))
        psi0 = init_psi(grid, SpinSystem(F); state=:m_plus_F)
        sp = SimParams(;
            dt=0.005,
            n_steps,
            imaginary_time=true,
            normalize_every=1,
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

    run_itp(ws) = _run_itp_loop!(
        ws, ws.sim_params.n_steps, 1.0e-13, nothing, nothing; verbose=false
    )

    @testset "DDI on: ψ independent of save_every" begin
        ws_a = build_ws(1; c_dd_val=2000.0)
        ws_b = build_ws(100; c_dd_val=2000.0)
        run_itp(ws_a)
        run_itp(ws_b)
        psi_a = ws_a.state.psi
        psi_b = ws_b.state.psi
        # Phase-align ψ_b to ψ_a (global phase freedom).
        ratio = sum(conj.(psi_a) .* psi_b) / sum(abs2, psi_a)
        psi_b_aligned = psi_b ./ (ratio / abs(ratio + 1e-30))
        max_dev = maximum(abs.(psi_a .- psi_b_aligned))
        @test max_dev < 1.0e-10                       # bytewise post-fix
        @test abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-10
    end

    @testset "DDI off: control passes" begin
        ws_a = build_ws(1; c_dd_val=0.0)
        ws_b = build_ws(100; c_dd_val=0.0)
        run_itp(ws_a)
        run_itp(ws_b)
        @test abs(total_energy(ws_a) - total_energy(ws_b)) < 1.0e-9
    end
end
