using StaticArrays
using LinearAlgebra
using FFTW

# --- Backend Abstraction ---

abstract type AbstractBackend end

# --- Grid Configuration ---

struct GridConfig{N}
    n_points::NTuple{N,Int}
    box_size::NTuple{N,Float64}

    function GridConfig{N}(n_points::NTuple{N,Int}, box_size::NTuple{N,Float64}) where {N}
        all(n -> n > 0 && iseven(n), n_points) ||
            throw(ArgumentError("n_points must be positive even integers"))
        all(L -> L > 0, box_size) || throw(ArgumentError("box_size must be positive"))
        new{N}(n_points, box_size)
    end
end

GridConfig(n_points::NTuple{N,Int}, box_size::NTuple{N,Float64}) where {N} =
    GridConfig{N}(n_points, box_size)
GridConfig(n_points::Int, box_size::Float64) = GridConfig{1}((n_points,), (box_size,))

spatial_dims(::GridConfig{N}) where {N} = N

# --- Spatial Grid ---

struct Grid{N,T<:AbstractFloat}
    config::GridConfig{N}
    x::NTuple{N,Vector{T}}
    dx::NTuple{N,T}
    k::NTuple{N,Vector{T}}
    dk::NTuple{N,T}
    k_squared::Array{T,N}
end

# Partial-application alias for the common Float64 case. Most call sites
# write `Grid{N}` or `grid::Grid{N}` — with this alias those continue to
# resolve to the concrete `Grid{N,Float64}`, so the precision-parameter
# rollout is backward compatible.
const GridF64{N} = Grid{N,Float64}

# --- Spin System ---

struct SpinSystem
    F::Int
    n_components::Int
    m_values::Vector{Int}
end

function SpinSystem(F::Int)
    F >= 0 || throw(ArgumentError("F must be non-negative"))
    n = 2F + 1
    SpinSystem(F, n, collect(F:-1:(-F)))
end

# --- Spin Matrices ---

struct SpinMatrices{D,M<:SMatrix}
    Fx::M
    Fy::M
    Fz::M
    Fp::M
    Fm::M
    F_dot_F::M
    system::SpinSystem
    Fy_eigvecs::Matrix{ComplexF64}
    Fy_eigvecs_adj::Matrix{ComplexF64}
    Fy_eigvals::SVector{D,Float64}
end

# --- Atom Species ---

"""
    AtomSpecies

Atomic species for spinor BEC simulation.

# Fields
- `name`: human-readable name (e.g. "87Rb")
- `mass`: atomic mass in kg
- `F`: total spin quantum number
- `a0`: F=1: F_tot=0 scattering length (m). F>1: mean s-wave scattering length a_s (m)
         when channel-resolved data is unavailable (e.g. Eu151). Use `a_s` for the
         unambiguous mean scattering length regardless of F.
- `a2`: F_tot=2 scattering length (m). Zero if unknown.
- `a_s`: mean s-wave scattering length (m). For F=1: (a0+2a2)/3. For F>1: same as `a0`.
- `mu_mag`: magnetic dipole moment (J/T). Zero for non-dipolar atoms.
- `g_F`: Landé g-factor
- `scattering_lengths`: Dict{Int,Float64} mapping total spin S => a_S (m).
                         Empty when channel-resolved data is unavailable.
- `Delta_E_hf`: hyperfine splitting (J). Zero if unknown/not applicable.
"""
struct AtomSpecies
    name::String
    mass::Float64
    F::Int
    a0::Float64
    a2::Float64
    a_s::Float64
    mu_mag::Float64
    g_F::Float64
    scattering_lengths::Dict{Int,Float64}
    Delta_E_hf::Float64

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        g_F,
        scattering_lengths;
        Delta_E_hf::Float64 = 0.0,
    )
        a_s = F == 1 ? (a0 + 2a2) / 3 : a0
        new(name, mass, F, a0, a2, a_s, mu_mag, g_F, scattering_lengths, Delta_E_hf)
    end

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        g_F::Real;
        Delta_E_hf::Float64 = 0.0,
    )
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int,Float64}(0 => a0, 2 => a2)
        else
            Dict{Int,Float64}()
        end
        a_s = F == 1 ? (a0 + 2a2) / 3 : a0
        new(name, mass, F, a0, a2, a_s, mu_mag, Float64(g_F), sl, Delta_E_hf)
    end

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        scattering_lengths::Dict;
        Delta_E_hf::Float64 = 0.0,
    )
        a_s = F == 1 ? (a0 + 2a2) / 3 : a0
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, scattering_lengths, Delta_E_hf)
    end

    function AtomSpecies(name, mass, F, a0, a2, mu_mag; Delta_E_hf::Float64 = 0.0)
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int,Float64}(0 => a0, 2 => a2)
        else
            Dict{Int,Float64}()
        end
        a_s = F == 1 ? (a0 + 2a2) / 3 : a0
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, sl, Delta_E_hf)
    end
