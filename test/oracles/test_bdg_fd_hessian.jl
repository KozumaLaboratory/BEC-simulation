# BdG ≡ FD-Hessian of the gated gradient — the matrix-level anchor.
#
# `test_bogoliubov_anchor.jl` pins the BdG SPECTRUM to the F=1 analytic
# dispersion (declaration-independent physics). This file pins the BdG
# OPERATOR — both blocks of σ_z[L M; M* L*] — to the finite-difference
# Hessian of the ALREADY-GATED gradient (`energy_gradient!`, master
# oracle), F-swept up to Eu F=6. It is the chains-off-the-gated-gradient
# counterpart: the hand-built CG-sum BdG matrices (`_bdg_normal_matrix`,
# `_bdg_anomalous_matrix`) and the FD of the gradient are two
# independent statements of the SAME second variation.
#
# Why this is load-bearing: every saddle-vs-minimum (gate-2) verdict on
# the M1 sweep rides on these matrices, and the conditioning-floor /
# PCV-onset marginal stability lives in the ANOMALOUS block M — which a
# spectrum-only or normal-block-only anchor would miss. The Hessian-
# vector product naturally carries both blocks: with g = 2·δE/δψ̄,
#   D_v g = 2(L_op v + M_op v̄),  D_{iv} g = 2i(L_op v − M_op v̄)
# so L_op[:,c] = (D_{e_c}g − i·D_{i e_c}g)/4 and M_op[:,c] = (… + …)/4
# extract both blocks (point: the soft mode is anomalous, so this
# v/iv sign convention is the Hessian analogue of the Wirtinger
# gradient convention). Measured equalities (n0=1, zee=0):
#   L_op = 2·h_mf      (= the BdG L-block mean-field part, 2n₀·h_mf)
#   M_op = M_anom      (= the BdG M-block, n₀·M_anom)
#
# CONTACT, k=0: DDI's Q(k)=0 at k=0, so this anchors the contact BdG at
# every F; the DDI k-structure is a finite-k follow-on. The HvP (not a
# dense Hessian) reuses the central-difference machinery; ε=1e-5.

using Test
using LinearAlgebra
using Random
using SpinorBEC
using SpinorBEC:
    energy_gradient!, precompute_cg_table, c_to_g,
    _bdg_normal_matrix, _bdg_anomalous_matrix

# Extract (L_op, M_op) = (δ²E/δψ̄δψ, δ²E/δψ̄δψ̄) at k=0 from the FD of the
# gated gradient on a uniform condensate ζ (|ζ|=1 ⇒ n0=1 per voxel).
function _fd_hessian_blocks(F, ζ; c0, c1, ε=1e-5, n=4)
    D = 2F + 1
    grid = make_grid(GridConfig{3}((n, n, n), (4.0, 4.0, 4.0)))
    ws = make_workspace(;
        grid, atom=(
            if F == 1
                Rb87
            elseif F == 2
                Rb85
            elseif F == 3
                Cr52
            else
                Eu151
            end
        ),
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap(ntuple(_ -> 0.0, 3)),
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
    )
    ψ0 = zeros(ComplexF64, n, n, n, D)
    for I in CartesianIndices((n, n, n)), c in 1:D
        ψ0[I, c] = ζ[c]
    end
    # directional HvP via the SINGLE-SOURCE src operator — this anchor
    # now gates `hessian_vector_product` itself, not a local copy.
    function Dg(vc)
        v = zeros(ComplexF64, n, n, n, D)
        for I in CartesianIndices((n, n, n)), c in 1:D
            v[I, c] = vc[c]
        end
        dg = SpinorBEC.hessian_vector_product(ws, ψ0, v; ε)
        ComplexF64[dg[1, 1, 1, c] for c in 1:D]   # uniform ⇒ any voxel
    end
    Lop = zeros(ComplexF64, D, D)
    Mop = zeros(ComplexF64, D, D)
    for c in 1:D
        ec = zeros(ComplexF64, D)
        ec[c] = 1
        De = Dg(ec)
        Die = Dg(im .* ec)
        Lop[:, c] = (De .- im .* Die) ./ 4
        Mop[:, c] = (De .+ im .* Die) ./ 4
    end
    Lop, Mop
end

@testset "BdG ≡ FD-Hessian of the gated gradient (both blocks, F-swept)" begin
    c0, c1 = 1.0, 0.2
    fixtures = [
        (1, ComplexF64[0, 1, 0], "F=1 polar"),
        (1, ComplexF64[1, 0, 0], "F=1 FM"),
        (2, (z=zeros(ComplexF64, 5); z[3]=1; z), "F=2 polar"),
        (3, (z=zeros(ComplexF64, 7); z[4]=1; z), "F=3 polar"),
        (6, (z=zeros(ComplexF64, 13); z[7]=1; z), "F=6 polar (Eu)"),
    ]
    for (F, ζ, label) in fixtures
        @testset "$label" begin
            D = 2F + 1
            Lop, Mop = _fd_hessian_blocks(F, ζ; c0, c1)
            cg = precompute_cg_table(F)
            gd = c_to_g(F, InteractionParams(Dict(0 => c0, 1 => c1)))
            hmf = _bdg_normal_matrix(ζ, F, D, gd, cg)
            Manom = _bdg_anomalous_matrix(ζ, F, D, gd, cg)
            # FD-Hessian normal block = 2·h_mf (the BdG L mean-field part)
            @test isapprox(Lop, 2 .* hmf; atol=1e-5, rtol=1e-5)
            # FD-Hessian anomalous block = M_anom (the BdG M block)
            @test isapprox(Mop, Manom; atol=1e-5, rtol=1e-5)
            # both blocks must be non-trivial (the anchor is not vacuous)
            @test norm(hmf) > 1e-3
            @test norm(Manom) > 1e-3
        end
    end
