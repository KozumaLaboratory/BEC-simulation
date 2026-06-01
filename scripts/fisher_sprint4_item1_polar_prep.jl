#!/usr/bin/env julia
# scripts/fisher_sprint4_item1_polar_prep.jl
#
# Sprint-4 item 1: linear-Fisher with m=0 polar initial state instead of the
# stretched m=±F of items 0 / Sprint 3. Companion to the stretched-EdH
# measurability theorem (sprint3_static_gate_baseline_2026_06_01.md):
# polar pair (m=0, m=0) has M=0, which by Bose-symmetry reaches ALL even-S
# channels (S = 0, 2, 4, 6, 8, 10, 12) — including singlet S=0 which is
# unreachable from stretched. So c_1, c_2, c_4, c_6 are *physically allowed*
# to couple at first order, and the linear Fisher rank can exceed 1.
#
# Two outputs from a single run:
#   (a) FEASIBILITY: does polar survive the evolution? Polar is unstable to
#       symmetric spin-mixing m=0 + m=0 → m=+1 + m=−1 driven by c_1 contact
#       interaction at rate ~ c_1 · n. We report f[m=0](T) so the operator
#       can judge whether the protocol is sterile (rapid collapse) before
#       trusting the Fisher numbers.
#   (b) FISHER: same 5-param FD as item 0 around Matsui nominal, on the
#       depolarised populations f_m(T). Expected: rank > 1 if polar holds
#       long enough; rank = 1 (collapsed back to g_{2F}) if polar collapsed
#       very early.
#
# Run:   julia --project=. scripts/fisher_sprint4_item1_polar_prep.jl
# Expected wall-clock: ~ 2 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((12, 12, 12), (10.0, 10.0, 10.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN_QUENCH = ZeemanParams(0.3, 0.0)
const T_EVOLVE = 0.5
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]

function forward_polar_prep(c::AbstractVector{<:Real})
    length(c) == 5 || error("expected 5 params (c_0, c_1, c_2, c_4, c_6)")
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:polar)
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_QUENCH, potential=POT, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false)
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    ws
end

"""f_m ordered m = -F..+F (length 2F+1). psi[..., c=1]=m=+F per CLAUDE.md."""
function summary_populations(ws)
    psi = ws.state.psi
    F_loc = ws.atom.F
    dV = SpinorBEC.cell_volume(ws.grid)
    n_by_c = Float64[sum(abs2, view(psi,:,:,:,c)) * dV
                     for c in 1:(2F_loc + 1)]
    n_asc = reverse(n_by_c)
    n_asc ./ sum(n_asc)
end

function main()
    println("=== Sprint-4 item 1: polar (m=0) prep + linear Fisher ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS, ω_ref=$OMEGA_REF rad/s")
    println("Grid: 12³ harmonic trap, λ_z = 1.182")
    println("Quench Zeeman: p=$(ZEEMAN_QUENCH.p) (~2.6 nT)")
    @printf "c_dd (dimless) = %.4g\n" C_DD_DIMLESS
    @printf "Evolution: T=%.2f ω_ref⁻¹ = %.2f ms, dt=%.4f, N_steps=%d\n" T_EVOLVE (
        T_EVOLVE / OMEGA_REF * 1e3
    ) DT N_STEPS
    println("Initial state: m=0 polar (all atoms in c=F+1 component)")
    println("Pair M=0 from polar reaches ALL even-S channels (S=0,2,4,6,8,10,12),")
    println("including singlet S=0 (c_0/c_1 alone) that stretched cannot reach.")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 run) ... ")
    t0 = time()
    ws0 = forward_polar_prep(c_nominal)
    y0 = summary_populations(ws0)
    nominal_time = time() - t0
    @printf "%.1f s\n" nominal_time

    println()
    println("Nominal post-evolution populations:")
    for m in (-F):F
        idx = m + F + 1
        bar = "█"^max(0, round(Int, y0[idx] * 40))
        @printf "  f[m=%+d] = %.4e  %s\n" m y0[idx] bar
    end
    println()

    # FEASIBILITY DIAGNOSTIC — operator readable
    polar_fraction = y0[F + 1]       # m=0 sits at idx F+1 in ascending order
    pm_one = y0[F] + y0[F + 2]        # m=±1 (spin-mixing daughters)
    pm_two = y0[F - 1] + y0[F + 3]    # m=±2 (second-step cascade)
    println("--- Feasibility diagnostic (polar survival) ---")
    @printf "  f[m=0]  = %.4f                 (was 1.0 at t=0)\n" polar_fraction
    @printf "  f[m=±1] = %.4f  (spin-mixing daughters)\n" pm_one
    @printf "  f[m=±2] = %.4f  (second-step cascade)\n" pm_two
    @printf "  m≠0 leak = %.4f\n" (1.0 - polar_fraction)

    feasibility_verdict = if polar_fraction < 0.05
        "STERILE — polar collapsed; Fisher numbers below describe a transient mix"
    elseif polar_fraction < 0.5
        "MARGINAL — polar lost majority population; treat Fisher as upper bound"
    elseif polar_fraction < 0.95
        "OK — polar in linear-departure regime; Fisher is meaningful"
    else
        "DORMANT — polar barely depolarised; try longer T_EVOLVE for c sensitivity"
    end
    println("  Verdict: $feasibility_verdict")
    println()

    @printf "Fisher FD will need 10 more runs, ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_polar_prep, c_nominal, summary_populations;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    sigma_y = fill(1e-3, length(y0))
    fish = fisher_information(J, sigma_y)
    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        @printf "  λ_%d = %.4e\n" i v
    end
    println()

    ident = identifiable_directions(fish; cutoff_ratio=1e-4, param_names=PARAM_NAMES)
    println(ident.summary)
    println()
    println("Direction breakdown (eigenvectors in c-basis):")
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        σstr =
            isfinite(ident.posterior_sigma[i]) ?
            @sprintf("%.3e", ident.posterior_sigma[i]) : "Inf"
        @printf "  Dir %d [%s] σ_post=%s :  %s\n" i tag σstr join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    println("--- Interpretation ---")
    println("From polar M=0 pair, all even-S channels are reachable at first order.")
    println("rank > 1 means item 1 already breaks ≥ 1 null beyond a_12 prior.")
    println("rank = 1 means polar collapsed too quickly to register c_2,4,6")
    println("  signals; feasibility verdict above tells which.")
    println("Compare MEAS directions against the stretched g_{2F} = (0.028, 1, 0, 0, 0)")
    println("(item 0 single MEAS): any orthogonal MEAS direction is genuinely NEW info.")
    println()
    println("=== Sprint-4 item 1 complete ===")
end

main()