end

AtomSpecies(name, mass, F, a0, a2) = AtomSpecies(name, mass, F, a0, a2, 0.0)

# --- Interaction Parameters ---

"""
    InteractionParams(c0, c1, [c_lhy], [c_extra])

Contact interaction parameters. `c0` is the density coupling, `c1` the spin coupling.

`c_extra` stores higher-rank couplings: `c_extra[n-1]` = cₙ for n ≥ 2.
Access via `get_cn(ip, n)`. When any even-rank c_extra entry with k ≥ 4 is nonzero,
`make_workspace` builds a `TensorInteractionCache` and zeros c0/c1 (all contact
interactions are then handled by the tensor step).
"""
struct InteractionParams
    c0::Float64
    c1::Float64
    c_lhy::Float64
    c_extra::Vector{Float64}

    InteractionParams(c0::Float64, c1::Float64) = new(c0, c1, 0.0, Float64[])
    InteractionParams(c0::Float64, c1::Float64, c_extra::Vector{Float64}) =
        new(c0, c1, 0.0, c_extra)
    InteractionParams(c0::Float64, c1::Float64, c_lhy::Float64) =
        new(c0, c1, c_lhy, Float64[])
    InteractionParams(c0::Float64, c1::Float64, c_lhy::Float64, c_extra::Vector{Float64}) =
        new(c0, c1, c_lhy, c_extra)
end

function get_cn(ip::InteractionParams, n::Int)
    n == 0 && return ip.c0
    n == 1 && return ip.c1
    idx = n - 1
    idx <= length(ip.c_extra) ? ip.c_extra[idx] : 0.0
end

# --- Zeeman Parameters ---

struct ZeemanParams
    p::Float64      # linear Zeeman (energy)
    q::Float64      # quadratic Zeeman (energy)
end

ZeemanParams() = ZeemanParams(0.0, 0.0)

struct TimeDependentZeeman
    p_wf::Waveform
    q_wf::Waveform
    bx_wf::Union{Nothing,Waveform}
    by_wf::Union{Nothing,Waveform}
end

TimeDependentZeeman(p_wf::Waveform, q_wf::Waveform) =
    TimeDependentZeeman(p_wf, q_wf, nothing, nothing)

TimeDependentZeeman(f::Function) = TimeDependentZeeman(
    FunctionWaveform(t -> f(t).p),
    FunctionWaveform(t -> f(t).q),
    nothing, nothing,
)

# --- Raman Coupling ---

struct RamanCoupling{N}
    Omega_R::Float64          # Rabi frequency
    delta::Float64            # two-photon detuning
    k_eff::NTuple{N,Float64}  # effective wave vector (difference of two beams)
end

struct TimeDependentRaman{N}
    omega_wf::Waveform
    delta_wf::Waveform
    k_eff::NTuple{N,Float64}
end

# --- Potential ---

abstract type AbstractPotential end

struct HarmonicTrap{N} <: AbstractPotential
    omega::NTuple{N,Float64}
end

HarmonicTrap(omega::Float64) = HarmonicTrap((omega,))
HarmonicTrap(ox::Float64, oy::Float64) = HarmonicTrap((ox, oy))
HarmonicTrap(ox::Float64, oy::Float64, oz::Float64) = HarmonicTrap((ox, oy, oz))

struct NoPotential <: AbstractPotential end

struct GravityPotential{N} <: AbstractPotential
    g::Float64
    axis::Int

    function GravityPotential{N}(g::Float64, axis::Int) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(g, axis)
    end
end

GravityPotential(g::Float64, axis::Int, ndim::Int) = GravityPotential{ndim}(g, axis)

struct CompositePotential{N} <: AbstractPotential
    components::Vector{AbstractPotential}
