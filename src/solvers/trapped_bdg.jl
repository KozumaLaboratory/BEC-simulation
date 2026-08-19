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

# Dense-assembly column for a REAL one-hot basis vector `e`. From the v/iv
# real representation of the gated HvP:
#   D_e g = 2(L_op e + M_op ē),  D_{ie} g = 2i(L_op e − M_op ē)
# ⇒ with hp = D_e g and hip = D_{ie} g computed ONCE,
#   L_op e = (hp − i·hip)/4,  M_op e = (hp + i·hip)/4.
# Because `e` is real (conj(e)=e), M_op·conj(e)=M_op·e and L_op·conj(e)=
# L_op·e, so BOTH BdG blocks reuse the SAME two HvPs — 2 HvP = 4 gradient
# evals per column, vs 4 HvP = 8 if the L and M actions were evaluated
# separately. `is_u` selects the upper (u, v=0) or lower (v, u=0) block:
#   u-column: top = (L_op−μ)·e,  bottom = −conj(M_op)·e = −conj(M_op·ē)
#   v-column: top = M_op·e,      bottom = −conj(L_op−μ)·e = −conj(L_op·ē)+μe
function _bdg_column(ws, ψ, e, μ, ε, is_u::Bool)
    hp = hessian_vector_product(ws, ψ, e; ε)
    hip = hessian_vector_product(ws, ψ, im .* e; ε)
    Le = (hp .- im .* hip) ./ 4
    Me = (hp .+ im .* hip) ./ 4
    is_u ? (Le .- μ .* e, .-conj.(Me)) : (Me, .-conj.(Le) .+ μ .* e)
end

"""
    trapped_bdg_spectrum(ws, ψ; μ, ε=1e-5, dim_cap=4000)
        → (; omega, max_growth, quartet_residual, radius, dim, dense_ok)

Dense trapped BdG spectrum at a stationary `ψ` with chemical potential `μ`.
`omega::Vector{ComplexF64}` are all `2·length(ψ)` eigenvalues;
`max_growth = maximum(imag, omega)` (> 0 ⇒ dynamical instability);
`radius = maximum(abs, omega)` (the spectral scale, so callers can apply a
RELATIVE growth threshold); `quartet_residual` is the relative violation of
the `ω ↦ −conj(ω)` symmetry (a weak self-check — see the loop comment).

FD-FLOOR CAVEAT (phase 2a): `H` is assembled from central-difference HvP
(ε), so its entries carry ~ε truncation/roundoff and `max_growth` /
`quartet_residual` have a noise floor of that order. A growth rate at the
floor is indistinguishable from a stable real spectrum — verdicts within a
few × the floor are noise-limited. The matrix-free Arnoldi (phase 2b) on
the analytic operator removes this floor.

`dim_cap = 4000` bounds the dense path (a 4000×4000 non-Hermitian eigvals
is seconds; assembly is `O(dim · HvP)`). PRODUCTION Eu F=6 grids
(`2·N·13 ≫ 4000`) therefore exceed it: `dense_ok=false`, empty `omega`,
`max_growth=NaN` — the caller MUST branch on `dense_ok` first (NaN compares
false, so a forgotten guard would silently read it as stable). The
dynamical axis stays `:indeterminate` for production until phase 2b.
"""
function trapped_bdg_spectrum(ws, ψ; μ::Real, ε::Float64=1e-5, dim_cap::Int=4000)
    P = length(ψ)
    dim = 2P
    if dim > dim_cap
        return (;
            omega=ComplexF64[], max_growth=NaN, quartet_residual=NaN,
            radius=NaN, dim, dense_ok=false,
        )
    end
    sz = size(ψ)
    H = zeros(ComplexF64, dim, dim)
    for col in 1:dim
        is_u = col <= P
        e = zeros(ComplexF64, sz)
        e[is_u ? col : col - P] = 1               # real one-hot basis vector
        top, bottom = _bdg_column(ws, ψ, e, μ, ε, is_u)
        H[1:P, col] .= vec(top)
        H[(P + 1):dim, col] .= vec(bottom)
    end

    omega = eigvals(H)
    max_growth = maximum(imag, omega)
    radius = maximum(abs, omega) + COUPLING_TOL

    # ω↦−conj(ω) symmetry: a NECESSARY-but-not-sufficient self-check. It is a
    # property of the [[A,B],[−conj(B),−conj(A)]] block PATTERN and holds for
    # ANY A,B, so it catches a corrupted assembly/solve but NOT a sign error
    # inside L_op/M_op/μ that preserves the pattern (and a purely-imaginary ω
    # is its own −conj(ω) partner ⇒ contributes 0). Operator-level correctness
    # is gated offline by test_trapped_bdg_spectrum.jl (uniform limit ≡
    # homogeneous BdG), not by this runtime residual.
    qr = 0.0
    for ω in omega
        target = -conj(ω)
        dmin = minimum(abs(target - ω2) for ω2 in omega)
        qr = max(qr, dmin)
    end
    quartet_residual = qr / radius

    (; omega, max_growth, quartet_residual, radius, dim, dense_ok=true)
end
