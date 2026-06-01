#!/usr/bin/env julia
# scripts/sprint5_A1_eu_nominal_phase.jl
#
# Track A1 v1 — first concrete Eu phase identification. At the nominal
# (a_S, B, trap, N) point chosen yesterday (Matsui-textbook truncation
# c_1/c_0 = 1/36), run ITP from multiple initial states across the
# state_zoo, pick the lowest-E solution, and report the classifier
# verdict.
#
# This is the first datum of the Eu phase map: which phase does the
# nominal point belong to? The phase BOUNDARY structure is the full A1
# scan (next session); this is the central point identification with
# multi-start as captured in v0 sanity.
#
# Run:   julia --project=. scripts/sprint5_A1_eu_nominal_phase.jl
# Expected wall-clock: ~ 10 minutes on a single CPU core (7 ITPs × ~1.5
# min each on 1D 24-pt; will scale to 3D 16³ at ~ 50 min for the proper
# scan next session).

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN = ZeemanParams(0.05, 0.0)  # very small Bz so phase competition is contact-driven
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0

# State zoo entries to try as inits. Cover the candidate phases.
const INITS = [:m_plus_F, :m_minus_F, :polar, :uniform,
    :antiferromagnetic, :cyclic, :biaxial_nematic]

function run_one(init_state::Symbol)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    try
        ws, conv, E, dE, last = find_ground_state(;
            grid=GRID, atom=ATOM, interactions=ip,
            zeeman=ZEEMAN, potential=POT,
            dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
            initial_state=init_state, verbose=false)
        ws, E, conv
    catch err
        @warn "init=$init_state failed" err
        nothing, NaN, false
    end
end

function summarise_ws(ws, E)
    psi = ws.state.psi
    F_loc = ws.atom.F
    sm = spin_matrices(F_loc)
    dV = SpinorBEC.cell_volume(ws.grid)
    D = 2F_loc + 1
    sys = SpinSystem(F_loc)
    n_per_m = Float64[sum(abs2, view(psi, :, c)) * dV for c in 1:D]
    Mz = SpinorBEC.magnetization(psi, ws.grid, sys)
    phase = SpinorBEC.classify_phase_detailed(psi, F_loc, ws.grid, sm)
    (E=E, Mz=Mz, n_per_m=n_per_m, phase=phase)
end

function main()
    println("=== A1 v1: Eu nominal phase identification ===")
    @printf "Atom: %s, N=%d, ω_ref=%.1f rad/s\n" ATOM.name N_ATOMS OMEGA_REF
    @printf "Trap: 1D 24-pt harmonic. Zeeman p=%.2f, q=%.2f\n" ZEEMAN.p ZEEMAN.q
    @printf "c = (%.2e, %.2e, %.2e, %.2e, %.2e) for n=(0,1,2,4,6)\n" C0 C1 C2 C4 C6
    println()

    results = Vector{Any}()
    for init in INITS
        print("  init=$init ... ")
        t0 = time()
        ws, E, conv = run_one(init)
        if ws === nothing
            @printf "%.1fs FAILED\n" (time() - t0)
            push!(results, (init=init, E=NaN, ws=nothing, conv=false))
            continue
        end
        summary = summarise_ws(ws, E)
        @printf "%.1fs E=%.5f Mz=%+.4f conv=%s phase=%s\n" (time() - t0) E summary.Mz conv string(summary.phase.phase)
        push!(results, (init=init, E=E, ws=ws, conv=conv, summary=summary))
    end
    println()

    # Pick lowest-E among converged
    valid = filter(r -> r.conv && isfinite(r.E), results)
    if isempty(valid)
        println("All inits failed to converge — investigate.")
        return
    end
    sorted_valid = sort(valid; by=r -> r.E)
    winner = sorted_valid[1]
    println("=== Lowest-E result ===")
    @printf "Winner init: %s, E = %.5f, ΔE to runner-up = %+.3e\n" winner.init winner.E (length(sorted_valid) > 1 ? sorted_valid[2].E - winner.E : NaN)
    sw = winner.summary
    @printf "Mz = %+.4f\n" sw.Mz
    @printf "n_per_m = %s\n" string(round.(sw.n_per_m, digits=4))
    @printf "Phase classifier verdict: %s\n" string(sw.phase.phase)
    if hasproperty(sw.phase, :details)
        @printf "Details: %s\n" string(sw.phase.details)
    end
    println()

    # Energy ranking (degeneracy check)
    println("Energy ranking (init → E):")
    for r in sorted_valid
        @printf "  %-25s E=%+.5f  (ΔE=%+.3e)\n" string(r.init) r.E (r.E - winner.E)
    end
    println()
    if length(sorted_valid) >= 2 && (sorted_valid[2].E - winner.E) < 1e-4
        println("WARNING: top two inits within 1e-4 in E — near-degenerate phases at this point.")
        println("This is exactly the regime where Track B (LHY/TDHFB) becomes load-bearing.")
    end

    println()
    println("=== Done ===")
end

main()
