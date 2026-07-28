# Magnitude oracle: every tabulated LHY mode, anchored to SI — not to itself.
#
# The closed forms had a CONSISTENCY oracle and no MAGNITUDE oracle.
# `test_lhy_full_bdg_closed_form_parity.jl` asserts
#
#     uniform g_S  ⇒  ε = (8/15π²)(g n)^(5/2)
#
# which is the closed form agreeing with its own algebraic statement. It passes
# whatever the units are. Meanwhile the only SI-anchored check in the tree,
# `test_scalar_lhy_si_roundtrip.jl`, covers the SCALAR path alone.
#
# In that gap the whole tabulated family was **exactly N_atoms too large**:
# `ε = (8/15π²)(g n)^(5/2)` is written for a PHYSICAL density and an SI coupling,
# but here `n = |ψ|²` is normalised to `∫|ψ|²dV = 1` and
# `c₀ = 4π(a_s/a_ho)N` already carries N. Counting N twice inside a 5/2 power is
# not a subtle error: on a 2026-05 ¹⁵¹Eu run it made E_LHY **96% of the total
# energy**, which is impossible for a beyond-mean-field correction — the scalar
# path gives 0.08% for the same state.
#
# The anchor used here is the scalar Lima-Pelster coefficient, which IS tied to
# SI by `μ_LHY/μ_contact = (32/3)√(n_SI a_s³/π)`. In the uniform-g_S limit every
# closed form must reduce to it exactly. That is a statement about MAGNITUDE and
# it is the one the family was missing.

using Test
using SpinorBEC
using SpinorBEC: scalar_lhy_coefficient, _lhy_V, LHYTableOpts

const _F = 6
const _NPTS = 8000          # central-difference table; 4e-7 residual at this size

# Physically sensible (a_s/a_ho, N) triples spanning three decades of N, so the
# check cannot pass by coincidence at one atom number.
const _CASES = ((1_000, 0.02), (30_000, 0.0071127), (100_000, 0.001))

# V_LHY = dε/dn of ε = (2/5)·c_lhy·n^(5/2) is c_lhy·n^(3/2).
_scalar_V(n, a_over_aho, N) = scalar_lhy_coefficient(a_over_aho, N) * n * sqrt(n)

@testset "tabulated LHY magnitude is anchored to SI, not to itself" begin
    n_eval = 0.004

    @testset "uniform g_S ⇒ every closed form == scalar Lima-Pelster" begin
        for (N, ah) in _CASES
            c0 = 4π * ah * N
            g = Dict(S => c0 for S in 0:2:(2_F))
            want = _scalar_V(n_eval, ah, N)
            @test want > 0

            builders = (
                "fm_contact" => compute_spinor_lhy_fm_contact(;
                    F=_F, g_dict=g, n_max=0.05, n_points=_NPTS, n_atoms=N),
                "polar_contact" => compute_spinor_lhy_polar_contact(;
                    F=_F, g_dict=g, n_max=0.05, n_points=_NPTS, n_atoms=N),
            )
            for (label, tbl) in builders
                @testset "$label N=$N" begin
                    @test isapprox(_lhy_V(n_eval, tbl), want; rtol=1e-5)
                end
            end
        end
    end

    @testset "the N-fold error is what this catches" begin
        # Without the 1/N the table is larger by EXACTLY N — measured at
        # 1e3, 3e4, 1e5 before the fix. Pinning the factor makes a regression
        # read as "N too large" rather than as a vague tolerance failure.
        for (N, ah) in _CASES
            c0 = 4π * ah * N
            g = Dict(S => c0 for S in 0:2:(2_F))
            unfixed = compute_spinor_lhy_fm_contact(;
                F=_F, g_dict=g, n_max=0.05, n_points=_NPTS, n_atoms=1)
            fixed = compute_spinor_lhy_fm_contact(;
                F=_F, g_dict=g, n_max=0.05, n_points=_NPTS, n_atoms=N)
            @test isapprox(_lhy_V(n_eval, unfixed) / _lhy_V(n_eval, fixed), N; rtol=1e-9)
        end
    end

    @testset "LHY stays a CORRECTION at a physical gas parameter" begin
        # The blunt sanity check the family never had: a beyond-mean-field term
        # that is most of the energy is not a correction, whatever the algebra
        # says. Before the 1/N it was 96% of the total on a real Eu run.
        #
        # The state has to be a PHYSICAL cloud. `init_psi`'s default is a narrow
        # blob whose peak density is ~37x the converged Eu run's, and E_LHY goes
        # as n^(5/2), so a share measured on it says nothing — it reads 90% even
        # with the fix in. Build a Gaussian at the run's actual peak density
        # (n ~ 3.7e-3, gas parameter n_SI a_s^3 ~ 4e-5) instead.
        N = 30_000
        n_pts, box = (24, 24, 24), (12.0, 12.0, 12.0)
        grid = make_grid(GridConfig(n_pts, box))
        atom = Eu151
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * 628.3))
        c0 = 4π * (atom.a_s / a_ho) * N
        ip = InteractionParams(Dict(0 => c0, 1 => -0.005 * c0))
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true)
        D = 2 * _F + 1

        sigma = 2.58                       # peak = (2π σ²)^(-3/2) ≈ 3.7e-3
        psi = zeros(ComplexF64, n_pts..., D)
        xs = [(i - 1) * box[1] / n_pts[1] - box[1] / 2 for i in 1:n_pts[1]]
        for I in CartesianIndices(n_pts)
            r2 = xs[I[1]]^2 + xs[I[2]]^2 + xs[I[3]]^2
            psi[I, 1] = exp(-r2 / (4 * sigma^2))
        end
        dV = prod(box) / prod(n_pts)
        psi ./= sqrt(sum(abs2, psi) * dV)
        peak = maximum(sum(abs2, psi; dims=4))
        @test 1e-3 < peak < 1e-2           # the regime this claim is about

        # SI prediction AT THE PEAK: μ_LHY/μ_MF = (32/3)√(n_SI a_s³/π).
        # The measured energy ratio is density-weighted over the whole cloud, so
        # it must sit BELOW the peak value but within the same order — that is a
        # physics bound, not a tuned threshold.
        gas_param = N * peak * (atom.a_s / a_ho)^3
        si_peak = (32 / 3) * sqrt(gas_param / π)
        @test 1e-5 < gas_param < 1e-4       # the dilute regime this claim needs

        for kind in (:icosahedral, :polar_contact, :fm_contact)
            ws = make_workspace(; grid, atom, interactions=ip, sim_params=sp,
                psi_init=psi, spinor_lhy=kind, lhy_opts=LHYTableOpts(; n_atoms=N))
            ed = energy_decomposition(ws)
            ratio = abs(ed.lhy) / abs(ed.density)
            @testset "$kind" begin
                @test isfinite(ed.lhy)
                # Percent-level, and a fraction of the peak prediction.
                # Measured: 2.26% (icosahedral / polar_contact), 1.37% (fm),
                # against si_peak = 3.9%. Without the 1/N this was 96% of the
                # TOTAL energy — off the top of this bound by orders.
                @test 0.2 < ratio / si_peak < 1.0
            end
        end
    end
end
