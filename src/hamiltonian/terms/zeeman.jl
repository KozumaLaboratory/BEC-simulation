# --- Zeeman family: LinearZeemanZTerm + TransverseZeemanTerm + MagneticGradientTerm ---
#
# All three terms encode pieces of `H_Zeeman = -(g_F μ_B B · F) + q F_z²`
# (user spec `b_block_builders.jl:27`):
#
#   LinearZeemanZTerm       : H_z      = -p·F_z + q·F_z²  (diagonal in m)
#   TransverseZeemanTerm    : H_perp   = -bx·F_x - by·F_y  (off-diagonal in m)
#   MagneticGradientTerm    : H_MG     = g_F·grad(t)·x_axis (spin-INDEPENDENT — see file note)
#
# Consolidation rationale: these three Hamiltonian pieces share the
# B-field origin and the user-spec sign convention; grouping the trinity
# methods + energy/gradient bodies in one file makes the convention
# audit fit in a single screen. Each term remains an independent
# HamTerm subtype with its own trinity dispatch.

# ============================================================================
# LinearZeemanZTerm — H_z = -p·F_z + q·F_z²
# ============================================================================
#
# Single source of truth for the z-Zeeman sign convention. User spec
# `b_block_builders.jl:27`: H = -(g_F μ_B B · F) + q F_z², so the z piece
# is -p·F_z with p = g_F·μ_B·B_z/(ℏ·ω_ref). Lower energy at +F_z when p>0.

"""
Linear z-Zeeman + quadratic z-Zeeman.

`H = -p·F_z + q·F_z²` per user spec (`b_block_builders.jl:27`).
"""
struct LinearZeemanZTerm <: HamTerm
    p::Float64
    q::Float64
end

# THE ONE LINE. The user-spec sign convention lives here exclusively.
# Every method below derives from this. Flipping `-p*m` to `+p*m`
# flips propagator AND energy AND gradient simultaneously — the
# sign_oracle test catches it immediately.
@inline _diag_coef(term::LinearZeemanZTerm, m::Real) = -term.p * m + term.q * m * m

function apply_operator!(out::AbstractArray, term::LinearZeemanZTerm, ws, psi::AbstractArray)
    # Direct broadcast accumulation (device-generic, zero-alloc).
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    for c in 1:D
        coef = _diag_coef(term, F - (c - 1))
        coef == 0.0 && continue
        idx = _component_slice(N, n_pts, c)
        view(out, idx...) .+= coef .* view(psi, idx...)
    end
    return out
end

function energy_contribution(term::LinearZeemanZTerm, psi::AbstractArray{<:Complex}, ws)
    # Diagonal: E = Σ_c coef_c · ‖ψ_c‖² · dV — per-component sum(abs2)
    # is device-generic and allocation-free (P1).
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    E = 0.0
    for c in 1:D
        coef = _diag_coef(term, F - (c - 1))
        coef == 0.0 && continue
        idx = _component_slice(N, n_pts, c)
        E += coef * sum(abs2, view(psi, idx...))
    end
    return E * cell_volume(ws.grid)
end

function apply_step!(term::LinearZeemanZTerm, psi::AbstractArray{<:Complex},
    dt::Real, imaginary_time::Bool, ws)
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    # ITP shift to prevent overflow: subtract min(diag) per the
    # standard SpinorBEC convention (CLAUDE.md "ITP Zeeman shift").
    shift = imaginary_time ? minimum(_diag_coef(term, F - (c - 1)) for c in 1:D) : 0.0
    @inbounds for c in 1:D
        m = F - (c - 1)
        coef = _diag_coef(term, m)
        if imaginary_time
            factor = exp(-(coef - shift) * dt)
            for I in CartesianIndices(n_pts)
                psi[I, c] *= factor
            end
        else
            factor = cis(-coef * dt)
            for I in CartesianIndices(n_pts)
                psi[I, c] *= factor
            end
        end
    end
    return nothing
end

"""
    _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)

Diagonal `-p·F_z + q·F_z²` body used by `_energy_decomposition_cpu`.
Caller already evaluates `zeeman_at(ws.zeeman, t)` and passes the result.
"""
function _zeeman_energy(psi, zeeman, sys, n_comp, ndim, n_pts, dV)
    p = zeeman.p
    q = zeeman.q
    E = 0.0
    @inbounds for c in 1:n_comp
        m = sys.m_values[c]
        zee_c = -p * m + q * m * m
        idx = _component_slice(ndim, n_pts, c)
        E += zee_c * sum(abs2, view(psi, idx...)) * dV
    end
    E
end

"""
    _grad_zeeman!(grad, psi, ws, n_pts, D, ::Val{N})

Add the full Zeeman gradient (diagonal + transverse) to `grad`. The
diagonal piece is folded inline; the transverse piece dispatches to
`TransverseZeemanTerm.apply_operator!` to close [GAP-1] (pre-2026-06-04
the routine silently dropped the transverse contribution).
"""
function _grad_zeeman!(grad, psi, ws, n_pts, D, ::Val{N}) where {N}
    zee = zeeman_at(ws.zeeman, ws.state.t)
    zee_vals = zeeman_energies(zee, ws.spin_matrices.system)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        view(grad, idx...) .+= zee_vals[c] .* view(psi, idx...)
    end
    bx, by = transverse_b(ws.zeeman, ws.state.t)
    if !(bx == 0.0 && by == 0.0)
        apply_operator!(grad, TransverseZeemanTerm(bx, by), ws, psi)
    end
    nothing
end

