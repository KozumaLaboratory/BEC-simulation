# T-sweep at α=0 — falsifier for the "‖W^φ‖·T phase accumulation"
# hypothesis on the slope_φ degradation.
#
# Initial state: random ρ (Hermitian, ~0.05 magnitude), κ=0. Same as
# `intermediate_delta_sweep.jl` α=0 regime. Δ^φ_baseline = 0, but
# ‖U^φ‖ ≈ 0.34 (≫ vacuum 0.02).
#
# Hypothesis (phase accumulation): φ slope is suppressed below 2 by
# rotation-averaging of asymmetric perturbation δW^φ. The effective
# averaging factor scales with ‖W^φ‖ · T (total rotation angle
# accumulated over the integration time).
#
# Predicted slope at α=0:
#   T = 0.05 → ‖W^φ‖·T = 0.017 → slope close to vacuum-like (~1.2)
#   T = 0.2  → ‖W^φ‖·T = 0.068 → slope 1.702 (B-3.5 anchor, confirmed)
#   T = 1.0  → ‖W^φ‖·T = 0.34  → slope approaching 2 (saturation)
#
# Falsifier: if slope stays ~1.7 across all T or doesn't track ‖W^φ‖·T
# monotonically, the phase-accumulation picture is refuted and a
# different mechanism is needed.
#
# Run: julia --project=. scripts/diagnostic/T_sweep_alpha0.jl

using SpinorBEC
using Printf
using LinearAlgebra
using Random

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
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

# α=0 initial: random ρ (Hermitian), κ=0.
function _state_alpha0(seed::Int=42)
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
        # κ left at zero (α=0).
        # Consume a second rng draw to keep state generation consistent
        # with intermediate_delta_sweep.jl (which would have used it).
        randn(rng, ComplexF64, D, D)
        for c in 1:D, cp in 1:D
            rho[I, c, cp] = rho_loc[c, cp]
        end
    end
    SpinorBEC.TDHFBState{3, typeof(phi), typeof(rho), Float64}(
        phi, rho, kappa, 0.0, 0
    )
end

function _baselines(state, g_S)
    V_kernel = SpinorBEC.channel_kernel(F, g_S)
    sz = size(state.phi)
    spatial = sz[1:(end - 1)]
    Dloc = sz[end]
    norm_U = 0.0
    norm_Delta = 0.0
    @inbounds for idx in CartesianIndices(spatial)
        for c in 1:Dloc, cp in 1:Dloc
            uval = ComplexF64(0)
            dval = ComplexF64(0)
            for c2 in 1:Dloc, c2p in 1:Dloc
                Vk = V_kernel[c, cp, c2, c2p]
                Vk == 0.0 && continue
                uval +=
                    Vk * (
                        conj(state.phi[idx, c2p]) * state.phi[idx, c2]
                        +
                        state.rho[idx, c2, c2p]
                    )
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
    mx = sum(log_xs) / n
    my = sum(log_ys) / n
    sum((log_xs[i] - mx) * (log_ys[i] - my) for i in 1:n) /
    sum((log_xs[i] - mx)^2 for i in 1:n)
end

function _measure_at_T(T::Float64, state0, g_S, V_ext, dts, norm_U)
    @printf("\n%s\n=== T = %.3f  (‖U^φ‖·T = %.4f) ===\n%s\n",
        "─"^72, T, norm_U * T, "─"^72)
    @printf("Building reference (Y4-mid @ dt=%.5f, %d steps)...\n",
        DT_REF, round(Int, T / DT_REF))
    t0 = time()
    state_ref = _run_ref(DT_REF, T, state0, g_S, V_ext)
    @printf("    ref wall = %.0fs\n", time() - t0)

    @printf("\n%-8s  %-13s  %-13s  %-13s  %-8s\n",
        "dt", "φ err", "ρ err", "κ err", "wall(s)")
    results = NamedTuple[]
    for dt in dts
        t1 = time()
        state = _run_strang(dt, T, state0, g_S, V_ext)
        err = _state_err(state, state_ref)
        @printf("%-8.5f  %-13.4e  %-13.4e  %-13.4e  %-8.1f\n",
            dt, err.phi, err.rho, err.kappa, time() - t1)
        push!(results, (dt=dt, err...))
    end
    log_dts = log.([r.dt for r in results])
    sφ = _fit_slope(log_dts, log.([r.phi for r in results]))
    sρ = _fit_slope(log_dts, log.([r.rho for r in results]))
    sκ = _fit_slope(log_dts, log.([r.kappa for r in results]))
    @printf("→ slopes: φ=%.3f  ρ=%.3f  κ=%.3f\n", sφ, sρ, sκ)
    return (T=T, slope_phi=sφ, slope_rho=sρ, slope_kappa=sκ,
        OT=norm_U * T)
end

@printf("=== T-sweep at α=0 (random ρ, κ=0) — phase accumulation test ===\n")
@printf("F=%d, %d³, g_S=(0=>1.0, 2=>1.2)\n", F, N_SPATIAL)

V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
state0 = _state_alpha0()
norm_U, norm_Delta = _baselines(state0, g_S)
@printf("Baseline ‖U^φ‖ = %.4e  ‖Δ^φ‖ = %.4e\n", norm_U, norm_Delta)

dts = [0.02, 0.01, 0.005, 0.0025]
T_values = [0.05, 0.2, 1.0]

results = NamedTuple[]
for T in T_values
    push!(results, _measure_at_T(T, state0, g_S, V_ext, dts, norm_U))
end

@printf("\n%s\n=== Phase accumulation sweep summary ===\n%s\n",
    "═"^72, "═"^72)
@printf("%-8s  %-12s  %-10s  %-10s  %-10s\n",
    "T", "‖U^φ‖·T", "slope(φ)", "slope(ρ)", "slope(κ)")
for r in results
    @printf("%-8.3f  %-12.4f  %-10.3f  %-10.3f  %-10.3f\n",
        r.T, r.OT, r.slope_phi, r.slope_rho, r.slope_kappa)
end

@printf("\n── Verdict ──\n")
phis = [r.slope_phi for r in results]
@printf("φ slope range: %.3f → %.3f over ‖U^φ‖·T = %.3f → %.3f\n",
    phis[1], phis[end], results[1].OT, results[end].OT)
if phis[end] > phis[1] + 0.2
    @printf("→ φ slope GROWS with ‖U^φ‖·T (phase accumulation hypothesis SUPPORTED)\n")
elseif abs(phis[end] - phis[1]) < 0.1
    @printf("→ φ slope T-INDEPENDENT (phase accumulation hypothesis REFUTED)\n")
else
    @printf("→ φ slope changes are intermediate — inspect data\n")
end
