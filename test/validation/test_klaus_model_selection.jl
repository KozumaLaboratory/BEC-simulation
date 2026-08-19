# Why the Klaus-2022 reproduction runs on the scalar eGPE and not the spinor
# solver — as a computation, not a paragraph.
#
# The decision is worth gating because getting it wrong is not a wrong answer,
# it is a ~10⁴× bill for the same answer (or a timeout). CLAUDE.md's
# "before computing" gates put the model choice first for exactly this reason,
# and the choice was previously recorded only in a memory note.

using Test
using SpinorBEC
using SpinorBEC: Units, compute_a_dd, compute_c_dd_dimless, scalar_lhy_coefficient,
    ATOM_REGISTRY, adiabatic_parameter, spinor_cost_factor

const KLAUS_DOC = normpath(
    joinpath(@__DIR__, "..", "..", "docs", "validation",
        "klaus2022_primary_source.md"),
)

# Klaus et al. 2022, Fig. 3b column of the parameter table in that document.
const KLAUS = (
    atom=:Dy162, a_s_bohr=110.0, N=10000,
    f_perp=50.0, f_z=130.0, B_gauss=5.333, omega_over_perp=0.75,
)

"μ/ℏω_ref from the contact Thomas-Fermi profile — the mean-field scale the
Larmor precession has to beat. Deliberately the cheap estimate: the decision it
feeds is four orders of magnitude away from its boundary."
function _mu_tf(c0, lambda)
    R = (15 * c0 * lambda / (4π))^(1 / 5)
    R^2 / 2
end

@testset "Klaus 2022 model selection" begin
    atom = ATOM_REGISTRY[KLAUS.atom]
    a_s = KLAUS.a_s_bohr * Units.BOHR_RADIUS
    ω_ref = 2π * KLAUS.f_perp
    a_ho = sqrt(Units.HBAR / (atom.mass * ω_ref))
    c0 = 4π * (a_s / a_ho) * KLAUS.N
    μ = _mu_tf(c0, KLAUS.f_z / KLAUS.f_perp)

    r = spin_treatment_report(atom;
        B_gauss=KLAUS.B_gauss, omega_ref=ω_ref, mu_dimless=μ,
        f_trap_hz=KLAUS.f_z, f_drive_hz=KLAUS.omega_over_perp * KLAUS.f_perp,
        dt_physics=2e-3)

    @testset "the hierarchy is what the decision rests on" begin
        # ω_L ≫ mean field ≫ trap ≳ stir. If this ordering ever breaks the
        # scalar path is not merely slower-to-justify, it is wrong.
        @test r.f_larmor > 100 * r.f_meanfield
        @test r.f_meanfield > r.f_trap
        @test r.f_trap > r.f_drive
        # Quoted in the doc as 9.256 MHz / 526 Hz.
        @test r.f_larmor / 1e6 ≈ 9.256 atol = 0.01
        @test r.f_meanfield ≈ 526.0 atol = 2.0
        @test adiabatic_parameter(r) < 1e-3
    end

    @testset "the recommendation, and that it can say the other thing" begin
        @test recommend_spin_treatment(r) == :scalar_adiabatic
        # NEGATIVE CONTROL. A recommender that always says `:scalar_adiabatic`
        # would pass every assertion above. The complementary regime this repo
        # actually runs — Eu151 at the bare-DDI field, where the Larmor
        # precession is NOT fast — must come back `:spinor`.
        eu = ATOM_REGISTRY[:Eu151]
        weak = spin_treatment_report(eu;
            B_gauss=63e-6, omega_ref=2π * 50.0, mu_dimless=10.0,
            f_trap_hz=130.0, f_drive_hz=38.0, dt_physics=2e-3)
        @test recommend_spin_treatment(weak) == :spinor
        @test adiabatic_parameter(weak) > adiabatic_parameter(r)
    end

    @testset "the cost of choosing the spinor path anyway" begin
        # p·F·dt < π forces dt ≈ 2.1e-6 against a trap-scale 2e-3, and J=8
        # carries 17 components.
        @test r.n_components == 17
        @test r.dt_zeeman_max ≈ 2.12e-6 rtol = 0.02
        @test spinor_cost_factor(r) > 1e4
    end

    @testset "the primary-source document states these numbers" begin
        # The doc is where a reader meets the decision; a value that drifts out
        # of agreement with the code here is the failure mode this pins.
        txt = read(KLAUS_DOC, String)
        for s in ("9.256 MHz", "526 Hz", "1.85×10⁵", "2.1×10⁻⁶", "17 components")
            @test occursin(s, txt)
        end
        # Calibration: a string that must NOT be there, so "occursin found it"
        # cannot be a property of the file being large.
        @test !occursin("9.999 MHz", txt)
    end
end
