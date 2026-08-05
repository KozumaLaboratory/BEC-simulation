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

const KZ_L = 200.0                 # circumference, a_perp (the paper's)
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
# The paper's system is a SCALAR field. Running it on an F=1 species gives three
# components, and the reservoir noise is added to every one of them — so the two
# empty spin channels fill thermally and feed the density term c₀n = c₀Σ_c|ψ_c|²,
# shifting the effective chemical potential. A spinless (F=0) species makes the
# field genuinely one-component. The species identity is otherwise irrelevant
# here: in internal units ℏ = m = ω_perp = 1 the mass scales out, and c₀ is
# supplied directly as g₁ rather than taken from the atom's a_s.
const KZ_ATOM = Sr88
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
    winding_of(field) -> Float64

`W = θ_c/2π` for one complex field on a ring, from the WRAPPED phase increments.
"""
function winding_of(ψ::AbstractVector{<:Complex})
    n = length(ψ)
    θ = 0.0
    for j in 1:n
        d = angle(ψ[mod1(j + 1, n)]) - angle(ψ[j])
        θ += d - 2π * round(d / (2π))
    end
    θ / (2π)
end

"""
    spinor_windings(psi, grid) -> (; per_m, mass, spin)

Every winding a spin-1 ring admits, reported together rather than one chosen in
advance:

- `per_m[c]` — the phase winding of component `c`.
- `mass` — the winding of `Σ_c ψ_c`.
- `spin` — the winding of the transverse spin `ψ_{+1}*ψ_0 + ψ_0*ψ_{−1}`, the order
  parameter a ferromagnetic ring winds in, invariant under a global phase.

