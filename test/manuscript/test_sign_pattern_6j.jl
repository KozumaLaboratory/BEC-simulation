# Sign Pattern Systematic — Wigner-Eckart 6j numerical analysis (Strategy A Step 4)
#
# For each paper3 polyhedral inert state, compute the 2-body channel-S projections
# of the "rotated" spinor F_a ζ ⊗ ζ and F_a ζ ⊗ F_a ζ. These build the structural
# decomposition of β_S^{λ_spin}:
#
#   β_S^{λ_spin} ∝ [⟨S | F_a ζ ⊗ F_a ζ⟩ · ⟨ζ ⊗ ζ | S⟩]_anomalous
#                - 2 · |⟨S | F_a ζ ⊗ ζ⟩|²_HF
#                + (subleading)
#
# Sign pattern in S emerges from the competition. Tabulate explicitly for paper3 cases
# F = 3, 4, 6, 8, 10 and compare to paper3 stated β_S^{λ_spin} signs.

using SpinorBEC
using LinearAlgebra
using Printf
using Random

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

function octahedral_gen(F::Int)
    C4z = wigner_D(F, [0.0, 0.0, 1.0], π/2)
    C3 = wigner_D(F, [1.0, 1.0, 1.0] / sqrt(3), 2π/3)
    return [C4z, C3]
end

function icosahedral_gen(F::Int)
    phi_g = (1 + sqrt(5)) / 2
    theta_3 = acos((1 + phi_g) / sqrt(3 * (1 + phi_g^2)))
    az_3 = π / 5
    C5z = wigner_D(F, [0.0, 0.0, 1.0], 2π/5)
    C3 = wigner_D(F, [sin(theta_3) * cos(az_3), sin(theta_3) * sin(az_3), cos(theta_3)], 2π/3)
    return [C5z, C3]
end

