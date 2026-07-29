# Per-kernel breakdown of ONE ITP step, in the exact order `_run_itp_loop!`
# runs them. The RTP bench (`profile_1step.jl`) times `split_step!`, which is a
# DIFFERENT chain: ITP splits the DDI out of V(dt/2) and runs the outer chain
# twice per step (close + reopen), so an RTP profile does not tell you where
# ITP wall-clock goes.
#
# Usage:
#   julia --project=. bench/bench_itp_step.jl [cpu|gpu] [n] [lhy]
# e.g. julia --project=. bench/bench_itp_step.jl gpu 32 polar_contact

using Printf

const BACKEND_ARG = length(ARGS) >= 1 ? ARGS[1] : "cpu"
const N_GRID = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 32
const LHY_ARG = length(ARGS) >= 3 ? ARGS[3] : "none"

if BACKEND_ARG == "gpu"
    import CUDA
end
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

_sync() = BACKEND_ARG == "gpu" ? CUDA.synchronize() : nothing

function build_ws(; n, lhy_kind)
    L = 12.0
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> L, 3)))
    sp = SimParams(; dt = 0.002, n_steps = 1, imaginary_time = true, save_every = 100)
    ip = eu_interaction_params(0.05)
    # A tilted spin-coherent state: every spinor component occupied and all
    # three of ⟨F_x⟩, ⟨F_y⟩, ⟨F_z⟩ nonzero, so no DDI/spin kernel is measured
    # against an accidentally trivial field.
    psi0 = init_psi(grid, SpinSystem(6); state = :spin_coherent,
        init_theta = π / 4, init_phi = 0.3)
    bk = BACKEND_ARG == "gpu" ? CUDABackend() : CPUBackend()
    ws = make_workspace(;
        grid, atom = Eu151, interactions = ip,
        zeeman = ZeemanParams(EU_p_weak, 0.0),
        potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params = sp, psi_init = psi0,
        enable_ddi = true, c_dd = EU_c_dd,
        ddi_padding = true, ddi_trunc_radius = -1.0,
        spinor_lhy = lhy_kind == "none" ? nothing : Symbol(lhy_kind),
        backend = bk,
    )
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

"""Minimum-of-`reps` wall time (seconds) for `f`, synced on both ends."""
function tmin(f, reps)
    best = Inf
    for _ in 1:reps
        _sync()
        t0 = time_ns()
        f()
        _sync()
        best = min(best, (time_ns() - t0) * 1e-9)
    end
    best
end

function report(label; n, lhy_kind, reps = 30)
    ws = build_ws(; n, lhy_kind)
    dt = ws.sim_params.dt
    ndim = 3
    ncomp = ws.spin_matrices.system.n_components
    it = true
    omega = ws.sim_params.rotating_frame_omega

    # warm up every kernel
    for _ in 1:3
        SpinorBEC._outer_potential_fwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC._ddi_step!(ws, dt / 2, ndim, it)
        SpinorBEC._outer_potential_bwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC.apply_step!(SpinorBEC.CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws)
        SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws)
        SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, ncomp, ndim)
        total_energy(ws)
    end

    println("\n" * "="^72)
    println("ITP kernel breakdown: $label  (n=$(n)³, D=$(ncomp), lhy=$(lhy_kind), " *
            "$(BACKEND_ARG), threads=$(Threads.nthreads()))")
    println("="^72)

    t_fwd = tmin(() -> SpinorBEC._outer_potential_fwd!(ws, dt / 4, ncomp, ndim, it), reps)
    t_bwd = tmin(() -> SpinorBEC._outer_potential_bwd!(ws, dt / 4, ncomp, ndim, it), reps)
    t_ddi = tmin(() -> SpinorBEC._ddi_step!(ws, dt / 2, ndim, it), reps)
    t_kin = tmin(() -> SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws), reps)
    t_nrm = tmin(() -> SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, ncomp, ndim), reps)
    t_en = tmin(() -> total_energy(ws), reps)

    # A full ITP step = 2×(fwd + ddi + bwd) + kinetic (+ normalize at cadence).
    step_body = () -> begin
        SpinorBEC._outer_potential_fwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC._ddi_step!(ws, dt / 2, ndim, it)
        SpinorBEC._outer_potential_bwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws)
        SpinorBEC._outer_potential_fwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC._ddi_step!(ws, dt / 2, ndim, it)
        SpinorBEC._outer_potential_bwd!(ws, dt / 4, ncomp, ndim, it)
        SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, ncomp, ndim)
    end
    t_step = tmin(step_body, reps)

    # Host allocation per step — the crop/memset defects show up here even when
    # the wall-clock is dominated by FFTs.
    step_body()
    alloc_step = @allocated step_body()
    alloc_ddi = @allocated SpinorBEC._ddi_step!(ws, dt / 2, ndim, it)

    parts = [
        ("outer_fwd(dt/4)  ×2", 2t_fwd),
        ("outer_bwd(dt/4)  ×2", 2t_bwd),
        ("ddi(dt/2)        ×2", 2t_ddi),
        ("kinetic(dt)      ×1", t_kin),
        ("normalize        ×1", t_nrm),
    ]
    total_parts = sum(last, parts)
    for (nm, t) in parts
        @printf("  %-22s %9.3f ms   %5.1f%%\n", nm, t * 1e3, 100t / total_parts)
    end
    @printf("  %-22s %9.3f ms\n", "Σ parts", total_parts * 1e3)
    @printf("  %-22s %9.3f ms   (measured full body)\n", "STEP", t_step * 1e3)
    @printf("  %-22s %9.3f ms   (observation cadence only)\n", "total_energy", t_en * 1e3)
    @printf("  reconcile: Σparts/STEP = %.3f\n", total_parts / t_step)
    @printf("  host alloc: %.3f MB/step   (%.3f MB per ddi call)\n",
        alloc_step / 2^20, alloc_ddi / 2^20)
    (; label, n, t_step, t_fwd, t_bwd, t_ddi, t_kin, t_nrm, t_en, alloc_step)
end

report("eu-prod"; n = N_GRID, lhy_kind = LHY_ARG)
