# Spatially-varying LHY: ε_LHY(n, ζ) = n^(5/2) e₁(ζ), with e₁ tabulated against
# the local polarisation p = |⟨F⟩|/F.
#
# The claim that has to hold for this to be worth its cost is not "it runs" but
# "it beats the single-spinor table it replaces". Measured on converged
# weak-field Eu ground states (figs/eu_bscan_pin_tight), against a per-voxel
# BdG truth sampled by n^(5/2) weight:
#
#     frame       single-spinor    spatial
#     021            -1.78%         -0.83%
#     026            -3.61%         -0.63%
#     036            +0.81%         +0.31%
#     046            +3.54%         -0.05%
#
# Worst case 3.6% -> 0.8%, and the sign flip along the scan — the part that does
# not cancel in a B-comparison — is gone.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: compute_spatial_lhy, spatial_lhy_residual, _lhy_V, _lhy_energy,
    _lhy_needs_spin, _local_polarisation, _lhy_bdg_energy_density,
    _interpolate_1d, fp_ladder_coeff

const F_ = 6
const D_ = 13
const IP_ = InteractionParams(Dict(0 => 10.0, 1 => -0.02))

# A cloud whose polarisation runs 1 (centre) → 0 (edge): the shape a converged
# weak-field Eu ground state develops.
function _textured(n::Int=10)
    psi = zeros(ComplexF64, n, n, n, D_)
    c = (n + 1) / 2
    for i in 1:n, j in 1:n, k in 1:n
        r = clamp(sqrt((i - c)^2 + (j - c)^2 + (k - c)^2) / (n / 2), 0.0, 1.0)
        a = exp(-2r^2)
        psi[i, j, k, 1] = a * (1 - r)
        psi[i, j, k, F_ + 1] = a * r
    end
    psi
end

_uniform(n::Int=8) = (p=zeros(ComplexF64, n, n, n, D_);
    p[:, :, :, 1].=1.0; p)

