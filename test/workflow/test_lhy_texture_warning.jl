# Gate: every spinor LHY table is built for ONE spinor and applied at every
# voxel. That is exact for a uniform state and an approximation otherwise, and
# nothing used to say so.
#
# The measurement that sets the threshold (converged weak-field Eu ground
# states, figs/eu_bscan_pin_tight, F=6, c0=10, c1=-0.02, comparing the shipped
# single-spinor table against a per-voxel LDA over the full n^(5/2) weight):
#
#     |⟨F⟩|/F spread   ε_LHY error
#          0.00          +0.00%
#          0.375         -1.48%
#          0.892         -4.48%
#          0.901         +4.87%
#
# The sign FLIPS along the scan, so it does not cancel in a B-comparison —
# which is the reason this warns rather than being left as a docstring caveat.
#
# Only the magnitude of ⟨F⟩ matters. A pure DIRECTION texture is free: ε_LHY is
# an SO(3) scalar for contact (invariant to machine precision, measured across
# the full canting family) and moves 0.25% with the DDI at ε_dd ≈ 0.05.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _lhy_texture_spread, _warn_lhy_texture, _LHY_TEXTURE_WARN

@testset "LHY single-spinor texture warning" begin
    F = 6
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    sys = SpinSystem(F)

    @testset "direction textures are uniform in |⟨F⟩| ⇒ no warning" begin
        # flower / radial_spin_vortex / skyrmion rotate a fully polarised
        # spinor in space. |⟨F⟩|/F = 1 everywhere, so the single-spinor table
        # is exact and must stay silent.
        for st in (:m_plus_F, :m_minus_F, :flower, :radial_spin_vortex,
            :chiral_spin_vortex, :polar)
            psi = init_psi(grid, sys; state=st)
            spread, _, _ = _lhy_texture_spread(psi, F)
            @test spread < 1e-6
            @test spread <= _LHY_TEXTURE_WARN
            @test _warn_lhy_texture(:full_bdg, psi, F) === nothing
        end
    end

    @testset "a magnitude texture is detected and reported" begin
        # Build one directly: |⟨F⟩|/F running from 1 at the centre to 0 outside,
        # which is the shape a converged weak-field Eu ground state develops.
        n = 16
        psi = zeros(ComplexF64, n, n, n, 2F + 1)
        c = (n + 1) / 2
        for i in 1:n, j in 1:n, k in 1:n
            r = sqrt((i - c)^2 + (j - c)^2 + (k - c)^2) / (n / 2)
            amp = exp(-2r^2)
            x = clamp(r, 0.0, 1.0)                 # 0 at centre → 1 at edge
            psi[i, j, k, 1] = amp * (1 - x)        # m = +F
            psi[i, j, k, F + 1] = amp * x          # m = 0
        end
        spread, peak_f, mean_f = _lhy_texture_spread(psi, F)
        @test spread > _LHY_TEXTURE_WARN
        @test peak_f > mean_f                      # peak is more polarised
        @test 0.0 <= mean_f <= 1.0
        @test_logs (:warn, r"textured in \|⟨F⟩\|/F") match_mode = :any begin
            _warn_lhy_texture(:full_bdg, psi, F)
        end
        # The closed forms assume their own fixed ansatz, so they are at least
        # as exposed — they must warn too, with wording naming the ansatz.
        @test_logs (:warn, r"fixed :polar_contact ansatz") match_mode = :any begin
            _warn_lhy_texture(:polar_contact, psi, F)
        end
    end

    @testset "degenerate inputs do not throw" begin
        @test _lhy_texture_spread(nothing, F) == (0.0, 1.0, 1.0)
        @test _lhy_texture_spread(zeros(ComplexF64, 4, 4, 4, 2F + 1), F) ==
            (0.0, 1.0, 1.0)
        # component count not matching 2F+1 ⇒ abstain rather than mis-measure
        @test _lhy_texture_spread(ones(ComplexF64, 4, 4, 4, 3), F) == (0.0, 1.0, 1.0)
    end

    @testset "make_workspace warns through the real path" begin
        # The warning has to be reachable from where users actually build a
        # workspace, not just from the helper.
        atom = resolve_atom(:Eu151)
        g = make_grid(GridConfig((12, 12, 12), (8.0, 8.0, 8.0)))
        psi = zeros(ComplexF64, 12, 12, 12, 2F + 1)
        for i in 1:12, j in 1:12, k in 1:12
            r = sqrt((i - 6.5)^2 + (j - 6.5)^2 + (k - 6.5)^2) / 6
            amp = exp(-2r^2)
            psi[i, j, k, 1] = amp * (1 - clamp(r, 0, 1))
            psi[i, j, k, F + 1] = amp * clamp(r, 0, 1)
        end
        @test_logs (:warn, r"applied at every voxel") match_mode = :any begin
            make_workspace(; grid=g, atom=atom,
                interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.02)),
                potential=HarmonicTrap((1.0, 1.0, 1.0)),
                sim_params=SimParams(; dt=0.001, n_steps=1),
                psi_init=psi, spinor_lhy=:polar_contact)
        end
    end
end
