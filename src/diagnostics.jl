# --- Elliptic integral (AGM algorithm) ---

function _elliptic_k(m::Float64)
    0.0 <= m < 1.0 || throw(DomainError(m, "K(m) requires 0 ≤ m < 1"))
    a = 1.0
    b = sqrt(1.0 - m)
    while abs(a - b) > eps(a)
        a, b = (a + b) / 2, sqrt(a * b)
    end
    π / (2a)
end

# --- Step 0: Spin mixing oscillation period ---

function _spin_mixing_period_core(ac1::Float64, q::Float64)
    ac1 > 0 || throw(ArgumentError("c1_tilde must be nonzero"))
    ratio = q / ac1
    0.0 <= ratio < 1.0 || throw(DomainError(ratio, "q/|c̃₁| must be in [0, 1)"))
    2.0 / ac1 * _elliptic_k(ratio)
end

spin_mixing_period(c1_tilde::Float64, q::Float64) = _spin_mixing_period_core(abs(c1_tilde), q)

spin_mixing_period_si(c1_tilde_si::Float64, q_si::Float64) = Units.HBAR * _spin_mixing_period_core(abs(c1_tilde_si), q_si)

function quadratic_zeeman_from_field(g_F::Float64, B::Float64, Delta_E_hf::Float64)
    Delta_E_hf > 0 || throw(ArgumentError("Delta_E_hf must be positive"))
    (g_F * Units.MU_BOHR * B)^2 / Delta_E_hf
end

"""
    compute_quadratic_zeeman(atom, B) → Float64

Quadratic Zeeman q = (g_F μ_B B)² / ΔE_hf in SI units (J).
Throws if `Delta_E_hf` is zero (unknown).
"""
function compute_quadratic_zeeman(atom::AtomSpecies, B::Float64)
    atom.Delta_E_hf > 0 || throw(ArgumentError(
        "Delta_E_hf unknown for $(atom.name); set it or use quadratic_zeeman_from_field directly"))
    quadratic_zeeman_from_field(atom.g_F, B, atom.Delta_E_hf)
end

"""
    compute_quadratic_zeeman_dimless(atom, B, omega_ref) → Float64

Dimensionless q = (g_F μ_B B)² / (ΔE_hf · ℏω).
"""
function compute_quadratic_zeeman_dimless(atom::AtomSpecies, B::Float64, omega_ref::Float64)
    compute_quadratic_zeeman(atom, B) / (Units.HBAR * omega_ref)
end

# --- Step 1: Healing lengths (SI) ---

function healing_length_contact(mass::Float64, c0_density::Float64, n::Float64)
    mass > 0 || throw(ArgumentError("mass must be positive"))
    c0_density > 0 || throw(ArgumentError("c0_density must be positive"))
    n > 0 || throw(ArgumentError("n must be positive"))
    Units.HBAR / sqrt(2 * mass * c0_density * n)
end

function healing_length_spin(mass::Float64, c1_density::Float64, n::Float64)
    mass > 0 || throw(ArgumentError("mass must be positive"))
    c1_density != 0 || throw(ArgumentError("c1_density must be nonzero"))
    n > 0 || throw(ArgumentError("n must be positive"))
    Units.HBAR / sqrt(2 * mass * abs(c1_density) * n)
end

function healing_length_ddi(mass::Float64, C_dd::Float64, n::Float64)
    mass > 0 || throw(ArgumentError("mass must be positive"))
    C_dd > 0 || throw(ArgumentError("C_dd must be positive"))
    n > 0 || throw(ArgumentError("n must be positive"))
    Units.HBAR / sqrt(2 * mass * C_dd * n)
end

# --- Step 1: Thomas-Fermi radius extraction ---

function thomas_fermi_radius(density::AbstractVector{<:Real}, x::AbstractVector{<:Real})
    length(density) == length(x) || throw(DimensionMismatch("density and x must have same length"))
    n_max = maximum(density)
    n_max > 0 || return 0.0
    half_max = n_max / 2
    r_max = 0.0
    for i in eachindex(density)
        if density[i] >= half_max
            r_max = max(r_max, abs(x[i]))
        end
    end
    r_max
end

function thomas_fermi_radius_harmonic(mu::Float64, omega::Float64)
    mu > 0 || throw(ArgumentError("mu must be positive"))
    omega > 0 || throw(ArgumentError("omega must be positive"))
    sqrt(2 * mu / omega^2)
end

# --- Step 1: Phase diagram coordinates ---

function phase_diagram_point(; R_TF::Float64, mass::Float64,
                              c1_density::Float64, n::Float64, C_dd::Float64)
    xi_sp = healing_length_spin(mass, c1_density, n)
    xi_dd = healing_length_ddi(mass, C_dd, n)
    (R_TF_over_xi_sp = R_TF / xi_sp,
     R_TF_over_xi_dd = R_TF / xi_dd,
     xi_sp = xi_sp,
     xi_dd = xi_dd,
     R_TF = R_TF)
