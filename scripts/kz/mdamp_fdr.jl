# Does the energy-damping reservoir preserve the Rayleigh-Jeans state?
#
# It must. With gamma = 0 the term conserves N to machine precision, so the only
# thing it can do is move atoms BETWEEN modes — and if its noise matches its
# dissipation, the stationary spectrum <|a_k|^2> = T/(eps_k - mu) is untouched.
#
# Measured elsewhere: switching Mbar on drops the equilibrium N to 55% of
# Thomas-Fermi at both gamma = 0.1 and 0.01. That cannot happen if the two
# reservoirs share a stationary distribution, so either the FDR of this term is
# wrong or its kernel is. Separating the two is what this does:
#
#   spectrum drifts away from RJ   -> the noise does not match the dissipation
#   spectrum holds                 -> the equilibrium shift comes from elsewhere
#
# The kernel is the other suspect. eps~(k) = Mbar/|k| is Rooney's THREE-dimensional
# result, where the measure k^2 dk makes int d^3k/|k| infrared-convergent. In 1D
# the measure is dk and int dk/|k| diverges logarithmically, cut off only by the
# box — so the term's strength would depend on L, which is not a property an
# operator should have. Run at two box sizes to see it.
using SpinorBEC, FFTW, Printf, Statistics, Random
mu, T, c0 = 1.0, 1.026, 0.0139
k_cut = sqrt(2 * (mu + T))

function rj_seed!(psi, grid, plans; T, mu, seed)
    n = length(psi)
    buf = zeros(ComplexF64, n)
    rng = MersenneTwister(seed)
    for i in 1:n
        buf[i] = randn(rng) + im * randn(rng)
    end
    plans.forward * buf
    L = grid.config.box_size[1]
    for i in 1:n
        k2 = grid.k_squared[i]
        d = 0.5 * k2 - mu + 2c0 * 0.0
        buf[i] = (k2 > k_cut^2 || d <= 0) ? 0 : buf[i] * sqrt(T / d)
    end
    plans.inverse * buf
    # normalise so the sample carries the RJ number for these modes
    psi .= buf
end

# Occupation per k-mode, |a_k|^2 with a_k the coefficient of the plane-wave basis.
function spectrum(psi, grid, plans)
    b = ComplexF64.(vec(psi))
    plans.forward * b
    L = grid.config.box_size[1]
    n = length(b)
    abs2.(b) .* (L / n^2)
end

for L in (200.0, 800.0)
    n = round(Int, 512 * L / 200)
    grid = make_grid(GridConfig((n,), (L,)))
    plans = make_fft_plans((n,); flags=FFTW.ESTIMATE)
    for Md in (0.0, 0.01, 0.1)
        sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Sr88,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
            potential=HarmonicTrap{1}((0.0,)), sim_params=sp, fft_flags=FFTW.ESTIMATE)
        # mu < 0 keeps every mode thermal, so RJ is exactly the right statement
        res = SPGPEReservoir(; T, mu=-1.0, a_s=c0 / 2, k_cut, gamma=0.0, M=Md,
            allow_unphysical_rates=true)
        psi = view(ws.state.psi, :, 1)
        rj_seed!(psi, grid, plans; T, mu=-1.0, seed=771)
        dV = cell_volume(grid)
        N0 = real(sum(abs2, ws.state.psi)) * dV
        s0 = spectrum(Array(psi), grid, plans)
        for s in 1:20_000
            split_step!(ws)
            apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=61_000 + s)
        end
        N1 = real(sum(abs2, ws.state.psi)) * dV
        s1 = spectrum(Array(psi), grid, plans)
        # compare the low-k half of the C region, where the occupations are large
        idx = [i for i in eachindex(s0) if 0 < grid.k_squared[i] <= (k_cut / 2)^2]
        r = mean(s1[idx]) / mean(s0[idx])
        idx2 = [i for i in eachindex(s0) if (k_cut / 2)^2 < grid.k_squared[i] <= k_cut^2]
        r2 = mean(s1[idx2]) / mean(s0[idx2])
        @printf("L=%5.0f  Mbar=%-6.3g  N: %.6g -> %.6g (%.2e)   low-k x%.3f   high-k x%.3f\n",
            L, Md, N0, N1, (N1 - N0) / N0, r, r2)
        flush(stdout)
    end
end
