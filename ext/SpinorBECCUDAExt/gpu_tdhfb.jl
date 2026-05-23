# GPU dispatch for TDHFB scaffolding (Phase 5a: state + V-step + Hermiticity).
#
# Design reference: `docs/design/tdhfb_gpu_port_design.md` §5.2 ("Method
# dispatch"). Each `_tdhfb_*` leaf method gets a CuArray-specialized version
# so the top-level `tdhfb_strang_step!` is shared between backends.
#
# Phase 5a deliverables (this file):
#   - `_tdhfb_v_step!(::CuArray, ::CuArray, dt)`  — broadcast V-step
#   - `tdhfb_hermiticity_check(::TDHFBState{N, <:CuArray, <:CuArray})`
#     — GPU-friendly Hermiticity / symmetry check
#
# `init_tdhfb_vacuum(::CuArray)` works as-is via the generic CPU code
# (`similar(psi, ...)` + `fill!` are CuArray-compatible) — no override needed.
#
# Phase 5c-5e (FUTURE): HF substep (channel kernel gemm + batched Padé
# matrix-exp + R update), full strang_step.

"""
GPU broadcast V-step:  phi_m(r) ← exp(-i V_ext[r, m] dt) · phi_m(r).
Avoids the CPU's per-voxel scalar-indexing loop (which crashes on CuArray)
by collapsing the operation into a single fused broadcast.
"""
function SpinorBEC._tdhfb_v_step!(
    phi::CuArray{<:Complex},
    V_ext::CuArray{<:Real},
    dt::Float64,
)
    # phi: (spatial..., D), V_ext: (spatial..., D). Broadcast aligns.
    @assert size(phi) == size(V_ext) "phi and V_ext must have matching shape"
    phi .*= cis.(.- V_ext .* dt)
    phi
end

# Same for ComplexF32 V_ext (rare but valid).
function SpinorBEC._tdhfb_v_step!(
    phi::CuArray{<:Complex},
    V_ext::CuArray{<:Complex},
    dt::Float64,
)
    @assert size(phi) == size(V_ext) "phi and V_ext must have matching shape"
    phi .*= cis.(.- real.(V_ext) .* dt)
    phi
end

"""
GPU K-step: batched FFT over spatial axes, broadcast kinetic phase, IFFT.
Replaces the CPU per-component loop `for m in 1:D: fft(phi_m); phase; ifft`
with a single batched FFT pair where the trailing `D` axis is the batch.

Achieves ~1 forward FFT + 1 multiply + 1 inverse FFT per call instead of
D × (FFT + multiply + IFFT). On RTX 4090/5070 Ti for D=13 at N=32³,
expected per-call wall ~ 5–10 ms (vs CPU's 50-150 ms per call).
"""
function SpinorBEC._tdhfb_kinetic_step!(
    phi::CuArray{<:Complex},
    dt::Float64;
    k_squared=nothing,
)
    sz = size(phi)
    D = sz[end]
    n_spatial = length(sz) - 1
    spatial = sz[1:n_spatial]

    # Default k² grid (built once per call if not cached); promote to device
    # in the calling precision. `_default_tdhfb_k_squared` returns Float64,
    # convert to match phi's real precision.
    if k_squared === nothing
        T_real = real(eltype(phi))
        k_squared_host = SpinorBEC._default_tdhfb_k_squared(spatial)
        k_squared = CuArray{T_real}(k_squared_host)
    elseif k_squared isa Array
        # k_squared on host but phi on device — move it.
        T_real = real(eltype(phi))
        k_squared = CuArray{T_real}(k_squared)
    end
    @assert size(k_squared) == spatial "k_squared shape must match spatial dims"

    # Forward FFT over spatial dims; D axis is batched implicitly.
    phi_k = CUDA.CUFFT.fft(phi, 1:n_spatial)

    # Kinetic phase: cis(-0.5 |k|² dt) broadcast across D.
    T_real = real(eltype(phi))
    phase = cis.(.- T_real(0.5) .* k_squared .* T_real(dt))
    # Reshape to (spatial..., 1) for broadcast over the D axis.
    phase_bc = reshape(phase, spatial..., 1)
    phi_k .*= phase_bc

    # Inverse FFT
    phi_back = CUDA.CUFFT.ifft(phi_k, 1:n_spatial)

    # Write back into phi
    phi .= phi_back
    phi
end

"""
GPU Hermiticity/symmetry check. Computes max(|rho - rho†|) and max(|kappa - kappaᵀ|)
by reduction over CuArrays — no scalar indexing.
"""
function SpinorBEC.tdhfb_hermiticity_check(
    state::SpinorBEC.TDHFBState{N, A, B, T};
    tol::Real=1e-10,
) where {N, A <: CuArray, B <: CuArray, T}
    rho = state.rho
    kappa = state.kappa
    sz = size(rho)
    D = sz[end]
    n_spatial_dims = length(sz) - 2

    # rho: (spatial..., D, D). The swap (m, m') ↔ (m', m) is achieved
    # by permuting the last two axes via `PermutedDimsArray`. Then
    # rho - conj(rho_swap) should be zero for a Hermitian state.
    perm = (ntuple(identity, n_spatial_dims)..., n_spatial_dims + 2, n_spatial_dims + 1)
    rho_swap = PermutedDimsArray(rho, perm)
    kappa_swap = PermutedDimsArray(kappa, perm)

    # |rho - conj(rho_swap)| reduction — single GPU kernel
    rho_dev = maximum(abs.(rho .- conj.(rho_swap)))
    kappa_dev = maximum(abs.(kappa .- kappa_swap))

    # Pull scalar to host for return
    (Float64(rho_dev), Float64(kappa_dev))
end
