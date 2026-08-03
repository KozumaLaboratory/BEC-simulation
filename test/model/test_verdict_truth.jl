using Test
using SpinorBEC
using JLD2
using SpinorBEC:
    MarkerVerdict, VerdictAudit, verify_verdict,
    _VERDICT_ENERGY_RTOL, _VERDICT_GRAD_RATIO

# The verdict must be true of the payload, not merely present beside it.
#
# `test_completion_marker.jl` + `test_marker_verdict.jl` + `test_marker_cutoff.jl`
# are 168 assertions about the marker's shape, round-trip, ordering and internal
# consistency. Every one of them stays green if the solver's `converged` is
# forced to `true`, because none of them opens the payload. This file is the arm
# that does.
#
# The failure it gates is on record here: `solvers/lbfgs/atomic.jl:418` — on
# 2026-06-05, 13 of 22 M1 cells carried a disk `grad_norm` that a fresh
# re-evaluation at the ψ stored beside it did not reproduce.

# `c0`, NOT `c1`, is the knob that perturbs this fixture's Hamiltonian.
# Measured: the polar ground state has ⟨F⟩ = 0, so the c1 term contributes
# nothing to its energy and moving c1 from -0.3 to +0.9 left the energy
# reproducing to 1e-16 — the canary passed against the defect it was written
# for. The density term is nonzero for any state, so c0 moves it. The
# "fixture actually moves" assertion below is what keeps this from silently
# regressing to a degenerate knob again.
function probe_ws(; c0=5.0, n=(8, 8, 8))
    grid = make_grid(GridConfig{3}(n, (6.0, 6.0, 6.0)))
    atom = resolve_atom(:Rb87)
    make_workspace(; grid, atom,
        interactions=InteractionParams(Dict(0 => c0, 1 => -0.3)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1))
end

# The honest spine: solve, then take E and ‖∇E‖ from the solver itself rather
# than from a hand-computed value, so the fixture cannot be right by
# construction in a way the production path is not.
function solved_state(ws)
    r = find_ground_state(; grid=ws.grid, atom=ws.atom,
        interactions=InteractionParams(Dict(0 => 5.0, 1 => -0.3)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        dt=1.0e-3, n_steps=300, tol=1.0e-10, initial_state=:polar, verbose=false)
    psi = Array(r.workspace.state.psi)
    (psi, Float64(r.energy))
end

@testset "verdict truth" begin
    ws = probe_ws()
    psi, E = solved_state(ws)

    @testset "a truthful verdict reproduces" begin
        v = MarkerVerdict(true, "tol", false, NaN)
        a = verify_verdict(v, psi, ws; energy_recorded=E, F=ws.atom.F)
        @test a.checked
        @test a.agrees
        @test isapprox(a.energy_rederived, E; rtol=_VERDICT_ENERGY_RTOL)
        @test isfinite(a.grad_norm_rederived)
    end

    @testset "the perturbation used by the canary actually moves the energy" begin
        # A canary against a knob the observable is degenerate in is not a
        # canary. Assert the perturbation is visible BEFORE trusting the arms
        # that depend on it — otherwise those arms pass for the wrong reason,
        # which is exactly what happened with `c1` on this polar state.
        a_ref = verify_verdict(MarkerVerdict(true, "tol", false, NaN),
            psi, ws; energy_recorded=E, F=ws.atom.F)
        a_pert = verify_verdict(MarkerVerdict(true, "tol", false, NaN),
            psi, probe_ws(; c0=25.0); energy_recorded=E, F=ws.atom.F)
        rel = abs(a_pert.energy_rederived - a_ref.energy_rederived) / abs(a_ref.energy_rederived)
        @test rel > 1.0e-3      # visible, by four orders over the 1e-10 gate
    end

    # ---- THE CANARY, as a first-class arm -----------------------------------
    # Not a manual experiment run once and described in a comment: the whole
    # claim of this file is that it can go red, so the red case is asserted.
    @testset "canary: a lying verdict is caught" begin
        # (a) the #236 shape — the workspace states a different Hamiltonian from
        #     the one that wrote the payload. Here: a different c0. The energy
        #     will not reproduce.
        ws_other = probe_ws(; c0=25.0)
        a = verify_verdict(MarkerVerdict(true, "tol", false, NaN),
            psi, ws_other; energy_recorded=E, F=ws.atom.F)
        @test a.checked
        @test !a.agrees
        @test occursin("different Hamiltonian", a.reason)

        # (b) the 2026-06-05 shape — the verdict describes a different state.
        #     A converged claim with a residual six orders off what the stored ψ
        #     actually has.
        a2 = verify_verdict(MarkerVerdict(true, "tol", false, 1.0e-14),
            psi, ws; energy_recorded=E, F=ws.atom.F)
        @test a2.checked
        @test !a2.agrees
        @test occursin("different state", a2.reason)

        # (c) an energy that is merely WRONG, by less than the #236 defect's
        #     0.64 %. The gate is at 1e-10 relative, so a 1e-6 error must fail —
        #     otherwise the tolerance is decorative.
        a3 = verify_verdict(MarkerVerdict(true, "tol", false, NaN),
            psi, ws; energy_recorded=E * (1 + 1.0e-6), F=ws.atom.F)
        @test !a3.agrees
    end

    @testset "absent is absent, not a pass" begin
        a = verify_verdict(nothing, psi, ws; energy_recorded=E, F=ws.atom.F)
        @test !a.checked
        @test !a.agrees          # `checked=false` must never read as agreement
        @test occursin("no verdict", a.reason)

        a2 = verify_verdict(MarkerVerdict(true, "tol", false, NaN),
            psi, ws; energy_recorded=NaN, F=ws.atom.F)
        @test !a2.checked
        @test !a2.agrees
    end

    @testset "a NaN residual is normal, not a disagreement" begin
        # The ITP reports no gradient. The energy arm must still run — that is
        # the arm that catches a wrong Hamiltonian, and ITP payloads are the
        # majority of the store.
        a = verify_verdict(MarkerVerdict(true, "unknown", false, NaN),
            psi, ws; energy_recorded=E, F=ws.atom.F)
        @test a.agrees
        @test isnan(a.grad_norm_recorded)
        # …and it does NOT become a free pass: a wrong energy with a NaN
        # residual still fails.
        b = verify_verdict(MarkerVerdict(true, "unknown", false, NaN),
            psi, probe_ws(; c0=25.0); energy_recorded=E, F=ws.atom.F)
        @test !b.agrees
    end

    @testset "tolerances are derived, and stated" begin
        # Pinned so that widening one is a deliberate edit with a diff, not a
        # drift. The derivations are in `src/model/verdict_truth.jl`; if these
        # move, that argument has to move with them.
        @test _VERDICT_ENERGY_RTOL == 1.0e-10
        @test _VERDICT_GRAD_RATIO == 100.0
        # The energy gate must be far tighter than the smallest real defect it
        # is meant to catch. #236 moved the energy 0.64 %.
        @test _VERDICT_ENERGY_RTOL < 0.0064 / 1000
    end
end
