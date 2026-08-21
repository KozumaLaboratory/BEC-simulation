using Test
using FFTW
using LinearAlgebra
using Printf
using Random
using SpinorBEC

# Full SPGPE — growth (number-damping) + scattering (energy-damping) reservoirs.
# Rooney, Blakie & Bradley PRA 86, 053634 (2012); eq. numbers below are theirs.
#
# The gates, in order of how much they can catch:
#
#  A. Reservoir coefficients reproduce the paper's own published numbers
#     (γ̄, ℳ̄) ≈ (1.5, 2.7)×10⁻⁴ for their Rb-87 example  — verification type C,
#     the only check that pins the PREFACTORS rather than the structure.
#  B. ∇·j = Σ_c Im(ψ_c*∇²ψ_c) equals the divergence of the independently-coded
#     `probability_current` — the identity the cheap kernel rests on.
#  C. Energy damping conserves atom number to MACHINE PRECISION (it is a real
#     phase). Number-conserving is the defining property of the scattering
#     reservoir, so this is a bit-level gate, not a tolerance.
#  D. Quiet energy damping decreases E_C monotonically, at the analytic rate of
#     Eq. (29). Sign oracle: the wrong sign would heat.
#  E. Energy damping is inert on a stationary state (∇·j = 0) and non-zero on a
#     flowing one — the directional test that it is coupled to the current at all.
#  F. Quiet number damping relaxes N_C toward the reservoir μ, with the sign of
#     dN_C/dt set by sign(μ − μ̃), Eq. (23).
#  G. A ramped reservoir actually moves the rates (the s-scale evaporation lever).

const SQRT_EPS = sqrt(eps(Float64))

# --- helpers ---------------------------------------------------------------

function scalar_ws(; n=(32, 32, 32), box=(18.0, 18.0, 18.0), c0=20.0, dt=0.002, psi=nothing)
    grid = make_grid(GridConfig(n, box))
    ip = InteractionParams(Dict{Int, Float64}(0 => c0))
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87, interactions=ip,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        fft_flags=FFTW.ESTIMATE)
    psi === nothing || copyto!(ws.state.psi, psi)
    ws
end

norm_sq(ws) = real(sum(abs2, ws.state.psi)) * cell_volume(ws.grid)

# Drifting + breathing Gaussian: carries real compressible flow (∇·j ≠ 0) while
# staying BAND-LIMITED and decayed to ~1e-8 at the box edge. Both matter — the reference
# ∇·j differentiates the product j = ψ*∇ψ, whose spectrum is twice as wide as ψ's,
# so a state with structure near k_max aliases the reference (not the kernel).
# The decay matters more: the kernel takes a SECOND derivative, so any
# discontinuity across the periodic boundary is amplified by k² and the gap GROWS
# with resolution instead of shrinking.
function flowing_state!(ws; k0=0.5, curv=0.08, w=1.5, amp=1.0)
    grid = ws.grid
    D = ws.spin_matrices.system.n_components
    psi = zeros(ComplexF64, grid.config.n_points..., D)
    for I in CartesianIndices(grid.config.n_points)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2 + z^2
        ph = k0 * x + curv * r2          # drift + radial breathing ⇒ ∇·j ≠ 0
        psi[I, D] = amp * exp(-r2 / (2w^2)) * cis(ph)
    end
    copyto!(ws.state.psi, psi)
    ws
end

# ∇·j computed the long way: build j with `probability_current`, take its
# spectral divergence. Independent of the Laplacian identity under test.
function divj_reference(ws)
    grid = ws.grid
    n_pts = grid.config.n_points
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    j = probability_current(Array(ws.state.psi), grid, plans)
    out = zeros(Float64, n_pts)
    tmp = zeros(ComplexF64, n_pts)
    for d in 1:3
        tmp .= j[d]
        plans.forward * tmp
        @inbounds for I in CartesianIndices(n_pts)
            tmp[I] *= im * grid.k[d][I[d]]
        end
        plans.inverse * tmp
        out .+= real.(tmp)
    end
    out
end

# ∇·j as the energy-damping kernel computes it.
function divj_kernel(ws)
    n_pts = ws.grid.config.n_points
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    D = ws.spin_matrices.system.n_components
    out = zeros(Float64, n_pts)
    buf = zeros(ComplexF64, n_pts)
    for c in 1:D
        psi_c = Array(view((ws.state.psi),:,:,:,c))
        buf .= psi_c
        plans.forward * buf
        @inbounds for I in CartesianIndices(n_pts)
            buf[I] *= -ws.grid.k_squared[I]
        end
        plans.inverse * buf
        out .+= imag.(conj.(psi_c) .* buf)
    end
    out
end

gp_energy(ws) = total_energy(ws)

# --- A. reservoir coefficients vs the paper's published values -------------

