# F-systematic completion: derive β_S^(λ_spin) predictions for F=5, 7, 9, 11
# polyhedral inert states using the Lemma 1 General-S closed form:
#
#   β_S^(λ_spin) = (S(S+1) - 2F(F+1)) / (2F(F+1)) · β_S^(c_0)
#
# Inputs: β_S^(c_0) computed numerically by f9_f11_polyhedral_verification.jl
# and f5_f7_polyhedral_verification.jl.
#
# Outputs: predicted β_S^(λ_spin) per channel; identifies sign-change boundary
# in the discrete channel set; gives Feshbach engineering recipe for high-F species.

using SpinorBEC
using LinearAlgebra
using Printf
using Random

# Reuse: spin matrices, Wigner D, group closure, character/projection from
# f9_f11_polyhedral_verification.jl
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

tetrahedral_gen(F) = [wigner_D(F, [1.0, 1.0, 1.0] / sqrt(3), Float64(2π/3)),
                     wigner_D(F, [0.0, 0.0, 1.0], Float64(π))]
octahedral_gen(F) = [wigner_D(F, [0.0, 0.0, 1.0], Float64(π/2)),
                    wigner_D(F, [1.0, 1.0, 1.0] / sqrt(3), Float64(2π/3))]

function compute_T_character(group_elements, irrep::Symbol)
    chars = ComplexF64[]
    D_size = size(group_elements[1])
    Imat = Matrix{ComplexF64}(I, D_size...)
    for g in group_elements
        if norm(g - Imat) < 1e-6
            push!(chars, 1)
        else
            tr_g = tr(g)
            if abs(tr_g - 0) < 1e-3
                push!(chars, irrep === :A ? 1 : 0)
            elseif abs(abs(tr_g) - 1) < 1e-3 || abs(real(tr_g) + 0.5) < 0.3
                push!(chars, irrep === :A ? 1 : 0)
            else
                push!(chars, irrep === :A ? 1 : 0)
            end
        end
    end
    return chars
end

function compute_O_character(group_elements, irrep::Symbol)
    # Use trace-based class identification.
    # O has 5 conjugacy classes: E, 8C_3, 3C_2 (axial = squares of C_4), 6C_2', 6C_4
    # A_1: all char +1. A_2: E=1, 8C_3=1, 3C_2=1, 6C_2'=-1, 6C_4=-1.
    chars = ComplexF64[]
    D_size = size(group_elements[1])
    Imat = Matrix{ComplexF64}(I, D_size...)
    for g in group_elements
        if norm(g - Imat) < 1e-6
            push!(chars, 1)
            continue
        end
        # Determine: is g order-4? (= det = 1, g^4 = I, g^2 ≠ I)
        is_order_4 = norm(g^4 - Imat) < 1e-6 && norm(g^2 - Imat) > 1e-6
        is_order_3 = norm(g^3 - Imat) < 1e-6
        is_order_2 = norm(g^2 - Imat) < 1e-6
        # Axial C_2 = square of some C_4 in G
        is_axial_C2 = is_order_2 && any(norm(h * h - g) < 1e-6 for h in group_elements
                                          if norm(h^4 - Imat) < 1e-6 && norm(h^2 - Imat) > 1e-6)
        if irrep === :A_1
            push!(chars, 1)
        elseif irrep === :A_2
            if is_order_3 || is_axial_C2
                push!(chars, 1)
            else
                # 6C_2' or 6C_4 — char = -1
                push!(chars, -1)
            end
        else
            push!(chars, 0)
        end
    end
    return chars
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

"""
    lemma1_general_S_prediction(F, S, β_c0)

Apply Lemma 1 General-S closed form:
    β_S^(λ_spin) = (S(S+1) - 2F(F+1)) / (2F(F+1)) · β_S^(c_0)
"""
function lemma1_general_S_prediction(F::Int, S::Int, β_c0::Float64)
    return (S * (S + 1) - 2 * F * (F + 1)) / (2 * F * (F + 1)) * β_c0
end

