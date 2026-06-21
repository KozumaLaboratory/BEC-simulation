# Trapped non-Hermitian Bogoliubov-de Gennes spectrum — the DYNAMICAL
# stability axis (complex frequency ⇒ exponential growth) for a trapped
# state. Built from the SAME gated `hessian_vector_product` that
# `test_bdg_fd_hessian` anchors to (L_op = δ²E/δψ̄δψ, M_op = δ²E/δψ̄δψ̄), so
# the operator inherits that anchor. The BdG operator matches the
# homogeneous convention in `analysis/phases/bogoliubov.jl` EXACTLY:
#
#   H_BdG = [ L_op − μ        M_op         ]
#           [ −conj(M_op)   −conj(L_op − μ) ]
#
# Eigenvalues ω come in (ω, −conj(ω)) pairs; Im(ω) > tol ⇒ dynamical
# instability. The energetic (Hessian λ_min) gate answers "is ψ a minimum";
# this answers the orthogonal "does a perturbation grow exponentially" — a
# state can be energetically marginal yet dynamically unstable.
#
# Phase 2a: DENSE eigen (LAPACK, non-Hermitian, exact — no iterative
# convergence certificate needed, unlike the energetic Lanczos). Systems
# larger than `dim_cap` exceed dense feasibility and the caller abstains
# (:indeterminate) until the matrix-free Arnoldi (phase 2b) lands — the
# Arnoldi path is where the BdG convergence certificate (targeting the
# imaginary axis + Ritz residual) becomes load-bearing.

export trapped_bdg_spectrum

# L_op·w and M_op·w from the gated HvP via the v/iv real representation:
#   D_w g = 2(L_op w + M_op w̄),  D_{iw} g = 2i(L_op w − M_op w̄)
# ⇒ L_op w = (D_w g − i D_{iw} g)/4,  M_op w = (D_{w̄} g + i D_{iw̄} g)/4.
_bdg_L_action(ws, ψ, w, ε) =
    (hessian_vector_product(ws, ψ, w; ε) .-
     im .* hessian_vector_product(ws, ψ, im .* w; ε)) ./ 4
_bdg_M_action(ws, ψ, w, ε) =
    (
        hessian_vector_product(ws, ψ, conj.(w); ε) .+
        im .* hessian_vector_product(ws, ψ, im .* conj.(w); ε)
    ) ./ 4

# H_BdG action on (u, v) (both ψ-shaped). `skip_u`/`skip_v` short-circuit
# the zero half during dense column assembly (conj(M_op)·u = conj(M_op·ū),
# conj(L_op−μ)·v = conj(L_op·v̄) − μ v).
function _bdg_apply(ws, ψ, u, v, μ, ε; skip_u::Bool=false, skip_v::Bool=false)
    Lu = skip_u ? zero(u) : _bdg_L_action(ws, ψ, u, ε)
    Mv = skip_v ? zero(v) : _bdg_M_action(ws, ψ, v, ε)
    top = Lu .- μ .* u .+ Mv
    McU = skip_u ? zero(u) : _bdg_M_action(ws, ψ, conj.(u), ε)
    LcV = skip_v ? zero(v) : _bdg_L_action(ws, ψ, conj.(v), ε)
    bottom = .-conj.(McU) .- conj.(LcV) .+ μ .* v
    top, bottom
end

"""
    trapped_bdg_spectrum(ws, ψ; μ, ε=1e-5, dim_cap=4000)
        → (; omega, max_growth, quartet_residual, dim, dense_ok)

Dense trapped BdG spectrum at a stationary `ψ` with chemical potential `μ`.
`omega::Vector{ComplexF64}` are all `2·length(ψ)` eigenvalues;
`max_growth = maximum(imag, omega)` (> 0 ⇒ dynamical instability);
`quartet_residual` is the relative violation of the `ω ↦ −conj(ω)` spectral
symmetry (a self-consistency check on the assembly + solve). When
`dim = 2·length(ψ) > dim_cap`, returns `dense_ok=false` with empty `omega`
— the caller abstains rather than over-claim.
"""
function trapped_bdg_spectrum(ws, ψ; μ::Real, ε::Float64=1e-5, dim_cap::Int=4000)
    P = length(ψ)
    dim = 2P
    if dim > dim_cap
        return (;
            omega=ComplexF64[], max_growth=NaN, quartet_residual=NaN,
            dim, dense_ok=false,
        )
    end
    sz = size(ψ)
    z = zeros(ComplexF64, sz)
    H = zeros(ComplexF64, dim, dim)
    for col in 1:dim
        if col <= P
            u = zeros(ComplexF64, sz)
            u[col] = 1
            top, bottom = _bdg_apply(ws, ψ, u, z, μ, ε; skip_v=true)
        else
            v = zeros(ComplexF64, sz)
            v[col - P] = 1
            top, bottom = _bdg_apply(ws, ψ, z, v, μ, ε; skip_u=true)
        end
        H[1:P, col] .= vec(top)
        H[(P + 1):dim, col] .= vec(bottom)
    end

    omega = eigvals(H)
    max_growth = maximum(imag, omega)

    radius = maximum(abs, omega) + 1e-30
    qr = 0.0
    for ω in omega
        target = -conj(ω)
        dmin = minimum(abs(target - ω2) for ω2 in omega)
        qr = max(qr, dmin)
    end
    quartet_residual = qr / radius

    (; omega, max_growth, quartet_residual, dim, dense_ok=true)
end