@testset "SPGPE reservoir coefficients" begin
    @testset "γ and ℳ̄ reproduce Rooney 2012 Fig. 2 values" begin
        # Their Rb-87 example: N = 5×10⁴ in a spherical ω = 2π×10 Hz trap at
        # T ≈ 0.85 T_c, quoted as (γ̄, ℳ̄) = (1.5, 2.7)×10⁻⁴.
        #
        # Rebuild those conditions in internal units (ℏ = m = ω_ref = 1):
        ħ, kB, m, a0 = 1.054571817e-34, 1.380649e-23, 1.443160648e-25, 5.29177210903e-11
        ω = 2π * 10.0
        N = 5e4
        a_s_SI = 100.4 * a0                      # Rb-87 triplet
        x0 = sqrt(ħ / (m * ω))                   # a_ho
        Tc = ħ * ω * (N / 1.20205)^(1 / 3) / kB   # ideal-Bose harmonic T_c
        T_int = 0.85 * Tc * kB / (ħ * ω)          # k_B T / ℏω_ref
        a_s = a_s_SI / x0

        # The cutoff enters both coefficients only through (ϵ_cut − μ)/T. The
        # paper does not print it for this point; solve for it from their ℳ̄ and
        # check that the SAME value reproduces their γ̄ — a one-parameter fit
        # constrained by two independent numbers, so agreement is meaningful.
        Mbar_target = 2.7e-4
        Δ_over_T = log1p(16π * a_s^2 / Mbar_target)   # from ℳ̄ = 16πa²/(e^{Δ/T}−1)
        mu = 0.0
        eps_cut = mu + Δ_over_T * T_int

        M = spgpe_scattering_rate(; T=T_int, mu, eps_cut, a_s)
        γ = spgpe_growth_rate(; T=T_int, mu, eps_cut, a_s)

        @test isapprox(M, Mbar_target; rtol=1e-9)          # by construction
        @test 0.3 < Δ_over_T < 3.0                          # a physical cutoff, not a fitted absurdity
        @test isapprox(γ, 1.5e-4; rtol=0.35)                # the real check
        # γ and ℳ̄ are "comparable in size" (their §III F) — within one decade.
        @test 0.1 < γ / M < 10
    end

    @testset "γ₀ prefactor = 8a²/λ_dB²" begin
        # In internal units λ_dB² = 2π/T, so γ₀ = 4a_s²T/π. As ϵ_cut → ∞ the
        # series' j=1 term (ln(1−x))² → x²(1+x)², so γ/γ₀ → x² = e^{2(μ−ϵ_cut)/T}
        # with a relative correction of order x — the tolerance tracks it rather
        # than being a round number, so a wrong PREFACTOR still fails.
        T, mu, a_s = 3.0, 0.0, 0.01
        γ0 = 4 * a_s^2 * T / π
        errs = Float64[]
        for eps_cut in (30.0, 40.0)
            x = exp((mu - eps_cut) / T)
            γ = spgpe_growth_rate(; T, mu, eps_cut, a_s)
            @test isapprox(γ, γ0 * x^2; rtol=10x)
            push!(errs, abs(γ / (γ0 * x^2) - 1))
        end
        @test errs[2] < errs[1]        # and it really is converging to the asymptote
    end

    @testset "monotonicity + domain" begin
        base = (; T=2.0, mu=1.0, a_s=0.01)
        # raising the cutoff empties the reservoir ⇒ both rates fall
        γ_lo = spgpe_growth_rate(; base..., eps_cut=3.0)
        γ_hi = spgpe_growth_rate(; base..., eps_cut=8.0)
        M_lo = spgpe_scattering_rate(; base..., eps_cut=3.0)
        M_hi = spgpe_scattering_rate(; base..., eps_cut=8.0)
        @test γ_hi < γ_lo
        @test M_hi < M_lo
        @test γ_lo > 0 && M_lo > 0
        # both scale as a²
        @test isapprox(spgpe_growth_rate(; T=2.0, mu=1.0, eps_cut=3.0, a_s=0.02),
            4 * γ_lo; rtol=1e-9)
        @test isapprox(spgpe_scattering_rate(; T=2.0, mu=1.0, eps_cut=3.0, a_s=0.02),
            4 * M_lo; rtol=1e-9)
        # ϵ_cut ≤ μ is unphysical and must throw, not silently diverge
        @test_throws ArgumentError spgpe_growth_rate(; T=1.0, mu=2.0, eps_cut=1.0, a_s=0.01)
        @test_throws ArgumentError spgpe_scattering_rate(; T=1.0, mu=2.0, eps_cut=1.0, a_s=0.01)
    end
end

# --- B. the ∇·j identity ---------------------------------------------------

@testset "SPGPE ∇·j = Σ_c Im(ψ*∇²ψ)" begin
    errs = Float64[]
    for n in (24, 32, 48)
        ws = flowing_state!(scalar_ws(; n=(n, n, n)))
        ref = divj_reference(ws)
        ker = divj_kernel(ws)
        scale = maximum(abs, ref)
        @test scale > 1e-3                              # the test state really does flow
        push!(errs, maximum(abs, ker .- ref) / scale)
    end
    # The two sides are analytically identical; the reference differentiates the
    # product j (spectrum twice as wide as ψ's), so any gap is its aliasing and
    # must vanish with resolution. A wrong identity would not converge.
    @test errs[end] < 1e-6
    @test errs[end] < errs[1]
end

# --- C/D/E. energy damping -------------------------------------------------

