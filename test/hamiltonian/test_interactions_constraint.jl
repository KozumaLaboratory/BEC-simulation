@testset "even_c_extra canonical builder (hand-written misindex regression)" begin
    # CLAUDE.md flags `[c2, c4, c6]` hand-written arrays as silently
    # misindexing for F >= 3: c_extra is indexed by (rank - 1), so a
    # 3-element array `[c2, c4, c6]` sets c_extra[1]=c2 (rank=2, correct),
    # c_extra[2]=c4 (rank=3, ODD — should be 0!), c_extra[3]=c6 (rank=4,
    # NOT rank 6). For F >= 3 the canonical entry point is
    # `even_c_extra(F; c2, c4, ...)` which interleaves odd-rank zeros.

    out_F1 = even_c_extra(1; c2=10.0)
    @test out_F1 == [10.0]
    @test length(out_F1) == 1

    out_F2 = even_c_extra(2; c2=10.0, c4=20.0)
    @test out_F2 == [10.0, 0.0, 20.0]
    @test length(out_F2) == 3

    # F=3: 2F-1=5 slots. The misindex case.
    out_F3 = even_c_extra(3; c2=10.0, c4=20.0, c6=30.0)
    @test out_F3 == [10.0, 0.0, 20.0, 0.0, 30.0]
    @test length(out_F3) == 5
    # Hand-written [10, 20, 30] would silently misalign — verify this
    # diverges from the canonical layout:
    @test out_F3 != [10.0, 20.0, 30.0, 0.0, 0.0]

    # F=6 (Eu): 2F-1=11 slots. c2/c4/c6/c8/c10/c12 active.
    out_F6 = even_c_extra(6;
        c2=1.0, c4=2.0, c6=3.0, c8=4.0, c10=5.0, c12=6.0)
    @test length(out_F6) == 11
    @test out_F6 == [1.0, 0.0, 2.0, 0.0, 3.0, 0.0, 4.0, 0.0, 5.0, 0.0, 6.0]
    @test all(out_F6[2:2:end] .== 0.0)
    @test out_F6[1:2:end] == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

    # Refusing to set c_k > 2F (would be silently dropped otherwise).
    @test_throws ArgumentError even_c_extra(2; c2=1.0, c6=2.0)  # c6 > 2F=4
    @test_throws ArgumentError even_c_extra(3; c2=1.0, c8=2.0)  # c8 > 2F=6

    # Zero above 2F is OK (no-op).
    out_F2_zero = even_c_extra(2; c2=1.0, c6=0.0)
    @test out_F2_zero == [1.0, 0.0, 0.0]
end

