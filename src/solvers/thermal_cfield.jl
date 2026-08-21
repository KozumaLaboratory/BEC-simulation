export classical_field_equilibrium, thermal_cfield!
export incoherent_lda, mu_from_total_lda

"""
    classical_field_equilibrium(; T, mu, c0, omega=1.0, n_T=1.0, rmax, nr) -> (; r, n0, nth, N0, Nth, T_c_crossed)

Self-consistent Hartree–Fock equilibrium of the classical (Rayleigh–Jeans) field
in an isotropic harmonic trap, in the local-density approximation:

    c₀n₀(r) = max(μ − V(r) − 2c₀n_th(r), 0)
    n_th(r) = (T/π²)[K − √(2Δ) arctan(K/√(2Δ))]
    Δ(r)    = V + 2c₀n − μ,   K(r) = √(2(ϵ_cut − V − 2c₀n)),   ϵ_cut = μ + n_T·T

The closed form is the `k`-integral of the Rayleigh–Jeans occupation `T/(ϵ−μ)`
over the C region, so it uses the *same* cutoff prescription as
[`tracking_cutoff`](@ref) and is directly comparable to a run's `N_C`.

# What this is for

An SPGPE run has no independent statement of what its equilibrium should be, and
that gap is expensive. A Kibble–Zurek scan ran at μ = 15 with `T` ramped 30 → 2
under the assertion — written in the driver, never checked — that cooling crossed
the transition. It does not: at fixed μ the only thing that can destroy the
condensate is the thermal mean-field shift `2c₀n_th` reaching μ, and this
calculation puts that at **T_c = 49**. The ramp began at a condensate fraction of
0.33 and never crossed anything, so nothing measured along it was a KZ quantity.

The same numbers size the run: `N_th` at `T_hot` says how full the C region must
be before the quench starts, which is the check that catches a field that is
still filling.
"""
function classical_field_equilibrium(;
    T::Real, mu::Real, c0::Real, omega::Real=1.0, n_T::Real=1.0,
    rmax::Real=12.0, nr::Int=1200, iters::Int=400, mix::Real=0.5,
)
    eps_cut = mu + n_T * T
    r = range(0, rmax; length=nr)
    n0 = zeros(nr)
    nth = zeros(nr)
    for _ in 1:iters
        for i in 1:nr
            V = 0.5 * omega^2 * r[i]^2
            n0i = max(mu - V - 2c0 * nth[i], 0.0) / c0
            ntot = n0i + nth[i]
            Δ = max(V + 2c0 * ntot - mu, 0.0)
            K2 = 2 * (eps_cut - V - 2c0 * ntot)
            K = K2 > 0 ? sqrt(K2) : 0.0
            new = if K <= 0
                0.0
            elseif Δ < 1e-12
                T * K / π^2
            else
                (T / π^2) * (K - sqrt(2Δ) * atan(K / sqrt(2Δ)))
            end
            n0[i] = n0i
            # Damped, or the mean-field shift and the density chase each other.
            nth[i] = (1 - mix) * nth[i] + mix * new
        end
    end
    dr = step(r)
    (; r, n0, nth,
        N0=4π * sum(n0 .* r .^ 2) * dr,
        Nth=4π * sum(nth .* r .^ 2) * dr,
        n0_center=n0[1])
end