@testset "SPGPE energy damping (scattering)" begin
    @testset "conserves atom number to machine precision" begin
        ws = flowing_state!(scalar_ws())
        n0 = norm_sq(ws)
        for s in 1:20
            apply_energy_damping_step!(ws, 5e-3, 2.0, 0.01; seed=s, noise=true)
        end
        @test abs(norm_sq(ws) - n0) / n0 < 1e-13        # a real phase cannot change |ψ|²
    end

    @testset "the PROJECTED step's number loss: ONE-OFF without noise, a RATE with it" begin
        # TWO SUB-CASES, AND THE HISTORY OF GETTING THE SCOPE WRONG TWICE.
        #
        # An earlier version of this gate measured |dlnN/dt| through
        # `apply_spgpe_step!` at zero growth drive, found it flat in resolution,
        # and concluded the projected scattering step loses number "at the order of
        # the growth rate" — from which docs/guides/spgpe.md told callers a growth
        # problem must run `energy_damping=false`, and #334's whole ensemble did.
        #
        # That reading was then RETRACTED, here and independently in PR #351, on
        # the strength of the noise-off measurement below. The retraction was
        # itself too broad. Turning the noise back on (arm 4) gives ratio 4.04 for
        # 4x the steps: with noise the loss IS a rate, so the ORIGINAL operational
        # claim was right about production even though its evidence was not.
        #
        # What each measurement actually supports, kept separate because conflating
        # them is what produced both errors:
        #   noise OFF  ->  one-off, equal to the seed's out-of-C weight (arms 1-3)
        #   noise ON   ->  a rate                                       (arm 4)
        #   flatness in resolution  ->  supports NEITHER; a one-off is flat too
        #
        # The reading failed because a ONE-OFF and a RATE are identical at a single
        # endpoint, and because the measurement went through a `tracking_cutoff`:
        # a cutoff that moves every step MANUFACTURES fresh out-of-C content every
        # step, so a one-off is paid repeatedly and its cumulative curve is a
        # straight line. Flatness in resolution is what a one-off shows too.
        #
        # So this gate attacks the MECHANISM instead of matching the symptom.
        # #351's account is that the loss is whatever the SEED had outside the C
        # region, removed the first time the projector runs. That account makes
        # three predictions, and all three are asserted below:
        #
        #   1. pre-project the seed  ⇒  the loss disappears        (causal)
        #   2. the first step's ΔN   =  the seed's out-of-C weight (proportional)
        #   3. every later step      =  rounding                   (not a rate)
        #
        # Measured 2026-08-20 at 48³ box 18, k_cut = 5.5 (ratio 1.52, #334's own),
        # M̄ = 1.63e-3, T = 5, noise off, 400 steps: pre-projected 1.1e-13 total;
        # out-of-C 1.0e-4 → first step 1.0e-4; 9.9e-3 → 9.9e-3; tail 2.6e-16/step
        # in every arm; doubling dt changes nothing.
        #
        # NOISE OFF, and k_cut FINITE. Both are load-bearing. SPGPE noise makes ΔN
        # a random variable and a factor-2 reading cannot survive being buried in
        # run-to-run spread. And at k_cut = Inf the C region is everything, the
        # projector is the identity, and the mechanism cannot fire at all — a null
        # there says nothing, which is a check that was actually run and reported
        # before someone pointed out it could not have failed.
        kc = 5.5
        n_pts = 48
        box = 18.0

        """A flowing state carrying a controlled fraction of its norm ABOVE k_cut.

        The knob is the mechanism's own variable, not a proxy for it."""
        function ed_seed(ws, grid, out_frac)
            D = ws.spin_matrices.system.n_components
            n = grid.config.n_points
            psi = zeros(ComplexF64, n..., D)
            for I in CartesianIndices(n)
                x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
                r2 = x^2 + y^2 + z^2
                psi[I, D] = exp(-r2 / 4.5) * cis(0.5x + 0.08r2)
            end
            if out_frac > 0
                f = FFTW.fft(psi[:, :, :, D])
                mask = grid.k_squared .> kc^2
                hi = zero(f)
                hi[mask] .= f[mask] .+ 1e-3 * maximum(abs, f)
                s = sqrt(out_frac * sum(abs2, f[.!mask]) / max(sum(abs2, hi), eps()))
                psi[:, :, :, D] .= FFTW.ifft(f .+ s .* hi)
            end
            copyto!(ws.state.psi, psi)
            ws
        end

        function ed_trace(; out_frac, dt, nstep, pre_project)
            SpinorBEC.scratch_clear!()
            grid = make_grid(GridConfig((n_pts, n_pts, n_pts), (box, box, box)))
            sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
                normalize_every=0)
            ws = make_workspace(; grid, atom=Rb87,
                interactions=InteractionParams(Dict{Int, Float64}(0 => 20.0)),
                potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            ed_seed(ws, grid, out_frac)
            pre_project && apply_projected_gp!(ws, kc)
            D = ws.spin_matrices.system.n_components
            fk = FFTW.fft(Array(ws.state.psi)[:, :, :, D])
            w_out = sum(abs2, fk[grid.k_squared .> kc ^ 2]) / sum(abs2, fk)
            dV = cell_volume(grid)
            N(ws) = real(sum(abs2, ws.state.psi)) * dV
            ns = Float64[N(ws)]
            for _ in 1:nstep
                apply_energy_damping_step!(ws, 1.628e-3, 5.0, dt; noise=false, k_cut=kc)
                apply_projected_gp!(ws, kc)
                push!(ns, N(ws))
            end
            (; w_out,
                first=(ns[1] - ns[2]) / ns[1],
                tail=(ns[2] - ns[end]) / ns[1] / (length(ns) - 2),
                total=(ns[1] - ns[end]) / ns[1])
        end

        nstep = 120
        a = ed_trace(; out_frac=0.0, dt=0.01, nstep, pre_project=true)
        b = ed_trace(; out_frac=1.0e-4, dt=0.01, nstep, pre_project=false)
        c = ed_trace(; out_frac=1.0e-2, dt=0.01, nstep, pre_project=false)
        c2 = ed_trace(; out_frac=1.0e-2, dt=0.02, nstep=nstep ÷ 2, pre_project=false)
        Printf.@printf("\n  projected energy damping, noise off, k_cut = %.1f:\n", kc)
        for (nm, r) in (("pre-projected", a), ("out 1e-4", b), ("out 1e-2", c),
            ("out 1e-2, 2dt", c2))
            Printf.@printf("    %-16s out=%.2e  1st=%.3e  tail/step=%.3e  total=%.3e\n",
                nm, r.w_out, r.first, r.tail, r.total)
        end

        # 1. CAUSAL. A seed already inside its C region loses nothing — this is the
        #    assertion the retracted version could not have made, and it is the one
        #    that distinguishes "explained" from "consistent with".
        @test a.total < 1.0e-10

        # 2. PROPORTIONAL. The first step removes the seed's out-of-C weight, so the
        #    knob and the effect track over two decades. A rate would not care what
        #    the seed carried.
        @test isapprox(b.first, b.w_out; rtol=0.05)
        @test isapprox(c.first, c.w_out; rtol=0.05)
        @test c.first / b.first > 50            # two decades of knob, two of effect

        # 3. NOT A RATE. Everything after the first step is rounding, and doubling
        #    dt at fixed physical time changes neither the step nor the tail — which
        #    also rules out an O(dt) discretisation residual.
        for r in (a, b, c, c2)
            @test abs(r.tail) < 1.0e-14
        end
        @test isapprox(c2.first, c.first; rtol=0.05)

        # 4. AND THE SCOPE, asserted rather than left to the prose above. Every
        #    arm so far ran NOISE OFF, which is not the condition callers run.
        #    Turning the noise on and starting from a PRE-PROJECTED seed — so the
        #    one-off is already paid and cannot be mistaken for what follows —
        #    isolates whatever the noise channel does on its own.
        #
        #    This is here because the noise-off result was carried into an
        #    operational conclusion it does not support. `docs/guides/spgpe.md`
        #    arm D (zero drive, noise ON) lost 11.5 % of N_C in 60 ms while arm E
        #    (zero drive, noise OFF) lost 0.6 %; the loss needs the noise, and the
        #    gate that "retracted the rate" never turned it on. Whichever way this
        #    comes out, the gate now states its own scope instead of a title that
        #    outruns it.
        #
        #    Growth is switched OFF (gamma = 0), not merely balanced, so nothing
        #    physical can move N and the whole signal belongs to energy damping.
        function ed_noisy(; nstep, seed)
            SpinorBEC.scratch_clear!()
            grid = make_grid(GridConfig((n_pts, n_pts, n_pts), (box, box, box)))
            sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false,
                save_every=1, normalize_every=0)
            ws = make_workspace(; grid, atom=Rb87,
                interactions=InteractionParams(Dict{Int, Float64}(0 => 20.0)),
                potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
                fft_flags=FFTW.ESTIMATE)
            ed_seed(ws, grid, 0.0)
            apply_projected_gp!(ws, kc)
            dV = cell_volume(grid)
            n0 = real(sum(abs2, ws.state.psi)) * dV
            trunc = 0.0
            res = SPGPEReservoir(; T=5.0, mu=1.0, a_s=0.01, k_cut=kc, gamma=0.0,
                allow_unphysical_rates=true)
            for s in 1:nstep
                r = apply_spgpe_step!(ws, res, 0.01; t=0.0, seed=seed * 100_003 + s,
                    noise=true)
                trunc += get(r, :noise_truncated, 0.0)
            end
            n1 = real(sum(abs2, ws.state.psi)) * dV
            (; loss=(n0 - n1) / n0, trunc=trunc / n0)
        end

        mean_loss(nstep) = sum(ed_noisy(; nstep, seed=s).loss for s in 1:3) / 3
        l_short = mean_loss(50)
        l_long = mean_loss(200)
        Printf.@printf(
            "  noise ON, pre-projected, gamma=0: 50 steps %.4e | 200 steps %.4e | ratio %.2f\n",
            l_short, l_long, l_long / max(abs(l_short), eps()))

        # A one-off saturates: 4x the steps returns the same number. A rate scales
        # with them. The assertion is on the CLASSIFICATION, with the boundary far
        # from both hypotheses (1x versus 4x), so seed-to-seed spread in the noise
        # cannot flip it.
        # MEASURED 2026-08-20: 50 steps 1.0853e-4, 200 steps 4.3821e-4, ratio 4.04
        # against the 4.00 that exact proportionality would give. With the noise on
        # the loss IS a rate, and the one-off result above is a property of the
        # noise-off sub-case only.
        #
        # This is the boundary written AFTER the measurement, which is the point of
        # the comment that used to sit here. 3.0 sits five parts in a hundred from
        # the measured 4.04 and a full unit from the 1.0 a saturating one-off would
        # give, so seed-to-seed spread cannot cross it.
        @test l_long / l_short > 3.0
        @test l_short > 1.0e-6          # and the effect is real, not rounding
        @test isapprox(c2.total, c.total; rtol=0.05)
    end

    @testset "a ramped cutoff does not grow the scratch registry" begin
        # `tracking_cutoff` exists to RAMP k_cut, so it takes a different value
        # every reservoir sub-step. Keying the energy-damping buffers on it gave
        # one set of four device arrays per step: a 64³ D=13 growth ramp died at
        # 99.97 % of a 94 GiB H100 after 34 557 sub-steps, and every existing test
        # passed because they all hold the cutoff fixed. So the shape-dependent
        # buffers are keyed on SHAPE and the cutoff-dependent one is rebuilt in
        # place — which is checkable without a GPU and without a long run.
        SpinorBEC.scratch_clear!()
        ws = flowing_state!(scalar_ws())
        for (i, kc) in enumerate(range(2.0, 4.0; length=25))
            apply_energy_damping_step!(ws, 5e-3, 1.0, 1e-3; seed=i, noise=true, k_cut=kc)
        end
        for cat in (:ed_divj, :ed_phase, :ed_ksq, :ed_kinv)
            n = length(get(SpinorBEC.SCRATCH_REGISTRY, cat, Dict()))
            @test n == 1
            n == 1 || @info "energy-damping scratch grew with the cutoff" cat n
        end
        # …and the kernel it rebuilds is still the right one: the LAST cutoff must
        # be the one in force, or the buffer is being reused without being refilled.
        divj, phase_k, ksq, kinv = SpinorBEC._energy_damping_buffers(
            ws, ws.grid.config.n_points, 3.0)
        k2 = ws.grid.k_squared
        @test all(iszero, kinv[k2 .> 9.0])
        inband = (k2 .> 0) .& (k2 .<= 9.0)
        @test all(isapprox.(kinv[inband], 1 ./ sqrt.(k2[inband]); rtol=1e-12))
    end

    @testset "quiet: energy decreases monotonically (Eq. 29)" begin
        ws = flowing_state!(scalar_ws())
        E = Float64[gp_energy(ws)]
        for _ in 1:30
            apply_energy_damping_step!(ws, 2e-2, 0.0, 0.01; noise=false)
            push!(E, gp_energy(ws))
        end
        @test all(diff(E) .<= 1e-12 * abs(E[1]))        # never heats
        @test E[end] < E[1] - 1e-8 * abs(E[1])          # and actually damps
    end

    @testset "with NOISE ON it must relax TOWARD the reservoir, not away" begin
        # The gate above runs `noise=false, T=0.0` — the DRIFT alone, in a field
        # with no fluctuations. Energy damping is a drift/noise PAIR and only
        # relaxes to temperature T if the two balance. A gate on one half says
        # nothing about the balance, and production runs the pair.
        #
        # This is the second time that blind spot produced a wrong picture in one
        # day. The projected step's number loss is ONE-OFF with the noise off and
        # a RATE with it on (ratio 4.04, §"the PROJECTED step's number loss");
        # here the sign oracle says "never heats" with the noise off while #334's
        # ramp carries mu_psi from 8.48 to 51.68 with it on, a factor 6, while the
        # condensate collapses. Both gates turned the noise off for a REASON that
        # was sound, and both conclusions were then used past their scope.
        #
        # The assertion is directional and deliberately loose: a field started far
        # ABOVE the reservoir temperature must come DOWN. Pinning an equilibrium
        # value would need a thermometer this test does not have, and the failure
        # under investigation is not a few per cent — it is monotone divergence.
        T_res = 1.0
        ws = flowing_state!(scalar_ws())
        ws.state.psi .*= 3.0                       # hot: mean energy well above T
        mu_psi(w) = field_chemical_potential(w)
        e0 = mu_psi(ws)
        es = Float64[e0]
        res = SPGPEReservoir(; T=T_res, mu=1.0, a_s=0.01, k_cut=5.0, gamma=0.0,
            allow_unphysical_rates=true)
        for s in 1:400
            apply_spgpe_step!(ws, res, 0.002; t=0.0, seed=7000 + s, noise=true)
            s % 100 == 0 && push!(es, mu_psi(ws))
        end
        Printf.@printf("\n  energy damping with noise, hot start: µ̃ %s\n",
            join(round.(es; digits=4), " → "))
        @test all(isfinite, es)

        # POSITIVE CONTROL FIRST. The same call, with a scattering rate large
        # enough to act in 400 steps: if this does not cool, the arm cannot detect
        # cooling and any null below is about the arm, not about the physics.
        # `M` is set explicitly here rather than derived — the derived rate at
        # these parameters is what made the first attempt measure nothing.
        function cool_trace(; M, T, nstep=400)
            SpinorBEC.scratch_clear!()
            w = flowing_state!(scalar_ws())
            w.state.psi .*= 3.0
            r = SPGPEReservoir(; T, mu=1.0, a_s=0.01, k_cut=5.0, gamma=0.0, M,
                allow_unphysical_rates=true)
            a = field_chemical_potential(w)
            for k in 1:nstep
                apply_spgpe_step!(w, r, 0.002; t=0.0, seed=8000 + k, noise=true)
            end
            (a, field_chemical_potential(w))
        end
        (c0, c1) = cool_trace(; M=1.0, T=0.05)
        Printf.@printf("  positive control (M=1, T=0.05): µ̃ %.4f → %.4f\n", c0, c1)
        @test c1 < c0 - 1.0e-3 * abs(c0)     # the arm CAN see cooling

        # MEASURED 2026-08-21 and the arm is UNDER-POWERED, recorded here rather
        # than deleted because the null is the finding:
        #
        #   µ̃ 65.8286 → 65.8286 → 65.8286 → 65.8287 → 65.8287
        #
        # 400 steps move it by 1e-4. At this M̄ and duration the term does nothing
        # measurable in either direction, so "it did not cool" says nothing about
        # whether it CAN cool — and nothing at all about production's factor 6.
        #
        # What this arm needs before it can be asserted is a POSITIVE CONTROL: a
        # configuration where the same call demonstrably cools, so that a failure
        # to cool is informative. Without one this is the shape of null that a
        # degenerate check produces, which is the error this suite keeps catching
        # elsewhere. `@test_broken` would claim the mechanism is broken; it is not
        # established that anything here is.
        @info "energy damping with noise is under-powered at this rate — " *
            "needs a positive control before it can assert a direction" es
        @test abs(es[end] - es[1]) < 1e-2 * abs(es[1])   # what IS true: it barely moves
    end

    @testset "quiet damping rate matches −ℳ̄∫d³k|k·j̃|²/|k|" begin
        ws = flowing_state!(scalar_ws())
        M, dt = 1e-2, 1e-4
        # analytic prediction from the state BEFORE the step
        n_pts = ws.grid.config.n_points
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        j = probability_current(Array(ws.state.psi), ws.grid, plans)
        dV = cell_volume(ws.grid)
        Vbox = prod(ws.grid.config.box_size)
        acc = 0.0
        jhat = [
            begin
                t = ComplexF64.(j[d]) .* dV
                plans.forward * t
                t
            end for d in 1:3
        ]
        @inbounds for I in CartesianIndices(n_pts)
            k2 = ws.grid.k_squared[I]
            k2 > 0 || continue
            kdotj =
                ws.grid.k[1][I[1]] * jhat[1][I] +
                ws.grid.k[2][I[2]] * jhat[2][I] +
                ws.grid.k[3][I[3]] * jhat[3][I]
            acc += abs2(kdotj) / sqrt(k2)
        end
        dEdt_pred = -M * acc / Vbox

        E0 = gp_energy(ws)
        apply_energy_damping_step!(ws, M, 0.0, dt; noise=false)
        dEdt_num = (gp_energy(ws) - E0) / dt

        @test dEdt_pred < 0
        @test isapprox(dEdt_num, dEdt_pred; rtol=0.05)
    end

    @testset "inert on a stationary state, active on a flowing one" begin
        # A real, positive field has j ≡ 0 ⇒ ∇·j = 0 ⇒ no effect at all.
        ws = scalar_ws()
        grid = ws.grid
        D = ws.spin_matrices.system.n_components
        psi = zeros(ComplexF64, grid.config.n_points..., D)
        for I in CartesianIndices(grid.config.n_points)
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            psi[I, D] = exp(-(x^2 + y^2 + z^2) / 8)
        end
        copyto!(ws.state.psi, psi)
        before = copy(Array(ws.state.psi))
        apply_energy_damping_step!(ws, 1e-2, 0.0, 0.01; noise=false)
        @test maximum(abs, Array(ws.state.psi) .- before) < 1e-13 * maximum(abs, before)

        ws2 = flowing_state!(scalar_ws())
        before2 = copy(Array(ws2.state.psi))
        apply_energy_damping_step!(ws2, 1e-2, 0.0, 0.01; noise=false)
        @test maximum(abs, Array(ws2.state.psi) .- before2) > 1e-8 * maximum(abs, before2)
    end
