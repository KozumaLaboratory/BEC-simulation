# Trapped spinor excitation FREQUENCIES ≡ homogeneous BdG in the uniform limit,
# plus the analytic F=1 polar closed forms — the ω-axis operator anchor.
#
# `trapped_bdg_frequencies` reduces the symplectic problem `∂_tδ = J(½A)δ` onto
# the complexification of the constrained Hessian's soft eigenvectors. On a
# UNIFORM condensate in a periodic box with no trap the exact eigenmodes are
# plane waves, so every frequency must be a homogeneous 2D×2D BdG eigenvalue at
# one of the box's discrete k-modes — and for F=1 polar those are the closed
# forms this repo already anchors analytically in `test_bogoliubov_anchor.jl`:
#
#   density  ω = √(εk(εk + 2c₀n))      spin (×2)  ω = √(εk(εk + 2c₁n))
#
# Two independent constructions must agree: the trapped side is a
# finite-difference reduction of the gated `energy_gradient!` through the
# Hessian, the homogeneous side is a hand-written CG-sum matrix. Neither knows
# about the other.
#
# THE FIRST TESTSET IS THE ONE THAT MATTERS MOST, and not for the reason the
# issue's checklist assumed. Comparing the HESSIAN's low eigenvalues `λ` to a
# frequency is a category error, not a loose comparison: in the uniform scalar
# limit `λ₋ = 2εk ∝ k²` while `ω ∝ k`. The `λ is not ω` testset pins that with
# the identity `ω = √(λ₋λ₊)/2` and with the k-scaling exponents, so nobody
# re-reads `trapped_bdg_low_modes` as a spectrum.

using Test
using LinearAlgebra
using Random
using SpinorBEC
using SpinorBEC: trapped_bdg_frequencies, trapped_bdg_low_modes, trapped_bdg_spectrum,
    constrained_hessian_params, bogoliubov_spectrum, energy_gradient!, cell_volume

_εk(k) = k^2 / 2
_branch(k, g, n) = sqrt(_εk(k) * (_εk(k) + 2 * g * n))

# Uniform spinor on a periodic 1D box, no trap. `n0` is the per-voxel density.
function _uniform_box(spinor; n=16, L=8.0, F=1, c0=1.0, c1=0.2, n0=1.0, c_dd=0.0)
    D = 2F + 1
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    grid = make_grid(GridConfig((n,), (L,)))
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, potential=NoPotential(),
        enable_ddi=(c_dd != 0.0), c_dd=c_dd,
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
    )
    ψ = zeros(ComplexF64, n, D)
    for i in 1:n, c in 1:D
        ψ[i, c] = sqrt(n0) * spinor[c]
    end
    (; ws, ψ, grid, ip, dk=2π / L)
end

# Positive frequencies of the homogeneous BdG at exactly the box's k-modes:
# `range(0, 2dk; length=3)` lands on {0, dk, 2dk}.
function _homogeneous_omegas(spinor, F, ip; n0, dk, c_dd=0.0, k_direction=(1.0, 0.0, 0.0))
    res = bogoliubov_spectrum(;
        spinor=collect(ComplexF64, spinor), n0=n0, F=F, interactions=ip, c_dd=c_dd,
        k_max=2dk, n_k=3, k_direction=k_direction,
    )
    @test isapprox(res.k_values[2], dk; rtol=1e-12)      # the grid really is the box's
    sort(filter(>(1e-12), vec(real.(res.omega))))
end

