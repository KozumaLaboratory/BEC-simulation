# S(k, ω) by real-time impulse response ≡ the Bogoliubov branch it should sit on.
#
# `bragg_response` kicks the state with `exp(−i·A·cos(k·r)·O)`, evolves under the
# gated propagator and Fourier-transforms the density (`O = 1`) or longitudinal
# spin (`O = F_z`) response. On a uniform F=1 polar condensate in a periodic box
# the answer is a closed form this repo already anchors analytically:
#
#   density kick  → ω = √(εk(εk + 2c₀n))      spin kick → ω = √(εk(εk + 2c₁n))
#
# The state is the polar director along x, `ζ = (1,0,1)/√2`. That choice is
# load-bearing: for the m=0 polar state `F_zζ = 0`, so a spin_z kick would do
# NOTHING and the spin arm would be a null test. Rotating the director into x
# gives `F_zζ ≠ 0` while keeping the closed forms (a contact-only, q=0 polar
# spectrum is spin-rotation invariant).
#
# Three controls, because a peak at a plausible frequency is not a measurement:
#   CHANNEL SELECTIVITY — the density kick must leave S_spin empty and vice
#     versa. This is what says the peak came from the channel it was named for.
#   LINEARITY — doubling the kick must move the peak by ≪ one bin and multiply
#     the weight by 4 (|FT|²). Without it the "spectrum" could be the nonlinear
#     response to too hard a kick.
#   ZERO KICK — with amplitude 0 there must be no line at all. This is the probe
#     that fails if the instrument manufactures peaks out of roundoff, which it
#     does do at 1e-27 weight — hence `peak_contrast`, not `peak_weight`, is the
#     "is there a line" test.

using Test
using SpinorBEC
using SpinorBEC: bragg_response

_εk(k) = k^2 / 2
_branch(k, g, n) = sqrt(_εk(k) * (_εk(k) + 2 * g * n))

function _polar_x_box(; n=16, L=8.0, c0=1.0, c1=0.2, n0=1.0, dt=0.01)
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    grid = make_grid(GridConfig((n,), (L,)))
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, potential=NoPotential(),
        sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=false, save_every=10^6),
    )
    ζ = ComplexF64[1, 0, 1] ./ sqrt(2)
    ψ = zeros(ComplexF64, n, 3)
    for i in 1:n, c in 1:3
        ψ[i, c] = sqrt(n0) * ζ[c]
    end
    (; ws, ψ, dk=2π / L, c0, c1, n0)
end

@testset "Bragg S(k,ω) peak ≡ Bogoliubov branch, per channel" begin
    fx = _polar_x_box()
    ω_dens = _branch(fx.dk, fx.c0, fx.n0)
    ω_spin = _branch(fx.dk, fx.c1, fx.n0)
    @test ω_dens > 1.5 * ω_spin            # the two branches are resolvable at all

    rd = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=1e-3, channel=:density)
    rs = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=1e-3, channel=:spin_z)

    # Peaks land on the analytic branches, within the bin the run can resolve.
    @test abs(rd.peak_omega_density - ω_dens) < rd.omega_resolution
    @test abs(rs.peak_omega_spin - ω_spin) < rs.omega_resolution
    # …and the claim is only as tight as the window: this run cannot separate
    # anything closer than Δω, and that number is reported, not assumed.
    @test rd.omega_resolution < 0.1 * abs(ω_dens - ω_spin)
    @test rd.nyquist_omega > 10 * ω_dens

    # CHANNEL SELECTIVITY. A scalar kick creates no F_z modulation and an F_z
    # kick no net density modulation, both exactly — so the cross-channel weight
    # must sit at roundoff, 15+ orders below the on-channel line.
    #
    # Stated as a WEIGHT RATIO, not as a contrast. `peak_contrast` is a ratio to
    # the median of its OWN spectrum, so it cannot say "this spectrum is empty":
    # measured here, the roundoff-only cross-channel spectrum has contrast 13,
    # because roundoff is not flat. Contrast answers "is there a line in this
    # spectrum", never "is this spectrum zero".
    @test rd.peak_contrast_density > 50
    @test rs.peak_contrast_spin > 50
    @test rd.peak_weight_spin < 1e-15 * rd.peak_weight_density
    @test rs.peak_weight_density < 1e-15 * rs.peak_weight_spin

    # Propagator hygiene: the kick is unitary, so any norm drift is the
    # integrator, and a spectrum from a drifting run measures the integrator.
    for r in (rd, rs)
        @test r.norm_drift < 1e-10
        @test r.energy_drift < 1e-8
        @test !r.lhy_active                # mean-field spectrum, and it says so
    end
end

@testset "Bragg response is LINEAR in the kick" begin
    fx = _polar_x_box()
    r1 = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=1e-3, channel=:density)
    r2 = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=2e-3, channel=:density)
    # Peak position invariant to well under one bin…
    @test abs(r2.peak_omega_density - r1.peak_omega_density) < 0.1 * r1.omega_resolution
    # …and the weight scales as amplitude² (the spectrum is |FT|²).
    @test isapprox(r2.peak_weight_density / r1.peak_weight_density, 4.0; rtol=0.02)
end

@testset "Bragg response: zero kick ⇒ no line (negative control)" begin
    fx = _polar_x_box()
    r0 = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=0.0, channel=:density)
    r1 = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=1e-3, channel=:density)
    # A stationary state kicked by nothing does not respond. `peak_omega` is
    # still a NUMBER here — the argmax of roundoff — so the verdict has to be a
    # weight compared against the kicked run, never the peak position.
    @test r0.peak_weight_density < 1e-15 * r1.peak_weight_density
    @test isfinite(r0.peak_omega_density)      # returns a value, does not throw
end

@testset "Bragg resolution scales as 2π/T (window, not a constant)" begin
    fx = _polar_x_box()
    long = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=200.0,
        amplitude=1e-3, channel=:density)
    short = bragg_response(fx.ws, fx.ψ; k_vec=[fx.dk], t_total=50.0,
        amplitude=1e-3, channel=:density)
    @test isapprox(short.omega_resolution / long.omega_resolution, 4.0; rtol=0.05)
    # The peak still lands on the branch — with the wider bar the shorter run
    # honestly reports.
    ω_dens = _branch(fx.dk, fx.c0, fx.n0)
    @test abs(short.peak_omega_density - ω_dens) < short.omega_resolution
end
