# --- Phase 1.1 state zoo: named builders -------------------------------

export init_psi_polar, init_psi_m_plus_F, init_psi_m_minus_F
export init_psi_uniform, init_psi_antiferromagnetic, init_psi_random
export init_psi_spin_coherent, init_psi_fl_vortex, init_psi_spin_helix
export init_psi_cyclic, init_psi_biaxial_nematic, init_psi_polar_core_vortex
export init_psi_bright_soliton, init_psi_dark_soliton, init_psi_skyrmion
export init_psi_wavepacket, init_psi_domain_wall, init_psi_two_packets
export init_psi_chiral_spin_vortex, init_psi_magnetic_domain
export init_psi_vortex_lattice, init_psi_skyrmion_lattice

# Thin wrappers around `init_psi(grid, sys; state=:..., init_state_params=...)`
# so callers can write `init_psi_polar(grid, sys)` instead of remembering
# the right symbol. Each wrapper accepts the relevant kwargs and forwards
# them as `init_state_params`. This deliberately does NOT touch the
# underlying `init_psi` dispatch — same physics, just nicer names.
#
# Coverage matches the state-type list in initialization.jl as of
# Phase 1.1 closeout.

const _ZOO_NAMES = (
    :polar, :m_plus_F, :m_minus_F, :uniform, :antiferromagnetic,
    :random, :spin_coherent, :fl_vortex, :spin_helix, :cyclic, :biaxial_nematic,
    :polar_core_vortex, :soliton_bright, :soliton_dark, :skyrmion,
    :gaussian_wavepacket, :domain_wall, :two_packet, :chiral_spin_vortex,
    :magnetic_domain, :vortex_lattice, :skyrmion_lattice,
)

# --- Trivial pass-through wrappers (auto-generated) --------------------
#
# Each entry below maps to `init_psi(grid, sys; state=:NAME,
# init_state_params=Dict(kwargs...))`. Wrappers whose function name does
# NOT match their state symbol (e.g. `init_psi_bright_soliton` →
# `:soliton_bright`), or which apply default values / argument renaming
# (e.g. `init_psi_fl_vortex`'s `winding` → `vortex_charge`), live in
# their own hand-written `init_psi_<name>` blocks below.
const _TRIVIAL_ZOO_STATES = (
    (:polar,
        "Polar (m=0) initial state — all population in m=0 component."),
    (:m_plus_F,
        "m=+F polarized state (lowest Zeeman energy when p>0 under " *
        "`H_zee = -p·m + q·m²`; historical name was `ferromagnetic`)."),
    (:m_minus_F,
        "m=−F polarized state. Highest Zeeman energy at p>0; only the GS " *
        "when p<0 (reversed Zeeman)."),
    (:uniform,
        "Equal population across all 2F+1 components."),
    (:antiferromagnetic,
        "Alternating (anti-aligned) magnetic structure."),
    (:cyclic,
        "Cyclic phase (F=2 / F=6 spinor) — three nonzero amplitudes " *
        "with relative phase 2π/3."),
    (:skyrmion,
        "Single-charge skyrmion texture."),
)

for (state, doc) in _TRIVIAL_ZOO_STATES
    fn = Symbol("init_psi_", state)
    @eval begin
        @doc $doc $fn(grid, sys; kwargs...) = init_psi(
            grid, sys; state=($(QuoteNode(state))), kwargs...
        )
    end
end

"""
    init_psi_random(grid, sys; seed=nothing)

Random-amplitude initial state seeded by `seed` (Int). `nothing` keeps
`init_psi`'s default `seed=42`.
"""
init_psi_random(grid, sys; seed=nothing) =
    if seed === nothing
        init_psi(grid, sys; state=:random)
    else
        init_psi(grid, sys; state=:random, seed=Int(seed))
    end

# Parameterised wrappers below forward their kwargs through `init_psi`'s
# real keyword surface (`init_theta`, `init_phi`, `init_vortex_charge`,
# `helix_k`, `seed`). The earlier `init_state_params=Dict(...)` route
# pre-dates a 2026-05 refactor of `init_psi` to a flat-kwarg signature
# and was silently broken (MethodError at call time) until the audit
# turn caught it. Wrappers whose user-API kwarg has no `init_psi`
# counterpart simply accept-and-drop it for backwards compatibility.

"""
    init_psi_spin_coherent(grid, sys; theta=0.0, phi=0.0)

Spin-coherent state along the (theta, phi) direction on the Bloch sphere.
"""
init_psi_spin_coherent(grid, sys; theta::Real=0.0, phi::Real=0.0) = init_psi(grid, sys;
    state=:spin_coherent,
    init_theta=theta, init_phi=phi)

"""
    init_psi_fl_vortex(grid, sys; winding=1)

Flux-closure (FL) vortex — spin-coherent texture forced to θ=π/2 with
the given winding number around the trap centre. (`theta` is fixed
inside `init_psi` for this state; only `winding` is plumbed through.)
"""
init_psi_fl_vortex(grid, sys; winding::Int=1) = init_psi(
    grid, sys; state=:fl_vortex, init_vortex_charge=winding
)

"""
    init_psi_spin_helix(grid, sys; q_vector=ntuple(_->0, N))

Spin helix winding along the wave vector `q_vector`. Must have
length matching the grid dimensionality.
"""
init_psi_spin_helix(grid::Grid{N}, sys; q_vector=ntuple(_ -> 0.0, N)) where {N} = init_psi(grid,
    sys; state=:spin_helix,
    helix_k=NTuple{N, Float64}(Float64(q_vector[d]) for d in 1:N))

