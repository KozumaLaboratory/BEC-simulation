# Intermediate-Δ regime sweep — falsifier between threshold vs continuous
# mechanism for the φ-slope dependence on Nambu mixing structure.
#
# Initial state has random ρ (Hermitian, ~0.05 magnitude) plus κ scaled
# by α ∈ {0, 0.1, 0.3, 0.5, 1.0}. φ same across α (random ~0.1).
#
# Δ^φ_baseline ≡ ‖V·κ‖_∞  scales linearly with α.
# U^φ_baseline ≡ ‖V·(φ*φ + ρ)‖_∞  is α-independent.
#
# For each α: measure φ global slope via Strang plain order ladder at T=0.2.
# Outcome distinguishes:
#   THRESHOLD mechanism — φ slope ~1 for α < threshold, ~2 above (binary)
#   MAGNITUDE mechanism — φ slope interpolates continuously 1 → 2 with α
#
# Predicted at 5 α values, the B-2 anchors are α=0 → slope 1.1 (vacuum
# is α=0 with ρ=0 too, but here ρ=random) and α=1 → slope 1.9 (random).
#
# Run: julia --project=. scripts/diagnostic/intermediate_delta_sweep.jl

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

# Build a random initial state with κ scaled by α.
function _state_with_kappa_scale(α::Float64; seed::Int=42)
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
        # κ built with a SEPARATE rng draw for independence
        B = randn(rng, ComplexF64, D, D) * 0.05
        kappa_loc = 0.5 * (B + transpose(B)) * α
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
            kappa[I, c, cp] = kappa_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0
    )
end

# Measure baseline ‖U^φ‖_∞ and ‖Δ^φ‖_∞ at the initial state.
function _baselines(state, g_S)
    V_kernel = SpinorBEC.channel_kernel(F, g_S)
    sz = size(state.phi)
    spatial = sz[1:(end - 1)]
    Dloc = sz[end]
    norm_U = 0.0
    norm_Delta = 0.0
    @inbounds for idx in CartesianIndices(spatial)
        for c in 1:Dloc, cp in 1:Dloc
            uval = ComplexF64(0);
            dval = ComplexF64(0)
            for c2 in 1:Dloc, c2p in 1:Dloc
                Vk = V_kernel[c, cp, c2, c2p]
                Vk == 0.0 && continue
                uval +=
                    Vk * (conj(state.phi[idx, c2p]) * state.phi[idx, c2]
                          +
                          state.rho[idx, c2, c2p])
                dval += Vk * state.kappa[idx, c2, c2p]
            end
            norm_U = max(norm_U, abs(uval))
            norm_Delta = max(norm_Delta, abs(dval))
        end
    end
    return norm_U, norm_Delta
end

function _run_strang(dt, T, state0, g_S, V_ext)
    n_steps = round(Int, T / dt)
    state = deepcopy(state0)
    tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps; scheme=:strang)
    return state
end

function _run_ref(dt, T, state0, g_S, V_ext)
    n_steps = round(Int, T / dt)
    state = deepcopy(state0)
    tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
        scheme=:y4_midpoint,
        picard_midpoint=true,
        picard_midpoint_tol=1e-14,
        picard_midpoint_max_iter=100,
    )
    return state
end

function _state_err(state, state_ref)
    phi_e = maximum(abs.(state.phi .- state_ref.phi))
    rho_e = maximum(abs.(state.rho .- state_ref.rho))
    kappa_e = maximum(abs.(state.kappa .- state_ref.kappa))
    (phi=phi_e, rho=rho_e, kappa=kappa_e)
end

function _fit_slope(log_xs, log_ys)
    n = length(log_xs)
    mx = sum(log_xs) / n;
    my = sum(log_ys) / n
    sum((log_xs[i] - mx) * (log_ys[i] - my) for i in 1:n) /
    sum((log_xs[i] - mx)^2 for i in 1:n)
end