end

# --- Conservation monitoring ---

"""
    make_conservation_monitor(ws; track_Jz=false) → (callback, data)

Create a callback for `run_simulation!` or `run_simulation_yoshida!` that records
conserved quantities at each save point.

Returns a `(callback, data)` tuple where `data` is a mutable named tuple holder.
After simulation completes, `data` contains:
- `t`: time stamps
- `E`: total energy
- `N`: total norm
- `Sz`: magnetization ⟨Fz⟩
- `Jz`: total angular momentum (only if `track_Jz=true`, requires 2D+)

Usage:
    cb, mon = make_conservation_monitor(ws)
    run_simulation!(ws; callback=cb)
    # mon.t, mon.E, mon.N, mon.Sz now contain time series
"""
function make_conservation_monitor(ws::Workspace{N}; track_Jz::Bool=false) where {N}
    sys = ws.spin_matrices.system
    grid = ws.grid
    plans = ws.fft_plans

    data = (
        t = Float64[],
        E = Float64[],
        N = Float64[],
        Sz = Float64[],
        Jz = Float64[],
    )

    function callback(ws_cb, step)
        push!(data.t, ws_cb.state.t)
        push!(data.E, total_energy(ws_cb))
        push!(data.N, total_norm(ws_cb.state.psi, grid))
        push!(data.Sz, magnetization(ws_cb.state.psi, grid, sys))
        if track_Jz && N >= 2
            push!(data.Jz, total_angular_momentum(ws_cb.state.psi, grid, plans, sys))
        end
    end

    (callback, data)
end

# --- Probe A: Component populations ---

"""
    classify_phase(psi, F, grid, sm) → NamedTuple

Compute order parameters and classify the spinor phase.

Returns `(spin_order, nematic_order, channel_weights, phase, magnetization_density)`.
"""
function classify_phase(psi::AbstractArray{ComplexF64}, F::Int, grid::Grid{N},
                        sm::SpinMatrices) where {N}
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)
    sys = sm.system

    n_total = total_density(psi, N)
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(n_total .^ 2) * dV
    n_sum < 1e-30 && return (spin_order=0.0, nematic_order=0.0,
        channel_weights=Dict{Int,Float64}(), phase=:vacuum, magnetization_density=0.0)

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int,Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)

    Mz = magnetization(psi, grid, sys) / n_sum

    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    (spin_order=spin_order, nematic_order=nematic_order,
     channel_weights=cw_norm, phase=phase, magnetization_density=Mz)
end

function _density_weighted_mean(field, density, dV)
    w = density .^ 2
    w_sum = sum(w) * dV
    w_sum < 1e-30 && return 0.0
    sum(field .* w) * dV / w_sum
end

function _majorana_star_entropy(spinor::AbstractVector{ComplexF64}, F::Int)
    F < 1 && return 0.0
    stars = majorana_stars(spinor, F)
    points = [_stereo_to_sphere(z) for z in stars]
    n_stars = length(points)
    n_stars == 0 && return 0.0

    n_bins = max(6, n_stars)
    cos_edges = range(-1.0, 1.0, length=n_bins + 1)
    counts = zeros(Float64, n_bins)
    for p in points
        cos_theta = clamp(p[3], -1.0, 1.0)
        bin = min(searchsortedlast(cos_edges, cos_theta), n_bins)
        bin = max(bin, 1)
        counts[bin] += 1.0
    end
    counts ./= n_stars
    S = 0.0
    for p in counts
        p > 0 && (S -= p * log(p))
    end
    S / log(n_bins)
end

function _mean_majorana_entropy(psi, F::Int, ndim::Int, n_total, dV;
                                density_cutoff::Float64=1e-10,
                                sampling::Float64=1.0)
    D = 2F + 1
    n_pts = ntuple(d -> size(psi, d), ndim)
    all_indices = vec(collect(CartesianIndices(n_pts)))
    indices = if sampling < 1.0
        rng = Random.MersenneTwister(0)
        n_sample = max(1, round(Int, length(all_indices) * sampling))
        perm = Random.randperm(rng, length(all_indices))
        all_indices[perm[1:n_sample]]
    else
        all_indices
    end
    w_sum = 0.0
    s_sum = 0.0
    @inbounds for I in indices
        ni = n_total[I]
        ni > density_cutoff || continue
        spinor = Vector{ComplexF64}(undef, D)
        norm_sq = 0.0
        for c in 1:D
            spinor[c] = psi[I, c]
            norm_sq += abs2(psi[I, c])
        end
        inv_norm = 1.0 / sqrt(norm_sq)
        spinor .*= inv_norm
        w = ni^2
        s_sum += w * _majorana_star_entropy(spinor, F)
        w_sum += w
    end
    w_sum < 1e-30 && return 0.0
    s_sum / w_sum
