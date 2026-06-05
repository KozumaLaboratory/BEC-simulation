# --- LHY HamTerm ---
#
# Lee-Huang-Yang correction. Multiple LHY models share a HamTerm:
# the propagator/energy/gradient go through ws.lhy.

"""LHY beyond-mean-field correction. Repulsive by physics."""
struct LHYTerm <: HamTerm end

function apply_step!(::LHYTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # LHY is folded into the diagonal step in the legacy implementation;
    # at the HamTerm level we delegate via apply_lhy_step! if available.
    ws.lhy === nothing && ws.interactions.c_lhy == 0.0 && return nothing
    apply_lhy_step!(psi, ws, dt; imaginary_time=imaginary_time)
    return nothing
end

function energy_contribution(::LHYTerm, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    if ws.lhy !== nothing
        return _lhy_energy(psi, ws.lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    elseif ws.interactions.c_lhy != 0.0
        return _lhy_energy(psi, ws.interactions.c_lhy, n_comp, N, n_pts, cell_volume(ws.grid))
    end
    return 0.0
end

# ============================================================================
# Trinity authoritative kernel: apply_operator!
# E_LHY = (2/5)·c_lhy·∫n^(5/2)·dV (scalar) or ws.lhy's specific formula.
# δE/δψ̄ = c_lhy·n^(3/2)·ψ (scalar LHY). `_grad_lhy!` implements this;
# apply_operator! is a fill-then-call wrapper.
# ============================================================================

function apply_operator!(out::AbstractArray, ::LHYTerm, ws, psi::AbstractArray)
    fill!(out, zero(eltype(out)))
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    n_density = total_density(psi, N)
    _grad_lhy!(out, psi, ws, n_density, n_pts, D, Val(N))
    return out
end

function add_gradient!(grad, ::LHYTerm, psi, ws)
    buf = similar(psi)
    apply_operator!(buf, LHYTerm(), ws, psi)
    grad .+= buf
    return nothing
end

# Context-aware: borrow ctx.n_density.
function add_gradient!(grad, ::LHYTerm, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    _grad_lhy!(grad, psi, ws, ctx.n_density, ctx.n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{LHYTerm}) = (
    name="LHYTerm: c_lhy > 0 ⇒ E_LHY > 0 (repulsive correction)",
    predicate=function (psi, ws)
        c_lhy = ws.lhy === nothing ? ws.interactions.c_lhy : 1.0
        E = energy_contribution(LHYTerm(), psi, ws)
        return c_lhy >= 0.0 ? E >= -1e-12 : E <= 1e-12
    end,
)
