# L-BFGS energy + gradient + projected-constraint helpers
#
# Extracted from solvers/lbfgs_ground_state.jl in the 2026-05-09 refactor.

# --- L-BFGS ground state solver ---
#
# Direct minimization of E[ψ] on the constraint manifold {‖ψ‖²=1, ⟨Fz⟩=Mz}.
#
# Advantages over split-step ITP:
#   - Energy is guaranteed to decrease at every step (line search)
#   - DDI self-consistency is exact (Φ[ψ] computed at current ψ)
#   - No split-step error or operator-ordering artifacts
#
# Cost per step: ~1 split-step equivalent (FFT pairs + DDI convolution)
# for the gradient, plus ~1 energy evaluation for line search.

using Printf

# Scratch buffers (fft_buf, fx/fy/fz spin-density, Coriolis derivative)
# backed by the shared scratch registry. Avoids ~0.5 MB/call CuArray pool
# churn that OOM'd 1000+-step LBFGS sweeps pre-2026-06-02.
function _energy_gradient_scratch(psi, n_pts)
    scratch_get!(:energy_gradient, (typeof(psi), n_pts)) do
        (
            similar(psi, ComplexF64, n_pts),  # fft_buf
            similar(psi, Float64, n_pts),     # fx scratch
            similar(psi, Float64, n_pts),     # fy scratch
            similar(psi, Float64, n_pts),     # fz scratch
            similar(psi, ComplexF64, n_pts),  # Coriolis derivative scratch
        )
    end
end

# `_axis_broadcast` lives in `src/foundation/backend.jl`; reused here for
# the Coriolis −Ω·L_z·ψ term's per-axis coordinate / wavenumber arrays.

"""
    energy_gradient!(grad, psi, ws; k_squared_dev) → E

Compute δE/δψ* = H_eff ψ and return total energy.

Covered terms: kinetic, trap (incl. centrifugal modification when
`rotating_frame_omega ≠ 0`), Zeeman (incl. Barnett shift when
`rotating_frame_omega ≠ 0`), c₀, LHY, c₁ spin, light shift, DDI, and
the Coriolis `−Ω·L_z·ψ` orbital piece of the rotating-frame functional.

NOT covered: c₂ singlet-pair and tensor-cache higher-rank channels
(c₄, c₆, …). For those, `find_ground_state_lbfgs` emits a warning and
the caller should fall back to ITP.

`k_squared_dev` must live on the same device as `psi` (defaults to
`ws.grid.k_squared`, which only works on CPU). L-BFGS on GPU should
pass a device-resident copy.
"""
function energy_gradient!(
    grad::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    ws::Workspace{N};
    k_squared_dev::AbstractArray{<:AbstractFloat}=ws.grid.k_squared,
) where {N}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components

    fill!(grad, zero(ComplexF64))
    copyto!(ws.state.psi, psi)  # sync ws for energy evaluation

    fft_buf, fx_scratch, fy_scratch, fz_scratch, deriv_buf = _energy_gradient_scratch(psi, n_pts)

    # Linear-in-ψ terms (always accumulate). Order chosen to share the
    # fft_buf scratch productively: kinetic consumes it first, then
    # Coriolis can re-use it as a per-component FFT workspace.
    _grad_kinetic!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, Val(N))
    _grad_coriolis!(grad, psi, ws, fft_buf, deriv_buf, n_pts, D, Val(N))
    _grad_trap!(grad, psi, ws, n_pts, D, Val(N))
    _grad_zeeman!(grad, psi, ws, n_pts, D, Val(N))

    # Nonlinear (density / spin) terms; gated by coupling magnitude.
    n_density = total_density(psi, N)
    _grad_c0_density!(grad, psi, ws, n_density, n_pts, D, Val(N))
    _grad_lhy!(grad, psi, ws, n_density, n_pts, D, Val(N))
    _grad_c1_spin!(grad, psi, ws, fx_scratch, fy_scratch, fz_scratch, n_pts, D, Val(N))
    _grad_light_shift!(grad, psi, ws, n_pts, D, Val(N))
    _grad_ddi!(grad, psi, ws, n_pts, D, Val(N))

    # Scale gradient by 2 for complex ψ convention:
    # δE = 2 Re ∫ (δE/δψ*)* · δψ dV, so grad_R = 2 × δE/δψ*
    # makes δE = Re ∫ grad_R* · δψ dV (standard real inner product)
    grad .*= 2

    energy_decomposition(ws).total
