# Can the field condense at the ramp's END conditions, with the ramp removed?
#
# Along the ramp the field does not condense: at the derived gamma it ends with
# N_C = 34 and N_0 = 0.071 against a constraint saying 3498, and at 10x gamma the C
# region fills to 94% of the cloud (2.28e4 of 2.43e4) and still returns N_0 = 7.2.
# Raising gamma cannot buy coherence anyway — the growth noise goes as sqrt(2 gamma T),
# so the fluctuation-dissipation relation ties them and gamma changes only the RATE.
#
# But the machinery does condense when it is allowed to: measured earlier in this arc,
# at fixed mu = 5, T = 2 the solver reached 82% of N_TF and was still rising. So the
# question is not "can it" but "what about the ramp stops it", and the way to separate
# those is to remove the ramp.
#
# Fixed (mu, T, eps_cut) at the ramp's END values, seeded thermal, run long. If N_0 grows
# to the constraint's number, the ramp is what prevents it — a lag, and a real answer. If
# it does not, the failure is at fixed point and has nothing to do with the ramp.
using SpinorBEC, FFTW, Printf
# _n0_tf_projection is defined in the driver, checked against a known TF state in
# D = 1, 3, 13 and in both the first and last component (all 1.00000).
include(joinpath(@__DIR__, "eu_number_conserving.jl"))

const T_END = 2.279
const MU_END = 2.948
const EPS_CUT = 8.34
const C0 = 0.02

k_cut = sqrt(2 * EPS_CUT)
grid = make_grid(GridConfig((44, 44, 44), (10.0, 10.0, 10.0)))
dV = cell_volume(grid)

eq = classical_field_equilibrium(; T=T_END, mu=MU_END, c0=C0,
    n_T=(EPS_CUT - MU_END) / T_END, rmax=5.0)
g = mu_from_total_lda(3563.0; T=T_END, c0=C0, eps_cut=EPS_CUT)
@printf("fixed point: mu=%.4g T=%.4g eps_cut=%.4g k_cut=%.4g\n",
    MU_END, T_END, EPS_CUT, k_cut)
@printf("  classical-field equilibrium at this mu: N0=%.5g  Nth=%.5g\n", eq.N0, eq.Nth)
@printf("  LDA constraint at N_total=3563:          N0=%.5g  Nth_C=%.5g  mu=%.4g\n",
    g.N0, g.Nth_C, g.mu)

sp = SimParams(; dt=0.02, n_steps=1, imaginary_time=false, save_every=1,
    normalize_every=0)
ws = make_workspace(; grid, atom=Eu151,
    interactions=InteractionParams(Dict{Int, Float64}(0 => C0)),
    potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp, fft_flags=FFTW.MEASURE)
hp = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
host = zeros(ComplexF64, size(ws.state.psi))
N_seed = thermal_cfield!(host, grid, hp; T=T_END, mu=MU_END, c0=C0, k_cut, seed=777)
copyto!(ws.state.psi, host)
apply_projected_gp!(ws, k_cut)
@printf("  seeded %.4g -> %.4g in C\n", N_seed, real(sum(abs2, ws.state.psi)) * dV)

res = SPGPEReservoir(; T=T_END, mu=MU_END, a_s=0.007, k_cut, gamma=NaN, M=NaN)
@printf("\n%-10s %-12s %-12s %-8s\n", "t", "N_C", "N_0", "f_0")
for s in 1:200_000
    apply_spgpe_step!(ws, res, 0.02; t=0.0, seed=5_000_000 + s, cayley_iters=2)
    if s % 20_000 == 0
        NC = real(sum(abs2, ws.state.psi)) * dV
        N0 = sum(_n0_tf_projection(ws.state.psi, grid, C0; comp=c)
                 for c in 1:size(ws.state.psi, 4))
        @printf("%-10.1f %-12.5g %-12.5g %-8.4f\n", s * 0.02, NC, N0, N0 / max(NC, 1))
        flush(stdout)
    end
end
@printf("\nN_0 -> the constraint's number => the RAMP is what prevents condensation\n")
@printf("N_0 stays ~0                  => the failure is at fixed point\n")
