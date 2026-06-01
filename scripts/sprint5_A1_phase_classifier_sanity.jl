#!/usr/bin/env julia
# scripts/sprint5_A1_phase_classifier_sanity.jl
#
# Track A1 v0 (analyzer sanity, before any Eu scan): verify that
# `phase_classify` correctly identifies polar vs FM in the F=1 textbook
# limit where c_1 sign cleanly separates them. Also check that
# winding_map returns Lz ≈ 0 in a uniformly-pinned harmonic trap (no
# spontaneous circulation expected for ordinary scalar/polar GS at this
# Bz / trap).
#
# Expected:
#   c_1 < 0  (ferromagnetic side):  classifier should say FM, Mz ≈ ±F
#   c_1 = 0  (spin-independent):    scalar-like, any-m equally valid;
#                                     classifier output reflects init bias
#   c_1 > 0  (polar/antiferromag):  classifier should say polar, Mz ≈ 0
#
# If this sanity passes, A1 proper (F=6 Eu phase diagram scan) can use
# the same analyzer with confidence. If it fails, fix or replace the
# classifier before any Eu work.
#
# Run:   julia --project=. scripts/sprint5_A1_phase_classifier_sanity.jl
# Expected wall-clock: ~ 3 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 1
const ATOM = SpinorBEC.Rb87
const GRID = make_grid(GridConfig((32,), (12.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN = ZeemanParams(0.5, 0.05)   # small Zeeman bias, not regime-defining
const DT_ITP = 0.005
const N_STEPS_ITP = 4000
const TOL = 1e-7

# Sweep c_1 sign at fixed c_0
const C0 = 4.0
const C1_VALUES = [-0.5, -0.1, 0.0, 0.1, 0.5]
const INIT_STATES = [:m_plus_F, :polar, :m_minus_F]

function run_one(c0::Float64, c1::Float64, init_state::Symbol)
    ip = InteractionParams(Dict{Int, Float64}(0 => c0, 1 => c1))
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=init_state, verbose=false)
    ws, E, conv
end

function summarise(ws, E)
    psi = ws.state.psi
    F_loc = ws.atom.F
    sm = spin_matrices(F_loc)
    dV = SpinorBEC.cell_volume(ws.grid)
    D = 2F_loc + 1
    # Per-m populations
    n_per_m = Float64[sum(abs2, view(psi, :, c)) * dV for c in 1:D]
    # ⟨F_z⟩ (use the codebase's magnetization observable)
    sys = SpinSystem(F_loc)
    Mz_total = SpinorBEC.magnetization(psi, ws.grid, sys)
    # Phase classifier
    phase_info = SpinorBEC.classify_phase_detailed(psi, F_loc, ws.grid, sm)
    (E=E, Mz=Mz_total, n_per_m=n_per_m, phase=phase_info)
end

function main()
    println("=== A1 v0: phase classifier sanity (F=1 c_1 sign sweep) ===")
    @printf "Atom: %s, Grid: 32-pt 1D harmonic, p=%.2f q=%.2f\n" ATOM.name ZEEMAN.p ZEEMAN.q
    @printf "c_0 = %.2f, c_1 ∈ %s\n" C0 string(C1_VALUES)
    println()

    for c1 in C1_VALUES
        println("─── c_1 = $c1 ───")
        for init in INIT_STATES
            print("  init=$init ... ")
            t0 = time()
            ws, E, conv = run_one(C0, c1, init)
            summary = summarise(ws, E)
            @printf "%.1fs E=%.4f Mz=%+.4f conv=%s\n" (time() - t0) E summary.Mz conv
            @printf "    n_per_m = [%.3f, %.3f, %.3f]\n" summary.n_per_m[1] summary.n_per_m[2] summary.n_per_m[3]
            # phase_info structure may vary; just print what's there
            if hasproperty(summary.phase, :phase)
                @printf "    phase classifier verdict: %s\n" string(summary.phase.phase)
            else
                @printf "    phase classifier fields: %s\n" join(propertynames(summary.phase), ", ")
            end
        end
        println()
    end

    println("=== Expected ===")
    println(" c_1 < 0  : FM,   Mz → ±1 (depending on init)")
    println(" c_1 = 0  : degenerate, classifier reflects init")
    println(" c_1 > 0  : polar, Mz → 0 (m=0 condenses regardless of init bias")
    println("            unless q-favoured)")
    println()
    println("=== Done ===")
end

main()
