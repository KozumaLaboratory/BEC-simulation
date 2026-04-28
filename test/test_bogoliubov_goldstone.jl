using Test
using LinearAlgebra
using SpinorBEC

# Bogoliubov ferromagnetic Goldstone-mode regression test.
#
# Round-3 code review flagged a subtle question: in `_bdg_k_scan`, μ is
# computed as `dot(spinor, (Z + n₀·h_mf)·spinor)` where `h_mf` includes the
# k̂-direction-dependent DDI piece. This makes μ direction-dependent — for
# Eu (F=6, c_dd × F² ~ 275 000) the bias is huge.
#
# The canonical check: a homogeneous ferromagnetic state in zero magnetic
# field spontaneously breaks SU(2). The associated Goldstone (magnon) mode
# must satisfy ω(k → 0) → 0. If μ is computed in a way that leaves a
# residual gap, this test fails.
#
# We test the contact-only and DDI-on cases separately so a future μ-fix
# can be evaluated against the same baseline.

@testset "Bogoliubov ferromagnetic Goldstone mode (μ convention)" begin
    F = 1
    D = 2F + 1
    n0 = 0.1
    spinor_FM = ComplexF64[1.0, 0.0, 0.0]   # |m = +F⟩, fully polarized

    @testset "F=1 contact-only ferromagnetic phase, zero field" begin
        # c1 < 0 → ferromagnetic regime in F=1 (KU Eq. 49-ish).
        ip = InteractionParams(50.0, -2.0)
        zee = ZeemanParams(0.0, 0.0)

        bdg = bogoliubov_spectrum(;
            spinor=spinor_FM, n0=n0, F=F,
            interactions=ip, zeeman=zee,
            c_dd=0.0,
            k_max=0.05, n_k=50,
            k_direction=(0.0, 0.0, 1.0),
        )

        # Smallest |Re ω| over the BdG branches at the smallest k probed.
        # Goldstone mode ⇒ this should be ≪ the typical mode spacing.
        omega_at_smallest_k = bdg.omega[1, :]
        gap = minimum(abs.(real.(omega_at_smallest_k)))
        # Currently FAILS (gap ≈ 0.4 for c1=-2, n0=0.1) — this is the
        # round-3 review finding. The chemical potential convention in
        # `_bdg_k_scan` (line 77-78) yields a residual k=0 gap. Marked
        # @test_broken to pin the current behaviour without breaking CI;
        # remove `_broken` once the μ convention is corrected.
        @test_broken gap < 1e-6
        @info "F=1 FM gap at k=0 = $(round(gap; sigdigits=4))  (expected ~0 for true Goldstone)"
    end

    @testset "F=6 DDI-on ferromagnetic, k̂ ∥ magnetization, zero field" begin
        # Reproduce the regime where the round-3 reviewer's concern is
        # quantitative: c_dd × F² ~ 275 000 for Eu-scale couplings. With
        # k̂ ∥ ẑ (the magnetization direction), the DDI is diagonal in the
        # F_z basis, and the issue (if any) shows up cleanly.
        F6 = 6
        ip6 = InteractionParams(100.0, 0.0)   # c0-only contact
        zee6 = ZeemanParams(0.0, 0.0)
        c_dd_eu = 200.0                        # smaller than Eu run-time, but
        # still big enough to amplify a
        # broken-μ gap relative to the
        # contact-only mode spacing.
        spinor6_FM = ComplexF64[1.0, zeros(ComplexF64, 12)...]

        bdg = bogoliubov_spectrum(;
            spinor=spinor6_FM, n0=n0, F=F6,
            interactions=ip6, zeeman=zee6,
            c_dd=c_dd_eu,
            k_max=0.05, n_k=50,
            k_direction=(0.0, 0.0, 1.0),
        )

        omega_at_smallest_k = bdg.omega[1, :]
        gap = minimum(abs.(real.(omega_at_smallest_k)))

        # If μ were wrong by O(c_dd · F² · n0) = 0.1 × 200 × 36 = 720, the
        # lowest mode at k → 0 would carry a finite gap of that order.
        # Currently FAILS at gap ≈ 1440 (twice that order). Pinned via
        # @test_broken so the test exists and tracks the issue without
        # breaking CI. Remove `_broken` once μ convention is corrected.
        @test_broken gap < 0.1
        @info "F=6 FM Goldstone gap = $(round(gap; sigdigits=4))  (μ convention check; expected ~0)"
    end
end