end

struct RingPotential{N} <: AbstractPotential
    radius::Float64
    strength::Float64
    width::Float64
end

RingPotential(; radius=5.0, strength=50.0, width=1.0, ndim::Int=2) =
    RingPotential{ndim}(radius, strength, width)

struct BoxPotential{N} <: AbstractPotential
    size::NTuple{N,Float64}
    wall_strength::Float64
    wall_width::Float64
end

BoxPotential(size::NTuple{N,Float64}; wall_strength=1000.0, wall_width=0.5) where {N} =
    BoxPotential{N}(size, wall_strength, wall_width)

struct OpticalLatticePotential{N} <: AbstractPotential
    depth::NTuple{N,Float64}
    period::NTuple{N,Float64}
    phase::NTuple{N,Float64}
end

OpticalLatticePotential(depth::NTuple{N,Float64}, period::NTuple{N,Float64};
    phase::NTuple{N,Float64}=ntuple(_ -> 0.0, N)) where {N} =
    OpticalLatticePotential{N}(depth, period, phase)

struct DoubleWellPotential{N} <: AbstractPotential
    separation::Float64
    barrier::Float64
    omega::NTuple{N,Float64}
    axis::Int
end

DoubleWellPotential(; separation=4.0, barrier=10.0, omega=(1.0,), axis=1) =
    DoubleWellPotential{length(omega)}(separation, barrier, omega, axis)

struct QuarticPotential{N} <: AbstractPotential
    omega::NTuple{N,Float64}
    lambda::NTuple{N,Float64}
end

# --- LHY Abstraction ---

abstract type AbstractLHY end

struct ScalarLHY <: AbstractLHY
    c_lhy::Float64
end

struct Quasi2DLHY <: AbstractLHY
    c_lhy_2d::Float64
    a_2d_sq::Float64
    log_const::Float64
end

struct SpinorLHYTable <: AbstractLHY
    mode::Symbol
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct MagneticGradient{N} <: AbstractPotential
    gradient::Float64
    axis::Int
    g_F::Float64

    function MagneticGradient{N}(gradient::Float64, axis::Int, g_F::Float64) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(gradient, axis, g_F)
    end
end

MagneticGradient(; gradient=0.1, axis=3, g_F=1.0, ndim::Int=3) =
    MagneticGradient{ndim}(gradient, axis, g_F)

struct TimeDependentMagneticGradient{N}
    gradient_wf::Waveform
    axis::Int
    g_F::Float64

    function TimeDependentMagneticGradient{N}(gradient_wf::Waveform, axis::Int, g_F::Float64) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(gradient_wf, axis, g_F)
    end
end

TimeDependentMagneticGradient(; gradient_wf::Waveform, axis::Int=3, g_F::Float64=1.0, ndim::Int=3) =
    TimeDependentMagneticGradient{ndim}(gradient_wf, axis, g_F)

struct LaguerreGaussBeam{N} <: AbstractPotential
    power::Float64
    waist::Float64
    l_mode::Int
    p_mode::Int
    polarizability::Float64
end

LaguerreGaussBeam(; power=1.0, waist=10.0, l_mode=1, p_mode=0, polarizability=1.0, ndim::Int=2) =
    LaguerreGaussBeam{ndim}(power, waist, l_mode, p_mode, polarizability)

struct PlugBeam{N} <: AbstractPotential
    strength::Float64
    waist::Float64
end

PlugBeam(; strength=50.0, waist=2.0, ndim::Int=2) = PlugBeam{ndim}(strength, waist)

struct ShakenLatticePotential{N} <: AbstractPotential
    depth::NTuple{N,Float64}
    period::NTuple{N,Float64}
    shake_wf::NTuple{N,Waveform}
end

# --- Time-dependent extensions ---

struct TimeDependentTrap{N} <: AbstractPotential
    base::AbstractPotential
    omega_wf::NTuple{N,Waveform}
end

struct TimeDependentInteractions
    c0_wf::Waveform
    c1_wf::Waveform
end

TimeDependentInteractions(; c0=0.0, c1=0.0) =
    TimeDependentInteractions(ConstantWaveform(Float64(c0)), ConstantWaveform(Float64(c1)))

function interactions_at(ip::InteractionParams, ::Float64)
    ip
end

