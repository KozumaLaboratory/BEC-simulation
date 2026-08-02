export classical_field_equilibrium, thermal_cfield!

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
    plans.forward * buf
    kc2 = k_cut^2
    for I in CartesianIndices(n_pts)
        grid.k_squared[I] > kc2 && (buf[I] = 0)
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
