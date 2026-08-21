# Where inside a 48^3 D=13 DDI step does the 460 ms go? Proposals before this
# measurement would be guesses; today's extrapolation was 10x wrong.
using SpinorBEC, FFTW, Printf
bench(f, n) = (f(); t0 = time(); for _ in 1:n; f(); end; (time() - t0) / n * 1e3)
n, box = 48, 12.0
grid = make_grid(GridConfig((n, n, n), (box, box, box)))
D = SpinSystem(6).n_components
sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
ws = make_workspace(; grid, atom=Eu151,
    interactions=InteractionParams(Dict{Int, Float64}(0 => 0.02, 1 => -1e-4)),
    potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
    fft_flags=FFTW.MEASURE, enable_ddi=true, c_dd=0.1)
for c in 1:D
    view(ws.state.psi, :, :, :, c) .= 0.1 + 0.01im
end
res = SPGPEReservoir(; T=1.0, mu=2.0, a_s=0.007, k_cut=sqrt(2*2.0), gamma=0.1, M=0.1,
    allow_unphysical_rates=true)
N = 12
@printf("%-40s %10s\n", "piece", "ms/call")
@printf("%-40s %10.2f\n", "split_step! (all of it)", bench(() -> split_step!(ws), N))
@printf("%-40s %10.2f\n", "apply_spgpe_step! (all)", bench(() -> apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=1), N))
@printf("%-40s %10.2f\n", "  apply_projected_gp! alone", bench(() -> apply_projected_gp!(ws, sqrt(2*2.0)), N))
@printf("%-40s %10.2f\n", "  apply_energy_damping_step! alone", bench(() -> apply_energy_damping_step!(ws, 0.1, 1.0, 0.05; seed=1, k_cut=sqrt(2*2.0)), N))
@printf("%-40s %10.2f\n", "apply_ddi_step! alone", bench(() -> apply_ddi_step!(ws, 0.05), N))
@printf("%-40s %10.2f\n", "apply_kinetic_step_batched! alone", bench(() -> apply_kinetic_step_batched!(ws, 0.05), N))
b = zeros(ComplexF64, n, n, n); pl = make_fft_plans((n, n, n); flags=FFTW.MEASURE)
t1 = bench(() -> pl.forward * b, 200)
@printf("%-40s %10.4f  (x%d comps = %.1f ms)\n", "ONE 48^3 FFT", t1, D, t1 * D)
@printf("\nimplied FFT count per full step: %.0f\n", (460.0) / t1)
