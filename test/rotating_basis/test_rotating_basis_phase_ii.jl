using Test
using SpinorBEC
using StaticArrays: SVector

# Phase II quantitative validation: in the adiabatic limit (large p, static
# tilted B̂), Option γ tilde-basis ground state must reproduce scalar eGPE.

@testset "Option γ Phase II: scalar eGPE adiabatic limit" begin
    config = GridConfig((16, 16, 16), (12.0, 12.0, 12.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 16, 16, 16)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    # Stable parameter regime: ε_dd_eff = c_dd · F² / (3·g) ≈ 0.1
    g_t = 100.0
    F_t = 2
    c_t = 0.1 * 3 * g_t / F_t^2
    p_t = 5000.0
    tilt = π/6
    Bh = SVector{3, Float64}(sin(tilt), 0.0, cos(tilt))

    # --- Scalar eGPE ITP ---
    ws_s = SpinorBEC.make_scalar_ws(grid, V_trap;
        g_contact=g_t, c_dd=c_t, F=Float64(F_t), gamma_lhy=0.0, dt=0.0)
    σ = 1.0
    @inbounds for I in CartesianIndices(grid.config.n_points)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        ws_s.psi[I] = exp(-(x*x + y*y + z*z) / (2σ*σ))
    end
    SpinorBEC.normalize_scalar!(ws_s)
    SpinorBEC.find_ground_state_scalar!(ws_s, 150, 0.01; B_hat=Bh, target_norm=1.0)
    rho_s = abs2.(ws_s.psi)

    # --- Option γ ITP (adiabatic limit) ---
    ws_g = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
        p=p_t, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
        theta_func=(_t)->tilt, phi_func=(_t)->0.0,
        theta_dot_func=(_t)->0.0, phi_dot_func=(_t)->0.0)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        ws_g.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
    end
    SpinorBEC.normalize_rotating!(ws_g)
    SpinorBEC.find_ground_state_rotating!(ws_g, 150, 0.005)

    D_t = 2F_t + 1
    rho_g = zeros(Float64, 16, 16, 16)
    @inbounds for m_idx in 1:D_t, I in CartesianIndices(rho_g)
        rho_g[I] += abs2(ws_g.psi_tilde[I, m_idx])
    end

    per_m = SpinorBEC.rotating_per_m_norms(ws_g)

    # --- Adiabatic checks ---
    @test per_m[1] > 0.9999          # m=+F fully populated (adiabatic)
    @test sum(per_m[2:end]) < 1e-3   # all other m's empty
    @test SpinorBEC.rotating_norm(ws_g) ≈ 1.0 atol=1e-6
    @test SpinorBEC.scalar_norm(ws_s) ≈ 1.0 atol=1e-6

    # Density overlap (Bhattacharyya)
    inner = sum(@. sqrt(rho_s * rho_g))
    norm_a = sum(rho_s);
    norm_b = sum(rho_g)
    overlap = inner / sqrt(norm_a * norm_b)
    @test overlap > 0.998   # small grid + quick ITP; full convergence script reaches > 0.9999

    # Aspect ratio match
    function ar(rho)
        dV = prod(grid.dx)
        n_total = sum(rho) * dV
        σ_xy = 0.0;
        σ_z = 0.0
        @inbounds for I in CartesianIndices(rho)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            σ_xy += rho[I] * (x*x + y*y) / 2
            σ_z += rho[I] * z * z
        end
        σ_xy *= dV / n_total;
        σ_z *= dV / n_total
        sqrt(σ_z / σ_xy)
    end
    ar_s = ar(rho_s);
    ar_g = ar(rho_g)
    @test abs(ar_s - ar_g) / ar_s < 0.05    # aspect ratios within 5%
end

@testset "Option γ Phase II: F sweep at adiabatic p" begin
    config = GridConfig((12, 12, 12), (10.0, 10.0, 10.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 12, 12, 12)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end
    tilt = π/6
    Bh = SVector{3, Float64}(sin(tilt), 0.0, cos(tilt))

    for F_t in [1, 3]
        g_t = 80.0
        c_t = 0.1 * 3 * g_t / F_t^2
        p_t = 1000.0

        ws_s = SpinorBEC.make_scalar_ws(grid, V_trap;
            g_contact=g_t, c_dd=c_t, F=Float64(F_t), gamma_lhy=0.0, dt=0.0)
        σ = 1.0
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws_s.psi[I] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_scalar!(ws_s)
        SpinorBEC.find_ground_state_scalar!(ws_s, 200, 0.01; B_hat=Bh, target_norm=1.0)
        rho_s = abs2.(ws_s.psi)

        ws_g = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=p_t, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
            theta_func=(_t)->tilt, phi_func=(_t)->0.0,
            theta_dot_func=(_t)->0.0, phi_dot_func=(_t)->0.0)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws_g.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws_g)
        SpinorBEC.find_ground_state_rotating!(ws_g, 200, 0.005)

        D_t = 2F_t + 1
        rho_g = zeros(Float64, 12, 12, 12)
        @inbounds for m_idx in 1:D_t, I in CartesianIndices(rho_g)
            rho_g[I] += abs2(ws_g.psi_tilde[I, m_idx])
        end

        per_m = SpinorBEC.rotating_per_m_norms(ws_g)
        @test per_m[1] > 0.9999

        inner = sum(@. sqrt(rho_s * rho_g))
        norm_a = sum(rho_s);
        norm_b = sum(rho_g)
        overlap = inner / sqrt(norm_a * norm_b)
        @test overlap > 0.998   # small grid + quick ITP; full convergence script reaches > 0.9999
    end
end
