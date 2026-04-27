using Test
using SpinorBEC
using StaticArrays: SVector

# Phase III: Option γ vs lab-frame at the same trap-scale dt.
# Both solvers eigen-exact in their spin step → must agree to dt² Strang error.
# Caveat: gauge_fix=false required for ψ_lab(T) = Û_B(T) ψ̃(T) to hold without
# residual χ-phase (gauge fix changes basis by χ-rotation around F_z).

@testset "Option γ Phase III: agreement with lab-frame" begin
    config = GridConfig((10, 10, 10), (8.0, 8.0, 8.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 10, 10, 10)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    F_t = 2; D_t = 2F_t + 1
    g_t = 60.0
    c_t = 0.05 * 3 * g_t / F_t^2
    tilt = π/6
    omega_rot = 2.0
    σ = 1.0

    theta_f(t) = tilt
    phi_f(t) = omega_rot * t
    theta_dot_f(t) = 0.0
    phi_dot_f(t) = omega_rot

    function build_workspaces(p_t)
        ws_g = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=p_t, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
            theta_func=theta_f, phi_func=phi_f,
            theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f,
            gauge_fix=false)

        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
            ws_g.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws_g)

        ws_l = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=p_t, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
            theta_func=theta_f, phi_func=phi_f,
            theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f,
            gauge_fix=false)
        copyto!(ws_l.psi_tilde, ws_g.psi_tilde)
        SpinorBEC._apply_UB!(ws_l.psi_tilde, ws_l.spin_matrices, tilt, 0.0, 3; inverse=false)
        ws_g, ws_l
    end

    function compare(p_t, dt, n_steps)
        ws_g, ws_l = build_workspaces(p_t)
        SpinorBEC.evolve_rotating!(ws_g, n_steps, dt)
        SpinorBEC.evolve_lab!(ws_l, n_steps, dt)

        # Convert γ → lab via Û_B(T_final)
        T_final = n_steps * dt
        psi_g_lab = copy(ws_g.psi_tilde)
        SpinorBEC._apply_UB!(psi_g_lab, ws_g.spin_matrices, theta_f(T_final), phi_f(T_final), 3; inverse=false)

        coh = abs(sum(@. conj(ws_l.psi_tilde) * psi_g_lab) * prod(grid.dx))
        rho_g = zeros(Float64, 10, 10, 10); rho_l = zeros(Float64, 10, 10, 10)
        @inbounds for m_idx in 1:D_t, I in CartesianIndices(rho_g)
            rho_g[I] += abs2(psi_g_lab[I, m_idx])
            rho_l[I] += abs2(ws_l.psi_tilde[I, m_idx])
        end
        ov = sum(@. sqrt(rho_g * rho_l)) / sqrt(sum(rho_g) * sum(rho_l))
        (coh, ov)
    end

    @testset "moderate p=20, dt=0.01, T=1" begin
        coh, ov = compare(20.0, 0.01, 100)
        @test coh > 0.999
        @test ov > 0.9999
    end

    @testset "Klaus regime p=10000, dt=0.005, T=0.5" begin
        coh, ov = compare(10000.0, 0.005, 100)
        @test coh > 0.999
        @test ov > 0.9999
    end

    @testset "dt convergence (p=50, dt halves)" begin
        coh1, _ = compare(50.0, 0.02, 50)
        coh2, _ = compare(50.0, 0.01, 100)
        coh3, _ = compare(50.0, 0.005, 200)
        # Coherent overlap monotonically improves toward 1 as dt → 0
        @test coh3 ≥ coh2 - 1e-6
        @test coh2 ≥ coh1 - 1e-6
        @test coh3 > 0.9999   # converges to ≥ 0.9999 at dt=0.005
    end
end
