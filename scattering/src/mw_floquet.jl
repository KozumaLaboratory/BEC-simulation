"""
Single-atom microwave Floquet dressing.

For a time-periodic Hamiltonian H(t) = H_0 + V e^{-iωt} + V† e^{+iωt},
the Floquet theorem gives quasi-stationary solutions Ψ(t) = e^{-iεt} φ(t)
with φ(t+T) = φ(t), T = 2π/ω. Expanding φ(t) = Σ_n e^{-inωt} |φ_n⟩ and
truncating n ∈ [-N, N] turns the periodic problem into a time-independent
block-tridiagonal eigenproblem on the extended Hilbert space
`H ⊗ ℓ²(−N..N)`:

    H_F |{φ_n}⟩ = ε |{φ_n}⟩

with blocks

    (H_F)_{n,n}   = H_0 − n ω I,
    (H_F)_{n,n+1} = V ,
    (H_F)_{n+1,n} = V† .

Quasi-energies are defined modulo ω (Floquet zone). For a multi-tone
drive all tone frequencies must be commensurate with a base frequency
ω_base; each tone contributes to the off-diagonal block at offset
`k = ω_tone / ω_base`.
"""

"""
    MWTone

Single monochromatic component of a microwave drive. `V` is the
"rotating-wave" (positive-frequency) part of the interaction — the full
time-dependence is `V e^{-iω t} + V† e^{+iω t}`. All quantities in
atomic units (ω in E_h, V in E_h).
"""
struct MWTone
    ω::Float64
    V::Matrix{ComplexF64}
end

"""
    MWField

Microwave drive as a sum of monochromatic tones. `ω_base` is the common
base frequency; every `tone.ω` must be an integer (positive) multiple of
`ω_base`.
"""
struct MWField
    ω_base::Float64
    tones::Vector{MWTone}
end

"""
    MWField(tone::MWTone) → MWField

Shorthand for a single-tone field (`ω_base = tone.ω`).
"""
MWField(tone::MWTone) = MWField(tone.ω, [tone])

"""
    mw_sigma_plus(basis, ω, B_amp; g_J=basis.atom.g_J, g_I=basis.atom.g_I)
        → MWTone

Construct the rotating-wave perturbation for a σ⁺ (right-circularly
polarized, driving Δm_F = +1) microwave field of magnitude `B_amp`
(tesla) and frequency `ω` (E_h). The oscillating magnetic field is

    B_MW(t) = B_amp (x̂ cos ωt + ŷ sin ωt)

and the interaction is `H_MW(t) = −μ·B_MW(t)` with μ = −g_J μ_B J +
g_I μ_N I (Ramsey). The rotating part (coefficient of e^{−iωt}) evaluates
to `V = (B_amp/2)(g_J μ_B J_+ − g_I μ_N I_+)` in E_h.
"""
function mw_sigma_plus(
    basis::SingleAtomBasis,
    ω::Real,
    B_amp::Real;
    g_J::Real = basis.atom.g_J,
    g_I::Real = basis.atom.g_I,
)
    Jp = Jplus_matrix(basis)
    Ip = Iplus_matrix(basis)
    E_mu_B = (_muB_JT * B_amp) / _Eh_J
    E_mu_N = (_muN_JT * B_amp) / _Eh_J
    V = ComplexF64.(0.5 .* (g_J * E_mu_B .* Jp .- g_I * E_mu_N .* Ip))
    MWTone(Float64(ω), V)
end

"""
    mw_sigma_minus(basis, ω, B_amp; ...) → MWTone

σ⁻ drive (drives Δm_F = −1). The rotating part is `V = (B_amp/2)
(g_J μ_B J_− − g_I μ_N I_−) = V_{σ+}^†`.
"""
function mw_sigma_minus(
    basis::SingleAtomBasis,
    ω::Real,
    B_amp::Real;
    g_J::Real = basis.atom.g_J,
    g_I::Real = basis.atom.g_I,
)
    Jp = Jplus_matrix(basis)
    Ip = Iplus_matrix(basis)
    E_mu_B = (_muB_JT * B_amp) / _Eh_J
    E_mu_N = (_muN_JT * B_amp) / _Eh_J
    V = ComplexF64.(0.5 .* (g_J * E_mu_B .* Jp .- g_I * E_mu_N .* Ip))'
    MWTone(Float64(ω), Matrix(V))
end

