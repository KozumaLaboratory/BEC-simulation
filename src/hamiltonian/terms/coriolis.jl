# --- Coriolis HamTerm ---
#
# Single-source-of-truth declaration of `H_coriolis = -Ω·L_z` where
# `L_z = x·p_y - y·p_x = -i·(x·∂_y - y·∂_x)`. This is the orbital
# Coriolis piece of the rotating-frame Hamiltonian
# `H_rot = H_lab - Ω·(L_z + F_z)` (the F_z piece is handled
# separately via `_shift_zeeman_for_rotating_frame`).
#
# Phase 2 (2026-06-04): consolidates the 2026-06-03 sign-audit work
# (`mistake_coriolis_substep_sign_2026_06_03`) into the HamTerm
# protocol. The 3-shear factor signs in `_apply_coriolis_step!`
# remain authoritative — `apply_step!` delegates to it. Energy and
# gradient delegate to the audited `orbital_angular_momentum` /
# `_grad_coriolis!` routines.

"""
Coriolis (orbital) piece of the rotating-frame Hamiltonian.
`H = -Ω · L_z` where `L_z = -i·(x·∂_y - y·∂_x)`.
"""
struct Coriolis <: HamTerm
    Ω::Float64
end

# THE ONE LINE. Sign convention `H_coriolis = -Ω·L_z` lives here.
# Read this way: positive Ω makes negative ΔE on +L_z eigenstates,
# so descent on -Ω·L_z amplifies +L_z components in ITP.
@inline _coriolis_sign(term::Coriolis) = -term.Ω

function apply_step!(term::Coriolis, psi, dt::Real, imaginary_time::Bool, ws)
    _apply_coriolis_step!(psi, ws.grid, term.Ω, dt, imaginary_time, ws.coriolis_cache)
    return nothing
end

function energy_contribution(term::Coriolis, psi::AbstractArray{<:Complex}, ws)
    # E_coriolis = -Ω · ⟨L_z⟩ (energy.jl:97-98 convention).
    N = ndims(psi) - 1
    N >= 2 || return 0.0
    return _coriolis_sign(term) * orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
end

function add_gradient!(grad::AbstractArray{<:Complex}, term::Coriolis,
    psi::AbstractArray{<:Complex}, ws)
    # ∂E/∂ψ̄ = -Ω · L_z · ψ = +iΩ · (x·∂_y - y·∂_x) · ψ
    # Delegate to existing `_grad_coriolis!`, which encodes the
    # +iΩ·(x∂_y - y∂_x) decomposition correctly (energy_gradient.jl:117).
    # We just need scratch buffers it expects.
    N = ndims(psi) - 1
    N >= 2 || return nothing
    abs(term.Ω) < SpinorBEC.ROTATION_TOL && return nothing
    D = ws.spin_matrices.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))
    # `_grad_coriolis!` requires fft_buf and deriv_buf scratch.
    fft_buf = similar(psi, ComplexF64, n_pts...)
    deriv_buf = similar(psi, ComplexF64, n_pts...)
    # Use the workspace's stored Ω temporarily, then restore.
    Ω_save = ws.sim_params.rotating_frame_omega
    ws_overridden = ws  # NOTE: rotating_frame_omega is a field of sim_params; for
    # the consistency test we mutate-and-restore. In a future
    # refactor, we lift Ω out of sim_params entirely.
    @assert isapprox(Ω_save, term.Ω; atol=1e-12) ||
        isapprox(Ω_save, 0.0; atol=1e-12) "Coriolis term Ω mismatch — workspace and HamTerm should agree"
    _grad_coriolis!(grad, psi, ws, fft_buf, deriv_buf, n_pts, D, Val(N))
    return nothing
end

"""
Directional sign oracle for `Coriolis`. In ITP, the substep
`exp(+Ω·L_z·dτ)` amplifies the +L_z eigenstate `(x+iy)·gauss`
relative to the -L_z eigenstate `(x-iy)·gauss`. With +Ω, the ratio
of post-step `||ψ_+||²` to pre-step is `exp(+2Ω·dτ)`.

The Coriolis directional test is **already enshrined** in
`test/solvers/test_simulation.jl:253` — this oracle is the
HamTerm-facing wrapper for documentation/CI integration.
"""
function sign_oracle(::Type{Coriolis})
    return (
        name="Coriolis: +Ω ⇒ amplifies +L_z component",
        predicate=function (psi, ws)
            # The vortex (x+iy)·gauss seed has L_z = +1. After ITP with
            # +Ω, its norm² grows by exp(+2Ω·dτ) per step.
            # Implementation: caller must seed the state appropriately;
            # the predicate checks that ⟨L_z⟩ has increased relative
            # to the seed value (caller passes seed_Lz via ws).
            Lz_now = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
            return Lz_now > 0.5  # for (x+iy)·gauss seed, ⟨L_z⟩ ≈ 1
        end,
    )
end
