using Test
using CUDA
using SpinorBEC
using StaticArrays: SVector

# Comprehensive GPU integration test for Option γ (rotating_basis).
#
# Strategy: build a small GPU workspace, then exercise EVERY public
# function. With `CUDA.allowscalar(false)` (the default in modern CUDA.jl),
# any scalar-indexing bug surfaces as an error. The goal is to surface
# ALL such bugs in one pass instead of fixing them one error at a time.
#
# Each `@testset` is a single function under test. The error message
# pinpoints which function still has scalar indexing.

CUDA.functional() || error("CUDA not functional — cannot run GPU tests")
@info "Starting GPU integration test on $(CUDA.device())"

@testset "Option γ GPU comprehensive" begin
    F_t = 1
    config = GridConfig((8, 8, 4), (4.0, 4.0, 2.0))
    grid = SpinorBEC.make_grid(config)
    V_trap = zeros(Float64, 8, 8, 4)
    @inbounds for I in CartesianIndices(V_trap)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        V_trap[I] = 0.5 * (x^2 + y^2 + 2.6^2 * z^2)
    end

    function make_ws_gpu(; c_dd=0.0, c1=0.0)
        ws = SpinorBEC.make_rotating_basis_ws(grid, F_t, V_trap;
            p=2.0, q=0.0, c0=10.0, c1=c1, c_dd=c_dd, gamma_lhy=0.0,
            theta_func=(t)->π/8, phi_func=(t)->1.0*t,
            theta_dot_func=(t)->0.0, phi_dot_func=(t)->1.0,
            gauge_fix=false,
            backend=SpinorBEC.CUDABackend())
        # Initialize Gaussian on host, copy to device
        psi_host = zeros(ComplexF64, 8, 8, 4, 3)
        @inbounds for I in CartesianIndices((8, 8, 4))
            x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
            psi_host[I, 1] = exp(-(x^2 + y^2 + z^2) / 2)
        end
        copyto!(ws.psi_tilde, psi_host)
        ws
    end

    @testset "make_rotating_basis_ws (GPU allocation)" begin
        ws = make_ws_gpu()
        @test ws.psi_tilde isa CuArray
        @test ws.V_trap isa CuArray
        @test ws.spatial_buf isa CuArray
        @test ws.rho_buf isa CuArray
    end

    @testset "rotating_norm" begin
        ws = make_ws_gpu()
        n = SpinorBEC.rotating_norm(ws)
        @test n > 0 && isfinite(n)
    end

    @testset "normalize_rotating!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-10
    end

    @testset "rotating_per_m_norms" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        pm = SpinorBEC.rotating_per_m_norms(ws)
        @test sum(pm) ≈ 1.0 atol=1e-10
    end

    @testset "rotating_total_density" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        rho = SpinorBEC.rotating_total_density(ws)
        @test rho isa Array{Float64, 3}     # returns host array
        @test sum(rho) > 0
    end

    @testset "apply_kinetic_step_rotating!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.apply_kinetic_step_rotating!(ws, 0.01)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
    end

    @testset "apply_spatial_diagonal_step!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.apply_spatial_diagonal_step!(ws, 0.01)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
    end

    @testset "apply_local_spin_step!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.apply_local_spin_step!(ws, 0.01, 0.0)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
    end

    @testset "_apply_UB! roundtrip" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        n_before = SpinorBEC.rotating_norm(ws)
        SpinorBEC._apply_UB!(ws.psi_tilde, ws.spin_matrices, π/4, 0.5, 3; inverse=false)
        SpinorBEC._apply_UB!(ws.psi_tilde, ws.spin_matrices, π/4, 0.5, 3; inverse=true)
        @test SpinorBEC.rotating_norm(ws) ≈ n_before atol=1e-8
    end

    @testset "apply_ddi_step_rotating!" begin
        ws = make_ws_gpu(; c_dd=5.0)
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.apply_ddi_step_rotating!(ws, 0.01, 0.0)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7
    end

    @testset "apply_gauge_step!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.apply_gauge_step!(ws, 0.01, 0.0)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
    end

    @testset "split_step_rotating! (RTP)" begin
        ws = make_ws_gpu(; c_dd=3.0)
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.split_step_rotating!(ws, 0.005, 0.0)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7
    end

    @testset "split_step_rotating! (ITP)" begin
        ws = make_ws_gpu(; c_dd=3.0)
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.split_step_rotating!(ws, 0.005, 0.0; imaginary_time=true)
        SpinorBEC.normalize_rotating!(ws)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-8
    end

    @testset "find_ground_state_rotating! (ITP loop)" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        μ = SpinorBEC.find_ground_state_rotating!(ws, 10, 0.005)
        @test isfinite(μ)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-7
    end

    @testset "evolve_rotating! (RTP loop)" begin
        ws = make_ws_gpu(; c_dd=3.0)
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.evolve_rotating!(ws, 5, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-6
    end

    @testset "evolve_rotating_yoshida4!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.evolve_rotating_yoshida4!(ws, 5, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-6
    end

    @testset "evolve_rotating_yoshida6!" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        SpinorBEC.evolve_rotating_yoshida6!(ws, 5, 0.005)
        @test SpinorBEC.rotating_norm(ws) ≈ 1.0 atol=1e-6
    end

    @testset "rotating_Lz" begin
        ws = make_ws_gpu()
        SpinorBEC.normalize_rotating!(ws)
        lz = SpinorBEC.rotating_Lz(ws)
        @test isfinite(lz)
    end
end

@info "All GPU integration tests passed."
