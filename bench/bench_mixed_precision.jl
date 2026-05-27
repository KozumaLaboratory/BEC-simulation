# Mixed-precision benchmark: F32 vs F64 on CPU and (if available) CUDA.
#
# Measures VRAM/RAM footprint and throughput (steps/sec) of:
#   (a) full split-step with DDI on Eu151 spinor (F=6, 13 components)
#   (b) scalar F=1 spinor at smaller grid (cheaper, more robust)
#
# Usage:
#   julia --project=. bench/bench_mixed_precision.jl             # CPU only
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/bench_mixed_precision.jl  # CPU + CUDA
#
# Prints a compact markdown table at the end.

using Printf
using SpinorBEC

try
    global _have_cuda = false
    using CUDA
    CUDA.functional() && (_have_cuda = true)
catch
    _have_cuda = false
end

# ---------------- harness ----------------

function _memory_mb(ws)
    # ψ + fft_buf + kinetic_phase + V + density_buf
    psi_b  = sizeof(ws.state.psi)
    fft_b  = sizeof(ws.state.fft_buf)
    kin_b  = sizeof(ws.kinetic_phase)
    V_b    = sizeof(ws.potential_values)
    dens_b = sizeof(ws.density_buf)
    ddi_b  = if ws.ddi === nothing
        0
    else
        sizeof(ws.ddi.Q_xx) * 6 +
        sizeof(ws.ddi_bufs.Fx_r) * 3 +
        sizeof(ws.ddi_bufs.Fx_rk) * 6 +
        sizeof(ws.ddi_bufs.Phi_x) * 3
    end
    (psi_b + fft_b + kin_b + V_b + dens_b + ddi_b) / (1024^2)
end

function bench_case(; dims::NTuple, T::Type, F::Int, enable_ddi::Bool, backend,
                      label::String, n_bench_steps::Int = 50)
    cfg = GridConfig(dims, ntuple(_ -> 10.0, length(dims)))
    grid = make_grid(cfg; dtype = T)

    atom = if F == 1
        AtomSpecies("Na23", 3.8e-26, 1, 52.0 * 5.29e-11, 54.3 * 5.29e-11, 0.0)
    elseif F == 6
        # 151Eu (dipolar)
        AtomSpecies("Eu151", 2.5e-25, 6, 110 * 5.29e-11, 0.0, 6.977 * 9.274e-24)
    else
        error("unsupported F=$F")
    end

    ip = F == 1 ? InteractionParams(Dict(0 => 50.0, 1 => -0.2)) : InteractionParams(Dict(0 => 100.0, 1 => 2.8))
    trap = length(dims) == 3 ? HarmonicTrap(1.0, 1.0, 1.0) :
           length(dims) == 2 ? HarmonicTrap(1.0, 1.0) : HarmonicTrap(1.0)
    sp = SimParams(; dt = 0.001, n_steps = n_bench_steps)

    ws_kwargs = (;
        grid, atom, interactions = ip, sim_params = sp, potential = trap,
        backend = backend, dtype = T,
    )
    ws_kwargs = enable_ddi ? merge(ws_kwargs, (; enable_ddi = true, c_dd = 100.0)) :
                             ws_kwargs

    ws = make_workspace(; ws_kwargs...)

    # Warm up JIT
    for _ = 1:3
        SpinorBEC.split_step!(ws)
    end

    # Measure
    n_trials = 3
    best = Inf
    for _ = 1:n_trials
        t0 = time_ns()
        for _ = 1:n_bench_steps
            SpinorBEC.split_step!(ws)
        end
        t_per_step = (time_ns() - t0) / 1e9 / n_bench_steps
        best = min(best, t_per_step)
    end
    t_per_step = best

    mem_mb = _memory_mb(ws)

    @printf("  %-35s | dims=%s | ψ=%s | %.2f MB | %.3f ms/step | %.0f steps/s\n",
            label, string(dims), eltype(ws.state.psi), mem_mb,
            t_per_step * 1e3, 1 / t_per_step)

    (; label, dims, eltype_psi = eltype(ws.state.psi),
       mem_mb, t_per_step, steps_per_sec = 1/t_per_step)