end

# --- per-term gradient helpers ---
#
# Each helper mutates `grad` in place with its term's contribution to
# δE/δψ* (BEFORE the final ×2 complex-convention scaling done by the
# parent `energy_gradient!`). Helpers are gated on coupling magnitude so
# they no-op when the term is inactive.

function _grad_kinetic!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, ::Val{N}) where {N}
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf .*= (0.5 .* k_squared_dev)
        ws.fft_plans.inverse * fft_buf
        view(grad, idx...) .+= fft_buf
    end
    nothing
end

# Coriolis: −Ω·L_z·ψ where L_z = −i(x·∂_y − y·∂_x). The δE_cor/δψ*
# contribution is +iΩ·(x·∂_y − y·∂_x)·ψ. Closes the rotating-frame
# functional alongside the Barnett Zeeman shift (in ws.zeeman) and the
# centrifugal trap modification (in ws.potential_values). Active only
# when `rotating_frame_omega ≠ 0` and N ≥ 2.
function _grad_coriolis!(
    grad, psi, ws, fft_buf, deriv_buf, n_pts, D, ::Val{N}
) where {N}
    Ω = ws.sim_params.rotating_frame_omega
    (is_active(Ω, ROTATION_TOL) && N >= 2) || return nothing
    grid = ws.grid
    x_bcast = _axis_broadcast(fft_buf, grid.x[1], 1)
    y_bcast = _axis_broadcast(fft_buf, grid.x[2], 2)
    kx_bcast = _axis_broadcast(fft_buf, grid.k[1], 1)
    ky_bcast = _axis_broadcast(fft_buf, grid.k[2], 2)
    iΩ = im * Ω
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        # +iΩ · x · ∂_y ψ
        deriv_buf .= fft_buf .* (im .* ky_bcast)
        ws.fft_plans.inverse * deriv_buf
        view(grad, idx...) .+= iΩ .* x_bcast .* deriv_buf
        # −iΩ · y · ∂_x ψ
        deriv_buf .= fft_buf .* (im .* kx_bcast)
        ws.fft_plans.inverse * deriv_buf
        view(grad, idx...) .-= iΩ .* y_bcast .* deriv_buf
    end
    nothing
end

function _grad_trap!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= ws.potential_values .* view(psi, idx...)
    end
    nothing
end

function _grad_zeeman!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zee_vals = zeeman_energies(zee, ws.spin_matrices.system)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= zee_vals[c] .* view(psi, idx...)
    end
    nothing
end

function _grad_c0_density!(grad, psi, ws, n_density, n_pts, D, ::Val{N}) where {N}
    c0 = ws.interactions[0]
    is_active(c0) || return nothing
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= c0 .* n_density .* view(psi, idx...)
    end
    nothing
end

function _grad_lhy!(grad, psi, ws, n_density, n_pts, D, ::Val{N}) where {N}
    c_lhy_val = ws.interactions.c_lhy
    c_lhy_val != 0.0 || return nothing
    v_lhy = c_lhy_val .* n_density .* sqrt.(max.(n_density, 0.0))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= v_lhy .* view(psi, idx...)
    end
    nothing
end

function _grad_c1_spin!(grad, psi, ws, fx, fy, fz, n_pts, D, ::Val{N}) where {N}
    c1 = ws.interactions[1]
    is_active(c1) || return nothing
    sm = ws.spin_matrices
    F = ws.atom.F
    _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), N, n_pts)
    # Fz part (diagonal)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        m = Float64(F - (c - 1))
        view(grad, idx...) .+= c1 .* m .* fz .* view(psi, idx...)
    end
    # F+/F− parts (tridiagonal)
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        view(grad, idx_cm1...) .+= c1 .* 0.5 .* fp .* (fx .- im .* fy) .* view(psi, idx_c...)
        view(grad, idx_c...) .+= c1 .* 0.5 .* fp .* (fx .+ im .* fy) .* view(psi, idx_cm1...)
    end
    nothing
