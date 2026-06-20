# Rotating-basis ⇄ standard-path static-field parity (Option γ).
#
# `docs/design/rotating_basis_unification.md` prescribes that every term wired
# into the rotating path must pass a *rotating-vs-standard* parity gate on a
# STATIC field B̂ = ẑ — where the tilde basis coincides with the lab basis, so
# the rotating ground state must equal the standard split-step ground state for
# the same physics. That gate was missing; this file adds it.
#
# It is the physics-level (Layer-B) counterpart to the matrix-level Zeeman gate
# (`test_redundancy_gates.jl (f)`) and the directional sign oracle: rather than
# pinning one declaration, it validates that the WHOLE rotating integrator
# (kinetic + trap + c₀ + c₁ spin-mixing + c₂ singlet-pair + diagonal Zeeman)
# reproduces the production `find_ground_state` physics in ONE shot.
#
# Config — the spin-1 BROKEN-AXISYMMETRY phase (ferromagnetic c₁<0, quadratic
# 0 < q < q_c ≈ |c₁|·n_peak). It is the only static-B̂=ẑ regime where ALL of
# c₀/c₁/c₂/q shape the per-m populations: the polar (m=0) and antiferromagnetic
# (m=±1) phases have ⟨F⟩=0 (c₁-blind) and/or singlet-invariant populations
# (c₂-blind), so a wiring bug there is physically silent. Here the ground state
# is genuinely 3-component and every channel moves it. Verified by canary
# (deleting a channel in the rotating call moves per-m off the standard state):
#   - drop c₁ → per-m diverges by ~0.25
#   - drop c₂ → per-m diverges by ~0.03
# both ≫ the 2e-3 tolerance, so a real regression turns this red.

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, InteractionParams, ZeemanParams,
    HarmonicTrap, find_ground_state, make_rotating_basis_ws,
    find_ground_state_rotating!, normalize_rotating!, rotating_per_m_norms,
    component_populations

@testset "Option γ rotating ⇄ standard static-field GS parity" begin
    F = 1
    D = 2F + 1
    n = 16
    L = 10.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))

    V_trap = zeros(Float64, n, n, n)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x * x + y * y + z * z)
    end

    # Shared imaginary-time seed (both paths start identically so they descend
    # to the same minimum; the slightly transverse weighting picks one member
    # of the broken-axisymmetry U(1) family — per-m is invariant to which).
    σ = 1.0
    seed = zeros(ComplexF64, n, n, n, D)
    @inbounds for I in CartesianIndices((n, n, n))
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / (2σ * σ))
        seed[I, 1] = 0.7 * g    # m = +1
        seed[I, 2] = g          # m =  0
        seed[I, 3] = 0.7 * g    # m = -1
    end

    c0, c1, c2, p, q = 10.0, -5.0, -2.0, 0.0, 0.2

    # Standard production path.
    res = find_ground_state(;
        grid, atom=SpinorBEC.Na23,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1, 2 => c2)),
        zeeman=ZeemanParams(p, q),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)),
        dt=0.01, n_steps=8000, psi_init=copy(seed), tol=1e-13,
    )
    @test res.converged
    pop_std = component_populations(
        res.workspace.state.psi, grid, res.workspace.spin_matrices.system
    ).populations

    # Rotating path, static B̂ = ẑ.
    ws = make_rotating_basis_ws(
        grid, F, V_trap;
        p=p, q=q, c0=c0, c1=c1, c2=c2,
        theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
    )
    copyto!(ws.psi_tilde, seed)
    normalize_rotating!(ws)
    find_ground_state_rotating!(ws, 8000, 0.01)
    pm = rotating_per_m_norms(ws)
    pm ./= sum(pm)

    # Sanity: the gate is non-trivial — a genuine 3-component (broken-axisymmetry)
    # ground state, so every channel contributes (measured ≈ [0.125, 0.75, 0.125]).
    @test pop_std[1] > 0.05 && pop_std[3] > 0.05 && pop_std[2] > 0.3

    # Per-m populations agree. Measured residual ≈ 5e-4 (a converged O(dt²)
    # difference between the two Strang orderings, identical at 8k and 12k
    # steps); 2e-3 leaves 4× headroom while sitting ~15× below the smallest
    # canary divergence (drop-c₂ ≈ 0.03).
    @test maximum(abs.(pop_std .- pm)) < 2e-3

    # Total density n(r) = Σ_m |ψ_m|² is basis-invariant — Bhattacharyya
    # overlap (measured 1 − 1e-7).
    n_std = dropdims(sum(abs2, res.workspace.state.psi; dims=4); dims=4)
    n_rot = dropdims(sum(abs2, ws.psi_tilde; dims=4); dims=4)
    overlap =
        sum(sqrt.(max.(n_std, 0.0) .* max.(n_rot, 0.0))) /
        (sqrt(sum(n_std)) * sqrt(sum(n_rot)))
    @test overlap > 0.9999
end

# c₂ sign check. The parity test above already gates the *presence* of the c₂
# wiring (drop-c₂ canary moves per-m by ~0.03). This pins its energetic SIGN
# independently: an attractive singlet (c₂<0) must LOWER the imaginary-time
# chemical potential of the m=0 polar ground state (where the singlet amplitude
# a₀ ∝ ψ₀² is non-zero). A flipped sign would raise it.
@testset "Option γ singlet-pair c₂ lowers the rotating GS energy" begin
    F = 1
    n = 16
    L = 10.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    V_trap = zeros(Float64, n, n, n)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x * x + y * y + z * z)
    end

    function ground_mu(c2)
        ws = make_rotating_basis_ws(
            grid, F, V_trap;
            p=0.0, q=0.1, c0=10.0, c1=1.0, c2=c2,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
        )
        σ = 1.0
        @inbounds for I in CartesianIndices((n, n, n))
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            z = grid.x[3][I[3]]
            g = exp(-(x * x + y * y + z * z) / (2σ * σ))
            ws.psi_tilde[I, 1] = g
            ws.psi_tilde[I, 2] = g
            ws.psi_tilde[I, 3] = g
        end
        normalize_rotating!(ws)
        find_ground_state_rotating!(ws, 5000, 0.01)
    end

    μ_off = ground_mu(0.0)
    μ_on = ground_mu(-6.0)
    # Attractive singlet lowers μ; measured shift ≈ 0.076 (≫ convergence noise).
    @test μ_off - μ_on > 0.01
end
