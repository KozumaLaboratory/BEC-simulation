# --- Elliptic integral (AGM algorithm) ---

export spin_mixing_period, spin_mixing_period_si
export quadratic_zeeman_si, quadratic_zeeman_dimless_si
export healing_length_contact, healing_length_spin, healing_length_ddi
export thomas_fermi_radius, thomas_fermi_radius_harmonic
export phase_diagram_point, component_populations, make_conservation_monitor
export power_spectrum

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

spin_mixing_period_si(c1_tilde_si::Float64, q_si::Float64) =
    Units.HBAR * _spin_mixing_period_core(abs(c1_tilde_si), q_si)

"""
    quadratic_zeeman_si(atom, B_tesla) → Float64 (J)

Rigorous quadratic Zeeman shift coefficient `q` in SI (joules) from
2nd-order perturbation theory:

    q = (g_J μ_B B)² · q_geometry / |ΔE_hf|

Uses the per-atom `g_J` and `q_geometry` (closed-form 6j × Clebsch²)
rather than the naive `(g_F μ_B B)² / ΔE_hf` form, which is incorrect
by a factor (g_J/g_F)² · q_geometry — for Eu-151 F=6 this is ~0.71×
(35/144 / (g_F/g_J)² ≈ 0.243 · 2.94 = 0.715), so the naive form
overestimates q by ~40%.

Throws if any of `Delta_E_hf`, `g_J`, `q_geometry` is missing on the
atom. Bosonic isotopes (I=0, Delta_E_hf=0) return 0.
"""
function quadratic_zeeman_si(atom::AtomSpecies, B_tesla::Float64)
    atom.Delta_E_hf > 0 || return 0.0
    (atom.g_J > 0 && atom.q_geometry > 0) || throw(
        ArgumentError(
            "atom $(atom.name): missing g_J or q_geometry; cannot compute q. " *
            "Fill in src/workflow/initialization/atoms.jl."),
    )
    (atom.g_J * Units.MU_BOHR * B_tesla)^2 * atom.q_geometry / atom.Delta_E_hf
end

"""
    quadratic_zeeman_dimless_si(atom, B_tesla, omega_ref) → Float64

Dimensionless q (= q_SI / (ℏ ω_ref)) for a given physical B in Tesla.
"""
function quadratic_zeeman_dimless_si(atom::AtomSpecies, B_tesla::Float64, omega_ref::Float64)
    quadratic_zeeman_si(atom, B_tesla) / (Units.HBAR * omega_ref)
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
    length(density) == length(x) ||
        throw(DimensionMismatch("density and x must have same length"))
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

function phase_diagram_point(;
    R_TF::Float64,
    mass::Float64,
    c1_density::Float64,
    n::Float64,
    C_dd::Float64,
)
    xi_sp = healing_length_spin(mass, c1_density, n)
    xi_dd = healing_length_ddi(mass, C_dd, n)
    (
        R_TF_over_xi_sp=R_TF / xi_sp,
        R_TF_over_xi_dd=R_TF / xi_dd,
        xi_sp=xi_sp,
        xi_dd=xi_dd,
        R_TF=R_TF,
    )
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
    run_simulation!(ws; callbacks=SimulationCallbacks(on_snapshot=cb))
    # mon.t, mon.E, mon.N, mon.Sz now contain time series
"""
function make_conservation_monitor(ws::Workspace{N}; track_Jz::Bool=false) where {N}
    sys = ws.spin_matrices.system
    grid = ws.grid
    plans = ws.fft_plans

    data = (t=Float64[], E=Float64[], N=Float64[], Sz=Float64[], Jz=Float64[])

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

function component_populations(
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    sys::SpinSystem,
) where {N}
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), N)
    pops = Vector{Float64}(undef, sys.n_components)
    for c in 1:(sys.n_components)
        idx = _component_slice(N, n_pts, c)
        pops[c] = sum(abs2, view(psi, idx...)) * dV
    end
    total = sum(pops)
    if total > 0
        pops ./= total
    end
    (populations=pops, m_values=copy(sys.m_values))
end

"""
    power_spectrum(times, signal; window=:hanning, pad_factor=1) → NamedTuple

Compute power spectrum of a uniformly-sampled signal.
Returns `(frequencies, power)` using rfft. Applies windowing to reduce spectral leakage.
"""
function power_spectrum(
    times::Vector{Float64},
    signal::Vector{Float64};
    window::Symbol=:hanning,
    pad_factor::Int=1,
)
    N_sig = length(times)
    length(signal) == N_sig ||
        throw(DimensionMismatch("times and signal must have same length"))
    N_sig >= 2 || throw(ArgumentError("need at least 2 samples"))
    pad_factor >= 1 || throw(ArgumentError("pad_factor must be >= 1"))

    dt = times[2] - times[1]
    dt > 0 || throw(ArgumentError("times must be increasing"))

    max_dt_var = maximum(abs(times[i + 1] - times[i] - dt) for i in 1:(N_sig - 1))
    max_dt_var / dt < 1e-6 || throw(
        ArgumentError("times must be uniformly spaced (max variation = $(max_dt_var))")
    )

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
    [0.5 * (1 - cos(2π * i / (N - 1))) for i in 0:(N - 1)]
end

function _hamming_window(N::Int)
    [0.54 - 0.46 * cos(2π * i / (N - 1)) for i in 0:(N - 1)]
end