function interactions_at(td::TimeDependentInteractions, t::Float64)
    InteractionParams(evaluate(td.c0_wf, t), evaluate(td.c1_wf, t))
end

# --- Simulation Parameters ---

struct SimParams
    dt::Float64
    n_steps::Int
    imaginary_time::Bool
    normalize_every::Int
    save_every::Int
    rotating_frame_omega::Float64
end

SimParams(dt, n_steps, imaginary_time, normalize_every, save_every) =
    SimParams(dt, n_steps, imaginary_time, normalize_every, save_every, 0.0)

function SimParams(;
    dt::Float64,
    n_steps::Int,
    imaginary_time::Bool = false,
    normalize_every::Int = imaginary_time ? 1 : 0,
    save_every::Int = max(1, n_steps ÷ 100),
    rotating_frame_omega::Float64 = 0.0,
)
    dt > 0 || throw(ArgumentError("dt must be positive"))
    n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
    SimParams(
        dt,
        n_steps,
        imaginary_time,
        normalize_every,
        save_every,
        rotating_frame_omega,
    )
end

# --- Simulation State (mutable) ---

mutable struct SimState{N,A<:AbstractArray,B<:AbstractArray,T<:AbstractFloat}
    psi::A              # wavefunction: spatial dims... × n_components (eltype Complex{T})
    fft_buf::B          # spatial-only buffer for FFT (same device + eltype as psi)
    psi_scratch::A      # full-size scratch (same shape as psi); avoids per-call
                        # similar(psi) in apply_uniform_spin_rotation! and other
                        # whole-ψ broadcast ops on the spin axis. Reusable across
                        # any operator that does ψ_new = R · ψ in place.
    t::Float64
    step::Int
end

# Convenience: T is always real(eltype(psi)). Use this so callers don't
# need to specify T manually.
SimState{N,A,B}(psi::A, fft_buf::B, psi_scratch::A, t, step) where {N,A,B} =
    SimState{N,A,B,real(eltype(A))}(psi, fft_buf, psi_scratch, t, step)

# --- FFT Plans ---

struct FFTPlans{P,IP}
    forward::P
    inverse::IP
end

# --- rFFT Plans (for DDI on real-valued spin density) ---

struct RFFTPlans{N,RP,IRP}
    forward::RP
    inverse::IRP
    rk_shape::NTuple{N,Int}
end

# --- DDI ---

mutable struct DDIParams{N,AQ<:AbstractArray{<:AbstractFloat,N}}
    C_dd::Float64
    Q_xx::AQ
    Q_xy::AQ
    Q_xz::AQ
    Q_yy::AQ
    Q_yz::AQ
    Q_zz::AQ
end

struct DDIBuffers{N,RP,IRP,AR<:AbstractArray,AC<:AbstractArray}
    rfft_plans::RFFTPlans{N,RP,IRP}
    Fx_r::AR
    Fy_r::AR
    Fz_r::AR
    Fx_rk::AC
    Fy_rk::AC
    Fz_rk::AC
    Phi_x_rk::AC
    Phi_y_rk::AC
    Phi_z_rk::AC
    Phi_x::AR
    Phi_y::AR
    Phi_z::AR
end

# --- Loss Parameters ---

"""
Loss parameters for dipolar relaxation, two-body, three-body, and
energy-selective evaporation channels.

Fields:
- `gamma_dr` — base dipolar-relaxation rate. Internally re-weighted per m
  via Clebsch–Gordan factors so only Δm=−1,−2 transitions drive loss and
  the average rate across m equals `gamma_dr`.
- `L3` / `L3_per_m` — **legacy 2-body-shaped** rate that uses
  `exp(-rate · n_total · dt / 2)`. Convenient when calibrated against the
  same shape; physically a 2-body loss with a 3-body label.
- `K3_cubic` / `K3_per_m_cubic` — **physically correct 3-body** rate
  applied as `exp(-K_3 · n_total² · dt / 2)`, i.e. dn/dt = −K_3 n² n_m.
  Use this for true 3-body recombination loss (Eu151/Dy164 in dense
  regimes). Per-m vector overrides scalar.
- `evap_energy_cutoff` / `evap_rate` — energy-selective evaporation
  (Phase 4 #40): atoms in regions where the local potential energy
  exceeds `evap_energy_cutoff` are removed at rate `evap_rate`. Models
  RF-knife evaporative cooling. Both must be non-zero to activate.
"""
struct LossParams
    gamma_dr::Float64
    L3::Float64
    L3_per_m::Vector{Float64}
    K3_cubic::Float64
    K3_per_m_cubic::Vector{Float64}
    evap_energy_cutoff::Float64
    evap_rate::Float64
