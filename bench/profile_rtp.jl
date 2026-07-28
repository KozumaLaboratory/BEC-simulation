# Real-time-propagation profiler.
#
#   julia --project=. bench/profile_rtp.jl [N_GRID] [n_steps] [cpu|gpu]
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/profile_rtp.jl 64 10 gpu
#
# Two independent views of one RTP step on a production-shaped Eu151 workspace
# (F=6, D=13, DDI + c0 + c1):
#
#   1. a knob decomposition — the same step re-run with DDI off / the mean-field
#      midpoint corrector off, so each structural cost is a difference of two
#      end-to-end numbers rather than an isolated kernel benchmark;
#   2. a sampling profile attributed to the leaf kernels, which sums to the
#      total by construction.
#
# Both are needed: (1) says which design decision costs what, (2) says which
# line to edit. Reporting either alone has produced wrong conclusions in this
# repo before (see bench/reconcile.jl).

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10
const USE_GPU = length(ARGS) >= 3 && lowercase(ARGS[3]) == "gpu"

if USE_GPU
    @eval import CUDA
end
using SpinorBEC
using Printf
using Profile
using LinearAlgebra
include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "reconcile.jl"))

function build_rtp_workspace(; n=N_GRID, gpu=USE_GPU, c1_ratio=0.05, dt=1e-4, ddi=true)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    ip = eu_interaction_params(c1_ratio)
    sp = SimParams(; dt, n_steps=N_STEPS, imaginary_time=false, save_every=10^9)
    backend = gpu ? CUDABackend() : CPUBackend()
    ws = make_workspace(;
        grid,
        atom=Eu151,
        interactions=ip,
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
        sim_params=sp,
        enable_ddi=ddi,
        c_dd=ddi ? EU_c_dd : NaN,
        backend,
    )
    # Tilted spin-coherent: ⟨F⟩ has all three components non-zero, so neither
    # the spin-mixing rotation nor the DDI Euler rotation short-circuits.
    psi = init_psi(grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.6, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    copyto!(ws.state.psi, psi)
    ws
end

gpu_sync() = USE_GPU ? Base.invokelatest(getfield(Main, :CUDA).synchronize) : nothing

function step_n!(ws, k)
    for _ in 1:k
        SpinorBEC.split_step!(ws)
    end
    gpu_sync()
end

"ms per step, minimum over samples, after warm-up."
function ms_per_step(ws; k=N_STEPS, samples=3)
    r = timed(() -> step_n!(ws, k); warmup=1, samples)
    1e3 * r.t / k
end

function knob_decomposition()
    println("\n=== knob decomposition (ms/step, min of 3) ===")
    rows = Tuple{String, Float64}[]

    ws = build_rtp_workspace(; ddi=true)
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
    full = ms_per_step(ws)
    push!(rows, ("DDI + midpoint  (production default)", full))

    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = false
    plain = ms_per_step(ws)
    push!(rows, ("DDI, no midpoint", plain))
    SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true

    ws0 = build_rtp_workspace(; ddi=false)
    noddi = ms_per_step(ws0)
    push!(rows, ("no DDI (⇒ no midpoint either)", noddi))

    for (name, v) in rows
        @printf("  %-40s %9.3f\n", name, v)
    end
    @printf("\n  midpoint predictor-corrector costs %.3f ms/step (%.0f%% of full)\n",
        full - plain, 100 * (full - plain) / full)
    @printf("  DDI (incl. its midpoint) costs      %.3f ms/step (%.0f%% of full)\n",
        full - noddi, 100 * (full - noddi) / full)
    @printf("  everything else                     %.3f ms/step (%.0f%% of full)\n",
        noddi, 100 * noddi / full)
    full
end

function sampling_profile()
    println("\n=== sampling profile (leaf attribution) ===")
    ws = build_rtp_workspace()
    step_n!(ws, 2)
    Profile.clear()
    Profile.init(; n=10^7, delay=0.0005)
    Profile.@profile step_n!(ws, N_STEPS)

    data, lidict = Profile.retrieve()
    counts = Dict{String, Int}()
    total = 0
    # Leaf attribution: the first (innermost) frame of each backtrace.
    i = 1
    while i <= length(data)
        j = i
        while j <= length(data) && data[j] != 0
            j += 1
        end
        if j > i
            frames = lidict[data[i]]
            fr = frames isa Vector ? first(frames) : frames
            key = string(fr.func, "  @ ", basename(string(fr.file)), ":", fr.line)
            counts[key] = get(counts, key, 0) + 1
            total += 1
        end
        i = j + 1
    end
    top = sort(collect(counts); by=last, rev=true)
    @printf("  %-64s %7s %6s\n", "leaf frame", "samples", "%")
    for (k, v) in first(top, 25)
        @printf("  %-64s %7d %5.1f%%\n", k, v, 100 * v / total)
    end
    println("  (total leaf samples: $total)")
end

function gpu_kernel_profile()
    println("\n=== CUDA kernel breakdown (one step) ===")
    CUDA = getfield(Main, :CUDA)
    ws = build_rtp_workspace()
    step_n!(ws, 3)
    display(CUDA.@profile step_n!(ws, 1))
    println()
end

function main()
    @printf("RTP profile — Eu151 F=6 (D=13), %d^3, %s\n", N_GRID, USE_GPU ? "GPU" : "CPU")
    @printf("  julia threads=%d  BLAS threads=%d  load=%s\n",
        Threads.nthreads(), LinearAlgebra.BLAS.get_num_threads(),
        first(split(read("/proc/loadavg", String))))
    knob_decomposition()
    USE_GPU ? gpu_kernel_profile() : sampling_profile()
end

main()