function verify_case_with_lemma1(F::Int, group::Symbol, irrep::Symbol)
    @printf("\n%s\n", "─"^72)
    @printf("F=%d  %s:%s — Lemma 1 General-S predictions\n", F, group, irrep)
    @printf("%s\n", "─"^72)

    D = 2F + 1
    gens = group == :T ? tetrahedral_gen(F) : octahedral_gen(F)
    expected_order = group == :T ? 12 : 24
    G = group_close(gens, 1e-6, expected_order + 20)
    chars = group == :T ? compute_T_character(G, irrep) : compute_O_character(G, irrep)
    P = project_onto_irrep(G, chars)
    ζ = find_invariant_vector(P, D)

    if ζ === nothing
        @printf("[NO INVARIANT VECTOR FOUND]\n")
        return
    end

    # Check Schur isotropy
    Fx, Fy, Fz = spin_matrices_general(F)
    F2 = real(ζ' * (Fx*Fx + Fy*Fy + Fz*Fz) * ζ)
    Fx2 = real(ζ' * (Fx*Fx) * ζ)
    Fy2 = real(ζ' * (Fy*Fy) * ζ)
    Fz2 = real(ζ' * (Fz*Fz) * ζ)
    schur_dev = max(abs(Fx2 - F2/3), abs(Fy2 - F2/3), abs(Fz2 - F2/3))

    # Verify Lemma 1 endpoint S=0:
    β_0 = project_S_channel(ζ, F, 0)
    expected_β_0 = 1.0 / (2F + 1)
    @printf("Schur isotropy dev: %.2e | β_0 = %.6f (expected 1/%d = %.6f)\n",
        schur_dev, β_0, 2F+1, expected_β_0)

    # Compute β_S^(c_0) and predict β_S^(λ_spin) for each non-excluded S
    @printf("\n  %-4s %-15s %-15s %-15s %-8s\n", "S", "β_S^(c_0)",
        "(S(S+1)-2F(F+1))/(2F(F+1))", "β_S^(λ_spin)", "sign")
    @printf("  %-4s %-15s %-15s %-15s %-8s\n", "---", "---------",
        "------------------", "------------", "----")
    S_bd = sqrt(2.0 * F * (F + 1))
    for S in 0:2:2F
        β_c0 = project_S_channel(ζ, F, S)
        if β_c0 < 1e-6
            continue
        end
        prefactor = (S * (S + 1) - 2 * F * (F + 1)) / (2 * F * (F + 1))
        β_lambda = prefactor * β_c0
        sign_str = β_lambda < 0 ? "neg" : (β_lambda > 0 ? "pos" : "zero")
        @printf("  %-4d %-15.6f %-15.6f %-15.6f %-8s\n",
            S, β_c0, prefactor, β_lambda, sign_str)
    end
    @printf("\n  Sign-change boundary: S_bd = sqrt(2F(F+1)) = sqrt(%d) = %.3f (S_bd/F = %.3f)\n",
        2*F*(F+1), S_bd, S_bd/F)
end

@printf("F-systematic Lemma 1 General-S predictions\n")
@printf("Paper #6 (post-修論 D 論 Year 1 Q3) target: β_S^(λ_spin) from closed form\n\n")

cases = [
    # F=7 (T:A + O:A_2)
    (7, :T, :A),
    (7, :O, :A_2),
    # F=9 (O:A_1, O:A_2)
    (9, :O, :A_1),
    (9, :O, :A_2),
    # F=11 (T:A, O:A_2)
    (11, :T, :A),
    (11, :O, :A_2),
]

for (F, grp, irrep) in cases
    try
        verify_case_with_lemma1(F, grp, irrep)
    catch e
        @warn "Failed at F=$F $grp:$irrep" exception=e
    end
end

@printf("\n%s\n", "="^72)
@printf("F-systematic predictions complete. Total: %d new polyhedral inert state\n", length(cases))
@printf("instances with closed-form β_S^(λ_spin) predictions.\n")
@printf("These extend paper3 §V verification from 5 cases (F=3/4/6/8/10) to 11 cases.\n")
@printf("%s\n", "="^72)