end

# ---------------- runs ----------------

const RESULTS = NamedTuple[]

function run_case(args...; kwargs...)
    r = try
        bench_case(args...; kwargs...)
    catch e
        @warn "bench failed" label=kwargs[:label] exc=sprint(showerror, e)
        nothing
    end
    r !== nothing && push!(RESULTS, r)
    r
end

println("=== CPU benchmarks (F=1, no DDI) ===")
for dims in [(32, 32, 32), (64, 64, 64)]
    run_case(; dims, T = Float64, F = 1, enable_ddi = false,
              backend = CPUBackend(), label = "CPU F=1 F64")
    run_case(; dims, T = Float32, F = 1, enable_ddi = false,
              backend = CPUBackend(), label = "CPU F=1 F32")
end

println("\n=== CPU benchmarks (F=6 Eu151, DDI on) ===")
for dims in [(32, 32, 32)]
    run_case(; dims, T = Float64, F = 6, enable_ddi = true,
              backend = CPUBackend(), label = "CPU Eu151 F64 + DDI")
    run_case(; dims, T = Float32, F = 6, enable_ddi = true,
              backend = CPUBackend(), label = "CPU Eu151 F32 + DDI")
end

if _have_cuda
    println("\n=== GPU benchmarks (F=1, no DDI) ===")
    for dims in [(64, 64, 64), (128, 128, 128)]
        run_case(; dims, T = Float64, F = 1, enable_ddi = false,
                  backend = SpinorBEC.CUDABackend(), label = "GPU F=1 F64")
        run_case(; dims, T = Float32, F = 1, enable_ddi = false,
                  backend = SpinorBEC.CUDABackend(), label = "GPU F=1 F32")
    end

    println("\n=== GPU benchmarks (F=6 Eu151, DDI on) ===")
    for dims in [(64, 64, 64)]
        run_case(; dims, T = Float64, F = 6, enable_ddi = true,
                  backend = SpinorBEC.CUDABackend(), label = "GPU Eu151 F64 + DDI")
        run_case(; dims, T = Float32, F = 6, enable_ddi = true,
                  backend = SpinorBEC.CUDABackend(), label = "GPU Eu151 F32 + DDI")
    end
else
    println("\n(CUDA not available — skipping GPU benchmarks)")
end

println("\n=== Summary ===")
println("| label | dims | ψ eltype | mem (MB) | ms/step | steps/s |")
println("|-------|------|----------|----------|---------|---------|")
for r in RESULTS
    @printf("| %s | %s | %s | %.2f | %.3f | %.0f |\n",
            r.label, string(r.dims), r.eltype_psi,
            r.mem_mb, r.t_per_step * 1e3, r.steps_per_sec)
end

# Ratios
println("\n=== F32/F64 speedup (same grid, same label family) ===")
pairs = [
    ("CPU F=1 F64",        "CPU F=1 F32"),
    ("CPU Eu151 F64 + DDI", "CPU Eu151 F32 + DDI"),
    ("GPU F=1 F64",        "GPU F=1 F32"),
    ("GPU Eu151 F64 + DDI", "GPU Eu151 F32 + DDI"),
]
for (lab64, lab32) in pairs
    rs64 = filter(r -> r.label == lab64, RESULTS)
    rs32 = filter(r -> r.label == lab32, RESULTS)
    for (r64, r32) in zip(rs64, rs32)
        r64.dims == r32.dims || continue
        mem_ratio = r32.mem_mb / r64.mem_mb
        speed = r64.t_per_step / r32.t_per_step
        @printf("  %s @ dims=%s: memory %.2f×, speed %.2f×\n",
                lab64, string(r64.dims), mem_ratio, speed)
    end
end