@testset "trapped ω ≡ homogeneous BdG (uniform F=1 polar box) + closed forms" begin
    fx = _uniform_box(ComplexF64[0, 1, 0])
    p = constrained_hessian_params(fx.ws, fx.ψ)
    g = similar(fx.ψ)
    fill!(g, 0)
    energy_gradient!(g, fx.ψ, fx.ws)
    # Precondition of the whole construction: ψ must be stationary, else μ and
    # every frequency built on it are meaningless.
    @test sqrt(sum(abs2, g .- 2p.μ .* fx.ψ) * p.dV) < 1e-12

    r = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80, hess_tol=1e-9,
        params=p, rng=MersenneTwister(1))

    # Reduction health: the subspace is J-closed, the ±λ pair symmetry holds,
    # and the reduced Hessian is symmetric to the finite-difference floor.
    @test r.j_min > 0.99
    @test r.pair_residual < 1e-6
    @test r.hessian_symmetry_defect < 1e-6
    @test r.subspace_dim == 2 * r.n_hessian
    @test !r.lhy_active                    # mean-field spectrum, and it says so

    trusted = findall(<(1e-6), r.residuals)
    @test length(trusted) >= 8             # the whole returned block is usable here

    # CONTAINMENT: every trusted frequency is a homogeneous eigenvalue at a box
    # k-mode. The homogeneous side is `bogoliubov_spectrum`, itself anchored to
    # the analytic dispersion — so agreement here transitively pins the
    # symplectic reduction, the J convention, and the ½ in ½A.
    ref = _homogeneous_omegas(ComplexF64[0, 1, 0], 1, fx.ip; n0=1.0, dk=fx.dk)
    for k in trusted
        r.omega[k] < 1e-3 && continue      # the k=0 Goldstone pair, no ref partner
        @test minimum(abs(r.omega[k] - w) for w in ref) < 1e-6
    end

    # CLOSED FORMS + MULTIPLICITY. ±k give the same ω, so at |k| = dk the spin
    # branch is 4-fold (2 magnons × 2 signs) and the density branch 2-fold.
    ω_spin = _branch(fx.dk, 0.2, 1.0)
    ω_dens = _branch(fx.dk, 1.0, 1.0)
    @test count(w -> isapprox(w, ω_spin; atol=1e-6), r.omega) == 4
    @test count(w -> isapprox(w, ω_dens; atol=1e-6), r.omega) == 2

    # GOLDSTONE / GAUGE bookkeeping. The polar state breaks the two transverse
    # spin rotations ⇒ exactly TWO ω≈0 modes, identified by generator. The
    # gauge direction is NOT among them: `P` removes ψ and iψ together, so its
    # overlap is ~0 for every mode, and that zero is the evidence the gauge pair
    # was deflated rather than mislabelled as physics.
    zero_modes = findall(<(1e-3), r.omega)
    @test length(zero_modes) == 2
    gauge_col = findfirst(==(:gauge), r.generators)
    sx = findfirst(==(:spin_x), r.generators)
    sy = findfirst(==(:spin_y), r.generators)
    @test maximum(@view r.overlaps[:, gauge_col]) < 1e-6
    for k in zero_modes
        @test r.labels[k] in (:zero_mode_spin_x, :zero_mode_spin_y)
        @test r.overlaps[k, sx] > 0.9      # spin_x/spin_y are degenerate here,
        @test r.overlaps[k, sy] > 0.9      # so the block carries both
    end
    # NEGATIVE CONTROL for the labeller: the k≠0 branches must NOT be claimed by
    # any generator, or a 1.0 above would only mean "this code returns 1.0".
    for k in eachindex(r.omega)
        r.omega[k] < 1e-3 && continue
        @test r.labels[k] === :excitation
        @test maximum(@view r.overlaps[k, :]) < 0.5
    end
    # The uniform state's translation generator is identically zero (∂ψ = 0), so
    # its column is 0 for a reason that has nothing to do with orthogonality —
    # do not read it as a measurement.
end

# `spectrum_reached` — the flag that separates "the spectrum is gapless" from
# "the block never left the null manifold". Measured at F=6 polar in 3D: nev=6
# returned six ω < 1e-5 modes, every number honest and none of them an
# excitation. The F=1 polar box reproduces the same situation cheaply at nev=2,
# because its zero block is exactly the two broken transverse spin rotations and
# they sort first.
@testset "spectrum_reached distinguishes a null manifold from a gapless spectrum" begin
    fx = _uniform_box(ComplexF64[0, 1, 0])
    p = constrained_hessian_params(fx.ws, fx.ψ)

    only_zeros = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=2, max_iter=80,
        hess_tol=1e-9, params=p, rng=MersenneTwister(1))
    @test all(<(1e-3), only_zeros.omega)
    @test !only_zeros.spectrum_reached          # and it warns

    reached = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80,
        hess_tol=1e-9, params=p, rng=MersenneTwister(1))
    @test reached.spectrum_reached
    # POSITIVE CONTROL on the flag: it is not simply "nev > 2". The same box with
    # the same nev=2 must flip the flag once the zero modes are gone, so pin the
    # mechanism — the flag is false exactly when every returned ω is under the
    # zero tolerance, which the two runs above bracket.
    @test count(>(1e-3), reached.omega) >= 6
