# Phase 5e — Eu151 F=6 32³ TDHFB GPU production benchmark.
#
# Design ref: `docs/design/tdhfb_gpu_port_design.md` §1.2-1.3, §6.3.
# Target: 30-60× speedup vs CPU on full `tdhfb_strang_step!`.
#
# Workload: F=6 (D=13) at 32³ grid, Eu-typical g_S = {S=0: 0.1, S=2: 0.05,
# S=4: 0.02, S=6: 0.01}, thermal initial state (ρ_diag=0.01).
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/bench/track_5e_tdhfb_gpu_eu.jl

using CUDA
using SpinorBEC
using Printf

const N_GRID = 32
const F = 6
const D = 2F + 1
const N_STEPS = 10
const DT = 0.001

const g_S = Dict{Int, Float64}(
    0 => 0.1,
    2 => 0.05,
    4 => 0.02,
    6 => 0.01,
)

function _make_state(::Type{T}) where {T <: AbstractArray}
    phi = T <: CuArray ?
        CUDA.zeros(ComplexF64, N_GRID, N_GRID, N_GRID, D) :
        zeros(ComplexF64, N_GRID, N_GRID, N_GRID, D)
    # Hand-build a small random initial state
    if T <: Array
        phi .= randn(ComplexF64, size(phi)) * 0.05
    else
        phi_host = randn(ComplexF64, size(phi)) * 0.05
        copyto!(phi, phi_host)
    end
    state = init_tdhfb_vacuum(phi; alias=true)
    # Add small thermal ρ (diagonal)
    if T <: CuArray
        rho_host = zeros(ComplexF64, N_GRID, N_GRID, N_GRID, D, D)
        for I in CartesianIndices((N_GRID, N_GRID, N_GRID)), c in 1:D
            rho_host[I, c, c] = 0.01 + 0im
        end
        copyto!(state.rho, rho_host)
    else
        for I in CartesianIndices((N_GRID, N_GRID, N_GRID)), c in 1:D
            state.rho[I, c, c] = 0.01 + 0im
        end
    end
    state
end

function bench_backend(::Type{T}, n_steps::Int; warmup::Int=1) where {T}
    state = _make_state(T)
    V_ext = T <: CuArray ?
        CUDA.zeros(Float64, N_GRID, N_GRID, N_GRID, D) :
        zeros(Float64, N_GRID, N_GRID, N_GRID, D)

    # Warmup (JIT + cache fill)
    for _ in 1:warmup
        tdhfb_strang_step!(state, F, g_S, V_ext, DT)
    end
    T <: CuArray && CUDA.synchronize()

    # Reset for timing
    state = _make_state(T)
    t_start = time()
    for _ in 1:n_steps
        tdhfb_strang_step!(state, F, g_S, V_ext, DT)
    end
    T <: CuArray && CUDA.synchronize()
    wall = time() - t_start
    (wall, state)
end

# ===== Run =====
@printf("=== Phase 5e: Eu151 F=6 %d³ TDHFB GPU benchmark ===\n", N_GRID)
@printf("F=%d, D=%d, n_steps=%d, dt=%.4f\n", F, D, N_STEPS, DT)
@printf("g_S = %s\n", g_S)
@printf("\n")

# GPU
println("--- GPU (CUDA RTX 5070 Ti) ---")
flush(stdout)
gpu_wall, state_gpu = bench_backend(CuArray, N_STEPS; warmup=2)
@printf("Wall: %.2fs (%.1f ms/step)\n", gpu_wall, gpu_wall * 1000 / N_STEPS)

# CPU
println("\n--- CPU ---")
flush(stdout)
@printf("Starting CPU (this takes ~%d s)...\n", Int(N_STEPS * 2))
cpu_wall, state_cpu = bench_backend(Array, N_STEPS; warmup=1)
@printf("Wall: %.2fs (%.1f ms/step)\n", cpu_wall, cpu_wall * 1000 / N_STEPS)

# Comparison
speedup = cpu_wall / gpu_wall
@printf("\n=== Speedup ===\n")
@printf("CPU: %.2f s/step\n", cpu_wall / N_STEPS)
@printf("GPU: %.3f s/step\n", gpu_wall / N_STEPS)
@printf("Speedup: %.1f×\n", speedup)

@printf("\n=== Design-doc acceptance §1.3 ===\n")
if speedup >= 60
    @printf("✓✓✓ STRETCH PASS (≥ 60×): %.1f×\n", speedup)
elseif speedup >= 30
    @printf("✓ MINIMUM PASS (≥ 30×): %.1f×\n", speedup)
else
    @printf("△ Below minimum target 30×: %.1f×\n", speedup)
end

# Correctness check at small grid
@printf("\n=== Correctness sanity (F=6 8³ side check) ===\n")
const N_SMALL = 8
phi_init = randn(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D) * 0.05
state_cpu_s = SpinorBEC.TDHFBState{3, Array{ComplexF64, 4}, Array{ComplexF64, 5}, Float64}(
    copy(phi_init),
    zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
    zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
    0.0, 0,
)
state_gpu_s = SpinorBEC.TDHFBState{3, CuArray{ComplexF64, 4, CUDA.DeviceMemory}, CuArray{ComplexF64, 5, CUDA.DeviceMemory}, Float64}(
    CuArray(copy(phi_init)),
    CUDA.zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
    CUDA.zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
    0.0, 0,
)
for I in CartesianIndices((N_SMALL, N_SMALL, N_SMALL)), c in 1:D
    state_cpu_s.rho[I, c, c] = 0.01 + 0im
end
rho_h = zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D)
for I in CartesianIndices((N_SMALL, N_SMALL, N_SMALL)), c in 1:D
    rho_h[I, c, c] = 0.01 + 0im
end
copyto!(state_gpu_s.rho, rho_h)
Vc = zeros(Float64, N_SMALL, N_SMALL, N_SMALL, D)
Vg = CUDA.zeros(Float64, N_SMALL, N_SMALL, N_SMALL, D)
for _ in 1:5
    tdhfb_strang_step!(state_cpu_s, F, g_S, Vc, DT)
    tdhfb_strang_step!(state_gpu_s, F, g_S, Vg, DT)
end
CUDA.synchronize()
phi_diff = maximum(abs.(Array(state_gpu_s.phi) .- state_cpu_s.phi))
@printf("F=6 8³ 5-step CPU vs GPU diff (phi): %.3e\n", phi_diff)