"""
    thermal_cfield!(psi, grid, plans; T, mu, c0, k_cut, seed, omega=1.0, n_T=1.0)

Seed `psi` with a thermal classical field at `(μ, T)`: a complex Gaussian random
field, low-passed at `k_cut`, with the local amplitude set by the
Hartree–Fock density from [`classical_field_equilibrium`](@ref). Only the last
spinor component is filled. Returns the seeded atom number.

# Why the density and not the spectrum

Letting the growth reservoir fill an empty C region does not work, and the reason
is structural rather than a matter of waiting longer. A mode relaxes at
`2γ(ϵ−μ)`, which vanishes as `ϵ → μ` — and the Rayleigh–Jeans occupation
`T/(ϵ−μ)` puts most of the atoms in exactly those modes. Measured: at `T = 80`,
where `1/(2γμ) = 15`, an equilibration of `150` reached `N = 1.85e4` against an
equilibrium `1.52e5`. Ten response times bought a factor of eight short, and
closing it would take of order `10³` time units per trajectory.

So the total and the profile are imposed by construction and only the *spectrum*
is left to the reservoir — which it fixes quickly, since the high-`k` modes are
the ones with large `ϵ−μ`. What this sampler gets right is `⟨|ψ(r)|²⟩ = n(r)`;
what it does not get right is the `k`-space occupation, which is why a short
equilibration is still required and why `N_C` should be re-checked after it.

Seeding above `T_c` (no condensate) is the intended use — there the field is
purely thermal and no coherent part has to be constructed.
"""
function thermal_cfield!(
    psi::AbstractArray{<:Complex}, grid::Grid{N}, plans::FFTPlans;
    T::Real, mu::Real, c0::Real, k_cut::Real, seed::Integer,
    omega::Real=1.0, n_T::Real=1.0,
) where {N}
    eq = classical_field_equilibrium(; T, mu, c0, omega, n_T,
        rmax=maximum(grid.config.box_size) / 2)
    n_pts = grid.config.n_points

    rng = MersenneTwister(seed)
    buf = zeros(ComplexF64, n_pts)
    for I in eachindex(buf)
        buf[I] = randn(rng) + im * randn(rng)
    end
    # Weight by the Rayleigh-Jeans occupation, not a flat low-pass. A hard cut
    # gives every mode equal weight, which — since the mode count grows as k² —
    # puts almost all of the atoms at HIGH k, exactly where ϵ−μ is large and the
    # reservoir relaxes them away within a few time units. Measured: seeding that
    # way was indistinguishable from starting at vacuum, `N` after 150 units of
    # equilibration coming out at 1.85e4 either way against an equilibrium 1.52e5.
    #
    # The offset Δ₀ is the mean-field shift at the cloud centre, so the spectrum
    # is the homogeneous one there. Multiplying by the envelope afterwards
    # convolves the spectrum with the envelope's own transform, whose width is
    # ~1/R_cloud ≈ 0.1 against a Rayleigh-Jeans scale √(2T) ≈ 12.6 — a 1% smearing,
    # which is why the trap can be applied in real space without spoiling this.
    Δ0 = max(2c0 * (eq.nth[1] + eq.n0[1]) - mu, 1e-3)
    plans.forward * buf
    kc2 = k_cut^2
    for I in CartesianIndices(n_pts)
        k2 = grid.k_squared[I]
        buf[I] = k2 > kc2 ? 0 : buf[I] * sqrt(T / (0.5 * k2 + Δ0))
    end
    plans.inverse * buf
    # A filtered Gaussian field has uniform variance; normalise it globally so the
    # local amplitude below is exactly the HF density and not that times a factor.
    s = sqrt(sum(abs2, buf) / length(buf))
    s > 0 && (buf ./= s)

    dr = step(eq.r)
    fill!(psi, 0)
    comp = size(psi, N + 1)
    for I in CartesianIndices(n_pts)
        r2 = 0.0
        for d in 1:N
            r2 += grid.x[d][I[d]]^2
        end
        j = clamp(Int(floor(sqrt(r2) / dr)) + 1, 1, length(eq.r))
        n_loc = eq.nth[j] + eq.n0[j]
        n_loc > 0 && (psi[I, comp] = sqrt(n_loc) * buf[I])
    end
    real(sum(abs2, psi)) * cell_volume(grid)
end

