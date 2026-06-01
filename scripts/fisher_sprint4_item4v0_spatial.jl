#!/usr/bin/env julia
# scripts/fisher_sprint4_item4v0_spatial.jl
#
# Sprint-4 item 4 v0 (spatial-observable, Matsui-regime). Heuristic gate for
# moving from cumulative-rank-2 static linear Fisher (Sprint 3 stretched +
# item 1 v2 polar) into the non-linear cascade regime where Matsui et al.
# read c_1 / c_0 from m=−4 ring morphology.
#
# Anko correction 2026-06-01 to the original v0 (which used scalar f_m
# populations at 1.76% depolarisation and would have category-errored a
# rank-1 result as "need beyond-GP / TWA / TDHFB"):
#   - SPATIAL observables ⟨ρ⟩_m, ⟨ρ²⟩_m on the depolarised cascade
#     components m=−F+1, m=−F+2 (NOT scalar populations alone)
#   - Realistic depolarisation 20-30% (Matsui paper's regime), not the
#     1.76% linear regime where ∂(ring)/∂c_1 ∝ depolarisation vanishes
#   - GP + MDDI + secular_ddi=false (no beyond-mean-field needed; Matsui
#     reproduced the ring-count effect in GP)
#   - Local linear Fisher at this regime is HEURISTIC ("does c_1 lift?"),
#     not a precision quantification — the FD perturbation 0.1% in c is
#     small enough for Fisher to be mathematically valid, but tens-of-%
#     depolarisation means extrapolation in c is unreliable
#
# Decision tree:
#   rank > 1 with c_1 in MEAS basis ⇒ SBI-on-GP justified, scope full
#     Sprint 4 SBI budget for long-T cascade
#   rank = 1 with all Jacobian rows non-trivial ⇒ observables are
#     sensitive but linearly dependent at this T; try different T or
#     additional moments before reaching for beyond-GP
#   rank = 1 with Jacobian rows trivial ⇒ wrong T, wrong observables,
#     wrong regime — fix the probe before any larger commitment
#
# Run:   julia --project=. scripts/fisher_sprint4_item4v0_spatial.jl
# Expected wall-clock: ~ 10 minutes on a single CPU core.

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
const T_EVOLVE = 4.0           # push to Matsui regime (~20-30% depolarised)
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

# Cascade components of interest for spatial probing: m=−F+1 (first daughter)
# and m=−F+2 (second daughter, where second-order cascade products live and
# where c_1 spatial-structure dependence is expected to lift per Matsui).
const CASCADE_M_INDICES = [(F - 1) + F + 1, (F - 2) + F + 1]   # ascending-m idx

function forward_cascade(c::AbstractVector{<:Real})
    length(c) == 5 || error("expected 5 params")
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
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

"""Spatial moments per m: f_m, ⟨ρ⟩_m, ⟨ρ²⟩_m for m=-F..+F (ascending).

Length 3·(2F+1). For uninhabited m (n ≈ 0) the spatial moments are set to 0
so the FD numerator stays well-defined (zero gradient there is informative —
absence of cascade population is itself a c-dependent signal in nearby m).
"""
function summary_spatial(ws)
    psi = ws.state.psi
    F_loc = ws.atom.F
    grid = ws.grid
    dV = SpinorBEC.cell_volume(grid)
    nx, ny, nz = grid.config.n_points
    xs = grid.x[1]
    ys = grid.x[2]

    # Precompute ρ(i,j) = √(x_i² + y_j²)
    rho = [sqrt(xs[i]^2 + ys[j]^2) for i in 1:nx, j in 1:ny]
    rho_sq = rho .^ 2

    n_per_m = Float64[]
    r_per_m = Float64[]
    rsq_per_m = Float64[]

    @inbounds for c in 1:(2F_loc + 1)
        psi_c = view(psi,:,:,:,c)
        N_m = 0.0
        rsum = 0.0
        rsqsum = 0.0
        for k in 1:nz, j in 1:ny, i in 1:nx
            w = abs2(psi_c[i, j, k])
            N_m += w
            rsum += rho[i, j] * w
            rsqsum += rho_sq[i, j] * w
        end
        N_m *= dV
        push!(n_per_m, N_m)
        if N_m > 1e-12
            push!(r_per_m, rsum * dV / N_m)
            push!(rsq_per_m, rsqsum * dV / N_m)
        else
            push!(r_per_m, 0.0)
            push!(rsq_per_m, 0.0)
        end
    end

    # Reverse to ascending m order
    n_asc = reverse(n_per_m)
    r_asc = reverse(r_per_m)
    rsq_asc = reverse(rsq_per_m)
    n_asc ./= sum(n_asc)
    [n_asc; r_asc; rsq_asc]
