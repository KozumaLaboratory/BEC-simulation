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
    # Trinity-only: iterate the HamTerm registry, each term contributes
    # via `apply_operator!(out, ::Term, ws, psi, ctx::GradientContext)`.
    # The ctx pre-builds shared scratch (fft_buf, fx/fy/fz, n_density)
    # so each term's hot-path skips per-call alloc.
    copyto!(ws.state.psi, psi)
    if _is_gpu(psi)
        # Fused GPU path: fill grad with Σ_term H_term·ψ AND return total energy
        # in ONE per-term apply_operator! pass (the FFT-heavy kinetic/DDI faces
        # run once, not once for grad + once for energy_decomposition). Bit-
        # equivalent to the two-pass path below; gated by the per-term parity
        # oracle + a grad/energy-consistency test.
        E = _energy_and_gradient_gpu!(grad, ws)
    else
        apply_operator_via_registry!(grad, ws)
        E = energy_decomposition(ws).total
    end
    # Wirtinger scaling: δE = 2·Re⟨δE/δψ̄, δψ⟩ ⇒ grad_R = 2·δE/δψ̄
    # makes δE = Re⟨grad_R, δψ⟩ (standard real inner product).
    grad .*= 2
    return E
end

# GPU fused energy+gradient — implemented in the CUDA extension (gpu_energy.jl).
function _energy_and_gradient_gpu! end

# --- per-term gradient helpers ---
#
# Each helper mutates `grad` in place with its term's contribution to
# δE/δψ* (BEFORE the final ×2 complex-convention scaling done by the
# parent `energy_gradient!`). Helpers are gated on coupling magnitude so
# they no-op when the term is inactive.

# Per-term gradient bodies (_grad_trap!, _grad_zeeman!, _grad_c0_density!,
# _grad_lhy!) now live with their HamTerm subtypes in src/hamiltonian/terms/.
# `energy_gradient!` above calls each by its canonical name — Julia resolves
# to the terms/ definition. The trinity dispatch
# (`apply_operator!(out, ::Term, ws, psi)`) provides the same physics via
# the registry.

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
