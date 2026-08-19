# Is the energy-damping number loss a discretisation error or a defect?
#
# Energy damping is the NUMBER-CONSERVING reservoir — that is its definition and the
# reason it supplies the model E/F coupling in the KZ reproduction. Measured on the euv3
# ramp with energy damping alone, N_C fell 1716 -> 64, 96% gone.
#
# Rooney, Blakie & Bradley (PRE 89, 013302, arXiv:1310.0161) settle what to expect: the
# scattering term is number-conserving ANALYTICALLY and the discretised integration
# introduces a step-size-dependent delta-N, which their Fig. 4 measures against Delta t.
# So the discriminator is dt. If the loss per unit TIME falls as dt shrinks the scheme is
# converging and the step was simply too large; if it is flat, the term is wrong.
#
# Loss per unit time, not per step: a per-step figure falls with dt for free and would
# make any scheme look convergent.
#
# This also re-examines a gate of mine. test_spgpe_projector_composition PINS the
# measured rate 0.00238/step at Mbar = 0.01 — 0.00238 x 1493 steps is the 97% seen — so
# if that loss is a dt artefact the gate has been holding an artefact as specification.
using SpinorBEC, FFTW, Printf
n, L, c0, T = 44, 10.0, 0.02, 7.28
eps_cut = 1.5 + 3T
k_cut = sqrt(2eps_cut)
grid = make_grid(GridConfig((n, n, n), (L, L, L)))
dV = cell_volume(grid)
@printf("44^3 box %.1f  T=%.3g  eps_cut=%.3g  k_cut=%.3g  k_max=%.3g\n",
    L, T, eps_cut, k_cut, π * n / L)
@printf("\n%-9s %-8s %-13s %-13s %-13s %-13s\n",
    "dt", "steps", "N start", "N end", "loss/step", "loss/TIME")
T_TOTAL = 20.0
for dt in (0.02, 0.01, 0.005, 0.002, 0.001)
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        fft_flags=FFTW.ESTIMATE)
    hp = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    host = zeros(ComplexF64, size(ws.state.psi))
    thermal_cfield!(host, grid, hp; T, mu=1.5, c0, k_cut, seed=31337)
    copyto!(ws.state.psi, host)
    # Energy damping ONLY: growth off, so nothing can mask a loss by adding atoms.
    res = SPGPEReservoir(; T, mu=1.5, a_s=0.007, k_cut, gamma=NaN, M=NaN,
        number_damping=false, energy_damping=true)
    N0 = real(sum(abs2, ws.state.psi)) * dV
    steps = round(Int, T_TOTAL / dt)
    for s in 1:steps
        apply_spgpe_step!(ws, res, dt; t=0.0, seed=90000 + s)
    end
    N1 = real(sum(abs2, ws.state.psi)) * dV
    per_step = (N0 - N1) / (N0 * steps)
    @printf("%-9.4g %-8d %-13.6g %-13.6g %-13.4e %-13.4e\n",
        dt, steps, N0, N1, per_step, per_step / dt)
    flush(stdout)
end
@printf("\nloss/TIME flat  => the term is wrong (a defect)\n")
@printf("loss/TIME -> 0  => discretisation, and dt was too large\n")
@printf("\nBEFORE the increment form: 4.5285e-03 4.5288e-03 4.5305e-03 4.5312e-03 4.5303e-03\n")
@printf("  (dt 0.02 -> 0.001, flat to 0.06%% over a factor of 20 — the exponential form)\n")
