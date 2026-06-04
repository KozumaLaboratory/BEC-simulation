# --- MagneticGradientTerm HamTerm ---
#
# Closes [GAP-2] of the systematic Hamiltonian audit.
#
# # Propagator (current convention; load-bearing)
#
# `_apply_mg_to_V!(ws, t)` in `split_step.jl:130` mutates
# `ws.potential_values` IN PLACE by adding
#
#     ΔV(r) = g_F · grad(t) · x_axis
#
# (per-voxel scalar, the same for every spin component). The diagonal
# step then sees `V_eff = V_trap + ΔV`, applies `exp(-V_eff · dt)`
# (ITP) or `cis(-V_eff · dt)` (RT), and `_remove_mg_from_V!` restores
# `V_trap` so the workspace field is "clean" between split_step
# calls. `evaluate_potential(::MagneticGradient, grid)` returns the
# same ΔV — propagator and potential evaluator agree.
#
# Therefore the Hamiltonian contribution is
#
#     H_MG = g_F · grad(t) · x_axis ⊗ 𝟙_spin     (spin-INDEPENDENT)
#     E_MG = g_F · grad(t) · ∫ x_axis · n(r) d³r
#     ∂E_MG/∂ψ*_c = g_F · grad(t) · x_axis · ψ_c
#
# This is NOT a true Stern-Gerlach gradient (which would carry an F_z
# factor and be m-dependent). The YAML reference calls it
# "Stern-Gerlach-style" but the implementation treats `g_F` as a
# generic scalar prefactor; users who need m-dependence must
# additionally polarise the cloud or use a magnetic-field profile via
# a different mechanism. The term is internally self-consistent
# (propagator ↔ energy ↔ gradient) which is what the registry
# guarantees.
#
# Pre-[GAP-2]: `energy_decomposition` and `energy_gradient!` both
# silently dropped MG because the legacy code only read
# `ws.potential_values` (clean between split_step calls) and
# `_grad_trap!` (likewise). Closed 2026-06-04 by routing MG through
# the HamTerm registry.

"""
Magnetic gradient along a single axis. Spin-INDEPENDENT linear
potential `H = g_F · grad(t) · x_axis` (see file docstring).
"""
struct MagneticGradientTerm <: HamTerm end

"""
Resolve `(g_F, grad(t), axis)` from the workspace at the current time.
Returns `nothing` if MG is inactive on this workspace.
"""
@inline function _mg_at(ws)
    mg = ws.magnetic_gradient
    mg === nothing && return nothing
    grad_val = if mg isa TimeDependentMagneticGradient
        evaluate(mg.gradient_wf, ws.state.t)
    else
        mg.gradient
    end
    return (g_F=mg.g_F, grad=grad_val, axis=mg.axis)
end

function apply_step!(::MagneticGradientTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # Standalone propagator step: `cis(-g_F·grad·x · dt)` per voxel.
    # The PRODUCTION integration uses `_apply_mg_to_V!` + diagonal step
    # for sharing with V_trap; this standalone variant is provided for
    # registry-driven Strang stacks and one-term ITP tests.
    p = _mg_at(ws)
    p === nothing && return nothing
    coeff = p.g_F * p.grad
    coeff == 0.0 && return nothing
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    x_axis = ws.grid.x[p.axis]
    if imaginary_time
        for c in 1:D
            psi_c = view(psi, ntuple(_ -> :, Val(N))..., c)
            @inbounds for I in CartesianIndices(size(psi_c))
                psi_c[I] *= exp(-coeff * x_axis[I[p.axis]] * dt)
            end
        end
    else
        for c in 1:D
            psi_c = view(psi, ntuple(_ -> :, Val(N))..., c)
            @inbounds for I in CartesianIndices(size(psi_c))
                psi_c[I] *= cis(-coeff * x_axis[I[p.axis]] * dt)
            end
        end
    end
    return nothing
end

function energy_contribution(::MagneticGradientTerm, psi::AbstractArray{<:Complex}, ws)
    # E_MG = g_F · grad · ∫ x_axis · n_total(r) d³r where n_total = Σ_c |ψ_c|².
    p = _mg_at(ws)
    p === nothing && return 0.0
    coeff = p.g_F * p.grad
    coeff == 0.0 && return 0.0
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    x_axis = _to_host(ws.grid.x[p.axis])
    dV = cell_volume(ws.grid)
    E = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        n_I = 0.0
        for c in 1:D
            n_I += abs2(psi[I, c])
        end
        E += x_axis[I[p.axis]] * n_I
    end
    return coeff * E * dV
end

function add_gradient!(grad, ::MagneticGradientTerm, psi, ws)
    # ∂E_MG/∂ψ*_c = g_F · grad · x_axis · ψ_c (same coefficient per component).
    p = _mg_at(ws)
    p === nothing && return nothing
    coeff = p.g_F * p.grad
    coeff == 0.0 && return nothing
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    x_axis = _to_host(ws.grid.x[p.axis])
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        grad_c = view(grad, idx...)
        @inbounds for I in CartesianIndices(n_pts)
            grad_c[I] += coeff * x_axis[I[p.axis]] * psi_c[I]
        end
    end
    return nothing
end

"""
Directional sign oracle for MagneticGradientTerm.

For the current spin-independent gradient `H = g_F·grad·x_axis`, the
propagator is `exp(-H·dτ)` (ITP). For a state spread across `±x_axis`,
ITP under +grad damps the +x half exponentially harder and amplifies
the −x half. The post-ITP density-weighted ⟨x_axis⟩ is therefore < 0
when `g_F · grad > 0`.

This is the physical sign signature, independent of spin.
"""
function sign_oracle(::Type{MagneticGradientTerm})
    return (
        name="MagneticGradientTerm: +g_F·grad ⇒ ⟨x_axis⟩ < 0 after ITP",
        predicate=function (psi, ws)
            p = _mg_at(ws)
            p === nothing && return true
            coeff = p.g_F * p.grad
            coeff == 0.0 && return true
            N = ndims(psi) - 1
            D = size(psi, N + 1)
            n_pts = ntuple(d -> size(psi, d), Val(N))
            x_axis = _to_host(ws.grid.x[p.axis])
            dV = cell_volume(ws.grid)
            num = 0.0
            den = 0.0
            @inbounds for I in CartesianIndices(n_pts)
                n_I = 0.0
                for c in 1:D
                    n_I += abs2(psi[I, c])
                end
                num += x_axis[I[p.axis]] * n_I
                den += n_I
            end
            den = max(den, 1e-30)
            x_mean = num * dV / (den * dV)
            return coeff > 0 ? x_mean < 0.0 : x_mean > 0.0
        end,
    )
end