end

# The FD Hessian action must be HOMOGENEOUS: H·(cδ) = c·(H·δ). This needs no
# reference solution and no tolerance to fit — it is a property of any linear
# operator, and a finite-difference realisation only has it if the step is taken
# along the NORMALISED direction.
#
# It did not hold until 2026-07-29. `hessian_vector_product` differenced at
# `ψ ± ε·δ` with ε absolute, so shrinking δ shrank the perturbation instead of
# the answer, and the quotient drowned in round-off. Measured deviation of
# H·(cδ)/c from H·δ, before → after:
#
#   c=1e-2   5.9e-9  → 1.3e-16
#   c=1e-4   5.6e-7  → 1.3e-16
#   c=1e-6   6.8e-5  → 2.6e-16
#   c=1e-8   4.6e-3  → 1.2e-16
#
# The consumer that suffered is Newton-CG, which passes CG iterates whose norm
# spans decades (‖δ‖ ~ 1e-6 after an L-BFGS stage); the Lanczos consumer passes
# unit vectors and never saw it. The visible symptom was a non-deterministic
# `newton_polish`.
@testset "FD Hessian action is homogeneous in δ" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.4)),
        zeeman=ZeemanParams(0.3, 0.1), potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true))
    Random.seed!(11)
    psi = randn(ComplexF64, 8, 8, 8, 3)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    d = randn(ComplexF64, 8, 8, 8, 3)
    d ./= sqrt(sum(abs2, d))

    H1 = hessian_vector_product(ws, psi, d)
    @test norm(H1) > 1e-6                     # the operator is live
    for c in (1e-2, 1e-4, 1e-6, 1e-8)
        Hc = hessian_vector_product(ws, psi, c .* d) ./ c
        # The bound is DERIVED from the finite-difference amplification, not from
        # a measurement: the gradient carries ~1e-16 relative round-off and the
        # quotient divides by 2ε = 2e-5, so ~5e-12 is the floor this construction
        # can have. Measured, constant in c:
        #
        #   1.3e-16   plain build
        #   4.7e-11   `--check-bounds=yes`, which is what `Pkg.test()` uses —
        #             disabling @inbounds changes the summation order inside
        #             energy_gradient!, and 1/2ε amplifies the last-bit difference
        #
        # 1e-9 sits two decades above the worse of those and six decades below the
        # pre-fix deviation (4.6e-3 at c=1e-8), so it separates "homogeneous" from
        # "the step does not scale" without pinning either number. A tighter bound
        # here would be a test that passes standalone and fails under Pkg.test —
        # which is exactly what 1e-12 did.
        @test maximum(abs, Hc .- H1) / maximum(abs, H1) < 1e-9
    end
end

# ALIASING — the same defect class as the homogeneity bug above (the step is not
# the step the caller thinks it is), and silent in the same way.
#
# `energy_gradient!` opens with `copyto!(ws.state.psi, psi)`. So when the caller
# passes `ws.state.psi` ITSELF, the first of the two gradient evaluations moves
# that array to `ψ+εd`; the second is then taken at `(ψ+εd)−εd = ψ`, the
# difference spans `ε` rather than `2ε`, and the operator comes back at EXACTLY
# half. Half an operator is NOT a scaled operator: the `−2μ` shift in
# `constrained_hessian_action` no longer cancels, so `(H−2μ)` sends every
# broken-symmetry direction `g` (which satisfies `Hg = 2μg`) to `−μg` instead of
# to zero — the Goldstone modes stop existing.
#
# Measured 2026-08-26 on ¹⁵¹Eu's F=1 sibling, two TSUBAME jobs one `copy` apart
# (8496696 aliased vs 8496708 not), same states and the same solver output:
#
#   ‖(H−2μ)(iψ)‖/2μ    0.500          vs 1.1e-09
#   trapped F=1 polar  0 zero modes   vs 2   (the count this file's sibling
#   trapped F=1 FM     0              vs 1    oracle already asserts)
#
# Nothing threw and nothing warned; `hessian_converged` going false was the only
# hint, and it is the kind of hint a soft manifold produces anyway. Hence a
# refusal at the primitive rather than a note in a docstring — every face
# (`constrained_hessian_action`, the LOBPCG block, `trapped_bdg_frequencies`,
# Newton-CG) reaches the operator through this one function.
@testset "Hessian refuses a ψ that aliases ws.state.psi" begin
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    ws = make_workspace(; grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.4)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true))
    Random.seed!(12)
    ψ0 = randn(ComplexF64, 8, 8, 8, 3)
    ψ0 ./= sqrt(sum(abs2, ψ0) * cell_volume(grid))
    copyto!(ws.state.psi, ψ0)
    d = randn(ComplexF64, 8, 8, 8, 3)
    d ./= sqrt(sum(abs2, d))

    @test_throws ArgumentError hessian_vector_product(ws, ws.state.psi, d)
    # The refusal must not be reachable the other way round: a copy is the
    # supported call and has to keep working, or the guard would just be a
    # tripwire on the whole instrument.
    ψ = copy(ws.state.psi)
    @test norm(hessian_vector_product(ws, ψ, d)) > 1e-6
    # And the guard is at the primitive, so the faces inherit it — checked on
    # the one every BdG consumer goes through rather than assumed.
    p = constrained_hessian_params(ws, ψ)
    @test_throws ArgumentError constrained_hessian_action(
        ws, ws.state.psi, d; p.μ, p.dV, p.n2)
end