"""
Directional sign oracle for `LinearZeemanZTerm`. With +p (representing
+Bz), ITP from `:m_plus_F` initial state should preserve ⟨F_z⟩ ≈ +F.
"""
function sign_oracle(::Type{LinearZeemanZTerm})
    return (
        name="LinearZeemanZTerm: +p ⇒ ⟨F_z⟩ > 0",
        predicate=function (psi, ws)
            sm = ws.spin_matrices
            N = ndims(psi) - 1
            _, _, fz = spin_density_vector(psi, sm, N)
            return sum(fz) * cell_volume(ws.grid) > 0.5
        end,
    )
end

# ============================================================================
# TransverseZeemanTerm — H_perp = -bx·F_x - by·F_y
# ============================================================================
#
# Closes [GAP-1] from the systematic 2026-06-04 audit: the pre-fix
# `_zeeman_energy` and `_grad_zeeman!` silently dropped transverse
# contributions because they only read `zeeman.p` and `zeeman.q`. The
# HamTerm-based dispatch makes this structurally impossible: a
# Workspace whose registry contains a `TransverseZeemanTerm` includes
# the transverse contribution via `energy_contribution` / `apply_operator!`
# automatically.

"""
Linear transverse Zeeman: `H = -bx·F_x - by·F_y` per user spec.
"""
struct TransverseZeemanTerm <: HamTerm
    bx::Float64
    by::Float64
end

# THE ONE LINE. Sign convention -bx·F_x - by·F_y lives here exclusively.
@inline _h_matrix(term::TransverseZeemanTerm, sm) =
    (-term.bx) .* Matrix(sm.Fx) .+ (-term.by) .* Matrix(sm.Fy)

function apply_step!(term::TransverseZeemanTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # `apply_uniform_spin_rotation!` applies `exp(-i·dt·(phi·F̂))`, i.e.
    # H_eff = +phi_x·F_x + phi_y·F_y. To realise `H = -bx·F_x - by·F_y`,
    # pass phi = (-bx, -by). The 2026-06-04 sign bug was passing phi = (+bx, +by) directly.
    apply_uniform_spin_rotation!(
        psi, ws.spin_matrices,
        -term.bx, -term.by, 0.0,
        dt, ndims(psi) - 1;
        imaginary_time=imaginary_time,
        scratch=ws.state.psi_scratch,
    )
    return nothing
end

"""
    _transverse_zeeman_energy(psi, bx, by, sm, ndim, dV)

`⟨H_perp⟩ = -bx·⟨F_x⟩ - by·⟨F_y⟩` for the spatially-uniform
transverse-Zeeman term.
"""
function _transverse_zeeman_energy(psi, bx::Real, by::Real, sm, ndim, dV)
    (bx == 0.0 && by == 0.0) && return 0.0
    fx, fy, _ = spin_density_vector(psi, sm, ndim)
    return (-bx) * sum(fx) * dV + (-by) * sum(fy) * dV
end

function apply_operator!(out::AbstractArray, term::TransverseZeemanTerm, ws, psi::AbstractArray)
    # Gate-first + direct ladder accumulation (device-generic broadcast,
    # zero-alloc; same coefficients as the original body).
    (term.bx == 0.0 && term.by == 0.0) && return out
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    coeff_lower = -(term.bx + im * term.by) / 2   # acts at c reading psi at c-1
    coeff_upper = -(term.bx - im * term.by) / 2   # acts at c-1 reading psi at c
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        view(out, idx_c...) .+= coeff_lower .* fp .* view(psi, idx_cm1...)
        view(out, idx_cm1...) .+= coeff_upper .* fp .* view(psi, idx_c...)
    end
    return out
end

function energy_contribution(term::TransverseZeemanTerm, psi::AbstractArray{<:Complex}, ws)
    # Gate BEFORE any allocation (P1: the inactive term used to pay a
    # full similar(psi) + dot on every energy_decomposition call).
    (term.bx == 0.0 && term.by == 0.0) && return 0.0
    out = similar(psi)
    fill!(out, zero(eltype(out)))
    apply_operator!(out, term, ws, psi)
    return real(dot(vec(psi), vec(out))) * cell_volume(ws.grid)
end

# Context-aware: E = −bx·∫f_x − by·∫f_y from the shared spin densities.
function energy_contribution(
    term::TransverseZeemanTerm, psi::AbstractArray{<:Complex}, ws, ctx::EnergyContext
)
    (term.bx == 0.0 && term.by == 0.0) && return 0.0
    s = 0.0
    @inbounds for i in eachindex(ctx.fx, ctx.fy)
        s += -term.bx * ctx.fx[i] - term.by * ctx.fy[i]
    end
    return s * ctx.dV
end

"""
Directional sign oracle for `TransverseZeemanTerm`. With +bx and a small
+Bz parity breaker, ITP from `:m_plus_F` should give ⟨F_x⟩ > 0.
"""
function sign_oracle(::Type{TransverseZeemanTerm})
    return (
        name="TransverseZeemanTerm: +bx ⇒ ⟨F_x⟩ > 0",
        predicate=function (psi, ws)
            sm = ws.spin_matrices
            N = ndims(psi) - 1
            fx, _, _ = spin_density_vector(psi, sm, N)
            return sum(fx) * cell_volume(ws.grid) > 0.0
        end,
    )
end

# ============================================================================
# MagneticGradientTerm — H_MG = g_F · grad(t) · x_axis (spin-independent)
# ============================================================================
#
# Closes [GAP-2] of the systematic Hamiltonian audit. The propagator
# `_apply_mg_to_V!(ws, t)` in `split_step.jl:130` mutates
# `ws.potential_values` IN PLACE by adding `ΔV(r) = g_F·grad(t)·x_axis`
# (per-voxel scalar, same for every spin component). The diagonal step
# sees `V_eff = V_trap + ΔV`, applies `exp(-V_eff·dt)`, and
# `_remove_mg_from_V!` restores `V_trap` so the workspace field is
# "clean" between split_step calls.
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