"""
    mw_pi(basis, ω, B_amp; ...) → MWTone

π drive: linearly polarized along ẑ, `B_MW(t) = B_amp ẑ cos ωt`. The
rotating-wave part is `V = (B_amp/2)(g_J μ_B J_z − g_I μ_N I_z)`.
Same `V` for the counter-rotating component (linear pol).
"""
function mw_pi(
    basis::SingleAtomBasis,
    ω::Real,
    B_amp::Real;
    g_J::Real = basis.atom.g_J,
    g_I::Real = basis.atom.g_I,
)
    Jz = Jz_matrix(basis)
    Iz = Iz_matrix(basis)
    E_mu_B = (_muB_JT * B_amp) / _Eh_J
    E_mu_N = (_muN_JT * B_amp) / _Eh_J
    V = ComplexF64.(0.5 .* (g_J * E_mu_B .* Jz .- g_I * E_mu_N .* Iz))
    MWTone(Float64(ω), V)
end

"""
    floquet_hamiltonian(H0, field::MWField; n_photon) → Matrix{ComplexF64}

Build the truncated Floquet Hamiltonian in the extended basis
`|F, m_F⟩ ⊗ |n⟩` with `n ∈ −N..N`, N = `n_photon`. Block layout:
photon index runs fastest — row index = (n + N) * d + i (1-based).
"""
function floquet_hamiltonian(
    H0::AbstractMatrix,
    field::MWField;
    n_photon::Int,
)
    n_photon >= 0 || throw(ArgumentError("n_photon must be ≥ 0"))
    d = size(H0, 1)
    size(H0, 2) == d || throw(ArgumentError("H0 must be square"))
    N = n_photon
    nblocks = 2N + 1
    dim = nblocks * d
    ω_b = field.ω_base
    ω_b > 0 || throw(ArgumentError("ω_base must be positive"))

    # Resolve each tone's integer order k relative to ω_base.
    orders = Int[]
    for t in field.tones
        size(t.V) == (d, d) || throw(ArgumentError(
            "tone V size $(size(t.V)) does not match H0 dimension $d"))
        k = t.ω / ω_b
        kr = round(Int, k)
        isapprox(k, kr; atol=1e-10, rtol=1e-10) ||
            throw(ArgumentError("tone ω=$(t.ω) is not a multiple of ω_base=$ω_b"))
        kr >= 1 || throw(ArgumentError(
            "tone ω=$(t.ω) must be positive multiple of ω_base"))
        push!(orders, kr)
    end

    HF = zeros(ComplexF64, dim, dim)

    # Diagonal blocks: H_0 − n ω_b I.
    for nb in -N:N
        off = (nb + N) * d
        @inbounds for j in 1:d, i in 1:d
            HF[off + i, off + j] = H0[i, j]
        end
        @inbounds for i in 1:d
            HF[off + i, off + i] -= nb * ω_b
        end
    end

    # Off-diagonal blocks: V sits on block (n+k, n) (lower off-diagonal)
    # and V† on (n, n+k). Matches the Schrödinger coefficient-matching
    #   ε|φ_k⟩ = (H_0 − kω)|φ_k⟩ + V |φ_{k-1}⟩ + V† |φ_{k+1}⟩.
    for (ti, kr) in enumerate(orders)
        V = field.tones[ti].V
        for nb in -N:(N - kr)
            off_lo = (nb + N) * d                   # block row for n
            off_hi = (nb + kr + N) * d              # block row for n+k
            @inbounds for j in 1:d, i in 1:d
                HF[off_hi + i, off_lo + j] += V[i, j]
                HF[off_lo + j, off_hi + i] += conj(V[i, j])
            end
        end
    end

    HF
end

"""
    FloquetBasisLabel

Label for a Floquet basis vector `|F, m_F; n⟩`.
"""
struct FloquetBasisLabel
    two_F::Int
    two_m::Int
    n::Int
end

"""
    floquet_basis_labels(basis, n_photon) → Vector{FloquetBasisLabel}

Enumerate the extended-basis labels matching the row ordering used by
`floquet_hamiltonian`.
"""
function floquet_basis_labels(basis::SingleAtomBasis, n_photon::Int)
    out = Vector{FloquetBasisLabel}(undef, length(basis) * (2n_photon + 1))
    idx = 1
    for nb in -n_photon:n_photon
        for (tF, tm) in basis.states
            out[idx] = FloquetBasisLabel(tF, tm, nb)
            idx += 1
        end
    end
    out
end

