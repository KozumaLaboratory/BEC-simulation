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
        grid, atom=(if F == 1
            Rb87
        elseif F == 2
            Rb85
        elseif F == 3
            Cr52
        else
            Eu151
        end),
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap(ntuple(_ -> 0.0, 3)),
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
    )
    ψ0 = zeros(ComplexF64, n, n, n, D)
    for I in CartesianIndices((n, n, n)), c in 1:D
        ψ0[I, c] = ζ[c]
    end
    g(ψ) = (gr=similar(ψ); fill!(gr, 0); energy_gradient!(gr, ψ, ws); gr)
    function Dg(vc)
        v = zeros(ComplexF64, n, n, n, D)
        for I in CartesianIndices((n, n, n)), c in 1:D
            v[I, c] = vc[c]
        end
        dg = (g(ψ0 .+ ε .* v) .- g(ψ0 .- ε .* v)) ./ (2ε)
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
