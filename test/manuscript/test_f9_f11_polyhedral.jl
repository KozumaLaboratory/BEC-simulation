# F=9 / F=11 odd-F polyhedral inert state verification.
#
# Extension of f5_f7 framework, covering remaining odd-F cases.
#
# F=9 (Table II §D.5):
#   T:A multiplicity 2 (two distinct T:A invariant subspaces)
#   T:E_1 multiplicity 1 (complex 1-dim, deferred to 2-dim real construction)
#   O:A_1 multiplicity 1
#   O:A_2 multiplicity 1
#
# F=11 (Table II):
#   T:A multiplicity 1
#   T:E_1 multiplicity 2 (deferred)
#   O:A_2 multiplicity 1
#
# Run: julia --project=. scripts/manuscript/f9_f11_polyhedral_verification.jl

using SpinorBEC
using LinearAlgebra
using Printf
using Random

# Reuse infrastructure from f5_f7
function spin_matrices_general(F::Int)
    D = 2F + 1
    Fz = Diagonal(ComplexF64[F - i for i in 0:(D - 1)])
    Fp = zeros(ComplexF64, D, D)
    for i in 1:(D - 1)
        m = F - i
        Fp[i, i + 1] = sqrt(F * (F + 1) - m * (m + 1))
    end
    Fm = Fp'
    Fx = (Fp + Fm) / 2
    Fy = (Fp - Fm) / (2im)
    return Matrix(Fx), Matrix(Fy), Matrix(Fz)
end

