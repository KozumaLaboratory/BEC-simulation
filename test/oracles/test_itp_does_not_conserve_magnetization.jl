using Test
using FFTW
using Random
using SpinorBEC
using SpinorBEC: KineticTerm, TrapTerm, ZeemanTerm, DensityC0Term, SpinC1Term,
    apply_step!

# Why an adiabatically ramped RTP does NOT have to land on the ITP ground state.
#
# Issue #22 asks it directly ("疑問1"), and the answer is a conservation law
# rather than a question of how slowly you ramp.
#
# `test_magnetization_conservation_rtp.jl` pins the first half: with no
# transverse field, no Raman and DDI off, H commutes with F_z, so ⟨F_z⟩ is a
# constant of the REAL-time motion however violently c₁ redistributes the
# m-components. A ramp that stays inside that Hamiltonian family therefore cannot
# leave the magnetization sector it started in, at any rate.
#
# This file pins the second half, which nothing asserted: imaginary time is not
# unitary, so it does NOT conserve ⟨F_z⟩. ITP minimises over ALL sectors while an
# adiabatic RTP is confined to one, and the two agree only when the ITP minimum
# happens to lie in the sector the ramp started in.
#
# That is the mechanism behind #335's verdict — the two branches of the
# κ-dependent transition sit in different J_z sectors, so no ramp rate crosses
# between them — and behind #334's premise that the chiral ground state has to be
# nucleated in place rather than ramped into.
#
# The arms share one fixture and differ only in `imaginary_time`, which is what
# makes this a comparison rather than two measurements. The DIRECTION is claimed
# only where it is derivable. Under imaginary time the m-populations are tilted
# by exp(−2·zee_m·t), so for m-independent everything else
#
#     d⟨m⟩/dt = −2 Cov(m, zee_m) = 2p·Var(m) − 2q·Cov(m, m²),
#
# which would be monotone at q = 0. It is NOT, and the reason is worth writing
# down because it was wrong twice before it was measured (TSUBAME jobs 8443462
# and 8443496, both 7 of 8): the imaginary-time KINETIC step damps by exp(−k²dt/2),
# which is m-independent as an operator but not in effect — each m-component
# carries its own spatial profile, so their norms decay at different rates and
# the weights do not follow the Zeeman tilt alone. Monotonicity is therefore not
# derivable for a generic initial state, and is not asserted.
#
# What IS asserted: the endpoint direction at q = 0, c₁ = 0 (population moves
# toward m = +F, the state the Zeeman ladder selects), and non-conservation by
# orders of magnitude everywhere. With c₁ ≠ 0 the AFM spin-mixing pushes ⟨F⟩
# toward zero and competes with the Zeeman, so that arm claims no direction at
# all — that would be asserting a race whose winner has not been derived.

const _P, _Q = 0.3, 0.05

"⟨F_z⟩ of a spinor field, in the same normalisation as the RTP oracle."
function _fz(psi, F, dV)
    D = 2F + 1
    sum((F - (c - 1)) * sum(abs2, selectdim(psi, ndims(psi), c)) for c in 1:D) * dV
end

function _evolve(F, imag_time; c1, q=_Q, n=8, steps=200, dt=0.005, seed=20260819)
    D = 2F + 1
    grid = make_grid(GridConfig((n, n, n), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=(F == 1 ? Rb87 : Eu151),
        interactions=InteractionParams(Dict(0 => 1.0, 1 => c1)),
        zeeman=ZeemanParams(_P, q), potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=imag_time),
        fft_flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    psi = randn(Xoshiro(seed), ComplexF64, n, n, n, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    terms = (ZeemanTerm(0.0, 0.0, _P, q), DensityC0Term(1.0), SpinC1Term(c1),
        TrapTerm(), KineticTerm())
    trace = Float64[_fz(psi, F, dV)]
    for _ in 1:steps
        for term in terms
            apply_step!(term, psi, dt, imag_time, ws)
        end
        imag_time && (psi ./= sqrt(sum(abs2, psi) * dV))   # ITP renormalises
        push!(trace, _fz(psi, F, dV))
    end
    trace
end

@testset "real time conserves ⟨F_z⟩, imaginary time does not (F=$F)" for F in (1, 6)
    real_trace = _evolve(F, false; c1=0.5)
    fz0 = real_trace[1]
    drift = maximum(abs, real_trace .- fz0)
    @test drift < 1e-10

    # Same fixture, imaginary time: not conserved, by orders of magnitude.
    imag_mix = _evolve(F, true; c1=0.5)
    @test imag_mix[1] ≈ fz0
    @test abs(imag_mix[end] - fz0) > 1e6 * max(drift, eps())

    # c₁ = 0, q = 0: the Zeeman ladder selects m = +F, and the population moves
    # that way. Endpoint only — see the header for why the path is not monotone.
    imag_pure = _evolve(F, true; c1=0.0, q=0.0)
    @test imag_pure[end] - imag_pure[1] > 0.05
    @test imag_pure[end] < F + 1e-9                   # and it cannot overshoot +F

    # q ≠ 0 breaks the monotonicity ARGUMENT, not the non-conservation: the
    # Cov(m, m²) term has no fixed sign. Measured, not assumed (job 8443462).
    imag_q = _evolve(F, true; c1=0.0)
    @test abs(imag_q[end] - imag_q[1]) > 1e6 * max(drift, eps())

    # CONTROL: with c₁ = 0 the real-time arm must still conserve, or the
    # difference above would be about the fixture rather than about the flag.
    @test maximum(abs, _evolve(F, false; c1=0.0) .- fz0) < 1e-10
end
