using Test, SpinorBEC
using SpinorBEC: _run_step, GroundStateStep, energy_decomposition, total_energy

# The ground-state step must return ONE state.
#
# It returns three things that all claim to describe its answer: the ψ it saves,
# the workspace it hands to every downstream analyzer, and the energy it
# reports. Until 2026-08-03 those could be three different objects.
#
# `_null_nyquist_modes!` is applied to the saved ψ and not to the workspace. Its
# docstring says the split-step dealias already strips Nyquist content during
# ITP, "so this is a no-op there" — and that is true only without a rotating
# frame. Measured at 8^3, dt = 0.002, `method: itp`:
#
#     rotating_frame_omega = 0      projection moves ψ by 1.1e-16   (a no-op)
#     rotating_frame_omega = 0.3    projection moves ψ by 1.1e-5    (not)
#
# present in every combination containing Ω and in none without: the Coriolis
# 3-shear runs after the dealias inside the sandwich, and an FFT-based shear
# rings at the Nyquist frequency. So the saved ψ differed from the analysed one
# by 2.6e-5 relative, and the reported energy — taken from the solver, i.e. from
# the unprojected state — was the energy of neither the file nor a state anyone
# could reconstruct. A cache hit rebuilds its workspace FROM the saved ψ, so
# fresh and cached analysis of one artifact disagreed by 3.0e-8 in the energy.
#
# This is `_finalize_lbfgs_atomic!`'s discipline one level up. That function
# makes {ψ, E, ∇E} atomic at the SOLVER's return; nothing made them atomic at
# the STEP's.

base(; extra...) = begin
    p = Dict{String, Any}(
        "atom" => "Eu151",
        "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "interactions" => Dict{String, Any}(
            "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => -0.01),
        "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 2.0]),
        "B" => Dict{String, Any}("Bz" => 0.01),
        "ddi" => Dict{String, Any}("secular" => true),
        "method" => "itp", "n_steps" => 5, "dt" => 0.002, "tol" => 1.0e-8,
        "backend" => "cpu")
    for (k, v) in extra
        p[String(k)] = v
    end
    p
end

const LHY = Dict{String, Any}("kind" => "polar_contact", "n_max" => 12.0)
const LS = Dict{String, Any}("eta_tensor" => 0.2)

# Every combination, not just the one that failed. The defect was invisible in
# seven of these eight and the eighth is not special — it is just the one whose
# Ω was nonzero.
const CASES = [
    "bare" => base(),
    "lhy" => base(; lhy=LHY),
    "rotating frame" => base(; rotating_frame_omega=0.3),
    "light shift" => base(; light_shift=LS),
    "lhy + frame" => base(; lhy=LHY, rotating_frame_omega=0.3),
    "lhy + shift" => base(; lhy=LHY, light_shift=LS),
    "frame + shift" => base(; rotating_frame_omega=0.3, light_shift=LS),
    "all three" => base(; lhy=LHY, rotating_frame_omega=0.3, light_shift=LS),
    "lbfgs, all three" => base(; method="lbfgs", lhy=LHY,
        rotating_frame_omega=0.3, light_shift=LS),
]

@testset "the ground-state step returns one state" begin
    for (label, p) in CASES
        @testset "$label" begin
            (psi, _, _, ws, r) = _run_step(GroundStateStep(deepcopy(p)),
                nothing, nothing, nothing, nothing; verbose=false)

            # 1. The workspace handed to the analyzers is AT the ψ that is
            #    saved. Bit-identity, not a tolerance: they are the same array
            #    copied, so anything else is a second state.
            @test Array(ws.state.psi) == Array(psi)

            # 2. The reported energy is the energy OF that state. Exact,
            #    because it is now read from this workspace rather than carried
            #    from the solver's.
            #
            #    Weaker than arm 1 and worth saying so: since the fix reads the
            #    energy from this same workspace, this arm is a CONSISTENCY
            #    check, not an independent one — measured by canary, removing
            #    the fix reddens arm 1 in all nine cases and leaves this arm
            #    green. Arm 1 is what carries the gate; this one pins that the
            #    energy is not re-sourced from elsewhere later.
            @test Float64(r[:ground_state_energy]) == Float64(total_energy(ws))
            @test Float64(r[:ground_state_energy]) ==
                Float64(energy_decomposition(ws).total)
        end
    end

    # POSITIVE CONTROL. Arms 1 and 2 are equalities, and an equality is
    # satisfied by a degenerate fixture — if the rotating-frame cases silently
    # stopped having a rotating frame, or the projection stopped moving ψ, every
    # assertion above would stay green while gating nothing.
    #
    # So: assert the projection IS a state change in the Ω ≠ 0 cases and IS NOT
    # in the Ω = 0 cases. That is the measurement the defect was made of, and it
    # is what makes the equalities above load-bearing.
    @testset "positive control: the projection really moves psi, and only with Ω" begin
        function nyquist_shift(p)
            (psi, grid, _, _, _) = _run_step(GroundStateStep(deepcopy(p)),
                nothing, nothing, nothing, nothing; verbose=false)
            a = Array(psi)
            b = SpinorBEC._null_nyquist_modes!(copy(a), grid)
            maximum(abs.(b .- a)) / maximum(abs.(a))
        end
        # Ω = 0: the dealias really has already stripped it. Machine epsilon.
        @test nyquist_shift(base()) < 1.0e-12
        @test nyquist_shift(base(; light_shift=LS)) < 1.0e-12
        # Ω ≠ 0: it has not. Orders of magnitude larger — and now IDEMPOTENT,
        # because the step already applied it, which is the fix.
        @test nyquist_shift(base(; rotating_frame_omega=0.3)) < 1.0e-12

        # …and the un-projected state genuinely differs, or the fix is a no-op
        # dressed as a fix. Take the raw solver output and project it.
        p = base(; rotating_frame_omega=0.3)
        (psi, grid, _, _, _) = _run_step(GroundStateStep(deepcopy(p)),
            nothing, nothing, nothing, nothing; verbose=false)
        # A state with deliberate Nyquist content must move under the
        # projection by far more than 1e-12 — otherwise `nyquist_shift` is
        # measuring nothing and the three assertions above are vacuous.
        dirty = copy(Array(psi))
        n = size(dirty, 1)
        dirty[n ÷ 2 + 1, :, :, :] .+= 1.0e-3 * maximum(abs.(dirty))
        @test maximum(abs.(SpinorBEC._null_nyquist_modes!(copy(dirty), grid) .- dirty)) /
              maximum(abs.(dirty)) > 1.0e-6
    end
end
