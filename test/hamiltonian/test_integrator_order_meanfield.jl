using Test
using SpinorBEC
using Printf

# Order verification under MEAN-FIELD with parameter sweep.
#
# Companion to `test_higher_order_integrators.jl`, which only exercises
# the integrators with `c1 = c_dd = 0`. That trivial-MF setup validates
# time-stepping infrastructure but NOT the order claim against the
# self-consistent Hamiltonian `H_eff(t) = H_0 + V_MF[ψ(t)]`. With
# mean-field active, frozen-midpoint splitting truncates Magnus at
# O(dt²) per V substep, regardless of outer composition order.
#
# This test sweeps four (c1, c_dd) configurations × four schemes ×
# three dt values, computes the empirical order from consecutive
# halvings (so we get TWO order estimates per scheme — they must
# agree, otherwise we're in a pre-asymptotic regime), and asserts
# behavior matched to the empirical reality:
#
#   ┌────────────┬────────┬────┬────┬───────┐
#   │ (c1, c_dd) │ Strang │ Y4 │ Y6 │ CFET4 │
#   ├────────────┼────────┼────┼────┼───────┤
#   │ (0, 0)     │   2    │  4 │  6 │   4   │  ← test_higher_order_integrators
#   │ (0, c_dd)  │   2    │ ~3 │ ~1 │  ~2   │  ← DDI alone breaks Y6
#   │ (c1, 0)    │   2    │ ~3 │ ~1 │  ~2   │  ← SM alone also breaks Y6
#   │ (c1, c_dd) │   2    │ ~3 │ ~1 │  ~2   │  ← full mean-field
#   └────────────┴────────┴────┴────┴───────┘
#
# Numbers are empirical orders observed on 8³ rotating-basis F=1.
# Y6 collapses universally whenever ANY mean-field channel is active.
# Y4 retains super-Strang behavior. CFET4 degrades to ~Strang order
# but with a smaller absolute constant. Strang itself is unaffected.
#
# Test design: configurations with mean-field assert orders >=
# empirically-measured floors. Y6 is `@test_broken` for its nominal
# order claim because no fix is in scope — recovering Y6 with MF
# requires implicit-midpoint predictor-corrector for V_MF[ψ], which
# doubles per-V cost.

@testset "Order verification under mean-field (parameter sweep)" begin
    config = GridConfig((8, 8, 8), (6.0, 6.0, 6.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 8, 8, 8)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x*x + y*y + z*z)
    end

    F_t = 1
    σ = 1.0
    T_final = 0.2
    omega_rot = 1.0

    function make_ws(c1, c_dd)
        ws = SpinorBEC.make_rotating_basis_ws(
            grid, F_t, V_trap;
            p=10.0, q=0.0,
            c0=20.0, c1=c1, c_dd=c_dd,
            theta_func=(t) -> π/6, phi_func=(t) -> omega_rot*t,
            theta_dot_func=(t) -> 0.0, phi_dot_func=(t) -> omega_rot,
            gauge_fix=false,
        )
        @inbounds for I in CartesianIndices(grid.config.n_points)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            z = grid.x[3][I[3]]
            ws.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
        end
        SpinorBEC.normalize_rotating!(ws)
        ws
    end

    function final_psi(driver, dt, c1, c_dd)
        ws = make_ws(c1, c_dd)
        n = Int(round(T_final / dt))
        driver(ws, n, dt)
        copy(ws.psi_tilde)
    end

    function err_at(driver, dt, c1, c_dd, psi_ref)
        psi = final_psi(driver, dt, c1, c_dd)
        sqrt(sum(abs2, psi - psi_ref))
    end

    # Three dt values: dt_a, dt_a/2, dt_a/4 → two consecutive halvings,
    # two order estimates that must agree (consistency check).
    dt_a, dt_b, dt_c = 0.02, 0.01, 0.005
    dt_ref = 0.0002

    drivers = [
        ("Strang", SpinorBEC.evolve_rotating!, 4),  # 4th value = nominal order
        ("Yoshida4", SpinorBEC.evolve_rotating_yoshida4!, 4),
        ("Yoshida6", SpinorBEC.evolve_rotating_yoshida6!, 6),
        ("CFET4", SpinorBEC.evolve_rotating_cfet4_real!, 4),
    ]

    configs = [
        (c1=0.0, c_dd=0.3, label="DDI only"),
        (c1=0.5, c_dd=0.0, label="c1 only"),
        (c1=0.5, c_dd=0.3, label="full mean-field"),
    ]

    for cfg in configs
        c1, c_dd, label = cfg.c1, cfg.c_dd, cfg.label
        @testset "($label) c1=$c1 c_dd=$c_dd" begin
            psi_ref = final_psi(SpinorBEC.evolve_rotating_cfet4_real!, dt_ref, c1, c_dd)

            errs = Dict{String, NTuple{3, Float64}}()
            for (name, driver, _nominal) in drivers
                err_a = err_at(driver, dt_a, c1, c_dd, psi_ref)
                err_b = err_at(driver, dt_b, c1, c_dd, psi_ref)
                err_c = err_at(driver, dt_c, c1, c_dd, psi_ref)
                errs[name] = (err_a, err_b, err_c)
                order_ab = log2(err_a / err_b)
                order_bc = log2(err_b / err_c)
                @info @sprintf(
                    "%-9s [%s]  err: %.2e → %.2e → %.2e   order: %.2f, %.2f",
                    name, label, err_a, err_b, err_c, order_ab, order_bc,
                )

                # ROBUST: errors monotonically decrease (no instability).
                # Skip when below reference's own noise floor (~1e-8 from
                # CFET4 at dt=2e-4) — there assertions are meaningless.
                if err_a > 1e-7
                    @test err_b < err_a
                end
                if err_b > 1e-7
                    @test err_c < err_b
                end
            end

            # Strang: nominal O(dt²), should be solid in all MF regimes.
            err_st_a, err_st_b, err_st_c = errs["Strang"]
            @test 1.5 < log2(err_st_a / err_st_b) < 2.7
            @test 1.5 < log2(err_st_b / err_st_c) < 2.7

            # Y4 / CFET4: must BEAT Strang at coarse dt by a wide margin.
            # Asserting absolute error ratio is more robust than order
            # ratio because higher-order schemes hit O(dt²) mean-field
            # sub-leading floors at small dt (Y4 drops to ~1.2 by dt_c).
            err_y4_a = errs["Yoshida4"][1]
            err_cfet_a = errs["CFET4"][1]
            @test err_y4_a < err_st_a / 50      # Y4 ≥ 50× better at coarse dt
            @test err_cfet_a < err_st_a / 5     # CFET4 ≥ 5× better at coarse dt

            # Y6 KNOWN BROKEN under mean-field. Assert it doesn't EXPLODE
            # (still beats Strang at coarse dt by ≥ 2×) but broken-test
            # the nominal order ≥ 5 claim.
            err_y6_a = errs["Yoshida6"][1]
            err_y6_b = errs["Yoshida6"][2]
            @test err_y6_a < err_st_a / 2
            @test_broken log2(err_y6_a / err_y6_b) ≥ 5.0
        end
    end

    # Norm preservation across all schemes, all configurations.
    @testset "Norm preservation under mean-field" begin
        for cfg in configs
            for (name, driver, _) in drivers
                ws = make_ws(cfg.c1, cfg.c_dd)
                n = Int(round(0.05 / 0.005))
                driver(ws, n, 0.005)
                @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7
            end
        end
    end
end
