# B-3: Substep generator asymmetry probe.
#
# Two-component error model: E_global = A·τ² + B·τ + O(τ³)
#   A = standard symmetric Strang order-2 coefficient
#   B = asymmetry-driven order-1 coefficient (TDHFB inner triple specific)
#
# B is sourced by left/right φ-half generator difference
#   ΔW^φ ≡ W^φ[state after R-step] − W^φ[state at substep entry]
#       = V · (Δρ + Δκ)
#
# Per-step asymmetry contribution to global error:
#   ‖ΔW^φ‖ × τ accumulates as B · τ ∝ T · (V · ρ̇ / V · ρ_baseline) → slope 1.
#
# B / A scale per regime / component:
#   - V · ρ_baseline small (vacuum / pre-evolved): B / A ≫ 1 → slope 1
#   - V · ρ_baseline large (random): B_φ / A_φ ≪ 1 → φ near nominal 2
#   - W^R has no analogous suppression mechanism (ρ, κ couple direct) →
#     ρ, κ slopes stay 1 even at random.
#
# This script measures ‖ΔW^φ‖ / ‖W^φ_L‖ at each regime, decomposed by
# channel (V · Δρ vs V · Δκ), as a function of τ. The ratio at τ = 0.005
# is the empirical B / A indicator.
#
# Setup: F=1 16³, anti-polar / pre-evolved / random Hermitian, g_S=(1.0, 1.2).
# Run: julia --project=. scripts/diagnostic/asymmetry_probe.jl

using SpinorBEC
using Printf
using LinearAlgebra
using Random

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0

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

# Build W^φ generator at each voxel from a given (phi, rho, kappa) state.
# Returns (U_phi, Delta_phi) as 5-D arrays (spatial..., D, D).
function _build_W_phi(state, V_kernel)
    sz = size(state.phi)
    spatial = sz[1:(end - 1)]
    Dloc = sz[end]
    U_phi = zeros(ComplexF64, spatial..., Dloc, Dloc)
    Delta_phi = zeros(ComplexF64, spatial..., Dloc, Dloc)
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
            U_phi[idx, c, cp] = uval
            Delta_phi[idx, c, cp] = dval
        end
    end
    return U_phi, Delta_phi
end

function _probe(label, state0, V_ext, g_S, dts)
    @printf("\n%s\n=== %s ===\n%s\n", "─"^72, label, "─"^72)
    V_kernel = SpinorBEC.channel_kernel(F, g_S)

    # Baseline W^φ_L from the starting state.
    U_L, Delta_L = _build_W_phi(state0, V_kernel)
    norm_U_L = maximum(abs.(U_L))
    norm_Delta_L = maximum(abs.(Delta_L))
    norm_W_L = max(norm_U_L, norm_Delta_L)

    @printf("Baseline ‖W^φ_L‖_∞: ‖U^φ‖=%.4e  ‖Δ^φ‖=%.4e  ‖W‖=%.4e\n",
        norm_U_L, norm_Delta_L, norm_W_L)
    @printf("Baseline ‖ρ‖_∞ = %.4e  ‖κ‖_∞ = %.4e\n",
        maximum(abs.(state0.rho)), maximum(abs.(state0.kappa)))

    @printf("\n%-8s  %-12s  %-12s  %-12s  %-12s\n",
        "dt", "‖ΔU^φ‖", "‖VΔρ part‖", "‖ΔΔ^φ‖", "ratio/baseline")
    results = NamedTuple[]
    for dt in dts
        # Take ONE Strang step from state0 and compare W^φ at exit vs entry.
        # This gives the per-substep asymmetry ΔW^φ that drives the B term.
        s = deepcopy(state0)
        # Need (ρ, κ) AFTER the R-step but with original φ context. Easiest:
        # full Strang step gives state after V/2, HF/2, K, HF/2, V/2 — the
        # (ρ, κ) shift sampled here is the cumulative one across the step.
        tdhfb_strang_step!(s, F, g_S, V_ext, dt)
        U_R, Delta_R = _build_W_phi(s, V_kernel)
        dU = maximum(abs.(U_R .- U_L))
        dDelta = maximum(abs.(Delta_R .- Delta_L))
        # Decompose ΔU^φ contributions: V · Δρ vs V · Δ(φ*φ).
        # ΔU^φ = V · (Δ(φ*φ) + Δρ). The V·Δρ-only part:
        Delta_rho = s.rho .- state0.rho
        VDrho = zeros(ComplexF64, size(U_L))
        @inbounds for idx in CartesianIndices(size(state0.phi)[1:(end - 1)])
            for c in 1:D, cp in 1:D
                acc = ComplexF64(0)
                for c2 in 1:D, c2p in 1:D
                    Vk = V_kernel[c, cp, c2, c2p]
                    Vk == 0.0 && continue
                    acc += Vk * Delta_rho[idx, c2, c2p]
                end
                VDrho[idx, c, cp] = acc
            end
        end
        norm_VDrho = maximum(abs.(VDrho))

        ratio_W = max(dU, dDelta) / norm_W_L
        @printf("%-8.5f  %-12.4e  %-12.4e  %-12.4e  %-12.4e\n",
            dt, dU, norm_VDrho, dDelta, ratio_W)
        push!(results, (
            dt=dt, dU=dU, dDelta=dDelta,
            VDrho=norm_VDrho, ratio=ratio_W,
        ))
    end

    # Slope fits.
    log_dts = log.([r.dt for r in results])
    function _slope(field)
        ys = log.([getfield(r, field) for r in results])
        n = length(log_dts)
        mx = sum(log_dts) / n;
        my = sum(ys) / n
        sum((log_dts[i] - mx) * (ys[i] - my) for i in 1:n) /
        sum((log_dts[i] - mx)^2 for i in 1:n)
    end
    sU = _slope(:dU)
    sDelta = _slope(:dDelta)
    sVDrho = _slope(:VDrho)
    sRatio = _slope(:ratio)
    @printf("\nLSQ slopes: ‖ΔU^φ‖=%.3f  ‖VΔρ‖=%.3f  ‖ΔΔ^φ‖=%.3f  ratio=%.3f\n",
        sU, sVDrho, sDelta, sRatio)
    return (norm_W_L=norm_W_L, results=results,
        slope_U=sU, slope_Delta=sDelta, slope_VDrho=sVDrho, slope_ratio=sRatio)
