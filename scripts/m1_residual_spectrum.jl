#!/usr/bin/env julia
# scripts/m1_residual_spectrum.jl
#
# Direct test of "is the 0.218 P_⊥∇E residual cosmetic?"
#
# Two independent diagnostics, no metric-change goalpost-moving:
#
#   (a) k-space radial spectrum of P_⊥∇E per spinor component,
#       compared against ψ's spectrum. Cosmetic (Sobolev-justified)
#       case: residual concentrated at high |k| while ψ is at low |k|.
#       Physical case: residual lives at the same |k| as ψ → moving
#       it actually moves the state.
#
#   (b) Newton-step / curvature-based ΔE_to_min estimate. From the
#       clean freeze test's α-scan:
#         ΔE(α) = −α·R² + (1/2)·α²·H + O(α³)
#       Solve for H from one (α, ΔE) sample, then the locally optimal
#       step is α* = R²/H and ΔE_to_min ≈ −R²·α*/2 = −R²² / (2H).
#       Compare to basin threshold 0.01 to decide whether the freeze
#       energy gap is cosmetic (≪0.01) or load-bearing (~0.01).
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_residual_spectrum.jl
#
# Cost: 1 gradient call on the cached 24³×13 grid + a handful of FFTs.

if !("--smoke" in ARGS)
    import CUDA
end
using SpinorBEC
using Printf
using JLD2
using FFTW
const USE_SMOKE = "--smoke" in ARGS
const USE_CPU = USE_SMOKE
const BACKEND = USE_CPU ? CPUBackend() : CUDABackend()

const TW = eu151_preset()
const CACHED_PATH = "runs/sprint5_M1_basin_valley_B0.0_Om0.4.jld2"
const B_NT = 0.0
const OMEGA = 0.4
const SEED = :polar
const N_BINS = 12

# Curvature from the α-scan we already have in m1_clean_freeze_test.jl.
# Pair: (α, ΔE_meas). Pick α not too large (else cubic term contaminates)
# and not too small (else round-off in ΔE). α=1e-2 is in the sweet spot:
# the α² term dominates the linear, but cubic is still <O(R²·α³·H_3) ≪ α²·H/2.
const ALPHA_SAMPLE = 1e-2
const DELTA_E_SAMPLE = 7.850447e-5   # measured in the freeze test

# Basin threshold for "cosmetic vs load-bearing" decision.
const BASIN_THRESHOLD = 0.01

function projected_gradient(ws, psi_cpu, dV)
    grad_dev = similar(ws.state.psi)
    k_squared_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi_cpu) * dV
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / psi_norm²
    proj_cpu = grad_cpu .- μ .* psi_cpu
    return proj_cpu, grad_cpu, μ, sqrt(sum(abs2, proj_cpu) * dV)
end

"""
Radial power-spectrum of a 4-D field `f[x,y,z,c]` summed over the spinor
axis. Returns `(k_centers, power_per_bin)` with `N_BINS` log-spaced bins
between `k_min` and `k_max`. Power is `|FFT(f)|²` normalised so the sum
over bins equals `‖f‖²_L²` (Parseval up to the dV/N factor).
"""
function radial_power_spectrum(f_cpu::AbstractArray{<:Complex, 4}, grid, n_bins::Int)
    nx, ny, nz, nc = size(f_cpu)
    # k magnitude on the grid (FFT layout matches grid.k[1], grid.k[2], grid.k[3]).
    kx = grid.k[1]
    ky = grid.k[2]
    kz = grid.k[3]
    k_mag = zeros(Float64, nx, ny, nz)
    @inbounds for I in CartesianIndices((nx, ny, nz))
        k_mag[I] = sqrt(kx[I[1]]^2 + ky[I[2]]^2 + kz[I[3]]^2)
    end
    k_max = maximum(k_mag)

    # Bin edges: equal-width in k (linear), bin centres reported.
    edges = range(0.0, k_max; length=n_bins + 1)
    centers = 0.5 .* (edges[1:(end - 1)] .+ edges[2:end])
    power = zeros(Float64, n_bins)

    # FFT per component, accumulate |·|² into bins.
    fft_buf = zeros(ComplexF64, nx, ny, nz)
    for c in 1:nc
        fft_buf .= view(f_cpu,:,:,:,c)
        fft!(fft_buf)
        @inbounds for I in CartesianIndices((nx, ny, nz))
            k = k_mag[I]
            # Find bin index. Linear-spaced edges → floor((k - 0) / Δk).
            Δk = step(edges)
            b = clamp(Int(floor(k / Δk)) + 1, 1, n_bins)
            power[b] += abs2(fft_buf[I])
        end
    end
    # Parseval normalisation: sum(|f|²)·dV ≡ sum(|FFT(f)|²) / N · dV_k...
    # We keep raw |FFT|² sums per bin and report normalised fractions.
    total = sum(power)
    fractions = total > 0 ? power ./ total : power
    return collect(centers), power, fractions, k_max
end

