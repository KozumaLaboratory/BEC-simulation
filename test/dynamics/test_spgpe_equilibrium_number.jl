using Test
using FFTW
using SpinorBEC

# What atom number does the SPGPE actually equilibrate to, and does the closed
# form used to size runs agree with it?
#
# In a trap at mu = 15, T = 80 the run reaches N = 1.85e4 from BOTH directions —
# growing from vacuum and decaying from a seed of 1.24e5 — while
# classical_field_equilibrium predicts 1.24e5. A factor of 6.7, and one of the
# two is wrong.
#
# The suspect is the cutoff convention. The projector cuts on |k|; the closed
# form cuts on the TOTAL energy k^2/2 + V + 2 c0 n, so its C region is smaller by
# the mean-field shift. Removing the trap makes the Rayleigh-Jeans prediction a
# plain mode sum with no local-density approximation in the way, and lets both
# conventions be evaluated against the same run.
#
# gamma is deliberately far above its physical value here: the EQUILIBRIUM does
# not depend on it, only the time taken to reach it, and the point is to reach it.
@testset "SPGPE equilibrium atom number vs the Rayleigh-Jeans mode sum" begin
    n, L = 48, 10.0
    mu, T, c0 = 15.0, 80.0, 0.19
    k_cut = sqrt(2 * (mu + T))
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    V = prod(grid.config.box_size)
    @test π / (L / n) > k_cut                      # the grid must resolve the cut

    # Prediction in the CODE's convention: occupation T/(eps - mu) per plane-wave
    # mode inside |k| < k_cut, with eps = k^2/2 + 2 c0 n, solved for n.
    function rj_modesum(nguess; iters=200)
        nn = nguess
        for _ in 1:iters
            s = 0.0
            for I in CartesianIndices(grid.config.n_points)
                k2 = grid.k_squared[I]
                k2 <= k_cut^2 || continue
                d = 0.5 * k2 + 2c0 * nn - mu
                d > 0 && (s += T / d)
            end
            nn = 0.5 * nn + 0.5 * (s / V)          # damped
        end
        nn * V
    end
    N_modesum = rj_modesum(50.0)

    # Prediction in the CLOSED FORM's convention: same physics, but the cut is on
    # total energy, so K = sqrt(2 (eps_cut - 2 c0 n)) < k_cut.
    eq = classical_field_equilibrium(; T, mu, c0, omega=0.0, rmax=L / 2, nr=200)
    N_closed = (eq.N0 + eq.Nth) * V / (4π / 3 * (L / 2)^3)   # its r-integral is a ball

    @test N_modesum > 0
    # The cutoff convention was the suspect and it is NOT the culprit: measured
    # 6.59e4 (mode sum, cut on |k|) against 5.91e4 (closed form, cut on total
    # energy), 12% apart, not the factor of 6.7 that has to be explained. So the
    # closed form is sound in the homogeneous limit and whatever is wrong is
    # either the run or the trapped local-density step.
    @test isapprox(N_modesum, N_closed; rtol=0.3)

    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{3}((0.0, 0.0, 0.0)),   # homogeneous
        sim_params=sp, fft_flags=FFTW.ESTIMATE)
    res = SPGPEReservoir(; T, mu, a_s=0.01, k_cut, gamma=0.05, M=0.0,
        allow_unphysical_rates=true)
    fill!(ws.state.psi, 0)
    dV = cell_volume(grid)
    N_hist = Float64[]
    for s in 1:8000                                 # 16 units, 1/(2 gamma mu) = 0.67
        split_step!(ws)
        apply_spgpe_step!(ws, res, 0.002; t=0.0, seed=4200 + s)
        s % 1000 == 0 && push!(N_hist, real(sum(abs2, ws.state.psi)) * dV)
    end

    # Equilibrated: the last two samples agree.
    @test isapprox(N_hist[end], N_hist[end - 1]; rtol=0.1)
    N_run = N_hist[end]

    # The verdict. Whichever prediction the run matches is the right convention,
    # and the other one is what has been sizing the KZ campaign.
    @info "SPGPE equilibrium" N_run N_modesum N_closed ratio_modesum=N_run / N_modesum ratio_closed=N_run /
                                                                                                    N_closed
    @test isapprox(N_run, N_modesum; rtol=0.25)
end
