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
    Fz = Diagonal(ComplexF64[F - i for i in 0:D-1])
    Fp = zeros(ComplexF64, D, D)
    for i in 1:(D-1)
        m = F - i
        Fp[i, i+1] = sqrt(F * (F + 1) - m * (m + 1))
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
    P = sum(conj(chars[i]) * group_elements[i] for i in 1:length(group_elements)) / length(group_elements)
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
    for M in -S:S
        amp = 0.0im
        for m1 in -F:F
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
        return
    end

    max_dev = maximum(norm(g * ζ - chars[i] * ζ) for (i, g) in enumerate(G))
    @printf("Equivariance max ||g·ζ - χ(g)·ζ||: %.2e\n", max_dev)

    if max_dev > 1e-7
        @printf("[EQUIVARIANCE FAILED]\n")
        return
    end

    F2 = real(ζ' * (Fx*Fx + Fy*Fy + Fz*Fz) * ζ)
    Fx2 = real(ζ' * (Fx*Fx) * ζ)
    Fy2 = real(ζ' * (Fy*Fy) * ζ)
    Fz2 = real(ζ' * (Fz*Fz) * ζ)
    schur_dev = max(abs(Fx2 - F2/3), abs(Fy2 - F2/3), abs(Fz2 - F2/3))
    Fx_m = real(ζ' * Fx * ζ); Fy_m = real(ζ' * Fy * ζ); Fz_m = real(ζ' * Fz * ζ)

    @printf("⟨F²⟩ = %.6f (expected %d)\n", F2, F*(F+1))
    @printf("Schur isotropy deviation: %.2e\n", schur_dev)
    @printf("⟨F⟩ = (%.2e, %.2e, %.2e)\n", Fx_m, Fy_m, Fz_m)

    @printf("ζ support m ∈ {")
    for m in F:-1:-F
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
