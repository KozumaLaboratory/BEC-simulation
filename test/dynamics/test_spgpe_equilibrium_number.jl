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
# THE FIXTURE IS INTENSIVE, WHICH IS WHY IT COULD BE SHRUNK (#305).
#
# Every assertion below is on a RATIO — N/N_TF, N/N_rj — and the physics is set
# by (mu, T, c0), which are a chemical potential, a temperature and a coupling,
# none of them extensive. The only constraint tying n to L is that the grid must
# resolve the cut, `pi*n/L > k_cut`, so n and L shrink TOGETHER at fixed n/L and
# the work falls as n^3.
#
# That is an argument, and an argument is not evidence, so it was run at three
# fixtures before being changed (2026-08-22, 10-core box):
#
#   n=48 L=10.0    N/N_TF = 1.9104 / 0.8760 / 0.9598   N/N_rj = 2.2873   1032 s
#   n=32 L=6.5     N/N_TF = 1.8931 / 0.8842 / 0.9606   N/N_rj = 2.2639    174 s
#   n=24 L=5.0     N/N_TF = 1.8858 / 0.8687 / 0.9525   N/N_rj = 2.2592     80 s
#
# All four ratios agree to within 1.3 % across an 8x range in box volume, and the
# `condensed` selector is false/true/true in all three. n=32 was taken rather
# than n=24 because its deviations are the smaller (<= 1.0 %) and because the
# Rayleigh-Jeans prediction is a MODE SUM: shrinking the box thins the C-region
# mode sphere, and this file's whole subject is a discrepancy against that sum.
#
# WHY `steps` WAS NOT ALSO CUT. The N(step) traces say it would break the test:
# at c0 = 0.002 the run is still climbing 3 % between step 6000 and step 8000 at
# every fixture. 8000 is not generous, it is barely enough, and the `settled`
# check passes on a 10 % tolerance rather than on a plateau.
#
# Cost on the CI runner: this file was 2432 s (run 32300172779), 23 % of the
# whole `full` tier and the single file that made its makespan unschedulable
# (#304). At 5.9x it is ~410 s.
@testset "SPGPE equilibrium atom number vs the Rayleigh-Jeans mode sum" begin
    n, L = 32, 6.5
    # THE SPIN COUNT, and it is the whole of the discrepancy this file was
    # written about. The field has D = 2F+1 components; the mode sums below run
    # over SPATIAL modes only, so each k carries D of them. Omitting D made the
    # predictor low by up to a factor of D and produced the "factor of 6.7" in
    # the header. Measured at c0 = 0 exactly, where Rayleigh-Jeans is exact and
    # has no self-consistency: N_run/N_analytic = 3.0055 for this D = 3 atom,
    # and D x N_analytic matched the run to 0.18 % (#305, 2026-08-22).
    D = 2 * Int(Rb87.F) + 1
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
            # NO D HERE, deliberately, and it is not an oversight. This sum
            # exists only to be compared against `classical_field_equilibrium`,
            # which is a SCALAR closed form — it carries no spin index anywhere.
            # Comparing a D-counted sum against it would be comparing two
            # different quantities. `rj_at` below IS compared against the run and
            # does carry D.
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
    # FLAGGED, not asserted: `classical_field_equilibrium` is spin-blind, and its
    # docstring says the same numbers "size the run". If it is used to size a
    # SPINOR run it is low by D = 2F+1 — the very factor #305 found missing here.
    # Not audited: this file does not know that function's callers. See #305.

    # The verdict, as a function of interaction strength. The SPGPE's exact
    # stationary distribution is P ∝ exp(−(H−μN)/T), the FULL interacting
    # classical-field measure; T/(ϵ_k−μ) is only its Hartree–Fock approximation
    # and becomes exact as c₀ → 0. So run the same box at three couplings: if the
    # ratio goes to 1 with c₀ the code is right and the closed form is merely
    # approximate, and if it does not the code is wrong.
    #
    # At the KZ parameters (c₀ = 0.19, c₀n = 28.6 against T = 80) the run sits
    # 2.29× above the mode sum, which is either a real 2.3× error or Hartree–Fock
    # failing at an interaction it has no right to describe.
    function run_equilibrium(c0_run; steps=8000, seed0=4200)
        sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}(0 => c0_run)),
            potential=HarmonicTrap{3}((0.0, 0.0, 0.0)),   # homogeneous
            sim_params=sp, fft_flags=FFTW.ESTIMATE)
        res = SPGPEReservoir(; T, mu, a_s=0.01, k_cut, gamma=0.05, M=0.0,
            allow_unphysical_rates=true)
        fill!(ws.state.psi, 0)
        dV = cell_volume(grid)
        N_hist = Float64[]
        for s in 1:steps
            split_step!(ws)
            apply_spgpe_step!(ws, res, 0.002; t=0.0, seed=seed0 + s)
            s % 1000 == 0 && push!(N_hist, real(sum(abs2, ws.state.psi)) * dV)
        end
        (; N=N_hist[end], settled=isapprox(N_hist[end], N_hist[end - 1]; rtol=0.1))
    end

    # Hartree–Fock prediction at the same coupling, in the code's convention.
    # Rayleigh-Jeans is the THERMAL prediction and only applies while there is
    # no condensate. Returns NaN + condensed=true otherwise rather than a number
    # that silently omits the largest term.
    function rj_at(c0_run)
        nn = 50.0
        for _ in 1:400
            s = 0.0
            for I in CartesianIndices(grid.config.n_points)
                k2 = grid.k_squared[I]
                k2 <= k_cut^2 || continue
                d = 0.5 * k2 + 2c0_run * nn - mu
                # `d <= 0` is NOT an absent mode to skip. It means mu sits above
                # the Hartree-Fock floor, which is a CONDENSATE — and skipping it
                # made this predictor report 2.2e5 where the run held 7.2e6, then
                # the run was blamed for the difference. Signal it.
                d > 0 || return (; N=NaN, condensed=true)
                s += T / d
            end
            nn = 0.5 * nn + 0.5 * (D * s / V)
        end
        (; N=nn * V, condensed=false)
    end

    # Weak coupling at mu = 15 is deeply CONDENSED, so the Thomas-Fermi number
    # mu*V/c0 is the prediction there and Rayleigh-Jeans does not apply at all.
    # That is the whole lesson: at c0 = 0.002 the run holds 7.2e6 against a
    # Thomas-Fermi 7.5e6, 4% low, while the thermal-only predictor said 2.2e5 —
    # and the 33x was charged to the code.
    #
    # `condensed` is the SELECTOR for which prediction applies, not a property all
    # three cells have. It used to be asserted of all three ("all three are
    # condensed") and c0 = 0.19 does not satisfy it: raising c0 lifts
    # d = k^2/2 + 2 c0 n - mu through the mean-field shift, so the d <= 0
    # condensate signal never fires there. That cell is the LEAST condensed of the
    # three, which is also why it is the one far from Thomas-Fermi.
    for c0_run in (0.19, 0.02, 0.002)
        r = run_equilibrium(c0_run)
        @test r.settled
        rj = rj_at(c0_run)
        N_TF = mu * V / c0_run
        @info "equilibrium" c0_run N_run=r.N N_TF ratio_TF=r.N / N_TF rj_applies=!rj.condensed N_rj=rj.N

        if rj.condensed
            # mu above the Hartree-Fock floor: the thermal-only sum does not
            # apply and Thomas-Fermi is what to check. Measured 0.884 (c0 = 0.02)
            # and 0.961 (c0 = 0.002) at this fixture, so 0.15 is the tolerance
            # the data supports. It was rtol = 1.0, which admits anything inside
            # a factor of two and passed the 1.89 below without objecting.
            @test r.N≈N_TF rtol=0.15
        else
            # RESOLVED 2026-08-22 (#305), and it was the PREDICTOR. Two things,
            # measured in this order:
            #
            # 1. THE SPIN COUNT. At c0 = 0 exactly, Rayleigh-Jeans is exact —
            #    independent Gaussians, no self-consistency, no approximation —
            #    and the run came back 3.0055x the sum. D = 3 for Rb87, and the
            #    sums here run over SPATIAL modes only. With the D above they
            #    agree to 0.18 % in that limit.
            #
            # 2. WHAT IS LEFT IS HARTREE-FOCK'S OWN ERROR, and it behaves the way
            #    an approximation must — it vanishes with the coupling:
            #
            #      c0n/T   0.355  0.206  0.116  0.054  0.029  0.016   ->  0
            #      N/N_rj  1.162  1.145  1.119  1.085  1.077  1.049   -> 1.002
            #
            #    So the 2.29x in the header was one factor of the missing D
            #    partly cancelled by HF error, and "one of the two is wrong" has
            #    the answer: the predictor was, and the code was not.
            #
            # rtol = 0.20 admits the 1.162 this cell measures. It is NOT a
            # fitted tolerance: the number it has to admit is HF's error at
            # c0n/T = 0.355, and the row above shows that error going to zero
            # along the axis that controls it. A tighter bound here would be
            # asserting that Hartree-Fock is better than it is.
            #
            # WHAT THE FIXTURE SCAN DID SETTLE (2026-08-22, #305): the ratio is
            # not a finite-size or mode-count artifact. It is 2.2873 at n=48
            # L=10.0, 2.2639 at n=32 L=6.5 and 2.2592 at n=24 L=5.0 — three box
            # volumes spanning 8x, agreeing to 1.2 %. Together with the cutoff
            # convention, already excluded above at 12 % against a factor of 6.7,
            # that leaves the two candidates the header names: a real error, or
            # Hartree-Fock failing at c0*n = 28.6 against T = 80, an interaction
            # it has no right to describe. Discriminating them needs a cell that
            # is BOTH uncondensed and weakly interacting, and lowering c0 at
            # fixed mu condenses the gas instead — which is why the three-coupling
            # scan this file already runs cannot separate them.
            #
            @test r.N≈rj.N rtol=0.20
        end
    end
end
