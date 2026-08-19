# Type-C gate: Klaus et al., "Observation of vortices and vortex stripes in a
# dipolar Bose-Einstein condensate", Nat. Phys. 18, 1453 (2022),
# arXiv:2206.12265.
#
# Parameters, systematics and the pre-registered accept/reject thresholds are in
# `docs/validation/klaus2022_primary_source.md`, written before the first
# launch. The production runs are ~1.5 h each on the scalar eGPE path
# (`scripts/klaus2022_reproduce.jl`) and their verdicts live in
# `docs/validation/klaus2022_results.json`; this file re-applies the thresholds
# to that record and keeps the cheap invariants that would break first.
#
# What is deliberately NOT compared: our raw vortex count against their 𝒩ᵥ.
# Their published number is a detector output on a blurred, noise-added image —
# their own benchmark reports ≈9 detected where ≈33 are present. See §3 of the
# primary-source doc.

using Test
using JSON
using SpinorBEC
using SpinorBEC: Units, compute_a_dd, compute_c_dd_dimless, ATOM_REGISTRY,
    make_scalar_ws, find_ground_state_scalar!, planar_aspect_ratio,
    normalize_scalar!, GridConfig, make_grid, scalar_lhy_coefficient
using StaticArrays: SVector

const RESULTS_JSON = normpath(
    joinpath(@__DIR__, "..", "..", "docs", "validation",
        "klaus2022_results.json"),
)