@testset "Spatially-varying LHY" begin
    @testset "abstains when there is no texture to follow" begin
        # A single-spinor table is already exact for a uniform state, so paying
        # for BdG solves would buy nothing.
        @test compute_spatial_lhy(; psi_init=_uniform(), F=F_, interactions=IP_) ===
            nothing
    end

    @testset "builds an e₁(p) table over the polarisations present" begin
        lhy = compute_spatial_lhy(; psi_init=_textured(), F=F_, interactions=IP_,
            n_bins=8)
        @test lhy isa SpatialLHY
        @test lhy.F == F_
        @test issorted(lhy.polarisations)
        @test length(lhy.polarisations) == length(lhy.e1_values) >= 2
        @test all(0 .<= lhy.polarisations .<= 1)
        @test all(>(0), lhy.e1_values)
        # e₁ falls as the state polarises — FM (p=1) is softer than polar (p=0).
        @test lhy.e1_values[end] < lhy.e1_values[1]
        @test length(lhy.fp_coeffs) == D_
    end

    @testset "V_LHY = (5/2) n^(3/2) e₁(p), and only SpatialLHY reads p" begin
        lhy = compute_spatial_lhy(; psi_init=_textured(), F=F_, interactions=IP_,
            n_bins=8)
        for n in (0.5, 1.0, 3.0), p in (0.1, 0.5, 0.9)
            e1 = _interpolate_1d(lhy.polarisations, lhy.e1_values, p)
            @test _lhy_V(n, p, lhy) ≈ 2.5 * e1 * n^1.5 rtol = 1e-12
        end
        @test _lhy_V(0.0, 0.5, lhy) == 0.0
        # the p argument must be inert for every other LHY, or adding it would
        # have changed existing physics
        for other in (NoLHY(), ScalarLHY(1.5), nothing)
            for p in (0.0, 0.5, 1.0)
                @test _lhy_V(2.0, p, other) == _lhy_V(2.0, other)
            end
            @test !_lhy_needs_spin(other)
        end
        @test _lhy_needs_spin(lhy)
    end

    @testset "the propagator's p matches a direct ⟨F⟩ computation" begin
        # `_local_polarisation` reuses the density loop's component reads via the
        # O(D) ladder form; it must agree with the explicit spin matrices or the
        # propagator and the physics part ways.
        sm = spin_matrices(F_)
        Fx, Fy, Fz = Matrix{ComplexF64}(sm.Fx), Matrix{ComplexF64}(sm.Fy),
        Matrix{ComplexF64}(sm.Fz)
        fp = [fp_ladder_coeff(F_, F_ - (c - 1)) for c in 1:D_]
        for trial in 1:12
            z = randn(ComplexF64, D_)
            P = reshape(copy(z), 1, D_)
            s = sum(abs2, z)
            got = _local_polarisation(P, 1, s, F_, fp, Val(D_))
            zn = z ./ norm(z)
            want = sqrt(real(zn' * Fx * zn)^2 + real(zn' * Fy * zn)^2 +
                        real(zn' * Fz * zn)^2) / F_
            @test got ≈ want rtol = 1e-10
        end
        @test _local_polarisation(reshape(zeros(ComplexF64, D_), 1, D_), 1, 0.0,
            F_, fp, Val(D_)) == 0.0
    end

    @testset "energy and propagator use the same e₁(p)" begin
        # If these drift the term is silently wrong — the bug class the HamTerm
        # protocol exists to prevent. E = Σ n^(5/2) e₁ dV must equal (2/5)Σ n V.
        lhy = compute_spatial_lhy(; psi_init=_textured(), F=F_, interactions=IP_,
            n_bins=8)
        psi = _textured(8)
        n_pts = (8, 8, 8)
        dV = 0.25
        E = _lhy_energy(psi, lhy, D_, 3, n_pts, dV)
        P = reshape(psi, prod(n_pts), D_)
        E2 = 0.0
        for i in 1:prod(n_pts)
            s = sum(c -> abs2(P[i, c]), 1:D_)
            s < 1e-30 && continue
            p = _local_polarisation(P, i, s, F_, lhy.fp_coeffs, Val(D_))
            E2 += 0.4 * s * _lhy_V(s, p, lhy)      # (2/5) n V = n^(5/2) e₁
        end
        @test E ≈ E2 * dV rtol = 1e-10
        @test E > 0
    end

    @testset "it beats the single-spinor table it replaces" begin
        # The claim the whole thing rests on. Truth = per-voxel BdG on the actual
        # local spinors; the two models are the tabulated e₁(p) and one spinor
        # applied everywhere.
        psi = _textured(10)
        lhy = compute_spatial_lhy(; psi_init=psi, F=F_, interactions=IP_, n_bins=10)
        n = dropdims(sum(abs2, psi; dims=4); dims=4)
        cut = 1e-6 * maximum(n)
        peak = let I = argmax(n)
            z = ComplexF64[psi[I, c] for c in 1:D_]
            z ./ norm(z)
        end
        e1_single = _lhy_bdg_energy_density(peak, 1.0, F_, IP_, ZeemanParams(), 0.0,
            nothing, nothing, nothing; rtol=1e-4)
        num_t = 0.0
        num_s = 0.0
        den = 0.0
        for I in CartesianIndices(size(n))
            n[I] < cut && continue
            z = ComplexF64[psi[I, c] for c in 1:D_]
            nz = norm(z)
            nz < 1e-14 && continue
            z ./= nz
            fz = sum(c -> (F_ - (c - 1)) * abs2(z[c]), 1:D_)
            fre = sum(c -> lhy.fp_coeffs[c] * real(conj(z[c - 1]) * z[c]), 2:D_)
            fim = sum(c -> lhy.fp_coeffs[c] * imag(conj(z[c - 1]) * z[c]), 2:D_)
            p = clamp(sqrt(fre^2 + fim^2 + fz^2) / F_, 0.0, 1.0)
            w = n[I]^2.5
            num_t +=
                w * _lhy_bdg_energy_density(z, 1.0, F_, IP_, ZeemanParams(),
                    0.0, nothing, nothing, nothing; rtol=1e-3)
            num_s += w * _interpolate_1d(lhy.polarisations, lhy.e1_values, p)
            den += w
        end
        truth = num_t / den
        err_spatial = abs(num_s / den - truth) / truth
        err_single = abs(e1_single - truth) / truth
        @test err_spatial < err_single
        @test err_spatial < 0.02
    end

    @testset "reports its own error bar" begin
        # p does not determine ζ, so the table carries a residual. It has to be
        # measurable rather than assumed small — that number is what should be
        # quoted with any result that uses this.
        psi = _textured()
        lhy = compute_spatial_lhy(; psi_init=psi, F=F_, interactions=IP_, n_bins=8)
        r = spatial_lhy_residual(lhy, psi, F_, IP_; n_probe=2, rtol=1e-3)
        @test isfinite(r)
        @test 0.0 <= r < 0.10
    end

    @testset "rejected inputs" begin
        @test_throws ArgumentError SpatialLHY([0.5], [1.0], F_, ones(D_))
        @test_throws ArgumentError SpatialLHY([1.0, 0.0], [1.0, 2.0], F_, ones(D_))
        @test_throws ArgumentError SpatialLHY([0.0, 1.0], [1.0], F_, ones(D_))
        @test_throws ArgumentError SpatialLHY([0.0, 1.0], [1.0, 2.0], F_, ones(3))
        @test_throws ArgumentError compute_spatial_lhy(; psi_init=_textured(),
            F=F_, interactions=IP_, n_bins=1)
        @test_throws DimensionMismatch compute_spatial_lhy(;
            psi_init=zeros(ComplexF64, 4, 4, 4, 5), F=F_, interactions=IP_)
    end
end
