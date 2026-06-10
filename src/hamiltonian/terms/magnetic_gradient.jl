# --- MagneticGradientTerm — H_MG = g_F · grad(t) · x_axis (spin-independent) ---
#
# NOT a Zeeman term despite the "B-field" framing: the propagator
# `_apply_mg_to_V!(ws, t)` in `split_step.jl` mutates `ws.potential_values`
# IN PLACE by adding `ΔV(r) = g_F·grad(t)·x_axis` (per-voxel scalar, the
# SAME for every spin component). The diagonal step sees
# `V_eff = V_trap + ΔV`, applies `exp(-V_eff·dt)`, and `_remove_mg_from_V!`
# restores `V_trap` so the workspace field is clean between split_step calls.
#
# Therefore the Hamiltonian contribution is
#   H_MG = g_F · grad(t) · x_axis ⊗ 𝟙_spin     (spin-INDEPENDENT)
#   E_MG = g_F · grad(t) · ∫ x_axis · n(r) d³r
#   ∂E_MG/∂ψ*_c = g_F · grad(t) · x_axis · ψ_c
#
# This is NOT a true Stern-Gerlach gradient (which would carry an F_z
# factor). The YAML reference calls it "Stern-Gerlach-style" but the
# implementation treats `g_F` as a generic scalar prefactor; users who
# need m-dependence must use a different mechanism.
#
# Pre-[GAP-2]: `energy_decomposition` and `energy_gradient!` both
# silently dropped MG because the legacy code only read
# `ws.potential_values` (clean between split_step calls). Closed
# 2026-06-04 by routing MG through the HamTerm registry.

"""
Magnetic gradient along a single axis. Spin-INDEPENDENT linear
potential `H = g_F · grad(t) · x_axis` (see file note above).
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

"""
    _magnetic_gradient_energy(psi, ws, ndim, n_pts, dV)

`E_MG = g_F · grad · ∫ x_axis · n_total(r) d³r`. Body used by
`_energy_decomposition_cpu`. Mirror of `energy_contribution(::MagneticGradientTerm, ...)`.
"""
function _magnetic_gradient_energy(psi, ws, ndim, n_pts, dV)
    p = _mg_at(ws)
    p === nothing && return 0.0
    coeff = p.g_F * p.grad
    coeff == 0.0 && return 0.0
    D = size(psi, ndim + 1)
    x_axis = _to_host(ws.grid.x[p.axis])
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

function energy_contribution(::MagneticGradientTerm, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    return _magnetic_gradient_energy(psi, ws, N, n_pts, cell_volume(ws.grid))
end

function apply_operator!(out::AbstractArray, ::MagneticGradientTerm, ws, psi::AbstractArray)
    # Gate-first + direct accumulation (P1: the inactive term used to
    # allocate a full similar(psi) before short-circuiting).
    p = _mg_at(ws)
    p === nothing && return out
    coeff = p.g_F * p.grad
    coeff == 0.0 && return out
    N = ndims(psi) - 1
    D = size(psi, N + 1)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    x_bcast = _axis_broadcast(view(psi, ntuple(_ -> :, Val(N))..., 1),
        ws.grid.x[p.axis], p.axis)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(out, idx...) .+= coeff .* x_bcast .* view(psi, idx...)
    end
    return out
end

"""
Directional sign oracle for MagneticGradientTerm.

For the spin-independent gradient `H = g_F·grad·x_axis`, the propagator
is `exp(-H·dτ)` (ITP). For a state spread across `±x_axis`, ITP under
+grad damps the +x half exponentially harder and amplifies the −x half.
The post-ITP density-weighted ⟨x_axis⟩ is therefore < 0 when
`g_F · grad > 0`.
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