"""
    init_psi_biaxial_nematic(grid, sys; angles=(0.0, 0.0))

Biaxial nematic state. `init_psi` constructs the canonical
(|+δ⟩+|−δ⟩)/√2 representative and ignores the angle pair — kept as
a wrapper kwarg for API symmetry with other oriented states.
"""
init_psi_biaxial_nematic(grid, sys; angles=(0.0, 0.0)) = begin
    angles isa Tuple && length(angles) == 2 ||
        throw(ArgumentError("angles must be a 2-tuple (θ, φ)"))
    init_psi(grid, sys; state=:biaxial_nematic)
end

"""
    init_psi_polar_core_vortex(grid, sys; winding=1, axis=:z)

Polar-core vortex — m=0 vortex core surrounded by m=±F density.
(`axis` is currently hardcoded to z inside `init_psi`; accepted for
forward compatibility.)
"""
init_psi_polar_core_vortex(grid, sys; winding::Int=1, axis::Symbol=:z) = begin
    axis === :z || throw(ArgumentError(
        ":polar_core_vortex currently only supports axis=:z (got $axis)"))
    init_psi(grid, sys; state=:polar_core_vortex, init_vortex_charge=winding)
end

"""
    init_psi_bright_soliton(grid, sys; m_state=:max, width=1.0)

Bright soliton in the central m component. `width` is currently
derived from the grid box size inside `init_psi`; the kwarg is
accepted for API symmetry.
"""
init_psi_bright_soliton(grid, sys; m_state=:max, width::Real=1.0) = init_psi(
    grid, sys; state=:soliton_bright
)

"""
    init_psi_dark_soliton(grid, sys; m_state=:max, position=0.0)

Dark soliton kink in the central m component. `position` is fixed at
0 inside `init_psi`; the kwarg is accepted for API symmetry.
"""
init_psi_dark_soliton(grid, sys; m_state=:max, position::Real=0.0) = init_psi(
    grid, sys; state=:soliton_dark
)

"""
    init_psi_wavepacket(grid, sys; momentum=0.0, width=1.0, m_state=1)

Gaussian wavepacket with momentum kick along dim 1. `momentum` plumbs
through `init_theta` (which `init_psi` uses as k₀ for this state).
"""
init_psi_wavepacket(grid, sys;
    momentum::Real=0.0, width::Real=1.0, m_state::Int=1) = init_psi(
    grid, sys; state=:gaussian_wavepacket, init_theta=momentum
)

"""
    init_psi_domain_wall(grid, sys; axis=1)

Two oppositely-magnetized regions joined by a wall along axis 1.
(`axis` is currently hardcoded to 1 inside `init_psi`.)
"""
init_psi_domain_wall(grid, sys; axis::Int=1) = begin
    axis == 1 || throw(ArgumentError(
        ":domain_wall currently only supports axis=1 (got $axis)"))
    init_psi(grid, sys; state=:domain_wall)
end

"""
    init_psi_two_packets(grid, sys; separation=2.0, momentum_kick=1.0)

Pair of Gaussian packets boosted toward each other. `momentum_kick`
plumbs through `init_theta`; `separation` is fixed inside `init_psi`.
"""
init_psi_two_packets(grid, sys;
    separation::Real=2.0, momentum_kick::Real=1.0) = init_psi(
    grid, sys; state=:two_packet, init_theta=momentum_kick
)

"""
    init_psi_chiral_spin_vortex(grid, sys; winding=1)

Chiral spin vortex — vortex with non-trivial spin texture in the core.
"""
init_psi_chiral_spin_vortex(grid, sys; winding::Int=1) = init_psi(grid, sys;
    state=:chiral_spin_vortex,
    init_vortex_charge=winding)

"""
    init_psi_magnetic_domain(grid, sys; pattern=:stripe)

2D magnetic domain pattern. `pattern ∈ {:stripe, :square, :hexagonal}`
maps to `init_psi`'s `init_vortex_charge` enum (0/1=stripe, 2=square,
3=hexagonal).
"""
init_psi_magnetic_domain(grid, sys; pattern::Symbol=:stripe) = begin
    pattern_code = if pattern === :stripe
        1
    elseif pattern === :square
        2
    elseif pattern === :hexagonal
        3
    else
        throw(
            ArgumentError(
                "magnetic_domain pattern must be :stripe / :square / :hexagonal (got $pattern)"
            ),
        )
    end
    init_psi(grid, sys; state=:magnetic_domain, init_vortex_charge=pattern_code)
end

"""
    init_psi_vortex_lattice(grid, sys; n_vortices=4, lattice=:triangular)

Regular array of vortices. `n_vortices` plumbs through `init_vortex_charge`
(used as lattice size). `lattice` is currently unused (only the default
square pattern is implemented inside `init_psi`).
"""
init_psi_vortex_lattice(grid, sys;
    n_vortices::Int=4, lattice::Symbol=:triangular) = init_psi(grid, sys; state=:vortex_lattice,
    init_vortex_charge=n_vortices)

"""
    init_psi_skyrmion_lattice(grid, sys; q_vector=(2π,0,0))

Skyrmion lattice with reciprocal-lattice scale `q_vector[1]` (only the
x-component is used as q0 in the triple-Q ansatz inside `init_psi`).
"""
init_psi_skyrmion_lattice(grid, sys; q_vector=(2π, 0.0, 0.0)) = init_psi(grid, sys;
    state=:skyrmion_lattice,
    init_theta=Float64(q_vector[1]))
