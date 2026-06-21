# --- Light Shift (tensor + vector AC Stark shift) ---
#
# AC Stark Hamiltonian beyond scalar α₀:
#   H_LS(r) = I(r) × [α_v (iε̂*×ε̂)·F̂/F + α_t (3(ε̂·F̂)²−F(F+1))/(F(2F−1))]
#
# Strategy: precompute M = spin matrix, eigendecompose M = UΛU†.
#   Diagonal case: fold eigenvalues into diagonal step kernel.
#   Off-diagonal case: separate substep with U†→phase→U per grid point.

export make_light_shift, make_light_shift_from_trap, apply_light_shift_step!

"""
    _build_light_shift_operator(F, sm, polarization, alpha_v, alpha_t) → Matrix{ComplexF64}

Build the D×D light-shift spin operator M = M_vector + M_tensor.
"""
function _build_light_shift_operator(
    F::Int,
    sm::SpinMatrices,
    polarization,
    alpha_v::Float64,
    alpha_t::Float64,
)
    D = 2F + 1
    Fx = Matrix{ComplexF64}(sm.Fx)
    Fy = Matrix{ComplexF64}(sm.Fy)
    Fz = Matrix{ComplexF64}(sm.Fz)
    eps = ComplexF64.(collect(polarization))
    eps ./= norm(eps)

    M = zeros(ComplexF64, D, D)

    # Vector part: α_v/F × (iε̂*×ε̂)·F̂
    if is_active(alpha_v)
        cross_vec = im .* cross(conj.(eps), eps)
        Mv = (real(cross_vec[1]) * Fx + real(cross_vec[2]) * Fy + real(cross_vec[3]) * Fz)
        M .+= (alpha_v / F) .* Mv
    end

    # Tensor part: α_t × (3(ε̂·F̂)² − F(F+1)I) / (F(2F−1))
    if is_active(alpha_t)
        eFhat = eps[1] * Fx + eps[2] * Fy + eps[3] * Fz
        eFhat_sq = eFhat' * eFhat
        Mt = 3.0 .* eFhat_sq .- F * (F + 1) * I(D)
        denom = F * (2F - 1)
        denom = denom == 0 ? 1.0 : Float64(denom)
        M .+= (alpha_t / denom) .* Mt
    end

    M
end

"""
    make_light_shift(; F, polarization, alpha_vector, alpha_tensor, profile, backend) → LightShift

Build a LightShift from explicit parameters.
"""
function make_light_shift(;
    F::Int,
    polarization=(0, 0, 1),
    alpha_vector::Float64=0.0,
    alpha_tensor::Float64=0.0,
    profile::AbstractArray{<:AbstractFloat},
    backend::AbstractBackend=CPUBackend(),
)
    sm = spin_matrices(F)
    M = _build_light_shift_operator(F, sm, polarization, alpha_vector, alpha_tensor)

    D = 2F + 1
    off_diag_norm = 0.0
    for i in 1:D, j in 1:D
        i != j && (off_diag_norm += abs2(M[i, j]))
    end

    if off_diag_norm < 1e-20
        eigvals = [real(M[c, c]) for c in 1:D]
        U = Matrix{ComplexF64}(LinearAlgebra.I, D, D)
        LightShift(_to_device(backend, profile), eigvals, U, true)
    else
        H = Hermitian(M)
        eig = eigen(H)
        LightShift(_to_device(backend, profile), eig.values, eig.vectors, false)
    end
end

"""
    make_light_shift_from_trap(V_trap, F, eta_tensor; eta_vector=0, polarization=(0,0,1), backend)

Convenience: use trap potential as intensity profile with η = α₂/α₀ effective ratio.
"""
function make_light_shift_from_trap(
    V_trap::AbstractArray{<:AbstractFloat},
    F::Int,
    eta_tensor::Float64;
    eta_vector::Float64=0.0,
    polarization=(0, 0, 1),
    backend::AbstractBackend=CPUBackend(),
)
    profile = abs.(V_trap)
    make_light_shift(;
        F, polarization,
        alpha_vector=eta_vector,
        alpha_tensor=eta_tensor,
        profile, backend,
    )
end

"""
    apply_light_shift_step!(psi, ls, dt_frac, ndim; imaginary_time=false)

Off-diagonal light-shift substep: U†→phase(λ·I(r)·dt)→U per grid point.
Only called when `!ls.is_diagonal`.
"""
function apply_light_shift_step!(
    psi::Array{<:Complex},
    ls::LightShift,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
)
    D = length(ls.eigvals)
    n_pts = ntuple(d -> size(psi, d), ndim)
    U = ls.U
    Uadj = U'
    profile = ls.profile
    eigvals = ls.eigvals

    Threads.@threads for lin in 1:prod(n_pts)
        I = CartesianIndices(n_pts)[lin]
        intensity = profile[I]
        v = MVector{D, ComplexF64}(undef)
        spinor = MVector{D, ComplexF64}(undef)
        for c in 1:D
            spinor[c] = psi[I, c]
        end
        # v = U† × spinor
        for k in 1:D
            s = zero(ComplexF64)
            for c in 1:D
                s += Uadj[k, c] * spinor[c]
            end
            v[k] = s
        end
        # phase rotation in eigenbasis
        for k in 1:D
            phase_arg = eigvals[k] * intensity * dt_frac
            v[k] *= imaginary_time ? exp(-phase_arg) : cis(-phase_arg)
        end
        # spinor = U × v
        for c in 1:D
            s = zero(ComplexF64)
            for k in 1:D
                s += U[c, k] * v[k]
            end
            psi[I, c] = s
        end
    end
    nothing
end

function apply_light_shift_step!(
    psi::AbstractArray{<:Complex},
    ls::LightShift,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool=false,
)
    # GPU path: the host loop indexes `ls.profile` element-wise, so gather
    # it to host first (U / eigvals are already host). Without this the
    # off-diagonal step scalar-indexes a device array.
    ls_host = LightShift(Array(ls.profile), ls.eigvals, ls.U, ls.is_diagonal)
    _run_on_host!(psi) do p
        apply_light_shift_step!(p, ls_host, dt_frac, ndim; imaginary_time)
    end
end