end

@testset "λ is NOT ω: ω = √(λ₋λ₊)/2, and the k-exponents differ" begin
    fx = _uniform_box(ComplexF64[0, 1, 0])
    lm = trapped_bdg_low_modes(fx.ws, fx.ψ; nev=12, block=18, max_iter=80,
        tol=1e-7, rng=MersenneTwister(2))
    n0 = 1.0
    ε1 = _εk(fx.dk)
    ε2 = _εk(2fx.dk)

    # The Hessian's own soft eigenvalue is 2εk in EVERY channel: it carries no
    # interaction at all, which is exactly why it is not a frequency.
    λ_soft(ε) = 2ε
    # The whole nev=12 block, accounted for exactly: 2 null (broken transverse
    # spin rotations), 6 soft at 2ε₁ (3 channels × ±k), 2 stiff spin partners at
    # k=0 (2·2c₁n), 2 stiff spin partners at |k|=dk. The remaining stiff
    # partners lie above this block.
    @test count(l -> abs(l) < 1e-6, lm.λ) == 2
    @test count(l -> isapprox(l, λ_soft(ε1); rtol=1e-6), lm.λ) == 6
    @test count(l -> isapprox(l, 2 * (2 * 0.2 * n0); rtol=1e-6), lm.λ) == 2
    @test count(l -> isapprox(l, 2 * (ε1 + 2 * 0.2 * n0); rtol=1e-6), lm.λ) == 2

    # THE IDENTITY. ω = √(λ₋λ₊)/2 — 0.4674 from λ₋=0.6169, λ₊=1.4169, not from
    # either of them.
    ω_spin = _branch(fx.dk, 0.2, n0)
    @test isapprox(sqrt(λ_soft(ε1) * 2 * (ε1 + 2 * 0.2 * n0)) / 2, ω_spin; rtol=1e-9)
    @test !isapprox(λ_soft(ε1), ω_spin; rtol=0.1)      # they are not the same number

    # THE EXPONENTS. Doubling k multiplies the Hessian's soft eigenvalue by
    # exactly 4 (it is 2εk ∝ k²) and the frequency by less than 2.5 (ω is
    # asymptotically linear). No tolerance can reconcile a quadratic with a
    # linear, which is why reading λ as a spectrum is a category error and not
    # an approximation.
    @test isapprox(λ_soft(ε2) / λ_soft(ε1), 4.0; rtol=1e-12)
    @test _branch(2fx.dk, 1.0, n0) / _branch(fx.dk, 1.0, n0) < 2.5
end

# Regression: the projector's null space (ψ, iψ) leaking back into the LOBPCG
# basis. `A = P(H−2μ)P` annihilates it exactly, so a leaked direction reports as
# a converged eigenvalue 0 — and `trapped_bdg_frequencies` would then have
# published it as a physical Goldstone. MGS amplifies the leak geometrically
# (‖W‖→0 ⇒ the normalising division multiplies it), so it appears only at the
# `nev`/`max_iter` an excitation spectrum needs: measured 4 zero modes where
# the F=1 polar box has 2, with residuals ~1e-10 on all four. The fix
# re-projects each normalised basis vector (`_mgs_ortho(...; refine=project)`).
@testset "no spurious null-space modes at large nev / max_iter" begin
    fx = _uniform_box(ComplexF64[0, 1, 0])
    p = constrained_hessian_params(fx.ws, fx.ψ)
    dV = p.dV
    lm = trapped_bdg_low_modes(fx.ws, fx.ψ; nev=6, block=12, max_iter=120,
        tol=1e-10, params=p, rng=MersenneTwister(1))
    # No returned Ritz vector may carry the ψ / iψ direction.
    for v in lm.vectors
        @test abs(sum(conj.(fx.ψ) .* v) * dV) < 1e-8
    end
    # The F=1 polar box has exactly 2 null directions of the constrained
    # Hessian (the two broken transverse spin rotations); before the fix this
    # counted 4.
    @test count(l -> abs(l) < 1e-6, lm.λ) == 2
end

