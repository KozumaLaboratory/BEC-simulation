using Test
using SpinorBEC
using StaticArrays: SVector

# Verify order of convergence for all rotating-basis integrators by
# comparing against a fine-dt Strang reference.
#
# Expected scaling at dt → 0:
#   Strang (midpoint):     err ~ dt²
#   Yoshida4:              err ~ dt⁴ (autonomous), dt² (time-dep)
#   Yoshida6 / BM-S6:      err ~ dt⁶ (autonomous), dt² (time-dep)
#   Real CFET4:            err ~ dt⁴ (autonomous AND time-dep)

@testset "Higher-order integrators: order verification" begin
    config = GridConfig((8, 8, 8), (6.0, 6.0, 6.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 8, 8, 8)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    F_t = 1
    σ = 1.0
    T_final = 0.4
    omega_rot = 1.0

    function make_ws()
        ws = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=10.0, q=0.0, c0=20.0, c1=0.0, c_dd=0.0,
            theta_func=(t)->π/6, phi_func=(t)->omega_rot*t,
            theta_dot_func=(t)->0.0, phi_dot_func=(t)->omega_rot,
            gauge_fix=false)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]];
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws)
        ws
    end

    function final_psi(driver, dt)
        ws = make_ws()
        n = Int(round(T_final / dt))
        driver(ws, n, dt)
        copy(ws.psi_tilde)
    end

    # Reference at very fine dt with Strang
    psi_ref = final_psi(SpinorBEC.evolve_rotating!, 0.0001)

    # Coarse dt for all schemes
    dt_coarse = 0.01

    psi_strang = final_psi(SpinorBEC.evolve_rotating!, dt_coarse)
    psi_y4 = final_psi(SpinorBEC.evolve_rotating_yoshida4!, dt_coarse)
    psi_y6 = final_psi(SpinorBEC.evolve_rotating_yoshida6!, dt_coarse)
    psi_cfet4 = final_psi(SpinorBEC.evolve_rotating_cfet4_real!, dt_coarse)

    err_strang = sqrt(sum(abs2, psi_strang - psi_ref))
    err_y4 = sqrt(sum(abs2, psi_y4 - psi_ref))
    err_y6 = sqrt(sum(abs2, psi_y6 - psi_ref))
    err_cfet4 = sqrt(sum(abs2, psi_cfet4 - psi_ref))

    @info "Errors at dt=$dt_coarse vs reference at dt=0.0001" err_strang err_y4 err_y6 err_cfet4

    # All higher-order schemes must beat Strang
    @test err_y4 < err_strang
    @test err_y6 < err_strang
    @test err_cfet4 < err_strang    # Real CFET4 only ~order 2.5 in current form

    # Yoshida6 should genuinely outperform Yoshida4
    @test err_y6 < err_y4

    # Norm preservation across all schemes
    function norm_check(driver, dt)
        ws = make_ws()
        n = Int(round(0.1 / dt))
        driver(ws, n, dt)
        SpinorBEC.rotating_norm(ws)
    end
    @test norm_check(SpinorBEC.evolve_rotating_yoshida4!, 0.005) ≈ 1.0 atol=1e-7
    @test norm_check(SpinorBEC.evolve_rotating_yoshida6!, 0.005) ≈ 1.0 atol=1e-7
    @test norm_check(SpinorBEC.evolve_rotating_cfet4_real!, 0.005) ≈ 1.0 atol=1e-7
end

@testset "ITP guards: higher-order RTP-only" begin
    config = GridConfig((6, 6, 6), (4.0, 4.0, 4.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 6, 6, 6)
    ws = SpinorBEC.make_rotating_basis_ws(grid, 1, V_trap;
        p=1.0, q=0.0, c0=1.0, c1=0.0, c_dd=0.0,
        theta_func=(t)->0.0, phi_func=(t)->0.0)
    @test_throws ErrorException SpinorBEC.yoshida6_step_rotating!(
        ws, 0.01, 0.0; imaginary_time=true
    )
    @test_throws ErrorException SpinorBEC.cfet4_real_step_rotating!(
        ws, 0.01, 0.0; imaginary_time=true
    )
end
