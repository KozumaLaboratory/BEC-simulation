# test/oracles/test_negative_dt_substeps.jl
#
# Every propagator substep must respond to dt < 0.
#
# The Yoshida / Suzuki / Blanes-Moan composers run their middle substep
# BACKWARD in time (`_YOSHIDA_W0 < 0` — CLAUDE.md lists this under "conventions,
# do NOT fix"). A substep that silently no-ops for dt < 0 therefore drops that
# operator from every high-order composition while leaving all fixed-dt,
# positive-dt tests green. The only thing that sees it is an order test, and the
# order tests here live in FULL_EXTRA, which the PR gate does not run.
#
# That is not hypothetical. Between #183 and 03dc152c, `apply_spin_mixing_step!`
# guarded its early exit on `maximum(theta)` where `theta[k] = c₁|⟨F⟩ₖ|·dt`. For
# dt < 0 every entry is ≤ 0, so `maximum` returned the entry CLOSEST TO ZERO — a
# vacuum voxel, exactly 0 — and the guard fired on every backward substep,
# dropping spin mixing from the composition. Yoshida-4 measured order 1.96
# instead of 4, with the c_dd = 0 control failing identically.
#
# It was removed by 03dc152c, a Taylor-Horner performance rewrite that replaced
# the whole reduction with `abs(c1·dt)·max|⟨F⟩|·F`. That commit's message does
# not mention dt < 0 or the order collapse, because nobody knew: the defect was
# fixed incidentally, and nothing pinned the claim. So this file is not a
# regression test for a live bug — it is the gate that was missing, and the next
# rewrite of that guard is what it is for.
#
# The claim these tests defend, stated once: a propagator substep is a function
# of dt that is not identically the identity on a half-line. It is a metamorphic
# relation — no reference solution, no tolerance to fit, microseconds to run.

using Test
using FFTW
using Random
using LinearAlgebra
using SpinorBEC
using SpinorBEC:
    HamTerm, LossTerm, apply_step!, build_h_terms_registry,
    apply_spin_mixing_step!, spin_matrices

const _NDIM = 3
const _N = (8, 8, 8)

# F = 2, NOT F = 1. `_spin_mixing_loop!` dispatches D == 3 to a per-voxel
# Rodrigues kernel and everything else to the gemm-batched Euler path, and it is
# the batched path — the one every production run at Eu F = 6 takes — that holds
# the reduction being defended. An F = 1 fixture passes against the known-bad
# code (canaried); D = 5 is the cheapest D that exercises the real path.
const _F = 2
const _D = 2 * _F + 1
const _ATOM = AtomSpecies("test_F$(_F)", 1.0, _F, 0.0, 0.0, 0.0, 0.0)
const _C1 = -0.5

function _reversibility_workspace()
    grid = make_grid(GridConfig(_N, (4.0, 4.0, 4.0)))
    # Every term that has a coefficient gets a NON-ZERO one: an inactive term
    # legitimately no-ops for both signs and would make the gate vacuous.
    interactions = InteractionParams(Dict(0 => 30.0, 1 => _C1))
    zeeman = ZeemanParams(0.3, 0.15)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false)
    make_workspace(;
        grid, atom=_ATOM, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.1, 0.9)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
end

"""
Random spinor under a Gaussian envelope — a TRAPPED cloud, with genuine vacuum
in the box corners.

The envelope and the emptied corner are load-bearing, not decoration.

The guard being defended reduces the per-voxel angle θₖ = c₁|⟨F⟩ₖ|·dt and exits
when the result is below 1e-14. A flat random spinor holds every θₖ far from
zero, so the reduction can be wrong and nothing moves — canaried: with a flat
random state this file passes against the known-bad code. A Gaussian tail alone
is not enough either, because 1e-14 is a hard floor and an 8-point box does not
reach it. What does reach it is what every trapped cloud actually has: voxels
where the condensate is gone. One emptied corner voxel makes min θₖ exactly
zero, which is the regime the guard is written for.
"""
function _seeded_state(ws; seed::Int=20260729)
    rng = MersenneTwister(seed)
    D = ws.spin_matrices.system.n_components
    psi = randn(rng, ComplexF64, _N..., D)
    x = ws.grid.x
    for I in CartesianIndices(_N)
        r2 = sum(x[d][I[d]]^2 for d in 1:_NDIM)
        @views psi[I, :] .*= exp(-r2)
    end
    @views psi[1, 1, 1, :] .= 0            # vacuum voxel: min θ ≡ 0
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    psi
end

