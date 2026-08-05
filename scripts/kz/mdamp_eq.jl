# Does the energy-damping reservoir change the EQUILIBRIUM?
#
# It must not. Both SPGPE reservoir terms satisfy detailed balance with the same
# (mu, T), so the stationary distribution is exp(-(H-mu N)/T) either way and the
# equilibrium atom number cannot depend on Mbar. The term is separately
# number-conserving per step, and that is unit-tested.
#
# But a toroidal run at L = 800 gives N_final = 5.73e4 with number damping alone,
# against the Thomas-Fermi 5.76e4, and 4.45e4 — 77% — with energy damping on. If
# that survives here, the energy-damping noise does not match its dissipation and
# every full-SPGPE result on this branch is measuring a wrong stationary state.
using SpinorBEC, FFTW, Printf, Statistics
n, L, mu, T, c0 = 512, 200.0, 1.0, 1.026, 0.0139
k_cut = sqrt(2 * (mu + T))
grid = make_grid(GridConfig((n,), (L,)))
N_TF = mu * L / c0
@printf("L=%.0f  mu=%.2f  T=%.3f  c0=%.4f  k_cut=%.3f   N_TF=%.4g\n", L, mu, T, c0, k_cut, N_TF)
@printf("%-10s %-8s %-12s %-12s %-10s\n", "gamma", "Mbar", "N_final", "N/N_TF", "drift(last 20%)")
for γ in (0.1, 0.01), Md in (0.0, γ)
    sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=Sr88,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
    res = SPGPEReservoir(; T, mu, a_s=c0 / 2, k_cut, gamma=γ, M=Md,
        allow_unphysical_rates=true)
    fill!(ws.state.psi, 0)
    dV = cell_volume(grid)
    nsteps = round(Int, (200.0 / (γ * mu)) / 0.05)      # 200 relaxation times
    hist = Float64[]
    for s in 1:nsteps
        split_step!(ws)
        apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=31_000 + s)
        s % (nsteps ÷ 20) == 0 && push!(hist, real(sum(abs2, ws.state.psi)) * dV)
    end
    drift = (hist[end] - hist[end - 3]) / hist[end]
    @printf("%-10.3g %-8.3g %-12.5g %-12.4f %-10.4f\n", γ, Md, hist[end], hist[end] / N_TF, drift)
    flush(stdout)
end
