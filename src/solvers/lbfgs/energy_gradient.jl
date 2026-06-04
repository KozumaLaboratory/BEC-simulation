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

    # Magnetic gradient (post-[GAP-2] 2026-06-04): closes the same gap
    # in the LBFGS gradient that `_magnetic_gradient_energy` closed in
    # `energy_decomposition`. Pre-fix LBFGS minimised a Hamiltonian
    # missing the MG term, biasing the converged state when MG ≠ 0.
    if ws.magnetic_gradient !== nothing
        add_gradient!(grad, MagneticGradientTerm(), psi, ws)
    end

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

# Authoritative kernel `_grad_kinetic_core!` lives in
# `src/hamiltonian/terms/kinetic.jl` (Part B collapse, 2026-06-04).
# This shim preserves the legacy entry point name for `energy_gradient!`.
_grad_kinetic!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, vN) =
    _grad_kinetic_core!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, vN)

# Coriolis: −Ω·L_z·ψ where L_z = −i(x·∂_y − y·∂_x). The δE_cor/δψ*
# contribution is +iΩ·(x·∂_y − y·∂_x)·ψ. Closes the rotating-frame
# functional alongside the Barnett Zeeman shift (in ws.zeeman) and the
# centrifugal trap modification (in ws.potential_values). Active only
# when `rotating_frame_omega ≠ 0` and N ≥ 2.
# Authoritative kernel `_grad_coriolis_core!` lives in
# `src/hamiltonian/terms/coriolis.jl` (Part B collapse, 2026-06-04).
# This shim preserves the legacy entry point for `energy_gradient!`.
_grad_coriolis!(grad, psi, ws, fft_buf, deriv_buf, n_pts, D, vN) =
    _grad_coriolis_core!(grad, psi, ws, fft_buf, deriv_buf, n_pts, D, vN)

function _grad_trap!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= ws.potential_values .* view(psi, idx...)
    end
    nothing
end

function _grad_zeeman!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    # Diagonal Zeeman: -p·F_z + q·F_z². Pre-2026-06-04 this routine
    # silently dropped transverse contributions ([GAP-1]). Now: also
    # adds -bx·F_x - by·F_y via the TransverseZeemanTerm HamTerm dispatch.
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zee_vals = zeeman_energies(zee, ws.spin_matrices.system)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= zee_vals[c] .* view(psi, idx...)
    end
    # Transverse Zeeman contribution via HamTerm dispatch.
    bx, by = transverse_b(ws.zeeman, ws.state.t)
    if !(bx == 0.0 && by == 0.0)
        add_gradient!(grad, TransverseZeemanTerm(bx, by), psi, ws)
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

# Authoritative kernel `_grad_c1_spin_core!` lives in
# `src/hamiltonian/terms/spin_c1.jl` (Part B collapse, 2026-06-04).
_grad_c1_spin!(grad, psi, ws, fx, fy, fz, n_pts, D, vN) =
    _grad_c1_spin_core!(grad, psi, ws, fx, fy, fz, n_pts, D, vN)

# Authoritative kernel `_grad_light_shift_core!` lives in
# `src/hamiltonian/terms/light_shift.jl` (Part B collapse, 2026-06-04).
_grad_light_shift!(grad, psi, ws, n_pts, D, vN) =
    _grad_light_shift_core!(grad, psi, ws, n_pts, D, vN)

# Authoritative kernel `_grad_ddi_core!` lives in
# `src/hamiltonian/terms/ddi.jl` (Part B collapse, 2026-06-04).
_grad_ddi!(grad, psi, ws, n_pts, D, vN) =
    _grad_ddi_core!(grad, psi, ws, n_pts, D, vN)

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
