# paper3 v3 — independent audit of polyhedral verifications
#
# Reconstructs each of paper3's polyhedral inert states from scratch via
# group projection, verifies:
#   1. spinor norm + sparsity
#   2. ⟨F²⟩ = F(F+1) exact
#   3. Schur isotropy ⟨F_a²⟩ = F(F+1)/3 for a=x,y,z
#   4. ⟨F⟩ = 0
#   5. group-invariance
#   6. selection rule via β_S^{c0} = ⟨ζ⊗ζ|P_S|ζ⊗ζ⟩
#
# Cases:
#   F=3 octa (O:A_2, Round 5 NEW, paper3 §V.B)
#   F=4 cube (O:A_1, Round 4 NEW, paper3 §V.C)
#   F=6 icosahedral (I:A, Paper #2, paper3 §V.D)
#   F=8 cube-like octa (O:A_1, Round 5 NEW, paper3 §V.E) — Dy
#   F=10 dodecahedral (I:A, Round 4 NEW, paper3 §V.F)
#
# F=2 cyclic + F=12 covered separately (F=2 in Paper #1, F=12 in F12_verification_result.md).

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

# Group generator factories. Return (generators, axis-rotation labels) for projection.
function octahedral_generators(F::Int)
    # O group: C_4 axis (z, 4-fold) + C_3 body diagonal axis
    C4z = wigner_D(F, [0.0, 0.0, 1.0], π/2)
    n_body_diag = [1.0, 1.0, 1.0] / sqrt(3)
    C3 = wigner_D(F, n_body_diag, 2π/3)
    return [C4z, C3]
end

function icosahedral_generators(F::Int)
    phi_g = (1 + sqrt(5)) / 2
    theta_3 = acos((1 + phi_g) / sqrt(3 * (1 + phi_g^2)))
    az_3 = π / 5
    C5z = wigner_D(F, [0.0, 0.0, 1.0], 2π/5)
    C3 = wigner_D(F, [sin(theta_3) * cos(az_3), sin(theta_3) * sin(az_3), cos(theta_3)], 2π/3)
    return [C5z, C3]
end

