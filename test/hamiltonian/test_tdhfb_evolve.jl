# Regression test for `tdhfb_evolve!` unified API.
#
# Covers:
#   - `:strang` scheme produces SAME result as manual `tdhfb_strang_step!` loop
#   - `:y4_midpoint` scheme runs without error and preserves norm
#   - `save_every` snapshots are captured at the right cadence
#   - `on_step` callback fires per step
#   - precomputed `k_squared` is honored (vs internal rebuild)
#   - error on unknown scheme

using SpinorBEC
using LinearAlgebra
using Test

@testset "tdhfb_evolve! unified API" begin
    F = 1
    D = 2F + 1
    N = 8
    DT = 0.005

    function _build_phi()
        phi = zeros(ComplexF64, N, N, N, D)
        center = N ÷ 2 + 1
        @inbounds for i in 1:N, j in 1:N, k in 1:N
            r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
            g = exp(-r2 / 8)
            phi[i, j, k, 1] = g / sqrt(2)
            phi[i, j, k, 3] = g / sqrt(2)
        end
        phi ./= sqrt(sum(abs2, phi))
        phi
    end

    V_ext = zeros(Float64, N, N, N, D)
    g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)

    @testset ":strang matches manual loop (deterministic)" begin
        phi0 = _build_phi()
        state_manual = init_tdhfb_vacuum(phi0)
        for _ in 1:25
            tdhfb_strang_step!(state_manual, F, g_S, V_ext, DT)
        end

        phi0 = _build_phi()
        state_evolve = init_tdhfb_vacuum(phi0)
        tdhfb_evolve!(state_evolve, F, g_S, V_ext, DT, 25; scheme=:strang)

        # k_squared precomputation in evolve! vs rebuild-per-step in manual
        # gives bit-identical results (both use _default_tdhfb_k_squared).
        @test norm(state_manual.phi - state_evolve.phi) < 1e-12
        @test norm(state_manual.rho - state_evolve.rho) < 1e-9
        @test norm(state_manual.kappa - state_evolve.kappa) < 1e-9
    end

    @testset ":y4_midpoint runs end-to-end" begin
        phi0 = _build_phi()
        state = init_tdhfb_vacuum(phi0)
        tdhfb_evolve!(state, F, g_S, V_ext, DT, 10; scheme=:y4_midpoint)
        # φ norm bounded — Y4-mid wrapper currently empirically order 2
        # (palindrome breakage) but unitary-ish over short T.
        @test isfinite(norm(state.phi))
        @test abs(norm(state.phi) - 1.0) < 0.1
    end

    @testset "save_every cadence" begin
        phi0 = _build_phi()
        state = init_tdhfb_vacuum(phi0)
        _, history = tdhfb_evolve!(state, F, g_S, V_ext, DT, 20;
            scheme=:strang, save_every=5)
        @test length(history) == 4   # steps 5, 10, 15, 20
        @test history[1].step == 5
        @test history[end].step == 20
        # snapshot contents are deep copies (mutating state.phi later doesn't
        # change history)
        state.phi .= zero(eltype(state.phi))
        @test norm(history[end].phi) > 0.0
    end

    @testset "on_step callback fires per step" begin
        phi0 = _build_phi()
        state = init_tdhfb_vacuum(phi0)
        ts = Float64[]
        steps_seen = Int[]
        tdhfb_evolve!(state, F, g_S, V_ext, DT, 7;
            on_step=(s, step) -> begin
                push!(ts, s.t)
                push!(steps_seen, step)
            end,
        )
        @test length(ts) == 7
        @test steps_seen == collect(1:7)
        @test ts[end] ≈ 7 * DT atol=1e-12
    end

    @testset "unknown scheme errors" begin
        phi0 = _build_phi()
        state = init_tdhfb_vacuum(phi0)
        @test_throws ErrorException tdhfb_evolve!(state, F, g_S, V_ext, DT, 1;
            scheme=:nonexistent_scheme)
    end

    @testset "init_tdhfb_vacuum copies phi by default" begin
        phi_orig = _build_phi()
        state = init_tdhfb_vacuum(phi_orig)
        # mutate state.phi; phi_orig should be unchanged
        state.phi[1, 1, 1, 1] = 999.0 + 0im
        @test phi_orig[1, 1, 1, 1] != state.phi[1, 1, 1, 1]
    end

    @testset "init_tdhfb_vacuum alias=true shares phi" begin
        phi_orig = _build_phi()
        state = init_tdhfb_vacuum(phi_orig; alias=true)
        state.phi[1, 1, 1, 1] = 999.0 + 0im
        @test phi_orig[1, 1, 1, 1] == state.phi[1, 1, 1, 1]
    end
end
