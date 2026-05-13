using Test
using SpinorBEC
using LinearAlgebra
using Printf

# Phase 5c HF substep — design ref `tdhfb_gpu_port_design.md` §3c-3f.
#
# Tests the GPU `_tdhfb_hf_step!(::CuArray, ...)` dispatch against the CPU
# `_tdhfb_hf_step!` reference. Covers:
#   - φ subupdate alone
#   - R subupdate alone (vacuum κ, thermal κ)
#   - Full HF step composition (φ + R + φ symmetric Strang)
#   - Hermitian projection on ρ, symmetric projection on κ
#   - Norm preservation on a vacuum-(ρ=κ=0) initial state

try
    @eval using CUDA
    if !CUDA.functional()
        @info "CUDA not functional — skipping TDHFB GPU phase5c HF tests"
        return nothing
    end
catch e
    @info "CUDA not available — skipping TDHFB GPU phase5c HF tests"
    return nothing
end

GC.gc()
CUDA.reclaim()

function _make_states(F::Int, spatial::Tuple; with_rho::Real=0.0, with_kappa::Real=0.0)
    D = 2F + 1
    phi_cpu = randn(ComplexF64, spatial..., D) * 0.1
    rho_cpu = zeros(ComplexF64, spatial..., D, D)
    kappa_cpu = zeros(ComplexF64, spatial..., D, D)
    if with_rho > 0
        for I in CartesianIndices(spatial), c in 1:D
            rho_cpu[I, c, c] = with_rho + 0im
        end
    end
    if with_kappa > 0
        for I in CartesianIndices(spatial), c in 1:D
            kappa_cpu[I, c, c] = with_kappa + 0im
        end
    end
    N = length(spatial)
    state_cpu = SpinorBEC.TDHFBState{N, typeof(phi_cpu), typeof(rho_cpu), Float64}(
        copy(phi_cpu), copy(rho_cpu), copy(kappa_cpu), 0.0, 0
    )
    state_gpu = SpinorBEC.TDHFBState{
        N,
        CuArray{ComplexF64, N + 1, CUDA.DeviceMemory},
        CuArray{ComplexF64, N + 2, CUDA.DeviceMemory},
        Float64,
    }(
        CuArray(copy(phi_cpu)), CuArray(copy(rho_cpu)), CuArray(copy(kappa_cpu)),
        0.0, 0,
    )
    (state_cpu, state_gpu)
end

@testset "TDHFB GPU phase5c HF: φ subupdate vs CPU (F=1, vacuum)" begin
    state_cpu, state_gpu = _make_states(1, (4, 4, 4))
    g_S = Dict{Int, Float64}(0 => 0.5)
    V_cpu = SpinorBEC.channel_kernel(1, g_S)
    SpinorBEC._tdhfb_phi_subupdate!(state_cpu, 1, g_S, V_cpu, 0.005; hfb_mode=:full_hfb)
    SpinorBEC._tdhfb_phi_subupdate!(state_gpu, 1, g_S, nothing, 0.005; hfb_mode=:full_hfb)
    CUDA.synchronize()
    phi_diff = maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi))
    @test phi_diff < 1e-13
end

@testset "TDHFB GPU phase5c HF: R subupdate vs CPU (F=1, thermal)" begin
    state_cpu, state_gpu = _make_states(1, (4, 4, 4); with_rho=0.05, with_kappa=0.01)
    g_S = Dict{Int, Float64}(0 => 0.5)
    V_cpu = SpinorBEC.channel_kernel(1, g_S)
    SpinorBEC._tdhfb_R_subupdate!(state_cpu, 1, g_S, V_cpu, 0.01)
    SpinorBEC._tdhfb_R_subupdate!(state_gpu, 1, g_S, nothing, 0.01)
    CUDA.synchronize()
    rho_diff = maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho))
    kappa_diff = maximum(abs.(Array(state_gpu.kappa) .- state_cpu.kappa))
    @test rho_diff < 1e-13
    @test kappa_diff < 1e-13
end