"""Displacement a substep produces at ±dt, as a fraction of ‖ψ‖."""
function _displacements(term::HamTerm, ws, psi0, dt::Float64)
    scale = norm(psi0)
    fwd = copy(psi0)
    apply_step!(term, fwd, dt, false, ws)
    bwd = copy(psi0)
    apply_step!(term, bwd, -dt, false, ws)
    (norm(fwd .- psi0) / scale, norm(bwd .- psi0) / scale)
end

@testset "negative-dt substeps" begin
    ws = _reversibility_workspace()
    psi0 = _seeded_state(ws)
    dt = 0.01

    @testset "no substep is a no-op only for dt < 0" begin
        registry = build_h_terms_registry(ws)
        active = 0
        for term in registry
            # Loss is non-unitary BY DESIGN and its dt < 0 branch is not part of
            # any composer; excluded rather than given a special tolerance.
            term isa LossTerm && continue
            d_fwd, d_bwd = _displacements(term, ws, psi0, dt)
            # Inactive terms move the state for neither sign — nothing to claim.
            d_fwd > 1e-12 || continue
            active += 1
            @test d_bwd > 1e-12
            # A substep is O(dt) in dt near zero, so the two displacements must
            # agree to within the O(dt²) curvature. A factor-2 window is far
            # looser than any real asymmetry and far tighter than a dropped
            # operator (which lands at exactly 0).
            @test 0.5 < d_bwd / d_fwd < 2.0
        end
        # If a refactor makes every term inactive in this fixture the loop above
        # asserts nothing; that must be a failure, not a green run.
        @test active >= 4
    end

    # BOTH signs of c₁. The guard being defended compares a signed product
    # against a floor, so whether a missing `abs` shows up depends on
    # sign(c₁)·sign(dt): a single-sign fixture leaves half the defect invisible.
    # (The 2026-07-29 form of the guard reduced over per-voxel θ; the form that
    # replaced it bounds `abs(c1·dt)·max|⟨F⟩|·F`. Same claim, different arithmetic
    # — which is exactly why the claim, not the arithmetic, is what is tested.)
    @testset "spin mixing is exactly reversible at frozen mean field (c1=$c1)" for c1 in (_C1, -_C1)

        # With `psi_mf` pinned to the ORIGINAL state the rotation operator is the
        # same for both calls, so U(-dt)·U(+dt) is the identity to round-off.
        # This is the sharpest form of the claim and the cheapest to run.
        sm = spin_matrices(_F)
        psi = _seeded_state(ws)
        psi_mf = copy(psi)

        fwd = copy(psi)
        apply_spin_mixing_step!(fwd, sm, c1, dt, _NDIM; psi_mf=psi_mf)
        @test norm(fwd .- psi) / norm(psi) > 1e-10   # the operator is live

        back = copy(fwd)
        apply_spin_mixing_step!(back, sm, c1, -dt, _NDIM; psi_mf=psi_mf)
        @test norm(back .- psi) / norm(psi) < 1e-12
    end

    @testset "spin mixing responds symmetrically to the sign of dt (c1=$c1)" for c1 in (_C1, -_C1)

        # The form the defect took: the backward call returned the input
        # unchanged. Stated without reference to reversibility so it still holds
        # when the mean field is read from the state being rotated.
        sm = spin_matrices(_F)
        psi = _seeded_state(ws)

        fwd = copy(psi)
        apply_spin_mixing_step!(fwd, sm, c1, dt, _NDIM)
        bwd = copy(psi)
        apply_spin_mixing_step!(bwd, sm, c1, -dt, _NDIM)

        d_fwd = norm(fwd .- psi)
        d_bwd = norm(bwd .- psi)
        @test d_fwd > 1e-12
        @test d_bwd > 1e-12
        @test isapprox(d_bwd, d_fwd; rtol=0.05)
    end
end