function _measure_slopes(α, V_ext, g_S, dts)
    @printf("\n%s\n=== α = %.3f ===\n%s\n", "─"^72, α, "─"^72)
    state0 = _state_with_kappa_scale(α)
    norm_U, norm_Delta = _baselines(state0, g_S)
    ratio = norm_U > 0 ? norm_Delta / norm_U : 0.0
    @printf("‖U^φ‖_∞ = %.4e   ‖Δ^φ‖_∞ = %.4e   ratio Δ/U = %.4f\n",
        norm_U, norm_Delta, ratio)

    @printf("Building reference (Y4-mid @ dt=%.5f, %d steps)...\n",
        DT_REF, round(Int, T_FINAL / DT_REF))
    t0 = time()
    state_ref = _run_ref(DT_REF, T_FINAL, state0, g_S, V_ext)
    @printf("    wall=%.0fs\n", time() - t0)

    @printf("\n%-8s  %-13s  %-13s  %-13s  %-8s\n",
        "dt", "φ err", "ρ err", "κ err", "wall(s)")
    results = NamedTuple[]
    for dt in dts
        t1 = time()
        state = _run_strang(dt, T_FINAL, state0, g_S, V_ext)
        err = _state_err(state, state_ref)
        @printf("%-8.5f  %-13.4e  %-13.4e  %-13.4e  %-8.1f\n",
            dt, err.phi, err.rho, err.kappa, time() - t1)
        push!(results, (dt=dt, err...))
    end
    log_dts = log.([r.dt for r in results])
    sφ = _fit_slope(log_dts, log.([r.phi for r in results]))
    sρ = _fit_slope(log_dts, log.([r.rho for r in results]))
    sκ = _fit_slope(log_dts, log.([r.kappa for r in results]))
    @printf("→ Strang plain slopes: φ=%.3f, ρ=%.3f, κ=%.3f\n", sφ, sρ, sκ)
    return (α=α, norm_U=norm_U, norm_Delta=norm_Delta, ratio=ratio,
        slope_phi=sφ, slope_rho=sρ, slope_kappa=sκ)
end

@printf("=== Intermediate-Δ regime sweep (random ρ, scaled κ) ===\n")
@printf("F=%d, %d³, g_S=(0=>1.0, 2=>1.2), T=%.2f\n", F, N_SPATIAL, T_FINAL)
@printf("Threshold hypothesis: φ-slope is ~1 for α below threshold, ~2 above\n")
@printf("Magnitude hypothesis: φ-slope interpolates continuously 1 → 2 with α\n")

V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
dts = [0.02, 0.01, 0.005, 0.0025]

αs = [0.0, 0.1, 0.3, 0.5, 1.0]
results = NamedTuple[]
for α in αs
    push!(results, _measure_slopes(α, V_ext, g_S, dts))
end

@printf("\n%s\n=== Sweep summary: φ-slope vs Δ^φ/U^φ baseline ratio ===\n%s\n",
    "═"^72, "═"^72)
@printf("%-6s  %-12s  %-12s  %-10s  %-10s  %-10s  %-10s\n",
    "α", "‖U^φ‖", "‖Δ^φ‖", "ratio", "slope(φ)", "slope(ρ)", "slope(κ)")
for r in results
    @printf("%-6.3f  %-12.4e  %-12.4e  %-10.4f  %-10.3f  %-10.3f  %-10.3f\n",
        r.α, r.norm_U, r.norm_Delta, r.ratio,
        r.slope_phi, r.slope_rho, r.slope_kappa)
end

@printf("\n── Verdict ──\n")
slopes = [r.slope_phi for r in results]
ratios = [r.ratio for r in results]
# Sharpness check: how monotonic is the slope vs ratio?
sorted_idx = sortperm(ratios)
sorted_slopes = slopes[sorted_idx]
sorted_ratios = ratios[sorted_idx]
@printf("Sorted by Δ/U ratio:  ")
for (r, s) in zip(sorted_ratios, sorted_slopes)
    @printf("(%.3f → %.2f) ", r, s)
end
@printf("\n")
# Crude threshold detector: largest jump in φ-slope per unit ratio change
local biggest_jump = 0.0
local biggest_at = 0
for i in 2:length(sorted_slopes)
    dr = sorted_ratios[i] - sorted_ratios[i - 1]
    ds = sorted_slopes[i] - sorted_slopes[i - 1]
    rate = abs(ds / max(dr, 1e-9))
    if rate > biggest_jump
        biggest_jump = rate
        biggest_at = i
    end
end
@printf(
    "Biggest slope jump per unit ratio: %.2f at index %d (Δ/U %.3f → %.3f, slope %.2f → %.2f)\n",
    biggest_jump, biggest_at,
    sorted_ratios[biggest_at - 1], sorted_ratios[biggest_at],
    sorted_slopes[biggest_at - 1], sorted_slopes[biggest_at])
if biggest_jump > 3.0
    @printf("→ Likely THRESHOLD mechanism (binary transition near ratio %.3f)\n",
        0.5 * (sorted_ratios[biggest_at - 1] + sorted_ratios[biggest_at]))
elseif maximum(sorted_slopes) - minimum(sorted_slopes) > 0.4
    @printf("→ Likely MAGNITUDE mechanism (continuous slope interpolation)\n")
else
    @printf("→ Insufficient slope variation; need wider α range or refined diagnostic\n")
end