end

function main()
    println("=== Sprint-4 item 4 v0 (spatial): heuristic gate for SBI commitment ===")
    @printf "Evolution T = %.2f ω_ref⁻¹ (%.2f ms), targeting 20-30%% depolarisation\n" T_EVOLVE (
        T_EVOLVE / OMEGA_REF * 1e3
    )
    println("Observables: f_m, ⟨ρ⟩_m, ⟨ρ²⟩_m for m = -F..+F (length 3·(2F+1) = 39).")
    println("Spatial moments on cascade components m=−F+1, m=−F+2 are the c_1 probe;")
    println("Matsui's m=−4 ring-count discrimination was reproduced in GP, not TWA.")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 run) ... ")
    t0 = time()
    ws0 = forward_cascade(c_nominal)
    y0 = summary_spatial(ws0)
    nominal_time = time() - t0
    @printf "%.1f s\n" nominal_time

    # Sanity: populations are y[1:13], radial moments y[14:26] and y[27:39]
    n_asc = y0[1:(2F + 1)]
    r_asc = y0[(2F + 2):(2 * (2F + 1) + 1)]

    println()
    println("Cascade signature (top components by population):")
    for m in (-F):F
        idx = m + F + 1
        if n_asc[idx] > 1e-4
            @printf "  m=%+d : f=%.4f  ⟨ρ⟩=%.3f  ⟨ρ²⟩=%.3f\n" m n_asc[idx] r_asc[idx] y0[2 * (2F + 1) + idx]
        end
    end
    println()

    depolarisation = 1.0 - n_asc[1]   # m=-F is index 1 in ascending
    @printf "Depolarisation amplitude = %.3f  (target 0.20-0.30; <0.05 too linear, >0.5 saturated)\n" depolarisation
    println()

    @printf "Fisher FD ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_cascade, c_nominal, summary_spatial;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    # Diagnostic: print which observable rows actually moved
    println("Observable sensitivities (max |∂y_i/∂c| across c-params):")
    obs_labels = vcat(
        [("f[m=$m]", m + F + 1) for m in (-F):F],
        [("ρ[m=$m]", m + F + 1 + (2F + 1)) for m in (-F):F],
        [("ρ²[m=$m]", m + F + 1 + 2 * (2F + 1)) for m in (-F):F],
    )
    for (label, row) in obs_labels
        sig = maximum(abs, view(J, row, :))
        sig > 1e-8 && @printf "  %s  max|∂/∂c| = %.3e\n" label sig
    end
    println()

    # Noise model: per-population 1e-3, per-radial-moment 0.05 (5% of trap size)
    sigma_y = vcat(fill(1e-3, 2F + 1), fill(0.05, 2F + 1), fill(0.1, 2F + 1))
    fish = fisher_information(J, sigma_y)
    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        @printf "  λ_%d = %.4e\n" i v
    end
    println()

    ident = identifiable_directions(fish; cutoff_ratio=1e-4, param_names=PARAM_NAMES)
    println(ident.summary)
    println()
    println("Direction breakdown:")
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
    println("--- Heuristic gate ---")
    println("This Fisher is a *qualitative* indicator of whether c_1 sensitivity")
    println("lifts beyond the stretched-EdH theorem (rank=1 at first order) when")
    println("spatial observables enter at finite depolarisation. The σ_post values")
    println("at tens-of-percent cascade are not reliable for precision; extrapolation")
    println("of FD-linearised c shifts breaks down. Use only to decide whether to")
    println("commit Sprint-4 full SBI budget.")
    println()
    if ident.measurable_count > 1
        println("→ rank > 1: c-information beyond g_{2F} = a_12 is present in this")
        println("  regime via spatial observables. SBI-on-GP justified. Scope full")
        println("  Sprint-4 SBI for long-T cascade against the NEW directions above.")
    else
        println("→ rank = 1: spatial observables alone at this T do not lift c-rank")
        println("  beyond stretched theorem. Before reaching for beyond-GP, check:")
        println("  (1) Observable sensitivities above — did ρ/ρ² actually move?")
        println("      If NOT, the spatial probe didn't engage; try different T or")
        println("      finer moments (multi-r sampling of |ψ_m(ρ)|²).")
        println("  (2) Is depolarisation in the 20-30%% window? If not, retune T.")
        println("  (3) Bogoliubov / collective-mode probe for tensor channels —")
        println("      that is item 1', NOT TWA/TDHFB (category error).")
    end
    println()
    println("=== Sprint-4 item 4 v0 spatial complete ===")
end

main()
