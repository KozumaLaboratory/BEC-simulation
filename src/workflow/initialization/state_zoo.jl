# --- Phase 1.1 state zoo: named builders -------------------------------
#
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

# --- Legacy state-name aliases (kept for backward compat) --------------
#
# Old codebase used the term "ferromagnetic" for m=+F and
# "ferromagnetic_min" for m=−F. The latter docstring claimed it was
# "lowest Zeeman energy when g_F > 0", which is wrong for the
# `H_zee = -p·m` convention this codebase uses (m=+F is the lowest
# energy state at p>0). Rename to physically unambiguous names; keep
# the old symbols as direct aliases that downstream `init_psi` resolves
# the same way as the new ones.
const _STATE_ALIASES = Dict{Symbol, Symbol}(
    :ferromagnetic => :m_plus_F,
    :ferromagnetic_min => :m_minus_F,
)

"""Resolve a state symbol through the legacy alias table. Returns the
canonical name (`:m_plus_F`/`:m_minus_F`/...) for downstream dispatch."""
canonicalize_state(state::Symbol) = get(_STATE_ALIASES, state, state)

"""
    init_psi_polar(grid, sys; kwargs...)

Polar (m=0) initial state — all population in m=0 component.
"""
init_psi_polar(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:polar, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_m_plus_F(grid, sys; kwargs...)

m=+F polarized state (lowest Zeeman energy when p>0 in the codebase's
`H_zee = -p·m + q·m²` convention; the historical name was
`ferromagnetic`).
"""
init_psi_m_plus_F(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:m_plus_F, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_m_minus_F(grid, sys; kwargs...)

m=−F polarized state. Highest Zeeman energy at p>0; only the GS when p<0
(reversed Zeeman). Historical name was `ferromagnetic_min` whose
docstring claimed "lowest Zeeman" — that was inverted from the `-p·m`
convention. Use `:m_plus_F` for the actual ground state.
"""
init_psi_m_minus_F(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:m_minus_F, init_state_params=Dict{Symbol, Any}(kwargs...)
)

# Legacy aliases — preserved for compat. New code should use the
# m_plus_F / m_minus_F names.
const init_psi_ferromagnetic = init_psi_m_plus_F
const init_psi_ferromagnetic_min = init_psi_m_minus_F

"""
    init_psi_uniform(grid, sys; kwargs...)

Equal population across all 2F+1 components.
"""
init_psi_uniform(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:uniform, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_antiferromagnetic(grid, sys; kwargs...)

Alternating (anti-aligned) magnetic structure.
"""
init_psi_antiferromagnetic(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:antiferromagnetic, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_random(grid, sys; seed=nothing, kwargs...)

Random-amplitude initial state seeded by `seed` (Int).
"""
init_psi_random(grid, sys; seed=nothing, kwargs...) = begin
    p = Dict{Symbol, Any}(kwargs...)
    seed !== nothing && (p[:seed] = seed)
    init_psi(grid, sys; state=:random, init_state_params=p)
end

"""
    init_psi_spin_coherent(grid, sys; theta=0.0, phi=0.0, kwargs...)

Spin-coherent state along the (theta, phi) direction on the Bloch sphere.
"""
init_psi_spin_coherent(grid, sys; theta=0.0, phi=0.0, kwargs...) = init_psi(grid, sys;
    state=:spin_coherent,
    init_state_params=Dict{Symbol, Any}(:theta => theta, :phi => phi, kwargs...))

"""
    init_psi_fl_vortex(grid, sys; winding=1, theta=π/2, kwargs...)

Flux-closure (FL) vortex — singular spin-coherent texture with given
winding number around the trap centre.
"""
init_psi_fl_vortex(grid, sys; winding::Int=1, theta=π/2, kwargs...) = init_psi(grid, sys;
    state=:fl_vortex,
    init_state_params=Dict{Symbol, Any}(
        :vortex_charge => winding, :theta => theta, kwargs...))

"""
    init_psi_spin_helix(grid, sys; q_vector, kwargs...)

Spin helix winding along the wave vector `q_vector`.
"""
init_psi_spin_helix(grid, sys; q_vector=(0.0, 0.0, 0.0), kwargs...) = init_psi(grid, sys;
    state=:spin_helix,
    init_state_params=Dict{Symbol, Any}(:q_vector => q_vector, kwargs...))

"""
    init_psi_cyclic(grid, sys; kwargs...)

Cyclic phase (F=2 / F=6 spinor) — three nonzero amplitudes with relative
phase 2π/3.
"""
init_psi_cyclic(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:cyclic, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_biaxial_nematic(grid, sys; angles=(0.0, 0.0), kwargs...)

Biaxial nematic state with director angles (θ, φ).
"""
init_psi_biaxial_nematic(grid, sys; angles=(0.0, 0.0), kwargs...) = begin
    p = Dict{Symbol, Any}(kwargs...)
    angles isa Tuple && length(angles) == 2 || throw(ArgumentError("angles must be (θ, φ)"))
    p[:theta] = angles[1];
    p[:phi] = angles[2]
    init_psi(grid, sys; state=:biaxial_nematic, init_state_params=p)
end

"""
    init_psi_polar_core_vortex(grid, sys; winding=1, axis=:z, kwargs...)

Polar-core vortex — m=0 vortex core surrounded by m=±F density.
"""
init_psi_polar_core_vortex(grid, sys; winding::Int=1, axis::Symbol=:z, kwargs...) = init_psi(grid,
    sys; state=:polar_core_vortex,
    init_state_params=Dict{Symbol, Any}(:vortex_charge => winding, :axis => axis, kwargs...))

"""
    init_psi_bright_soliton(grid, sys; m_state=:max, width=1.0, kwargs...)

Bright soliton in component `m_state` (defaults to the m with the
strongest attractive interaction).
"""
init_psi_bright_soliton(grid, sys; m_state=:max, width=1.0, kwargs...) = init_psi(grid, sys;
    state=:soliton_bright,
    init_state_params=Dict{Symbol, Any}(:m_state => m_state, :width => width, kwargs...))

"""
    init_psi_dark_soliton(grid, sys; m_state=:max, position=0.0, kwargs...)

Dark soliton kink in component `m_state` centred at `position`.
"""
init_psi_dark_soliton(grid, sys; m_state=:max, position=0.0, kwargs...) = init_psi(grid, sys;
    state=:soliton_dark,
    init_state_params=Dict{Symbol, Any}(:m_state => m_state, :position => position, kwargs...))

"""
    init_psi_skyrmion(grid, sys; kwargs...)

Single-charge skyrmion texture.
"""
init_psi_skyrmion(grid, sys; kwargs...) = init_psi(
    grid, sys; state=:skyrmion, init_state_params=Dict{Symbol, Any}(kwargs...)
)

"""
    init_psi_wavepacket(grid, sys; center=(0.0,...), momentum=(0.0,...),
                        width=1.0, m_state=1, kwargs...)

Gaussian wavepacket in component `m_state` with optional momentum kick.
"""
init_psi_wavepacket(grid, sys; center=nothing, momentum=nothing,
    width=1.0, m_state::Int=1, kwargs...) = begin
    p = Dict{Symbol, Any}(:width => width, :m_state => m_state, kwargs...)
    center !== nothing && (p[:center] = center)
    momentum !== nothing && (p[:momentum] = momentum)
    init_psi(grid, sys; state=:gaussian_wavepacket, init_state_params=p)
end

"""
    init_psi_domain_wall(grid, sys; axis=1, kwargs...)

Two oppositely-magnetized regions joined by a wall along `axis`.
"""
init_psi_domain_wall(grid, sys; axis::Int=1, kwargs...) = init_psi(grid, sys; state=:domain_wall,
    init_state_params=Dict{Symbol, Any}(:axis => axis, kwargs...))

"""
    init_psi_two_packets(grid, sys; separation=2.0, momentum_kick=1.0, kwargs...)

Pair of Gaussian packets boosted toward each other for collision dynamics.
"""
init_psi_two_packets(grid, sys; separation=2.0, momentum_kick=1.0, kwargs...) = init_psi(grid, sys;
    state=:two_packet,
    init_state_params=Dict{Symbol, Any}(
        :separation => separation, :momentum_kick => momentum_kick, kwargs...))

"""
    init_psi_chiral_spin_vortex(grid, sys; winding=1, kwargs...)

Chiral spin vortex (vortex with non-trivial spin texture in the core).
"""
init_psi_chiral_spin_vortex(grid, sys; winding::Int=1, kwargs...) = init_psi(grid, sys;
    state=:chiral_spin_vortex,
    init_state_params=Dict{Symbol, Any}(:vortex_charge => winding, kwargs...))

"""
    init_psi_magnetic_domain(grid, sys; pattern=:stripe, kwargs...)

2D magnetic domain pattern. `pattern ∈ {:stripe, :hexagonal, :square}`.
"""
init_psi_magnetic_domain(grid, sys; pattern::Symbol=:stripe, kwargs...) = init_psi(grid, sys;
    state=:magnetic_domain,
    init_state_params=Dict{Symbol, Any}(:pattern => pattern, kwargs...))

"""
    init_psi_vortex_lattice(grid, sys; n_vortices=4, lattice=:triangular, kwargs...)

Regular array of vortices. `lattice ∈ {:triangular, :square}`.
"""
init_psi_vortex_lattice(grid, sys; n_vortices::Int=4,
lattice::Symbol=:triangular, kwargs...) = init_psi(grid, sys; state=:vortex_lattice,
    init_state_params=Dict{Symbol, Any}(
        :n_vortices => n_vortices, :lattice => lattice, kwargs...))

"""
    init_psi_skyrmion_lattice(grid, sys; q_vector=(2π,0,0), kwargs...)

Skyrmion lattice with reciprocal-lattice vector `q_vector`.
"""
init_psi_skyrmion_lattice(grid, sys; q_vector=(2π, 0.0, 0.0), kwargs...) = init_psi(grid, sys;
    state=:skyrmion_lattice,
    init_state_params=Dict{Symbol, Any}(:q_vector => q_vector, kwargs...))
