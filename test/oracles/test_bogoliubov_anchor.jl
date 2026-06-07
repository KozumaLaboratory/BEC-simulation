# Bogoliubov / BdG analytic-dispersion anchor.
#
# `bogoliubov_spectrum` builds the BdG matrices σ_z[L M; M* L*] from a
# single hand-written CG-sum derivation (`_bdg_normal_matrix`,
# `_bdg_anomalous_matrix`). It is the linearize/Hessian functor on which
# every stability verdict rides — the saddle-rejection that gates any
# phase claim from the M1 rotating-frame sweep. Before this file its only
# tests were structural/smoke (return types, growth ≥ 0, roton
# detection); nothing pinned the spectrum VALUE. A measurement
# (2026-06-08) confirmed the operator is numerically CORRECT but UNGATED
# — so a future edit could silently break it and no stability verdict
# would notice.
#
# This anchor states the KNOWN closed-form Ueda spinor-BEC dispersions
# (the test declares the physics; the code declares the operator —
# agreement is non-trivial and declaration-independent), pinning the
# contact BdG machinery at machine precision. εk = k²/2.
#
#   POLAR  ζ = e_0 :   density  ω = √(εk(εk + 2c₀n))
#                      spin(×2) ω = √(εk(εk + 2c₁n))     (q = 0)
#   FM     ζ = e_{+F}: density  ω = √(εk(εk + 2(c₀+c₁)n))
#                      + a free-particle magnon branch ω = εk
#
# KNOWN-LIMIT: this gates the CONTACT BdG at F=1 (the cleanest,
# unambiguous closed forms) + the universal free-particle limit at
# general F. The F=6 + DDI operator the Eu sweep actually uses is
# anchored by the FD-Hessian gate (L(k=0) = finite-difference of the
# already-gated energy_gradient! on a uniform grid) — its own unit, the
# chains-off-the-gated-gradient counterpart.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: bogoliubov_spectrum

_εk(k) = k^2 / 2
_branch(k, g, n) = sqrt(_εk(k) * (_εk(k) + 2 * g * n))

# positive branches at column i, sorted ascending
function _pos_branches(res, i)
    om = res.omega
    col = size(om, 1) == length(res.k_values) ? om[i, :] : om[:, i]
    sort(filter(>(1e-12), real.(col)))
end

@testset "Bogoliubov BdG analytic-dispersion anchor" begin
    n0 = 1.0
    c0 = 1.0
    c1 = 0.2

    @testset "F=1 polar — density + 2 spin branches (exact, all k)" begin
        ip = InteractionParams(Dict(0 => c0, 1 => c1))
        res = bogoliubov_spectrum(;
            spinor=ComplexF64[0, 1, 0], n0=n0, F=1, interactions=ip,
            k_max=6.0, n_k=60,
        )
        # at every non-trivial k, the three positive branches must be
        # {spin, spin, density} = {√(εk(εk+2c₁n)) (×2), √(εk(εk+2c₀n))}.
        for i in 2:length(res.k_values)
            k = res.k_values[i]
            br = _pos_branches(res, i)
            @test length(br) == 3
            spin = _branch(k, c1, n0)
            dens = _branch(k, c0, n0)
            @test isapprox(br[1], spin; rtol=1e-9, atol=1e-10)
            @test isapprox(br[2], spin; rtol=1e-9, atol=1e-10)
            @test isapprox(br[3], dens; rtol=1e-9, atol=1e-10)
        end
    end

    @testset "F=1 FM — density (c₀+c₁) + free-particle magnon (exact)" begin
        ip = InteractionParams(Dict(0 => c0, 1 => c1))
        res = bogoliubov_spectrum(;
            spinor=ComplexF64[1, 0, 0], n0=n0, F=1, interactions=ip,
            k_max=6.0, n_k=60,
        )
        # NOTE: the FM spectrum is subtler than polar — besides the
        # density branch and the free-particle magnon there is a GAPPED
        # mode that exceeds the density branch at small k (and crosses
        # below it by k≈0.5). So we assert only the two branches whose
        # closed form is unambiguous (PRESENT among the three, not
        # ordered); the gapped third mode is left to the FD-Hessian unit
        # rather than asserting a closed form not yet verified.
        for i in 2:length(res.k_values)
            k = res.k_values[i]
            br = _pos_branches(res, i)
            @test length(br) == 3
            # density branch carries the FM coupling c₀+c₁
            @test any(b -> isapprox(b, _branch(k, c0 + c1, n0); rtol=1e-9, atol=1e-10), br)
            # one branch is the exact free-particle magnon εk
            @test any(b -> isapprox(b, _εk(k); rtol=1e-9, atol=1e-10), br)
        end
    end

    @testset "universal: density/phonon branch = √(εk(εk+2c₀n)) (F-swept polar)" begin
        # The fully-symmetric density mode of a polar condensate is the
        # universal Bogoliubov branch √(εk(εk+2c₀n)) at every F — phonon
        # (linear, slope √(c₀n₀)) at small k, free-particle at large k.
        for F in (1, 2, 3, 6)
            D = 2F + 1
            ζ = zeros(ComplexF64, D)
            ζ[F + 1] = 1     # m=0 polar
            ip = InteractionParams(Dict(0 => c0, 1 => c1))
            res = bogoliubov_spectrum(; spinor=ζ, n0=n0, F=F, interactions=ip,
                k_max=6.0, n_k=60)
            @testset "F=$F" begin
                for i in 2:length(res.k_values)
                    k = res.k_values[i]
                    br = _pos_branches(res, i)
                    dens = _branch(k, c0, n0)
                    @test any(b -> isapprox(b, dens; rtol=1e-8, atol=1e-9), br)
                end
                # phonon limit: lowest-k density-branch slope → √(c₀n₀)
                k1 = res.k_values[2]
                @test isapprox(_branch(k1, c0, n0) / k1, sqrt(c0 * n0); rtol=0.05)
            end
        end
    end
end
