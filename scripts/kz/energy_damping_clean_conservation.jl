# Does energy damping lose number PER STEP, with the confounds removed?
#
# Every earlier measurement in this arc had one of two confounds, and both made a
# one-time loss look like a rate.
#
#   The SEED was not in C. thermal_cfield! low-passes at k_cut and then multiplies by
#   the density envelope in REAL space, which broadens the spectrum past the cutoff. The
#   first projection removes that, once. The signature is unmistakable in the dt scan:
#   N_end was 664.759 / 664.762 / 664.729 / 664.743 for 1000 / 2000 / 4000 / 10000 steps
#   — four digits identical across a factor of ten in step count. A per-step process
#   cannot do that. "Loss per unit TIME" was a constant divided by a constant, and I read
#   its flatness as proof the term was wrong.
#
#   The CUTOFF tracked. On the euv3 ramp eps_cut falls with T, so k_cut goes 6.83 -> 4.08
#   and the C region shrinks. A shrinking C region must shed atoms to I — the reservoir
#   conserves C+I, not N_C. The 1716 -> 64 may be that, and not a defect at all.
#
# So: fixed cutoff, and a seed projected into C before the clock starts. Then N is
# allowed to change only by the term itself.
using SpinorBEC, FFTW, Printf
n, L, c0, T = 48, 12.0, 0.05, 6.0
eps_cut = 1.5 + 3T
k_cut = sqrt(2eps_cut)
grid = make_grid(GridConfig((n, n, n), (L, L, L)))
dV = cell_volume(grid)
@printf("48^3 box %.1f  k_cut %.3g  k_max %.3g (%.2fx)  FIXED cutoff\n",
    L, k_cut, π * n / L, π * n / L / k_cut)

function build(dt)
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        fft_flags=FFTW.ESTIMATE)
    hp = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    h = zeros(ComplexF64, size(ws.state.psi))
    thermal_cfield!(h, grid, hp; T, mu=1.5, c0, k_cut, seed=515)
    copyto!(ws.state.psi, h)
    # INTO C before the clock starts, so the one-time loss is not counted as a rate.
    apply_projected_gp!(ws, k_cut)
    ws
end
N_of(w) = real(sum(abs2, w.state.psi)) * dV

@printf("\n%-7s %-8s %-8s %-13s %-13s %-13s %-12s\n",
    "form", "dt", "steps", "N after proj", "N end", "loss/step", "loss/TIME")
for (label, iters) in (("expo", 0), ("cayley", 2))
    for dt in (0.02, 0.005)
        w = build(dt)
        N0 = N_of(w)
        steps = round(Int, 20.0 / dt)
        for s in 1:steps
            apply_energy_damping_step!(w, 0.05, T, dt; seed=7000 + s, noise=false,
                k_cut, cayley_iters=iters)
            apply_projected_gp!(w, k_cut)
        end
        N1 = N_of(w)
        @printf("%-7s %-8.4g %-8d %-13.7g %-13.7g %-13.4e %-12.4e\n",
            label, dt, steps, N0, N1, (N0 - N1) / (N0 * steps), (N0 - N1) / (N0 * 20.0))
        flush(stdout)
    end
end
@printf("\nN end differing with step count => a real per-step process\n")
@printf("N end identical across step count => one-time, and there is nothing to fix\n")