function main()
    println("=== M1 residual-spectrum diagnostic (cosmetic vs load-bearing) ===")
    @printf "Cell: B=%.1f nT, Ω=%.2f   seed: :%s   backend: %s\n\n" B_NT OMEGA SEED (
        USE_CPU ? "CPU" : "CUDA"
    )

    isfile(CACHED_PATH) || error("Missing $CACHED_PATH.")
    cached = JLD2.load(CACHED_PATH)
    psi_cached = cached["psi_$(SEED)"]

    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)

    # Warm-start workspace, snap ψ back to cached.
    r_warm = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=1, tol=0.0,
        initial_state=:polar, verbose=false,
        psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA, backend=BACKEND,
    )
    ws = r_warm.workspace
    copyto!(ws.state.psi, psi_cached)

    psi_cpu = copy(psi_cached)
    E0 = SpinorBEC.energy_decomposition(ws).total
    proj_cpu, grad_cpu, μ, R = projected_gradient(ws, psi_cpu, dV)
    R² = R^2
    @printf "‖ψ‖²_L²              = %.6e\n" sum(abs2, psi_cpu) * dV
    @printf "μ (Lagrange)         = %.6e\n" μ
    @printf "‖∇E‖_L²              = %.6e\n" sqrt(real(sum(abs2, grad_cpu)) * dV)
    @printf "‖P_⊥∇E‖_L²           = %.6e\n" R
    @printf "R² = ‖P_⊥∇E‖²_L²    = %.6e\n\n" R²

    # --- (a) Radial spectrum of ψ, ∇E, P_⊥∇E ---
    println("--- (a) Radial k-space power spectrum ---")
    println("    bins: $N_BINS linear in |k|, summed over all 13 spinor components")
    println()
    centers, pow_ψ, frac_ψ, kmax = radial_power_spectrum(psi_cpu, TW.grid, N_BINS)
    _, pow_g, frac_g, _ = radial_power_spectrum(grad_cpu, TW.grid, N_BINS)
    _, pow_p, frac_p, _ = radial_power_spectrum(proj_cpu, TW.grid, N_BINS)

    @printf "k_max on grid = %.3f\n\n" kmax
    @printf "%8s  %10s  %10s  %10s\n" "k_center" "ψ_frac" "∇E_frac" "P_⊥∇E_frac"
    for i in 1:N_BINS
        @printf "%8.3f  %10.4f  %10.4f  %10.4f\n" centers[i] frac_ψ[i] frac_g[i] frac_p[i]
    end
    println()

    # Cumulative low-k mass (k ≤ k_half).
    k_half = kmax / 2
    half_idx = something(findfirst(c -> c > k_half, centers), N_BINS + 1) - 1
    half_idx = clamp(half_idx, 1, N_BINS)
    cum_ψ = sum(frac_ψ[1:half_idx])
    cum_g = sum(frac_g[1:half_idx])
    cum_p = sum(frac_p[1:half_idx])
    @printf "Cumulative power below k=%.2f (= k_max/2):\n" k_half
    @printf "  ψ          : %.4f\n" cum_ψ
    @printf "  ∇E         : %.4f\n" cum_g
    @printf "  P_⊥∇E      : %.4f\n\n" cum_p

    cosmetic_a = cum_p < 0.3 && cum_ψ > 0.7
    println(
        "(a) Verdict: ",
        if cosmetic_a
            "COSMETIC — P_⊥∇E concentrated above k_half while ψ is below it."
        else
            "LOAD-BEARING — P_⊥∇E lives at the same |k| as ψ."
        end,
    )
    println()

    # --- (b1) Sanity: Re⟨grad, proj⟩ must equal R² (orthogonality bookkeeping) ---
    println("--- (b1) Projection-orthogonality sanity ---")
    inner_gp = real(sum(conj.(grad_cpu) .* proj_cpu)) * dV
    inner_pp = real(sum(conj.(proj_cpu) .* proj_cpu)) * dV
    inner_gp_psi = real(sum(conj.(proj_cpu) .* psi_cpu)) * dV
    @printf "  Re⟨∇E, P_⊥∇E⟩      = %.6e  (should equal R²)\n" inner_gp
    @printf "  Re⟨P_⊥∇E, P_⊥∇E⟩   = %.6e  (= R²)\n" inner_pp
    @printf "  Re⟨P_⊥∇E, ψ⟩       = %.6e  (should be ~0 — Lagrange projection)\n" inner_gp_psi
    @printf "  ratio Re⟨∇E,P⟩ / R² = %.6e\n\n" inner_gp / R²

    # --- (b2) Multi-α curvature fit: is H stable across α? ---
    # If a single quadratic ΔE = -α·R² + α²·H/2 fits all α, the local
    # landscape is quadratic and Newton-step ΔE_to_min is well-defined.
    # If H grows as α shrinks (or vice versa), the direction is
    # strongly anharmonic — Newton step is not informative.
    println("--- (b2) Multi-α curvature fit ---")
    α_grid = [1e-2, 1e-3, 1e-4, 1e-5]
    @printf "%12s  %14s  %14s  %12s\n" "α" "ΔE_meas" "fitted H" "‖step‖"
    for α in α_grid
        psi_step = psi_cpu .- α .* proj_cpu
        nrm² = sum(abs2, psi_step) * dV
        psi_step ./= sqrt(nrm²)
        # eval E
        copyto!(ws.state.psi, psi_step)
        E_step = SpinorBEC.energy_decomposition(ws).total
        ΔE = E_step - E0
        H_fit = 2 * (ΔE + α * R²) / α^2
        step_norm = α * R
        @printf "%12.2e  %+.6e  %+.6e  %12.4e\n" α ΔE H_fit step_norm
    end
    println()

    # --- (b3) Identify dominant landscape order along P_⊥∇E direction ---
    # If H = 2(ΔE + αR²)/α² scales as 1/α (constant ΔE_residual_curvature),
    # the QUADRATIC term is negligible and the quartic-leading model
    #     ΔE(α) ≈ −α·R² + (γ/24)·α⁴
    # fits with constant γ. Solve dE/dα = 0 →
    #     α* = (6R²/γ)^(1/3),     ΔE_to_min = −α*·R²·(3/4)
    # The factor 3/4 is the standard "energy at quartic minimum" identity.
    println("--- (b3) Quartic-leading landscape fit ---")
    println("    Fit ΔE(α) = −α·R² + (γ/24)·α⁴ from the smallest-α samples")
    γ_fits = Float64[]
    for α in [1e-3, 1e-4, 1e-5]
        psi_step = psi_cpu .- α .* proj_cpu
        psi_step ./= sqrt(sum(abs2, psi_step) * dV)
        copyto!(ws.state.psi, psi_step)
        ΔE = SpinorBEC.energy_decomposition(ws).total - E0
        γ = 24 * (ΔE + α * R²) / α^4
        push!(γ_fits, γ)
        @printf "  α=%.0e  →  γ_fit = %.4e\n" α γ
    end
    γ_avg = (γ_fits[end - 1] + γ_fits[end]) / 2   # smallest-α average (most reliable)
    α_star = (6 * R² / γ_avg)^(1/3)
    ΔE_to_min = -α_star * R² * 3 / 4   # ΔE at quartic minimum
    @printf "\n  γ (smallest-α avg)   = %.4e\n" γ_avg
    @printf "  α* (Newton-like)     = %.4e\n" α_star
    @printf "  ΔE_to_min (quartic)  = %.4e\n" ΔE_to_min
    @printf "  basin threshold      = %.4e\n\n" -BASIN_THRESHOLD

    cosmetic_b = abs(ΔE_to_min) < BASIN_THRESHOLD
    println(
        "(b) Verdict: ",
        if cosmetic_b
            @sprintf("COSMETIC — |ΔE_to_min| = %.2e < basin %.2e (quartic-soft-mode signature)",
            abs(ΔE_to_min), BASIN_THRESHOLD)
        else
            @sprintf("LOAD-BEARING — |ΔE_to_min| = %.2e ≥ basin %.2e",
            abs(ΔE_to_min), BASIN_THRESHOLD)
        end,
    )
    println()

    # Restore ws for any downstream use.
    copyto!(ws.state.psi, psi_cached)

    # --- Combined ---
    println("=== Combined verdict ===")
    if cosmetic_a && cosmetic_b
        println("BOTH cosmetic → Sobolev-consistent LBFGS stopping is JUSTIFIED.")
        println("    The 0.218 L² residual is high-k AND energetically irrelevant.")
    elseif !cosmetic_a && cosmetic_b
        println("ENERGETICALLY COSMETIC at PHYSICAL k → near-Goldstone soft mode.")
        println("    The residual lives at the same |k| as ψ (not high-k noise),")
        println("    but the energy landscape along it is QUARTIC-leading — the")
        println("    quadratic curvature is essentially zero. ΔE_to_min ≪ basin")
        println("    threshold by many orders. Sobolev stop ALONE will not help")
        println("    (the direction is not high-k). The correct response:")
        println("    1. Use an energy-based LBFGS stopping rule (ΔE per step <")
        println("       1e-5 ≈ basin/1000) instead of L²-residual.")
        println("    2. Accept that LBFGS terminates in the soft-mode manifold;")
        println("       any state within ΔE_to_min of E_0 is the same physical GS.")
        println("    3. For comparing multiple candidates, use ΔE between")
        println("       candidates, not within-candidate residuals.")
    elseif !cosmetic_a && !cosmetic_b
        println("BOTH load-bearing → Sobolev metric change would be moving goalposts.")
        println("    Need actual descent: sobolev_alpha>0 in BOTH step and stopping,")
        println("    or switch optimizer (CG / projected-gradient flow).")
    else
        println("MIXED — residual is high-k but locally curved (ΔE_to_min ≳ basin).")
        println("    Sobolev stop alone may hide a load-bearing direction. Investigate.")
    end
end

main()