function build_polyhedral_spinor(F::Int, group::Symbol, irrep::Symbol)
    G = group == :O ? group_close(octahedral_gen(F)) : group_close(icosahedral_gen(F))
    # Compute characters as in paper3_audit.jl
    chars = zeros(Float64, length(G))
    D_size = size(G[1])

    for (i, g) in enumerate(G)
        is_I = norm(g - Matrix{ComplexF64}(I, D_size...)) < 1e-7
        g3 = g * g * g
        is_C3 = norm(g3 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
        g2 = g * g
        is_C2 = norm(g2 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
        g4 = g3 * g
        is_C4 = norm(g4 - Matrix{ComplexF64}(I, D_size...)) < 1e-7

        if group == :O
            if is_I
                chars[i] = 1.0
            elseif is_C3
                chars[i] = 1.0
            elseif is_C4
                chars[i] = irrep == :A_1 ? 1.0 : -1.0
            elseif is_C2
                chars[i] = NaN  # refine below
            end
        elseif group == :I
            chars[i] = 1.0  # only A irrep
        end
    end

    if group == :O
        order4_squares = Matrix{ComplexF64}[]
        for g in G
            g2 = g * g
            if norm(g2 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
                continue
            end
            g4 = g2 * g2
            if norm(g4 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
                push!(order4_squares, g2)
            end
        end
        for i in 1:length(G)
            if isnan(chars[i])
                g = G[i]
                is_axial = any(norm(g - sq) < 1e-7 for sq in order4_squares)
                if irrep == :A_1
                    chars[i] = 1.0
                elseif irrep == :A_2
                    chars[i] = is_axial ? 1.0 : -1.0
                end
            end
        end
    end

    # Project
    P = sum(chars[i] * G[i] for i in 1:length(G)) / length(G)
    Random.seed!(42)
    for seed in 1:30
        Random.seed!(seed)
        v = randn(ComplexF64, 2F+1)
        ζ_proj = P * v
        if norm(ζ_proj) > 1e-6
            return ζ_proj / norm(ζ_proj)
        end
    end
    error("Cannot find $irrep invariant vector")
end

# ⟨S M | ζ1 ⊗ ζ2⟩ for all M; returns Vector{Complex}
function project_2body(ζ1::Vector, ζ2::Vector, F::Int, S::Int)
    amps = ComplexF64[]
    for M in (-S):S
        amp = 0.0im
        for m1 in (-F):F
            m2 = M - m1
            if -F <= m2 <= F
                cg = clebsch_gordan(F, m1, F, m2, S, M)
                i1 = F - m1 + 1
                i2 = F - m2 + 1
                amp += cg * ζ1[i1] * ζ2[i2]
            end
        end
        push!(amps, amp)
    end
    return amps
end

# β_S^{c_0} = |⟨S | ζ⊗ζ⟩|² (sum over M)
function beta_S_c0(ζ::Vector, F::Int, S::Int)
    return sum(abs2, project_2body(ζ, ζ, F, S))
end

# Sign Pattern structural quantity:
#   X_S = ⟨S | F_a ζ ⊗ F_a ζ⟩² / ||F_a ζ||⁴ (rotated projection)
#   compared to β_S^{c_0} = ⟨S | ζ ⊗ ζ⟩²
# These reflect the anomalous + HF contributions to β_S^{λ_spin}.
function sign_pattern_decomposition(ζ::Vector, F::Int)
    D = 2F + 1
    Fx, Fy, Fz = spin_matrices_general(F)

    # Use F_z direction (will be Schur-equivalent to F_x, F_y for polyhedral inert)
    F_a_ζ = Fz * ζ
    norm_Fz = norm(F_a_ζ)
    F_a_ζ_normalized = F_a_ζ / norm_Fz

    println("    F_z direction (||F_z ζ||² = $(real(F_a_ζ' * F_a_ζ)))")

    for S in 0:2:2F
        # β_S^{c_0} = ⟨S | ζ⊗ζ⟩²
        proj_ζζ = project_2body(ζ, ζ, F, S)
        β_c0 = sum(abs2, proj_ζζ)

        # ⟨S | F_a ζ ⊗ ζ⟩² (HF-like contribution)
        proj_Faζζ = project_2body(F_a_ζ_normalized, ζ, F, S)
        X_HF = sum(abs2, proj_Faζζ)

        # ⟨S | F_a ζ ⊗ F_a ζ⟩ · ⟨ζ⊗ζ | S⟩ (anomalous-like)
        proj_FaζFaζ = project_2body(F_a_ζ_normalized, F_a_ζ_normalized, F, S)
        X_anom = real(sum(proj_FaζFaζ .* conj.(proj_ζζ)))

        # Sign Pattern heuristic: estimate sign(β_S^{λ_spin})
        # Build structural quantity that should correlate with β_S^{λ_spin} sign
        # Approximation: β_S^{λ_spin} ∝ X_HF - X_anom (HF positive, anom negative for low S)
        structural = X_HF - X_anom
        sign_str = abs(structural) < 1e-10 ? "0" : (structural > 0 ? "+" : "−")

        @printf("    S=%2d  β_c0=%.5f  X_HF=%.5f  X_anom=%+.5f  HF-anom=%+.5f  sign=%s\n",
            S, β_c0, X_HF, X_anom, structural, sign_str)
    end
end

cases = [
    (3, :O, :A_2, "F=3 octa A_2", "paper3 §V.B"),
    (4, :O, :A_1, "F=4 cube", "paper3 §V.C"),
    (6, :I, :A, "F=6 icosa", "paper3 §V.D"),
    (8, :O, :A_1, "F=8 cube-octa Dy", "paper3 §V.E"),
    (10, :I, :A, "F=10 dodec", "paper3 §V.F"),
]

# Reference: paper3 stated β_S^{λ_spin} signs (S, sign)
paper3_signs = Dict(
    3 => Dict(0=>-1, 4=>-1, 6=>+1),
    4 => Dict(0=>-1, 4=>-1, 6=>+1, 8=>+1),
    6 => Dict(0=>-1, 6=>-1, 10=>+1, 12=>+1),
    8 => Dict(0=>-1, 4=>-1, 6=>-1, 8=>-1, 10=>-1, 12=>+1, 14=>+1, 16=>+1),
    10 => Dict(0=>-1, 6=>-1, 10=>-1, 12=>-1, 16=>+1, 18=>+1, 20=>+1),
)

println("="^80)
println("Sign Pattern Systematic — 6j numerical analysis")
println("="^80)

for (F, grp, irrep, label, ref) in cases
    println()
    println("─"^80)
    @printf("Case: %s [%s]\n", label, ref)
    println("─"^80)
    ζ = build_polyhedral_spinor(F, grp, irrep)
    @printf("Spinor support m ∈ {")
    for m in F:-1:(-F)
        i = F - m + 1
        if abs(ζ[i]) > 1e-6
            print("$m, ")
        end
    end
    println("}")
    sign_pattern_decomposition(ζ, F)

    # Compare with paper3 signs
    @printf("\n    paper3 stated β_S^{λ_spin} signs: ")
    for S in sort(collect(keys(paper3_signs[F])))
        sgn = paper3_signs[F][S]
        @printf("S=%d:%s ", S, sgn>0 ? "+" : "−")
    end
    println()
end

println()
println("="^80)
println("Sign Pattern 6j analysis complete.")
println("="^80)
