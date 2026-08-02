#!/usr/bin/env julia
# Kibble-Zurek scaling of the winding number in a toroidal SPGPE — a reproduction
# of McDonald & Bradley, PRA 92, 033616 (2015), arXiv:1507.08357.
#
# WHY THIS AND NOT A NEW MEASUREMENT
#
# The first attempt at a KZ exponent in this project was built from scratch and
# every structural choice disagreed with published practice: a harmonic trap
# (whose KZ exponent differs from the homogeneous one, 2 against 1/2 at mean
# field), a temperature ramp at fixed mu that never crossed the transition
# (T_c = 49 against a ramp of 30 -> 2), a growth rate pinned 2.4-370x off its
# derived value, a cutoff violating eps_cut >~ 2 mu at the cold end, measurement
# at a fixed hold of 0.06 response times, and 8 realisations against a literature
# norm of 1000-10000. The reported alpha = 0.93 is retracted.
#
# So: reproduce a published SPGPE KZ result first. It is also the result that
# makes this branch worth having — the number-damping ("simple growth") SPGPE has
# a non-conserved order parameter and no conserved density, putting it in model A
# with z = 2, and it recovers mean field. The energy-damping reservoir is
# number-conserving and supplies the coupling that defines model E/F. McDonald &
# Bradley measured both and found the full SPGPE lands off mean field AND off
# every equilibrium universality class.
#
# THE TARGET
#
#   quantity                  number-damping        full SPGPE
#   alpha  (t_hat ∝ τ_Q^α)    0.5119 ± 0.0178       0.7145 ± 0.0358
#   beta   (σ(W) ∝ τ_Q^-β)    0.1236 ± 0.0098       0.0966 ± 0.0128
#   ν = 2β/(1-α)              0.5065 ± 0.0586       0.6767 ± 0.1745
#   z = α/(2β)                2.071 ± 0.236         3.698 ± 0.675
#
# (The ν, z relations are not quoted here on faith — they invert α = zν/(1+zν)
# and β = ν/2(1+zν), and reproduce all four published values.)
#
# PROTOCOL, from Sec. III of the paper
#
#   geometry      toroid, circumference L = 200 a_perp, transverse ω_perp,
#                 periodic, effectively quasi-1D;  M = 1024 grid points
#   interaction   ⁸⁷Rb, g₁ = 0.0139 ℏω_perp a_perp;  N = μL/g₁ ≈ 14400
#   quench        μ(t) = μ₀ t/τ_Q,  t ∈ [-τ_Q, τ_Q],  μ₀ = ℏω_perp
#                 so μ runs -ℏω_perp -> +ℏω_perp over a duration 2τ_Q
#   τ_Q           ω_perp τ_Q = e² … e⁸
#   rates         γ = 10⁻² during the quench;  ℳ = γ = 10⁻² for the full SPGPE
#   initial       ψ = 0, relaxed at γ = 1 for 1000 relaxation times τ ≡ ℏ/(γ|μ|)
#   final         a further 10 relaxation times, then W = θ_c/2π
#
# Two numbers the paper does not print are derived here rather than guessed:
# T = 0.5T_c with T_c from the ideal Bose gas in this geometry, and ϵ_cut from
# the standard prescription (occupation ~1 at the cut, ϵ_cut >~ 2μ) — which for
# this trap also coincides with the quasi-1D validity bound ℏω_perp.

using SpinorBEC, FFTW, Printf, Statistics, Random

const KZ_L = 200.0                 # circumference, a_perp
const KZ_M = 1024                  # grid points
const KZ_G1 = 0.0139               # 1D coupling, ℏω_perp a_perp
const KZ_MU0 = 1.0                 # ℏω_perp
# Quasi-1D: g₁ = 2ℏω_perp a_s, so the paper's g₁ fixes a_s rather than leaving it
# to be guessed. 0.0139/2 = 0.00695 a_perp, and ⁸⁷Rb's 5.3 nm against
# a_perp = √(ℏ/mω_perp) = 0.76 µm at ω_perp/2π = 200 Hz gives 0.0070 — the two
# agree, which is a check on the geometry as stated.
const KZ_AS = KZ_G1 / 2
# Trajectory seeds must be separated by more than the number of steps in one
# trajectory, since each step draws with `seed + s`. The longest run here is
# (1000 + 2e⁸ + 1000)/dt ≈ 8×10⁵ steps at dt = 0.01.
const KZ_SEED_STRIDE = 10_000_000
const OUTDIR = get(ENV, "SPINORBEC_FIGS_ROOT", "runs/kz_toroidal")

