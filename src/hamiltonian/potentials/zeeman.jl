export zeeman_diagonal, zeeman_energies, zeeman_at

"""
Return Zeeman energy shifts as a vector indexed by m = F, F-1, ..., -F.

Linear Zeeman: E_m = -p * m
Quadratic Zeeman: E_m = q * m²
"""
function zeeman_energies(z::ZeemanParams, sys::SpinSystem)
    [(-z.p * m + z.q * m^2) for m in sys.m_values]
end

function zeeman_diagonal(z::ZeemanParams, sys::SpinSystem)
    SVector{sys.n_components, Float64}(zeeman_energies(z, sys))
end

function zeeman_diagonal(z::ZeemanParams, sm::SpinMatrices{D}) where {D}
    F = sm.system.F
    SVector{D, Float64}(ntuple(c -> -z.p * (F - (c - 1)) + z.q * (F - (c - 1))^2, Val(D)))
end

# Quadratic-only variant: returns q F_z² without the linear Zeeman.
# Used when the linear -p F_z is folded into the same uniform_spin_rotation
# call as the transverse Bx F_x + By F_y so the full linear spin
# Hamiltonian is computed as one exact matrix exponential — eliminating the
# Strang error between -p F_z and ±B_⊥·F_⊥ that scrambles the spin in
# strong-field runs (Klaus 2022 magnetostir, etc.).
function zeeman_diagonal_quadratic_only(z::ZeemanParams, sm::SpinMatrices{D}) where {D}
    F = sm.system.F
    SVector{D, Float64}(ntuple(c -> z.q * (F - (c - 1))^2, Val(D)))
end

# Spin rotating-frame variant: returns the H_rot diagonal for ψ_rot evolution.
# H_rot_diag(m) = -(p - ω_R) m + q m²  (the +ω_R F_z from i ∂_t U U† cancels
# the -p F_z linear Zeeman when ω_R = p).
function zeeman_diagonal(z::ZeemanParams, sm::SpinMatrices{D}, omega_R::Float64) where {D}
    F = sm.system.F
    p_eff = z.p - omega_R
    SVector{D, Float64}(ntuple(c -> -p_eff * (F - (c - 1)) + z.q * (F - (c - 1))^2, Val(D)))
end

zeeman_at(z::ZeemanParams, ::Float64) = z
zeeman_at(z::TimeDependentZeeman, t::Float64) = ZeemanParams(
    evaluate(z.p_wf, t), evaluate(z.q_wf, t)
)
