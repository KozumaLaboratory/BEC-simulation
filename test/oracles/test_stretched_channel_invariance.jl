using Test
using FFTW
using SpinorBEC
using SpinorBEC: interaction_params_from_constraint, compute_c_total, c_to_g,
    _bdg_contact_matrices, lhy_energy_fm, lhy_energy_polar,
    epsilon_LHY_F6_Ih
using LinearAlgebra

# WHICH Eu observables cannot be moved by the six unmeasured scattering channels.
#
# ¹⁵¹Eu has one measured input — a₁₂ = 110(4) a_B, the STRETCHED channel, which
# Matsui et al. state is "the only parameter experimentally known". The other six
# even channels (S = 0…10) have never been measured. Production expresses that
# ignorance as one number, `c1_ratio` = r, at fixed c_total: the constraint
# c₀ + F²c₁ = c_total IS the statement g_{2F} = c_total, since
# g_S = c₀ + c₁·(S(S+1) − 2F(F+1))/2 gives λ_{2F} = F².
#
# So r is a knob that sweeps the unknown while holding the known fixed. This
# file pins what such a sweep CANNOT move — the class of results quotable before
# the atomic-physics measurement arrives (issue #342, and the table in
# `docs/campaign/as_dependency_map.md`).
#
# The physics: two bosons in the fully stretched pair |−F,−F⟩ have total
# M = −2F, and the only symmetric two-body channel with that M is S = 2F. One
# magnon on top (|−F,−F+1⟩, M = −2F+1) is likewise pure S = 2F. From m = −F+2
# upward a second channel opens and the ignorance enters.
#
# Every invariance below is paired with a control that MOVES. An invariance test
# whose knob does nothing anywhere is a degenerate knob, and this repository has
# already published one null from exactly that.

# 0, the "Matsui AFM" value 1/F² (= 1/36 at F=6), and the other sign. Written
# in units of 1/F² so the F=2 case sits at the same distance from the c₀ pole at
# r = −1/F², rather than 9× closer to it.
_rs(F) = (0.0, 1 / F^2, -1 / (2F^2))
const _RS = _rs(6)