# Apply representation to a vector, weighted by character (for non-trivial irreps)
# For trivial irrep A_1: χ(g) = 1 for all g, projector = (1/|G|) Σ D(g)
# For A_2 of O: χ(g) = +1 for {e, 8C_3, 3C_2}, -1 for {6C_4, 6C'_2}
#   In our generator basis, distinguish by trace (C_4 has trace = ?, C_3 has trace = ?)
function character_A2_octahedral(g::AbstractMatrix, F::Int)
    # Classify g by trace of corresponding SO(3) element (= trace of D^{F=1} part).
    # F=1 representation trace = 1 + 2cos(θ).
    # For O: angles are 0 (e, χ=3), 2π/3 (8 C_3, χ=0), π/2 (6 C_4, χ=1), π (3 C_2 + 6 C'_2, χ=-1)
    # χ_A2: +1 for e, C_3, C_2(diagonal=3 C_2 of C_4); -1 for C_4, C'_2 (6 face-diagonal C_2's of O)
    # In O = T ⋊ Z_2 with the Z_2 = C_4 outer automorphism:
    # A_2 = +1 on T (12 elements), -1 on T·C_4 (12 elements).
    # The 12 T elements are: e + 8 C_3 + 3 C_2(axis)
    # The 12 C_4 cosets: 6 C_4 + 6 C'_2
    # So χ_A2(g) = +1 iff g ∈ T subgroup.

    # Compute D^{F=1} version of g via repeated tensor contractions...
    # Simpler: compute trace_F1(g) directly from full D^F(g).
    # For F=1, trace = 1 + 2cos(θ) where θ is rotation angle.
    # For F arbitrary, trace = sin((2F+1)θ/2) / sin(θ/2).
    # Inverse: extract θ from F=1 trace gives cos(θ) = (tr_F1 - 1)/2.
    #
    # We don't have direct access to F=1 trace; use the angle invariance:
    # Take det of D^F(g) eigenvalues, etc. Easier: just classify by trace mod symmetry.
    #
    # Method: compute g's spectrum, get phases, recover rotation angle θ.
    eigs = eigvals(g)
    phases = sort(angle.(eigs))  # angles in [-π, π]
    # Smallest non-zero phase magnitude (mod 2π) ≈ θ for unit-rotation part
    # F=1 spectrum: {1, e^{iθ}, e^{-iθ}}, so phases ∈ {0, θ, -θ}
    # F arbitrary: phases are multiples of θ from -Fθ to Fθ
    # Smallest positive phase = θ (assuming θ < 2π/(2F+1))

    # Easier discriminator: check if g satisfies g^3 = I (=> C_3 type, in T) or g^4 = I (=> C_4 type, not in T)
    g3 = g * g * g
    is_C3 = norm(g3 - Matrix{ComplexF64}(I, size(g))) < 1e-7
    g4 = g3 * g
    is_C4 = norm(g4 - Matrix{ComplexF64}(I, size(g))) < 1e-7
    g2 = g * g
    is_C2 = norm(g2 - Matrix{ComplexF64}(I, size(g))) < 1e-7
    is_I = norm(g - Matrix{ComplexF64}(I, size(g))) < 1e-7

    # T elements: e, 8 C_3 (order 3), 3 C_2 (along 4-fold axes, special)
    # Non-T elements: 6 C_4 (order 4), 6 C'_2 (face-diagonal 2-folds, order 2)

    # All elements: order 1 (e), 2 (C_2 or C'_2), 3 (C_3), or 4 (C_4)
    # In T:  order 1 + 8 order-3 + 3 order-2 (= along old 4-fold axes)
    # Not in T: 6 order-4 + 6 order-2 (= face diagonal)

    # Discriminator for order-2 elements:
    # In T, the 3 order-2 elements are the squares of the 6 C_4. C_4^2 acts as -I on F=1 z-component if axis is z.
    # The 6 C'_2 are NOT squares of C_4's; they act on different axes.
    # Numerically harder to distinguish.

    # Pragmatic approach: a known representative of "T" subgroup:
    # T elements = {e, 8 C_3, 3 C_2_principal}. The 3 C_2_principal axes are
    # (1,0,0), (0,1,0), (0,0,1) — i.e., they have trace = -1 in F=1 AND
    # they commute with C_4z. Squares of C_4 axes = π rotations about C_4 axes.
    #
    # The 6 C'_2 axes are (±1,±1,0)/√2 + permutations — face-diagonal 2-folds.

    if is_I
        return +1.0  # e ∈ T
    elseif is_C3
        return +1.0  # C_3 ∈ T
    elseif is_C4
        return -1.0  # C_4 ∈ O\T
    elseif is_C2
        # C_2 might be order-2 in T (3 elements) or order-2 in O\T (6 elements).
        # T's order-2: along 4-fold axes (x, y, z).
        # O\T's order-2: along face-diagonals.
        # Test: does this order-2 element commute with C_4z?
        # If yes → axis-parallel C_2 (in T).
        # If no → face-diagonal C_2 (in O\T).
        #
        # Skip refined check: count and bin by trace in F=1 component.
        # Both types have F=1 trace = -1 (rotation by π).
        # F=12 trace = (-1)^F = 1 for F=12, depends on F.
        #
        # Refinement via class size: T's 3 C_2 + O\T's 6 C'_2. There are 3 of one and 6 of the other.
        # Just enumerate and split by trace in arbitrary representation? Won't work directly.
        #
        # Cleaner: A_2 has χ = +1 on {e, 8C_3, 3C_2_axial} and -1 on {6C_4, 6C_2_diag}.
        # Total χ over all 24 elements should be 0 (orthogonal to trivial irrep).
        #
        # In our group closure of {C_4z, C_3_body}, we'll iterate and assign by
        # connection with parent elements. Too complex inline.
        #
        # Practical heuristic: assume A_2 character +1 by default for C_2.
        # Then renormalize projector via inner product (won't be 1 if mis-assigned).
        #
        # Better: enumerate group elements with their classes. Build table once.
        return 0.0  # mark ambiguous; do later via class enumeration
    end
    return 0.0
end