end

# --- F. number damping direction -------------------------------------------

@testset "SPGPE number damping relaxes N_C toward the reservoir μ (Eq. 23)" begin
    # dN_C/dt = −2γ(μ̃ − μ)N_C: below the reservoir μ the c-field grows, above it decays.
    function n_after(mu_res)
        ws = scalar_ws(; c0=20.0)
        grid = ws.grid
        D = ws.spin_matrices.system.n_components
        psi = zeros(ComplexF64, grid.config.n_points..., D)
        for I in CartesianIndices(grid.config.n_points)
            x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
            psi[I, D] = exp(-(x^2 + y^2 + z^2) / 8)
        end
        copyto!(ws.state.psi, psi)
        # `field_chemical_potential` rather than a fourth hand-rolled copy: this
        # was written out here, and again in #418's instrumentation, before the
        # third site made it a shared function.
        μ̃ = field_chemical_potential(ws)
        n0 = norm_sq(ws)
        res = SPGPEReservoir(; T=0.0, mu=mu_res, a_s=0.01, k_cut=6.0,
            # Rate chosen for a visible effect in a few steps, not for fidelity:
            # the derived value here is 1.2e-8 and nothing would move.
            gamma=0.05, energy_damping=false, allow_unphysical_rates=true)
        for _ in 1:10
            apply_spgpe_step!(ws, res, 0.002; noise=false)
        end
        (μ̃, (norm_sq(ws) - n0) / n0)
    end

    μ̃, dn_hi = n_after(50.0)      # reservoir well above μ̃ ⇒ grows
    _, dn_lo = n_after(-20.0)     # reservoir well below μ̃ ⇒ decays
    @test μ̃ > 0
    @test dn_hi > 1e-4
    @test dn_lo < -1e-4
