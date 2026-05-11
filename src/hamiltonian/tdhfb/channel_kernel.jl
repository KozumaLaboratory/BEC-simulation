# TDHFB channel kernel — shared between Hartree-Fock self-energy U and
# anomalous pair potential Δ.
#
# Computes the rank-4 channel-decomposed tensor
#
#   V[c, c', c2, c2'] = Σ_S g_S Σ_M ⟨F m(c), F m(c2) | S M⟩ ⟨S M | F m(c'), F m(c2')⟩
#
# in the convention c=1 ↔ m=+F, c=D ↔ m=-F (matching the existing
# `hf_matrix_generic!`). V is real and conserves m(c)+m(c2) = m(c')+m(c2') = M.
#
# `channel_kernel`              — un-symmetrized; used by `pair_potential_generic!`
# `channel_kernel_symmetrized`  — factor-2 Bose-symmetrized; used by
#                                 `hf_matrix_generic!` (the BdG self-energy)
#
# Reference: Kawaguchi-Ueda 2012 §3.2; matches the inlined `P` array previously
# built locally inside `hf_matrix_generic!`.

export channel_kernel

"""
    channel_kernel(F::Int, g_S::AbstractDict{Int, Float64}) -> Array{Float64, 4}

Compute the un-symmetrized rank-4 channel tensor

    V[c, c', c2, c2'] = Σ_S g_S Σ_M ⟨F m(c), F m(c2) | S M⟩ ⟨S M | F m(c'), F m(c2')⟩

with the convention `c=1 ↔ m=+F`, `c=D ↔ m=-F` (D = 2F+1).

`g_S` is a Dict keyed by total spin S ∈ {0, 2, …, 2F}; missing keys are
treated as zero coupling. Triangle inequality `|M| ≤ S` and the magnetization
conservation `m(c) + m(c2) = m(c') + m(c2') = M` are enforced.

The factor-2 Bose symmetrization required by the **second-derivative**
Hartree-Fock self-energy `U = 2 V (φ*φ + ρ)` is NOT included here; that is
the caller's concern (see `channel_kernel_symmetrized`). The un-symmetrized
form is the natural one for the anomalous pair potential

    Δ_{m, m'} = Σ_{m2, m2'} V_{m m'; m2 m2'} (φ_{m2} φ_{m2'} + κ_{m2, m2'})

because `(φ_{m2} φ_{m2'} + κ_{m2, m2'})` is already symmetric in `(m2, m2')`.

# Memory cost
For F=6 (Eu): 13⁴ = 28561 Float64 entries = 224 KB. Trivial.
"""
function channel_kernel(F::Int, g_S::AbstractDict{Int, Float64})
    D = 2 * F + 1
    V = zeros(Float64, D, D, D, D)
    c_to_m(c::Int) = F + 1 - c
    @inbounds for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
        m = c_to_m(c)
        m_p = c_to_m(c_p)
        m2 = c_to_m(c2)
        m2_p = c_to_m(c2_p)
        # Magnetization conservation: m + m2 = m_p + m2_p = M
        m + m2 != m_p + m2_p && continue
        M = m + m2
        s_total = 0.0
        for (S, gS) in g_S
            abs(M) > S && continue
            cg1 = clebsch_gordan(F, m, F, m2, S, M)
            cg2 = clebsch_gordan(F, m_p, F, m2_p, S, M)
            s_total += gS * cg1 * cg2
        end
        V[c, c_p, c2, c2_p] = s_total
    end
    return V
end

"""
    channel_kernel_symmetrized(F::Int, g_S::AbstractDict{Int, Float64}) -> Array{Float64, 4}

Bose-symmetrized rank-4 channel tensor `2 V`. This is the kernel that appears
in the Hartree-Fock self-energy (second functional derivative of E_int),

    U_{m, m'} = Σ_{m2, m2'} P_{m m'; m2 m2'} (φ_{m2'}^* φ_{m2} + ρ_{m2', m2})
              = 2 Σ_{m2, m2'} V_{m m'; m2 m2'} (φ_{m2'}^* φ_{m2} + ρ_{m2', m2})

as used by `hf_matrix_generic!`. Convenience alias for `2 .* channel_kernel(F, g_S)`.
"""
function channel_kernel_symmetrized(F::Int, g_S::AbstractDict{Int, Float64})
    return 2.0 .* channel_kernel(F, g_S)
end
