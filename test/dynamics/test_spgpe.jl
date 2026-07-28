using Test
using FFTW
using LinearAlgebra
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
        μ̃ = let hpsi = similar(ws.state.psi)
            SpinorBEC.apply_operator_via_registry!(hpsi, ws)
            real(sum(conj.(ws.state.psi) .* hpsi)) / real(sum(abs2, ws.state.psi))
        end
        n0 = norm_sq(ws)
        res = SPGPEReservoir(; T=0.0, mu=mu_res, a_s=0.01, k_cut=6.0,
            gamma=0.05, energy_damping=false)
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

        fixed = SPGPEReservoir(; T=2.0, mu=1.0, a_s=0.01, k_cut=4.0, gamma=0.3, M=0.4)
        @test spgpe_rates(fixed, 0.0).gamma == 0.3
        @test spgpe_rates(fixed, 0.0).M == 0.4
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