"""
    DressedState

Floquet eigenstate with quasi-energy `ε`, extended-basis amplitudes
`coeffs` (same ordering as `floquet_basis_labels`), and the primary
`(tF, tm)` label of its largest-weight component after summing over
photon number `n` (with `n·ω_base` folded into `ε`).
"""
struct DressedState
    quasi_energy::Float64
    primary_two_F::Int
    primary_two_m::Int
    primary_weight::Float64
    coeffs::Vector{ComplexF64}
end

"""
    floquet_dressed_states(H_F, basis, ω_base, n_photon; zone=:first)
        → Vector{DressedState}

Diagonalize a Floquet Hamiltonian and collapse the resulting eigenstates
onto labels in the fundamental Floquet zone. Two zone folding options:

- `:first` — fold quasi-energies into `[−ω_base/2, +ω_base/2)`.
- `:full`  — keep raw eigenvalues; returns `(2N+1)·d` duplicates.

For `:first` the output length equals `length(basis)`, one dressed state
per bare label, picked as the solution whose amplitude is largest on
that `(tF, tm)` summed over photon sectors.
"""
function floquet_dressed_states(
    HF::AbstractMatrix,
    basis::SingleAtomBasis,
    ω_base::Real,
    n_photon::Int;
    zone::Symbol = :first,
)
    zone ∈ (:first, :full) || throw(ArgumentError("zone must be :first or :full"))
    d = length(basis)
    N = n_photon
    nblocks = 2N + 1
    size(HF) == (nblocks * d, nblocks * d) ||
        throw(ArgumentError("HF size inconsistent with basis × (2N+1)"))

    F = eigen(Hermitian(Matrix(HF)))
    evals = F.values
    evecs = F.vectors

    if zone === :full
        out = Vector{DressedState}(undef, length(evals))
        for k in eachindex(evals)
            v = Vector{ComplexF64}(evecs[:, k])
            w_Fm, (tF, tm) = _fold_primary_label(v, basis, N)
            out[k] = DressedState(evals[k], tF, tm, w_Fm, v)
        end
        return out
    end

    # :first — pick one dressed state per (tF, tm).
    # Weight per (tF, tm) for each eigenvector (summed over photon sector).
    weights = zeros(Float64, d, length(evals))
    @inbounds for k in eachindex(evals)
        for nb in 0:(nblocks - 1)
            off = nb * d
            for i in 1:d
                weights[i, k] += abs2(evecs[off + i, k])
            end
        end
    end

    out = Vector{DressedState}(undef, d)
    used = falses(length(evals))
    for i in 1:d
        # Among unused eigenstates, pick the one with largest weight on
        # bare state i; tiebreak on quasi-energy closest to zone center.
        best_k = 0
        best_w = -1.0
        for k in eachindex(evals)
            used[k] && continue
            if weights[i, k] > best_w
                best_w = weights[i, k]
                best_k = k
            end
        end
        used[best_k] = true
        tF, tm = basis.states[i]
        ε_raw = evals[best_k]
        ε_folded = _fold_first_zone(ε_raw, ω_base)
        v = Vector{ComplexF64}(evecs[:, best_k])
        out[i] = DressedState(ε_folded, tF, tm, best_w, v)
    end
    out
end

function _fold_first_zone(ε::Real, ω::Real)
    # Return ε − n·ω with n = round(ε/ω) so result ∈ [−ω/2, +ω/2).
    n = round(Int, ε / ω)
    ε - n * ω
end

function _fold_primary_label(
    v::AbstractVector,
    basis::SingleAtomBasis,
    N::Int,
)
    d = length(basis)
    best_w = -1.0
    best_i = 1
    for i in 1:d
        w = 0.0
        for nb in 0:(2N)
            w += abs2(v[nb * d + i])
        end
        if w > best_w
            best_w = w
            best_i = i
        end
    end
    (best_w, basis.states[best_i])
end

"""
    dressed_energies(basis, H0, field::MWField; n_photon) → Vector{Float64}

Convenience: return quasi-energies of the dressed states ordered to
match `basis.states`. Equivalent to `[s.quasi_energy for s in
floquet_dressed_states(floquet_hamiltonian(H0, field; n_photon), basis,
field.ω_base, n_photon)]`.
"""
function dressed_energies(
    basis::SingleAtomBasis,
    H0::AbstractMatrix,
    field::MWField;
    n_photon::Int,
)
    HF = floquet_hamiltonian(H0, field; n_photon)
    [s.quasi_energy for s in floquet_dressed_states(HF, basis, field.ω_base, n_photon)]
end
