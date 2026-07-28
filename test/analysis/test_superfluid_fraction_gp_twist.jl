# Type-B gate for `superfluid_fraction`: the rigid-density variational value vs
# a direct twisted-boundary-condition GP minimisation.
#
# `superfluid_fraction` freezes the density and relaxes only the phase. The
# obvious worry is that a real condensate also redistributes its density under
# the twist, making the reported number a loose upper bound. It does not, at
# the order that matters: the density response is O(q²), and because the
# untwisted state is stationary its energy cost enters at O(q⁴), leaving f_s —
# an O(q²) quantity — exact within mean field. This file checks that claim
# numerically instead of asserting it.
#
# The reference below is written out longhand: its own imaginary-time
# split-step, its own energy functional, no call into the production
# propagator. Twisted BCs ψ(x+L) = e^{iθ}ψ(x) are gauged into ψ = e^{iqx}φ with
# q = θ/L and φ periodic, so the twist appears only as k → k + q.

using Test
using SpinorBEC
using FFTW

function _gp_energy_twisted(phi, kx, V, g, q, dx)
    phik = fft(phi)
    npt = length(phi)
    e_kin = 0.5 * sum(abs2.(phik) .* (kx .+ q) .^ 2) * dx / npt
    e_pot = sum(V .* abs2.(phi)) * dx
    e_int = 0.5 * g * sum(abs2.(phi) .^ 2) * dx
    e_kin + e_pot + e_int
end

# Imaginary-time split-step ground state of the twisted 1D scalar GP.
function _gp_twisted(; npt, L, V0, m_lat, g, q, dt=5e-3, n_steps=80_000, tol=1e-13)
    dx = L / npt
    x = collect(0:(npt - 1)) .* dx .- L / 2
    kx = 2π .* fftfreq(npt, 1 / dx)
    V = V0 .* cos.(2π * m_lat .* x ./ L)

    phi = ones(ComplexF64, npt)
    phi ./= sqrt(sum(abs2, phi) * dx)
    kin = exp.(-0.5 * dt .* (kx .+ q) .^ 2)

    E_prev = Inf
    for step in 1:n_steps
        @. phi *= exp(-0.5 * dt * (V + g * abs2(phi)))
        phi = ifft(kin .* fft(phi))
        @. phi *= exp(-0.5 * dt * (V + g * abs2(phi)))
        phi ./= sqrt(sum(abs2, phi) * dx)
        if step % 500 == 0
            E = _gp_energy_twisted(phi, kx, V, g, q, dx)
            abs(E - E_prev) < tol * max(1.0, abs(E)) && break
            E_prev = E
        end
    end
    (E=_gp_energy_twisted(phi, kx, V, g, q, dx), n=abs2.(phi))
end

# f_s = 2(E(q) − E(0)) / q², Richardson-extrapolated in q so the O(q²)
# correction to the quadratic response cancels.
function _fs_by_twist(; L, theta1=0.05, theta2=0.1, kwargs...)
    E0 = _gp_twisted(; L, q=0.0, kwargs...).E
    q1, q2 = theta1 / L, theta2 / L
    f1 = 2 * (_gp_twisted(; L, q=q1, kwargs...).E - E0) / q1^2
    f2 = 2 * (_gp_twisted(; L, q=q2, kwargs...).E - E0) / q2^2
    (f=(4 * f1 - f2) / 3, dq=abs(f1 - f2))
end

@testset "Superfluid fraction vs twisted-BC GP (type B)" begin
    L = 10.0
    npt = 128
    grid = make_grid(GridConfig(npt, L))

    @testset "no lattice ⇒ f_s = 1 exactly" begin
        # Sanity anchor for the reference itself: a uniform condensate carries
        # the full rigid-flow energy, interactions or not.
        for g in (0.0, 5.0)
            r = _fs_by_twist(; L, npt, V0=0.0, m_lat=2, g)
            @test r.f ≈ 1.0 rtol = 1e-6
        end
    end

    @testset "rigid density is exact within mean field" begin
        # Spans f_s over three and a half decades, from a weakly corrugated
        # condensate to nearly isolated droplets.
        cases = [
            (V0=1.0, g=0.0), (V0=1.0, g=5.0), (V0=3.0, g=5.0), (V0=6.0, g=2.0)
        ]
        for c in cases
            r = _fs_by_twist(; L, npt, m_lat=2, c.V0, c.g)
            gs = _gp_twisted(; L, npt, m_lat=2, c.V0, c.g, q=0.0)

            f_leggett = superfluid_fraction(gs.n, grid; method=:leggett)
            f_relaxed = superfluid_fraction(gs.n, grid; method=:relaxed)

            # 1D, so there is no transverse rerouting and the two branches
            # describe the same number. `:leggett` is spectrally accurate and
            # carries the claim; `:relaxed` adds its own one-sided O(dx²)
            # error, larger in relative terms where f_s is small and the
            # density is sharply peaked (see the refinement check below).
            @test f_leggett ≈ r.f rtol = 5e-3
            @test 0 <= (f_relaxed - r.f) / r.f < 5e-2
            # The q-extrapolation has to be converged for the above to mean
            # anything.
            @test r.dq < 1e-3 * max(r.f, 1e-3)
        end
    end

    @testset "the relaxed branch's residual is discretisation, not physics" begin
        # Hardest case above (f_s ≈ 2e-2, sharply peaked). If the excess were a
        # real rigid-density bias it would survive refinement; it should instead
        # fall like dx².
        V0, g = 3.0, 5.0
        ref = _fs_by_twist(; L, npt=256, m_lat=2, V0, g).f
        excess = map((64, 128, 256)) do np
            gs = _gp_twisted(; L, npt=np, m_lat=2, V0, g, q=0.0)
            g_np = make_grid(GridConfig(np, L))
            superfluid_fraction(gs.n, g_np; method=:relaxed) - ref
        end
        @test all(excess .> 0)
        @test excess[1] / excess[2] > 3.0
        @test excess[2] / excess[3] > 3.0
    end

    @testset "a loose upper bound would have shown up as a one-sided gap" begin
        # If density relaxation mattered at O(q²) the direct value would sit
        # systematically BELOW the rigid-density one. Check the residuals are
        # not one-sided at the 5e-3 level across the same cases.
        residuals = map([
            (V0=1.0, g=0.0), (V0=1.0, g=5.0), (V0=3.0, g=5.0), (V0=6.0, g=2.0)
        ]) do c
            r = _fs_by_twist(; L, npt, m_lat=2, c.V0, c.g)
            gs = _gp_twisted(; L, npt, m_lat=2, c.V0, c.g, q=0.0)
            (superfluid_fraction(gs.n, grid; method=:leggett) - r.f) / r.f
        end
        @test maximum(abs, residuals) < 5e-3
    end
end
