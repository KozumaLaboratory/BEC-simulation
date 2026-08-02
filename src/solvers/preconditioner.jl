# Combined potential+kinetic preconditioner  P_C = P_V^½ P_K P_V^½  for the
# GP ground-state Hessian.
#
# The Sobolev / kinetic-only preconditioner inverts only ½∇² (the high-k
# stiffness). The GP Hessian diagonal is ≈ k² + 2(V_eff − μ) with
# V_eff = V_trap + c₀·n, so on a dense, ill-conditioned state (e.g. the weak-
# field Eu+DDI soft manifold) the real-space potential stiffness is left
# unpreconditioned and first-order GS / the BdG eigensolver crawl. P_C adds
# the real-space part as a symmetric split: multiply by P_V^½ (real space),
# damp high-k with P_K (Fourier), multiply by P_V^½ again — so it stays
# symmetric (valid as a CG/L-BFGS metric).
#
# Knobs: α_V regularizes the potential inverse, α_K the kinetic inverse.
# P_V(r) = 1/(V_trap + c₀ n + α_V),  P_K(k) = 1/(½k² + α_K).

export combined_precondition!, build_precond_sqrt_pv

# √P_V = 1/√(V_trap + c₀·n(r) + α_V), a positive real-space array on ψ's device.
function build_precond_sqrt_pv(ws::Workspace{N}, psi, α_V::Float64) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Ns = prod(n_pts)
    D = ws.spin_matrices.system.n_components
    P = reshape(psi, Ns, D)
    n = reshape(sum(abs2, P; dims=2), n_pts)          # density (device array)
    c0 = ws.interactions[0]
    veff = ws.potential_values .+ c0 .* n             # V_trap + c0·n
    sqrt_pv = inv.(sqrt.(veff .+ real(eltype(veff))(α_V)))
    sqrt_pv
end

# Apply P_C = P_V^½ P_K P_V^½ to v in place. `sqrt_pv` is (n_pts...) real;
# `k2 = ws.grid.k_squared` (device); α_K regularizes the kinetic inverse.
function combined_precondition!(
    v::AbstractArray{<:Complex}, ws::Workspace{N},
    sqrt_pv::AbstractArray{<:Real}, k2::AbstractArray{<:Real}, α_K::Float64,
) where {N}
    n_pts = ntuple(d -> size(v, d), Val(N))
    spv = reshape(sqrt_pv, n_pts..., 1)               # broadcast over components
    αK = real(eltype(k2))(α_K)
    filt = cached_kspace_filter(
        k2, :combined_precond_k, α_K, k2v -> inv(oftype(αK, 0.5) * k2v + αK)
    )

    v .*= spv                                         # P_V^½
    batched_kspace_filter!(v, ws, filt)               # P_K (all components)
    v .*= spv                                         # P_V^½
    v
end
