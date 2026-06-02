# scripts/lib/eu_digital_twin.jl
#
# Shared setup for the Eu-151 Matsui digital twin used by Track M0 (EdH
# cascade), Track M1 (rotating-frame Barnett), Track A1 v3 (phase
# identification), and Track B (LHY order-by-disorder).
#
# Single source of truth for:
#   * ¹⁵¹Eu atom + F=6 spinor + ω_ref = 2π·110 Hz
#   * digital-twin geometry (24³ default, box=(30,30,26))
#   * c_0 / c_1 / c_dd / a_ho derived constants
#   * lab-Gauss → dimensionless p_lab conversion (γ_Eu/2π = 16.28 Hz/nT)
#   * Gaussian symmetry-breaking noise injection
#
# Usage:
#   include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))
#   const TW = eu_digital_twin()           # default: 24³, N=5×10⁴
#   const ip = TW.interactions             # InteractionParams(c0 + c1)
#   # ... build seed via TW.atom / TW.grid / TW.potential ...
#   add_noise!(psi, 0.01, 1, TW.grid)
#
# Override defaults by kwarg, e.g.:
#   TW = eu_digital_twin(; n_pts=(32, 32, 32), n_atoms=20000)

using SpinorBEC
using Random

const _EU_OMEGA_REF = 691.15            # 2π·110 Hz, rad/s
const _EU_P_PER_NT = 0.148              # γ_Eu/2π = 16.28 Hz/nT → 16.28·2π / ω_ref
const _EU_F = 6
const _EU_D = 2 * _EU_F + 1
const _EU_DEFAULT_NPTS = (24, 24, 24)
const _EU_DEFAULT_BOX = (30.0, 30.0, 26.0)
const _EU_DEFAULT_TRAP_RATIOS = (1.0, 1.0, 1.1818)   # ω_z/ω_⊥ from (110, 110, 130) Hz

"""
    eu_digital_twin(; n_atoms=50000, n_pts=(24,24,24), box=(30,30,26),
                     trap_ratios=(1,1,1.1818)) → NamedTuple

Construct the canonical Eu-151 Matsui digital-twin configuration.

Returned NamedTuple fields:
  * `atom`             — `SpinorBEC.Eu151`
  * `F`                — `6`
  * `D`                — `13`
  * `omega_ref`        — `691.15` rad/s (= 2π·110 Hz)
  * `n_atoms`          — atom number (kwarg)
  * `n_pts`            — grid point count tuple (kwarg)
  * `box`              — box edge lengths tuple (kwarg)
  * `grid`             — `Grid` from `make_grid(GridConfig(n_pts, box))`
  * `potential`        — `HarmonicTrap{3}(trap_ratios)`
  * `a_ho`             — harmonic-oscillator length √(ℏ/(m·ω_ref))
  * `c_total`, `c0`, `c1` — Kawaguchi-Ueda spinor coefficients
  * `c_dd`             — dimensionless DDI coupling
  * `interactions`     — `InteractionParams(Dict(0 => c0, 1 => c1))`
  * `p_per_nT`         — `0.148` (γ_Eu/2π · 2π / ω_ref)
"""
function eu_digital_twin(;
    n_atoms::Int=50000,
    n_pts::NTuple{3, Int}=_EU_DEFAULT_NPTS,
    box::NTuple{3, Float64}=_EU_DEFAULT_BOX,
    trap_ratios::NTuple{3, Float64}=_EU_DEFAULT_TRAP_RATIOS,
)
    atom = SpinorBEC.Eu151
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * _EU_OMEGA_REF))
    c_total = 4π * (atom.a_s / a_ho) * n_atoms
    c0 = c_total / (1 + _EU_F^2 / 36.0)
    c1 = c0 / 36.0
    c_dd = SpinorBEC.compute_c_dd_dimless(atom;
        N_atoms=n_atoms, omega_ref=_EU_OMEGA_REF)
    grid = make_grid(GridConfig(n_pts, box))
    potential = HarmonicTrap{3}(trap_ratios)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0, 1 => c1))
    (
        atom=atom,
        F=_EU_F,
        D=_EU_D,
        omega_ref=_EU_OMEGA_REF,
        n_atoms=n_atoms,
        n_pts=n_pts,
        box=box,
        grid=grid,
        potential=potential,
        a_ho=a_ho,
        c_total=c_total,
        c0=c0,
        c1=c1,
        c_dd=c_dd,
        interactions=interactions,
        p_per_nT=_EU_P_PER_NT,
    )
end

"""
    add_noise!(psi, amp, seed, grid) → psi

Inject IID complex-Gaussian noise of amplitude `amp` into `psi` and
renormalise so ∫|ψ|² dV = 1. Convenience wrapper for sweep scripts that
seed symmetry-breaking from a structured initial state.
"""
function add_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid::Grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    norm = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= norm
end
