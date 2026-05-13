# B-2 extended: full 4 × 3 = 12 entry order ladder matrix.
#
# Schemes (TDHFB side):
#   1. Strang plain        — base, picard_midpoint=false.   Predict order 2.
#   2. Strang picard       — base, picard_midpoint=true.    Predict order 2 (Picard
#                            kills palindrome residual but doesn't lift base order).
#   3. Y4 plain            — Y4 composition over plain Strang. Predict regime-
#                            dependent: ~4 at vacuum (degeneracy), ~3.4 elsewhere.
#   4. Y4 picard (A4 fix)  — Y4 over Picard Strang. Predict order 4 across regimes.
#
# Regimes (same as B-1):
#   (1) vacuum         — ρ=0, κ=0. Leading O(dt²) palindrome coefficient
#                        vanishes; falsifier for the degeneracy hypothesis.
#   (2) pre-evolved    — vacuum + 20 plain Strang steps at dt=0.002. The
#                        production-relevant state.
#   (3) random Hermitian — generic non-trivial (ρ, κ).
#
# Each regime gets its OWN reference (Y4-mid at dt=0.0005). Cost ~30 min CPU.
#
# Run: julia --project=. scripts/diagnostic/order_ladder_full_matrix.jl

using SpinorBEC
using Printf
using LinearAlgebra
using Random

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
const T_FINAL = 0.2
const DT_REF = 0.0005

function _initial_state_anti_polar()
    phi = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2)) + 0im
        phi[i, j, k, 1] = g / sqrt(2)
        phi[i, j, k, 3] = g / sqrt(2)
    end
    phi ./= sqrt(sum(abs2, phi))
    init_tdhfb_vacuum(phi)
end

function _harmonic_trap()
    V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    dx = BOX / N_SPATIAL
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        v = 0.5 * (((i - center) * dx)^2 + ((j - center) * dx)^2
                   + 1.4^2 * ((k - center) * dx)^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    return V_ext
end

function _state_pre_evolved(state0, V_ext, g_S; n_steps=20, dt=0.002)
    s = deepcopy(state0)
    for _ in 1:n_steps
        tdhfb_strang_step!(s, F, g_S, V_ext, dt)
    end
    return s
end

function _state_random(seed::Int)
    rng = MersenneTwister(seed)
    phi = randn(rng, ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D) * 0.1
    rho = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D, D)
    kappa = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D, D)
    for I in CartesianIndices((N_SPATIAL, N_SPATIAL, N_SPATIAL))
        A = randn(rng, ComplexF64, D, D) * 0.05
        rho_loc = 0.5 * (A + adjoint(A))
        for c in 1:D
            rho_loc[c, c] += 0.05
        end
        B = randn(rng, ComplexF64, D, D) * 0.05
        kappa_loc = 0.5 * (B + transpose(B))
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
            kappa[I, c, cp] = kappa_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0
    )
end

function _run(scheme::Symbol, picard_midpoint::Bool, dt::Float64,
    state0, g_S, V_ext)
    n_steps = round(Int, T_FINAL / dt)
    state = deepcopy(state0)
    if scheme === :strang
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
            scheme=:strang)
        # NOTE: scheme=:strang in tdhfb_evolve! doesn't forward picard_midpoint;
        # use direct tdhfb_strang_step! loop for picard=true variant.
    elseif scheme === :strang_pm
        for _ in 1:n_steps
            tdhfb_strang_step!(state, F, g_S, V_ext, dt;
                picard_midpoint=true, picard_tol=1e-14, picard_max_iter=100)
        end
    else  # :y4_midpoint
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
            scheme=:y4_midpoint,
            picard_midpoint=picard_midpoint,
            picard_midpoint_tol=1e-14,
            picard_midpoint_max_iter=100,
        )
    end
    return state
end

function _state_err(state, state_ref)
    phi_e = maximum(abs.(state.phi .- state_ref.phi))
    rho_e = maximum(abs.(state.rho .- state_ref.rho))
    kappa_e = maximum(abs.(state.kappa .- state_ref.kappa))
    (phi=phi_e, rho=rho_e, kappa=kappa_e, total=max(phi_e, rho_e, kappa_e))
end

function _fit_slope(log_dts, log_err)
    n = length(log_dts)
    mean_x = sum(log_dts) / n;
    mean_y = sum(log_err) / n
    sum((log_dts[i] - mean_x) * (log_err[i] - mean_y) for i in 1:n) /
    sum((log_dts[i] - mean_x)^2 for i in 1:n)
end