end

# --- G. the reservoir ramp -------------------------------------------------

@testset "SPGPEReservoir" begin
    @testset "defaults + overrides" begin
        res = SPGPEReservoir(; T=2.0, mu=1.0, a_s=0.01, k_cut=4.0)
        r = spgpe_rates(res, 0.0)
        @test r.eps_cut ≈ 0.5 * 4.0^2                      # ϵ_cut = ½k_cut² by default
        @test r.gamma ≈ spgpe_growth_rate(; T=2.0, mu=1.0, eps_cut=8.0, a_s=0.01)
        @test r.M ≈ spgpe_scattering_rate(; T=2.0, mu=1.0, eps_cut=8.0, a_s=0.01)

        off = SPGPEReservoir(; T=2.0, mu=1.0, a_s=0.01, k_cut=4.0,
            number_damping=false, energy_damping=false)
        @test spgpe_rates(off, 0.0).gamma == 0.0
        @test spgpe_rates(off, 0.0).M == 0.0

        # An override IS honoured — but only when the caller says the mismatch is
        # deliberate. 0.3 here is 1.25e6× the derived 2.4e-7, which is fine for a
        # unit test that wants visible damping in a few steps and is exactly what
        # a physics run must not be able to do by accident.
        fixed = SPGPEReservoir(; T=2.0, mu=1.0, a_s=0.01, k_cut=4.0, gamma=0.3, M=0.4,
            allow_unphysical_rates=true)
        @test spgpe_rates(fixed, 0.0).gamma == 0.3
        @test spgpe_rates(fixed, 0.0).M == 0.4

        # …and without that flag it must not build. gamma was pinned at 0.002 and
        # 0.02 through an entire Kibble-Zurek scan against a physical 8.2e-4 to
        # 5.4e-5, which put the reservoir response time at 40-622 while every τ_Q
        # in the scan was 2-32. Nothing failed: not norm conservation, not GPU/CPU
        # parity, not one oracle. A fitted rate is invisible unless something
        # compares it to the derivation.
        @test_throws ArgumentError SPGPEReservoir(;
            T=2.0, mu=1.0, a_s=0.01, k_cut=4.0, gamma=0.3, M=0.4)
        @test_throws ArgumentError SPGPEReservoir(;
            T=30.0, mu=15.0, a_s=0.01, k_cut=sqrt(90.0), gamma=0.002)

        # The derived value itself must pass, or the gate is just an obstacle.
        g_ok = spgpe_growth_rate(; T=30.0, mu=15.0, eps_cut=45.0, a_s=0.01)
        @test SPGPEReservoir(; T=30.0, mu=15.0, a_s=0.01, k_cut=sqrt(90.0),
            gamma=g_ok) isa SPGPEReservoir
    end

    @testset "a FIXED cutoff decouples the reservoir as T falls (the 80³ null result)" begin
        # This is the failure that produced no condensate on 2026-07-28. Both
        # coefficients depend on the cutoff only through (ϵ_cut−μ)/T, so holding
        # ϵ_cut fixed in absolute energy while T falls drives that ratio up and
        # collapses them exponentially. Gate the mechanism, not the anecdote.
        T_hot, T_cold, mu = 40.5, 4.7, 1.0
        pinned = SPGPEReservoir(;
            T=PiecewiseLinearWaveform([0.0, 1.0], [T_hot, T_cold]),
            mu=mu, a_s=0.0148, k_cut=10.6)
        r_hot, r_cold = spgpe_rates(pinned, 0.0), spgpe_rates(pinned, 1.0)
        @test r_cold.gamma < 1e-6 * r_hot.gamma       # γ collapses by >10⁶
        @test r_cold.M < 1e-3 * r_hot.M

        # The tracking cutoff holds (ϵ_cut−μ)/T fixed, so both rates stay O(1)
        # relative to each other across the same temperature drop.
        tracked = SPGPEReservoir(;
            T=PiecewiseLinearWaveform([0.0, 1.0], [T_hot, T_cold]),
            mu=mu, a_s=0.0148,
            k_cut=tracking_cutoff([0.0, 1.0], [mu, mu], [T_hot, T_cold]; n_T=2.5))
        t_hot, t_cold = spgpe_rates(tracked, 0.0), spgpe_rates(tracked, 1.0)
        @test t_cold.k_cut < t_hot.k_cut                       # the cutoff really moves
        @test isapprox((t_hot.eps_cut - t_hot.mu) / t_hot.T,
            (t_cold.eps_cut - t_cold.mu) / t_cold.T; rtol=1e-9)  # ratio held fixed
        # γ ∝ γ₀ ∝ T at fixed ratio, so it tracks T rather than collapsing. Only
        # the j=1 Lerch term depends on (ϵ_cut−μ)/T alone; j≥2 carry a residual
        # fugacity dependence through z^{1−j}, hence sub-percent rather than exact.
        @test isapprox(t_cold.gamma / t_hot.gamma, T_cold / T_hot; rtol=1e-2)
        @test isapprox(t_cold.M, t_hot.M; rtol=1e-9)           # ℳ̄ depends only on the ratio
        # The contrast that matters: pinning the cutoff loses >5 decades of γ
        # relative to tracking it, over the same temperature drop.
        @test (r_cold.gamma / r_hot.gamma) < 1e-5 * (t_cold.gamma / t_hot.gamma)
    end

    @testset "ramped reservoir moves the rates" begin
        # This is the evaporation lever: cooling and depleting the reservoir over
        # the ramp must change γ and ℳ̄, not just relabel time.
        res = SPGPEReservoir(;
            T=PiecewiseLinearWaveform([0.0, 100.0], [8.0, 2.0]),
            mu=PiecewiseLinearWaveform([0.0, 100.0], [-4.0, 0.5]),
            a_s=0.01, k_cut=5.0)
        r0, r1 = spgpe_rates(res, 0.0), spgpe_rates(res, 100.0)
        @test r0.T ≈ 8.0 && r1.T ≈ 2.0
        @test r0.mu ≈ -4.0 && r1.mu ≈ 0.5
        @test r0.gamma != r1.gamma
        @test r0.M != r1.M
        # midpoint interpolates
        @test spgpe_rates(res, 50.0).T ≈ 5.0
    end
