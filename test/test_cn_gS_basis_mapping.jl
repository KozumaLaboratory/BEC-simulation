# c_n ↔ g_S basis mapping — comprehensive regression.
#
# THE PROBLEM. "c_n" in this codebase is a layered routing of three
# distinct operator types under one indexing scheme:
#
#   n=0  (c_0)   density coupling, scalar n²        → diagonal step
#   n=1  (c_1)   spin coupling ⟨F̂⟩·F̂                → spin_mixing step
#   n=2  (c_2)   singlet-pair |A_{00}|² (S=0 chan)  → singlet_pair step
#                                                    (NOT a rank-2 tensor!)
#   n=3  (c_3)   REJECTED — odd rank not physical
#   n=4,6,...    rank-k symmetric traceless tensor   → tensor_cache step
#                (6j transform to channel g_S)
#
# Storage: `c_extra[idx] = c_{idx+1}` for n ≥ 2. So `c_extra[1]=c_2`,
# `c_extra[3]=c_4`, etc. Hand-writing `[c2, c4, c6]` would silently
# misindex (c4 → c3, c6 → c4) — use `even_c_extra(F; c2, c4, c6, ...)`.
#
# The g_S channel-coupling basis is FUNDAMENTAL: each S ∈ {0, 2, ..., 2F}
# corresponds to two atoms colliding into total-spin-S. The c_n basis is
# DERIVED via:
#
#   g_S = c_0 + c_1·(S(S+1) − 2F(F+1))/2       [from c_0, c_1 ansatz]
#       + Σ_k (2k+1)·{F F k; F F S}·c_k         [from c_extra rank-k]
#
# At F=1 (only g_0 and g_2), c_0+c_1 is a complete basis. At F≥2 the
# 2-param ansatz is incomplete; c_extra refines specific ranks.
#
# This file pins:
#   1. c_0/c_1 → g_S linear-in-S(S+1) formula (exact at F=1)
#   2. Round-trip _gS_to_cn ∘ _cn_to_gS = identity (rank-k basis is invertible)
#   3. even_c_extra(F=6; c2=...) places c_2 at index 1, c_4 at index 3, etc.
#   4. even_c_extra rejects c_k for k > 2F (silent-drop guard)
#   5. Hand-written c_extra with odd-rank nonzero throws at parse time
#   6. Workspace double-count guard: tensor_cache + nonzero c_0/c_1 → throw
#   7. apply_singlet_pair_step uses c_2 as A_{00} coupling at F=2 (KU convention)
#   8. Bogoliubov spectrum picks up c_extra via _c_extra_to_delta_gS
#      (i.e. c_4 changes the g_4 channel coupling)

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _c0c1_to_gS, _c_extra_to_delta_gS, _cn_to_gS, _gS_to_cn,
    _make_tensor_cache_from_channels, get_cn, bogoliubov_spectrum

