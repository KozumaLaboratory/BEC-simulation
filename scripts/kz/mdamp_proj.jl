# Is the loss the projector, or the energy-damping term itself?
#
# The term multiplies by cis(real(phase)), whose modulus is exactly 1, so it
# cannot change |psi|^2 on its own. But apply_spgpe_step! projects AFTER it, and
# the phase exp(i dU) — dU being white noise coloured only by 1/sqrt(|k|) — is
# rough, so it scatters weight above k_cut for the projector to remove. Additive
# terms do not have this problem: projecting the increment and projecting the
# state are the same thing when the map is linear. A multiplicative one is not.
#
# Measured: with gamma = 0 and Mbar = 0.1, N falls 56.4 -> 1.1e-44 over 20000
# steps of apply_spgpe_step!. The unit test calls apply_energy_damping_step!
# DIRECTLY, with no projector in the path, and sees conservation to 1e-13.
using SpinorBEC, FFTW, Printf, Statistics, Random
mu, T, c0, k_cut = -1.0, 1.026, 0.0139, sqrt(2 * (1.0 + 1.026))
n, L = 512, 200.0
grid = make_grid(GridConfig((n,), (L,)))
plans = make_fft_plans((n,); flags=FFTW.ESTIMATE)

function seeded_ws()
    sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
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
        buf[i] = (grid.k_squared[i] > k_cut^2 || d <= 0) ? 0 : buf[i] * sqrt(T / d)
    end
    plans.inverse * buf
    view(ws.state.psi, :, 1) .= buf
    ws
end

# how much weight does one energy-damping phase push above k_cut?
function above_cut_fraction(ws)
    b = ComplexF64.(vec(view(ws.state.psi, :, 1)))
    plans.forward * b
    tot = sum(abs2, b)
    hi = sum(abs2(b[i]) for i in eachindex(b) if grid.k_squared[i] > k_cut^2)
    hi / tot
end

dV = cell_volume(grid)
@printf("%-34s %-14s %-14s %-10s\n", "path", "N before", "N after", "ratio")
for Md in (0.01, 0.1)
    # (a) the term ALONE, no projector, no split-step
    ws = seeded_ws();
    N0 = real(sum(abs2, ws.state.psi)) * dV
    for s in 1:20_000
        apply_energy_damping_step!(ws, Md, T, 0.05; seed=61_000 + s)
    end
    N1 = real(sum(abs2, ws.state.psi)) * dV
    @printf("Mbar=%-5.3g term alone                 %-14.6g %-14.6g %-10.3g\n",
        Md, N0, N1, N1 / N0)

    # (b) the term followed by the projector, nothing else
    ws = seeded_ws();
    N0 = real(sum(abs2, ws.state.psi)) * dV
    frac = Float64[]
    for s in 1:20_000
        apply_energy_damping_step!(ws, Md, T, 0.05; seed=61_000 + s)
        s <= 5 && push!(frac, above_cut_fraction(ws))
        apply_projected_gp!(ws, k_cut)
    end
    N1 = real(sum(abs2, ws.state.psi)) * dV
    @printf("Mbar=%-5.3g term + projector           %-14.6g %-14.6g %-10.3g\n",
        Md, N0, N1, N1 / N0)
    @printf("           weight above k_cut after one phase: %s\n",
        join((@sprintf("%.4f", f) for f in frac), " "))
    flush(stdout)
end
