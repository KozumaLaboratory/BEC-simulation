# H100 GPU ratchet-metric collector for the goal-driven observability.
#
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib \
#   julia --project=. observability/collect_gpu.jl [N] [dtype] [commit]
#
# Emits ONE env-stamped JSON record to stdout AND appends it to
# observability/history.jsonl. Measures the ratchet metrics defined in
# observability/metrics.toml:
#   - gpu_busy_pct         Σ(device kernel time × per-step count) / wall  (launch-overhead headline)
#   - gpu_step_us          whole split_step! wall (min)
#   - kernels.*_us         per-kernel device time (min, isolated CUDA.@sync)
#   - kernels.*.util_lb    LOWER BOUND on roofline utilisation vs peak HBM BW
#   - allocs               host-side @allocated for one step
#
# No targets: these are ratcheted forever toward hardware limits. The record
# carries a full env stamp so only same-env-class records are ever compared.

import CUDA
using SpinorBEC
using Printf, JSON, Dates

include(joinpath(@__DIR__, "..", "bench", "eu151_params.jl"))

const N      = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 128
const DTYPE  = length(ARGS) >= 2 && lowercase(ARGS[2]) == "f32" ? Float32 : Float64
const COMMIT = length(ARGS) >= 3 ? ARGS[3] : get(ENV, "GIT_COMMIT", "unknown")

# ------------------------------------------------------------------ workspace
function ferro_init(grid, D, ::Type{CT}) where {CT}
    psi = zeros(CT, grid.config.n_points..., D)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        r2 = sum(grid.x[d][I[d]]^2 for d in 1:length(grid.config.n_points))
        psi[I, 1] = exp(-r2 / 2)
    end
    psi
end

L = 16.0
grid = make_grid(GridConfig(ntuple(_ -> N, 3), ntuple(_ -> L, 3)))
sp = SimParams(; dt = 0.005, n_steps = 1)
psi0 = ferro_init(grid, 13, Complex{DTYPE})
ws = make_workspace(;
    grid, atom = Eu151,
    interactions = InteractionParams(Dict(0 => EU_c0, 1 => 0.0)),
    zeeman = ZeemanParams(EU_p_weak, 0.0),
    potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
    sim_params = sp, psi_init = psi0,
    enable_ddi = true, c_dd = 100.0,
    backend = CUDABackend(),
)
dV = prod(grid.config.box_size ./ grid.config.n_points)
ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)

# ------------------------------------------------------------------ env stamp
dev = CUDA.device()
gpu_name = CUDA.name(dev)

# The DEVICE_ATTRIBUTE_MEMORY_CLOCK_RATE × bus-width formula UNDER-reports HBM3
# effective bandwidth on H100 (~2.4 TB/s vs the real 3.35 TB/s). Keep it for
# audit, but drive util_lb from a known-GPU spec when we recognise the card.
mem_clock_khz = CUDA.attribute(dev, CUDA.DEVICE_ATTRIBUTE_MEMORY_CLOCK_RATE)          # kHz
bus_width_bit = CUDA.attribute(dev, CUDA.DEVICE_ATTRIBUTE_GLOBAL_MEMORY_BUS_WIDTH)    # bits
peak_bw_attr_Bps = 2.0 * (mem_clock_khz * 1e3) * (bus_width_bit / 8)                  # bytes/s

function known_peak_bw_Bps(name)
    n = lowercase(name)
    occursin("h200", n) && return 4.8e12
    occursin("h100", n) && return 3.352e12   # SXM5 HBM3 (TSUBAME 4)
    occursin("a100", n) && return 2.039e12
    occursin("5070", n) && return 6.72e11
    return nothing
end
peak_known = known_peak_bw_Bps(gpu_name)
peak_bw_Bps   = peak_known === nothing ? peak_bw_attr_Bps : peak_known
peak_bw_src   = peak_known === nothing ? "device_attr" : "known_gpu_spec"