end

function _grad_light_shift!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    ws.light_shift !== nothing || return nothing
    ls = ws.light_shift
    profile = _to_host(ls.profile)
    if ls.is_diagonal
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= ls.eigvals[c] .* profile .* view(psi, idx...)
        end
    else
        M_full = ls.U * Diagonal(ls.eigvals) * ls.U'
        for c in 1:D
            idx_c = _component_slice(N, n_pts, c)
            for c2 in 1:D
                abs(M_full[c, c2]) < 1e-30 && continue
                idx_c2 = _component_slice(N, n_pts, c2)
                view(grad, idx_c...) .+= M_full[c, c2] .* profile .* view(psi, idx_c2...)
            end
        end
    end
    nothing
end

function _grad_ddi!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    ws.ddi !== nothing || return nothing
    sm = ws.spin_matrices
    F = ws.atom.F
    bufs = ws.ddi_bufs
    _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, n_pts)
    compute_ddi_potential!(ws.ddi, bufs)
    phi_x, phi_y, phi_z = bufs.Phi_x, bufs.Phi_y, bufs.Phi_z
    # Fz part (diagonal)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        m = Float64(F - (c - 1))
        view(grad, idx...) .+= m .* phi_z .* view(psi, idx...)
    end
    # F+/F− parts (tridiagonal)
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        view(grad, idx_cm1...) .+= 0.5 .* fp .* (phi_x .- im .* phi_y) .* view(psi, idx_c...)
        view(grad, idx_c...) .+= 0.5 .* fp .* (phi_x .+ im .* phi_y) .* view(psi, idx_cm1...)
    end
    nothing
end

"""
Project gradient onto constraint tangent space:
  1. Remove ψ-component (particle number conservation)
  2. Remove Mz-changing component (magnetization conservation)
"""
function _project_constraints!(
    grad::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    grid::Grid{N},
    target_Mz::Union{Nothing, Float64},
    F::Int,
) where {N}
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = 2F + 1

    # 1. Remove ψ-direction: grad -= Re⟨ψ|grad⟩ × ψ
    #    (chemical potential projection). `dot(a, b) = sum(conj(a)*b)`,
    #    no `conj.(psi)` and no broadcast-product temporary.
    μ_real = real(dot(psi, grad)) * dV
    grad .-= μ_real .* psi

    # 2. Magnetization conservation
    if target_Mz !== nothing
        mz_grad = 0.0
        mz_norm = 0.0
        for c in 1:D
            m = Float64(F - (c - 1))
            idx = _component_slice(N, n_pts, c)
            gc = view(grad, idx...)
            pc = view(psi, idx...)
            mz_grad += m * real(dot(pc, gc)) * dV
            mz_norm += m^2 * sum(abs2, pc) * dV
        end
        if is_active(mz_norm)
            λ = mz_grad / mz_norm
            for c in 1:D
                m = Float64(F - (c - 1))
                idx = _component_slice(N, n_pts, c)
                view(grad, idx...) .-= λ * m .* view(psi, idx...)
            end
        end
    end
    nothing
end

"""
    find_ground_state_lbfgs(; kwargs...) → NamedTuple

Find ground state by direct energy minimization using L-BFGS on the
constraint manifold {‖ψ‖²=1}.

# Hamiltonian coverage

The gradient implementation (`energy_gradient!`) covers:
kinetic, trap, Zeeman, c0 (density), c_lhy, c1 (spin), light_shift, DDI.

It does **NOT** cover:
- c2 (the S=0 singlet-pair channel — `apply_singlet_pair_step!`)
- higher-rank c_n tensor couplings (c4, c6, …)
- `tensor_cache` (per-channel g_S table)

The energy evaluation at end of step is correct (uses
`energy_decomposition`), but the gradient direction is biased when any
of those channels is active. The optimizer will converge to a wrong
minimum. A runtime `@warn` fires in this case; for those Hamiltonians
use the ITP path (`find_ground_state`) instead, or only LBFGS-polish a
state already ITP-converged with the full Hamiltonian.
"""
