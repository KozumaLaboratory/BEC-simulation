# --- DDI tensors, padded context, light shift, loss, tensor cache ---
#
# `DDIParams{N,AQ}` carries the precomputed Q_αβ(k) tensors for the
# unpadded periodic DDI convolution; `DDIBuffers` packs the plans +
# scratch arrays. `DDIPaddedContext` is the doubled-grid version used
# when periodicity must be killed (zero-padded convolution). `LossParams`
# parametrises dipolar-relaxation / 2-body / 3-body / evap channels.
# `LightShift` carries the spatial AC-Stark profile + spin-tensor
# diagonalisation. `TensorInteractionCache` holds the CG coefficients
# for the general-F contact step.

export DDIParams, DDIBuffers, DDIPaddedContext
export LossParams, LightShift, TensorInteractionCache

# --- DDI ---

mutable struct DDIParams{N, AQ <: AbstractArray{<:AbstractFloat, N}}
    C_dd::Float64
    Q_xx::AQ
    Q_xy::AQ
    Q_xz::AQ
    Q_yy::AQ
    Q_yz::AQ
    Q_zz::AQ
end

struct DDIBuffers{N, RP, IRP, AR <: AbstractArray, AC <: AbstractArray}
    rfft_plans::RFFTPlans{N, RP, IRP}
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

# --- DDI Padded Context ---

struct DDIPaddedContext{N, RP, IRP, AR <: AbstractArray, AC <: AbstractArray}
    padded_shape::NTuple{N, Int}
    rfft_plans::RFFTPlans{N, RP, IRP}
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

LossParams(gamma_dr::Float64) = LossParams(gamma_dr, 0.0, Float64[], 0.0, Float64[], 0.0, 0.0)
LossParams(gamma_dr::Float64, L3::Float64) = LossParams(
    gamma_dr, L3, Float64[], 0.0, Float64[], 0.0, 0.0
)

function LossParams(;
    gamma_dr::Real=0.0,
    L3::Real=0.0,
    L3_per_m::AbstractVector{<:Real}=Float64[],
    K3_cubic::Real=0.0,
    K3_per_m_cubic::AbstractVector{<:Real}=Float64[],
    evap_energy_cutoff::Real=0.0,
    evap_rate::Real=0.0,
)
    LossParams(Float64(gamma_dr), Float64(L3), collect(Float64, L3_per_m),
        Float64(K3_cubic), collect(Float64, K3_per_m_cubic),
        Float64(evap_energy_cutoff), Float64(evap_rate))
end

# --- Light Shift (tensor + vector AC Stark) ---

struct LightShift{A <: AbstractArray}
    profile::A               # spatial intensity I(r), shape n_pts
    eigvals::Vector{Float64} # eigenvalues of spin matrix M (length D)
    U::Matrix{ComplexF64}    # eigenvector matrix D×D
    is_diagonal::Bool        # true → fold into diagonal step, no rotation needed
end

# --- Tensor Interaction Cache (general-F) ---

struct TensorInteractionCache
    F::Int
    D::Int
    cg_table::Dict{NTuple{4, Int}, Float64}
    active_channels::Vector{Int}      # S values (even total spin channels)
    g_values::Vector{Float64}         # corresponding g_S coupling constants
end
