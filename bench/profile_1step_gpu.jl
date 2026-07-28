# GPU profile of ONE split_step! for Eu F=6 + DDI (TSUBAME H100 production path).
# Per-kernel breakdown via CUDA.@profile + whole-step wall via CUDA.@sync.
#
#   julia --project=. bench/profile_1step_gpu.jl [N] [dtype]
#   N      grid size per dim (default 128)
#   dtype  f64 | f32 (default f64)

import CUDA
using SpinorBEC
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const N      = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 128
const DTYPE  = length(ARGS) >= 2 && lowercase(ARGS[2]) == "f32" ? Float32 : Float64

println("="^70)
println("GPU split_step profile — Eu F=6 + DDI")
println("  N=$N^3, dtype=$DTYPE, device=", CUDA.name(CUDA.device()))
println("="^70)

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

println("\nGPU free/total: ",
    round(CUDA.available_memory() / 2^30; digits=1), "/",
    round(CUDA.total_memory() / 2^30; digits=1), " GiB")
flush(stdout)

# --- Warmup (JIT all kernels) ---
println("Warmup…"); flush(stdout)
for _ in 1:5; split_step!(ws); end
CUDA.synchronize()

# --- Whole-step wall time (min over many) ---
function timed(ws, iters)
    best = Inf
    for _ in 1:iters
        CUDA.synchronize()
        t0 = time_ns()
        split_step!(ws)
        CUDA.synchronize()
        best = min(best, (time_ns() - t0) / 1e3)  # μs
    end
    best
end
whole = timed(ws, 50)
@printf("\nWHOLE split_step!: min %.1f μs/step  (%.2f ms)\n", whole, whole/1e3)
flush(stdout)

# --- Per-kernel breakdown via CUDA.@sync timing of each sub-step ---
function gtime(f; iters=40)
    best = Inf
    for _ in 1:iters
        CUDA.synchronize(); t0 = time_ns()
        f()
        CUDA.synchronize(); best = min(best, (time_ns() - t0) / 1e3)
    end
    best
end

n_pts = ntuple(d -> size(ws.state.psi, d), 3)
psi = ws.state.psi
sm = ws.spin_matrices
bufs = ws.ddi_bufs
zd = SpinorBEC.zeeman_diagonal(SpinorBEC.zeeman_at(ws.zeeman, 0.0), sm, 0.0)

# warm each isolated call
SpinorBEC._compute_and_convolve_ddi!(psi, sm, ws.ddi, bufs, Val(13), 3, n_pts)
SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3)
SpinorBEC.apply_kinetic_step_batched!(psi, ws.batched_kinetic)
SpinorBEC._dispatch_diagonal_step!(ws, Val(3), zd, 0.00125, false, ws.interactions)
CUDA.synchronize()

t_conv = gtime(() -> SpinorBEC._compute_and_convolve_ddi!(psi, sm, ws.ddi, bufs, Val(13), 3, n_pts))
t_rot  = gtime(() -> SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3))
t_kin  = gtime(() -> SpinorBEC.apply_kinetic_step_batched!(psi, ws.batched_kinetic))
t_diag = gtime(() -> SpinorBEC._dispatch_diagonal_step!(ws, Val(3), zd, 0.00125, false, ws.interactions))

# Report which DDI-rotation path the production config selects.
let Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)
    pm = sqrt(maximum(bufs.Phi_x.^2 .+ bufs.Phi_y.^2 .+ bufs.Phi_z.^2))
    R = 0.0025 * pm * Float64(sm.system.F)
    K = Ext._taylor_degree(R, 1e-13)
    use0 = Ext._SPIN_TAYLOR_ENABLED[]
    rmax0 = Ext._SPIN_TAYLOR_RMAX[]
    @printf("\nDDI rotation: R = dt·max|Φ|·F = %.4f  ->  production default = %s\n", R,
        use0 && R <= rmax0 ? "Taylor K=$K" : "Euler")
    # Force Taylor (raise RMAX) so we time it regardless of this config's R.
    Ext._SPIN_TAYLOR_RMAX[] = Inf
    Ext._SPIN_TAYLOR_ENABLED[] = true
    t_rot_tay = gtime(() -> SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3))
    Ext._SPIN_TAYLOR_ENABLED[] = false
    t_rot_eul = gtime(() -> SpinorBEC._apply_ddi_rotation!(psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, 0.0025, 3))
    Ext._SPIN_TAYLOR_RMAX[] = rmax0
    Ext._SPIN_TAYLOR_ENABLED[] = use0          # restore the real default
    @printf("  ddi_rotation  Taylor(K=%d) %8.1f μs   Euler %8.1f μs   (Euler/Taylor=%.2fx)\n",
        K, t_rot_tay, t_rot_eul, t_rot_eul / t_rot_tay)
end

println("\n=== Per-kernel min (μs), isolated CUDA.@sync ===")
@printf("  ddi_convolve   %8.1f\n", t_conv)
@printf("  ddi_rotation   %8.1f   <-- (×2/step)\n", t_rot)
@printf("  kinetic        %8.1f   <-- (×1/step)\n", t_kin)
@printf("  diagonal       %8.1f   <-- (×4/step)\n", t_diag)
@printf("  rough step est %8.1f  (2·conv + 2·rot + kin + 4·diag)\n",
        2t_conv + 2t_rot + t_kin + 4t_diag)
flush(stdout)

# --- Device kernel trace (names + times) ---
println("\n=== CUDA.@profile (one step) ===")
prof = CUDA.@profile split_step!(ws)
show(stdout, MIME("text/plain"), prof)
println("\nDONE")