end

# --- composition -----------------------------------------------------------

@testset "SPGPE equilibrates the C region to the Rayleigh-Jeans population" begin
    # The existing FDR test pins the RJ *slope*; this pins the TOTAL, which is
    # what a run actually reports. Free field (c0 = 0) with no trap makes
    # eps_k = k^2/2 exact, so the classical equilibrium is the unambiguous sum
    # N_C = sum_{|k|<k_cut} T/(eps_k - mu) over the modes the grid really has.
    #
    # Worth its own gate: when a production run came back with N_C two orders
    # below a hand estimate, this is the check that decided which of the two was
    # wrong (the hand estimate).
    n, L = 32, 16.0
    T, mu, kcut, gam, dt = 2.0, -2.0, 4.0, 0.05, 0.005
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => 0.0)),
        sim_params=SimParams(; dt, n_steps=1, imaginary_time=false,
            save_every=1, normalize_every=0),
        fft_flags=FFTW.ESTIMATE)
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)

    rj = 0.0
    for I in CartesianIndices(grid.config.n_points)
        k2 = grid.k_squared[I]
        k2 <= kcut^2 && (rj += T / (0.5 * k2 - mu))
    end

    # γ here only has to be fast enough to reach equilibrium in 2400 steps; the
    # Rayleigh-Jeans population it equilibrates TO is independent of it.
    res = SPGPEReservoir(; T, mu, a_s=0.01, k_cut=kcut, gamma=gam, M=0.0,
        allow_unphysical_rates=true)
    fill!(ws.state.psi, 0)
    for s in 1:2400
        apply_spgpe_step!(ws, res, dt; t=0.0, seed=1000 + s)
    end
    N_C = real(sum(abs2, ws.state.psi)) * dV

    @test isapprox(N_C, rj * D; rtol=0.12)      # equilibrium, all D components
    @test N_C > 100                              # the field really filled
