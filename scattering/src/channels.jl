"""
Two-atom scattering channel enumeration with identical-boson
symmetrization and total-projection quantum-number conservation.

Conserved quantum numbers (in the full H + B along z):
    M_tot = m_{F1} + m_{F2} + m_ℓ
For identical bosons, the full state (spin × spatial) must be symmetric
under 1 ↔ 2 exchange:
    • spin part |F₁m₁; F₂m₂⟩ symmetric   ⟹  spatial (-1)^ℓ = +1  ⟹ ℓ even
    • spin part antisymmetric              ⟹  ℓ odd

Thus:
    • if (F₁,m₁) = (F₂,m₂): only ℓ even channels exist
    • if (F₁,m₁) ≠ (F₂,m₂): each ℓ (even or odd) gives one channel
      (the spin wave function is fixed by ℓ parity to be sym or asym).
"""

"""
    ScatteringChannel

A single partial-wave scattering channel.

# Fields
- `state::TwoAtomHyperfineState` : symmetrized 2-atom spin state
- `ℓ::Int`                       : partial wave (≥ 0)
- `m_ℓ::Int`                     : projection, |m_ℓ| ≤ ℓ
- `E_threshold::Float64`         : asymptotic energy [E_h] at R → ∞
"""
struct ScatteringChannel
    state::TwoAtomHyperfineState
    ℓ::Int
    m_ℓ::Int
    E_threshold::Float64
end

"""
    threshold_energy(atom, tF1, tm1, tF2, tm2, B_tesla) [E_h]

Asymptotic 2-atom energy at R → ∞ in the weak-field approximation:
uses hyperfine energies E_hfs(F_i) plus diagonal Zeeman shifts in the
bare |F, m⟩ basis. The full dressed-threshold computation (that accounts
for Paschen–Back mixing of different F at the same m) is deferred to
Phase 2 — it requires diagonalizing `single_atom_hamiltonian(B)` and
relabelling channels by dressed indices.

Callers that need exact thresholds at arbitrary B should diagonalize
`single_atom_hamiltonian(basis, B_tesla)` directly; this helper is only
a channel-ordering convenience.
"""
function threshold_energy(atom::AtomParams,
                          tF1::Int, tm1::Int,
                          tF2::Int, tm2::Int,
                          B_tesla::Real)
    E = hfs_energy(atom, tF1) + hfs_energy(atom, tF2)
    # diagonal Zeeman: ⟨F m | g_J μ_B J_z − g_I μ_N I_z | F m⟩ × B
    E_muB = _muB_JT * B_tesla / _Eh_J
    E_muN = _muN_JT * B_tesla / _Eh_J
    Jz1 = _Jz_matrix_element(atom, tF1, tF1, tm1)
    Iz1 = _Iz_matrix_element(atom, tF1, tF1, tm1)
    Jz2 = _Jz_matrix_element(atom, tF2, tF2, tm2)
    Iz2 = _Iz_matrix_element(atom, tF2, tF2, tm2)
    E += atom.g_J * E_muB * (Jz1 + Jz2) - atom.g_I * E_muN * (Iz1 + Iz2)
    E
end

"""
    enumerate_channels(atom, M_tot, ℓ_max; B_tesla = 0.0) → Vector{ScatteringChannel}

Return all symmetry-allowed scattering channels with total projection
`M_tot` (integer) and partial wave ℓ ≤ ℓ_max.

# Arguments
- `atom`        : `AtomParams` (both atoms assumed identical for symmetrization)
- `M_tot::Int`  : conserved total projection m_{F1} + m_{F2} + m_ℓ
- `ℓ_max::Int`  : maximum partial wave (both even and odd are enumerated;
                  caller may filter)
- `B_tesla`     : magnetic field used for the (approximate) threshold

# Returns
Vector of `ScatteringChannel`, sorted by ascending threshold energy.

# Selection rules
- F_i ∈ {|J-I|, ..., J+I}, m_{F_i} ∈ {-F_i, ..., F_i}
- m_ℓ = M_tot - (m_{F1} + m_{F2}), with |m_ℓ| ≤ ℓ
- identical-boson parity (see module docstring)
"""
function enumerate_channels(atom::AtomParams, M_tot::Int, ℓ_max::Int;
                            B_tesla::Real = 0.0)
    tJ, tI = atom.two_J, atom.two_I
    tF_min = abs(tJ - tI)
    tF_max = tJ + tI

    # Enumerate unordered pairs (tF1,tm1) ≤ (tF2,tm2) lexicographic.
    pairs = Tuple{Int,Int,Int,Int,Bool}[]
    for tF1 in tF_min:2:tF_max
        for tm1 in -tF1:2:tF1
            for tF2 in tF_min:2:tF_max
                for tm2 in -tF2:2:tF2
                    key1 = (tF1, tm1); key2 = (tF2, tm2)
                    key1 > key2 && continue             # canonical order
                    identical = key1 == key2
                    push!(pairs, (tF1, tm1, tF2, tm2, identical))
                end
            end
        end
    end

    chans = ScatteringChannel[]
    for (tF1, tm1, tF2, tm2, identical) in pairs
        # m_ℓ = M_tot - (m1 + m2); in 2j units: 2m_ℓ = 2M_tot - (tm1 + tm2)
        two_mℓ = 2 * M_tot - (tm1 + tm2)
        isodd(two_mℓ) && continue               # impossible (should not occur for integer F)
        m_ℓ = two_mℓ ÷ 2
        for ℓ in 0:ℓ_max
            abs(m_ℓ) > ℓ && continue
            if identical && isodd(ℓ)
                continue                        # antisym spin state vanishes
            end
            state = TwoAtomHyperfineState(tF1, tm1, tF2, tm2, identical)
            E = threshold_energy(atom, tF1, tm1, tF2, tm2, B_tesla)
            push!(chans, ScatteringChannel(state, ℓ, m_ℓ, E))
        end
    end

    sort!(chans, by = c -> (c.E_threshold, c.ℓ, c.m_ℓ))
end
