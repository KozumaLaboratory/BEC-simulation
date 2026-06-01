#!/usr/bin/env julia
# scripts/sprint5_matsui_ring_extended.jl
#
# Extended Matsui ring-formation test — addresses the 3 deficits diagnosed
# at the end of yesterday's sprint4_matsui_ring_prediction.jl:
#   - T_evolve pushed from 10 ω_ref⁻¹ (14.5 ms) to 20 ω_ref⁻¹ (29 ms) —
#     closer to Matsui's 40 ms regime
#   - Grid pushed from 16×16×12 to 20×20×16 — finer radial resolution
#   - m-dependent K_3 loss added (calibrated K_3≈50 baseline) — Matsui's
#     40% loss in the weak-Bz hold reshapes the m=−4 distribution
#
# Two c_1 scenarios to test the FM↔AFM bifurcation:
#   FM   c_1/c_0 = 0     → expect 2 rings per Matsui
#   AFM  c_1/c_0 = 1/18  → expect 3 rings (matches Matsui's data)
#
# Run:   julia --project=. scripts/sprint5_matsui_ring_extended.jl
# Expected wall-clock: ~ 30 minutes per scenario on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((20, 20, 16), (10.0, 10.0, 8.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN_QUENCH = ZeemanParams(0.3, 0.0)
const T_EVOLVE = 20.0
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const SCENARIOS = [
    ("FM (c_1/c_0=0)", 0.0),
    ("AFM stronger (c_1/c_0=1/18)", 1.0 / 18.0),
]

# m-dependent K_3: stretched immune, cascade products enhanced.
# Calibration target: ~40% total loss at T=20 (Matsui scaled = 28%).
function k3_per_m_vector()
    k3 = zeros(Float64, 2F + 1)
    for c in 1:(2F + 1)
        m = F - (c - 1)
        if m == -F                # stretched component — Matsui sees survival here
            k3[c] = 5.0
        elseif m in (-F + 1, -F + 2, -F + 3)   # cascade products (m=-5, -4, -3)
            k3[c] = 80.0
        else
            k3[c] = 20.0
        end
    end
    k3
end

function run_one(c1_ratio::Float64)
    c0 = C_TOTAL / (1 + F^2 * c1_ratio)
    c1 = c1_ratio * c0
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => c0, 1 => c1,
            2 => 0.05 * c0, 4 => 0.02 * c0, 6 => 0.005 * c0)
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:m_minus_F)
    loss = LossParams(; K3_per_m_cubic=k3_per_m_vector())
    ws = make_workspace(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_QUENCH, potential=POT, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        loss=loss)
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    ws
end

function radial_profile(ws, m_target::Int)
    psi = ws.state.psi
    F_loc = ws.atom.F
    c_idx = (F_loc - m_target) + 1
    nx, ny, nz = ws.grid.config.n_points
    xs = ws.grid.x[1]
    ys = ws.grid.x[2]
    z_mid = (nz + 1) ÷ 2
    n_slice = abs2.(view(psi,:,:,z_mid,c_idx))
    box = ws.grid.config.box_size[1]
    rho_max = 0.5 * box
    n_bins = 24                              # finer bins than yesterday's 16
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

function count_rings(n::Vector{Float64}; rel_threshold::Float64=0.05)
    n_max = maximum(n)
    n_max < 1e-12 && return 0
    count = 0
    for i in 2:(length(n) - 1)
        if n[i] > n[i - 1] && n[i] > n[i + 1] && n[i] > rel_threshold * n_max
            count += 1
        end
    end
    count
end

function main()
    println("=== Sprint-5 Matsui ring (extended): T=$T_EVOLVE, 20³, K_3 m-dep ===")
    @printf "Grid 20×20×16, T=%.1f ω_ref⁻¹ = %.1f ms (Matsui 40 ms target)\n" T_EVOLVE (
        T_EVOLVE / OMEGA_REF * 1e3
    )
    println("K_3 m-dep: stretched m=-F=5, cascade m∈{-5,-4,-3}=80, other=20")
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
        total_norm = sum(n_per_m_asc)
        @printf "  total norm: %.4f (loss %.1f%%)\n" total_norm 100 * (1 - total_norm)
        @printf "  f[m=-6]=%.4f, f[m=-5]=%.4f, f[m=-4]=%.4f, f[m=-3]=%.4f\n" n_per_m_asc[1] n_per_m_asc[2] n_per_m_asc[3] n_per_m_asc[4]

        for m_obs in (-5, -4)
            prof = radial_profile(ws, m_obs)
            rings = count_rings(prof.n)
            n_max = maximum(prof.n)
            @printf "  m=%d radial profile (z=0 slice), n_max=%.3e, %d rings:\n" m_obs n_max rings
            n_max < 1e-12 && (println("    (empty)"); continue)
            for i in 1:length(prof.ρ)
                bar = "█"^max(0, round(Int, prof.n[i] / n_max * 30))
                @printf "    ρ=%.2f  n=%.2e  %s\n" prof.ρ[i] prof.n[i] bar
            end
        end
        println()
    end

    println("=== Done ===")
    println("Per Matsui: FM c_1=0 → 2 rings, AFM c_1=(1/18)c_0 → 3 rings.")
    println("If we now see 2 vs 3, the codebase reproduces the experiment qualitatively.")
end

main()
