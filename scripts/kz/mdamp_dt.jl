# How large is the projected-scheme number loss, as a function of dt and Mbar?
#
# Number conservation under P{i psi dU} is only approximate — Rooney, Blakie &
# Bradley PRE 89 013302 say so — because the product of two band-limited fields
# reaches 2 k_cut. Band-limiting the kernel and the noise to C cut the loss 600x
# (4000 steps at Mbar = 0.1: 1.7e-5 of the field left, now 1.04e-2), but it is not
# zero and cannot be made zero by choosing a scheme.
#
# So the question is quantitative and has to be answered with numbers rather than
# hope: at what (dt, Mbar) is the loss small over the DURATION A KZ RUN ACTUALLY
# TAKES? Loss per step goes as the phase variance, hence as dt; steps go as 1/dt;
# so to leading order loss per unit TIME is dt-independent and only a
# higher-order remainder improves. Measure the exponent rather than assume it.
using SpinorBEC, FFTW, Printf, Statistics, Random
mu, T, c0 = -1.0, 1.026, 0.0139
k_cut = sqrt(2 * (1.0 + T))
n, L = 512, 200.0
grid = make_grid(GridConfig((n,), (L,)))
plans = make_fft_plans((n,); flags=FFTW.ESTIMATE)

function seeded_ws(dt)
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Sr88,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
    buf = zeros(ComplexF64, n)
    rng = MersenneTwister(771)
    for i in 1:n
        buf[i] = randn(rng) + im * randn(rng)
    end
    plans.forward * buf
    for i in 1:n
        d = 0.5 * grid.k_squared[i] - mu
        buf[i] = grid.k_squared[i] > k_cut^2 ? 0 : buf[i] * sqrt(T / d)
    end
    plans.inverse * buf
    view(ws.state.psi, :, 1) .= buf
    ws
end

# Loss per unit TIME, measured over a fixed elapsed time rather than a fixed
# step count — that is the comparison that matters when dt varies.
t_run = 200.0
@printf("%-8s %-8s %-8s %-12s %-14s %-12s\n",
    "Mbar", "dt", "steps", "N/N0", "loss/time", "phi_rms")
for Md in (0.1, 0.01, 0.001), dt in (0.05, 0.01, 0.002)
    ws = seeded_ws(dt)
    res = SPGPEReservoir(; T, mu, a_s=c0 / 2, k_cut, gamma=0.0, M=Md,
        allow_unphysical_rates=true)
    dV = cell_volume(grid)
    N0 = real(sum(abs2, ws.state.psi)) * dV
    ns = round(Int, t_run / dt)
    # phase amplitude for one step, for scale
    ψ0 = copy(Array(view(ws.state.psi, :, 1)))
    apply_spgpe_step!(ws, res, dt; t=0.0, seed=1)
    ψ1 = Array(view(ws.state.psi, :, 1))
    φ = std(angle.(ψ1 ./ (ψ0 .+ eps())))
    for s in 2:ns
        apply_spgpe_step!(ws, res, dt; t=0.0, seed=61_000 + s)
    end
    N1 = real(sum(abs2, ws.state.psi)) * dV
    r = N1 / N0
    @printf("%-8.3g %-8.3g %-8d %-12.5g %-14.4g %-12.3g\n",
        Md, dt, ns, r, -log(max(r, 1e-300)) / t_run, φ)
    flush(stdout)
end
