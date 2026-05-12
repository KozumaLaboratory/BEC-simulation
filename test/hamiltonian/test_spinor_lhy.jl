@testset "Spinor-dependent LHY" begin
    @testset "two_channel: basic construction" begin
        table = compute_spinor_lhy_two_channel(;
            F=1, c0=10.0, c1=-0.5, n_max=10.0, n_points=50
        )
        @test table isa TwoChannelLHY
        @test length(table.densities) == 50
        @test length(table.potential_values) == 50
        @test table.densities[1] == 0.0
        @test table.densities[end] ≈ 10.0
    end

    @testset "two_channel: monotonically increasing potential" begin
        table = compute_spinor_lhy_two_channel(;
            F=1, c0=10.0, c1=-0.5, n_max=10.0, n_points=100
        )
        for i in 3:length(table.potential_values)
            @test table.potential_values[i] >= table.potential_values[i - 1] - 1e-10
        end
    end

    @testset "two_channel: c1=0 consistent with scalar" begin
        table = compute_spinor_lhy_two_channel(;
            F=1, c0=10.0, c1=0.0, n_max=10.0, n_points=100
        )
        prefactor = 8.0 / (15.0 * π^2)
        n_test = 5.0
        expected_energy = prefactor * abs(10.0)^(5/2) * n_test^(5/2)
        expected_V = 5/2 * prefactor * abs(10.0)^(5/2) * n_test^(3/2)
        V_table = SpinorBEC._lhy_V(n_test, table)
        @test abs(V_table - expected_V) / max(abs(expected_V), 1e-30) < 0.1
    end

    @testset "_lhy_V near-zero for n≈0" begin
        table = compute_spinor_lhy_two_channel(;
            F=1, c0=10.0, c1=-0.5, n_max=5.0, n_points=50
        )
        V0 = SpinorBEC._lhy_V(0.0, table)
        V_mid = SpinorBEC._lhy_V(2.5, table)
        @test abs(V0) < abs(V_mid) + 1e-6
    end

    @testset "interpolation smoothness" begin
        table = compute_spinor_lhy_two_channel(;
            F=1, c0=10.0, c1=-0.5, n_max=10.0, n_points=200
        )
        ns = range(0.1, 9.9; length=20)
        Vs = [SpinorBEC._lhy_V(n, table) for n in ns]
        for i in 2:length(Vs)
            jump = abs(Vs[i] - Vs[i - 1])
            scale = max(abs(Vs[i]), abs(Vs[i - 1]), 1e-10)
            @test jump / scale < 1.0
        end
    end

    @testset "full_bdg: basic construction" begin
        spinor = ComplexF64[1.0, 0.0, 0.0]
        table = compute_spinor_lhy_table(;
            spinor, F=1,
            interactions=InteractionParams(10.0, -0.5),
            n_max=5.0, n_points=20, k_max=10.0, n_k=50,
        )
        @test table isa FullBdGLHY
        @test length(table.densities) == 20
    end

    @testset "_numerical_derivative" begin
        x = collect(0.0:0.1:1.0)
        y = x .^ 2
        dy = SpinorBEC._numerical_derivative(x, y)
        for i in 2:(length(x) - 1)
            @test abs(dy[i] - 2*x[i]) < 0.05
        end
    end

    @testset "_interpolate_1d" begin
        xs = [0.0, 1.0, 2.0, 3.0]
        ys = [0.0, 1.0, 4.0, 9.0]
        @test SpinorBEC._interpolate_1d(xs, ys, 0.5) ≈ 0.5
        @test SpinorBEC._interpolate_1d(xs, ys, 1.5) ≈ 2.5
        @test SpinorBEC._interpolate_1d(xs, ys, -1.0) ≈ 0.0
        @test SpinorBEC._interpolate_1d(xs, ys, 5.0) ≈ 9.0
    end

    @testset "two_channel is polar-state LHY at F=1 (Lavoine-Bourdel form)" begin
        # ε_LHY^polar(F=1) = (8/15π²) [c0^(5/2) + 2|c1|^(5/2)] n^(5/2)
        # Verify against the direct formula. No DDI (Q5=1).
        c0 = 10.0; c1 = -0.5
        tbl = compute_spinor_lhy_two_channel(;
            F=1, c0=c0, c1=c1, c_dd=0.0, n_max=2.0, n_points=400)
        prefactor = 8.0 / (15.0 * π^2)
        n_test = 1.0
        # Energy density via integration of V_LHY = dε/dn from 0 to n_test
        # Quick spot check: V_LHY(n) = (5/2) prefactor (c0^(5/2) + 2|c1|^(5/2)) n^(3/2)
        V_expected = (5.0 / 2.0) * prefactor *
            (abs(c0)^(5/2) + 2.0 * abs(c1)^(5/2)) * n_test^(3/2)
        V_table = SpinorBEC._lhy_V(n_test, tbl)
        @test isapprox(V_table, V_expected; rtol=1e-3)
    end

    @testset "two_channel is F-generic (formula explicit in F)" begin
        # The two-channel LHY uses `2F · |c1|^(5/2)` for the spin part —
        # F appears as a parameter, so the formula evaluates for any F.
        # Physical interpretation: exact at F=1; valid approximation for
        # F ≥ 2 when c_extra = 0 (S ≥ 4 channels absent from mean field).
        for F in (1, 2, 3, 6)
            tbl = compute_spinor_lhy_two_channel(;
                F=F, c0=10.0, c1=-0.5, n_max=1.0, n_points=10)
            @test tbl isa TwoChannelLHY
            @test all(isfinite, tbl.potential_values)
        end
        # Spin part scales linearly with F at large c1 (density term fixed).
        # Subtract the F=1 spin contribution × (F-1) and compare to F=N result.
        n_test = 0.5
        v1 = SpinorBEC._lhy_V(n_test,
            compute_spinor_lhy_two_channel(; F=1, c0=0.0, c1=-1.0,
                n_max=1.0, n_points=200))
        v6 = SpinorBEC._lhy_V(n_test,
            compute_spinor_lhy_two_channel(; F=6, c0=0.0, c1=-1.0,
                n_max=1.0, n_points=200))
        @test isapprox(v6 / v1, 6.0; rtol=1e-2)
        # F < 1 still rejected.
        @test_throws ArgumentError compute_spinor_lhy_two_channel(;
            F=0, c0=10.0, c1=-0.5, n_max=1.0, n_points=10)
    end

    @testset "validation guard: F=6 polar + FullBdG emits regime warning" begin
        # F=6 polar (ζ_α = δ_{α, 0}) is the documented broken regime.
        D = 13
        spinor_polar = ComplexF64[c == 7 ? 1.0 : 0.0 for c in 1:D]
        @test_logs (:warn, r"spurious energy offset") match_mode = :any begin
            compute_spinor_lhy_table(;
                spinor=spinor_polar, F=6,
                interactions=InteractionParams(10.0, 0.1),
                n_max=1.0, n_points=4, k_max=5.0, n_k=10,
            )
        end
        # Non-polar F=6 should NOT warn (table still constructed normally).
        spinor_fm = ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
        @test compute_spinor_lhy_table(;
            spinor=spinor_fm, F=6,
            interactions=InteractionParams(10.0, 0.1),
            n_max=1.0, n_points=4, k_max=5.0, n_k=10,
        ) isa FullBdGLHY
    end
end