end

@testset "projector diagnostic separates cutoff outflow from noise truncation" begin
    # The first attempt reported one combined number and it was ~10³× too large to
    # mean what it claimed: per step the projector removes a little of the field
    # (only if the cutoff moved) and a lot of the freshly injected noise.
    ws = flowing_state!(scalar_ws())
    n0 = norm_sq(ws)

    # (a) cutoff held fixed, noise off ⇒ nothing leaves by either route.
    #
    # `== 0.0` is NOT available here and asserting it was wrong: the projector is
    # an FFT round-trip, not a literal no-op. What IS available is a floor 16
    # orders below the old one. The outflow is accumulated in k-space as the
    # weight of the masked modes, so its floor is the residual amplitude left in
    # already-masked modes SQUARED (~1e-31), where differencing ∫|ψ|² across the
    # call floored at the FFT round-trip error itself (~1e-15) — and could come
    # out NEGATIVE, which is meaningless for "atoms that left".
    still = SPGPEReservoir(; T=0.0, mu=1.0, a_s=0.01, k_cut=5.0, gamma=0.01, M=0.0)
    apply_spgpe_step!(ws, still, 0.002; t=0.0, noise=false)          # settle
    r = apply_spgpe_step!(ws, still, 0.002; t=0.0, noise=false)
    @test 0.0 <= r.cutoff_outflow < 1e-25 * n0
    @test r.noise_truncated < 1e-12 * n0        # only FFT round-off

    # (b) cutoff SHRINKS, noise still off ⇒ the swept band leaves, and it is
    # booked as outflow. The residual on the other channel is the damping drift's
    # nonlinear term leaking a little power across the new (much smaller) cutoff —
    # real, but 7 decades down, so the attribution is unambiguous.
    shrink = SPGPEReservoir(; T=0.0, mu=1.0, a_s=0.01, gamma=0.01, M=0.0,
        k_cut=PiecewiseLinearWaveform([0.0, 1.0], [5.0, 2.0]))
    r2 = apply_spgpe_step!(ws, shrink, 0.002; t=1.0, noise=false)
    @test r2.cutoff_outflow > 1e-3 * n0
    @test r2.noise_truncated < 1e-5 * r2.cutoff_outflow

    # (c) noise on at a FIXED cutoff ⇒ truncation is large, outflow at the floor.
    # This is the case that made the first combined diagnostic meaningless: it
    # reported 1.4e7 "atoms leaving the C region" when the cutoff-driven flow was
    # identically nothing.
    noisy = SPGPEReservoir(; T=5.0, mu=1.0, a_s=0.01, k_cut=2.0, gamma=0.01, M=0.0,
        allow_unphysical_rates=true)
    r3 = apply_spgpe_step!(ws, noisy, 0.002; t=0.0, seed=5, noise=true)
    @test r3.noise_truncated > 1e-3 * n0
    @test 0.0 <= r3.cutoff_outflow < 1e-25 * n0
    # The separation is the point: 20+ decades between the two channels.
    @test r3.cutoff_outflow < 1e-20 * r3.noise_truncated
