# --- TransverseZeemanTerm HamTerm ---
#
# Single-source-of-truth declaration of `H_perp = -bx·F_x - by·F_y`. The
# user-spec convention (`b_block_builders.jl:27`) is
# `H_Zeeman = -(g_F μ_B B · F)`; the transverse piece is therefore
# `-bx·F_x - by·F_y` with `bx = +g_F μ_B B_x / (ℏ ω_ref)`.
#
# Phase 2 (2026-06-04): closes [GAP-1] from the systematic audit —
# `_zeeman_energy` and `_grad_zeeman!` silently dropped transverse
# contributions because they only read `zeeman.p` and `zeeman.q`. The
# HamTerm-based dispatch makes this structurally impossible: a
# Workspace that contains a `TransverseZeemanTerm` in its term registry
# has its energy and gradient automatically include the transverse
# contribution via `energy_contribution` / `add_gradient!`.

"""
Linear transverse Zeeman: `H = -bx·F_x - by·F_y` per user spec.
"""
struct TransverseZeemanTerm <: HamTerm
    bx::Float64
    by::Float64
end

# THE ONE LINE. Sign convention -bx·F_x - by·F_y lives here exclusively.
# Returns the (D × D) spatially-uniform Hamiltonian matrix. Flipping
# the signs flips propagator AND energy AND gradient simultaneously;
# the sign_oracle test catches it.
@inline _h_matrix(term::TransverseZeemanTerm, sm) =
    (-term.bx) .* Matrix(sm.Fx) .+ (-term.by) .* Matrix(sm.Fy)

function apply_step!(term::TransverseZeemanTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # `apply_uniform_spin_rotation!` applies `exp(-i·dt·(phi·F̂))`, i.e.
    # H_eff = +phi_x·F_x + phi_y·F_y. To realise `H = -bx·F_x - by·F_y`,
    # pass phi = (-bx, -by). This was the source of the 2026-06-04
    # sign bug when the legacy code passed phi = (+bx, +by) directly.
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
    _transverse_zeeman_energy_core(psi, bx, by, sm, ndim, dV)

`⟨H_perp⟩ = -bx·⟨F_x⟩ - by·⟨F_y⟩` for the spatially-uniform
transverse-Zeeman term. Closes [GAP-1] — pre-2026-06-04 the legacy
`_zeeman_energy` silently dropped this contribution.
"""
function _transverse_zeeman_energy_core(psi, bx::Real, by::Real, sm, ndim, dV)
    (bx == 0.0 && by == 0.0) && return 0.0
    fx, fy, _ = spin_density_vector(psi, sm, ndim)
    return (-bx) * sum(fx) * dV + (-by) * sum(fy) * dV
end

function energy_contribution(term::TransverseZeemanTerm, psi::AbstractArray{<:Complex}, ws)
    sm = ws.spin_matrices
    N = ndims(psi) - 1
    dV = cell_volume(ws.grid)
    return _transverse_zeeman_energy_core(psi, term.bx, term.by, sm, N, dV)
end

function add_gradient!(grad::AbstractArray{<:Complex}, term::TransverseZeemanTerm,
    psi::AbstractArray{<:Complex}, ws)
    # ∂E/∂ψ̄_m = (H_perp · ψ)_m. With H_perp = -bx·F_x - by·F_y and
    # F_x = (F_+ + F_-)/2, F_y = (F_+ - F_-)/(2i):
    #   H_perp = ((-bx + i·by)/2)·F_+ + ((-bx - i·by)/2)·F_-
    # F_+ |m⟩ = sqrt((F-m)(F+m+1)) |m+1⟩
    # F_- |m⟩ = sqrt((F+m)(F-m+1)) |m-1⟩
    # In code indexing (c=1 ↔ m=+F, c=D ↔ m=-F), c-1 corresponds to m+1
    # and c+1 corresponds to m-1.
    sm = ws.spin_matrices
    F = sm.system.F
    D = sm.system.n_components
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    # H_perp_{m, m+1} = -bx·(F_x)_{m,m+1} - by·(F_y)_{m,m+1}
    # For (F_x)_{m,m+1} = (1/2)·sqrt(F(F+1) - m(m+1)) > 0  (real positive)
    # For (F_y)_{m,m+1} = (i/2)·sqrt(F(F+1) - m(m+1))     (imaginary positive)
    # So H_perp_{m, m+1} = -(bx + i·by)/2 · sqrt(...)
    # And H_perp_{m+1, m} = conj(H_perp_{m, m+1}) = -(bx - i·by)/2 · sqrt(...)
    # In code: c→m+1, c-1→m (c-1 corresponds to higher m).
    coeff_lower = -(term.bx + im * term.by) / 2   # acts at c (lower m) reading psi at c-1 (higher m)
    coeff_upper = -(term.bx - im * term.by) / 2   # acts at c-1 (higher m) reading psi at c (lower m)
    # The matrix element ⟨m | H_perp | m+1⟩ = coeff_to_cm1 · sqrt((F-m)(F+m+1))
    # connects c (=> m) to c-1 (=> m+1). So grad[c] gets contribution
    # from coeff_to_cm1 · sqrt(...) · psi[c-1] and vice versa.
    for c in 2:D
        idx_c = _component_slice(N, n_pts, c)
        idx_cm1 = _component_slice(N, n_pts, c - 1)
        # The F+/F- prefactor between m (at c) and m+1 (at c-1):
        # m_below = F - (c-1) = F - c + 1, sqrt((F-m_below)(F+m_below+1)) = sqrt(c·(2F-c+2)) ... use the standard form
        # Mirror `_grad_c1_spin!` for arithmetic consistency:
        fp = sqrt(Float64(F * (F + 1) - (F - c + 1) * (F - c + 2)))
        # In my code: c indexes m (lower), c-1 indexes m+1 (higher).
        # Wait: c=1 ↔ m=+F, c=D ↔ m=-F. So c-1 corresponds to m+1
        # (higher m). The matrix element from psi at c-1 (higher m,
        # role m'+1) acting onto grad at c (lower m, role m) needs the
        # H_perp_{m, m'} where m'=m+1.  H_{m, m+1} = -(bx + i*by)/2 * fp.
        view(grad, idx_c...) .+= coeff_lower .* fp .* view(psi, idx_cm1...)
        view(grad, idx_cm1...) .+= coeff_upper .* fp .* view(psi, idx_c...)
    end
    return nothing
end

"""
Directional sign oracle for `TransverseZeemanTerm`. With +bx and a small
+Bz parity breaker, ITP from `:m_plus_F` should give ⟨F_x⟩ > 0 (spin
aligns WITH +Bx as the user spec demands). Pre-2026-06-04 the sign
was inverted (⟨F_x⟩ < 0 at +Bx) — this oracle catches the regression.
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