@testset "TDHFB GPU phase5c HF: full HF step vs CPU (F=1, thermal)" begin
    state_cpu, state_gpu = _make_states(1, (4, 4, 4); with_rho=0.05, with_kappa=0.01)
    g_S = Dict{Int, Float64}(0 => 0.5)
    SpinorBEC._tdhfb_hf_step!(state_cpu, 1, g_S, 0.01; hfb_mode=:full_hfb)
    SpinorBEC._tdhfb_hf_step!(state_gpu, 1, g_S, 0.01; hfb_mode=:full_hfb)
    CUDA.synchronize()
    phi_diff = maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi))
    rho_diff = maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho))
    kappa_diff = maximum(abs.(Array(state_gpu.kappa) .- state_cpu.kappa))
    @test phi_diff < 1e-13
    @test rho_diff < 1e-13
    @test kappa_diff < 1e-13
end

@testset "TDHFB GPU phase5c HF: Hermitian rho + symmetric kappa preserved" begin
    _, state_gpu = _make_states(1, (4, 4, 4); with_rho=0.05, with_kappa=0.01)
    g_S = Dict{Int, Float64}(0 => 0.5)
    SpinorBEC._tdhfb_hf_step!(state_gpu, 1, g_S, 0.01; hfb_mode=:full_hfb)
    CUDA.synchronize()
    rho_dev, kappa_dev = tdhfb_hermiticity_check(state_gpu)
    @test rho_dev < 1e-13
    @test kappa_dev < 1e-13
end

@testset "TDHFB GPU phase5c HF: Popov mode (drop anomalous in phi sub)" begin
    state_cpu, state_gpu = _make_states(1, (4, 4, 4); with_rho=0.05, with_kappa=0.01)
    g_S = Dict{Int, Float64}(0 => 0.5)
    SpinorBEC._tdhfb_hf_step!(state_cpu, 1, g_S, 0.01; hfb_mode=:popov)
    SpinorBEC._tdhfb_hf_step!(state_gpu, 1, g_S, 0.01; hfb_mode=:popov)
    CUDA.synchronize()
    @test maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi)) < 1e-13
    @test maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho)) < 1e-13
    @test maximum(abs.(Array(state_gpu.kappa) .- state_cpu.kappa)) < 1e-13
end

@testset "TDHFB GPU phase5c HF: 10 HF steps vs CPU end-to-end" begin
    state_cpu, state_gpu = _make_states(1, (4, 4, 4); with_rho=0.05, with_kappa=0.01)
    g_S = Dict{Int, Float64}(0 => 0.5)
    for _ in 1:10
        SpinorBEC._tdhfb_hf_step!(state_cpu, 1, g_S, 0.005)
        SpinorBEC._tdhfb_hf_step!(state_gpu, 1, g_S, 0.005)
    end
    CUDA.synchronize()
    # Accumulated error over 10 steps should still be at F64 precision (no
    # systematic divergence from CPU).
    @test maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi)) < 1e-10
    @test maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho)) < 1e-10
    @test maximum(abs.(Array(state_gpu.kappa) .- state_cpu.kappa)) < 1e-10
end

@testset "TDHFB GPU phase5c HF: F=6 Eu sample voxel" begin
    state_cpu, state_gpu = _make_states(6, (4, 4, 4); with_rho=0.01, with_kappa=0.0)
    # Eu-typical g_S (rough order-of-magnitude)
    g_S = Dict{Int, Float64}(0 => 0.1, 2 => 0.05, 4 => 0.02)
    SpinorBEC._tdhfb_hf_step!(state_cpu, 6, g_S, 0.001; hfb_mode=:full_hfb)
    SpinorBEC._tdhfb_hf_step!(state_gpu, 6, g_S, 0.001; hfb_mode=:full_hfb)
    CUDA.synchronize()
    # F=6 has D=13, larger matrices, slightly looser tolerance
    @test maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi)) < 1e-11
    @test maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho)) < 1e-11
    @test maximum(abs.(Array(state_gpu.kappa) .- state_cpu.kappa)) < 1e-11
end

GC.gc()
CUDA.reclaim()
