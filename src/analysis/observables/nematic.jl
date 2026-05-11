# --- Rank-2 nematic tensor + biaxiality ---
#
# Traceless rank-2 nematic tensor eigenvalue decomposition + biaxiality
# parameter. Used for nematic-class phase classification (BN, polar, etc).

export nematic_tensor_eigenvalues, biaxiality_parameter

"""
    nematic_tensor_eigenvalues(psi, sm, ndim; density_cutoff=1e-10)

Compute eigenvalues of the traceless nematic tensor at each grid point.

The rank-2 nematic tensor is N_{ab} = ⟨(F_a F_b + F_b F_a)/2⟩/n - F(F+1)/3 δ_{ab}.
Returns three N-dim arrays (lambda1, lambda2, lambda3) sorted lambda1 >= lambda2 >= lambda3.
"""
function nematic_tensor_eigenvalues(
    psi::AbstractArray{<:Complex},
    sm::SpinMatrices{D},
    ndim::Int;
    density_cutoff::Float64=1e-10,
) where {D}
    n_pts = ntuple(d -> size(psi, d), ndim)
    F = sm.system.F
    shift = F * (F + 1) / 3.0

    Fx = Matrix{ComplexF64}(sm.Fx)
    Fy = Matrix{ComplexF64}(sm.Fy)
    Fz = Matrix{ComplexF64}(sm.Fz)
    F_mats = (Fx, Fy, Fz)

    sym_prods = Matrix{ComplexF64}[]
    for a in 1:3
        for b in a:3
            push!(sym_prods, (F_mats[a] * F_mats[b] + F_mats[b] * F_mats[a]) / 2)
        end
    end

    l1 = zeros(Float64, n_pts)
    l2 = zeros(Float64, n_pts)
    l3 = zeros(Float64, n_pts)

    @inbounds for I in CartesianIndices(n_pts)
        n_local = sum(c -> abs2(psi[I, c]), 1:D)
        if n_local < density_cutoff
            continue
        end
        inv_n = 1.0 / n_local

        nab = zeros(Float64, 3, 3)
        idx = 0
        for a in 1:3
            for b in a:3
                idx += 1
                val = 0.0
                for j in 1:D
                    for k in 1:D
                        val += real(conj(psi[I, j]) * sym_prods[idx][j, k] * psi[I, k])
                    end
                end
                val = val * inv_n - (a == b ? shift : 0.0)
                nab[a, b] = val
                nab[b, a] = val
            end
        end

        evals = eigvals(Symmetric(nab))
        l1[I] = evals[3]
        l2[I] = evals[2]
        l3[I] = evals[1]
    end

    (l1, l2, l3)
end

"""
    biaxiality_parameter(lambda1, lambda2, lambda3)

Biaxiality parameter β = (λ₂ - λ₃) / (λ₁ - λ₃ + ε).
0 = uniaxial, 1 = maximally biaxial.
"""
function biaxiality_parameter(lambda1, lambda2, lambda3)
    @. (lambda2 - lambda3) / (lambda1 - lambda3 + eps(Float64))
end