"""
    ideal_torus_Tc(; L, g1, mu0) -> Float64

`T_c` of the ideal Bose gas in this toroidal trap, from
`N = Σ' [exp((ϵ−ϵ₀)/T) − 1]⁻¹` at `μ → ϵ₀`, with `N = μ₀L/g₁` the Thomas-Fermi
number the paper quotes post-quench and `ϵ = (n_x+n_y+1) + k²/2`, `k = 2πn/L`.

The paper states `T = 0.5T_c` without printing `T_c`; deriving it from the stated
geometry is the difference between reproducing the protocol and guessing at it.
"""
function ideal_torus_Tc(; L::Float64=KZ_L, g1::Float64=KZ_G1, mu0::Float64=KZ_MU0,
    nmax::Int=400, kmax::Int=2000)
    N_target = mu0 * L / g1
    N_exc = function (T)
        s = 0.0
        for nx in 0:nmax, ny in 0:nmax
            e_t = nx + ny + 1.0
            e_t - 1.0 > 60T && continue
            for n in (-kmax):kmax
                e = e_t + 0.5 * (2π * n / L)^2 - 1.0
                (e <= 0 || e / T > 60) && continue
                s += 1 / (exp(e / T) - 1)
            end
        end
        s
    end
    lo, hi = 0.05, 200.0
    for _ in 1:60
        mid = 0.5 * (lo + hi)
        N_exc(mid) < N_target ? (lo = mid) : (hi = mid)
    end
    0.5 * (lo + hi)
end

"""
    winding_number(psi, grid) -> Float64

`W = θ_c/2π`, the phase accumulated around the ring. Summing the *wrapped*
increments is what makes this a winding: an unwrapped `arg` would jump by 2π at
the branch cut and count that as circulation.
"""
function winding_number(psi::AbstractArray{<:Complex}, ::Grid{1})
    ψ = @view psi[:, size(psi, 2)]
    n = length(ψ)
    θ = 0.0
    for j in 1:n
        d = angle(ψ[mod1(j + 1, n)]) - angle(ψ[j])
        θ += d - 2π * round(d / (2π))
    end
    θ / (2π)
end

"""
    kz_trajectory_torus(; tau_Q, seed, energy_damping, …) -> (; W, N_final, N_equil, t)

One realisation: relax at `μ = −μ₀`, ramp `μ` linearly to `+μ₀` over `2τ_Q`, hold
for ten relaxation times, return the winding number.

The relaxation stage uses `γ = 1` and the quench uses `γ = 10⁻²`, exactly as the
paper does. That split is the point: the equilibrium is independent of `γ`, so a
large `γ` is legitimate for reaching it and only the quench needs the physical
rate. Growing a C region from vacuum at the small rate does not converge — a mode
relaxes at `2γ(ϵ−μ)`, which vanishes where the occupation is largest.
"""
function kz_trajectory_torus(;
    tau_Q::Float64, seed::Int, T::Float64, eps_cut::Float64,
    gamma::Float64=1e-2, gamma_relax::Float64=1.0, M_damp::Float64=0.0,
    dt::Float64=0.01, backend=CPUBackend(),
)
    grid = make_grid(GridConfig((KZ_M,), (KZ_L,)))
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict{Int, Float64}(0 => KZ_G1)),
        potential=HarmonicTrap{1}((0.0,)),      # ring: no confinement along it
        sim_params=sp, backend, fft_flags=FFTW.ESTIMATE)
    seed_device_rng!(backend, seed)
    fill!(ws.state.psi, 0)
    dV = cell_volume(grid)
    k_cut = sqrt(2 * (eps_cut - 0.0))

    # γ is PINNED here, as in the paper. It is not derived, and this is the one
    # place that is defensible: the comparison is number-damping vs full at the
    # SAME γ, and an exponent is a rate-independent statement. The derived value
    # is reported alongside so the gap is visible rather than assumed away.
    mk(γ, μ, Md) = SPGPEReservoir(; T, mu=μ, a_s=KZ_AS, k_cut, gamma=γ, M=Md,
        allow_unphysical_rates=true)

    # (1) relax to equilibrium at μ = −μ₀. τ ≡ ℏ/(γ|μ|) = 1 at γ = 1, |μ| = μ₀.
    res_relax = mk(gamma_relax, -KZ_MU0, 0.0)
    for s in 1:round(Int, 1000.0 / dt)
        split_step!(ws)
        apply_spgpe_step!(ws, res_relax, dt; t=0.0, seed=seed + s)
    end
    # NOTE the caller's contract: `seed` must be separated between trajectories by
    # more than the step count, because the per-step seed is `seed + s`. With
    # consecutive trajectory seeds the noise sequences are the SAME sequence
    # shifted by one step — measured, four "independent" runs gave ⟨W⟩ = 2.25 with
    # every sign the same, which is not an ensemble at all. `kz_winding_scan`
    # strides by KZ_SEED_STRIDE.
    N_equil = real(sum(abs2, ws.state.psi)) * dV

    # (2) the quench: μ(t) = μ₀ t/τ_Q over t ∈ [−τ_Q, τ_Q], then held at +μ₀ for
    #     ten relaxation times, τ = 1/(γ μ₀) = 100 at γ = 10⁻².
    t_hold = 10.0 / (gamma * KZ_MU0)
    μ_wave = PiecewiseLinearWaveform([0.0, 2tau_Q, 2tau_Q + t_hold],
        [-KZ_MU0, KZ_MU0, KZ_MU0])
    res = mk(gamma, μ_wave, M_damp)
    t = 0.0
    for s in 1:round(Int, (2tau_Q + t_hold) / dt)
        split_step!(ws)
        apply_spgpe_step!(ws, res, dt; t=t, seed=seed + 1_000_003 + s)
        t += dt
    end

    psi = Array(ws.state.psi)
    (; W=winding_number(psi, grid), N_final=real(sum(abs2, psi)) * dV, N_equil,
        t_total=1000.0 + 2tau_Q + t_hold)
