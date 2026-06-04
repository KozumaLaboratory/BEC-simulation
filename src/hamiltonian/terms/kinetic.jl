# --- Kinetic HamTerm ---
#
# H_kinetic = (1/2) p² = -(1/2) ∇²  (universal, no sign question).
# All implementations delegate to the existing FFT-based kinetic
# routines. Provided for registry completeness; the consistency
# oracle here is "norm conservation under RT" + "energy decreases
# in IT" (standard kinetic-energy sanity).

"""
Universal kinetic energy `H = (1/2) k²` in momentum space.
"""
struct KineticTerm <: HamTerm end

@inline _kinetic_sign() = +0.5  # H = +(1/2)·k²; no user-spec sign question

function apply_step!(::KineticTerm, psi, dt::Real, imaginary_time::Bool, ws)
    apply_kinetic_step_batched!(psi, ws.batched_kinetic)
    return nothing
end

function energy_contribution(::KineticTerm, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(ws.grid)
    fft_buf = zeros(ComplexF64, ws.grid.config.n_points)
    return _kinetic_energy(psi, ws.grid, ws.fft_plans, fft_buf, n_comp, N, n_pts, dV)
end

function add_gradient!(grad, ::KineticTerm, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fft_buf = similar(psi, ComplexF64, n_pts...)
    k_squared_dev = _to_device(ws.backend, ws.grid.k_squared)
    _grad_kinetic!(grad, psi, ws, fft_buf, k_squared_dev, n_pts, D, Val(N))
    return nothing
end

# Context-aware specialisation: borrow ctx.fft_buf instead of allocating.
function add_gradient!(grad, ::KineticTerm, psi, ws, ctx::GradientContext)
    N = ndims(psi) - 1
    D = ws.spin_matrices.system.n_components
    k_squared_dev = _to_device(ws.backend, ws.grid.k_squared)
    _grad_kinetic!(grad, psi, ws, ctx.fft_buf, k_squared_dev, ctx.n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{KineticTerm}) = (
    name="KineticTerm: ⟨k²/2⟩ ≥ 0 always",
    predicate=function (psi, ws)
        E = energy_contribution(KineticTerm(), psi, ws)
        return E >= -1e-12  # FFT roundoff floor
    end,
)
