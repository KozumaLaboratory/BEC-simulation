# Singlet-pair (c₂) wiring in the rotating basis (Option γ).
#
# The S=0 channel is rotationally invariant, so the rotating path applies the
# SAME shared `apply_singlet_pair_step!` (CPU+GPU) the standard path uses,
# directly on ψ̃ — no rotating-specific reimplementation. This test gates that
# the wiring is live and physically sound on a static field:
#   (1) norm conserved under RTP (the step is norm-preserving),
#   (2) total magnetization ⟨F_z⟩ conserved (pairing couples m ↔ -m, net 0),
#   (3) c₂ ≠ 0 has a non-trivial effect vs c₂ = 0 (proves the call is reached).
#
# A stronger rotating-vs-standard ground-state parity gate (static B̂ = ẑ, where
# the tilde basis coincides with the lab basis) is the natural follow-up once
# run against a standard `Workspace` ITP.

using Test
using SpinorBEC

function _rot_fz(ws)
    per_m = SpinorBEC.rotating_per_m_norms(ws)
    mvals = ws.spin_matrices.system.m_values
    sum(mvals[c] * per_m[c] for c in eachindex(mvals))
end

@testset "Option γ singlet-pair c₂ wiring (static field)" begin
    config = GridConfig((8, 8, 8), (6.0, 6.0, 6.0))
    grid = SpinorBEC.make_grid(config)
    F = 1
    D = 2F + 1

    V_trap = zeros(Float64, 8, 8, 8)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x * x + y * y + z * z)
    end

    # Seed m=+1 and m=-1 equally (+ a little m=0) so singlet pairing has work to
    # do. Static B̂ = ẑ, no DDI, no spin-mixing — isolate the c₂ channel.
    function seed!(ws)
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            z = grid.x[3][I[3]]
            g = exp(-(x * x + y * y + z * z) / (2σ * σ))
            ws.psi_tilde[I, 1] = g          # m = +1
            ws.psi_tilde[I, 2] = 0.3 * g    # m = 0
            ws.psi_tilde[I, 3] = g          # m = -1
        end
        SpinorBEC.normalize_rotating!(ws)
    end

    make_ws(c2) = SpinorBEC.make_rotating_basis_ws(
        grid, F, V_trap;
        p=0.0, q=0.0, c0=20.0, c1=0.0, c2=c2, c_dd=0.0,
        theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
    )

    @testset "norm + ⟨F_z⟩ conserved under c₂ RTP" begin
        ws = make_ws(-8.0)
        seed!(ws)
        fz0 = _rot_fz(ws)
        SpinorBEC.evolve_rotating!(ws, 40, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol = 1e-7
        # Singlet pairing couples (m=+1, m=-1) with net F_z = 0 ⇒ ⟨F_z⟩ fixed.
        @test isapprox(_rot_fz(ws), fz0; atol = 1e-6)
    end

    @testset "c₂ ≠ 0 changes the dynamics (wiring is reached)" begin
        ws_off = make_ws(0.0)
        seed!(ws_off)
        SpinorBEC.evolve_rotating!(ws_off, 40, 0.005)
        pm_off = SpinorBEC.rotating_per_m_norms(ws_off)

        ws_on = make_ws(-8.0)
        seed!(ws_on)
        SpinorBEC.evolve_rotating!(ws_on, 40, 0.005)
        pm_on = SpinorBEC.rotating_per_m_norms(ws_on)

        # With only c₀ (c₂=0) the per-m populations are static; c₂ pairing must
        # move them. A measurable difference proves the singlet-pair call fires.
        @test maximum(abs.(pm_on .- pm_off)) > 1e-4
    end
end
