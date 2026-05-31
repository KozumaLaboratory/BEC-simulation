using Test
using Random
using SpinorBEC
using SpinorBEC:
    apply_sg_overlap, apply_fringe_noise!, synthesise_image_ensemble,
    _analyze_forward_image

@testset "Imaging forward chain (G2/G3/G4)" begin
    @testset "ImagingParams construction + validation" begin
        sg = TOFParams(t_tof=10.0, gradient=0.1, imaging_axis=2)
        sigma_eff = [0.1, 0.5, 1.0]  # F=1 toy
        ip = ImagingParams(view_geometry=:face_on, sg_tof=sg, sigma_eff=sigma_eff,
            sigma_sg_pixels=1.5, psf_sigma_pixels=0.8,
            photons_per_pixel=5000.0, read_noise_sigma=5.0, n_shots_avg=116)
        @test ip.view_geometry === :face_on
        @test ip.sg_tof === sg
        @test ip.sigma_eff == sigma_eff
        @test ip.n_shots_avg == 116

        @test_throws ArgumentError ImagingParams(view_geometry=:bogus,
            sg_tof=sg, sigma_eff=sigma_eff)
        @test_throws ArgumentError ImagingParams(view_geometry=:face_on,
            sg_tof=sg, sigma_eff=sigma_eff, n_shots_avg=0)
        @test_throws ArgumentError ImagingParams(view_geometry=:face_on,
            sg_tof=sg, sigma_eff=sigma_eff, sigma_sg_pixels=-1.0)
        @test_throws ArgumentError ImagingParams(view_geometry=:face_on,
            sg_tof=sg, sigma_eff=[-1.0, 0.5, 1.0])
    end

    @testset "apply_sg_overlap: σ=0 reduces to weighted sum" begin
        # Two synthetic m-components at (slightly) different image positions.
        nx, ny = 16, 16
        c_minus = zeros(nx, ny);
        c_minus[4, 8] = 1.0
        c_plus = zeros(nx, ny);
        c_plus[12, 8] = 1.0
        components = Dict(-1 => c_minus, +1 => c_plus)
        # Uniform σ_eff: composite total = 2.0
        comp_uniform = apply_sg_overlap(components, 0.0)
        @test sum(comp_uniform) ≈ 2.0
        # Weighted: σ_eff[+1] = 2, σ_eff[-1] = 0.5 → total = 0.5 + 2 = 2.5
        weights = Dict(-1 => 0.5, +1 => 2.0)
        comp_weighted = apply_sg_overlap(components, 0.0; sigma_eff=weights)
        @test sum(comp_weighted) ≈ 2.5
        @test comp_weighted[12, 8] ≈ 2.0
        @test comp_weighted[4, 8] ≈ 0.5
    end

    @testset "apply_sg_overlap: σ > 0 broadens but preserves integral" begin
        nx, ny = 32, 32
        c = zeros(nx, ny);
        c[16, 16] = 1.0
        components = Dict(0 => c)
        # Gaussian broadening preserves mass for delta-like input on a wide grid.
        broadened = apply_sg_overlap(components, 2.0)
        @test sum(broadened) ≈ 1.0 atol = 1e-6
        @test broadened[16, 16] < 1.0   # peak reduced
        @test broadened[16, 18] > 0      # spread sideways
    end

    @testset "apply_sg_overlap: dimension mismatch errors" begin
        wrong = Dict(0 => zeros(8, 8), 1 => zeros(16, 16))
        @test_throws DimensionMismatch apply_sg_overlap(wrong, 0.0)
        @test_throws ArgumentError apply_sg_overlap(Dict{Int, Matrix{Float64}}(), 0.0)
    end

    @testset "apply_fringe_noise!: shape + reproducibility" begin
        nx, ny, K = 16, 16, 3
        img = zeros(nx, ny)
        rng = Random.MersenneTwister(42)
        basis = randn(rng, nx, ny, K)
        # Orthonormalize (not strictly needed but standard)
        sigmas = [0.1, 0.05, 0.02]
        img1 = copy(img);
        apply_fringe_noise!(img1, basis, sigmas; seed=123)
        img2 = copy(img);
        apply_fringe_noise!(img2, basis, sigmas; seed=123)
        @test img1 == img2  # deterministic given seed
        img3 = copy(img);
        apply_fringe_noise!(img3, basis, sigmas; seed=999)
        @test img1 != img3  # different seed differs

        @test_throws DimensionMismatch apply_fringe_noise!(
            zeros(8, 8), basis, sigmas; seed=0)
        @test_throws DimensionMismatch apply_fringe_noise!(
            zeros(nx, ny), basis, [0.1, 0.05]; seed=0)  # K mismatch
    end

    @testset "synthesise_image_ensemble: mean & variance scaling" begin
        grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
        clean = ones(16, 16)
        # Pure read noise to isolate variance scaling
        out1 = synthesise_image_ensemble(clean, grid;
            read_noise_sigma=0.1, n_shots=1, seed=1)
        out_many = synthesise_image_ensemble(clean, grid;
            read_noise_sigma=0.1, n_shots=200, seed=1)
        @test all(iszero, out1.var)               # single shot ⇒ var=0
        @test maximum(out_many.var) > 0
        # Per-pixel sample variance should be near σ_read² = 0.01 for large N
        mean_var = sum(out_many.var) / length(out_many.var)
        @test 0.005 < mean_var < 0.02
        # Mean converges to clean (no Poisson, no PSF)
        @test sum(abs.(out_many.mean .- clean)) / length(clean) < 0.02
    end

    @testset "_analyze_forward_image: returns expected NamedTuple structure" begin
        # Minimal 3D toy: 8³ grid, m=+F init, imaging_axis=3 ⇒ 2D x-y image.
        # F=1 keeps the spinor compact (3 components) so test runs <1s.
        F = 1
        sys = SpinSystem(F)
        grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        psi = init_psi(grid, sys; state=:m_plus_F)
        atom = (F=F,)

        params = Dict{String, Any}(
            "view_geometry" => "face_on",
            "t_tof" => 1.0,
            "sg_gradient" => 0.1,
            "imaging_axis" => 3,
            "polarization" => "sigma_plus",
            "saturation" => 0.3,
            "detuning_over_gamma" => 0.0,
            "t_pulse_gamma" => 5.0,
            "sigma_sg_pixels" => 1.0,
            "psf_sigma_pixels" => 0.8,
            "photons_per_pixel" => 1000.0,
            "read_noise_sigma" => 3.0,
            "n_shots_avg" => 4,
            "seed" => 42,
        )

        result = _analyze_forward_image(psi, grid, atom, params, nothing)

        @test haskey(result, :od_image)
        @test haskey(result, :od_var)
        @test haskey(result, :populations)
        @test haskey(result, :total_od)
        @test haskey(result, :view_geometry)
        @test haskey(result, :sigma_eff_table)
        @test haskey(result, :log_likelihood_kernel)

        @test result.view_geometry === :face_on
        @test length(result.sigma_eff_table) == 2F + 1
        @test result.od_image isa Matrix{Float32}
        @test size(result.od_image) == (8, 8)
        @test result.total_od >= 0
        @test all(>=(0.0), values(result.populations))

        # log_likelihood_kernel: closure callable, returns Float
        ll_self = result.log_likelihood_kernel(Float64.(result.od_image))
        @test ll_self isa Float64
        @test ll_self <= 0   # log p ≤ 0 (un-normalized Gaussian; quadratic ≥ 0)
        # Wrong size raises
        wrong = zeros(Float64, 9, 9)
        @test_throws DimensionMismatch result.log_likelihood_kernel(wrong)
    end
end
