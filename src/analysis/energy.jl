export total_energy, energy_decomposition

"""
    energy_decomposition(ws) → NamedTuple

Decompose total energy into individual contributions.

Returns `(kinetic, trap, zeeman, density, spin, ddi, lhy, tensor, raman, light_shift, total)`.
"""
function energy_decomposition(ws::Workspace{N}) where {N}
    # GPU path: dispatch to extension via _energy_decomposition_impl
    if _is_gpu(ws.state.psi)
        return _energy_decomposition_gpu(ws)
    end
    _energy_decomposition_cpu(ws)
end

function _energy_decomposition_gpu end

function _energy_decomposition_cpu(ws::Workspace{N}) where {N}
    # Trinity-only: iterate the HamTerm registry, each term computes its
    # own contribution via `energy_contribution(::Term, psi, ws)`. The
    # legacy-shape adapter maps `density_c0`/`spin_c1` to
    # `:density`/`:spin`; `:zeeman` is already a single slot (ZeemanTerm).
    return energy_decomposition_via_registry_legacy_shape(ws)
end

function total_energy(ws::Workspace{N}) where {N}
    energy_decomposition(ws).total
end

# Per-term bodies (_trap_energy, _zeeman_energy, _magnetic_gradient_energy,
# _density_interaction_energy, _lhy_energy multi-methods) now live with
# their HamTerm subtypes in src/hamiltonian/terms/. `_energy_decomposition_cpu`
# above calls each by its canonical name — Julia resolves to the terms/
# definition. The trinity dispatch (`energy_contribution(::Term, psi, ws)`)
# provides the same physics via the registry.