env = Dict(
    "host"          => gethostname(),
    "gpu"           => gpu_name,
    "driver"        => string(CUDA.driver_version()),
    "runtime"       => string(CUDA.runtime_version()),
    "julia"         => string(VERSION),
    "commit"        => COMMIT,
    "env_class"     => "tsubame_h100_node_q",
    "peak_bw_GBs"       => round(peak_bw_Bps / 1e9; digits = 1),
    "peak_bw_src"       => peak_bw_src,
    "peak_bw_attr_GBs"  => round(peak_bw_attr_Bps / 1e9; digits = 1),
)

# ------------------------------------------------------------------ warmup
for _ in 1:5; split_step!(ws); end
CUDA.synchronize()

# ------------------------------------------------------------------ timers
function timed(f; iters = 50)
    best = Inf
    for _ in 1:iters
        CUDA.synchronize(); t0 = time_ns()
        f()
        CUDA.synchronize(); best = min(best, (time_ns() - t0) / 1e3)  # μs
    end
    best
end

whole_us = timed(() -> split_step!(ws); iters = 50)

n_pts = ntuple(d -> size(ws.state.psi, d), 3)
psi = ws.state.psi
sm  = ws.spin_matrices
bufs = ws.ddi_bufs
zd = SpinorBEC.zeeman_diagonal(SpinorBEC.zeeman_at(ws.zeeman, 0.0), sm, 0.0)

# warm each isolated call
SpinorBEC._compute_and_convolve_ddi!(psi, sm, ws.ddi, bufs, Val(13), 3, n_pts)
SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3)
SpinorBEC.apply_kinetic_step_batched!(psi, ws.batched_kinetic)
SpinorBEC._dispatch_diagonal_step!(ws, Val(3), zd, 0.00125, false, ws.interactions)
CUDA.synchronize()

t_conv = timed(() -> SpinorBEC._compute_and_convolve_ddi!(psi, sm, ws.ddi, bufs, Val(13), 3, n_pts))
t_rot  = timed(() -> SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3))
t_kin  = timed(() -> SpinorBEC.apply_kinetic_step_batched!(psi, ws.batched_kinetic))
t_diag = timed(() -> SpinorBEC._dispatch_diagonal_step!(ws, Val(3), zd, 0.00125, false, ws.interactions))
# spin_mixing (c₁ term) — isolated, exercised with a nonzero c₁ (perf is
# c₁-magnitude-independent). Mutates psi like the other timed kernels.
const SM_C1 = 0.1 * EU_c0
SpinorBEC.apply_spin_mixing_step!(psi, sm, SM_C1, 0.00125, 3)   # warm
CUDA.synchronize()
t_sm   = timed(() -> SpinorBEC.apply_spin_mixing_step!(psi, sm, SM_C1, 0.00125, 3))

# per-kernel isolated-sum (SECONDARY cross-check; best-case, not authoritative)
kernel_sum_us = 2t_conv + 2t_rot + t_kin + 4t_diag

# AUTHORITATIVE gpu_busy_pct: profile M steps, busy = Σ device-activity duration
# over the trace span (captures inter-kernel AND inter-step launch idle). This is
# the same quantity CUDA.jl prints as "GPU was busy for X (Y% of the trace)".
function measure_busy(f, M)
    prof = CUDA.@profile trace = true (for _ in 1:M; f(); end)
    d = prof.device
    (isempty(d.start) || isempty(d.stop)) && return (nothing, nothing, nothing)
    device_us = sum(d.stop .- d.start) * 1e6
    span_us   = (maximum(d.stop) - minimum(d.start)) * 1e6
    (100.0 * device_us / span_us, device_us / M, span_us / M)
end
busy_pct, device_busy_us, span_per_step_us = try
    measure_busy(() -> split_step!(ws), 20)
catch e
    (nothing, nothing, nothing)
end