@testset "stretched-state observables ignore the unmeasured channels" begin
    @testset "the knob really moves the channel vector (calibration)" begin
        c_total = 4813.4
        for F in (2, 6)
            gs = [
                c_to_g(F, interaction_params_from_constraint(;
                    c_total, c1_ratio=r, F=F)) for r in _rs(F)
            ]
            # g_{2F} pinned by construction …
            for g in gs
                @test isapprox(g[2F], c_total; rtol=1e-12)
            end
            # … and every other channel swung by O(1) of it.
            spread = maximum(abs(gs[i][0] - gs[1][0]) for i in 2:length(gs))
            @test spread > 0.5 * abs(c_total)
        end
    end

    @testset "F=$F: BdG matrix elements on the stretched condensate" for F in (2, 6)
        D = 2F + 1
        c_total = 4813.4
        stretched = zeros(ComplexF64, D)
        stretched[D] = 1.0                      # m = −F
        mats(r) = _bdg_contact_matrices(stretched, F,
            interaction_params_from_constraint(; c_total, c1_ratio=r, F=F),
            ZeemanParams(0.0, 0.0))

        ref_h, ref_M, _, _ = mats(0.0)
        # The two channel-blind sectors, and their exact values.
        @test isapprox(real(ref_h[D, D]), c_total; rtol=1e-12)          # m = −F
        @test isapprox(real(ref_h[D - 1, D - 1]), c_total / 2; rtol=1e-12) # m = −F+1
        # Exactly one anomalous element: the condensate pairs only with itself.
        nz = count(x -> abs(x) > 1e-9 * c_total, ref_M)
        @test nz == 1
        @test isapprox(real(ref_M[D, D]), c_total; rtol=1e-12)

        for r in _rs(F)[2:end]
            h, M, _, _ = mats(r)
            @test isapprox(real(h[D, D]), real(ref_h[D, D]); rtol=1e-12)
            @test isapprox(real(h[D - 1, D - 1]), real(ref_h[D - 1, D - 1]); rtol=1e-12)
            @test isapprox(real(M[D, D]), real(ref_M[D, D]); rtol=1e-12)
            # CONTROL: the next rung up must move, or the knob is dead.
            @test !isapprox(real(h[D - 2, D - 2]), real(ref_h[D - 2, D - 2]); rtol=1e-3)
        end
    end

    # The same statement through the PRODUCTION path — the HamTerm registry —
    # rather than through the BdG helper, because the matrix element and the
    # propagator's coefficient are separate statements of the same physics.
    @testset "registry energy of a uniform stretched cloud" begin
        F, D = 6, 13
        n = 6
        grid = make_grid(GridConfig((n, n, n), (4.0, 4.0, 4.0)))
        dV = cell_volume(grid)
        c_total = 4813.4

        function total_contact(r, comp)
            ip = interaction_params_from_constraint(; c_total, c1_ratio=r, F=F)
            ws = make_workspace(; grid, atom=Eu151, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
                sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
                fft_flags=FFTW.ESTIMATE)
            psi = zeros(ComplexF64, n, n, n, D)
            if comp === :stretched
                psi[:, :, :, D] .= 1.0
            else                                  # equal superposition of two m
                psi[:, :, :, D] .= 1.0
                psi[:, :, :, D - 2] .= 1.0
            end
            psi ./= sqrt(sum(abs2, psi) * dV)
            ws.state.psi .= psi
            e = energy_decomposition(ws)
            e.total
        end

        ref = total_contact(0.0, :stretched)
        # A uniform cloud has zero kinetic and no trap here, so `total` IS the
        # contact energy: ½ g_{2F} ∫n².
        @test isapprox(ref, 0.5 * c_total * (1 / (dV * n^3))^2 * dV * n^3; rtol=1e-10)
        for r in _RS[2:end]
            @test isapprox(total_contact(r, :stretched), ref; rtol=1e-10)
        end
        # CONTROL: admit one m = −4 atom and the same sweep moves the energy.
        ref_mix = total_contact(0.0, :mixed)
        @test !isapprox(total_contact(1 / 36, :mixed), ref_mix; rtol=1e-3)
    end

    @testset "LHY: the FM closed form is the channel-blind one" begin
        F = 6
        c_total = 4813.4
        n = 3.313e-3
        gdict(r) = c_to_g(F, interaction_params_from_constraint(;
            c_total, c1_ratio=r, F=F))

        fm0 = lhy_energy_fm(n, F, gdict(0.0))
        @test fm0 > 0
        for r in _RS[2:end]
            # ε_LHY^FM = (8/15π²)(g_{2F} n)^{5/2} — g_{2F} is the measured one.
            @test isapprox(lhy_energy_fm(n, F, gdict(r)), fm0; rtol=1e-12)
        end
        # CONTROL: the polar and I_h closed forms read the whole channel vector.
        @test !isapprox(lhy_energy_polar(n, F, gdict(1 / 36)),
            lhy_energy_polar(n, F, gdict(0.0)); rtol=1e-2)
        gv(r) = [gdict(r)[S] for S in 0:2:2F]
        @test !isapprox(epsilon_LHY_F6_Ih(n, gv(1 / 36)),
            epsilon_LHY_F6_Ih(n, gv(0.0)); rtol=1e-2)
    end

    # q and p come from Breit-Rabi and the measured hyperfine constant. That
    # they take no interaction argument is the whole claim, so assert it on the
    # method signature rather than by running it twice and finding two equal
    # numbers — equal numbers are also what a silently-ignored argument gives.
    @testset "the Zeeman coefficients cannot see the channels" begin
        ms = methods(compute_quadratic_zeeman)
        @test !isempty(ms)
        sigs = [string(m.sig) for m in ms]
        @test !any(s -> occursin("InteractionParams", s), sigs)
        sigs_p = [string(m.sig) for m in methods(linear_zeeman_p)]
        @test !isempty(sigs_p)
        @test !any(s -> occursin("InteractionParams", s), sigs_p)
    end
end