end

"""
    kz_winding_scan(; tau_Qs, n_traj, energy_damping, …) -> (; beta, beta_err, …)

`σ(W)` against `τ_Q`, and the fitted `β` in `σ(W) ∝ τ_Q^(−β)`.

`σ(W)` is a *width*, so its own uncertainty is `σ/√(2(n−1))` — reported, because
with the ensembles this is affordable at, that uncertainty is what decides
whether 0.124 and 0.097 are distinguishable at all.
"""
function kz_winding_scan(;
    tau_Qs=exp.(2.0:1.0:8.0), n_traj::Int=200, M_damp::Float64=0.0,
    dt::Float64=0.01, backend=CPUBackend(), tag::String="kz_torus",
    T::Float64=NaN, eps_cut::Float64=NaN, gamma::Float64=1e-2,
)
    Tc = ideal_torus_Tc()
    isnan(T) && (T = 0.5Tc)
    isnan(eps_cut) && (eps_cut = KZ_MU0 + T)      # occupation ~1 at the cut
    # Order-of-magnitude only: spgpe_growth_rate is Rooney's THREE-dimensional
    # density of states and this trap is quasi-1D, so the number below is not the
    # quasi-1D rate. It is printed to show that the paper's γ is also far from a
    # first-principles value — which is defensible there and was not in the run
    # this branch retracted, because here the comparison is number-damping against
    # full at the SAME γ and an exponent does not depend on it.
    γ_derived = spgpe_growth_rate(; T, mu=KZ_MU0, eps_cut, a_s=KZ_AS)

    @printf("=== KZ winding, toroidal SPGPE (McDonald & Bradley PRA 92, 033616) ===\n")
    @printf("  L=%.0f  M=%d  g1=%.4f  N_TF=%.0f   T_c=%.3f  T=0.5T_c=%.3f\n",
        KZ_L, KZ_M, KZ_G1, KZ_MU0 * KZ_L / KZ_G1, Tc, T)
    @printf("  eps_cut=%.3f (2mu=%.1f, occ at cut=%.2f)  k_cut=%.3f  C modes≈%d\n",
        eps_cut, 2KZ_MU0, T / (eps_cut - KZ_MU0), sqrt(2eps_cut),
        round(Int, sqrt(2eps_cut) * KZ_L / π))
    @printf("  gamma=%.3g PINNED as in the paper (3D-formula rate %.3g, ratio %.3g — ORDER ONLY, trap is quasi-1D)\n",
        gamma, γ_derived, gamma / γ_derived)
    @printf("  M_damp=%.3g  %s   dt=%.4g   %d trajectories/point\n",
        M_damp, M_damp > 0 ? "FULL SPGPE" : "number-damping only", dt, n_traj)
    @printf("\n  %-10s %-9s %-9s %-10s %-10s %-10s\n",
        "tau_Q", "sigma(W)", "err", "<W>", "<N_equil>", "<N_final>")
    flush(stdout)

    σs, errs = Float64[], Float64[]
    for τ in tau_Qs
        Ws, Ne, Nf = Float64[], Float64[], Float64[]
        for j in 1:n_traj
            r = kz_trajectory_torus(;
                tau_Q=τ, seed=90_000 + round(Int, 1000τ) + j * KZ_SEED_STRIDE,
                T, eps_cut, gamma, M_damp, dt, backend)
            push!(Ws, r.W);
            push!(Ne, r.N_equil);
            push!(Nf, r.N_final)
        end
        σ = std(Ws)
        # ⟨W⟩ must be consistent with zero: the ring has no preferred sense, so a
        # mean far from zero means the trajectories are not independent (or the
        # winding is being computed with a bias). This is the check that caught
        # trajectory seeds separated by 1.
        z_mean = abs(mean(Ws)) / (σ / sqrt(n_traj) + eps())
        z_mean > 4 && @warn "⟨W⟩ is $(round(z_mean; digits=1))σ from zero — the " *
                            "ensemble is not independent or W is biased" τ mean_W=mean(Ws) σ
        # A standard deviation's own error, not the mean's — the quantity fitted
        # here IS the width.
        e = σ / sqrt(2 * (n_traj - 1))
        push!(σs, σ);
        push!(errs, e)
        @printf("  %-10.1f %-9.4f %-9.4f %-10.4f %-10.4g %-10.4g\n",
            τ, σ, e, mean(Ws), mean(Ne), mean(Nf))
        flush(stdout)
    end

    x = log.(collect(tau_Qs));
    y = log.(σs)
    x̄, ȳ = mean(x), mean(y)
    Sxx = sum((x .- x̄) .^ 2)
    slope = sum((x .- x̄) .* (y .- ȳ)) / Sxx
    resid = y .- (ȳ .+ slope .* (x .- x̄))
    β = -slope
    β_err = sqrt(sum(resid .^ 2) / max(length(x) - 2, 1) / Sxx)
    ref = M_damp > 0 ? (0.0966, 0.0128) : (0.1236, 0.0098)
    @printf("\n  beta = %.4f ± %.4f   published %.4f ± %.4f   (%.1f sigma)\n",
        β, β_err, ref[1], ref[2], abs(β - ref[1]) / sqrt(β_err^2 + ref[2]^2))

    mkpath(OUTDIR)
    csv = joinpath(OUTDIR, "$(tag).csv")
    open(csv, "w") do io
        println(io, "# beta=$β beta_err=$β_err published=$(ref[1]) M_damp=$M_damp " *
                    "T=$T eps_cut=$eps_cut gamma=$gamma dt=$dt n_traj=$n_traj")
        println(io, "tau_Q,sigma_W,sigma_W_err")
        for (i, τ) in enumerate(tau_Qs)
            @printf(io, "%.6f,%.8f,%.8f\n", τ, σs[i], errs[i])
        end
    end
    @printf("  wrote %s\n", csv)
    (; tau_Qs=collect(tau_Qs), sigma=σs, errs, beta=β, beta_err=β_err, csv, T, eps_cut)
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = get(ARGS, 1, "smoke")
    backend = get(ENV, "SBEC_KZ_BACKEND", "cpu") == "gpu" ? CUDABackend() : CPUBackend()
    if mode == "smoke"
        # Every code path, smallest ensemble, two shortest quenches. NOT physics.
        kz_winding_scan(; tau_Qs=(exp(2.0), exp(3.0)), n_traj=4, backend,
            tag="kz_torus_smoke")
    elseif mode == "dtconv"
        # dt convergence FIRST: for the SPGPE the time step matters more than the
        # k-space quadrature (Rooney, Blakie & Bradley, PRE 89, 013302).
        for dt in (0.02, 0.01, 0.005)
            kz_winding_scan(; tau_Qs=(exp(4.0),), n_traj=32, dt, backend,
                tag="kz_torus_dt$(replace(string(dt), "." => "p"))")
        end
    elseif startswith(mode, "nd")      # number-damping only
        kz_winding_scan(; n_traj=parse(Int, mode[3:end]), M_damp=0.0, backend,
            tag="kz_torus_nd")
    elseif startswith(mode, "full")
        kz_winding_scan(; n_traj=parse(Int, mode[5:end]), M_damp=1e-2, backend,
            tag="kz_torus_full")
    else
        error("unknown mode $mode")
    end
end