# per-kernel roofline LOWER BOUND: min traffic = 1 read + 1 write of full spinor field
field_bytes = 2 * prod(n_pts) * 13 * sizeof(Complex{DTYPE})
util_lb(t_us) = 100.0 * (field_bytes / (t_us * 1e-6)) / peak_bw_Bps  # %

kernels = Dict(
    "ddi_convolve_us"  => t_conv,
    "ddi_rotation_us"  => t_rot,
    "kinetic_us"       => t_kin,
    "diagonal_us"      => t_diag,
    "spin_mixing_us"   => t_sm,
    "util_lb_pct" => Dict(
        "ddi_convolve" => util_lb(t_conv),
        "ddi_rotation" => util_lb(t_rot),
        "kinetic"      => util_lb(t_kin),
        "diagonal"     => util_lb(t_diag),
    ),
)

allocs_bytes = CUDA.@allocated split_step!(ws)   # host-side driver allocations for one step

# ------------------------------------------------------------------ CUDA.@profile cross-check
# Authoritative device trace (kernel names + count) — recorded raw for audit.
profile_text = try
    io = IOBuffer()
    prof = CUDA.@profile split_step!(ws)
    show(io, MIME("text/plain"), prof)
    String(take!(io))
catch e
    "PROFILE_FAILED: $e"
end

# ------------------------------------------------------------------ record
record = Dict(
    "ts"        => string(now()),
    "metric_ns" => "gpu_ratchet",
    "workload"  => "eu151_ddi_split_step",
    "N"         => N,
    "dtype"     => string(DTYPE),
    "env"       => env,
    "metrics"   => Dict(
        "gpu_step_us"        => whole_us,
        "gpu_busy_pct"       => busy_pct,             # AUTHORITATIVE (profile trace, 20 steps)
        "gpu_device_busy_us" => device_busy_us,       # device-active time per step (profile)
        "gpu_span_per_step_us" => span_per_step_us,
        "gpu_kernel_sum_us"  => kernel_sum_us,        # secondary: isolated per-kernel best-case sum
        "allocs_bytes"       => allocs_bytes,
        "kernels"            => kernels,
    ),
)

hist = joinpath(@__DIR__, "history.jsonl")
open(hist, "a") do io
    println(io, JSON.json(record))
end

println("="^70)
println("GPU ratchet snapshot  N=$N^3 $DTYPE  $(env["gpu"])  ",
        "peak_bw=$(env["peak_bw_GBs"]) GB/s ($(env["peak_bw_src"]); attr=$(env["peak_bw_attr_GBs"]))")
println("="^70)
@printf("  whole step        %8.1f μs\n", whole_us)
if busy_pct === nothing
    println("  gpu_busy_pct      profile unavailable")
else
    @printf("  gpu_busy_pct      %8.1f %%   (device busy %.1f μs/step; headroom to 100%%: %.1f)\n",
            busy_pct, device_busy_us, 100.0 - busy_pct)
end
@printf("  kernel_sum (2nd)  %8.1f μs   (isolated best-case sum)\n", kernel_sum_us)
@printf("  ddi_convolve      %8.1f μs   (util_lb %.1f%%)\n", t_conv, util_lb(t_conv))
@printf("  ddi_rotation      %8.1f μs   (util_lb %.1f%%)  <-- ×2/step\n", t_rot, util_lb(t_rot))
@printf("  kinetic           %8.1f μs   (util_lb %.1f%%)\n", t_kin, util_lb(t_kin))
@printf("  diagonal          %8.1f μs   (util_lb %.1f%%)  <-- ×4/step\n", t_diag, util_lb(t_diag))
@printf("  spin_mixing       %8.1f μs\n", t_sm)
@printf("  host allocs/step  %8d bytes\n", allocs_bytes)
println("\n--- CUDA.@profile (audit) ---\n", profile_text)
println("\nappended -> $hist")
println("JSON_RECORD ", JSON.json(record))
println("DONE")
