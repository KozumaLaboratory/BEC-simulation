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

struct Grid{N}
    config::GridConfig{N}
    x::NTuple{N,Vector{Float64}}
    dx::NTuple{N,Float64}
    k::NTuple{N,Vector{Float64}}
    dk::NTuple{N,Float64}
    k_squared::Array{Float64,N}
end

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

struct TimeDependentZeeman{T<:Function}
    B_func::T  # t -> ZeemanParams
end

# --- Raman Coupling ---

struct RamanCoupling{N}
    Omega_R::Float64          # Rabi frequency
    delta::Float64            # two-photon detuning
    k_eff::NTuple{N,Float64}  # effective wave vector (difference of two beams)
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

mutable struct SimState{N,A<:AbstractArray,B<:AbstractArray{ComplexF64,N}}
    psi::A              # wavefunction: spatial dims... × n_components
    fft_buf::B          # spatial-only buffer for FFT (same device as psi)
    t::Float64
    step::Int
end

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

struct DDIParams{N,AQ<:AbstractArray{Float64,N}}
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

struct LossParams
    gamma_dr::Float64
    L3::Float64
end

LossParams(gamma_dr::Float64) = LossParams(gamma_dr, 0.0)

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
        error_mode in (:step_change, :richardson) || throw(
            ArgumentError(
                "error_mode must be :step_change or :richardson, got :$error_mode",
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

struct ObservablesConfig
    always::Vector{Symbol}
    on_save::Vector{Symbol}
    final_only::Vector{Symbol}
    spatial_sampling::Float64

    function ObservablesConfig(
        always::Vector{Symbol},
        on_save::Vector{Symbol},
        final_only::Vector{Symbol},
        spatial_sampling::Float64,
    )
        0.0 < spatial_sampling <= 1.0 || throw(
            ArgumentError("spatial_sampling must be in (0, 1], got $spatial_sampling"),
        )
        new(always, on_save, final_only, spatial_sampling)
    end
end

ObservablesConfig() = ObservablesConfig([:norm, :magnetization], [:energy], Symbol[], 1.0)

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
end

struct HysteresisResult
    param_values::Vector{Float64}
    forward::Vector{NamedTuple}
    backward::Vector{NamedTuple}
    hysteresis_intervals::Vector{Tuple{Float64,Float64}}
    transition_points::Vector{Float64}
end

# --- Phase Scan Types ---

struct ScanValues
    from::Float64
    to::Float64
    n_points::Int

    function ScanValues(from::Float64, to::Float64, n_points::Int)
        n_points >= 2 || throw(ArgumentError("n_points must be >= 2"))
        new(from, to, n_points)
    end
end

struct ScanAxis
    parameter::Symbol
    values::Union{ScanValues,Vector{Float64}}
end

struct ContinuationConfig
    enabled::Bool
    n_steps::Int
    energy_jump_threshold::Float64

    function ContinuationConfig(enabled::Bool, n_steps::Int, energy_jump_threshold::Float64)
        n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
        energy_jump_threshold > 0 ||
            throw(ArgumentError("energy_jump_threshold must be positive"))
        new(enabled, n_steps, energy_jump_threshold)
    end
end

ContinuationConfig() = ContinuationConfig(true, 1000, 0.1)

struct MultiStartConfig
    enabled::Bool
    initial_states::Vector{Symbol}
    n_random::Int
end

MultiStartConfig() =
    MultiStartConfig(false, [:polar, :ferromagnetic, :uniform, :antiferromagnetic], 0)

abstract type AbstractScanSpec end

struct ScanPointOverride
    parameter::Symbol
    range::Tuple{Float64,Float64}
    overrides::Dict{Symbol,Any}

    function ScanPointOverride(
        parameter::Symbol,
        range::Tuple{Float64,Float64},
        overrides::Dict{Symbol,Any},
    )
        allowed = Set([:n_steps, :tol, :dt, :initial_state])
        for k in keys(overrides)
            k in allowed ||
                throw(ArgumentError("Unknown override key: $k. Allowed: $allowed"))
        end
        isempty(overrides) &&
            throw(ArgumentError("Override must specify at least one field"))
        range[1] <= range[2] ||
            throw(ArgumentError("Override range must satisfy from <= to"))
        new(parameter, range, overrides)
    end
end

struct ParameterScan <: AbstractScanSpec
    axes::Vector{ScanAxis}
    continuation::ContinuationConfig
    multistart::MultiStartConfig
    per_point_overrides::Vector{ScanPointOverride}

    function ParameterScan(
        axes::Vector{ScanAxis},
        continuation::ContinuationConfig,
        multistart::MultiStartConfig,
        per_point_overrides::Vector{ScanPointOverride} = ScanPointOverride[],
    )
        1 <= length(axes) <= 2 ||
            throw(ArgumentError("ParameterScan requires 1 or 2 axes, got $(length(axes))"))
        new(axes, continuation, multistart, per_point_overrides)
    end
end

ParameterScan(axes::Vector{ScanAxis}) =
    ParameterScan(axes, ContinuationConfig(), MultiStartConfig())

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

struct ScanStabilityConfig
    enabled::Bool
    perturbation::Float64
    n_steps::Int
    sample_every::Int

    function ScanStabilityConfig(
        enabled::Bool,
        perturbation::Float64,
        n_steps::Int,
        sample_every::Int,
    )
        perturbation > 0 || throw(ArgumentError("perturbation must be positive"))
        n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
        sample_every > 0 || throw(ArgumentError("sample_every must be positive"))
        new(enabled, perturbation, n_steps, sample_every)
    end
end

ScanStabilityConfig() = ScanStabilityConfig(false, 1e-4, 300, 10)

# --- Workspace ---

struct Workspace{N,A,P,IP,SM<:SpinMatrices,ZEE,DDI,DDIB,RAM,LOSS,DDIP,BK,TC,CC,KPA<:AbstractArray,VPA<:AbstractArray,DBA<:AbstractArray,BACK<:AbstractBackend}
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
end

# --- Unified Config v3 (base types) ---

abstract type AbstractExperimentSpec end

struct GroundStateExperiment <: AbstractExperimentSpec end

struct PerturbationConfig
    amplitude::Float64
    seed::Union{Nothing,Int}

    function PerturbationConfig(amplitude::Float64, seed::Union{Nothing,Int})
        amplitude > 0 || throw(ArgumentError("perturbation amplitude must be positive"))
        new(amplitude, seed)
    end
end

struct OutputConfig
    dir::String
    csv::Bool
    save_psi::Bool
    checkpoint_enabled::Bool
    checkpoint_interval::Int
    seed::Union{Nothing,Int}
end

OutputConfig() = OutputConfig("results", true, false, false, 1000, nothing)