end

@testset "SPGPE grows a condensate to the Thomas-Fermi number" begin
    # The physics gate the suite was missing. Every other test here checks a
    # rate, an identity or a conservation law; none asserted that the thing the
    # solver exists for actually happens. Its absence let two runs be read as
    # "no condensate forms" when the solver was working and the ESTIMATOR was
    # wrong — a trapped condensate spreads over |k| <~ 1/R_TF, so the largest
    # single k-mode holds a small fraction of N0 (22x understated there).
    #
    # N0 is therefore the overlap with the actual GP mode, |<phi_GP|psi>|^2.
    ω, a_s = 1.0, 0.02
    c0 = 4π * a_s
    mu, T, γ, dt = 3.0, 1.0, 0.1, 0.002
    k_cut = sqrt(2 * (mu + T))
    grid = make_grid(GridConfig((24, 24, 24), (10.0, 10.0, 10.0)))
    dV = cell_volume(grid)
    N_TF = ((2 * mu / ω)^2.5) / (15 * a_s)
    @test π / minimum(grid.dx) > k_cut          # the grid resolves the C region

    gs = find_ground_state(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0 * N_TF)),
        potential=HarmonicTrap{3}((ω, ω, ω)), dt=0.002, n_steps=3000, tol=1e-10,
        initial_state=:m_minus_F, verbose=false)
    D = gs.workspace.spin_matrices.system.n_components
    phi = Array(view((gs.workspace.state.psi),:,:,:,D))
    phi ./= sqrt(sum(abs2, phi) * dV)

    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0)),
        potential=HarmonicTrap{3}((ω, ω, ω)),
        sim_params=SimParams(; dt, n_steps=1, imaginary_time=false,
            save_every=1, normalize_every=0), fft_flags=FFTW.ESTIMATE)
    res = SPGPEReservoir(; T, mu, a_s, k_cut, gamma=γ, M=0.0,
        allow_unphysical_rates=true)
    fill!(ws.state.psi, 0)

    N0 = 0.0
    for s in 1:25_000
        split_step!(ws)
        apply_spgpe_step!(ws, res, dt; t=0.0, seed=90_000 + s)
        @views for c in 1:(D - 1)
            ws.state.psi[:, :, :, c] .= 0
        end
    end
    psi = Array(view((ws.state.psi),:,:,:,D))
    N0 = abs2(sum(conj.(phi) .* psi) * dV)
    N_C = sum(abs2, psi) * dV

    @test N0 > 0.3 * N_TF        # a condensate, not a thermal field
    @test N0 < 1.5 * N_TF        # and not a runaway
    @test N_C > N0               # the C region holds it plus a thermal part
end

@testset "SPGPE full step composes and stays finite" begin
    ws = flowing_state!(scalar_ws())
    res = SPGPEReservoir(; T=1.0, mu=5.0, a_s=0.01, k_cut=5.0)
    r = apply_spgpe_step!(ws, res, 0.002; t=0.0, seed=1)
    @test r.gamma > 0 && r.M > 0
    @test all(isfinite, Array(ws.state.psi))
    @test norm_sq(ws) > 0

    # callback fires on schedule only
    fired = Int[]
    cb = spgpe_callback(res, 0.002; every=5, seed=3,
        on_rates=(t, rr) -> push!(fired, 1))
    for step in 1:20
        cb(ws, step)
    end
    @test length(fired) == 4
end
