# Does the residual scattering loss matter when the GROWTH term is also on?
#
# Every loss measurement so far used gamma = 0, which is not the configuration
# anything is run in. With gamma = 0 the scattering term is the only process and
# nothing replaces what leaks past 2 k_cut; with gamma > 0 the growth term pulls N
# toward the (mu, T) equilibrium continuously, so a steady leak is offset rather
# than integrated. The band-limited equilibrium test already passes at 60
# relaxation times — this asks whether it HOLDS over the 1e5 time units a KZ run
# spans, which is the only duration that matters.
#
# The distinction is between a loss that accumulates and a loss that shifts a
# steady state. The first kills the method; the second is a systematic to quote.
using SpinorBEC, FFTW, Printf, Statistics
mu, T, c0, L, n = 1.0, 1.026, 0.0139, 200.0, 512
k_cut = sqrt(2 * (mu + T))
grid = make_grid(GridConfig((n,), (L,)))
N_TF = mu * L / c0
# Print the md5 of the source under test. A previous run of this script started
# 14 seconds after the file it exercises was rsynced, and which version it loaded
# could not be established afterwards — so the run has to say.
@printf("spgpe.jl md5 = %s\n", readchomp(`md5sum src/solvers/spgpe.jl`))
@printf("N_TF = %.5g   k_cut = %.3f   T = %.3f\n", N_TF, k_cut, T)
@printf("%-8s %-8s %-10s %s\n", "gamma", "Mbar", "t_total", "N/N_TF at t = 1e3, 1e4, 3e4, 1e5")
for γ in (0.1,), Md in (0.0, 0.001, 0.01, 0.1)
    sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Sr88,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
    res = SPGPEReservoir(; T, mu, a_s=c0 / 2, k_cut, gamma=γ, M=Md,
        allow_unphysical_rates=true)
    fill!(ws.state.psi, 0)
    dV = cell_volume(grid)
    marks = [1e3, 1e4, 3e4, 1e5]
    out = Float64[]
    t = 0.0
    for s in 1:round(Int, 1e5 / 0.05)
        split_step!(ws)
        apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=81_000 + s)
        t += 0.05
        if !isempty(marks) && t >= marks[1]
            push!(out, real(sum(abs2, ws.state.psi)) * dV / N_TF)
            popfirst!(marks)
        end
    end
    @printf("%-8.3g %-8.3g %-10.3g %s\n", γ, Md, t,
        join((@sprintf("%.4f", v) for v in out), "  "))
    flush(stdout)
end
