using Test
using SpinorBEC

@testset "rotating_basis analyzers — 修論 Fig 2-7" begin
    # Build a minimal synthetic dynamics result without running the simulation
    F_val = 6
    D = 2F_val + 1
    Nx, Ny, Nz = 8, 8, 4
    n_frames = 5

    # Synthetic ψ̃: m=+F (idx 1) Gaussian, slowly leaking to m=+F-1
    snaps = Vector{Array{ComplexF64, 4}}()
    times = collect(0.0:0.1:0.4)
    per_m_hist = Vector{Vector{Float64}}()
    Lz_arr = Float64[]
    Fz_arr = Float64[]
    σ = 1.5
    for (i, t) in enumerate(times)
        ψ = zeros(ComplexF64, Nx, Ny, Nz, D)
        leak = 0.05 * t   # 0% at t=0, 2% at t=0.4
        amp_main = sqrt(1 - leak)
        amp_leak = sqrt(leak)
        for ix in 1:Nx, iy in 1:Ny, iz in 1:Nz
            x = ix - Nx/2 - 0.5;
            y = iy - Ny/2 - 0.5;
            z = iz - Nz/2 - 0.5
            g = exp(-(x*x + y*y + z*z) / (2σ*σ))
            ψ[ix, iy, iz, 1] = amp_main * g
            ψ[ix, iy, iz, 2] = amp_leak * g
        end
        # Normalize over the discrete spinor field
        norm = sqrt(sum(abs2, ψ))
        ψ ./= norm
        push!(snaps, ψ)

        pm = zeros(Float64, D)
        for m_idx in 1:D
            pm[m_idx] = sum(abs2, @view ψ[:, :, :, m_idx])
        end
        push!(per_m_hist, pm)
        push!(Lz_arr, 0.1 * t)            # synthetic: linear ⟨L_z⟩ growth
        # ⟨F_z⟩ = Σ m·N_m, with m_i = F - (i-1)
        push!(Fz_arr, sum((F_val - (i_-1)) * pm[i_] for i_ in 1:D))
    end

    dyn = Dict{Symbol, Any}(
        :times => times,
        :Lz => Lz_arr,
        :Fz => Fz_arr,
        :Fx => zeros(length(times)),
        :Fy => zeros(length(times)),
        :norms => ones(length(times)),
        :per_m_history => per_m_hist,
        :psi_snapshots => snaps,
        :theta_const => 0.611,
        :phi_omega => 4.524,
    )

    @testset "X2: population_dynamics — N_m(t)" begin
        res = SpinorBEC.population_dynamics(dyn)
        @test size(res.N_m) == (D, length(times))
        @test res.F == F_val
        # Initial: 100% in m=+F
        @test res.N_m[1, 1] ≈ 1.0 atol=1e-6
        # Final: leak signature visible
        @test res.N_m[1, end] < 1.0
        @test res.N_m[2, end] > 0.0
        # Population conservation (after normalize)
        for i in 1:length(times)
            @test sum(@view res.N_m[:, i]) ≈ 1.0 atol=1e-10
        end
    end

    @testset "X2': edh_conservation" begin
        res = SpinorBEC.edh_conservation(dyn)
        @test length(res.Jz) == length(times)
        @test res.Jz_drift[1] ≈ 0.0
        @test isfinite(res.conservation_max_rel)
    end

    @testset "X3: spin_texture_xy" begin
        res = SpinorBEC.spin_texture_xy(dyn; frame_idxs=[1, 3, 5])
        @test size(res.Fx) == (Nx, Ny, 3)
        @test size(res.Fy) == (Nx, Ny, 3)
        @test size(res.Fz) == (Nx, Ny, 3)
        @test res.F == F_val
        # Initial fully polarized in m=+F: ⟨F_z⟩ ≈ +F·ρ pointwise
        # Sum over (x,y) at frame 1: Σ ⟨F_z⟩ ≈ +F · ∫|ψ|²dxdy
        Fz_total_frame1 = sum(@view res.Fz[:, :, 1])
        @test Fz_total_frame1 > 0      # positive (m=+F polarized)
    end

    @testset "X4: per_m_column_density" begin
        cd = SpinorBEC.per_m_column_density(dyn; frame_idx=1)
        @test size(cd) == (Nx, Ny, D)
        # m=+F dominant
        @test sum(@view cd[:, :, 1]) > 0.9
        # m=+F-1 small but nonzero by frame 5
        cd5 = SpinorBEC.per_m_column_density(dyn; frame_idx=5)
        @test sum(@view cd5[:, :, 2]) > sum(@view cd[:, :, 2])
    end

    @testset "X4: detect_density_minima sanity" begin
        # Build a 2D field with a single hole at (4, 4)
        rho = ones(8, 8) * 1.0
        rho[4, 4] = 0.1
        cores = SpinorBEC.detect_density_minima(rho; density_threshold=0.5)
        @test (4, 4) in cores
    end

    @testset "X4: detect_per_m_vortices runs without error" begin
        res = SpinorBEC.detect_per_m_vortices(dyn; frame_idx=5,
            density_threshold=0.05)
        @test length(res.cores) == D
        @test size(res.column_density) == (Nx, Ny, D)
    end

    @testset "X6: berry_connection_trajectory analytical" begin
        # Constant tilt + linear stir (magnetostir-style)
        times_x6 = collect(0.0:0.1:1.0)
        res = SpinorBEC.berry_connection_trajectory(times_x6;
            theta_func=(t) -> 0.611,
            phi_func=(t) -> 4.524*t,
            theta_dot_func=(t) -> 0.0,
            phi_dot_func=(t) -> 4.524,
            gauge_fix=false)
        @test length(res.a_x) == length(times_x6)
        # Steady stir → constant Â magnitude
        @test all(abs.(res.a_mag .- res.a_mag[1]) .< 1e-10)
        # Magnitude = √(sin²θ + cos²θ)·φ̇ = φ̇
        @test res.a_mag[1] ≈ 4.524 atol=1e-10
        # Components match formula
        @test res.a_x[1] ≈ -4.524 * sin(0.611) atol=1e-10
        @test res.a_y[1] ≈ 0.0 atol=1e-10
        @test res.a_z[1] ≈ 4.524 * cos(0.611) atol=1e-10

        # gauge_fix=true: a_z absorbed into χ
        res_gf = SpinorBEC.berry_connection_trajectory(times_x6;
            theta_func=(t) -> 0.611,
            phi_func=(t) -> 4.524*t,
            theta_dot_func=(t) -> 0.0,
            phi_dot_func=(t) -> 4.524,
            gauge_fix=true)
        @test res_gf.a_z[1] ≈ 0.0 atol=1e-10
        @test res_gf.a_x[1] ≈ -4.524 * sin(0.611) atol=1e-10

        # From dyn dict
        res_dyn = SpinorBEC.berry_connection_trajectory(dyn; gauge_fix=false)
        @test res_dyn.a_mag[1] ≈ 4.524 atol=1e-10
    end
end
