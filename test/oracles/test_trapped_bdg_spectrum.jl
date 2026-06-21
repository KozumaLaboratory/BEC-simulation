# Trapped BdG ≡ homogeneous BdG in the uniform limit — the dynamical-axis
# operator anchor.
#
# `trapped_bdg_spectrum` builds the non-Hermitian σ_z[L M; M* L*] operator
# matrix-free from the gated `hessian_vector_product` (L_op = δ²E/δψ̄δψ,
# M_op = δ²E/δψ̄δψ̄). On a UNIFORM condensate in a no-trap periodic box it is
# translation-invariant, so its eigenmodes are plane waves and the spectrum
# is the union over box k-modes of the homogeneous 2D×2D BdG eigenvalues.
# The homogeneous side (`_bdg_contact_matrices`, CG-sum matrices) is itself
# anchored by test_bogoliubov_anchor → analytic F=1 dispersion, so a match
# here transitively pins the trapped operator's sign convention, the
# L_op/M_op v/iv extraction, the −μ shift, and the σ_z structure. Two
# independent constructions of the SAME BdG must agree to FD precision.

using Test
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _bdg_contact_matrices, trapped_bdg_spectrum, energy_gradient!,
    cell_volume

@testset "trapped BdG ≡ homogeneous BdG (uniform limit) + quartet symmetry" begin
    F = 1
    D = 3
    n = 12
    L = 8.0
    interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.2))
    zeeman = ZeemanParams(0.0, 0.3)
    # Generic off-axis spinor exercises the anomalous block M_op fully
    # (a single-|m⟩ state would zero most of it).
    spinor = ComplexF64[0.3, 0.9, 0.2]
    spinor ./= sqrt(sum(abs2, spinor))

    grid = make_grid(GridConfig((n,), (L,)))
    ws = make_workspace(;
        grid, atom=Rb87, interactions, zeeman, potential=NoPotential(),
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
    )
    ψ = zeros(ComplexF64, n, D)
    for i in 1:n, c in 1:D
        ψ[i, c] = spinor[c]
    end

    dV = cell_volume(grid)
    n2 = real(sum(abs2, ψ)) * dV
    g = similar(ψ)
    fill!(g, 0)
    energy_gradient!(g, ψ, ws)
    μ = real(sum(conj.(ψ) .* g)) * dV / (2 * n2)
    n0 = sum(abs2, @view ψ[1, :])              # uniform per-voxel density

    tr = trapped_bdg_spectrum(ws, ψ; μ, dim_cap=10_000)
    @test tr.dense_ok
    @test tr.dim == 2 * length(ψ)
    @test tr.quartet_residual < 1e-10          # ω↦−conj(ω) to machine precision

    # Homogeneous reference at the box's discrete k-modes — SAME μ so the
    # comparison isolates the operator structure from the μ definition.
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)
    ref = ComplexF64[]
    for kval in grid.k[1]
        ek = kval^2 / 2
        Lblk = 2n0 .* h_mf
        for i in 1:D
            Lblk[i, i] += ek - μ + zee[i]
        end
        Msc = n0 .* M_anom
        Hb = zeros(ComplexF64, 2D, 2D)
        Hb[1:D, 1:D] .= Lblk
        Hb[1:D, (D + 1):2D] .= Msc
        Hb[(D + 1):2D, 1:D] .= .-conj.(Msc)
        Hb[(D + 1):2D, (D + 1):2D] .= .-conj.(Lblk)
        append!(ref, eigvals(Hb))
    end

    # Containment: every trapped eigenvalue lies on the homogeneous set.
    maxerr = maximum(ω -> minimum(abs(ω - r) for r in ref), tr.omega)
    @test maxerr < 1e-6                        # FD ε=1e-5 truncation floor
end
