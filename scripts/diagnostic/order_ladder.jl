# B-2: Order ladder — measure observed global convergence order of each
# integrator at fixed T, by comparing against a high-accuracy reference.
#
# Schemes (TDHFB side):
#   1. Strang             — base, nominal order 2.
#   2. Y4-plain           — Y4 composition over plain Strang substep.
#                           Nominal 4, predicted to degrade (palindrome breakdown).
#   3. Y4-mid (A4 fix)    — Y4 composition with picard_midpoint=true substep.
#                           Nominal 4, expected to deliver order 4.
#
# Method:
#   Reference: Y4-mid at dt_ref = 0.0005, T = 0.2. Treated as exact.
#   Tests: each scheme at dt ∈ {0.02, 0.01, 0.005, 0.0025}, T = 0.2.
#   Error: ‖ψ_scheme(T) − ψ_ref(T)‖_∞ over (φ, ρ, κ).
#   Slope: LSQ fit of log(err) vs log(dt) gives the observed global order p.
#
# Setup: v3 anti-polar (F=1 16³, harmonic trap, g_S=(0=>1.0, 2=>1.2)).
#
# Run: julia --project=. scripts/diagnostic/order_ladder.jl

using SpinorBEC
using Printf
using LinearAlgebra

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
const T_FINAL = 0.2

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

function _run(scheme::Symbol, picard_midpoint::Bool, dt::Float64,
    state0, g_S, V_ext; verbose::Bool=false)
    n_steps = round(Int, T_FINAL / dt)
    state = deepcopy(state0)
    t_start = time()
    if scheme === :strang
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps; scheme=:strang)
    else  # :y4_midpoint
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
            scheme=:y4_midpoint,
            picard_midpoint=picard_midpoint,
            picard_midpoint_tol=1e-13,
            picard_midpoint_max_iter=30,
        )
    end
    wall = time() - t_start
    if verbose
        @printf("  scheme=%s, picard_midpoint=%s, dt=%.5f, n_steps=%d, wall=%.1fs\n",
            scheme, picard_midpoint, dt, n_steps, wall)
    end
    return state, wall
end

function _state_err(state, state_ref)
    phi_e = maximum(abs.(state.phi .- state_ref.phi))
    rho_e = maximum(abs.(state.rho .- state_ref.rho))
    kappa_e = maximum(abs.(state.kappa .- state_ref.kappa))
    (phi=phi_e, rho=rho_e, kappa=kappa_e, total=max(phi_e, rho_e, kappa_e))
end

function _ladder(label, scheme, picard_midpoint, dts, state0, state_ref, g_S, V_ext)
    @printf("\n%s\n=== %s ===\n%s\n", "─"^72, label, "─"^72)
    @printf("%-10s  %-13s  %-13s  %-13s  %-10s  %-8s\n",
        "dt", "φ err", "ρ err", "κ err", "slope(φ)", "wall (s)")
    results = NamedTuple[]
    prev_err = NaN
    for dt in dts
        state, wall = _run(scheme, picard_midpoint, dt, state0, g_S, V_ext)
        err = _state_err(state, state_ref)
        ord = isnan(prev_err) ? NaN : log2(prev_err / err.phi)
        @printf("%-10.5f  %-13.4e  %-13.4e  %-13.4e  %-10s  %-8.1f\n",
            dt, err.phi, err.rho, err.kappa,
            isnan(ord) ? "—" : @sprintf("%.2f", ord), wall)
        push!(results, (dt=dt, err...))
        prev_err = err.phi
    end
    log_dts = log.([r.dt for r in results])
    log_phi = log.([r.phi for r in results])
    n = length(log_dts)
    mean_x = sum(log_dts) / n;
    mean_y = sum(log_phi) / n
    slope =
        sum((log_dts[i] - mean_x) * (log_phi[i] - mean_y) for i in 1:n) /
        sum((log_dts[i] - mean_x)^2 for i in 1:n)
    @printf("\nLSQ slope (φ error, %d dts): %.3f\n", n, slope)
    return (slope=slope, results=results)
end

@printf("=== B-2: Order ladder (TDHFB, v3 anti-polar setup) ===\n")
@printf("F=%d, %d³, T=%.2f, g_S=(0=>1.0, 2=>1.2)\n", F, N_SPATIAL, T_FINAL)

state0 = _initial_state_anti_polar()
V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)

# Reference: Y4-mid at dt_ref = 0.0005
dt_ref = 0.0005
@printf("\n── Building reference: Y4-mid @ dt=%.5f, T=%.2f (%d steps) ──\n",
    dt_ref, T_FINAL, round(Int, T_FINAL / dt_ref))
state_ref, wall_ref = _run(:y4_midpoint, true, dt_ref, state0, g_S, V_ext; verbose=true)

dts = [0.02, 0.01, 0.005, 0.0025]

l_strang = _ladder("Strang (nominal order 2)",
    :strang, false, dts, state0, state_ref, g_S, V_ext)
l_y4_plain = _ladder("Y4-plain over plain Strang substep (nominal 4)",
    :y4_midpoint, false, dts, state0, state_ref, g_S, V_ext)
l_y4_mid = _ladder("Y4-mid (A4 fix, picard_midpoint=true) (nominal 4)",
    :y4_midpoint, true, dts, state0, state_ref, g_S, V_ext)

@printf("\n%s\n=== Order ladder summary ===\n%s\n", "═"^72, "═"^72)
@printf("%-50s  %-10s  %-10s\n", "scheme", "nominal", "measured")
@printf("%-50s  %-10d  %-10.3f\n", "Strang", 2, l_strang.slope)
@printf("%-50s  %-10d  %-10.3f\n", "Y4-plain", 4, l_y4_plain.slope)
@printf("%-50s  %-10d  %-10.3f\n", "Y4-mid (A4)", 4, l_y4_mid.slope)

@printf("\n── Verdict ──\n")
function _judge(label, nominal, measured)
    diff = abs(measured - nominal)
    if diff < 0.3
        @printf("✓ %s: measured %.2f matches nominal %d\n", label, measured, nominal)
    elseif measured < nominal - 0.5
        @printf("△ %s: measured %.2f DEGRADED from nominal %d (Δ=%.2f)\n",
            label, measured, nominal, nominal - measured)
    else
        @printf("? %s: measured %.2f vs nominal %d (Δ=%.2f, investigate)\n",
            label, measured, nominal, diff)
    end
end
_judge("Strang", 2, l_strang.slope)
_judge("Y4-plain", 4, l_y4_plain.slope)
_judge("Y4-mid", 4, l_y4_mid.slope)
