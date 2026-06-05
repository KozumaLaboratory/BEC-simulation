# T-CG: Clebsch-Gordan projection-structure oracle
# (docs/design/hamiltonian_layered_architecture.md §4.3).
#
# The validation lattice's common blind spot is coefficient MAGNITUDE
# for homogeneous terms — exactly the 7 Eu channels SBI infers. This
# file verifies the STRUCTURE of coeff(θ) → c_S (the absolute a_S are
# physics unknowns, not bugs) through three mutually independent
# statements of the same projection:
#
#   route A  KU closed form      g_S = c₀ + c₁·λ_S,  λ_S = ½(S(S+1) − 2F(F+1))
#            (`_c0c1_to_gS`, interactions.jl:165)
#   route B  Wigner-6j transform g_S = Σ_k (2k+1){F F k; F F S} c_k
#            (`_cn_to_gS`, clebsch_gordan.jl:143)
#   route C  CG-sum rank-4 kernel V = Σ_S g_S Σ_M |SM⟩⟨SM|
#            (`channel_kernel`, tdhfb/channel_kernel.jl:45 — the TDHFB
#            statement of contact physics)
#
# plus the literature INVERSE maps (Ho 1998 / Ohmi-Machida 1998 for
# F=1; Kawaguchi-Ueda Phys. Rep. 520 (2012) for F=2) as
# declaration-independent anchors: the test states the inverse, the
# code states the forward — agreement is non-trivial.
#
# Incident pedigree: the rank-vs-channel confusion class
# (`ip[12] ≠ g_12`, recorded gotcha) is structurally killed by these
# cross-route checks. Internal consistency (round-trips, API gotchas)
# is already pinned by test_cn_gS_basis_mapping.jl — not duplicated
# here.

using Test
using SpinorBEC
using SpinorBEC: _c0c1_to_gS, _cn_to_gS, channel_kernel, spin_matrices
using LinearAlgebra
using Random

@testset "CG projection structure oracle (T-CG)" begin

    # ── Part 1: literature inverse anchors ────────────────────────────
    # F=1 (Ho 1998 / Ohmi-Machida 1998): c₀ = (g₀ + 2g₂)/3, c₁ = (g₂ − g₀)/3.
    @testset "F=1 textbook inverse (Ho / Ohmi-Machida)" begin
        c0, c1 = 0.7, -0.13
        g = _c0c1_to_gS(1, c0, c1)
        @test isapprox((g[0] + 2g[2]) / 3, c0; rtol=1e-13)
        @test isapprox((g[2] - g[0]) / 3, c1; rtol=1e-13)
    end

    # F=2 (Kawaguchi-Ueda review): c₀ = (4g₂ + 3g₄)/7, c₁ = (g₄ − g₂)/7.
    @testset "F=2 textbook inverse (Kawaguchi-Ueda)" begin
        c0, c1 = 0.9, 0.21
        g = _c0c1_to_gS(2, c0, c1)
        @test isapprox((4g[2] + 3g[4]) / 7, c0; rtol=1e-13)
        @test isapprox((g[4] - g[2]) / 7, c1; rtol=1e-13)
    end

    # ── Part 2: cross-route — KU λ_S form vs Wigner-6j rank-1 ─────────
    # F̂₁·F̂₂ is the rank-1 piece of the two-body decomposition, so the
    # 6j route at k=1 must be PROPORTIONAL to the KU λ_S pattern with
    # one S-independent constant. Ratio constancy across channels is
    # the projection structure, independent of any coefficient value.
    # (Channels are even-S, so S-parity phases cannot fake constancy.)
    @testset "cross-route: KU λ_S ∝ 6j k=1 (F-swept)" begin
        for F in (1, 2, 3, 6)
            g_ku = _c0c1_to_gS(F, 0.0, 1.0)      # pure c₁ ⇒ g_S = λ_S
            g_6j = _cn_to_gS(F, Dict(1 => 1.0))  # rank-1 via 6j transform
            Ss = sort(collect(keys(g_ku)))
            ratios = [g_6j[S] / g_ku[S] for S in Ss if abs(g_ku[S]) > 1e-12]
            @test length(ratios) >= 2
            @test all(r -> isapprox(r, ratios[1]; rtol=1e-10), ratios)
        end
    end

    # ── Part 3: cross-statement — channel kernel ≡ GP mean field ──────
    # On the 2-parameter span {1, F̂₁·F̂₂} the channel sum closes exactly:
    # Σ_S (c₀ + c₁λ_S) P_S = c₀ + c₁ F̂₁·F̂₂ (P_S resolution of identity),
    # so the TDHFB CG-sum kernel contracted with a condensate must equal
    # the GP mean field c₀·n·φ + c₁·(f⃗·F̂)·φ — two independent statements
    # of contact physics (the audit's "third statement" risk, closed).
    #
    # Contraction convention: V[c, c', c2, c2'] has (c, c2) bra and
    # (c', c2') ket; E = ½ Σ φ̄_c φ̄_{c2} V φ_{c'} φ_{c2'} with V
    # symmetric under pair exchange ⇒ δE/δφ̄_c is the FULL single
    # contraction (factor 1, no extra ½ or 2). If this test ever fails
    # by an exact factor of 2, derive before patching — that is a
    # convention drift between the GP and TDHFB statements, not a
    # tolerance issue.
    @testset "cross-statement: channel_kernel ≡ c₀n + c₁f⃗·F̂ (F-swept)" begin
        rng = MersenneTwister(11)
        for F in (1, 2, 3, 6)
            D = 2F + 1
            c0, c1 = 0.8, -0.17
            V = channel_kernel(F, _c0c1_to_gS(F, c0, c1))
            sm = spin_matrices(F)
            φ = randn(rng, ComplexF64, D)

            n = sum(abs2, φ)
            fx = real(φ' * (sm.Fx * φ))
            fy = real(φ' * (sm.Fy * φ))
            fz = real(φ' * (sm.Fz * φ))
            h_gp = c0 .* n .* φ .+
                   c1 .* (fx .* (sm.Fx * φ) .+ fy .* (sm.Fy * φ) .+ fz .* (sm.Fz * φ))

            h_ck = zeros(ComplexF64, D)
            for c in 1:D, cp in 1:D, c2 in 1:D, c2p in 1:D
                h_ck[c] += V[c, cp, c2, c2p] * conj(φ[c2]) * φ[cp] * φ[c2p]
            end

            @test isapprox(h_ck, h_gp; rtol=1e-10, atol=1e-12)
        end
    end
end