end

LossParams(gamma_dr::Float64) =
    LossParams(gamma_dr, 0.0, Float64[], 0.0, Float64[], 0.0, 0.0)
LossParams(gamma_dr::Float64, L3::Float64) =
    LossParams(gamma_dr, L3, Float64[], 0.0, Float64[], 0.0, 0.0)

function LossParams(;
    gamma_dr::Real = 0.0,
    L3::Real = 0.0,
    L3_per_m::AbstractVector{<:Real} = Float64[],
    K3_cubic::Real = 0.0,
    K3_per_m_cubic::AbstractVector{<:Real} = Float64[],
    evap_energy_cutoff::Real = 0.0,
    evap_rate::Real = 0.0,
)
    LossParams(Float64(gamma_dr), Float64(L3), collect(Float64, L3_per_m),
               Float64(K3_cubic), collect(Float64, K3_per_m_cubic),
               Float64(evap_energy_cutoff), Float64(evap_rate))
end

# --- Absorbing Boundary ---

struct AbsorbingBoundary
    strength::Float64
    width::Float64
    power::Int
end

AbsorbingBoundary(; strength::Float64, width::Float64, power::Int = 2) =
    AbsorbingBoundary(strength, width, power)

# --- Light Shift (tensor + vector AC Stark) ---

struct LightShift{A<:AbstractArray}
    profile::A               # spatial intensity I(r), shape n_pts
    eigvals::Vector{Float64} # eigenvalues of spin matrix M (length D)
    U::Matrix{ComplexF64}    # eigenvector matrix D×D
    is_diagonal::Bool        # true → fold into diagonal step, no rotation needed
end

# --- DDI Padded Context ---

struct DDIPaddedContext{N,RP,IRP,AR<:AbstractArray,AC<:AbstractArray}
    padded_shape::NTuple{N,Int}
    rfft_plans::RFFTPlans{N,RP,IRP}
    Q_xx::AR
    Q_xy::AR
    Q_xz::AR
    Q_yy::AR
    Q_yz::AR
    Q_zz::AR
    Fx_pad::AR
    Fy_pad::AR
    Fz_pad::AR
    Fx_pad_rk::AC
    Fy_pad_rk::AC
    Fz_pad_rk::AC
    Phi_x_pad_rk::AC
    Phi_y_pad_rk::AC
    Phi_z_pad_rk::AC
    Phi_x_pad::AR
    Phi_y_pad::AR
    Phi_z_pad::AR
end

# --- Batched Kinetic Cache ---

struct BatchedKineticCache{P,IP,KP<:AbstractArray}
    forward::P
    inverse::IP
    kinetic_phase_bc::KP
end

# --- Coriolis Cache (in-place FFT plans for 3-shear decomposition) ---

struct CoriolisCache{P1,IP1,P2,IP2}
    fwd_dim1::P1
    inv_dim1::IP1
    fwd_dim2::P2
    inv_dim2::IP2
end

# --- Tensor Interaction Cache (general-F) ---

struct TensorInteractionCache
    F::Int
    D::Int
    cg_table::Dict{NTuple{4,Int},Float64}
    active_channels::Vector{Int}      # S values (even total spin channels)
    g_values::Vector{Float64}         # corresponding g_S coupling constants
end

# --- Adaptive Time Stepping ---

struct AdaptiveDtParams
    dt_init::Float64
    dt_min::Float64
    dt_max::Float64
    tol::Float64
    error_mode::Symbol

    function AdaptiveDtParams(;
        dt_init::Float64 = 0.001,
        dt_min::Float64 = 1e-5,
        dt_max::Float64 = 0.01,
        tol::Float64 = 1e-3,
        error_mode::Symbol = :step_change,
    )
        dt_init > 0 || throw(ArgumentError("dt_init must be positive"))
        dt_min > 0 || throw(ArgumentError("dt_min must be positive"))
        dt_max >= dt_min || throw(ArgumentError("dt_max must be >= dt_min"))
        tol > 0 || throw(ArgumentError("tol must be positive"))
        error_mode in (:step_change, :richardson, :embedded) || throw(
            ArgumentError(
                "error_mode must be :step_change, :richardson, or :embedded, got :$error_mode",
            ),
        )
        new(dt_init, dt_min, dt_max, tol, error_mode)
    end