@testset "Klaus 2022 vortex stripes (type-C)" begin
    @testset "the reference species and its coefficient chain" begin
        dy162 = ATOM_REGISTRY[:Dy162]
        # Published: a_dd = 129.2 a₀ for ¹⁶²Dy.
        @test compute_a_dd(dy162) / Units.BOHR_RADIUS ≈ 129.2 atol = 0.5
        # Species guard. ¹⁶⁴Dy is what the old magnetostir smoke runs; its mass
        # differs, so a_dd does too, and at fixed a_s that moves ε_dd — the
        # parameter the whole stripe phase depends on.
        @test compute_a_dd(ATOM_REGISTRY[:Dy164]) != compute_a_dd(dy162)

        a_s = 110 * Units.BOHR_RADIUS
        eps_dd = compute_a_dd(dy162) / a_s
        @test eps_dd ≈ 1.174 atol = 0.01           # doc §1
        @test eps_dd > 1                            # dipole-dominated, as stated

        # The scalar kernel weight against the contact one. μ₀μ² = 12πℏ²a_dd/m
        # and c₀ = 4π(a_s/a_ho)N, so the ratio is fixed at 3ε_dd by SI alone —
        # no convention freedom, and it is the single number that decides how
        # dipolar the simulated cloud is.
        ω_ref = 2π * 50.0
        N = 10000
        a_ho = sqrt(Units.HBAR / (dy162.mass * ω_ref))
        c0 = 4π * (a_s / a_ho) * N
        c_dd = compute_c_dd_dimless(dy162; N_atoms=N, omega_ref=ω_ref) * dy162.F^2
        @test c_dd / c0 ≈ 3 * eps_dd rtol = 1e-10

        # Lima-Pelster Q₅ is what the paper's γ_QF carries.
        @test lima_pelster_Q5(eps_dd) > 3.0
        @test lima_pelster_Q5(0.0) == 1.0          # calibration: it can be 1
    end

    @testset "magnetostriction points along the field" begin
        # The directional oracle the whole reproduction rests on: tilting B̂
        # into the plane must elongate the cloud ALONG the in-plane projection,
        # and must do nothing when there is no projection. Coarse grid on
        # purpose — this is a direction, not a magnitude.
        dy162 = ATOM_REGISTRY[:Dy162]
        ω_ref = 2π * 50.0
        N = 10000
        a_s = 110 * Units.BOHR_RADIUS
        a_ho = sqrt(Units.HBAR / (dy162.mass * ω_ref))
        eps_dd = compute_a_dd(dy162) / a_s
        λ = 2.6

        grid = make_grid(GridConfig((32, 32, 16), (12.0, 12.0, 6.0)))
        V = [0.5 * (x^2 + y^2 + λ^2 * z^2)
             for x in grid.x[1], y in grid.x[2], z in grid.x[3]]

        function gs_shape(θ, φ)
            ws = make_scalar_ws(grid, V;
                g_contact=4π * (a_s / a_ho) * N,
                c_dd=compute_c_dd_dimless(dy162; N_atoms=N, omega_ref=ω_ref) *
                     dy162.F^2,
                F=1.0,
                gamma_lhy=scalar_lhy_coefficient(a_s / a_ho, N; eps_dd=eps_dd))
            @inbounds for I in CartesianIndices(ws.psi)
                x = grid.x[1][I[1]];
                y = grid.x[2][I[2]];
                z = grid.x[3][I[3]]
                v = 12.0 - 0.5 * (x^2 + y^2 + λ^2 * z^2)
                ws.psi[I] = v > 0 ? sqrt(v) + 0im : 0im
            end
            normalize_scalar!(ws)
            find_ground_state_scalar!(ws, 1200, 0.004;
                B_hat=SVector(sin(θ) * cos(φ), sin(θ) * sin(φ), cos(θ)))
            planar_aspect_ratio(ws)
        end

        # NEGATIVE control: B̂ ∥ ẑ has no in-plane projection ⇒ no in-plane
        # deformation. Without this, "AR > 1" could be a property of the metric.
        s0 = gs_shape(0.0, 0.0)
        @test s0.ratio < 1.005

        # POSITIVE, φ = 0: long axis along x̂.
        sx = gs_shape(deg2rad(35), 0.0)
        @test sx.ratio > 1.01
        @test abs(sx.angle) < deg2rad(10)

        # POSITIVE, φ = 90°: the SAME deformation, rotated with the field.
        sy = gs_shape(deg2rad(35), π / 2)
        @test sy.ratio ≈ sx.ratio rtol = 0.02
        Δ = abs(abs(sy.angle) - π / 2)
        @test min(Δ, π / 2) < deg2rad(10)
    end

    @testset "production run verdicts against the published values" begin
        @test isfile(RESULTS_JSON)
        all_res = JSON.parsefile(RESULTS_JSON)

        for arm in ("ar-ramp", "stripes", "control")
            @testset "$arm" begin
                @test haskey(all_res, arm)
                r = all_res[arm]
                # A smoke result must never satisfy this gate: it is a
                # different grid and a different duration.
                @test r["smoke"] == false
                @test !isempty(r["git_hash"])
                @test r["norm_drift"] < r["accept"]["norm_drift_max"]
                @test r["verdict"] in ("ACCEPT", "REJECT")
            end
        end

        ramp = all_res["ar-ramp"]
        @test ramp["published"]["omega_c_over_perp"] == 0.74
        # The location of the AR MAXIMUM is what Klaus's Ω_c marks ("suddenly,
        # at Ω_c ≈ 0.74 ω_⊥, the AR abruptly collapses"). Recomputed here from
        # the stored series rather than read from a summary field, so the gate
        # does not depend on the reducer that produced it.
        ar = Float64.(ramp["aspect_ratio"])
        om = Float64.(ramp["omega"])
        @test length(ar) == length(om) > 100
        omega_peak = om[argmax(ar)]
        @test ramp["accept"]["omega_c_lo"] <= omega_peak <= ramp["accept"]["omega_c_hi"]
        # The instability has to be real, not a wobble: the cloud must actually
        # elongate before it collapses, and angular momentum must be pumped in.
        @test maximum(ar) > ramp["accept"]["ar_peak_min"]
        @test maximum(Float64.(ramp["Lz"])) > 5.0
        @test abs(Float64(ramp["Lz"][1])) < 0.1          # and start from zero

        # The pre-registered composite criterion FAILED, and stays recorded as
        # failed. Its `AR < 1.1` collapse leg was calibrated to a magnetostricted
        # baseline of 1.03 that this repository does not reproduce (see
        # `klaus2022_primary_source.md` §6b); with a baseline of 1.16 that
        # threshold measures something else. Pinning the failure keeps the
        # disagreement visible instead of letting a later edit quietly retune it.
        @test ramp["ar_static_verdict"] == "FAIL"
        @test ramp["verdict"] == "REJECT"
        @test 1.10 < ramp["ar_static_magnetostricted"] < 1.20

        stripes = all_res["stripes"]
        acc = stripes["accept"]
        # Three stripes, aligned with B̂ (Fig. 4b2/b3).
        @test acc["n_stripes_lo"] <= stripes["n_stripes"] <= acc["n_stripes_hi"]
        @test stripes["stripe_misalign_deg"] <= acc["stripe_axis_tol_deg"]
        @test stripes["stripe_misalign_deg"] < 10.0        # measured 5.9°
        # Against the VORTEX-FREE, equally-elongated t = 0 frame — the leg that
        # separates "vortices in stripes" from "the cloud is an ellipse aligned
        # with B̂". Measured 3.99×.
        @test stripes["axis_order_over_baseline"] >= acc["axis_order_over_baseline_min"]
        @test stripes["radial_prominence"] >= acc["radial_prominence_min"]
        # `radial_prominence` does NOT separate stripes from a smooth ellipse,
        # and it goes the OTHER way: the vortex-free t=0 frame reads 2.05 against
        # the turbulent late state's 1.52, because a clean elliptical residual is
        # more single-scale than a turbulent one. It is a "is there a peak in |k|
        # at all" check, not a discriminator. Pinned in the direction that was
        # actually measured so the wrong expectation cannot be re-asserted.
        @test stripes["radial_prominence"] < stripes["radial_prominence_baseline"]
        # The one leg that FAILED, pinned so it cannot be quietly retuned: the
        # order parameter reached 4.67× its null against a pre-registered 5×.
        # See §6d of the primary-source doc — the late-time single-realization
        # signal is weaker than the paper's, whose Fig. 4c stripes are an
        # ENSEMBLE average read over 700 ms–1.1 s, not one run at 500 ms.
        @test 4.0 < stripes["axis_order_over_null"] < acc["axis_order_over_null_min"]
        @test stripes["verdict"] == "REJECT"

        # THE NEGATIVE CONTROL, and it is the sharpest result here. Spiralling
        # B̂ to θ = 0 must destroy the axis (Fig. 4d3, "a homogeneous ring").
        # Judged on the frames where θ has actually reached 0 — the
        # pre-registered "last 20 %" window still held 40 ms at the full 35°
        # tilt and so did not implement the control at all.
        re = all_res["reanalysis"]
        @test re["stripes"]["pre_registered_window"]["over_null"] ≈
            stripes["axis_order_over_null"] rtol = 1e-6   # script reproduces the run
        ctl = re["control"]["declared_window"]
        @test ctl["n_frames"] >= 3
        @test ctl["over_null"] < 1.3            # measured 1.04 — AT the null
        @test ctl["over_baseline"] < 1.0        # measured 0.89
        @test ctl["misalign_deg"] > 25.0        # measured 33.5° — no axis at all
        # And the separation from the stripe arm, which is the whole claim.
        @test stripes["axis_order_over_null"] > 3 * ctl["over_null"]

        # The pre-registered control threshold was UNSATISFIABLE: 0.6× the t=0
        # baseline is 0.7× the isotropic null, i.e. below the noise floor. It is
        # recorded as failed rather than re-registered a second time.
        @test all_res["control"]["verdict"] == "REJECT"
        @test all_res["control"]["accept"]["control_axis_order_ratio_max"] <
            re["control"]["declared_window"]["over_baseline"]

        # A frames path was recorded, so a future metric change can be redone
        # from disk rather than from a 1.7 h re-run. This asserts the PATH was
        # written, not that the file is present here: `*.jld2` is gitignored and
        # the 48 MB of frames are local to the machine that ran them.
        for arm in ("stripes", "control")
            @test all_res[arm]["frames_path"] !== nothing
        end
    end
end
