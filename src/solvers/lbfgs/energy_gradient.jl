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

"""
    energy_gradient!(grad, psi, ws; k_squared_dev) → E

Compute δE/δψ* = H_eff ψ and return total energy.
The gradient includes kinetic, trap, contact, LHY, spin, and DDI terms.

`k_squared_dev` must live on the same device as `psi` (defaults to `ws.grid.k_squared`,
which only works on CPU). L-BFGS on GPU should pass a device-resident copy.
"""
function energy_gradient!(
    grad::AbstractArray{<:Complex},
    psi::AbstractArray{<:Complex},
    ws::Workspace{N};
    k_squared_dev::AbstractArray{<:AbstractFloat}=ws.grid.k_squared,
) where {N}
    grid = ws.grid
    n_comp = ws.spin_matrices.system.n_components
    F = ws.atom.F
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = n_comp

    fill!(grad, zero(ComplexF64))

    # Sync workspace psi for energy evaluation
    copyto!(ws.state.psi, psi)

    # --- Kinetic: (-∇²/2) ψ via FFT ---
    fft_buf = similar(psi, ComplexF64, n_pts)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        fft_buf .= view(psi, idx...)
        ws.fft_plans.forward * fft_buf
        fft_buf .*= (0.5 .* k_squared_dev)
        ws.fft_plans.inverse * fft_buf
        view(grad, idx...) .+= fft_buf
    end

    # --- Trap potential: V_trap ψ ---
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= ws.potential_values .* view(psi, idx...)
    end

    # --- Zeeman ---
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zee_vals = zeeman_energies(zee, ws.spin_matrices.system)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= zee_vals[c] .* view(psi, idx...)
    end

    # --- Density interaction: c₀ n ψ ---
    n_density = total_density(psi, N)
    c0 = ws.interactions[0]
    if abs(c0) > 1e-30
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= c0 .* n_density .* view(psi, idx...)
        end
    end

    # --- LHY ---
    c_lhy_val = ws.interactions.c_lhy
    if c_lhy_val != 0.0
        v_lhy = c_lhy_val .* n_density .* sqrt.(max.(n_density, 0.0))
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            view(grad, idx...) .+= v_lhy .* view(psi, idx...)
        end
    end

    # --- Spin interaction: c₁ (F⃗·f⃗) ψ ---
    c1 = ws.interactions[1]
    if abs(c1) > 1e-30
        sm = ws.spin_matrices
        # device-aware allocation: GPU when psi is CuArray, CPU otherwise
        fx = similar(psi, Float64, n_pts)
        fy = similar(psi, Float64, n_pts)
        fz = similar(psi, Float64, n_pts)
        _compute_spin_density!(fx, fy, fz, psi, sm, Val(D), N, n_pts)
        # Fz part (diagonal)
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            m = Float64(F - (c - 1))
            view(grad, idx...) .+= c1 .* m .* fz .* view(psi, idx...)
        end
        # F+/F- parts (tridiagonal)
        for c in 2:D
            idx_c = _component_slice(N, n_pts, c)
            idx_cm1 = _component_slice(N, n_pts, c - 1)
            fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            # (F⃗·f⃗)ψ has off-diagonal: fp/2 × [(fx-ify)ψ_{c} in row c-1, (fx+ify)ψ_{c-1} in row c]
            view(grad, idx_cm1...) .+= c1 .* 0.5 .* fp .* (fx .- im .* fy) .* view(psi, idx_c...)
            view(grad, idx_c...) .+= c1 .* 0.5 .* fp .* (fx .+ im .* fy) .* view(psi, idx_cm1...)
        end
    end

    # --- Light shift: M × I(r) × ψ ---
    if ws.light_shift !== nothing
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
    end

    # --- DDI: (Φ⃗·f⃗) ψ ---
    if ws.ddi !== nothing
        sm = ws.spin_matrices
        bufs = ws.ddi_bufs
        _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r, psi, sm, Val(D), N, n_pts)
        compute_ddi_potential!(ws.ddi, bufs)

        # Keep on device (bufs.Phi_* already live on the workspace backend)
        phi_x = bufs.Phi_x
        phi_y = bufs.Phi_y
        phi_z = bufs.Phi_z

        # Fz part
        for c in 1:D
            idx = _component_slice(N, n_pts, c)
            m = Float64(F - (c - 1))
            view(grad, idx...) .+= m .* phi_z .* view(psi, idx...)
        end
        # F+/F- parts
        for c in 2:D
            idx_c = _component_slice(N, n_pts, c)
            idx_cm1 = _component_slice(N, n_pts, c - 1)
            fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
            view(grad, idx_cm1...) .+= 0.5 .* fp .* (phi_x .- im .* phi_y) .* view(psi, idx_c...)
            view(grad, idx_c...) .+= 0.5 .* fp .* (phi_x .+ im .* phi_y) .* view(psi, idx_cm1...)
        end
    end

    # Scale gradient by 2 for complex ψ convention:
    # δE = 2 Re ∫ (δE/δψ*)* · δψ dV, so grad_R = 2 × δE/δψ*
    # makes δE = Re ∫ grad_R* · δψ dV (standard real inner product)
    grad .*= 2

    energy_decomposition(ws).total
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
        if mz_norm > 1e-30
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