Which of these carries the Kibble-Zurek scaling is a measurement, not a choice: a
spin rotation mixes the `m` components and changes `per_m`, mass winding misses a
spin defect, and the topological classification depends on the sign of `c₁`, which
for ¹⁵¹Eu is unknown. Reporting one number here would bake in an assumption of
exactly the kind that produced this branch's retracted results.
"""
function spinor_windings(psi::AbstractArray{<:Complex}, ::Grid{1})
    D = size(psi, 2)
    per_m = [winding_of(@view psi[:, c]) for c in 1:D]
    mass = winding_of(vec(sum(psi; dims=2)))
    spin = D == 3 ?
           winding_of(@views conj.(psi[:, 1]) .* psi[:, 2] .+
                             conj.(psi[:, 2]) .* psi[:, 3]) : NaN
    (; per_m, mass, spin)
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
    dt::Float64=0.01, M_grid::Int=KZ_M, backend=CPUBackend(),
    t_hold::Float64=NaN, n_probe::Int=0, L::Float64=KZ_L,
    spinor::Bool=false, c1::Float64=0.0, atom=KZ_ATOM,
)
    grid = make_grid(GridConfig((M_grid,), (L,)))
    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    ws = make_workspace(; grid, atom,
        interactions=InteractionParams(
            spinor ? Dict{Int, Float64}(0 => KZ_G1, 1 => c1) :
            Dict{Int, Float64}(0 => KZ_G1)),
        potential=HarmonicTrap{1}((0.0,)),      # ring: no confinement along it
        sim_params=sp, backend, fft_flags=FFTW.ESTIMATE)
    # Reservoir noise fills EVERY component, so on an F=1 species a scalar run's
    # empty spin channels thermalise and shift the effective μ through c₀n — a live
    # bug that showed as non-integer windings (2.25). A spinor run wants those
    # components and says so with `spinor=true`.
    spinor || size(ws.state.psi, 2) == 1 || error(
        "kz_toroidal_winding without spinor=true is a SCALAR reproduction and the " *
        "field has $(size(ws.state.psi, 2)) components; noise would " *
        "spin channels and shift mu through c0*n.")
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
    # "a further 10 units of relaxation time" with τ ≡ ℏ/(γ|μ|) is ambiguous in
    # the source: at the quench's γ = 10⁻² that is 1000 time units, at the
    # relaxation stage's γ = 1 it is 10. A hundredfold difference, and for
    # τ_Q = 7.4 the longer reading holds the system for 68x the quench itself —
    # long enough to relax away whatever the quench imprinted, which is what a
    # σ(W) flat in τ_Q looks like.
    isnan(t_hold) && (t_hold = 10.0 / (gamma * KZ_MU0))
    μ_wave = PiecewiseLinearWaveform([0.0, 2tau_Q, 2tau_Q + t_hold],
        [-KZ_MU0, KZ_MU0, KZ_MU0])
    res = mk(gamma, μ_wave, M_damp)
    n_steps_q = round(Int, (2tau_Q + t_hold) / dt)
    # N₀ = |∫ψ dx|²/L is the k=0 population on a ring: for a uniform ψ = √n it
    # returns nL = N exactly, so it needs no normalisation convention argued over.
    probe_t = Float64[];
    probe_N0 = Float64[]
    every = n_probe > 0 ? max(1, n_steps_q ÷ n_probe) : typemax(Int)
    t = 0.0
    for s in 1:n_steps_q
        split_step!(ws)
        apply_spgpe_step!(ws, res, dt; t=t, seed=seed + 1_000_003 + s)
        t += dt
        if s % every == 0
            ψ = ws.state.psi
            push!(probe_t, t - tau_Q)              # measured FROM the transition
            push!(probe_N0, abs2(sum(ψ)) * cell_volume(grid)^2 / L)
        end
    end

    psi = Array(ws.state.psi)
    # ξ̂ measured directly from g₁(r) on the ring, not inferred from σ(W). The
    # two must agree — σ(W)² ≈ L/(4ξ̂) for a phase random-walking over L/ξ̂
    # domains — and if they do not, the disagreement localises the error.
    hplans = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    rr, g1 = first_order_correlation(psi, grid, hplans)
    cl = coherence_length(rr, g1)
    sw = spinor_windings(psi, grid)
    pops = [real(sum(abs2, view(psi, :, c))) * dV for c in 1:size(psi, 2)]
    (; W=winding_number(psi, grid), N_final=real(sum(abs2, psi)) * dV, N_equil,
        xi_hat=cl.xi, f_inf=cl.f_inf, probe_t, probe_N0,
        W_per_m=sw.per_m, W_mass=sw.mass, W_spin=sw.spin, pops,
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
    dt::Float64=0.01, M_grid::Int=KZ_M, backend=CPUBackend(), tag::String="kz_torus",
    shard::Tuple{Int, Int}=(1, 1), raw_only::Bool=false, t_hold::Float64=NaN,
    spinor::Bool=false, c1::Float64=0.0, atom=KZ_ATOM, which_W::Symbol=:auto,
    L::Float64=KZ_L,
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
    @printf("  M_damp=%.3g  %s   dt=%.4g  M_grid=%d (k_max=%.2f, %.1fx k_cut)   %d traj/point\n",
        M_damp, M_damp > 0 ? "FULL SPGPE" : "number-damping only", dt, M_grid,
        π * M_grid / KZ_L, π * M_grid / KZ_L / sqrt(2eps_cut), n_traj)
    @printf("\n  %-10s %-9s %-9s %-10s %-10s %-10s %-8s\n",
        "tau_Q", "sigma(W)", "err", "<W>", "<N_equil>", "<N_final>", "int(W)")
    flush(stdout)

    σs, errs = Float64[], Float64[]
    all_W = Vector{Vector{Float64}}()
    for τ in tau_Qs
        Ws, Ne, Nf = Float64[], Float64[], Float64[]
        # Shards are strided, not blocked, so a shard that dies leaves the survivors
        # spread over the whole seed range rather than a contiguous hole.
        for j in shard[1]:shard[2]:n_traj
            r = kz_trajectory_torus(;
                tau_Q=τ, seed=90_000 + round(Int, 1000τ) + j * KZ_SEED_STRIDE,
                T, eps_cut, gamma, M_damp, dt, M_grid, backend, t_hold, L,
                spinor, c1, atom)
            # For a spinor, WHICH winding scales is the question, so the choice is
            # explicit and the others go on the record rather than being discarded.
            push!(Ws, which_W === :mass ? r.W_mass :
                      which_W === :spin ? r.W_spin : r.W)
            spinor && j == shard[1] && @printf(
                "    [tau=%.0f seed1] per_m=%s mass=%.2f spin=%.2f pops=%s\n",
                τ, string(round.(r.W_per_m; digits=2)), r.W_mass, r.W_spin,
                string(round.(r.pops; sigdigits=3)))
            push!(Ne, r.N_equil);
            push!(Nf, r.N_final)
        end
        σ = std(Ws)
        # ⟨W⟩ must be consistent with zero: the ring has no preferred sense, so a
        # mean far from zero means the trajectories are not independent (or the
        # winding is being computed with a bias). This is the check that caught
        # trajectory seeds separated by 1.
        # W must come out near-integer. A c-field's phase is not perfectly smooth,
        # but a well-formed condensate winds by whole turns — and the run that was
        # accidentally three-component returned 2.25. This is a free check that
        # the field being measured is a condensate at all.
        frac_int = count(w -> abs(w - round(w)) < 0.1, Ws) / length(Ws)
        frac_int < 0.8 && @warn "only $(round(100frac_int))% of windings are " *
                                "near-integer — the phase is not a clean condensate" τ
        z_mean = abs(mean(Ws)) / (σ / sqrt(length(Ws)) + eps())
        z_mean > 4 && @warn "⟨W⟩ is $(round(z_mean; digits=1))σ from zero — the " *
                            "ensemble is not independent or W is biased" τ mean_W=mean(Ws) σ
        # A standard deviation's own error, not the mean's — the quantity fitted
        # here IS the width.
        # length(Ws), NOT n_traj: a shard runs a strided SUBSET, and using the
        # full count understated this by sqrt(1000/63) = 4x — which would have
        # made agreement with the published beta look four times more significant
        # than the data supports.
        e = σ / sqrt(2 * (length(Ws) - 1))
        push!(σs, σ);
        push!(errs, e);
        push!(all_W, Ws)
        @printf("  %-10.1f %-9.4f %-9.4f %-10.4f %-10.4g %-10.4g %-8.2f\n",
            τ, σ, e, mean(Ws), mean(Ne), mean(Nf), frac_int)
        flush(stdout)
    end

    x = log.(collect(tau_Qs));
    y = log.(σs)
    x̄, ȳ = mean(x), mean(y)
    Sxx = sum((x .- x̄) .^ 2)
    slope = sum((x .- x̄) .* (y .- ȳ)) / Sxx
    resid = y .- (ȳ .+ slope .* (x .- x̄))
    β = -slope
    # With two points the line passes through both and the residual-based error is
    # identically zero — a structural zero, not a tight measurement. Refuse it.
    β_err = length(x) >= 3 ? sqrt(sum(resid .^ 2) / (length(x) - 2) / Sxx) : NaN
    ref = M_damp > 0 ? (0.0966, 0.0128) : (0.1236, 0.0098)
    @printf("\n  beta = %.4f ± %.4f   published %.4f ± %.4f   (%.1f sigma)\n",
        β, β_err, ref[1], ref[2], abs(β - ref[1]) / sqrt(β_err^2 + ref[2]^2))

    mkpath(OUTDIR)
    # Raw W per trajectory, not just the width: sigma(W) is one number distilled
    # from a distribution whose SHAPE is itself a check (windings must be
    # integers, the mean must vanish, and the literature's defect counts are
    # Poissonian). Distilling first throws away the evidence.
    if raw_only
        rawf = joinpath(OUTDIR, "$(tag)_raw.csv")
        open(rawf, "w") do io
            # First line, so a reader hits it before any data. assert_same_provenance
            # refuses to merge shards that disagree — which is the guard that was
            # missing when a merge read 10:49 files as a 13:34 rerun's output.
            println(io, provenance_header("src/solvers/spgpe.jl",
                "src/solvers/projected_gp.jl", "docs/guides/figures/kz_toroidal_winding.jl"))
            println(io, "# T=$T eps_cut=$eps_cut gamma=$gamma M_damp=$M_damp dt=$dt " *
                        "M_grid=$M_grid shard=$(shard[1])of$(shard[2])")
            println(io, "tau_Q,W")
            for (i, τ) in enumerate(tau_Qs), w in all_W[i]
                @printf(io, "%.6f,%.10f\n", τ, w)
            end
        end
        @printf("  wrote %s\n", rawf)
        return (; tau_Qs=collect(tau_Qs), all_W, T, eps_cut)
    end
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
    # Parse-only. A typo in a mode string used to cost a 20-hour reservation that
    # died on its first line — 48 shards did exactly that on `-6.4e-5`, which the
    # spin1 parser rejected because it accepted only `[0-9.]`. Nothing else looks at
    # a mode string: CI was green and the submit script's dirty check passed. Every
    # submit script now calls this before qsub, so the cost of a typo is a second.
    if mode == "--check-mode"
        want = get(ARGS, 2, "")
        pats = (
            r"^spin1\d+of\d+:-?[-+0-9.eE]+:(nd|full):\d+:(mass|spin|m)$",
            r"^gam\d+of\d+:[0-9.]+:(nd|full):\d+(:L[0-9.]+)?$",
            r"^shard\d+of\d+:(nd|full):\d+$",
            r"^slow\d+of\d+:(nd|full):\d+$",
            r"^merge:\S+$",
            r"^(smoke|conv|freeze|size|hold|dtconv)$",
            r"^(xi|kcut|rate|physq)[0-9._]+$",
        )
        ok = any(!isnothing(match(r, want)) for r in pats)
        println(ok ? "OK $want" : "REJECT $want")
        exit(ok ? 0 : 1)
    end
    backend = get(ENV, "SBEC_KZ_BACKEND", "cpu") == "gpu" ? CUDABackend() : CPUBackend()
    if mode == "smoke"
        # Every code path, smallest ensemble, two shortest quenches. NOT physics.
        kz_winding_scan(; tau_Qs=(exp(2.0), exp(3.0)), n_traj=4, backend,
            tag="kz_torus_smoke")
    elseif mode == "conv"
        # dt AND grid convergence, before any production run. For the SPGPE the
        # time step matters more than the k-space quadrature (Rooney, Blakie &
        # Bradley, PRE 89, 013302), and the grid is worth testing because
        # k_cut = 2.01 puts only 128 of the paper's 1024 modes inside the C
        # region — the rest are projected away every step. M = 256 still leaves
        # k_max = 4.0, i.e. 2x k_cut, which clears the 3/2 dealiasing margin.
        #
        # A cheaper setting is only allowed if sigma(W) does not move. That is
        # the same discipline the literature applies to the cutoff itself
        # (results must be stable under a 10-15% variation).
        # Ordered by what decides the question, not by cost: the paper's setting
        # and the cheap candidate first, so a job that runs out of wall time still
        # answers it.
        for (dt, Mg) in ((0.01, 1024), (0.05, 256), (0.01, 256),
            (0.02, 1024), (0.01, 512), (0.005, 1024))
            kz_winding_scan(; tau_Qs=(exp(4.0),), n_traj=64, dt, M_grid=Mg, backend,
                tag="kz_torus_conv_dt$(replace(string(dt), "." => "p"))_M$(Mg)")
        end
    elseif mode == "dtconv"
        # dt convergence FIRST: for the SPGPE the time step matters more than the
        # k-space quadrature (Rooney, Blakie & Bradley, PRE 89, 013302).
        for dt in (0.02, 0.01, 0.005)
            kz_winding_scan(; tau_Qs=(exp(4.0),), n_traj=32, dt, backend,
                tag="kz_torus_dt$(replace(string(dt), "." => "p"))")
        end
    elseif startswith(mode, "gam")
        # "gamIofN:GAMMA:MD:NTRAJ" — the test the range choice was missing.
        #
        # beta was reported as 0.0991 +- 0.0067 against a published 0.0966 and
        # that claim is withdrawn: the LOCAL slope drifts across the window
        # (0.066, 0.099, 0.045, 0.131, 0.133, 0.120), so the global fit averages a
        # changing slope rather than measuring an exponent. Choosing the window
        # and reading off a number that lands on the target is a fit with extra
        # steps.
        #
        # The window has to come from somewhere independent, and it does: the
        # MEASURED freeze-out t_hat = 3.4 sqrt(tau_Q/(gamma mu_0)) must be small
        # against the ramp. At gamma = 1e-2 the ratio t_hat/tau_Q runs
        # 3.40 2.06 1.25 0.76 0.46 0.28 0.17 over the scan — the first four points
        # are outside the regime by construction, and even the best is 0.17.
        # Reaching 0.05 needs tau_Q > 4.6e5, an hour per trajectory.
        #
        # gamma buys it back: t_hat/tau_Q = 3.4/sqrt(gamma mu_0 tau_Q), so ten
        # times the rate reaches the same ratio at a tenth of tau_Q. And the
        # exponent MUST NOT depend on gamma — gamma sets tau_0, not the scaling.
        # So the same window in t_hat/tau_Q at three rates is simultaneously the
        # affordable measurement and the check that the number is an exponent at
        # all rather than a local slope.
        m = match(r"^gam(\d+)of(\d+):([0-9.]+):(nd|full):(\d+)(?::L([0-9.]+))?$", mode)
        m === nothing && error("gam mode: gamIofN:GAMMA:nd|full:NTRAJ[:L<len>], got $mode")
        i, n = parse(Int, m[1]), parse(Int, m[2])
        γ = parse(Float64, m[3])
        # xi_hat = L/(4 sigma(W)^2) reached 145-153 on the paper's ring of 200 at
        # the slow end of the FULL runs — three quarters of the circumference. The
        # winding cannot fall further once a single domain spans the ring, so the
        # last interval flattens and beta is biased low. The size test already
        # showed xi_hat is physical and sigma(W) ∝ sqrt(L), so a longer ring buys
        # headroom without changing the length being measured.
        local Lr = m[6] === nothing ? KZ_L : parse(Float64, m[6])
        local Mg = round(Int, 256 * Lr / KZ_L)      # dx held fixed
        # Fixed window in t_hat/tau_Q = 3.4/sqrt(gamma tau_Q): span the same
        # ratios 0.34 … 0.034 at every gamma, i.e. tau_Q = 100/gamma … 1e4/gamma.
        τs = (1 / γ) .* [1e2, 3e2, 1e3, 3e3, 1e4]
        kz_winding_scan(; tau_Qs=τs, n_traj=parse(Int, m[5]),
            M_damp=(m[4] == "full" ? γ : 0.0), gamma=γ, dt=0.05, M_grid=Mg, L=Lr,
            backend, shard=(i, n), raw_only=true,
            # SBEC_TAG lets a rerun after a code change write somewhere new. Reusing
            # the tag once let a merge read 10:49 files as if they were the 13:34
            # run's output and report the pre-fix numbers as post-fix — the same
            # shape as leaving a distinguishing variable out of an output name.
            tag="kz_torus_$(get(ENV, "SBEC_TAG", ""))gam$(replace(string(γ), "." => "p"))$(m[4])L$(round(Int, Lr))_s$(i)of$(n)")
    elseif startswith(mode, "size")
        # Is xi_hat physical or is it the ring? It came out 20-37 at every quench
        # rate on a ring of 200 — L/6, six to eight domains, which is no dynamic
        # range for sigma(W) to have. Quadruple the circumference at fixed
        # everything else: a physical xi_hat stays put and sigma(W)^2 doubles
        # (more domains on a longer ring); a finite-size-limited one grows with L
        # and sigma(W) does not move.
        #
        # dx is held fixed at L/M so the resolution is identical — only the box
        # changes.
        for L in (200.0, 400.0, 800.0)
            Mg = round(Int, 256 * L / KZ_L)
            Ws, ξs = Float64[], Float64[]
            for j in 1:24
                r = kz_trajectory_torus(; tau_Q=1000.0,
                    seed=7_000_000 + j * KZ_SEED_STRIDE,
                    T=0.5 * ideal_torus_Tc(), eps_cut=KZ_MU0 + 0.5 * ideal_torus_Tc(),
                    M_damp=0.0, dt=0.05, M_grid=Mg, L, backend)
                push!(Ws, r.W);
                push!(ξs, r.xi_hat)
            end
            σW = std(Ws)
            fin = filter(isfinite, ξs)
            @printf("L=%6.0f M=%5d dx=%.3f  sigma(W)=%.3f ± %.3f  xi(from W)=%5.1f  xi(g1)=%5.1f ± %4.1f  L/xi=%.1f\n",
                L, Mg, L / Mg, σW, σW / sqrt(2 * 23),
                L / (4σW^2), mean(fin), std(fin) / sqrt(max(length(fin), 1)),
                L / mean(fin))
            flush(stdout)
        end
    elseif startswith(mode, "freeze")
        # The three quantities that have to agree, and never have been compared:
        #
        #  (1) t_hat, the delay in condensate growth after the transition. The ramp
        #      argument gives t_hat = sqrt(tau_Q/(gamma mu_0)); the published
        #      alpha = 0.5119 says t_hat ∝ tau_Q^(1/2). If there is no delay, there
        #      is no freeze-out and nothing downstream can be Kibble-Zurek.
        #  (2) xi_hat measured directly from g1(r) on the ring.
        #  (3) sigma(W)² ≈ L/(4 xi_hat), the random walk of phase over L/xi_hat
        #      domains.
        #
        # sigma(W) = 1.4 implies xi_hat ≈ 25 a_perp where KZ predicts ≈ 1.65 — a
        # factor of 15 that no choice of tau_Q range can absorb, since the exponent
        # is 1/4. Measuring all three separates "the scan is in the wrong regime"
        # from "the observable is wrong" from "the dynamics has no freeze-out".
        #
        # The threshold defining t_hat is SWEPT, because a threshold that sets the
        # answer is how a condensate fraction once passed for a coherence length.
        τs = [1e2, 1e3, 1e4]
        for τ in τs
            Ws, ξs, Ts, N0s = Float64[], Float64[], Vector{Float64}[], Vector{Float64}[]
            for j in 1:24
                r = kz_trajectory_torus(; tau_Q=τ, seed=5_000_000 + j * KZ_SEED_STRIDE,
                    T=0.5 * ideal_torus_Tc(), eps_cut=KZ_MU0 + 0.5 * ideal_torus_Tc(),
                    M_damp=0.0, dt=0.05, M_grid=256, backend, n_probe=400)
                push!(Ws, r.W);
                push!(ξs, r.xi_hat)
                push!(Ts, r.probe_t);
                push!(N0s, r.probe_N0)
            end
            N_TF = KZ_MU0 * KZ_L / KZ_G1
            tgrid = Ts[1]
            N0bar = [mean(N0s[j][i] for j in eachindex(N0s)) for i in eachindex(tgrid)]
            @printf("\ntau_Q = %.0f   t_hat_predicted = %.1f\n", τ, sqrt(τ / 1e-2))
            for thr in (0.02, 0.05, 0.10, 0.20)
                ic = findfirst(>(thr * N_TF), N0bar)
                @printf("   threshold %4.0f%% of N_TF -> t_hat = %s\n", 100thr,
                    ic === nothing ? "never" : @sprintf("%.1f", tgrid[ic]))
            end
            σW = std(Ws)
            ξ_from_W = KZ_L / (4 * σW^2)
            @printf("   sigma(W) = %.3f -> xi_hat(from W) = %.1f ;  xi_hat(from g1) = %.2f ± %.2f\n",
                σW, ξ_from_W, mean(filter(isfinite, ξs)),
                std(filter(isfinite, ξs)) / sqrt(max(count(isfinite, ξs), 1)))
            flush(stdout)
        end
    elseif startswith(mode, "slow")
        # "slowIofN:nd|full:NTRAJ" — the tau_Q range the FREEZE-OUT requires.
        #
        # During the ramp |mu(t)| = mu_0 |t|/tau_Q, so the relaxation time is
        # tau_Q/(gamma mu_0 |t|). Setting that equal to the time still to run, |t|,
        # gives the freeze-out
        #
        #     t_hat = sqrt(tau_Q/(gamma mu_0)) = sqrt(100 tau_Q)
        #
        # — and t_hat ∝ tau_Q^(1/2) is the published alpha = 0.5119. Scaling can
        # only appear where t_hat < tau_Q, i.e.
        #
        #     tau_Q > 1/(gamma mu_0) = 100.
        #
        # The first scan ran 7.4 … 2981 with FOUR of seven points below that,
        # frozen through the entire ramp. The measured sigma(W) says the same: it
        # is flat until the last three points, and fitting only those gives
        # beta = 0.082 for the full SPGPE against a published 0.0966 ± 0.0128.
        #
        # So the paper's e² … e⁸ is in units of the relaxation time tau =
        # hbar/(gamma mu_0) = 100/omega_perp, not of 1/omega_perp. Read that way
        # every point sits at least 7x above the crossover.
        m = match(r"^slow(\d+)of(\d+):(nd|full):(\d+)$", mode)
        m === nothing && error("slow mode: slowIofN:nd|full:NTRAJ, got $mode")
        i, n = parse(Int, m[1]), parse(Int, m[2])
        τ_relax = 1 / (1e-2 * KZ_MU0)
        # The number-damping case leaves the saturated regime later than the full
        # one: over 100 … 40343 its residual is 2.3x the propagated error, the
        # first four points are flat, and only the last three fall. Shifting the
        # window up by two e-folds rather than trimming points off the bottom —
        # trimming would be choosing the range from the answer.
        span = get(ENV, "SBEC_SPAN", "0") == "2" ? (2.0:1.0:8.0) : (0.0:1.0:6.0)
        kz_winding_scan(; tau_Qs=τ_relax .* exp.(span),
            n_traj=parse(Int, m[4]), M_damp=(m[3] == "full" ? 1e-2 : 0.0),
            dt=0.05, M_grid=256, backend, shard=(i, n), raw_only=true,
            tag="kz_torus_slow$(m[3])_s$(i)of$(n)")
    elseif startswith(mode, "hold")
        # Does the post-quench hold erase the imprint? beta came out 0.012 against
        # a published 0.124 with a hold of 1000 time units — 68x the quench itself
        # at the fast end. Vary only that.
        for th in (10.0, 100.0, 1000.0)
            kz_winding_scan(; n_traj=200, M_damp=0.0, dt=0.05, M_grid=256, backend,
                t_hold=th, tag="kz_torus_hold$(round(Int, th))")
        end
    elseif startswith(mode, "merge")
        # "merge:nd" / "merge:full" — read every shard's RAW windings, then do the
        # statistics once, on the pooled sample.
        md = split(mode, ":")[2]
        # `occursin`, not `==`: the tag is "slowfull" for the extended scan, and
        # comparing exactly printed the full-SPGPE data against the
        # number-damping reference — a mislabel that flatters or damns the result
        # by whichever number it happens to grab.
        is_full = occursin("full", md)
        files = filter(f -> startswith(f, "kz_torus_$(md)_s") && endswith(f, "_raw.csv"),
            readdir(OUTDIR))
        isempty(files) && error("no raw shards for $md in $OUTDIR")
        # Refuse rather than average across code versions.
        prov = assert_same_provenance(joinpath.(OUTDIR, files))
        println(prov)
        byτ = Dict{Float64, Vector{Float64}}()
        for f in files, ln in eachline(joinpath(OUTDIR, f))
            (isempty(ln) || startswith(ln, "#") || startswith(ln, "tau_Q")) && continue
            a_, b_ = split(ln, ",")
            push!(get!(byτ, parse(Float64, a_), Float64[]), parse(Float64, b_))
        end
        τs = sort(collect(keys(byτ)))
        @printf("=== %s [%s], %d shards ===\n",
            is_full ? "FULL SPGPE" : "number-damping", md, length(files))
        @printf("%-10s %-6s %-9s %-9s %-9s %-8s %-8s\n",
            "tau_Q", "n", "sigma(W)", "err", "<W>", "z(<W>)", "int(W)")
        σs, es = Float64[], Float64[]
        for τ in τs
            W = byτ[τ]
            nW = length(W)
            σ = std(W)
            e = σ / sqrt(2 * (nW - 1))
            z = abs(mean(W)) / (σ / sqrt(nW))
            fi = count(w -> abs(w - round(w)) < 0.1, W) / nW
            push!(σs, σ);
            push!(es, e)
            @printf("%-10.1f %-6d %-9.4f %-9.4f %-9.4f %-8.2f %-8.2f\n",
                τ, nW, σ, e, mean(W), z, fi)
            z > 4 && @warn "⟨W⟩ is $(round(z; digits=1))σ from zero" τ
            fi < 0.8 && @warn "only $(round(100fi))% integer windings" τ
        end

        # Every point has the same n, so log σ carries the same error at each and
        # an unweighted fit is the right one. The error on β then comes from that
        # error propagated, which is a statement about the data; the residual-based
        # error is a statement about the fit. Report both and take the larger.
        x = log.(τs);
        y = log.(σs)
        x̄, ȳ = mean(x), mean(y)
        Sxx = sum((x .- x̄) .^ 2)
        slope = sum((x .- x̄) .* (y .- ȳ)) / Sxx
        β = -slope
        δlogσ = mean(es ./ σs)
        β_prop = δlogσ / sqrt(Sxx)
        resid = y .- (ȳ .+ slope .* (x .- x̄))
        β_resid = sqrt(sum(resid .^ 2) / (length(x) - 2) / Sxx)
        β_err = max(β_prop, β_resid)
        ref = is_full ? (0.0966, 0.0128) : (0.1236, 0.0098)
        @printf("\nbeta = %.4f ± %.4f  (propagated %.4f, residual %.4f)\n",
            β, β_err, β_prop, β_resid)
        @printf("published %.4f ± %.4f   ->  %.1f sigma\n",
            ref[1], ref[2], abs(β - ref[1]) / sqrt(β_err^2 + ref[2]^2))
        open(joinpath(OUTDIR, "kz_torus_$(md)_merged.csv"), "w") do io
            println(io, "# beta=$β beta_err=$β_err published=$(ref[1]) shards=$(length(files))")
            println(io, "tau_Q,n,sigma_W,sigma_W_err")
            for (i, τ) in enumerate(τs)
                @printf(io, "%.6f,%d,%.8f,%.8f\n", τ, length(byτ[τ]), σs[i], es[i])
            end
        end
    elseif startswith(mode, "spin1")
        # Step 1 of the ladder, on the VALIDATED protocol: toroidal, mu ramp,
        # gamma = 0.1, L = 800, tau_Q spanning the freeze-out — where beta reproduced
        # at 0.6 sigma (number-damping) and 0.05 sigma (full). Only c1 != 0 and three
        # components change.
        #
        # "spin1IofN:C1:nd|full:NTRAJ:mass|spin|m". The winding is NAMED, not assumed:
        # one trajectory at tau_Q = 1000 gave per_m = [+1, -1, 0], mass = 0, spin = -1
        # for the same field, so the mass winding says no defect and the spin winding
        # says one. All three print for seed 1 at every rate.
        #
        # C1 takes exponent notation. `[0-9.]` rejected -6.4e-5 and killed 48 shards
        # on their first line with the 20-hour reservations already made.
        m = match(
            r"^spin1(\d+)of(\d+):(-?[-+0-9.eE]+):(nd|full):(\d+):(mass|spin|m)$", mode)
        m === nothing && error(
            "spin1 mode: spin1IofN:C1:nd|full:NTRAJ:mass|spin|m, got $mode")
        local i1 = parse(Int, m[1])
        local n1 = parse(Int, m[2])
        local c1v = parse(Float64, m[3])
        local g1v = 0.1
        local which = m[6] == "m" ? :auto : Symbol(m[6])
        # SBEC_MAX_RATES truncates the list for the pre-flight smoke. The smoke then
        # exercises THIS branch — its regex, its parsing, its kwargs, a real
        # trajectory — and only the rate list differs, which is declared rather than
        # a second code path. What it does NOT establish is that the slowest rate
        # fits the wall clock; that is a separate claim and is not being made.
        local nrates = parse(Int, get(ENV, "SBEC_MAX_RATES", "5"))
        local rates = ((1 / g1v) .* [1e2, 3e2, 1e3, 3e3, 1e4])[1:min(nrates, 5)]
        kz_winding_scan(; tau_Qs=rates,
            n_traj=parse(Int, m[5]), M_damp=(m[4] == "full" ? g1v : 0.0), gamma=g1v,
            dt=0.05, M_grid=1024, L=800.0, spinor=true, c1=c1v, atom=Rb87,
            which_W=which, backend, shard=(i1, n1), raw_only=true,
            tag="kz_torus_spin1c" * replace(string(c1v), "." => "p", "-" => "m") *
                m[4] * m[6] * "_s$(i1)of$(n1)")
    elseif startswith(mode, "shard")
        # "shardIofN:MD:NTRAJ" — one process per shard, strided over trajectories.
        # Trajectories are independent, and the per-step cost is small enough that
        # process-level parallelism beats threading, which would race on the
        # package's global scratch buffers.
        m = match(r"^shard(\d+)of(\d+):(nd|full):(\d+)$", mode)
        m === nothing && error("shard mode: shardIofN:nd|full:NTRAJ, got $mode")
        i, n = parse(Int, m[1]), parse(Int, m[2])
        md = m[3] == "full" ? 1e-2 : 0.0
        kz_winding_scan(; n_traj=parse(Int, m[4]), M_damp=md, dt=0.05, M_grid=256,
            backend, shard=(i, n), raw_only=true,
            tag="kz_torus_$(m[3])_s$(i)of$(n)")
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
