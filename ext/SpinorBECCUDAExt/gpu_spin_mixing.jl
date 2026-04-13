# GPU-native spin_mixing: eliminates GPU↔CPU round-trip
#
# Strategy: use broadcast-based approach instead of custom kernel.
# For each grid point, compute spin vector F, then apply Euler rotation
# R_z(α) R_y(β) exp(-iθFz) R_y(-β) R_z(-α) using precomputed Fy eigenvectors.
#
# Implemented as a sequence of batched matrix operations (CUBLAS gemm)
# to avoid kernel compilation issues with large D.

function SpinorBEC.apply_spin_mixing_step!(
    psi::CuArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices{D},
    c1::Float64,
    dt_frac::Float64,
    ndim::Int;
    imaginary_time::Bool = false,
) where {D}
    abs(c1) < 1e-30 && return nothing
    n_pts = ntuple(d -> size(psi, d), ndim)
    N = prod(n_pts)
    F = sm.system.F

    # Reshape psi to (N, D) for batched operations
    psi_2d = reshape(psi, N, D)

    # Step 1: Compute Fz per grid point (broadcast)
    m_vals_d = CUDA.CuArray(Float64[F - (c - 1) for c in 1:D])
    # Fz[i] = Σ_c m_c |ψ_{i,c}|²
    fz = dropdims(sum(abs2.(psi_2d) .* reshape(m_vals_d, 1, D); dims=2); dims=2)

    # Step 2: Compute F+ per grid point
    Ff1 = Float64(F * (F + 1))
    fp_d = CUDA.CuArray(Float64[c == 1 ? 0.0 : sqrt(Ff1 - (F - c + 1) * (F - c + 2)) for c in 1:D])
    # F+[i] = Σ_{c=2}^D fp_c conj(ψ_{i,c-1}) ψ_{i,c}
    fp_host = Float64[c == 1 ? 0.0 : sqrt(Ff1 - (F - c + 1) * (F - c + 2)) for c in 1:D]
    fplus = CUDA.zeros(ComplexF64, N)
    for c in 2:D
        fplus .+= fp_host[c] .* conj.(view(psi_2d, :, c-1)) .* view(psi_2d, :, c)
    end
    fx = real.(fplus)
    fy = imag.(fplus)

    # Step 3: Compute angles
    f_perp = sqrt.(fx.^2 .+ fy.^2)
    f_mag = sqrt.(fx.^2 .+ fy.^2 .+ fz.^2)

    # Avoid division by zero
    safe_mag = max.(f_mag, 1e-30)
    safe_perp = max.(f_perp, 1e-30)

    β = acos.(clamp.(fz ./ safe_mag, -1.0, 1.0))
    α = atan.(fy, fx)
    θ = c1 .* f_mag .* dt_frac

    # Zero out rotation for zero spin
    mask = f_mag .> 1e-30

    # Step 4: Apply R_z(-α) — diagonal per component
    for c in 1:D
        m = Float64(F - (c - 1))
        phase = cis.(-m .* α)
        view(psi_2d, :, c) .*= phase
    end

    # Step 5: R_y(-β) = V diag(exp(iβλ)) V†
    V_d = CUDA.CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs)))     # D×D
    Vt_d = CUDA.CuArray(ComplexF64.(Matrix(sm.Fy_eigvecs_adj))) # D×D
    λ_host = Float64.(sm.Fy_eigvals)

    # V† · ψ  (batched: (N,D) × (D,D)^T → (N,D))
    tmp = psi_2d * transpose(Vt_d)  # (N, D)

    # Multiply by exp(iβλ_j) per component (β is spatial angle, always cis)
    for j in 1:D
        λj = λ_host[j]
        view(tmp, :, j) .*= cis.(β .* λj) .* mask .+ (1.0 .- mask)
    end

    # V · tmp → psi_2d
    psi_2d .= tmp * transpose(V_d)

    # Step 6: exp(-iθFz) — diagonal
    # ITP: shift by exp(-F·θ) so largest factor = 1 (prevents overflow, removed by normalization)
    for c in 1:D
        m = Float64(F - (c - 1))
        if imaginary_time
            view(psi_2d, :, c) .*= exp.(θ .* (m .- F)) .* mask .+ (1.0 .- mask)
        else
            view(psi_2d, :, c) .*= cis.(-θ .* m) .* mask .+ (1.0 .- mask)
        end
    end

    # Step 7: R_y(β) = V diag(exp(-iβλ)) V†
    tmp .= psi_2d * transpose(Vt_d)
    for j in 1:D
        λj = λ_host[j]
        view(tmp, :, j) .*= cis.(-β .* λj) .* mask .+ (1.0 .- mask)
    end
    psi_2d .= tmp * transpose(V_d)

    # Step 8: R_z(α) — diagonal
    for c in 1:D
        m = Float64(F - (c - 1))
        phase = cis.(m .* α)
        view(psi_2d, :, c) .*= phase
    end

    nothing
end
