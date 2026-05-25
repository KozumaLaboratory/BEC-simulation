# c_n ↔ g_S basis mapping — regression after 2026-05-25 Dict refactor.
#
# InteractionParams now stores ALL c_n in a single Dict{Int,Float64}.
# The c_n → g_S mapping retains two physics conventions internally:
#
#   k=0   c_0 = constant g_S contribution         (KU density)
#   k=1   c_1 = (S(S+1)-2F(F+1))/2 contribution    (KU spin F̂·F̂)
#   k≥2   c_k = Wigner 6j rank-k tensor              (general T̂^(k)·T̂^(k))
#
# Routed via a single unified `c_to_g(F, ip)` entry point. The mixed
# convention is intentional (KU normalisation for k=0,1 vs 6j for k≥2)
# and documented in `c_to_g`'s docstring.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _c0c1_to_gS, _dict_to_delta_gS, _cn_to_gS, _gS_to_cn,
    _make_tensor_cache_from_channels, get_cn, bogoliubov_spectrum, c_to_g,
    has_higher_rank_couplings

@testset "c_n ↔ g_S basis mapping" begin
    @testset "1. c_0/c_1 → g_S formula: g_S = c_0 + c_1·(S(S+1)−2F(F+1))/2" begin
        for F in (1, 2, 3, 6, 8)
            c0 = 2.5
            c1 = 0.3
            g = _c0c1_to_gS(F, c0, c1)
            for S in 0:2:2F
                expected = c0 + c1 * (S * (S + 1) - 2 * F * (F + 1)) / 2
                @test isapprox(g[S], expected; rtol=1e-14)
            end
        end

        # F=1 special: 2-param ansatz IS the full basis.
        g = _c0c1_to_gS(1, 1.0, 0.5)
        @test isapprox(g[0], 0.0; atol=1e-14)
        @test isapprox(g[2], 1.5; rtol=1e-14)
    end

    @testset "2. Round-trip _gS_to_cn ∘ _cn_to_gS = identity (rank-k basis)" begin
        for F in (1, 2, 3, 6)
            even_vals = collect(0:2:2F)
            c_in = Dict{Int, Float64}(k => 0.5 * k + 0.1 for k in even_vals)
            g_mid = _cn_to_gS(F, c_in)
            c_out = _gS_to_cn(F, g_mid)
            for k in even_vals
                @test isapprox(c_in[k], c_out[k]; rtol=1e-10)
            end
            g_in = Dict{Int, Float64}(S => -0.3 * S + 1.0 for S in even_vals)
            c_mid = _gS_to_cn(F, g_in)
            g_out = _cn_to_gS(F, c_mid)
            for S in even_vals
                @test isapprox(g_in[S], g_out[S]; rtol=1e-10)
            end
        end
    end

    @testset "3. Dict construction: even-rank keys are written directly" begin
        # All c_n live in InteractionParams.c — write the Dict directly.
        ip = InteractionParams(
            Dict(0 => 0.0, 2 => 10.0, 4 => 20.0, 6 => 30.0,
                8 => 40.0, 10 => 50.0, 12 => 60.0),
        )
        @test ip[2] == 10.0
        @test ip[4] == 20.0
        @test ip[6] == 30.0
        @test ip[8] == 40.0
        @test ip[10] == 50.0
        @test ip[12] == 60.0
        # Unset slots default to 0.
        @test ip[3] == 0.0
        @test ip[5] == 0.0
    end

    @testset "4. _dict_to_delta_gS rejects c_k for k > 2F" begin
        # Silent-drop guard: passing a c_k that exceeds the spin allows
        # would silently disappear without this check.
        @test_throws ArgumentError _dict_to_delta_gS(2, Dict(6 => 2.0))
        @test_throws ArgumentError _dict_to_delta_gS(1, Dict(4 => 1.0))
        # Within range is fine.
        delta = _dict_to_delta_gS(2, Dict(2 => 1.0, 4 => 2.0))
        @test !isempty(delta)
    end

    @testset "5. InteractionParams rejects odd-rank n≥3 at construction" begin
        # The old Vector-based _dict_to_delta_gS used a runtime check.
        # The new Dict struct rejects at the constructor (earlier — better).
        @test_throws ArgumentError InteractionParams(Dict(3 => 1.0))
        @test_throws ArgumentError InteractionParams(Dict(0 => 1.0, 3 => 0.5))
        @test_throws ArgumentError InteractionParams(Dict(5 => 1.0))

        # Even ranks fine.
        ip = InteractionParams(Dict(0 => 1.0, 2 => 0.5, 4 => 0.3))
        @test ip[2] == 0.5
        @test ip[4] == 0.3
    end

    @testset "6. Workspace tensor routing: Path A vs Path B" begin
        grid = make_grid(GridConfig{1}((8,), (4.0,)))

        # Path B (c_4 = 0.5, k=4 ≥ 4): tensor_cache built from c_extra
        # only; c_0/c_1 stay in diagonal+spin_mixing steps (no double).
        ip_pathB = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
        ws_b = make_workspace(;
            grid, atom=Eu151, interactions=ip_pathB,
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
        )
        @test ws_b.tensor_cache !== nothing
        @test ws_b.interactions[0] == 2.0
        @test ws_b.interactions[1] == 0.1
        @test !has_higher_rank_couplings(ws_b.interactions)  # c_extra moved into cache

        # No tensor_cache when only c_0/c_1 set.
        ip_no_tensor = InteractionParams(Dict(0 => 2.0, 1 => 0.1))
        ws_n = make_workspace(;
            grid, atom=Eu151, interactions=ip_no_tensor,
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
        )
        @test ws_n.tensor_cache === nothing
    end

    @testset "7. c_2 routes to singlet_pair (KU convention) at F=2" begin
        F = 2
        D = 2F + 1
        grid = make_grid(GridConfig{1}((4,), (2.0,)))
        sys = SpinSystem(F)
        psi_polar = init_psi(grid, sys; state=:polar)
        psi_fm = init_psi(grid, sys; state=:m_plus_F)

        c_2 = 0.5
        ip = InteractionParams(Dict(2 => c_2))
        @test get_cn(ip, 2) == c_2

        # FM-up has A_{00} = 0: no change.
        ψ_fm_after = copy(psi_fm)
        SpinorBEC.apply_singlet_pair_step!(ψ_fm_after, ip, F, 0.01, 1;
            imaginary_time=false)
        @test maximum(abs, ψ_fm_after .- psi_fm) < 1e-14

        # Polar has A_{00} ≠ 0: phase accrued.
        ψ_polar_after = copy(psi_polar)
        SpinorBEC.apply_singlet_pair_step!(ψ_polar_after, ip, F, 0.01, 1;
            imaginary_time=false)
        @test maximum(abs, ψ_polar_after .- psi_polar) > 1e-10
        @test isapprox(sum(abs2, ψ_polar_after), sum(abs2, psi_polar);
            rtol=1e-12)
    end

    @testset "8. Bogoliubov picks up c_extra via c_to_g unified path" begin
        F = 2
        D = 2F + 1
        n0 = 1.0
        zeta = zeros(ComplexF64, D)
        zeta[(D + 1) ÷ 2] = 1.0

        ip_bare = InteractionParams(Dict(0 => 2.0, 1 => 0.3))
        bdg_bare = bogoliubov_spectrum(; spinor=zeta, n0=n0, F=F,
            interactions=ip_bare, k_max=2.0, n_k=20)

        ip_extra = InteractionParams(Dict(0 => 2.0, 1 => 0.3, 4 => 0.5))
        bdg_extra = bogoliubov_spectrum(; spinor=zeta, n0=n0, F=F,
            interactions=ip_extra, k_max=2.0, n_k=20)

        # Spectra must differ — c_4 shifts g_4 via 6j.
        @test maximum(abs.(bdg_bare.omega .- bdg_extra.omega)) > 1e-3
    end

    @testset "9. ip[n] symmetric indexing across all ranks" begin
        ip = InteractionParams(Dict(0 => 1.5, 1 => 2.5, 2 => 10.0,
            4 => 20.0, 6 => 30.0))
        @test ip[0] == 1.5  # c_0
        @test ip[1] == 2.5  # c_1
        @test ip[2] == 10.0  # c_2
        @test ip[3] == 0.0  # not set
        @test ip[4] == 20.0  # c_4
        @test ip[6] == 30.0  # c_6
        @test ip[8] == 0.0  # not set
    end

    @testset "10. Positional InteractionParams form throws" begin
        # The positional (c0::Real, c1::Real, ...) signature is not
        # supported — InteractionParams takes a Dict.
        @test_throws ArgumentError InteractionParams(2.0, 0.1)
        @test_throws ArgumentError InteractionParams(2.0, 0.1, 10.0)
    end

    @testset "11. c_to_g: single unified entry point" begin
        # Combines _c0c1_to_gS (KU closed-form for n=0,1) and
        # _dict_to_delta_gS (6j for n≥2) into one Dict→Dict call.
        F = 2
        c0_val = 2.0
        c1_val = 0.3
        c4_val = 0.4
        ip = InteractionParams(Dict(0 => c0_val, 1 => c1_val, 4 => c4_val))
        g_unified = c_to_g(F, ip)

        # Manual reconstruction.
        g_manual = _c0c1_to_gS(F, c0_val, c1_val)
        g_delta = _dict_to_delta_gS(F, Dict(4 => c4_val))
        for (S, dg) in g_delta
            g_manual[S] = get(g_manual, S, 0.0) + dg
        end

        @test sort(collect(keys(g_unified))) == sort(collect(keys(g_manual)))
        for S in keys(g_manual)
            @test isapprox(g_unified[S], g_manual[S]; rtol=1e-12)
        end
    end

    @testset "12. F=1: c_2 is an independent coupling" begin
        # At F=1 the channels are S=0, S=2. The c_n Dict can include
        # k=2 (rank-2 tensor) independently of c_0, c_1.
        ip = InteractionParams(Dict(2 => 0.5))
        @test ip[2] == 0.5
        # k > 2F is silent-drop guard.
        @test_throws ArgumentError _dict_to_delta_gS(1, Dict(4 => 0.1))
    end
end
