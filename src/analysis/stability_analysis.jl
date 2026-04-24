"""
    estimate_splitting_error(ws) → Float64

Richardson extrapolation error estimate: compare 1 step of dt vs 2 steps of dt/2.
Returns ||ψ₁ - ψ₂||∞ / ||ψ||∞, an O(dt²) error estimate.
"""
function estimate_splitting_error(ws::Workspace{N}) where {N}
    psi_save = copy(ws.state.psi)
    t_save = ws.state.t
    step_save = ws.state.step
    psi_norm = maximum(abs, psi_save)

    split_step!(ws)
    psi_full = copy(ws.state.psi)

    copyto!(ws.state.psi, psi_save)
    ws.state.t = t_save
    ws.state.step = step_save

    dt_half = ws.sim_params.dt / 2
    kinetic_phase_half = prepare_kinetic_phase(
        ws.grid,
        dt_half;
        imaginary_time = ws.sim_params.imaginary_time,
    )
    bk_half = _make_batched_kinetic_cache(ws.state.psi, kinetic_phase_half, N)
    sp_half = SimParams(
        dt_half,
        ws.sim_params.n_steps,
        ws.sim_params.imaginary_time,
        ws.sim_params.normalize_every,
        ws.sim_params.save_every,
    )
    ws_half = _rebuild_workspace(ws;
        kinetic_phase=kinetic_phase_half,
        sim_params=sp_half,
        batched_kinetic=bk_half,
    )

    split_step!(ws_half)
    split_step!(ws_half)
    psi_half = copy(ws_half.state.psi)

    copyto!(ws.state.psi, psi_save)
    ws.state.t = t_save
    ws.state.step = step_save

    maximum(abs, psi_full .- psi_half) / psi_norm
end

"""
    validate_conservation(ws; n_steps=100, tol_norm=1e-12, tol_energy=1e-3,
                          tol_magnetization=1e-6) → NamedTuple

Run a short simulation and check conservation laws.
Returns `(passed, norm_drift, energy_drift, magnetization_drift)`.
Restores the workspace state after validation.
"""
function validate_conservation(
    ws::Workspace{N};
    n_steps::Int = 100,
    tol_norm::Float64 = 1e-12,
    tol_energy::Float64 = 1e-3,
    tol_magnetization::Float64 = 1e-6,
    track_Jz::Bool = false,
    tol_Jz::Float64 = 1e-3,
) where {N}
    psi_save = copy(ws.state.psi)
    t_save, step_save = ws.state.t, ws.state.step

    sys = ws.spin_matrices.system
    grid = ws.grid
    plans = ws.fft_plans

    N0 = total_norm(ws.state.psi, grid)
    E0 = total_energy(ws)
    M0 = magnetization(ws.state.psi, grid, sys)
    Jz0 =
        (track_Jz && N >= 2) ? total_angular_momentum(ws.state.psi, grid, plans, sys) : NaN

    for _ = 1:n_steps
        split_step!(ws)
    end

    N1 = total_norm(ws.state.psi, grid)
    E1 = total_energy(ws)
    M1 = magnetization(ws.state.psi, grid, sys)
    Jz1 =
        (track_Jz && N >= 2) ? total_angular_momentum(ws.state.psi, grid, plans, sys) : NaN

    copyto!(ws.state.psi, psi_save)
    ws.state.t = t_save
    ws.state.step = step_save

    norm_drift = abs(N1 - N0) / max(N0, 1e-30)
    energy_drift = abs(E1 - E0) / max(abs(E0), 1e-30)
    mag_drift = abs(M1 - M0) / max(abs(M0), 1e-10)
    Jz_drift = (track_Jz && N >= 2) ? abs(Jz1 - Jz0) / max(abs(Jz0), 1e-10) : NaN

    passed =
        norm_drift < tol_norm && energy_drift < tol_energy && mag_drift < tol_magnetization
    if track_Jz && N >= 2
        passed = passed && Jz_drift < tol_Jz
    end

    (
        passed = passed,
        norm_drift = norm_drift,
        energy_drift = energy_drift,
        magnetization_drift = mag_drift,
        Jz_drift = Jz_drift,
    )
end

"""
    analyze_stability(ws; perturbation=1e-4, n_steps=500, sample_every=10, seed=42) → NamedTuple

Perturb-and-evolve dynamic instability analysis.

Adds a small random perturbation to the current state, evolves for `n_steps`,
and tracks growth of the perturbation and structure factor. Restores the original
state after analysis.

Returns `(growth_rate, unstable, k_peak, time_series, sk_series)` where:
- `growth_rate`: estimated exponential growth rate from log-linear fit
- `unstable`: true if growth_rate > threshold
- `k_peak`: peak wavenumber from final structure factor (excluding k=0)
- `time_series`: vector of perturbation norms δ(t)
- `sk_series`: vector of structure factor snapshots S(k,t)
"""
function analyze_stability(
    ws::Workspace{N};
    perturbation::Float64 = 1e-4,
    n_steps::Int = 500,
    sample_every::Int = 10,
    seed::Int = 42,
) where {N}
    psi_save = copy(ws.state.psi)
    t_save = ws.state.t
    step_save = ws.state.step

    rng = Random.MersenneTwister(seed)
    noise = randn(rng, ComplexF64, size(ws.state.psi)) .* perturbation
    ws.state.psi .+= noise
    psi_norm = sqrt(sum(abs2, ws.state.psi) * cell_volume(ws.grid))
    ws.state.psi ./= psi_norm

    time_series = Float64[]
    sk_series = Array{Float64}[]
    dt = ws.sim_params.dt

    for step = 1:n_steps
        split_step!(ws)
        if step % sample_every == 0
            delta = maximum(abs, ws.state.psi .- psi_save)
            push!(time_series, delta)
            push!(sk_series, structure_factor(ws.state.psi, ws.grid))
        end
    end

    growth_rate = _estimate_growth_rate(time_series, dt * sample_every)
    k_peak = _find_peak_k(sk_series[end], ws.grid)

    copyto!(ws.state.psi, psi_save)
    ws.state.t = t_save
    ws.state.step = step_save

    (
        growth_rate = growth_rate,
        unstable = growth_rate > 0.01,
        k_peak = k_peak,
        time_series = time_series,
        sk_series = sk_series,
    )
end

function _estimate_growth_rate(time_series::Vector{Float64}, dt_sample::Float64)
    n = length(time_series)
    n < 2 && return 0.0
    log_vals = [v > 0 ? log(v) : -50.0 for v in time_series]
    t_vals = [(i - 1) * dt_sample for i = 1:n]

    t_mean = sum(t_vals) / n
    y_mean = sum(log_vals) / n
    num = sum((t_vals[i] - t_mean) * (log_vals[i] - y_mean) for i = 1:n)
    den = sum((t_vals[i] - t_mean)^2 for i = 1:n)
    den < 1e-30 && return 0.0
    num / den
end

function _find_peak_k(sk::AbstractArray{<:AbstractFloat}, grid::Grid{N}) where {N}
    n_pts = size(sk)
    k_sq = grid.k_squared

    max_val = -Inf
    max_k = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        k2 = k_sq[I]
        k2 < 1e-10 && continue
        if sk[I] > max_val
            max_val = sk[I]
            max_k = sqrt(k2)
        end
    end
    max_k
end
