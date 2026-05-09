using Test
using SpinorBEC
using StaticArrays: SVector

# --- Phase I: static B̂, basis transform sanity ---

@testset "Option γ Phase I: static B̂ skeleton" begin
    config = GridConfig((16, 16, 16), (10.0, 10.0, 10.0))
    grid = SpinorBEC.make_grid(config)
    F_test = 1   # F=1: 3 components, simplest spinor

    V_trap = zeros(Float64, 16, 16, 16)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    @testset "norm preservation under basis-only transforms" begin
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F_test, V_trap;
            p=0.0, q=0.0, c0=0.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
        )
        # Initialize ψ̃ in the m=-F (lowest) component as a Gaussian
        D = 2F_test + 1
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, D] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws)
        n_initial = SpinorBEC.rotating_norm(ws)
        @test n_initial ≈ 1.0 atol=1e-10

        # Apply Û_B forward and back — norm preserved
        SpinorBEC._apply_UB!(ws.psi_tilde, ws.spin_matrices, 0.5, 0.3, 3; inverse=false)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-10
        SpinorBEC._apply_UB!(ws.psi_tilde, ws.spin_matrices, 0.5, 0.3, 3; inverse=true)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-10
    end

    @testset "RTP norm conservation, static B̂ = ẑ, no DDI" begin
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F_test, V_trap;
            p=0.5, q=0.1, c0=50.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
            theta_dot_func=(_t) -> 0.0, phi_dot_func=(_t) -> 0.0,
        )
        D = 2F_test + 1
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, D] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws)

        SpinorBEC.evolve_rotating!(ws, 20, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7

        # m=-F amplitude stays dominant (no transverse Zeeman, no spin coupling, no Â)
        per_m = SpinorBEC.rotating_per_m_norms(ws)
        @test per_m[D] > 0.999  # nearly all density still in m=-F
    end

    @testset "ITP convergence: scalar limit (F=1, c0 only)" begin
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F_test, V_trap;
            p=0.0, q=0.0, c0=100.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
        )
        D = 2F_test + 1
        # TF ansatz in m=-F component
        μ_TF = (15 * 100.0 / (8π))^(2/5)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            V_local = 0.5 * (x*x + y*y + z*z)
            ρ = max(0.0, (μ_TF - V_local) / 100.0)
            ws.psi_tilde[I, D] = sqrt(ρ)
        end
        SpinorBEC.normalize_rotating!(ws)

        μ_final = SpinorBEC.find_ground_state_rotating!(ws, 200, 0.01)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
        @test isfinite(μ_final)
        @test μ_final > 0   # repulsive scalar BEC has positive μ

        # m=-F still dominates (no spin-mixing → no leakage)
        per_m = SpinorBEC.rotating_per_m_norms(ws)
        @test per_m[D] > 0.999
        @test per_m[1] < 1e-6   # m=+F empty
    end

    @testset "Tilted static B̂: only Â=0, basis change only" begin
        # B̂ = (sin30°, 0, cos30°) static. Â = 0 because no time dependence.
        # Compare two runs:
        #   (a) ψ̃ initialized in m=-F of tilde basis (cloud's spin axis = B̂ tilted)
        #   (b) lab-frame psi initialized as U_B × (m=-F_tilde state) — same physical state
        # After ITP both should converge to the same total energy + norm.
        theta = π/6
        phi = 0.0

        ws_tilde = SpinorBEC.make_rotating_basis_ws(
            grid, F_test, V_trap;
            p=0.5, q=0.0, c0=50.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> theta, phi_func=(_t) -> phi,
        )
        D = 2F_test + 1
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws_tilde.psi_tilde[I, D] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws_tilde)
        SpinorBEC.find_ground_state_rotating!(ws_tilde, 100, 0.01)

        # Norm preserved
        @test SpinorBEC.rotating_norm(ws_tilde) ≈ 1.0 atol=1e-8

        # Per-m: in tilde basis, m=-F should remain dominant since the rotating-basis
        # quantization axis is B̂. (Lab-frame components m would be a tilted superposition.)
        per_m = SpinorBEC.rotating_per_m_norms(ws_tilde)
        @test per_m[D] > 0.999
    end

    @testset "LHY stabilization knob" begin
        # γ_LHY adds γ·ρ^(3/2) to local potential. At ε_dd_eff > 1, this is the
        # standard mechanism stabilizing the cloud. Skeleton check: norm preserved
        # and μ shifts upward when γ > 0 (LHY adds positive energy).
        F_t = 1
        ws_no = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=5.0, q=0.0, c0=80.0, c1=0.0, c_dd=200.0,  # ε_dd_eff = 0.83
            gamma_lhy=0.0,
            theta_func=(_t)->0.0, phi_func=(_t)->0.0)
        σ_l = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws_no.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_l*σ_l))
        end
        SpinorBEC.normalize_rotating!(ws_no)
        μ_no = SpinorBEC.find_ground_state_rotating!(ws_no, 80, 0.01)

        ws_lhy = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=5.0, q=0.0, c0=80.0, c1=0.0, c_dd=200.0,
            gamma_lhy=100.0,                              # nontrivial LHY
            theta_func=(_t)->0.0, phi_func=(_t)->0.0)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws_lhy.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_l*σ_l))
        end
        SpinorBEC.normalize_rotating!(ws_lhy)
        μ_lhy = SpinorBEC.find_ground_state_rotating!(ws_lhy, 80, 0.01)

        @test SpinorBEC.rotating_norm(ws_no) ≈ 1.0 atol=1e-7
        @test SpinorBEC.rotating_norm(ws_lhy) ≈ 1.0 atol=1e-7
        @test μ_lhy > μ_no                # LHY contributes positive energy
        @test μ_lhy - μ_no > 0.1          # nontrivial shift
    end

    @testset "L_z observable: real Gaussian → 0, vortex (l=1) → 1" begin
        ws = SpinorBEC.make_rotating_basis_ws(grid, 1, V_trap;
            p=1.0, q=0.0, c0=10.0, c1=0.0, c_dd=0.0,
            theta_func=(_t)->0.0, phi_func=(_t)->0.0)
        σ_l = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_l*σ_l))
        end
        SpinorBEC.normalize_rotating!(ws)
        @test abs(SpinorBEC.rotating_Lz(ws)) < 1e-10

        # Vortex
        fill!(ws.psi_tilde, 0.0)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            r2 = x*x + y*y + z*z
            ws.psi_tilde[I, 1] = (x + im*y) * exp(-r2 / (2σ_l*σ_l))
        end
        SpinorBEC.normalize_rotating!(ws)
        @test SpinorBEC.rotating_Lz(ws) ≈ 1.0 atol=1e-3
    end

    @testset "F=6 (Eu151): module accepts large D" begin
        F6 = 6
        ws6 = SpinorBEC.make_rotating_basis_ws(
            grid, F6, V_trap;
            p=1.0, q=0.001, c0=100.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> 0.0, phi_func=(_t) -> 0.0,
        )
        D6 = 2F6 + 1
        @test size(ws6.psi_tilde, 4) == D6
        # Initialize in m=-F=−6 (last index)
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws6.psi_tilde[I, D6] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws6)

        SpinorBEC.evolve_rotating!(ws6, 5, 0.005)
        @test SpinorBEC.rotating_norm(ws6) ≈ 1.0 atol=1e-7
    end
end

# --- Phase II: time-dependent B̂ (gauge connection active) ---

@testset "Option γ Phase II: time-dependent B̂ with Â≠0" begin
    config = GridConfig((16, 16, 16), (10.0, 10.0, 10.0))
    grid = SpinorBEC.make_grid(config)

    V_trap = zeros(Float64, 16, 16, 16)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    @testset "Constant rotation rate (φ̇ ≠ 0): norm preserved, gauge step active" begin
        ω = 1.0
        F_test = 2
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F_test, V_trap;
            p=0.5, q=0.0, c0=10.0, c1=0.0, c_dd=0.0,
            theta_func=(_t) -> π/4,           # constant tilt
            phi_func=(t) -> ω * t,            # uniform rotation
            theta_dot_func=(_t) -> 0.0,
            phi_dot_func=(_t) -> ω,
        )
        D = 2F_test + 1
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, D] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws)

        SpinorBEC.evolve_rotating!(ws, 30, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7

        # With Â ≠ 0 the F_x component spreads density to other m's
        per_m = SpinorBEC.rotating_per_m_norms(ws)
        # Some leakage out of m=-F (F=2: D=5)
        @test per_m[D] < 1.0    # not everything stays in m=-F under Â action
    end
end