# The DDI arm compares against the DENSE trapped BdG (`trapped_bdg_spectrum`)
# and NOT against `bogoliubov_spectrum`, for a measured reason recorded below.
# The two trapped paths are independent solvers over the same gated operator:
# dense LAPACK on an explicitly assembled 2NP×2NP non-Hermitian matrix vs a
# matrix-free symplectic reduction on a Krylov subspace. Agreement between them
# pins the reduction; it does not re-pin the operator, which the FD-Hessian gate
# owns.
@testset "reduction ω ≡ dense trapped BdG (contact and DDI)" begin
    for c_dd in (0.0, 0.05)
        fx = _uniform_box(ComplexF64[0, 1, 0]; c_dd=c_dd)
        p = constrained_hessian_params(fx.ws, fx.ψ)
        dense = trapped_bdg_spectrum(fx.ws, fx.ψ; μ=p.μ, dim_cap=10_000)
        @test dense.dense_ok
        dpos = sort(unique(round.(filter(>(1e-6), real.(dense.omega)); digits=8)))
        r = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80, hess_tol=1e-9,
            params=p, rng=MersenneTwister(1))
        for k in findall(<(1e-6), r.residuals)
            r.omega[k] < 1e-3 && continue
            @test minimum(abs(r.omega[k] - w) for w in dpos) < 1e-5
        end
    end
end

@testset "DDI moves the spin branch (anomalous block is live)" begin
    # A polar state has ⟨F⟩ = 0, so the DDI mean-field term vanishes and ONLY
    # the anomalous block can move the spectrum. Without this arm the DDI test
    # above would pass with the DDI silently switched off.
    r0 = let fx = _uniform_box(ComplexF64[0, 1, 0])
        trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80, hess_tol=1e-9,
            rng=MersenneTwister(1))
    end
    fx = _uniform_box(ComplexF64[0, 1, 0]; c_dd=0.05)
    r1 = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80, hess_tol=1e-9,
        rng=MersenneTwister(1))
    # The degenerate spin quartet SPLITS. Stated as "every c_dd=0 value has
    # moved", not "some pair of values differs" — the latter is satisfied by the
    # untouched density branch appearing in both lists and would pass with DDI
    # off. (That is how this control was written first, and it passed while the
    # reference spectrum was in fact bit-identical.)
    for w in r0.omega
        w < 1e-3 && continue
        w ≈ _branch(fx.dk, 1.0, 1.0) && continue     # density branch: untouched
        @test minimum(abs(w - v) for v in r1.omega) > 1e-3
    end
end

# DDI uniform-limit containment against `bogoliubov_spectrum` — and the story of
# this testset is the argument for the mechanism, so it stays written down.
#
# It shipped as `@test_broken` on 2026-08-19. The trapped spin quartet split to
# 0.456306 / 0.488935 at c_dd = 0.05 while the homogeneous path gave
# 0.451721 / 0.474220 — a 3 % disagreement — and the two TRAPPED paths (dense
# `trapped_bdg_spectrum` + this reduction, independent solvers) agreed with each
# other to 3.7e-7, so the odd one out was `bogoliubov_spectrum`, whose DDI blocks
# no test anchored (`test_bogoliubov_anchor.jl` states that KNOWN-LIMIT itself:
# contact only). Filed as #361 with the derivation — the second variation of
# `E_DDI = (c_dd/2)∫∫Q(M,M)` has a normal block of TWO terms and
# `_bdg_ddi_matrices` carried only the Hartree one, which is exactly ZERO for a
# polar state.
#
# Hours later `7e6770c2` (#367) landed that fix and this line reported
# **Unexpected Pass**. That is the whole point of `@test_broken` over a
# commented-out assertion or a pinned wrong number: the gate told the next person
# the day the premise changed, without anyone remembering to come back. It is now
# a live assertion at the same tolerance the contact arm uses.
@testset "trapped ω ≡ homogeneous BdG WITH DDI (was #361, fixed in 7e6770c2)" begin
    fx = _uniform_box(ComplexF64[0, 1, 0]; c_dd=0.05)
    r = trapped_bdg_frequencies(fx.ws, fx.ψ; nev=8, max_iter=80, hess_tol=1e-9,
        rng=MersenneTwister(1))
    ref = _homogeneous_omegas(ComplexF64[0, 1, 0], 1, fx.ip; n0=1.0, dk=fx.dk,
        c_dd=0.05, k_direction=(1.0, 0.0, 0.0))
    spin = [w for w in r.omega if 1e-3 < w < 0.7]
    @test !isempty(spin)
    @test maximum(w -> minimum(abs(w - v) for v in ref), spin) < 1e-5
end