end

struct IntegratorConfig
    method::Symbol
    params::Union{Nothing,AdaptiveDtParams}

    function IntegratorConfig(
        method::Symbol,
        params::Union{Nothing,AdaptiveDtParams} = nothing,
    )
        method in (:strang, :yoshida, :adaptive) || throw(
            ArgumentError(
                "integrator method must be :strang, :yoshida, or :adaptive, got :$method",
            ),
        )
        if method == :adaptive && params === nothing
            throw(ArgumentError("adaptive integrator requires AdaptiveDtParams"))
        end
        new(method, params)
    end
end

IntegratorConfig() = IntegratorConfig(:strang, nothing)

struct TOFParams
    t_tof::Float64
    gradient::Float64
    imaging_axis::Int

    function TOFParams(t_tof::Float64, gradient::Float64, imaging_axis::Int)
        t_tof >= 0 || throw(ArgumentError("t_tof must be non-negative"))
        1 <= imaging_axis <= 3 || throw(ArgumentError("imaging_axis must be 1, 2, or 3"))
        new(t_tof, gradient, imaging_axis)
    end
end

TOFParams(; t_tof::Float64, gradient::Float64 = 0.0, imaging_axis::Int = 3) =
    TOFParams(t_tof, gradient, imaging_axis)

struct BdGResult
    k_values::Vector{Float64}
    omega::Matrix{ComplexF64}
    max_growth_rate::Float64
    unstable::Bool
end

struct InstabilityMap
    k_values::Vector{Float64}
    directions::Vector{NTuple{3,Float64}}
    growth_rates::Matrix{Float64}
    max_growth_rate::Float64
    unstable::Bool
    most_unstable_k::Float64
    most_unstable_direction::NTuple{3,Float64}
    k_unstable_range::Tuple{Float64,Float64}
    predicted_wavelength::Float64
    angular_growth_map::Vector{Float64}
end

struct RotonParams
    k_roton::Float64
    omega_roton::Float64
    roton_gap::Float64
    has_roton::Bool
end

struct SupersolidPrediction
    wavelength::Float64
    pattern_type::Symbol
    k_roton::Float64
    angular_anisotropy::Float64
end

struct HysteresisResult
    param_values::Vector{Float64}
    forward::Vector{NamedTuple}
    backward::Vector{NamedTuple}
    hysteresis_intervals::Vector{Tuple{Float64,Float64}}
    transition_points::Vector{Float64}
end

# --- Phase Scan Types ---

abstract type AbstractScanSpec end

"""
    OverrideScan

Scan spec built from path-based config overrides. Each scan point is one
override map (a dict of dotted YAML paths → values) that the runner applies
to the raw YAML dict and re-parses before running.

Fields:
- `points`: list of override maps, one per scan point. Generated from a
  YAML `zip:` or `product:` block (see `expand_scan_points`).
- `comparison_runs`: list of `(name, override)` pairs. When non-empty, every
  scan point is run once per comparison run; the comparison override is
  merged on top of the scan point override.
- `continuation`: when true, the previous point's converged psi is reused
  as the initial condition for the next point.
- `auto_rotate_on_mz`: when true and `ground_state.target_magnetization`
  changes between adjacent points, the carried-over psi is rotated by
  Δα around y so the constraint normalization can redistribute populations.
"""
struct OverrideScan <: AbstractScanSpec
    points::Vector{Dict{String,Any}}
    comparison_runs::Vector{Tuple{String,Dict{String,Any}}}
    continuation::Bool
    auto_rotate_on_mz::Bool

    function OverrideScan(
        points::Vector{<:Dict},
        comparison_runs::Vector{<:Tuple{<:AbstractString,<:Dict}} = Tuple{String,Dict{String,Any}}[],
        continuation::Bool = false,
        auto_rotate_on_mz::Bool = false,
    )
        isempty(points) && throw(ArgumentError("OverrideScan requires at least one point"))
        new(
            Dict{String,Any}[Dict{String,Any}(p) for p in points],
            Tuple{String,Dict{String,Any}}[(String(n), Dict{String,Any}(o)) for (n, o) in comparison_runs],
            continuation,
            auto_rotate_on_mz,
        )
    end
