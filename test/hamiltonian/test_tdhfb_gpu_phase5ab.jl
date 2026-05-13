using Test
using SpinorBEC
using Printf

# Phase 5a + 5b GPU TDHFB tests — design ref `tdhfb_gpu_port_design.md`.
#
# Phase 5a: state allocation, V-step broadcast, Hermiticity check on GPU.
# Phase 5b: K-step via batched cuFFT.
#
# Tests skip on missing CUDA (CI without GPU).

try
    @eval using CUDA
    if !CUDA.functional()
        @info "CUDA not functional — skipping TDHFB GPU phase5ab tests"
        return nothing
    end
catch e
    @info "CUDA not available — skipping TDHFB GPU phase5ab tests"
    return nothing
end

# Reset GPU state between tests
GC.gc()
CUDA.reclaim()

@testset "TDHFB GPU phase5a: state allocation" begin
    psi = CUDA.zeros(ComplexF32, 16, 16, 16, 13)
    state = init_tdhfb_vacuum(psi)
    @test typeof(state.phi) <: CuArray
    @test typeof(state.rho) <: CuArray
    @test typeof(state.kappa) <: CuArray
    @test size(state.phi) == (16, 16, 16, 13)
    @test size(state.rho) == (16, 16, 16, 13, 13)
    @test size(state.kappa) == (16, 16, 16, 13, 13)
    @test eltype(state.phi) == ComplexF32

    # Memory size sanity (F=6 32³ should be < 200 MB at F32)
    total_mb = (sizeof(state.phi) + sizeof(state.rho) + sizeof(state.kappa)) / 1024 / 1024
    @test total_mb < 50  # at 16³ F32, ~ 11 MB
end

@testset "TDHFB GPU phase5a: 32³ F=6 memory budget" begin
    psi = CUDA.zeros(ComplexF32, 32, 32, 32, 13)
    state = init_tdhfb_vacuum(psi)
    total_mb = (sizeof(state.phi) + sizeof(state.rho) + sizeof(state.kappa)) / 1024 / 1024
    # Design budget for 32³ F=6 F32: 88 MB
    @test 80 < total_mb < 100
end

@testset "TDHFB GPU phase5a: Hermiticity check on vacuum" begin
    psi = CUDA.zeros(ComplexF32, 8, 8, 8, 13)
    state = init_tdhfb_vacuum(psi)
    rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
    @test rho_dev < 1e-10
    @test kappa_dev < 1e-10
end

@testset "TDHFB GPU phase5a: V-step broadcast" begin
    psi = CUDA.zeros(ComplexF32, 8, 8, 8, 13)
    psi .= ComplexF32(1.0) + 0.0im * ComplexF32(0.0)
    state = init_tdhfb_vacuum(psi; alias=true)
    # uniform V_ext, all components → uniform phase rotation
    V_ext = CUDA.fill(Float32(0.5), 8, 8, 8, 13)
    dt = 0.02
    SpinorBEC._tdhfb_v_step!(state.phi, V_ext, dt)
    phi_host = Array(state.phi)
    expected = cis(-Float64(0.5) * dt) |> ComplexF32
    @test all(abs.(phi_host .- expected) .< 1e-6)
end

@testset "TDHFB GPU phase5b: K-step matches CPU at F64" begin
    N_grid = 16
    D = 13
    # Deterministic random state to compare CPU vs GPU
    rng_phi = randn(ComplexF64, N_grid, N_grid, N_grid, D)
    phi_cpu = copy(rng_phi)
    phi_gpu = CuArray(copy(rng_phi))

    dt = 0.01
    SpinorBEC._tdhfb_kinetic_step!(phi_cpu, dt)
    SpinorBEC._tdhfb_kinetic_step!(phi_gpu, dt)
    CUDA.synchronize()

    rel_diff = maximum(abs.(Array(phi_gpu) .- phi_cpu)) / maximum(abs, phi_cpu)
    @test rel_diff < 1e-12
end

@testset "TDHFB GPU phase5b: K-step preserves norm" begin
    psi = CUDA.zeros(ComplexF32, 16, 16, 16, 13)
    psi .= randn(ComplexF32) * Float32(0.1)
    phi = copy(psi)
    norm_before = sqrt(sum(abs2, phi))
    SpinorBEC._tdhfb_kinetic_step!(phi, 0.05)
    CUDA.synchronize()
    norm_after = sqrt(sum(abs2, phi))
    # FFT/IFFT round-trip + unitary phase → norm preserved to F32 precision
    @test abs(norm_before - norm_after) / norm_before < 1e-5
end

@testset "TDHFB GPU phase5b: K-step F32 standalone" begin
    psi = CuArray(randn(ComplexF32, 16, 16, 16, 13))
    phi_before = copy(psi)
    SpinorBEC._tdhfb_kinetic_step!(psi, 0.01)
    CUDA.synchronize()
    # Just check that the call runs without error on F32 input
    @test all(isfinite, Array(psi))
end

# Cleanup
GC.gc()
CUDA.reclaim()
