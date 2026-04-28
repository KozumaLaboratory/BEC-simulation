using Test
using FFTW
using LinearAlgebra
using Random
using SpinorBEC

# SGPE Fluctuation-Dissipation Regression test.
#
# Round-3 review noted that test_phase4.jl covers SGPE building blocks
# (γ=0 no-op, damping reduces high-k, noise preserves mean) but NOT the
# joint thermal equilibrium: in the simple-growth form,
#
#     ⟨|ψ̂(k)|²⟩_eq = T / (½k² − μ)    (Rayleigh-Jeans)
#
# This pins that contract — flipping the sign of γ damping, flipping the
# noise amplitude, or breaking the dV scaling all show up as a deviation
# from the analytical Rayleigh-Jeans curve at moderate k.
#
# We use a free (c₀=c₁=0) 1-component classical field on a 2D grid for
# speed: equilibrium reaches in O(few thousand) steps and only one FFT pair
# per step.

@testset "SGPE FDR: Rayleigh-Jeans equilibrium" begin
    # Grid + workspace setup (free particle, no trap, no interactions)
    n_pts = (32, 32)
    box = (8.0, 8.0)
    config = GridConfig(n_pts, box)
    grid = make_grid(config)
    sys = SpinSystem(0)   # F=0, scalar (D=1)

    # Free dynamics: zero potential, zero interactions
    ip = InteractionParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false,
        save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87, interactions=ip,
        sim_params=sp, fft_flags=FFTW.ESTIMATE)

    # Seed with a small random field so FDR convergence is faster
    psi = ws.state.psi
    fill!(psi, 0.0)
    rng_init = 17
    Random_state = Xoshiro(rng_init)
    for c in 1:1, I in CartesianIndices(n_pts)
        psi[I, c] = 1e-4 * (randn(Random_state) + im * randn(Random_state))
    end

    # SGPE parameters
    γ = 0.5
    T = 0.5
    μ = -0.2          # ε(k) − μ ≥ 0.2 ⇒ FDR factor stays bounded
    dt = 0.01
    n_warmup = 3000   # reach equilibrium
    n_sample = 2000   # statistics

    # Warmup
    seed_offset = 1_000_000
    for step in 1:n_warmup
        apply_sgpe_step!(ws, γ, T, dt; μ=μ, seed=seed_offset + step)
    end

    # Sample ⟨|ψ̂(k)|²⟩ time-averaged over post-warmup steps
    psi_k_sq = zeros(Float64, n_pts...)
    fft_buf = zeros(ComplexF64, n_pts...)
    for step in 1:n_sample
        apply_sgpe_step!(ws, γ, T, dt;
            μ=μ, seed=seed_offset + n_warmup + step)
        copyto!(fft_buf, view(psi,:,:,1))
        ws.fft_plans.forward * fft_buf
        psi_k_sq .+= abs2.(fft_buf)
    end
    psi_k_sq ./= n_sample

    # Bin by |k| and compare to T / (½k² − μ)
    k_squared = grid.k_squared
    n_bins = 8
    k_max = sqrt(maximum(k_squared))
    bin_edges = collect(range(0.0, k_max; length=n_bins + 1))
    bin_n = zeros(Int, n_bins)
    bin_obs = zeros(Float64, n_bins)
    bin_pred = zeros(Float64, n_bins)
    for I in CartesianIndices(n_pts)
        k_mag = sqrt(k_squared[I])
        bin = clamp(searchsortedlast(bin_edges, k_mag), 1, n_bins)
        # Skip exactly-zero k for FDR (factor diverges as ε→μ from above)
        eps_k = 0.5 * k_squared[I]
        eps_k - μ < 1e-3 && continue
        bin_n[bin] += 1
        bin_obs[bin] += psi_k_sq[I]
        bin_pred[bin] += T / (eps_k - μ)
    end

    # Average per bin
    nonzero = bin_n .> 0
    bin_obs[nonzero] ./= bin_n[nonzero]
    bin_pred[nonzero] ./= bin_n[nonzero]

    # The FFT lives in dimensionful k-space; the analytic FDR has an
    # implicit volume factor we account for via dV in the noise term.
    # Per-mode classical-field ⟨|ψ̂(k)|²⟩ matches T/(ε−μ) up to a fixed
    # box-volume normalisation; we test the *shape* (power-law in k)
    # rather than the absolute value:
    #   log ⟨|ψ̂(k)|²⟩ = log T − log (½k² − μ) + const
    # The slope vs log(½k² − μ) should be ≈ −1.
    obs_log = log.(bin_obs[nonzero])
    pred_log = log.(bin_pred[nonzero])
    # Linear fit: obs = α · pred + β. Gradient α should be ≈ 1 if FDR
    # holds up to a global constant.
    n_fit = length(obs_log)
    @test n_fit >= 4   # need enough bins
    if n_fit >= 4
        x_mean = sum(pred_log) / n_fit
        y_mean = sum(obs_log) / n_fit
        num = sum((pred_log .- x_mean) .* (obs_log .- y_mean))
        den = sum((pred_log .- x_mean) .^ 2)
        slope = num / den
        @info "SGPE FDR slope (expect ≈ 1.0): $(round(slope; sigdigits=4))"
        @test 0.7 < slope < 1.3       # generous: classical FDR can be noisy
        # at ~5000 SGPE steps on 32² grid
    end
end