end

function _label_phase(spin_order, nematic_order, channel_weights, F)
    if spin_order > 0.9
        :ferromagnetic
    elseif nematic_order > 0.9
        F == 1 ? :polar : :nematic
    elseif get(channel_weights, 2F, 0.0) > 0.5
        :cyclic
    else
        :mixed
    end
end

"""
    classify_phase_detailed(psi, F, grid, sm) → NamedTuple

Extended phase classification with continuous order parameters.

Returns `(spin_order, nematic_order, biaxiality, Q6, star_entropy,
          channel_weights, magnetization_density, phase)`.
"""
function classify_phase_detailed(psi::AbstractArray{ComplexF64}, F::Int, grid::Grid{N},
                                 sm::SpinMatrices; sampling::Float64=1.0) where {N}
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)

    n_total = total_density(psi, N)
    n_sum = sum(n_total) * dV
    n_sq_sum = sum(n_total .^ 2) * dV
    if n_sum < 1e-30
        return (spin_order=0.0, nematic_order=0.0, biaxiality=0.0,
                Q6=0.0, star_entropy=0.0,
                channel_weights=Dict{Int,Float64}(), magnetization_density=0.0,
                phase=:vacuum, point_group=:trivial)
    end

    fx, fy, fz = spin_density_vector(psi, sm, N)
    f_mag_sq_sum = sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    spin_order = f_mag_sq_sum / (Float64(F)^2 * n_sq_sum)

    spec = pair_amplitude_spectrum(psi, F, grid)
    total_weight = sum(values(spec.channel_weights))
    cw_norm = Dict{Int,Float64}()
    for (S, w) in spec.channel_weights
        cw_norm[S] = total_weight > 0 ? w / total_weight : 0.0
    end

    nematic_order = get(spec.channel_weights, 0, 0.0) / (n_sq_sum / D)

    l1, l2, l3 = nematic_tensor_eigenvalues(psi, sm, N)
    biax = biaxiality_parameter(l1, l2, l3)
    mean_biax = _density_weighted_mean(biax, n_total, dV)

    Q6_field = icosahedral_order_parameter(psi, grid, sm; sampling)
    mean_Q6 = _density_weighted_mean(Q6_field, n_total, dV)

    star_entropy = _mean_majorana_entropy(psi, F, N, n_total, dV; sampling)

    sys = sm.system
    Mz = magnetization(psi, grid, sys) / n_sum

    phase = _label_phase(spin_order, nematic_order, cw_norm, F)

    pg = _peak_point_group(psi, F, N, n_total, dV)

    (spin_order=spin_order, nematic_order=nematic_order, biaxiality=mean_biax,
     Q6=mean_Q6, star_entropy=star_entropy,
     channel_weights=cw_norm, magnetization_density=Mz, phase=phase,
     point_group=pg)