end

"""
    ConstrainedJzScan

Scan a list of target `J_z` values, bisecting on the rotating-frame `Ω`
inside `find_ground_state` until the actual `J_z` matches the target within
`tolerance`. This is the one scan type that does NOT fit the
override-reparse model because the parameter being tuned (`Ω`) is resolved
by a runtime feedback loop, not by patching the config tree.
"""
struct ConstrainedJzScan <: AbstractScanSpec
    target_values::Vector{Float64}
    tolerance::Float64
    max_iter::Int
    omega_range::Tuple{Float64,Float64}

    function ConstrainedJzScan(
        target_values::Vector{Float64},
        tolerance::Float64,
        max_iter::Int,
        omega_range::Tuple{Float64,Float64},
    )
        !isempty(target_values) || throw(ArgumentError("target_values must not be empty"))
        tolerance > 0 || throw(ArgumentError("tolerance must be positive"))
        max_iter > 0 || throw(ArgumentError("max_iter must be positive"))
        omega_range[1] < omega_range[2] ||
            throw(ArgumentError("omega_range must satisfy lo < hi"))
        new(target_values, tolerance, max_iter, omega_range)
    end
end

# --- ITP Checkpoint (for pause/resume/refine) ---

struct ITPCheckpoint
    psi::Array{ComplexF64}
    step::Int
    n_steps::Int
    energy::Float64
    dE::Float64
    dpsi::Float64
    converged::Bool
    dt::Float64
    tol::Float64
end

# --- Simulation Result ---

struct SimulationResult
    times::Vector{Float64}
    energies::Vector{Float64}
    norms::Vector{Float64}
    magnetizations::Vector{Float64}
    psi_snapshots::Vector{Array{ComplexF64}}
end

# --- TWA (Truncated Wigner Approximation) ---

struct TWAConfig
    n_trajectories::Int
    seed_base::Int
    cutoff_energy::Union{Nothing,Float64}
    observables::Vector{Symbol}

    function TWAConfig(
        n_trajectories::Int,
        seed_base::Int = 42,
        cutoff_energy::Union{Nothing,Float64} = nothing,
        observables::Vector{Symbol} = [:density, :magnetization],
    )
        n_trajectories > 0 || throw(ArgumentError("n_trajectories must be positive"))
        new(n_trajectories, seed_base, cutoff_energy, observables)
    end
end

struct EnsembleResult
    times::Vector{Float64}
    mean::Dict{Symbol,Vector{<:AbstractArray}}
    var::Dict{Symbol,Vector{<:AbstractArray}}
    n_trajectories::Int
    trajectory_results::Union{Nothing,Vector{SimulationResult}}
end

# --- Workspace ---

struct Workspace{N,A,P,IP,SM<:SpinMatrices,ZEE,DDI,DDIB,RAM,LOSS,DDIP,BK,TC,CC,KPA<:AbstractArray,VPA<:AbstractArray,DBA<:AbstractArray,BACK<:AbstractBackend,LHY,ABM,LS,TDI,MG}
    state::SimState{N,A}
    fft_plans::FFTPlans{P,IP}
    kinetic_phase::KPA
    potential_values::VPA
    density_buf::DBA
    spin_matrices::SM
    grid::Grid{N}
    atom::AtomSpecies
    interactions::InteractionParams
    zeeman::ZEE
    potential::AbstractPotential
    sim_params::SimParams
    ddi::DDI
    ddi_bufs::DDIB
    raman::RAM
    loss::LOSS
    ddi_padded::DDIP
    batched_kinetic::BK
    tensor_cache::TC
    coriolis_cache::CC
    backend::BACK
    lhy::LHY
    absorbing_mask::ABM
    light_shift::LS
    time_dep_interactions::TDI
    magnetic_gradient::MG
end

"""
Real eltype carried by a Workspace's ψ. For mixed-precision audits:
`workspace_T(ws)` returns `Float32` for an F32 build, `Float64` for the
default. Equivalent to `real(eltype(ws.state.psi))` but documented +
exported so callers don't reach into internals.
"""
@inline workspace_T(ws::Workspace{N,A}) where {N,A} = real(eltype(A))

