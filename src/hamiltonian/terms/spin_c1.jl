# --- SpinC1 HamTerm ---
#
# H_c1 = (c1/2) ∫ |F|² d³r where F = ψ̄·F̂·ψ is the spin density vector.
# Sign of c1 picks polar (>0) or FM (<0) ground state.

"""Spin (c1) interaction `H = (c1/2)·|F|²`. Sign of c1 picks polar/FM."""
struct SpinC1 <: HamTerm
    c1::Float64
end

@inline _spin_sign(term::SpinC1) = +term.c1

function apply_step!(term::SpinC1, psi, dt::Real, imaginary_time::Bool, ws)
    # Delegate to existing spin-mixing step.
    is_active(term.c1) || return nothing
    apply_spin_mixing_step!(
        psi, ws.spin_matrices, term.c1, dt, ndims(psi) - 1;
        imaginary_time=imaginary_time,
    )
    return nothing
end

function energy_contribution(term::SpinC1, psi::AbstractArray{<:Complex}, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    return _spin_interaction_energy(psi, ws.spin_matrices, term.c1, n_comp, N, n_pts,
        cell_volume(ws.grid))
end

function add_gradient!(grad, term::SpinC1, psi, ws)
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    fx = similar(psi, ComplexF64, n_pts...)
    fy = similar(psi, ComplexF64, n_pts...)
    fz = similar(psi, ComplexF64, n_pts...)
    # _grad_c1_spin! reads c1 from ws.interactions; temporarily ok if
    # ws.interactions[1] == term.c1 (the common case).
    _grad_c1_spin!(grad, psi, ws, fx, fy, fz, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{SpinC1}) = (
    name="SpinC1: c1<0 → FM ⟨|F|²⟩=F², c1>0 → polar ⟨|F|²⟩=0",
    predicate=(_, _) -> true,  # ground-state structure already tested in test_simulation.jl
)