end

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
    kinetic_phase_half = prepare_kinetic_phase(ws.grid, dt_half;
        imaginary_time=ws.sim_params.imaginary_time)
    bk_half = _make_batched_kinetic_cache(ws.state.psi, kinetic_phase_half, N)
    sp_half = SimParams(dt_half, ws.sim_params.n_steps, ws.sim_params.imaginary_time,
                        ws.sim_params.normalize_every, ws.sim_params.save_every)
    ws_half = Workspace(
        ws.state, ws.fft_plans, kinetic_phase_half, ws.potential_values, ws.density_buf,
        ws.spin_matrices, ws.grid, ws.atom, ws.interactions,
        ws.zeeman, ws.potential, sp_half, ws.ddi, ws.ddi_bufs, ws.raman, ws.loss,
        ws.ddi_padded, bk_half, ws.tensor_cache, ws.coriolis_cache,
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
function validate_conservation(ws::Workspace{N}; n_steps::Int=100,
    tol_norm::Float64=1e-12, tol_energy::Float64=1e-3,
    tol_magnetization::Float64=1e-6,
    track_Jz::Bool=false, tol_Jz::Float64=1e-3,
) where {N}
    psi_save = copy(ws.state.psi)
    t_save, step_save = ws.state.t, ws.state.step

    sys = ws.spin_matrices.system
    grid = ws.grid
    plans = ws.fft_plans

    N0 = total_norm(ws.state.psi, grid)
    E0 = total_energy(ws)
    M0 = magnetization(ws.state.psi, grid, sys)
    Jz0 = (track_Jz && N >= 2) ? total_angular_momentum(ws.state.psi, grid, plans, sys) : NaN

    for _ in 1:n_steps
        split_step!(ws)
    end

    N1 = total_norm(ws.state.psi, grid)
    E1 = total_energy(ws)
    M1 = magnetization(ws.state.psi, grid, sys)
    Jz1 = (track_Jz && N >= 2) ? total_angular_momentum(ws.state.psi, grid, plans, sys) : NaN

    copyto!(ws.state.psi, psi_save)
    ws.state.t = t_save
    ws.state.step = step_save

    norm_drift = abs(N1 - N0) / max(N0, 1e-30)
    energy_drift = abs(E1 - E0) / max(abs(E0), 1e-30)
    mag_drift = abs(M1 - M0) / max(abs(M0), 1e-10)
    Jz_drift = (track_Jz && N >= 2) ? abs(Jz1 - Jz0) / max(abs(Jz0), 1e-10) : NaN

    passed = norm_drift < tol_norm && energy_drift < tol_energy &&
             mag_drift < tol_magnetization
    if track_Jz && N >= 2
        passed = passed && Jz_drift < tol_Jz
    end

    (passed=passed, norm_drift=norm_drift, energy_drift=energy_drift,
     magnetization_drift=mag_drift, Jz_drift=Jz_drift)
end

"""
    power_spectrum(times, signal; window=:hanning, pad_factor=1) → NamedTuple

Compute power spectrum of a uniformly-sampled signal.
Returns `(frequencies, power)` using rfft. Applies windowing to reduce spectral leakage.
"""
function power_spectrum(times::Vector{Float64}, signal::Vector{Float64};
                        window::Symbol=:hanning, pad_factor::Int=1)
    N_sig = length(times)
    length(signal) == N_sig || throw(DimensionMismatch("times and signal must have same length"))
    N_sig >= 2 || throw(ArgumentError("need at least 2 samples"))
    pad_factor >= 1 || throw(ArgumentError("pad_factor must be >= 1"))

    dt = times[2] - times[1]
    dt > 0 || throw(ArgumentError("times must be increasing"))

    max_dt_var = maximum(abs(times[i+1] - times[i] - dt) for i in 1:N_sig-1)
    max_dt_var / dt < 1e-6 || throw(ArgumentError(
        "times must be uniformly spaced (max variation = $(max_dt_var))"))

    w = if window === :hanning
        _hanning_window(N_sig)
    elseif window === :hamming
        _hamming_window(N_sig)
    elseif window === :none
        ones(Float64, N_sig)
    else
        throw(ArgumentError("Unknown window: $window. Use :hanning, :hamming, or :none"))
    end

    windowed = signal .* w
    w_norm = sqrt(sum(abs2, w) / N_sig)

    n_pad = N_sig * pad_factor
    padded = zeros(Float64, n_pad)
    padded[1:N_sig] .= windowed

    spectrum = FFTW.rfft(padded)
    power = abs2.(spectrum) ./ (w_norm^2 * N_sig^2)

    freqs = FFTW.rfftfreq(n_pad, 1.0 / dt)

    (frequencies=collect(freqs), power=collect(power))
end

function _hanning_window(N::Int)
    [0.5 * (1 - cos(2π * i / (N - 1))) for i in 0:N-1]
end

function _hamming_window(N::Int)
    [0.54 - 0.46 * cos(2π * i / (N - 1)) for i in 0:N-1]
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
function analyze_stability(ws::Workspace{N};
    perturbation::Float64=1e-4,
    n_steps::Int=500,
    sample_every::Int=10,
    seed::Int=42,
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

    for step in 1:n_steps
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

    (growth_rate=growth_rate, unstable=growth_rate > 0.01,
     k_peak=k_peak, time_series=time_series, sk_series=sk_series)
end

function _estimate_growth_rate(time_series::Vector{Float64}, dt_sample::Float64)
    n = length(time_series)
    n < 2 && return 0.0
    log_vals = [v > 0 ? log(v) : -50.0 for v in time_series]
    t_vals = [(i - 1) * dt_sample for i in 1:n]

    t_mean = sum(t_vals) / n
    y_mean = sum(log_vals) / n
    num = sum((t_vals[i] - t_mean) * (log_vals[i] - y_mean) for i in 1:n)
    den = sum((t_vals[i] - t_mean)^2 for i in 1:n)
    den < 1e-30 && return 0.0
    num / den
end

function _find_peak_k(sk::AbstractArray{Float64}, grid::Grid{N}) where {N}
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

function component_populations(psi::AbstractArray{ComplexF64}, grid::Grid{N},
                                sys::SpinSystem) where {N}
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)
    pops = Vector{Float64}(undef, sys.n_components)
    for c in 1:sys.n_components
        idx = _component_slice(N, n_pts, c)
        pops[c] = sum(abs2, view(psi, idx...)) * dV
    end
    total = sum(pops)
    if total > 0
        pops ./= total
    end
    (populations = pops, m_values = copy(sys.m_values))
end