function wigner_D(F::Int, axis::Vector{Float64}, angle::Float64)
    Fx, Fy, Fz = spin_matrices_general(F)
    Fn = axis[1] * Fx + axis[2] * Fy + axis[3] * Fz
    Fn = (Fn + Fn') / 2
    ev = eigen(Fn)
    return ev.vectors * Diagonal(exp.(-1im * angle .* ev.values)) * ev.vectors'
end

function group_close(generators::Vector{<:AbstractMatrix}, tol::Float64=1e-6, max_size::Int=200)
    G = [Matrix{ComplexF64}(I, size(generators[1])...)]
    while length(G) < max_size
        prev_size = length(G)
        for g in copy(G)
            for h in generators
                gh = g * h
                if !any(norm(gh - x) < tol for x in G)
                    push!(G, gh)
                end
            end
        end
        length(G) == prev_size && break
    end
    return G
end

function tetrahedral_gen(F::Int)
    C3 = wigner_D(F, [1.0, 1.0, 1.0] / sqrt(3), Float64(2π/3))
    C2z = wigner_D(F, [0.0, 0.0, 1.0], Float64(π))
    return [C3, C2z]
end

function octahedral_gen(F::Int)
    C4z = wigner_D(F, [0.0, 0.0, 1.0], Float64(π/2))
    C3 = wigner_D(F, [1.0, 1.0, 1.0] / sqrt(3), Float64(2π/3))
    return [C4z, C3]
end

function compute_T_character(group_elements, irrep::Symbol)
    chars = ComplexF64[]
    ω = exp(2π*im/3)
    D_size = size(group_elements[1])
    Imat = Matrix{ComplexF64}(I, D_size...)
    for g in group_elements
        is_I = norm(g - Imat) < 1e-7
        g2 = g * g
        g3 = g2 * g
        is_order2 = (norm(g2 - Imat) < 1e-7) && !is_I
        is_order3 = (norm(g3 - Imat) < 1e-7) && !is_I && !is_order2

        if is_I
            push!(chars, 1.0 + 0im)
        elseif is_order3
            if irrep == :A
                push!(chars, 1.0 + 0im)
            elseif irrep == :E_1
                push!(chars, ω)
            elseif irrep == :E_2
                push!(chars, conj(ω))
            else
                push!(chars, 0.0 + 0im)
            end
        elseif is_order2
            push!(chars, 1.0 + 0im)
        else
            push!(chars, 0.0 + 0im)
        end
    end
    return chars
end

function compute_O_character(group_elements, irrep::Symbol)
    chars = Float64[]
    D_size = size(group_elements[1])

    for g in group_elements
        Imat = Matrix{ComplexF64}(I, D_size...)
        is_I = norm(g - Imat) < 1e-7
        g2 = g * g
        g3 = g2 * g
        g4 = g2 * g2
        is_order2 = (norm(g2 - Imat) < 1e-7) && !is_I
        is_order3 = (norm(g3 - Imat) < 1e-7) && !is_I && !is_order2
        is_order4 = (norm(g4 - Imat) < 1e-7) && !is_I && !is_order2 && !is_order3

        if is_I
            push!(chars, 1.0)
        elseif is_order3
            push!(chars, 1.0)
        elseif is_order4
            push!(chars, irrep == :A_1 ? 1.0 : -1.0)
        elseif is_order2
            push!(chars, NaN)
        else
            push!(chars, 0.0)
        end
    end

    Imat = Matrix{ComplexF64}(I, D_size...)
    order4_squares = Matrix{ComplexF64}[]
    for g in group_elements
        g2 = g * g
        norm(g2 - Imat) < 1e-7 && continue
        g4 = g2 * g2
        if norm(g4 - Imat) < 1e-7
            push!(order4_squares, g2)
        end
    end
    for i in 1:length(chars)
        if isnan(chars[i])
            g = group_elements[i]
            is_axial = any(norm(g - sq) < 1e-7 for sq in order4_squares)
            if irrep == :A_1
                chars[i] = 1.0
            elseif irrep == :A_2
                chars[i] = is_axial ? 1.0 : -1.0
            end
        end
    end
    return ComplexF64.(chars)
end

function project_onto_irrep(group_elements, chars::Vector{ComplexF64})
    P =
        sum(conj(chars[i]) * group_elements[i] for i in 1:length(group_elements)) /
        length(group_elements)
    return P
end

function find_invariant_vector(P::Matrix, D::Int; max_seeds::Int=30)
    for seed in 1:max_seeds
        Random.seed!(seed)
        v = randn(ComplexF64, D)
        ζ = P * v
        if norm(ζ) > 1e-6
            return ζ / norm(ζ)
        end
    end
    return nothing
end

function project_S_channel(ζ::Vector, F::Int, S::Int)
    total = 0.0
    for M in (-S):S
        amp = 0.0im
        for m1 in (-F):F
            m2 = M - m1
            if -F <= m2 <= F
                cg = clebsch_gordan(F, m1, F, m2, S, M)
                i1 = F - m1 + 1
                i2 = F - m2 + 1
                amp += cg * ζ[i1] * ζ[i2]
            end
        end
        total += abs2(amp)
    end
    return total
end

"""
    find_invariant_basis(P::AbstractMatrix, D::Int; tol::Real=1e-8)
        -> (Vector{Vector{ComplexF64}}, Int)

Return an orthonormal basis of Im(P) via SVD. Length of returned vector equals
the numerical rank of P at tolerance `tol` (the irrep multiplicity m_rep).
Seed-independent (SVD basis up to U(m_rep) ambiguity, which the orbit-average
rho_inv = (1/m_rep) * sum_i |zeta_i><zeta_i| washes out by Schur's lemma on
the multiplicity space).
"""
function find_invariant_basis(P::AbstractMatrix, D::Int; tol::Real=1e-8)
    U, Sv, V = svd(Matrix(P))
    m_rep = count(s -> s > tol, Sv)
    basis = [Vector{ComplexF64}(U[:, i]) for i in 1:m_rep]
    # Defensive Gram-Schmidt re-orthonormalization (SVD U columns are already
    # orthonormal, but this guards against numerical drift near singular-value
    # ties at the cutoff).
    for i in 1:m_rep
        for j in 1:(i - 1)
            basis[i] -= (basis[j]' * basis[i]) * basis[j]
        end
        nrm = norm(basis[i])
        nrm > 0 || error("Gram-Schmidt collapsed at basis vector $i")
        basis[i] /= nrm
    end
    return basis, m_rep
end

"""
    mult_aware_beta_S(rho_inv::AbstractMatrix, F::Int, S::Int) -> Float64

Compute bar_beta_S = Tr[Pi_S (rho_inv ⊗ rho_inv)] where
Pi_S = sum_M |S,M><S,M| in V_F ⊗ V_F and the coupling amplitudes
c(m1, m2; S, M) = <S, M | F m1, F m2> are Clebsch-Gordan coefficients.

Strict generalization of `project_S_channel`: when rho_inv = |ζ><ζ| (rank 1),
this reduces to `project_S_channel(ζ, F, S)`.

Index convention (matching `project_S_channel` in this file):
    idx(m) = F - m + 1, so column 1 ↔ m = +F, column D ↔ m = -F.

Einstein-sum form (derived from <S, M | (rho_inv ⊗ rho_inv) | S, M>):
    bar_beta_S = sum_M sum_{m1, m2, m1', m2'}
        conj(c(m1, m2; S, M)) * c(m1', m2'; S, M)
            * rho_inv[idx(m1), idx(m1')] * rho_inv[idx(m2), idx(m2')]

This is real for Hermitian rho_inv. The implementation uses the matrix form
    real( tr( A' * rho_inv * A * transpose(rho_inv) ) )
where A[idx(m1), idx(m2)] = c(m1, m2; S, M); transpose(rho_inv) = conj(rho_inv)
by Hermiticity, but we keep the literal transpose for index-convention clarity.
"""
function mult_aware_beta_S(rho_inv::AbstractMatrix, F::Int, S::Int)
    D = 2F + 1
    total = 0.0
    for M in (-S):S
        A = zeros(ComplexF64, D, D)
        for m1 in (-F):F
            m2 = M - m1
            if -F <= m2 <= F
                cg = clebsch_gordan(F, m1, F, m2, S, M)
                A[F - m1 + 1, F - m2 + 1] = ComplexF64(cg)
            end
        end
        contrib = real(tr(A' * rho_inv * A * transpose(rho_inv)))
        total += contrib
    end
    return total
end

"""
    canonical_mult_aware_beta_S(rho_inv, F, S, m_rep) -> Float64

Candidate (i) per theorist turn_115 §2.B: the canonical multiplicity-aware
channel coefficient is

    bar_beta_S^{canonical} = m_rep * Tr[Pi_S (rho_inv tensor rho_inv)]
                           = (1/m_rep) * Tr[Pi_S (P_W tensor P_W)]

This thin wrapper applies the m_rep prefactor to `mult_aware_beta_S` at the
call site. At m_rep = 1 it reduces to `mult_aware_beta_S` exactly, hence the
strict-generalization regression on lemma1_general_S_verification.jl is
preserved. At m_rep >= 2 it cancels the (1/m_rep)^2 scaling of
rho_inv tensor rho_inv to recover the universal endpoint 1/(2F+1) at S = 0.
"""
canonical_mult_aware_beta_S(rho_inv::AbstractMatrix, F::Int, S::Int, m_rep::Int) =
    m_rep * mult_aware_beta_S(rho_inv, F, S)

"""
    verify_case_mult_aware(F::Int, group::Symbol, irrep::Symbol;
                           seeds::AbstractRange=1:10, tol::Real=1e-8)

Driver mirroring `verify_case` but using the projector-orbit-average
density-matrix formulation. Records per-seed bar_beta_0 for the F2
seed-independence falsifier.

The orbit-averaged density matrix rho_inv = (1/m_rep) sum_i |ζ_i><ζ_i|
is provably seed-independent by Schur's lemma on the multiplicity space:
any unitary mixing U ∈ U(m_rep) of the basis {ζ_i} leaves rho_inv invariant.
The `seeds` parameter perturbs the basis by a small seeded random kick before
re-orthonormalization; the orbit-average MUST be invariant to machine precision.
"""
function verify_case_mult_aware(F::Int, group::Symbol, irrep::Symbol;
    seeds::AbstractRange=1:10, tol::Real=1e-8)
    @printf("\n%s\n", "─"^70)
    @printf("F=%d  %s:%s  (mult-aware: projector-orbit average)\n", F, group, irrep)
    @printf("%s\n", "─"^70)

    D = 2F + 1
    Fx, Fy, Fz = spin_matrices_general(F)

    gens = group == :T ? tetrahedral_gen(F) : octahedral_gen(F)
    expected_order = group == :T ? 12 : 24
    G = group_close(gens, 1e-6, expected_order + 20)
    @printf("Group order: %d (expected %d)\n", length(G), expected_order)

    chars = group == :T ? compute_T_character(G, irrep) : compute_O_character(G, irrep)
    P = project_onto_irrep(G, chars)

    base_basis, m_rep = find_invariant_basis(P, D; tol=tol)
    @printf("m_rep (numerical rank of P at tol=%.0e): %d\n", tol, m_rep)
    @printf("m_rep_value: %d\n", m_rep)

    # Build the base orbit-averaged density matrix.
    function build_rho_inv(basis)
        rho = zeros(ComplexF64, D, D)
        for ζ in basis
            rho .+= ζ * ζ'
        end
        return rho / length(basis)
    end

    # Helper: re-randomize the basis via Schur lemma (any U(m_rep) mixing leaves
    # rho_inv invariant). Implementation: apply a seeded random kick to the
    # base basis vectors and re-orthonormalize. This tests the implementation
    # claim that rho_inv is basis-choice-independent.
    function seeded_basis(seed::Int)
        Random.seed!(seed)
        # Add small random kicks within Im(P) by perturbing within the basis subspace
        kicked = [copy(ζ) for ζ in base_basis]
        for i in 1:m_rep
            # Generate a random complex linear combination of base_basis vectors
            coeffs = randn(ComplexF64, m_rep)
            mix = zeros(ComplexF64, D)
            for j in 1:m_rep
                mix .+= coeffs[j] * base_basis[j]
            end
            # Add the mix as a perturbation (still within Im(P))
            kicked[i] = base_basis[i] + 0.5 * mix
        end
        # Re-orthonormalize via Gram-Schmidt
        for i in 1:m_rep
            for j in 1:(i - 1)
                kicked[i] -= (kicked[j]' * kicked[i]) * kicked[j]
            end
            nrm = norm(kicked[i])
            nrm > 0 || error("seeded Gram-Schmidt collapsed at i=$i (seed=$seed)")
            kicked[i] /= nrm
        end
        return kicked
    end

    expected_beta_0 = 1.0 / (2F + 1)

    # F2: seed-independence sweep
    bar_beta_0_per_seed = Float64[]
    for seed in seeds
        basis_s = seeded_basis(seed)
        rho_s = build_rho_inv(basis_s)
        b0 = mult_aware_beta_S(rho_s, F, 0)
        push!(bar_beta_0_per_seed, b0)
        @printf("  seed %d: bar_beta_0 = %.15f\n", seed, b0)
    end
    seed_spread = maximum(bar_beta_0_per_seed) - minimum(bar_beta_0_per_seed)
    @printf("seed_spread_max_min: %.3e\n", seed_spread)

    # Canonical orbit-average (use the base, non-perturbed basis)
    rho_inv = build_rho_inv(base_basis)
    @printf("rho_inv Hermitian deviation: %.3e\n", maximum(abs.(rho_inv - rho_inv')))
    @printf("rho_inv trace: %.15f (expected 1.0)\n", real(tr(rho_inv)))

    bar_beta_0 = mult_aware_beta_S(rho_inv, F, 0)
    dev_from_canonical = abs(bar_beta_0 - expected_beta_0)
    @printf("bar_beta_0_value: %.15f\n", bar_beta_0)
    @printf("expected (1/(2F+1)=1/%d): %.15f\n", 2F + 1, expected_beta_0)
    @printf("bar_beta_0_dev_from_1_over_%d: %.3e\n", 2F + 1, dev_from_canonical)

    # Schur isotropy of rho_inv
    iso_x = real(tr(rho_inv * (Fx * Fx)))
    iso_y = real(tr(rho_inv * (Fy * Fy)))
    iso_z = real(tr(rho_inv * (Fz * Fz)))
    iso_target = F * (F + 1) / 3
    @printf("schur_isotropy_rho_inv_x: %.15f (expected %.15f)\n", iso_x, iso_target)
    @printf("schur_isotropy_rho_inv_y: %.15f (expected %.15f)\n", iso_y, iso_target)
    @printf("schur_isotropy_rho_inv_z: %.15f (expected %.15f)\n", iso_z, iso_target)
    @printf("Schur isotropy max-deviation: %.3e\n",
        max(abs(iso_x - iso_target), abs(iso_y - iso_target), abs(iso_z - iso_target)))

    # Full bar_beta_S table
    @printf("\nbar_beta_S^{c_0} table (mult-aware orbit average):\n")
    for S in 0:2:2F
        b = mult_aware_beta_S(rho_inv, F, S)
        marker = abs(b) < 1e-12 ? "  (≈0, excluded)" : ""
        @printf("  S=%2d: bar_beta_S = %.15f%s\n", S, b, marker)
    end

    # Verdicts
    f1_verdict = if dev_from_canonical < 1e-13
        "CORROBORATE"
    elseif dev_from_canonical < 1e-6
        "INCONCLUSIVE"
    else
        "REFUTED"
    end
    f2_verdict = if seed_spread < 1e-13
        "CORROBORATE"
    elseif seed_spread < 1e-10
        "ADVISORY_PASS"
    else
        "REFUTED"
    end
    @printf("\nF1 verdict (|bar_beta_0 - 1/%d| < 1e-13): %s\n", 2F + 1, f1_verdict)
    @printf("F2 verdict (seed_spread < 1e-13): %s\n", f2_verdict)

    return (
        m_rep=m_rep,
        bar_beta_0=bar_beta_0,
        dev=dev_from_canonical,
        seed_spread=seed_spread,
        iso_x=iso_x,
        iso_y=iso_y,
        iso_z=iso_z,
        f1_verdict=f1_verdict,
        f2_verdict=f2_verdict,
        bar_beta_0_per_seed=bar_beta_0_per_seed,
    )
end

function verify_case(F::Int, group::Symbol, irrep::Symbol)
    @printf("\n%s\n", "─"^70)
    @printf("F=%d  %s:%s\n", F, group, irrep)
    @printf("%s\n", "─"^70)

    D = 2F + 1
    Fx, Fy, Fz = spin_matrices_general(F)

    gens = group == :T ? tetrahedral_gen(F) : octahedral_gen(F)
    expected_order = group == :T ? 12 : 24
    G = group_close(gens, 1e-6, expected_order + 20)
    @printf("Group order: %d (expected %d)\n", length(G), expected_order)

    chars = group == :T ? compute_T_character(G, irrep) : compute_O_character(G, irrep)
    char_sum = sum(chars)
    @printf("Character sum: %s\n", string(round(char_sum; digits=6)))

    P = project_onto_irrep(G, chars)
    ζ = find_invariant_vector(P, D)

    if ζ === nothing
        @printf("[NO INVARIANT VECTOR FOUND] — multiplicity = 0 OR projector issue\n")
        return nothing
    end

    max_dev = maximum(norm(g * ζ - chars[i] * ζ) for (i, g) in enumerate(G))
    @printf("Equivariance max ||g·ζ - χ(g)·ζ||: %.2e\n", max_dev)

    if max_dev > 1e-7
        @printf("[EQUIVARIANCE FAILED]\n")
        return nothing
    end

    F2 = real(ζ' * (Fx*Fx + Fy*Fy + Fz*Fz) * ζ)
    Fx2 = real(ζ' * (Fx*Fx) * ζ)
    Fy2 = real(ζ' * (Fy*Fy) * ζ)
    Fz2 = real(ζ' * (Fz*Fz) * ζ)
    schur_dev = max(abs(Fx2 - F2/3), abs(Fy2 - F2/3), abs(Fz2 - F2/3))
    Fx_m = real(ζ' * Fx * ζ);
    Fy_m = real(ζ' * Fy * ζ);
    Fz_m = real(ζ' * Fz * ζ)

    @printf("⟨F²⟩ = %.6f (expected %d)\n", F2, F*(F+1))
    @printf("Schur isotropy deviation: %.2e\n", schur_dev)
    @printf("⟨F⟩ = (%.2e, %.2e, %.2e)\n", Fx_m, Fy_m, Fz_m)

    @printf("ζ support m ∈ {")
    for m in F:-1:(-F)
        i = F - m + 1
        if abs(ζ[i]) > 1e-6
            @printf("%d ", m)
        end
    end
    @printf("}\n")

    excluded = Int[]
    @printf("β_S^{c_0}: ")
    for S in 0:2:2F
        β = project_S_channel(ζ, F, S)
        if abs(β) < 1e-6
            push!(excluded, S)
            @printf("S=%d:0 ", S)
        else
            @printf("S=%d:%.4f ", S, β)
        end
    end
    @printf("\n")
    @printf("Excluded: %s\n", excluded)
    # Verify β_0 = 1/(2F+1) Lemma 1
    β_0 = project_S_channel(ζ, F, 0)
    expected_β_0 = 1.0 / (2F + 1)
    @printf("Lemma 1 (β_0 = 1/(2F+1) = %.6f): actual β_0 = %.6f, dev = %.2e %s\n",
        expected_β_0, β_0, abs(β_0 - expected_β_0),
        abs(β_0 - expected_β_0) < 1e-6 ? "✓" : "✗")
end

@printf("F=9, F=11 odd-F polyhedral verification\n")
@printf("Paper #6 F-systematic completion (post-修論 D 論 Year 1 Q3)\n")

cases = [
    # F=9
    (9, :T, :A),
    (9, :O, :A_1),
    (9, :O, :A_2),
    # F=11
    (11, :T, :A),
    (11, :O, :A_2),
]

for (F, grp, irrep) in cases
    verify_case(F, grp, irrep)
end

@printf("\n%s\n", "="^70)
@printf("F=9 / F=11 verification complete.\n")
@printf("%s\n", "="^70)

# =====================================================================
# T115: multiplicity-aware projector-orbit-average fix for F=9 T:A
# (theorist turn_114 §2.A; implementer directive turn_115).
# Closes the 2e-4 residual in the rank-1 verify_case(9, :T, :A) above.
# =====================================================================
@printf("\n%s\n", "="^70)
@printf("MULTIPLICITY-AWARE VERIFICATION (T115 §2.A projector-orbit average)\n")
@printf("%s\n", "="^70)

ma_result = verify_case_mult_aware(9, :T, :A; seeds=1:10, tol=1e-8)

# =====================================================================
# T115-attempt2: Candidate (i) revised §2.A with m_rep prefactor
# (theorist turn_115 §2.B recommendation).
#   bar_beta_S_canonical = m_rep * mult_aware_beta_S(rho_inv, F, S)
# F1 (central) expects |bar_beta_0_canonical - 1/19| < 1e-13 at F=9 T:A.
# F2 (advisory) expects seed_spread < 1e-13.
# F4 (advisory sum-rule) expects Sum_{S in 0:2F} bar_beta_S_canonical ≈ m_rep.
# =====================================================================
@printf("\n%s\n", "="^70)
@printf("T115-attempt2: CANDIDATE (i) — m_rep prefactor Candidate (i) test\n")
@printf("    bar_beta_0_canonical = m_rep * mult_aware_beta_S(rho_inv, F, 0)\n")
@printf("%s\n", "="^70)

let F = 9, group = :T, irrep = :A, seeds = 1:10, tol = 1e-8
    D = 2F + 1
    gens = group == :T ? tetrahedral_gen(F) : octahedral_gen(F)
    expected_order = group == :T ? 12 : 24
    G = group_close(gens, 1e-6, expected_order + 20)
    chars = group == :T ? compute_T_character(G, irrep) : compute_O_character(G, irrep)
    P = project_onto_irrep(G, chars)
    base_basis, m_rep = find_invariant_basis(P, D; tol=tol)
    @printf("m_rep_at_F9_TA: %d\n", m_rep)

    function build_rho_inv(basis)
        rho = zeros(ComplexF64, D, D)
        for ζ in basis
            rho .+= ζ * ζ'
        end
        return rho / length(basis)
    end

    function seeded_basis(seed::Int)
        Random.seed!(seed)
        kicked = [copy(ζ) for ζ in base_basis]
        for i in 1:m_rep
            coeffs = randn(ComplexF64, m_rep)
            mix = zeros(ComplexF64, D)
            for j in 1:m_rep
                mix .+= coeffs[j] * base_basis[j]
            end
            kicked[i] = base_basis[i] + 0.5 * mix
        end
        for i in 1:m_rep
            for j in 1:(i - 1)
                kicked[i] -= (kicked[j]' * kicked[i]) * kicked[j]
            end
            nrm = norm(kicked[i])
            nrm > 0 || error("seeded Gram-Schmidt collapsed at i=$i (seed=$seed)")
            kicked[i] /= nrm
        end
        return kicked
    end

    expected_endpoint = 1.0 / (2F + 1)

    # F1 central: canonical formula at base basis
    rho_inv = build_rho_inv(base_basis)
    bar_beta_0_canonical = canonical_mult_aware_beta_S(rho_inv, F, 0, m_rep)
    dev_from_endpoint = abs(bar_beta_0_canonical - expected_endpoint)
    @printf("bar_beta_0_canonical_F9_TA: %.16f\n", bar_beta_0_canonical)
    @printf("expected 1/(2F+1) = 1/%d: %.16f\n", 2F + 1, expected_endpoint)
    @printf("bar_beta_0_canonical_dev_from_1_over_2F_plus_1: %.3e\n", dev_from_endpoint)

    # F2 advisory: seed-spread of the canonical formula
    per_seed = Float64[]
    for seed in seeds
        basis_s = seeded_basis(seed)
        rho_s = build_rho_inv(basis_s)
        push!(per_seed, canonical_mult_aware_beta_S(rho_s, F, 0, m_rep))
    end
    seed_spread = maximum(per_seed) - minimum(per_seed)
    @printf("seed_spread_F9_TA_canonical: %.3e\n", seed_spread)
    for (i, b) in enumerate(per_seed)
        @printf("  seed %d: bar_beta_0_canonical = %.16f\n", i, b)
    end

    # F4 advisory: full sum over ALL S (0:2F), not just 0:2:2F.
    # Even S contributions come from symmetric part of |zeta_i tensor zeta_j>;
    # odd S contributions come from antisymmetric off-diagonal (i != j) part.
    full_sum = 0.0
    even_sum = 0.0
    @printf("\nbar_beta_S_canonical table (ALL S, 0:2F):\n")
    for S in 0:(2F)
        b_canonical = canonical_mult_aware_beta_S(rho_inv, F, S, m_rep)
        full_sum += b_canonical
        if S % 2 == 0
            even_sum += b_canonical
        end
        marker = abs(b_canonical) < 1e-12 ? "  (≈0)" : ""
        parity = S % 2 == 0 ? "even" : "odd"
        @printf("  S=%2d (%s): bar_beta_S_canonical = %.15f%s\n", S, parity, b_canonical, marker)
    end
    @printf("sum_S_all_S_at_F9_TA_canonical: %.15f (expected ≈ m_rep = %d)\n",
        full_sum, m_rep)
    @printf("sum_S_even_S_partial_at_F9_TA_canonical: %.15f\n", even_sum)

    # Verdicts
    f1_verdict = if dev_from_endpoint < 1e-13
        "CORROBORATE"
    elseif dev_from_endpoint < 1e-6
        "INCONCLUSIVE"
    else
        "REFUTED"
    end
    f2_verdict = if seed_spread < 1e-13
        "CORROBORATE"
    elseif seed_spread < 1e-10
        "ADVISORY_PASS"
    else
        "REFUTED"
    end
    f4_dev_from_m_rep = abs(full_sum - m_rep)
    f4_verdict = if f4_dev_from_m_rep < 1e-12
        "CORROBORATE"
    elseif f4_dev_from_m_rep < 1e-6
        "ADVISORY_PASS"
    else
        "REFUTED"
    end
    @printf("\nF1 verdict (|bar_beta_0_canonical - 1/19| < 1e-13): %s\n", f1_verdict)
    @printf("F2 verdict (seed_spread_canonical < 1e-13): %s\n", f2_verdict)
    @printf("F4 verdict (|sum_S_all_S - m_rep| < 1e-12): %s (dev = %.3e)\n",
        f4_verdict, f4_dev_from_m_rep)
end

# =====================================================================
# F3 regression: the 29-channel mult-1 closed-form must still PASS.
# include() runs the standalone regression script untouched.
# =====================================================================
@printf("\n%s\n", "="^70)
@printf("F3 REGRESSION: lemma1_general_S_verification.jl\n")
@printf("%s\n", "="^70)
include(joinpath(@__DIR__, "test_lemma1_general_S.jl"))