@testset "Constraint-based interactions" begin
    @testset "interaction_params_from_constraint basic" begin
        ip = interaction_params_from_constraint(; c_total=4689.0, c1_ratio=0.0, F=6)
        @test ip.c0 ≈ 4689.0
        @test ip.c1 ≈ 0.0

        ip2 = interaction_params_from_constraint(; c_total=4689.0, c1_ratio=1.0/36, F=6)
        @test ip2.c0 + 36 * ip2.c1 ≈ 4689.0 rtol=1e-12
        @test ip2.c1 / ip2.c0 ≈ 1.0 / 36 rtol=1e-12

        ip3 = interaction_params_from_constraint(; c_total=4689.0, c1_ratio=-1.0/72, F=6)
        @test ip3.c0 + 36 * ip3.c1 ≈ 4689.0 rtol=1e-12
        @test ip3.c1 / ip3.c0 ≈ -1.0 / 72 rtol=1e-12
        @test ip3.c1 < 0
    end

    @testset "constraint preserves total for F=1" begin
        ip = interaction_params_from_constraint(; c_total=100.0, c1_ratio=-0.1, F=1)
        @test ip.c0 + 1^2 * ip.c1 ≈ 100.0 rtol=1e-12
    end

    @testset "compute_c_total" begin
        omega = 2π * 110.0
        c_total = compute_c_total(Eu151; N_atoms=50_000, omega_ref=omega)
        @test c_total > 4000
        @test c_total < 5000
    end

    @testset "compute_c_dd_dimless" begin
        omega = 2π * 110.0
        c_dd = compute_c_dd_dimless(Eu151; N_atoms=50_000, omega_ref=omega)
        # c_dd = μ₀(mu_mag/F)² × N/(ℏω a_ho³) ≈ 211 for Eu151
        @test c_dd > 180
        @test c_dd < 250
    end

    @testset "linear_zeeman_p" begin
        omega = 2π * 110.0
        p = linear_zeeman_p(Eu151, 2.6e-9, omega)
        @test p > 0.3
        @test p < 0.5
    end

    @testset "AtomSpecies g_F field" begin
        @test Eu151.g_F ≈ 1.9934 * 7.0 / 12.0
        @test Rb87.g_F == -0.5
        @test Na23.g_F == -0.5

        a = AtomSpecies("test", 1.0, 1, 0.1, 0.2)
        @test a.g_F == 0.0

        b = AtomSpecies("test", 1.0, 1, 0.1, 0.2, 0.5)
        @test b.g_F == 0.0

        c = AtomSpecies("test", 1.0, 2, 0.0, 0.0, 0.5, 1.5)
        @test c.g_F == 1.5
        @test c.mu_mag == 0.5
    end

    @testset "YAML c_total/c1_ratio parsing" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Eu151
              grid:
                n: [32]
                box: [10.0]
              interactions:
                c_total: 4689.0
                c1_ratio: 0.02778
              ddi:
                enabled: true
                c_dd: 211.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        config = load_config_from_string(yaml_str)
        p = config.steps[1].params
        @test p["interactions"]["c_total"] == 4689.0
        @test p["interactions"]["c1_ratio"] == 0.02778
        @test p["ddi"]["c_dd"] == 211.0
    end

    @testset "YAML c_total with c1_ratio=0" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Eu151
              grid:
                n: [32]
                box: [10.0]
              interactions:
                c_total: 4689.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        config = load_config_from_string(yaml_str)
        p = config.steps[1].params
        @test p["interactions"]["c_total"] == 4689.0
        @test get(p["interactions"], "c1_ratio", 0.0) == 0.0
    end

    @testset "compute_eu151_interactions" begin
        omega = 2π * 110.0
        ip = compute_eu151_interactions(; N_atoms=50_000, omega_ref=omega, c1_ratio=1.0/36)
        c_total = compute_c_total(Eu151; N_atoms=50_000, omega_ref=omega)
        @test ip.c0 + 36 * ip.c1 ≈ c_total rtol=1e-12
        @test ip.c1 / ip.c0 ≈ 1.0/36 rtol=1e-12

        ip0 = compute_eu151_interactions(; N_atoms=50_000, omega_ref=omega, c1_ratio=0.0)
        @test ip0.c0 ≈ c_total
        @test ip0.c1 ≈ 0.0
    end

    @testset "compute_interaction_params fallback for missing scattering lengths" begin
        ip = @test_logs (:warn, r"No channel scattering lengths") compute_interaction_params(
            Eu151; N_atoms=1, dims=3)
        @test ip.c0 > 0
        @test ip.c1 == 0.0
        @test ip.c0 ≈ compute_c0(Eu151; N_atoms=1, dims=3)
    end

    @testset "_c0c1_to_gS analytic F=1" begin
        c0, c1 = 100.0, -5.0
        g = SpinorBEC._c0c1_to_gS(1, c0, c1)
        @test g[0] ≈ c0 - 2c1   # g_0 = c_0 + c_1(0 - 2)/2 = c_0 - c_1
        @test g[2] ≈ c0 + c1    # g_2 = c_0 + c_1(6 - 4)/2 = c_0 + c_1
    end

    @testset "_c0c1_to_gS pair amplitude identity F=1,2,6" begin
        for F in [1, 2, 6]
            D = 2F + 1
            c0, c1 = 100.0, -3.0
            g = SpinorBEC._c0c1_to_gS(F, c0, c1)
            cg_table = precompute_cg_table(F)
            sm = spin_matrices(F)

            for trial in 1:5
                sp = randn(ComplexF64, D)
                n = sum(abs2, sp)

                Fvec = zeros(ComplexF64, 3)
                Fmats = [sm.Fx, sm.Fy, sm.Fz]
                for (a, Fa) in enumerate(Fmats)
                    for i in 1:D, j in 1:D
                        Fvec[a] += conj(sp[i]) * Fa[i, j] * sp[j]
                    end
                end
                Fsq = sum(abs2, Fvec) |> real

                E_pair = 0.0
                for S in 0:2:2F
                    gS = g[S]
                    for M in (-S):S
                        A = zero(ComplexF64)
                        for m1 in (-F):F
                            m2 = M - m1
                            abs(m2) > F && continue
                            cg_val = get(cg_table, (S, M, m1, m2), 0.0)
                            c1_idx = F - m1 + 1
                            c2_idx = F - m2 + 1
                            A += cg_val * sp[c1_idx] * sp[c2_idx]
                        end
                        E_pair += gS * abs2(A)
                    end
                end

                E_expected = c0 * n^2 + c1 * Fsq
                @test E_pair ≈ E_expected rtol = 1e-10
            end
        end
    end

    @testset "_c_extra_to_delta_gS" begin
        g = SpinorBEC._c_extra_to_delta_gS(2, [0.0, 0.0, 5.0])
        @test !isempty(g)

        g_empty = SpinorBEC._c_extra_to_delta_gS(2, Float64[])
        @test isempty(g_empty)

        # Odd-rank c_extra (c3 here, idx=2) now raises ArgumentError instead of
        # the previous silent @warn-and-drop. See refactor commit 0b0f48e.
        @test_throws ArgumentError SpinorBEC._c_extra_to_delta_gS(2, [0.0, 3.0])
    end

    @testset "interaction_params_from_constraint with c_extra" begin
        ip = interaction_params_from_constraint(; c_total=4689.0, c1_ratio=1.0/36, F=6,
            c_extra=[0.0, 0.0, 50.0])
        @test ip.c0 + 36 * ip.c1 ≈ 4689.0 rtol=1e-12
        @test length(ip.c_extra) == 3
        @test ip.c_extra[3] ≈ 50.0
    end

    @testset "YAML c_total with c_extra" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Eu151
              grid:
                n: [32]
                box: [10.0]
              interactions:
                c_total: 4689.0
                c1_ratio: 0.02778
                c4: 50.0
                c6: -20.0
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        config = load_config_from_string(yaml_str)
        p = config.steps[1].params
        @test p["interactions"]["c_total"] == 4689.0
        @test p["interactions"]["c4"] == 50.0
        @test p["interactions"]["c6"] == -20.0

        # Regression test: c_extra MUST reach InteractionParams via the
        # actual parsing pipeline. Pre-Apr 2026 _parse_gs_interactions
        # hardcoded c_extra=Float64[] and silently dropped these keys.
        ip = SpinorBEC._parse_gs_interactions(p["interactions"], Eu151)
        @test length(ip.c_extra) >= 5     # entries up to c6 (idx 5 = c6)
        @test ip.c_extra[3] == 50.0       # c4
        @test ip.c_extra[5] == -20.0      # c6
        @test ip.c_extra[1] == 0.0        # c2 unset → zero
    end

    @testset "YAML explicit c0/c1 still works" begin
        yaml_str = """
        pipeline:
          - ground_state:
              atom: Rb87
              grid:
                n: [32]
                box: [10.0]
              interactions:
                c0: 10.0
                c1: -0.5
              dt: 0.01
              n_steps: 10
              tol: 1e-4
              potential: {type: harmonic, omega: [1.0]}
        """
        config = load_config_from_string(yaml_str)
        p = config.steps[1].params
        @test p["interactions"]["c0"] == 10.0
        @test p["interactions"]["c1"] == -0.5
    end

    @testset "even_c_extra helper" begin
        # F=6: returned vector is length 2F-1 = 11; odd slots zero,
        # c_extra[k-1] = c_k for k = 2, 4, 6, 8, 10, 12.
        v = even_c_extra(6, c2=1.0, c4=2.0, c6=3.0, c8=4.0, c10=5.0, c12=6.0)
        @test length(v) == 11
        @test v[1] == 1.0    # c2
        @test v[2] == 0.0    # c3 (odd → 0)
        @test v[3] == 2.0    # c4
        @test v[5] == 3.0    # c6
        @test v[7] == 4.0    # c8
        @test v[9] == 5.0    # c10
        @test v[11] == 6.0   # c12

        # F=2: returned vector is length 3; only c2 slot used.
        v2 = even_c_extra(2, c2=0.5)
        @test length(v2) == 3
        @test v2[1] == 0.5
        @test v2[2] == 0.0
        @test v2[3] == 0.0

        # Default zeros — easy way to construct an empty extras vector.
        v_empty = even_c_extra(6)
        @test all(iszero, v_empty)

        # Reject c_k for k > 2F (would otherwise silently drop).
        @test_throws ArgumentError even_c_extra(2, c6=1.0)   # c6 > 2·2 = 4
        @test_throws ArgumentError even_c_extra(1, c4=1.0)   # c4 > 2·1 = 2
        # Boundary cases: c at exactly 2F is OK.
        @test even_c_extra(6, c12=1.0)[end] == 1.0
        @test even_c_extra(2, c4=1.0)[3] == 1.0
    end
end
