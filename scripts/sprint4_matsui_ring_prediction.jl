#!/usr/bin/env julia
# scripts/sprint4_matsui_ring_prediction.jl
#
# Direct test of the Sprint 4 Item A conclusion against the Matsui 2026
# Science EdH experiment. Item A determined all 5 c_n with σ_post: c_1
# (1.4e-4), tensor channels (8e-3 to 2e-2), c_0 (0.10) — well within the
# range where the m=-4 ring count (2 ferromagnetic / 3 antiferromagnetic)
# should be unambiguously predicted.
#
# Protocol (compact version of Matsui Phase 0+2):
#   1. ψ_init = m=-F stretched (Matsui prep at high Bz)
#   2. Quench Bz instantaneously to weak (p=0.3, ~2.6 nT scale)
#   3. Evolve under MDDI+contact for T_evolve = 10 ω_ref⁻¹ ≈ 14 ms
#      (Matsui used 40 ms = 28 ω_ref⁻¹; this is the headline-prediction
#       quick check, full-length run is next-session work)
#   4. Compute radial density profile n_{m=-4}(ρ) at z=0
#   5. Report ring count (local maxima in n(ρ))
#
# Three c_1 scenarios:
#   (FM)  c_1/c_0 ≈ 0           → ferromagnetic side, expect ~2 rings
#   (AFM) c_1/c_0 = 1/36 textbook → antiferromagnetic side, matches Matsui's
#                                   reported 3-ring m=-4
#   (AFM stronger) c_1/c_0 = 1/18  → stronger antiferromagnetic
#
# Run:   julia --project=. scripts/sprint4_matsui_ring_prediction.jl
# Expected wall-clock: ~ 15 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((16, 16, 12), (10.0, 10.0, 8.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN_QUENCH = ZeemanParams(0.3, 0.0)
const T_EVOLVE = 10.0
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# Scenarios. c_total is the same; c_1/c_0 differs.
const SCENARIOS = [
    ("FM (c_1/c_0=0)", 0.0),
    ("AFM textbook (c_1/c_0=1/36)", 1.0 / 36.0),
    ("AFM stronger (c_1/c_0=1/18)", 1.0 / 18.0),
]

function run_one(c1_ratio::Float64)
    c0 = C_TOTAL / (1 + F^2 * c1_ratio)
    c1 = c1_ratio * c0
    # Use nominal tensor channels (small naturalness values)
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => c0, 1 => c1,
            2 => 0.05 * c0, 4 => 0.02 * c0, 6 => 0.005 * c0)
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
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

"""Radial profile of |ψ_m|² in mid-z slice (z=0)."""
function radial_profile(ws, m_target::Int)
    psi = ws.state.psi
    F_loc = ws.atom.F
    c_idx = (F_loc - m_target) + 1   # codebase: c=1↔m=+F, c=D↔m=-F
    nx, ny, nz = ws.grid.config.n_points
    xs = ws.grid.x[1]
    ys = ws.grid.x[2]
    z_mid = (nz + 1) ÷ 2
    n_slice = abs2.(view(psi,:,:,z_mid,c_idx))
    # Radial bins
    box = ws.grid.config.box_size[1]
    rho_max = 0.5 * box
    n_bins = 16
    bin_w = rho_max / n_bins
    radial_n = zeros(Float64, n_bins)
    radial_w = zeros(Float64, n_bins)
    for j in 1:ny, i in 1:nx
        ρ = sqrt(xs[i]^2 + ys[j]^2)
        ρ < rho_max || continue
        b = Int(div(ρ, bin_w)) + 1
        b > n_bins && continue
        radial_n[b] += n_slice[i, j]
        radial_w[b] += 1.0
    end
    for b in 1:n_bins
        radial_w[b] > 0 && (radial_n[b] /= radial_w[b])
    end
    ρ_centers = [(b - 0.5) * bin_w for b in 1:n_bins]
    (ρ=ρ_centers, n=radial_n)
end

"""Count local maxima in radial profile (excluding boundary)."""
function count_rings(n::Vector{Float64}; threshold::Float64=1e-6)
    n_max = maximum(n)
    n_max < threshold && return 0
    count = 0
    for i in 2:(length(n) - 1)
        if n[i] > n[i - 1] && n[i] > n[i + 1] && n[i] > 0.1 * n_max
            count += 1
        end
    end
    count
end

function main()
    println("=== Matsui ring-formation prediction (Item A → experiment) ===")
    @printf "Atom: Eu151, N=%d, ω_ref=%.1f rad/s\n" N_ATOMS OMEGA_REF
    @printf "Grid 16×16×12, T_evolve=%.1f ω_ref⁻¹ = %.1f ms\n" T_EVOLVE (T_EVOLVE / OMEGA_REF * 1e3)
    println("Matsui Phase 2 quench at p=0.3 (~2.6 nT)")
    println()

    for (label, c1_ratio) in SCENARIOS
        println("Scenario: $label")
        print("  Running dynamics ... ")
        t0 = time()
        ws = run_one(c1_ratio)
        @printf "%.1f s\n" (time() - t0)

        dV = SpinorBEC.cell_volume(ws.grid)
        D = 2F + 1
        n_per_m = Float64[sum(abs2, view((ws.state.psi),:,:,:,c)) * dV
                          for c in 1:D]
        n_per_m_asc = reverse(n_per_m)

        # m=-4 radial profile
        prof = radial_profile(ws, -4)
        ring_count = count_rings(prof.n)

        @printf "  f[m=-6]=%.4f, f[m=-5]=%.4f, f[m=-4]=%.4f, f[m=-3]=%.4f\n" n_per_m_asc[1] n_per_m_asc[2] n_per_m_asc[3] n_per_m_asc[4]
        @printf "  m=-4 radial profile (z=0 slice):\n"
        for i in 1:length(prof.ρ)
            bar = "█"^max(0, round(Int, prof.n[i] / max(maximum(prof.n), 1e-30) * 30))
            @printf "    ρ=%.2f  n=%.3e  %s\n" prof.ρ[i] prof.n[i] bar
        end
        @printf "  → ring count (m=-4) = %d\n" ring_count
        println()
    end

    println("=== Done ===")
    println("Per Matsui paper: c_1≈0 → 2 rings (FM), c_1=(1/18)c_0 → 3 rings (AFM,")
    println("matches experiment). Our nominal c_1/c_0=1/36 is between; we report")
    println("ring counts so the trend matches expectation if Item A's predictions")
    println("hold at this T_evolve (full Matsui-length T=28 deferred to next session).")
end

main()