"""
    incoherent_lda(; T, mu, c0, eps_cut, omega=1.0, rmax, nr) -> Float64

Semiclassical Hartree–Fock population of the I region: every phase-space cell above
`eps_cut`, with the Bose occupation taken at the **effective** chemical potential

    μ_eff(r) = μ − V(r) − 2c₀[n_c(r) + ñ(r)]

so `N_I = ∫d³r ∫_{|p|>p_c} d³p/(2π)³ [exp((p²/2 − μ_eff)/T) − 1]⁻¹`,
`p_c(r) = √(2(ϵ_cut − V − 2c₀n))`.

# Why the effective potential, and why a level sum was wrong

An earlier version summed discrete harmonic levels with occupation `1/(e^{(ε−μ)/T}−1)`
and skipped every level below `μ`. That is not an approximation, it is a different
problem: the total then jumped down as `μ` crossed a level — measured in
`scripts/kz/mu_constraint_continuity.jl`, `N_C^th` fell 377 → 258 between μ = 2.375
and 2.5, and the whole constraint became NON-MONOTONE, which is why a 200-iteration
bisection returned 2.34 for 2.5.

There are no levels to skip. Inside the condensate the Thomas–Fermi relation
`μ = V + c₀n_c + 2c₀ñ` makes `μ_eff = −c₀n_c ≤ 0`, so the Bose argument
`z = e^{βμ_eff}` never reaches 1 and the occupation never diverges. The exchange
factor of 2 attaches to the thermal density and not the condensate density — Popov /
Zaremba–Griffin–Nikuni; see Giorgini, Pitaevskii & Stringari, cond-mat/9704014.
"""
function incoherent_lda(; T::Real, mu::Real, c0::Real, eps_cut::Real,
    omega::Real=1.0, rmax::Real=12.0, nr::Int=600, n_bose::Int=48)
    T > 0 || return 0.0
    eq = classical_field_equilibrium(; T, mu, c0, omega, n_T=(eps_cut - mu) / T,
        rmax, nr)
    r = eq.r
    dr = step(r)
    β = 1 / Float64(T)
    s = 0.0
    for i in eachindex(r)
        V = 0.5 * Float64(omega)^2 * r[i]^2
        n = eq.n0[i] + eq.nth[i]
        μ_eff = Float64(mu) - V - 2 * Float64(c0) * n
        pc2 = 2 * (Float64(eps_cut) - V - 2 * Float64(c0) * n)
        pc = pc2 > 0 ? sqrt(pc2) : 0.0
        # (1/2π²)∫_{pc}^∞ p² Σ_j exp(−j(p²/2 − μ_eff)/T) dp, term by term. The upper
        # tail of each Gaussian moment is closed-form, so no quadrature in p.
        acc = 0.0
        for j in 1:n_bose
            a = j * β
            z = exp(j * β * μ_eff)
            z < 1e-16 && break
            # ∫_pc^∞ p² e^{−a p²/2} dp = pc e^{−a pc²/2}/a + √(π/2)erfc(pc√(a/2))/a^{3/2}
            tail = pc * exp(-a * pc^2 / 2) / a +
                   sqrt(π / 2) * erfc(pc * sqrt(a / 2)) / a^1.5
            acc += z * tail
        end
        s += (acc / (2π^2)) * 4π * r[i]^2 * dr
    end
    s
end

"""
    mu_from_total_lda(N_total; T, c0, eps_cut, omega=1.0, rmax, nr) -> (; mu, N0, Nth_C, N_I)

Solve `N₀(μ) + ñ_C(μ) + N_I(μ) = N_total` with every region evaluated at the same `μ`
through the self-consistent effective potential.

`N₀` and `ñ_C` come from [`classical_field_equilibrium`](@ref) — the C region is a
classical field, so its occupation is Rayleigh–Jeans and not Bose — and `N_I` from
[`incoherent_lda`](@ref). The condensate number is an OUTPUT: it is whatever the
constraint leaves once the thermal regions take their share at that `μ`.
"""
function mu_from_total_lda(N_total::Real; T::Real, c0::Real, eps_cut::Real,
    omega::Real=1.0, rmax::Real=12.0, nr::Int=400, rtol::Real=1e-6, iters::Int=80)
    (N_total <= 0 || T <= 0) && return (; mu=NaN, N0=NaN, Nth_C=NaN, N_I=NaN)
    function parts(mu)
        eq = classical_field_equilibrium(; T, mu, c0, omega,
            n_T=(Float64(eps_cut) - mu) / Float64(T), rmax, nr)
        NI = incoherent_lda(; T, mu, c0, eps_cut, omega, rmax, nr)
        (; N0=eq.N0, Nth_C=eq.Nth, N_I=NI, tot=eq.N0 + eq.Nth + NI)
    end
    lo, hi = -20.0 * Float64(T), Float64(eps_cut)
    parts(hi).tot >= N_total || return (; mu=NaN, N0=NaN, Nth_C=NaN, N_I=NaN)
    for _ in 1:iters
        mid = 0.5 * (lo + hi)
        (parts(mid).tot < N_total) ? (lo = mid) : (hi = mid)
        abs(hi - lo) <= rtol * max(abs(hi), 1.0) && break
    end
    mu = 0.5 * (lo + hi)
    p = parts(mu)
    (; mu, p.N0, p.Nth_C, p.N_I)
end