end

@printf("=== B-3: substep generator asymmetry probe ===\n")
@printf("F=%d, %d³, g_S=(0=>1.0, 2=>1.2), three reference states\n", F, N_SPATIAL)

V_ext = _harmonic_trap()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
dts = [0.04, 0.02, 0.01, 0.005, 0.0025]

state_vacuum = _initial_state_anti_polar()
state_pre = _state_pre_evolved(state_vacuum, V_ext, g_S; n_steps=20, dt=0.002)
state_rand = _state_random(42)

r_vac = _probe("(1) vacuum", state_vacuum, V_ext, g_S, dts)
r_pre = _probe("(2) pre-evolved", state_pre, V_ext, g_S, dts)
r_rand = _probe("(3) random Hermitian", state_rand, V_ext, g_S, dts)

# Summary
@printf("\n%s\n=== Summary: |ΔW^φ| / |W^φ_L| at dt=0.005 ===\n%s\n", "═"^72, "═"^72)
@printf("%-25s  %-15s  %-15s  %-15s\n",
    "regime", "‖W^φ_L‖", "‖ΔW^φ‖", "ratio (B/A indicator)")
function _at_dt(scan, dt)
    for r in scan.results
        if r.dt ≈ dt
            return r
        end
    end
    return nothing
end
for (lbl, r) in [("vacuum", r_vac), ("pre-evolved", r_pre), ("random Hermitian", r_rand)]
    pt = _at_dt(r, 0.005)
    @printf("%-25s  %-15.4e  %-15.4e  %-15.4e\n",
        lbl, r.norm_W_L, max(pt.dU, pt.dDelta), pt.ratio)
end

@printf("\n=== Slope of ‖ΔW^φ‖ vs dt (should be ~1 — R-step shifts ρ,κ linearly) ===\n")
@printf("%-25s  %-10s  %-10s\n", "regime", "slope(ΔU)", "slope(ΔΔ)")
for (lbl, r) in [("vacuum", r_vac), ("pre-evolved", r_pre), ("random Hermitian", r_rand)]
    @printf("%-25s  %-10.3f  %-10.3f\n", lbl, r.slope_U, r.slope_Delta)
end

@printf("\n── B/A indicator interpretation ──\n")
@printf("ratio = ‖ΔW^φ‖/‖W^φ_L‖ at fixed dt:\n")
@printf("  → small (≪ 1): φ generator perturbation is suppressed by ‖W^φ_L‖\n")
@printf("                  baseline; B contribution to φ error is small;\n")
@printf("                  φ slope near nominal Strang order 2.\n")
@printf("  → large (~ 1): φ generator perturbation comparable to baseline;\n")
@printf("                  B contribution dominates; φ slope ~ 1.\n")
@printf("Compare with B-2 φ-slopes:\n")
@printf("  vacuum         1.099 → expect ratio ~ 1\n")
@printf("  pre-evolved    1.095 → expect ratio ~ 1\n")
@printf("  random         1.895 → expect ratio ≪ 1\n")
