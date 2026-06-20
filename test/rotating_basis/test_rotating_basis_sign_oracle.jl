# Directional sign oracle for the rotating-basis Zeeman (Option γ).
#
# The standard registry has `test_hamiltonian_sign_oracles.jl` pinning
# `+p ⇒ ⟨F_z⟩ > 0` for ZeemanTerm. The rotating path builds its Zeeman via
# `zeeman_field_matrix!` (gated against `_diag_coef` at the matrix level in
# `test_redundancy_gates.jl` (f)); this test closes the loop with a
# *physics-level* directional check — that an actual rotating-basis ITP
# descends to the correct magnetization. A sign flip that somehow survived
# the matrix gate (or a future regression in the eigen-exact local-spin
# step) turns this red.

using Test
using SpinorBEC

# ⟨F_z⟩ in the rotating (tilde) basis with B̂ = ẑ: F_z is diagonal, so
# ⟨F_z⟩ = Σ_m m · (normalised per-m population).
function _rotating_Fz(ws)
    per_m = SpinorBEC.rotating_per_m_norms(ws)
    mvals = ws.spin_matrices.system.m_values
    sum(mvals[c] * per_m[c] for c in eachindex(mvals))
end

@testset "Option γ Zeeman sign oracle: sign(p) ⇒ sign(⟨F_z⟩)" begin
    config = GridConfig((8, 8, 8), (6.0, 6.0, 6.0))
    grid = SpinorBEC.make_grid(config)

    V_trap = zeros(Float64, 8, 8, 8)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x * x + y * y + z * z)
    end

    # Static B̂ = ẑ (θ=φ=0, Â=0), no spin coupling: the diagonal Zeeman alone
    # decides which m wins under imaginary-time descent. Seed every component
    # equally so ITP must redistribute toward the lowest-energy m.
    function ground_Fz(F, p)
        D = 2F + 1
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F, V_trap;
            p=p, q=0.0, c0=0.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
        )
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points), c in 1:D
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, c] = exp(-(x * x + y * y + z * z) / (2σ * σ))
        end
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.find_ground_state_rotating!(ws, 400, 0.02)
        _rotating_Fz(ws)
    end

    # H = -p F_z ⇒ lowest energy at m = +F for p>0 (m = -F for p<0).
    # F=1 (debugging) and F=6 (production ¹⁵¹Eu, D=13) — the latter also
    # exercises the diagonal fast path (`_apply_diagonal_spin_phase!`) at the
    # production spinor width.
    @testset "F=$F" for F in (1, 6)
        @test ground_Fz(F, 1.0) > 0.5 * F    # +p ⇒ ⟨F_z⟩ → +F
        @test ground_Fz(F, -1.0) < -0.5 * F  # -p ⇒ ⟨F_z⟩ → -F
    end
end
