@testset "BdG enhancements" begin
    @testset "detect_roton: stable system" begin
        spinor = ComplexF64[1.0, 0.0, 0.0]
        bdg = bogoliubov_spectrum(;
            spinor, n0=1.0, F=1,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            k_max=10.0, n_k=100,
        )
        rp = detect_roton(bdg)
        @test rp isa RotonParams
        @test !rp.has_roton || rp.roton_gap >= 0.0
    end

    @testset "detect_roton: DDI system" begin
        spinor = ComplexF64[1.0, 0.0, 0.0]
        bdg = bogoliubov_spectrum(;
            spinor, n0=1.0, F=1,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.0)),
            c_dd=20.0, k_max=15.0, n_k=200,
        )
        rp = detect_roton(bdg)
        @test rp isa RotonParams
    end

    @testset "planar directions" begin
        imap = bogoliubov_instability_scan(;
            spinor=ComplexF64[1.0, 0.0, 0.0],
            n0=1.0, F=1,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            c_dd=5.0,
            k_max=10.0, n_k=50,
            directions=:planar,
            n_directions=8,
        )
        @test imap isa InstabilityMap
        for dir in imap.directions
            @test abs(dir[3]) < 1e-14
        end
        @test length(imap.directions) == 8
    end

    @testset "predict_supersolid_params: stable" begin
        imap = bogoliubov_instability_scan(;
            spinor=ComplexF64[1.0, 0.0, 0.0],
            n0=1.0, F=1,
            interactions=InteractionParams(Dict(0 => 100.0, 1 => -0.5)),
            k_max=10.0, n_k=50,
        )
        sp = predict_supersolid_params(imap)
        @test sp isa SupersolidPrediction
        if !imap.unstable
            @test sp.pattern_type === :none
            @test sp.wavelength == Inf
        end
    end

    @testset "predict_supersolid_params: unstable DDI" begin
        imap = bogoliubov_instability_scan(;
            spinor=ComplexF64[1.0, 0.0, 0.0],
            n0=10.0, F=1,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            c_dd=50.0,
            k_max=15.0, n_k=100,
            directions=:auto,
        )
        sp = predict_supersolid_params(imap)
        @test sp isa SupersolidPrediction
        @test imap.unstable
        @test sp.pattern_type in [:stripe, :triangular, :isotropic]
    end

    @testset "instability_angular_map dimensions" begin
        result = instability_angular_map(;
            spinor=ComplexF64[1.0, 0.0, 0.0],
            n0=1.0, F=1,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.0)),
            c_dd=5.0,
            k_max=5.0, n_k=20,
            n_theta=4, n_phi=6,
        )
        @test length(result.theta) == 4
        @test length(result.phi) == 6
        @test size(result.growth_map) == (4, 6)
        @test all(x -> x >= 0, result.growth_map)
    end
end
