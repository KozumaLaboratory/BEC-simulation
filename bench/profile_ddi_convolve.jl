# Where does the padded DDI convolution's time go on a GPU?
#
# After #183 and #191 it is the largest single item in an ITP step: 0.125 of a
# 0.472 ms step at 32³ per call, twice per step, i.e. ~53 %. The step-level
# breakdown cannot say WHICH of its stages owns that, and the answer decides the
# fix:
#
#   * if the six padded rFFTs are OVERHEAD-bound (each is only ~2 MB at 32³,
#     where cuFFT is launch-dominated) the fix is to batch them into two
#     executions — exact, mechanical;
#   * if they are BANDWIDTH-bound the fix has to reduce the padded VOLUME, which
#     is an accuracy decision about `ddi_pad_factor` and belongs in an
#     ErrorBudget, not in a kernel;
#   * if the k-space contraction dominates, fuse its three broadcasts into one
#     kernel (it currently re-reads the F fields three times).
#
# So this measures the stages separately rather than guessing which story is
# true. Each is timed min-of-N with a sync on both ends.
#
#   julia --project=. bench/profile_ddi_convolve.jl [n] [reps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: _compute_spin_density!, _convolve_ddi_padded!,
    _ddi_padded_k_contraction!, _get_ddi_brfft_plan,
    _compute_and_convolve_ddi_padded!
using LinearAlgebra: mul!

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const REPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 50

function build_ws(n)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=true, save_every=100)
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params=sp, psi_init=psi0,
        enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        backend=CUDABackend(),
    )
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

function tmin(f, reps)
    best = Inf
    for _ in 1:reps
        CUDA.synchronize()
        t0 = time_ns()
        f()
        CUDA.synchronize()
        best = min(best, (time_ns() - t0) * 1e-9)
    end
    best
end

ws = build_ws(N_GRID)
ctx = ws.ddi_padded
sm = ws.spin_matrices
D = sm.system.n_components
n_pts = ws.grid.config.n_points
pad = size(ctx.Phi_x_pad)
rk_shape = size(ctx.Phi_x_pad_rk)
rp = ctx.rfft_plans
bp = _get_ddi_brfft_plan(ctx.Phi_x_pad_rk, pad[1])

# warm every stage
for _ in 1:5
    _compute_and_convolve_ddi_padded!(ws.state.psi, sm, ws.ddi, ctx, Val(D), 3, n_pts)
end

println("="^76)
println("padded DDI convolve, Eu F=6 D=13, n=$(N_GRID)³ → padded $(pad), rk $(rk_shape)")
println("device: $(CUDA.name(CUDA.device()))   reps=$REPS")
println("="^76)

t_all = tmin(
    () -> _compute_and_convolve_ddi_padded!(
        ws.state.psi, sm, ws.ddi, ctx, Val(D), 3, n_pts), REPS)
t_dens = tmin(
    () -> _compute_spin_density!(
        ctx.Fx_pad, ctx.Fy_pad, ctx.Fz_pad, ws.state.psi, sm, Val(D), 3, n_pts), REPS)
t_fwd = tmin(() -> begin
        mul!(ctx.Fx_pad_rk, rp.forward, ctx.Fx_pad)
        mul!(ctx.Fy_pad_rk, rp.forward, ctx.Fy_pad)
        mul!(ctx.Fz_pad_rk, rp.forward, ctx.Fz_pad)
    end, REPS)
t_fwd1 = tmin(() -> mul!(ctx.Fx_pad_rk, rp.forward, ctx.Fx_pad), REPS)
# One fused kernel on the GPU since the contraction fuse; the label used to say
# "3 bcast" and would have quietly misdescribed the arm being measured.
t_contr = tmin(
    () -> _ddi_padded_k_contraction!(ctx, ws.ddi.C_dd / prod(pad)), REPS)
t_bwd = tmin(() -> begin
        mul!(ctx.Phi_x_pad, bp, ctx.Phi_x_pad_rk)
        mul!(ctx.Phi_y_pad, bp, ctx.Phi_y_pad_rk)
        mul!(ctx.Phi_z_pad, bp, ctx.Phi_z_pad_rk)
    end, REPS)
t_bwd1 = tmin(() -> mul!(ctx.Phi_x_pad, bp, ctx.Phi_x_pad_rk), REPS)

parts = [("spin density (1 kernel)", t_dens),
    ("rFFT forward ×3", t_fwd),
    ("k contraction", t_contr),
    ("brFFT backward ×3", t_bwd)]
tot = sum(last, parts)
for (nm, t) in parts
    @printf("  %-26s %8.1f µs   %5.1f%%\n", nm, t * 1e6, 100t / tot)
end
@printf("  %-26s %8.1f µs\n", "Σ stages", tot * 1e6)
@printf("  %-26s %8.1f µs   (whole convolve)\n", "MEASURED", t_all * 1e6)
@printf("  reconcile Σ/measured = %.3f\n", tot / t_all)

# The discriminating numbers. One 64³ R2C moves ~2 MB in + 2.2 MB out; at H100
# HBM bandwidth that is ~1.4 µs. Anything far above it is overhead, and overhead
# is what batching removes.
bytes_fft = (prod(pad) * 8 + prod(rk_shape) * 16)
@printf("\n  single rFFT forward        %8.1f µs   (3× costs %.1f µs)\n",
    t_fwd1 * 1e6, t_fwd * 1e6)
@printf("  single brFFT backward     %8.1f µs   (3× costs %.1f µs)\n",
    t_bwd1 * 1e6, t_bwd * 1e6)
@printf("  one transform moves       %8.2f MB → %.1f µs at 3 TB/s\n",
    bytes_fft / 2^20, bytes_fft / 3e12 * 1e6)
@printf("  ⇒ 3× / 1× ratio: fwd %.2f, bwd %.2f  (1.0 = pure overhead, 3.0 = pure bandwidth)\n",
    t_fwd / t_fwd1, t_bwd / t_bwd1)
