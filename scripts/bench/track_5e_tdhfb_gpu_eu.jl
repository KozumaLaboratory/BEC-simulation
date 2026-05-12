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

function _make_state(::Type{T}, ::Type{TC}) where {T, TC}
    # T: container (Array or CuArray), TC: ComplexF64 or ComplexF32
    phi_host = ComplexF64.(randn(ComplexF64, N_GRID, N_GRID, N_GRID, D) .* 0.05)
    phi = if T <: CuArray
        CuArray(TC.(phi_host))
    else
        TC.(phi_host)
    end
    state = init_tdhfb_vacuum(phi; alias=true)
    # Add small thermal ρ (diagonal)
    rho_host = zeros(TC, N_GRID, N_GRID, N_GRID, D, D)
    for I in CartesianIndices((N_GRID, N_GRID, N_GRID)), c in 1:D
        rho_host[I, c, c] = TC(0.01)
    end
    if T <: CuArray
        copyto!(state.rho, rho_host)
    else
        state.rho .= rho_host
    end
    state
end

function bench_backend(::Type{T}, ::Type{TC}, n_steps::Int; warmup::Int=2) where {T, TC}
    state = _make_state(T, TC)
    TR = real(TC)
    V_ext = if T <: CuArray
        CUDA.zeros(TR, N_GRID, N_GRID, N_GRID, D)
    else
        zeros(TR, N_GRID, N_GRID, N_GRID, D)
    end

    # Aggressive warmup with explicit sync between calls
    for _ in 1:warmup
        tdhfb_strang_step!(state, F, g_S, V_ext, DT)
        T <: CuArray && CUDA.synchronize()
    end

    # Fresh state for the actual timing run
    state = _make_state(T, TC)
    T <: CuArray && CUDA.synchronize()

    t_start = time()
    for _ in 1:n_steps
        tdhfb_strang_step!(state, F, g_S, V_ext, DT)
        # Explicit sync each step ensures we measure actual wall time, not
        # just kernel-queue time (CUDA is async by default).
        T <: CuArray && CUDA.synchronize()
    end
    wall = time() - t_start
    (wall, state)
end

# ===== Run =====
@printf("=== Phase 5e: Eu151 F=6 %d³ TDHFB GPU benchmark ===\n", N_GRID)
@printf("F=%d, D=%d, n_steps=%d, dt=%.4f\n", F, D, N_STEPS, DT)
@printf("g_S = %s\n", g_S)
@printf("\n")

# GPU F64
println("--- GPU F64 (CUDA RTX 5070 Ti, ComplexF64) ---")
flush(stdout)
gpu_f64_wall, _ = bench_backend(CuArray, ComplexF64, N_STEPS; warmup=2)
@printf("Wall: %.2fs (%.1f ms/step)\n", gpu_f64_wall, gpu_f64_wall * 1000 / N_STEPS)

# GPU F32
println("\n--- GPU F32 (ComplexF32 storage + compute) ---")
flush(stdout)
gpu_f32_wall, _ = bench_backend(CuArray, ComplexF32, N_STEPS; warmup=2)
@printf("Wall: %.2fs (%.1f ms/step)\n", gpu_f32_wall, gpu_f32_wall * 1000 / N_STEPS)

# CPU
println("\n--- CPU F64 ---")
flush(stdout)
@printf("Starting CPU (this takes ~%d s)...\n", Int(N_STEPS * 2))
cpu_wall, _ = bench_backend(Array, ComplexF64, N_STEPS; warmup=1)
@printf("Wall: %.2fs (%.1f ms/step)\n", cpu_wall, cpu_wall * 1000 / N_STEPS)

# Comparison
speedup_f64 = cpu_wall / gpu_f64_wall
speedup_f32 = cpu_wall / gpu_f32_wall
@printf("\n=== Speedup ===\n")
@printf("CPU F64:   %.2f s/step\n", cpu_wall / N_STEPS)
@printf("GPU F64:   %.3f s/step  → %5.1f× vs CPU\n",
    gpu_f64_wall / N_STEPS, speedup_f64)
@printf("GPU F32:   %.3f s/step  → %5.1f× vs CPU\n",
    gpu_f32_wall / N_STEPS, speedup_f32)
@printf("F64 → F32 ratio: %.1f× extra speedup from precision\n",
    gpu_f64_wall / gpu_f32_wall)

@printf("\n=== Design-doc acceptance §1.3 ===\n")
@printf("F32 speedup vs CPU: %.1f×\n", speedup_f32)
if speedup_f32 >= 60
    @printf("✓✓✓ STRETCH PASS (≥ 60×): %.1f×\n", speedup_f32)
elseif speedup_f32 >= 30
    @printf("✓ MINIMUM PASS (≥ 30×): %.1f×\n", speedup_f32)
else
    @printf("△ Below minimum target 30×: %.1f×\n", speedup_f32)
end

# Correctness check at small grid (both precisions)
@printf("\n=== Correctness sanity (F=6 8³ side check) ===\n")
function correctness_check(::Type{TC}) where {TC}
    N_SMALL = 8
    phi_seed = randn(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D) * 0.05
    state_cpu = SpinorBEC.TDHFBState{3, Array{ComplexF64, 4}, Array{ComplexF64, 5}, Float64}(
        copy(phi_seed),
        zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
        zeros(ComplexF64, N_SMALL, N_SMALL, N_SMALL, D, D),
        0.0, 0,
    )
    TR = real(TC)
    state_gpu = SpinorBEC.TDHFBState{3, CuArray{TC, 4, CUDA.DeviceMemory}, CuArray{TC, 5, CUDA.DeviceMemory}, TR}(
        CuArray(TC.(phi_seed)),
        CUDA.zeros(TC, N_SMALL, N_SMALL, N_SMALL, D, D),
        CUDA.zeros(TC, N_SMALL, N_SMALL, N_SMALL, D, D),
        TR(0), 0,
    )
    for I in CartesianIndices((N_SMALL, N_SMALL, N_SMALL)), c in 1:D
        state_cpu.rho[I, c, c] = 0.01 + 0im
    end
    rho_h = zeros(TC, N_SMALL, N_SMALL, N_SMALL, D, D)
    for I in CartesianIndices((N_SMALL, N_SMALL, N_SMALL)), c in 1:D
        rho_h[I, c, c] = TC(0.01)
    end
    copyto!(state_gpu.rho, rho_h)
    Vc = zeros(Float64, N_SMALL, N_SMALL, N_SMALL, D)
    Vg = CUDA.zeros(TR, N_SMALL, N_SMALL, N_SMALL, D)
    for _ in 1:5
        tdhfb_strang_step!(state_cpu, F, g_S, Vc, DT)
        tdhfb_strang_step!(state_gpu, F, g_S, Vg, DT)
    end
    CUDA.synchronize()
    phi_diff = maximum(abs.(Array(state_gpu.phi) .- state_cpu.phi))
    rho_diff = maximum(abs.(Array(state_gpu.rho) .- state_cpu.rho))
    @printf("  %s: phi diff = %.3e, rho diff = %.3e\n", TC, phi_diff, rho_diff)
end
correctness_check(ComplexF64)
correctness_check(ComplexF32)