function _ladder_scheme(label, scheme, picard_midpoint, dts, state0, state_ref, g_S, V_ext)
    @printf("  %-20s  dt-table:\n", label)
    @printf("    %-10s  %-13s  %-13s  %-13s  %-8s\n",
        "dt", "φ err", "ρ err", "κ err", "wall(s)")
    results = NamedTuple[]
    for dt in dts
        t0 = time()
        state = _run(scheme, picard_midpoint, dt, state0, g_S, V_ext)
        wall = time() - t0
        err = _state_err(state, state_ref)
        @printf("    %-10.5f  %-13.4e  %-13.4e  %-13.4e  %-8.1f\n",
            dt, err.phi, err.rho, err.kappa, wall)
        push!(results, (dt=dt, err..., wall=wall))
    end
    log_dts = log.([r.dt for r in results])
    log_phi = log.([r.phi for r in results])
    log_rho = log.([r.rho for r in results])
    log_kappa = log.([r.kappa for r in results])
    slope_phi = _fit_slope(log_dts, log_phi)
    slope_rho = _fit_slope(log_dts, log_rho)
    slope_kappa = _fit_slope(log_dts, log_kappa)
    wall_total = sum(r.wall for r in results)
    @printf("    → slopes: φ=%.3f, ρ=%.3f, κ=%.3f   wall=%.0fs\n",
        slope_phi, slope_rho, slope_kappa, wall_total)
    return (slope_phi=slope_phi, slope_rho=slope_rho, slope_kappa=slope_kappa,
        results=results)
end

@printf("=== B-2 full matrix: 4 schemes × 3 regimes order ladder ===\n")
@printf("F=%d, %d³, T=%.2f, g_S=(0=>1.0, 2=>1.2)\n", F, N_SPATIAL, T_FINAL)

V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
dts = [0.02, 0.01, 0.005, 0.0025]

# Build 3 initial states
state_vacuum = _initial_state_anti_polar()
state_pre = _state_pre_evolved(state_vacuum, V_ext, g_S; n_steps=20, dt=0.002)
state_rand = _state_random(42)

# Build 3 references (Y4-mid at dt_ref)
regimes = [
    ("vacuum", state_vacuum),
    ("pre-evolved", state_pre),
    ("random Hermitian", state_rand),
]
references = Dict{String, Any}()
for (rname, rstate) in regimes
    @printf("\n── Building reference for regime '%s' (Y4-mid @ dt=%.5f, T=%.2f, %d steps) ──\n",
        rname, DT_REF, T_FINAL, round(Int, T_FINAL / DT_REF))
    t0 = time()
    references[rname] = _run(:y4_midpoint, true, DT_REF, rstate, g_S, V_ext)
    @printf("    wall=%.0fs\n", time() - t0)
end

# 4 schemes
schemes = [
    ("Strang plain", :strang, false),
    ("Strang picard", :strang_pm, true),
    ("Y4 plain", :y4_midpoint, false),
    ("Y4 picard (A4)", :y4_midpoint, true),
]

# 4 × 3 matrix run
results_matrix = Dict{Tuple{String, String}, Any}()
for (rname, rstate) in regimes
    @printf("\n████ Regime: %s ████\n", rname)
    state_ref = references[rname]
    for (sname, scheme, pm) in schemes
        results_matrix[(rname, sname)] = _ladder_scheme(
            sname, scheme, pm, dts, rstate, state_ref, g_S, V_ext)
    end
end

# Summary tables (one per component)
for (component, getter) in [
    ("φ", r -> r.slope_phi),
    ("ρ", r -> r.slope_rho),
    ("κ", r -> r.slope_kappa),
]
    @printf("\n%s\n=== Order ladder matrix (%s slope) ===\n%s\n",
        "═"^80, component, "═"^80)
    @printf("%-20s  %-12s  %-15s  %-20s\n",
        "scheme", "vacuum", "pre-evolved", "random Hermitian")
    for (sname, _, _) in schemes
        s_v = getter(results_matrix[("vacuum", sname)])
        s_p = getter(results_matrix[("pre-evolved", sname)])
        s_r = getter(results_matrix[("random Hermitian", sname)])
        @printf("%-20s  %-12.3f  %-15.3f  %-20.3f\n", sname, s_v, s_p, s_r)
    end
end

@printf("\n── Hypothesis A (left/right φ-half generator asymmetry × κ build-up) ──\n")
@printf("Prediction matrix (component-aware):\n")
@printf("  vacuum:       Strang plain φ-slope LOW (~1),  ρ/κ-slope ~1 (asymmetry × build-up)\n")
@printf("                Strang picard ALL slopes ~2 (asymmetry killed by Picard)\n")
@printf("                Y4 plain ALL slopes LOW (~1) (asymmetry compounds in composition)\n")
@printf("                Y4 picard ALL slopes ~4 (confirmed at φ from initial B-2)\n")
@printf("  pre-evolved:  Strang plain ALL slopes ~2 (asymmetry vanishes at saturated κ)\n")
@printf("                Y4 plain ALL slopes ~3.4 (palindrome slope 2 degrades 4 → 3.4)\n")
@printf("                Y4 picard ALL slopes ~4\n")
@printf("  random:       Same as pre-evolved (generic non-trivial (ρ, κ))\n")