# Build characters by enumerating group then sorting by conjugacy class.
function compute_character(group_elements::Vector{<:AbstractMatrix},
    irrep::Symbol, point_group::Symbol, F::Int)
    chars = Vector{Float64}(undef, length(group_elements))
    # Determine each element's conjugacy class by computing its trace in F=1
    # (= the SO(3) trace) and its order

    # F=1 Wigner D from full F=F D: use spin-1 generators
    Fx1, Fy1, Fz1 = spin_matrices_general(1)
    # Each group element g acts via F^F generators; to get F^1 rep we need to identify
    # the rotation (axis, angle) and rebuild. Use eigenstructure.

    for (i, g) in enumerate(group_elements)
        # Find rotation angle θ from F=F spectrum: eigenvalues are {e^{-imθ}, m=-F..F}
        eigs = eigvals(g)
        phases = sort(real.(angle.(eigs)))
        # The phase spacing should be θ. Take diff between consecutive non-degenerate phases.
        # Or simpler: find the minimum positive phase.
        # For F=F representation, smallest positive phase corresponds to θ (assuming θ < 2π/(2F+1)).
        positive_phases = phases[phases .> 1e-10]
        θ = isempty(positive_phases) ? 0.0 : minimum(positive_phases)

        if point_group == :O
            # O classes: e (θ=0), 8C_3 (θ=2π/3), 6C_4 (θ=π/2), 3C_2 axial (θ=π, in T), 6C_2' diag (θ=π, in O\T)
            # Distinguish 3C_2 vs 6C_2': both have θ=π. Differentiate by class size?
            # Build list, count after.
            # Tag preliminarily.
            if abs(θ) < 1e-7
                # identity
                chars[i] = (irrep == :A_1 || irrep == :A_2) ? 1.0 : 0.0
            elseif abs(θ - 2π/3) < 1e-5
                # C_3
                chars[i] = (irrep == :A_1 || irrep == :A_2) ? 1.0 : 0.0
            elseif abs(θ - π/2) < 1e-5
                # C_4
                chars[i] = irrep == :A_1 ? 1.0 : (irrep == :A_2 ? -1.0 : 0.0)
            elseif abs(θ - π) < 1e-5
                # C_2 of some type; need refinement
                chars[i] = NaN  # mark for later
            else
                chars[i] = NaN
            end
        elseif point_group == :I
            # I classes: e (θ=0), 12 C_5 (θ=2π/5), 12 C_5² (θ=4π/5), 20 C_3 (θ=2π/3), 15 C_2 (θ=π)
            # All trivial irrep A: χ = 1 always
            if irrep == :A
                chars[i] = 1.0
            else
                chars[i] = 0.0  # other irreps not supported here
            end
        else
            chars[i] = 0.0
        end
    end

    # Refine NaN entries for O group (C_2 elements)
    if point_group == :O
        c2_indices = findall(isnan, chars)
        if length(c2_indices) == 9
            # 3 axial C_2 (in T, = squares of C_4) + 6 diagonal C_2 (in O\T)
            # Method: axial C_2 = h² for some order-4 h ∈ G; diagonal C_2 is not.
            # Enumerate order-4 elements and collect their squares.
            order4_squares = Matrix{ComplexF64}[]
            D_size = size(group_elements[1])
            for g in group_elements
                g2 = g * g
                if norm(g2 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
                    continue  # order 1 or 2
                end
                g4 = g2 * g2
                if norm(g4 - Matrix{ComplexF64}(I, D_size...)) < 1e-7
                    # order 4 — check g² is order 2 (which it is)
                    push!(order4_squares, g2)
                end
            end
            for i in c2_indices
                g = group_elements[i]
                # is_axial = g is square of some order-4 element
                is_axial = any(norm(g - sq) < 1e-7 for sq in order4_squares)
                if irrep == :A_1
                    chars[i] = 1.0
                elseif irrep == :A_2
                    chars[i] = is_axial ? 1.0 : -1.0
                end
            end
        end
    end

    return chars
end

function project_onto_irrep(ψ::Vector, group_elements::Vector{<:AbstractMatrix},
    chars::Vector{Float64})
    P =
        sum(chars[i] * group_elements[i] * ψ for i in 1:length(group_elements)) /
        length(group_elements)
    return P
end

# Build interaction projection coefficient β_S^{c_0} = ⟨ζ⊗ζ|P_S|ζ⊗ζ⟩
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

function audit_case(F::Int, group::Symbol, irrep::Symbol, label::String,
    paper3_excluded::Vector{Int}, paper3_section::String)
    @printf("\n%s\n", "="^70)
    @printf("AUDIT: F=%d, %s phase (%s:%s) — paper3 %s\n", F, label, group, irrep, paper3_section)
    @printf("%s\n", "="^70)

    D = 2F + 1
    Smax = 2F

    Fx, Fy, Fz = spin_matrices_general(F)

    # Build group
    gens = group == :O ? octahedral_generators(F) : icosahedral_generators(F)
    expected_order = group == :O ? 24 : 60
    G = group_close(gens, 1e-6, expected_order + 20)
    @printf("Group order: %d (expected %d)\n", length(G), expected_order)
    if length(G) != expected_order
        @warn "Group closure failed for $label"
        return nothing
    end

    # Characters
    chars = compute_character(G, irrep, group, F)
    nan_count = count(isnan, chars)
    if nan_count > 0
        @warn "Character computation has $nan_count NaN entries"
        return nothing
    end
    @printf("Character sum: %.2f (should be 0 for non-trivial, |G|=%d for trivial)\n",
        sum(chars), expected_order)

    # Projection
    Random.seed!(42)
    ψ_random = randn(ComplexF64, D)
    ζ = project_onto_irrep(ψ_random, G, chars)
    proj_norm = norm(ζ)
    if proj_norm < 1e-8
        # Try multiple random seeds
        found = false
        for seed in 1:20
            Random.seed!(seed)
            ψ = randn(ComplexF64, D)
            ζ_try = project_onto_irrep(ψ, G, chars)
            if norm(ζ_try) > 1e-6
                ζ = ζ_try
                found = true
                break
            end
        end
        if !found
            @warn "Cannot find $irrep invariant vector (multiplicity = 0)"
            return nothing
        end
    end
    ζ = ζ / norm(ζ)
    @printf("ζ found (||P_irrep v|| > 0).\n")

    # Verify invariance: g·ζ = χ(g)·ζ
    max_dev = 0.0
    for (i, g) in enumerate(G)
        dev = norm(g * ζ - chars[i] * ζ)
        max_dev = max(max_dev, dev)
    end
    @printf("Equivariance check: max ||g·ζ - χ(g)·ζ|| = %.2e\n", max_dev)

    # Structural sanity
    F2 = real(ζ' * (Fx*Fx + Fy*Fy + Fz*Fz) * ζ)
    Fx2 = real(ζ' * (Fx*Fx) * ζ)
    Fy2 = real(ζ' * (Fy*Fy) * ζ)
    Fz2 = real(ζ' * (Fz*Fz) * ζ)
    schur_dev = max(abs(Fx2 - F2/3), abs(Fy2 - F2/3), abs(Fz2 - F2/3))
    Fx_m = real(ζ' * Fx * ζ);
    Fy_m = real(ζ' * Fy * ζ);
    Fz_m = real(ζ' * Fz * ζ)

    @printf("⟨F²⟩ = %.6f (expected %d = F(F+1))\n", F2, F*(F+1))
    @printf("⟨F_a²⟩ = (%.3f, %.3f, %.3f) (Schur: %.3f); deviation %.2e\n",
        Fx2, Fy2, Fz2, F2/3, schur_dev)
    @printf("⟨F⟩ = (%.2e, %.2e, %.2e)\n", Fx_m, Fy_m, Fz_m)

    # Sparsity
    @printf("ζ non-zero m components: ")
    for m in F:-1:(-F)
        i = F - m + 1
        if abs(ζ[i]) > 1e-6
            @printf("%d ", m)
        end
    end
    @printf("\n")

    # Selection rule
    excluded = Int[]
    @printf("β_S^{c0} per channel:\n")
    for S in 0:2:Smax
        β = project_S_channel(ζ, F, S)
        marker = ""
        if abs(β) < 1e-6
            push!(excluded, S)
            marker = " [excluded by harmonics]"
        end
        @printf("  S=%2d: β = %.6f%s\n", S, β, marker)
    end
    @printf("Excluded S channels: %s\n", excluded)
    @printf("paper3 stated exclusion: %s\n", paper3_excluded)
    if Set(excluded) == Set(paper3_excluded)
        @printf("✓ Selection rule MATCHES paper3.\n")
    else
        @printf("✗ Selection rule MISMATCH! Diff = %s\n",
            symdiff(Set(excluded), Set(paper3_excluded)))
    end

    return ζ
end

# Run audits
audit_case(3, :O, :A_2, "octahedral", [2], "§V.B (Round 5 NEW)")
audit_case(4, :O, :A_1, "cube", [2], "§V.C (Round 4 NEW)")
audit_case(6, :I, :A, "icosahedral", [2, 4, 8, 14], "§V.D (Paper #2)")
audit_case(8, :O, :A_1, "cube-like octa", [2], "§V.E (Round 5 NEW, Dy)")
audit_case(10, :I, :A, "dodecahedral", [2, 4, 8, 14], "§V.F (Round 4 NEW)")

@printf("\n%s\n", "="^70)
@printf("paper3 v3 polyhedral cases AUDIT COMPLETE.\n")
@printf("%s\n", "="^70)