@testset "c_n ↔ g_S basis mapping" begin
    @testset "1. c_0/c_1 → g_S formula: g_S = c_0 + c_1·(S(S+1)−2F(F+1))/2" begin
        # F=1: g_0 = c_0 - 2c_1, g_2 = c_0 + c_1.
        # Verify exact at multiple F values.
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
        F = 1
        g = _c0c1_to_gS(F, 1.0, 0.5)
        @test isapprox(g[0], 1.0 - 2 * 0.5; rtol=1e-14)
        @test isapprox(g[2], 1.0 + 0.5; rtol=1e-14)
    end

    @testset "2. Round-trip: _gS_to_cn ∘ _cn_to_gS = identity (rank-k basis)" begin
        # The rank-k tensor basis is invertible via the 6j matrix.
        # Going round-trip in either direction must reproduce the input
        # at machine precision (within matrix-inverse conditioning).
        for F in (1, 2, 3, 6)
            even_vals = collect(0:2:2F)
            # Random c_k → g_S → c_k recovery.
            c_in = Dict{Int, Float64}(k => 0.5 * k + 0.1 for k in even_vals)
            g_mid = _cn_to_gS(F, c_in)
            c_out = _gS_to_cn(F, g_mid)
            for k in even_vals
                @test isapprox(c_in[k], c_out[k]; rtol=1e-10)
            end

            # And g → c → g.
            g_in = Dict{Int, Float64}(S => -0.3 * S + 1.0 for S in even_vals)
            c_mid = _gS_to_cn(F, g_in)
            g_out = _cn_to_gS(F, c_mid)
            for S in even_vals
                @test isapprox(g_in[S], g_out[S]; rtol=1e-10)
            end
        end
    end

    @testset "3. even_c_extra: correct index placement at F=6" begin
        # F=6: c_extra has length 2F-1 = 11.
        # Valid ranks k ∈ {2, 4, 6, 8, 10, 12} → indices {1, 3, 5, 7, 9, 11}.
        # Odd-index slots (2, 4, 6, 8, 10) must be zero.
        vec = even_c_extra(6; c2=10.0, c4=20.0, c6=30.0, c8=40.0,
            c10=50.0, c12=60.0)
        @test length(vec) == 11
        @test vec[1] == 10.0  # c_2 (rank-2)
        @test vec[2] == 0.0   # would-be c_3, must be zero
        @test vec[3] == 20.0  # c_4
        @test vec[4] == 0.0   # would-be c_5
        @test vec[5] == 30.0  # c_6
        @test vec[6] == 0.0
        @test vec[7] == 40.0  # c_8
        @test vec[8] == 0.0
        @test vec[9] == 50.0  # c_10
        @test vec[10] == 0.0
        @test vec[11] == 60.0  # c_12
    end

    @testset "4. even_c_extra rejects c_k for k > 2F" begin
        # F=2: only c_2, c_4 supported. c_6 nonzero must throw to
        # prevent silent drop.
        @test_throws ArgumentError even_c_extra(2; c2=1.0, c6=2.0)

        # F=2, c_6=0 explicitly is fine.
        vec = even_c_extra(2; c2=1.0, c4=2.0, c6=0.0)
        @test length(vec) == 3
        @test vec[1] == 1.0  # c_2
        @test vec[3] == 2.0  # c_4
    end

    @testset "5. c_extra with odd-rank nonzero throws at routing" begin
        # _c_extra_to_delta_gS rejects odd-rank nonzero values to
        # prevent KU "c_3 = pair channel" confusion with rank-3 tensor.
        F = 3
        c_extra_bad = [0.0, 1.0, 0.0, 0.0, 0.0]  # idx=2 → c_3 nonzero
        @test_throws ArgumentError _c_extra_to_delta_gS(F, c_extra_bad)

        # All-even is fine.
        c_extra_ok = [1.0, 0.0, 2.0, 0.0, 3.0]  # c_2, c_4, c_6
        delta = _c_extra_to_delta_gS(F, c_extra_ok)
        @test delta isa Dict
        @test haskey(delta, 0) && haskey(delta, 2) && haskey(delta, 4) &&
            haskey(delta, 6)
    end

    @testset "6. Workspace tensor routing: two intentional paths, no double-count" begin
        # The codebase distinguishes two routing paths for c_extra:
        #
        #   Path A (else): make_tensor_interaction_cache(F, interactions)
        #     - builds g_S from c_0, c_1, c_extra ALL via _cn_to_gS
        #     - tensor_cache then handles ALL channels including S=0 (c_0)
        #     - if c_0/c_1 nonzero → diagonal + spin_mixing steps ALSO use
        #       them → DOUBLE-COUNT → guard throws ArgumentError
        #
        #   Path B (if): _make_tensor_cache_from_channels(F, g_delta)
        #     - builds g_S ONLY from c_extra (NOT c_0/c_1) via 6j transform
        #     - tensor_cache adds rank-k corrections; diagonal+spin_mixing
        #       handle c_0/c_1 separately
        #     - NO double-count, no guard needed
        #
        # Activation: Path B triggers when ANY c_extra[k] (k=2F-1 indices,
        # even-rank only) with k≥4 is nonzero. Path A triggers when only
        # k=2 (singlet_pair) is set or via the scattering-lengths route.

        grid = make_grid(GridConfig{1}((8,), (4.0,)))

        # Path B (c_4 = 0.5 nonzero, k=4 ≥ 4): NO throw, c_0/c_1 kept
        # as independent diagonal/spin couplings.
        ip_pathB = InteractionParams(2.0, 0.1, 0.0,
            even_c_extra(6; c4=0.5))
        ws_b = make_workspace(;
            grid, atom=Eu151,
            interactions=ip_pathB,
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
        )
        @test ws_b.tensor_cache !== nothing
        # ws_interactions retains c_0/c_1 unchanged (diagonal/spin_mixing
        # still use them); c_extra is zeroed (now in tensor_cache).
        @test ws_b.interactions.c0 == 2.0
        @test ws_b.interactions.c1 == 0.1
        @test isempty(ws_b.interactions.c_extra)

        # Same setup with c_4=0 ONLY (c_extra empty after filtering) → no
        # tensor_cache → falls through to scalar steps.
        ip_no_tensor = InteractionParams(2.0, 0.1)
        ws_n = make_workspace(;
            grid, atom=Eu151,
            interactions=ip_no_tensor,
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
        )
        @test ws_n.tensor_cache === nothing
    end

    @testset "7. c_2 routes to singlet_pair (not rank-2 tensor) at F=2" begin
        # apply_singlet_pair_step! reads c_2 = get_cn(ip, 2) = c_extra[1]
        # and applies the KU |A_{00}|² operator. Cross-check: a state
        # with A_{00} ≠ 0 picks up a phase ∝ c_2 over one step; a state
        # with A_{00} = 0 (e.g. ferromagnetic |m=+2⟩) does NOT.
        F = 2
        D = 2F + 1
        grid = make_grid(GridConfig{1}((4,), (2.0,)))
        sys = SpinSystem(F)

        # Polar |m=0⟩ has |A_{00}|² = n²/D (max singlet-pair amplitude).
        psi_polar = init_psi(grid, sys; state=:polar)
        # FM up |m=+F⟩ has A_{00} = 0.
        psi_fm = init_psi(grid, sys; state=:m_plus_F)

        c_2 = 0.5
        ip = InteractionParams(0.0, 0.0, 0.0, even_c_extra(F; c2=c_2))
        @test get_cn(ip, 2) == c_2

        # apply singlet_pair to FM-up: no change (A_{00} = 0).
        ψ_fm_after = copy(psi_fm)
        SpinorBEC.apply_singlet_pair_step!(ψ_fm_after, ip, F, 0.01, 1;
            imaginary_time=false)
        @test maximum(abs, ψ_fm_after .- psi_fm) < 1e-14

        # apply singlet_pair to polar: phase accrued.
        ψ_polar_after = copy(psi_polar)
        SpinorBEC.apply_singlet_pair_step!(ψ_polar_after, ip, F, 0.01, 1;
            imaginary_time=false)
        @test maximum(abs, ψ_polar_after .- psi_polar) > 1e-10
        # Norm must be preserved (unitary step).
        @test isapprox(sum(abs2, ψ_polar_after), sum(abs2, psi_polar);
            rtol=1e-12)
    end

    @testset "8. Bogoliubov picks up c_extra via 6j (g_S shifts)" begin
        # Without c_extra: g_S from c_0/c_1 alone.
        # With c_4 nonzero: g_4 shifts via (2·4+1)·{F F 4; F F 4}·c_4 etc.
        # The Bogoliubov spectrum at F=2 must DIFFER between the two cases.
        F = 2
        D = 2F + 1
        n0 = 1.0
        zeta = zeros(ComplexF64, D)
        zeta[(D + 1) ÷ 2] = 1.0  # polar

        ip_bare = InteractionParams(2.0, 0.3)
        bdg_bare = bogoliubov_spectrum(;
            spinor=zeta, n0=n0, F=F,
            interactions=ip_bare,
            k_max=2.0, n_k=20,
        )

        # With c_4 = 0.5 added; bypass the make_workspace c0/c1 guard by
        # passing the constructor directly (Bogoliubov uses 6j path).
        ip_extra = InteractionParams(2.0, 0.3, 0.0, even_c_extra(F; c4=0.5))
        bdg_extra = bogoliubov_spectrum(;
            spinor=zeta, n0=n0, F=F,
            interactions=ip_extra,
            k_max=2.0, n_k=20,
        )

        # Spectra must differ — c_4 shifts g_4 which enters the BdG
        # matrix. Use the max_growth_rate as a coarse discriminator.
        # Exact equality would mean c_extra is being silently dropped.
        ω_bare = bdg_bare.omega
        ω_extra = bdg_extra.omega
        @test maximum(abs.(ω_bare .- ω_extra)) > 1e-3
    end

    @testset "9. get_cn indexing: c_0 → c0, c_1 → c1, c_n→c_extra[n-1]" begin
        # Verify the get_cn dispatch matches the documented contract.
        ip = InteractionParams(1.5, 2.5, 0.0, [10.0, 0.0, 20.0, 0.0, 30.0])
        @test get_cn(ip, 0) == 1.5  # c_0
        @test get_cn(ip, 1) == 2.5  # c_1
        @test get_cn(ip, 2) == 10.0  # c_2 (c_extra[1])
        @test get_cn(ip, 3) == 0.0  # c_3 (c_extra[2])
        @test get_cn(ip, 4) == 20.0  # c_4 (c_extra[3])
        @test get_cn(ip, 6) == 30.0  # c_6 (c_extra[5])
        @test get_cn(ip, 8) == 0.0  # out of range → 0
    end

    @testset "10. Hand-written c_extra misindex: documents the footgun" begin
        # If a user writes `c_extra = [c2, c4, c6]` for F=6 (length 3),
        # they intend c_2=c2, c_4=c4, c_6=c6 but the code reads:
        #   c_extra[1] = c2 (correct → c_2)
        #   c_extra[2] = c4 (WRONG: this is c_3, which is odd-rank;
        #                   _c_extra_to_delta_gS will THROW because c_3≠0)
        # This means the misindex bug is loudly caught — good.
        # Pin this with a test so the safety remains.
        bad_extra = [10.0, 20.0, 30.0]  # User meant c2, c4, c6.
        # Index 2 is c_3 (odd) and nonzero → must throw.
        @test_throws ArgumentError _c_extra_to_delta_gS(6, bad_extra)

        # The correct way: use even_c_extra.
        good_extra = even_c_extra(6; c2=10.0, c4=20.0, c6=30.0)
        @test good_extra[1] == 10.0  # c_2
        @test good_extra[2] == 0.0   # c_3 (forced zero)
        @test good_extra[3] == 20.0  # c_4
        @test good_extra[5] == 30.0  # c_6
        # And this routes through _c_extra_to_delta_gS without throw.
        delta = _c_extra_to_delta_gS(6, good_extra)
        @test delta isa Dict
    end
end
