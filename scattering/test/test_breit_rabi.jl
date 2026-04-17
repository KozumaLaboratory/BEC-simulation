using Test
using Scattering
using LinearAlgebra

# Analytical Landé g_F for |F, m_F⟩ (sign convention:
# H_Z = g_J μ_B B J_z − g_I μ_N B I_z, g_I > 0 for μ_I ∥ I).
function g_F_theory(atom, tF::Int)
    tJ = atom.two_J; tI = atom.two_I
    F2 = tF * (tF + 2) / 4
    J2 = tJ * (tJ + 2) / 4
    I2 = tI * (tI + 2) / 4
    atom.g_J * (F2 + J2 - I2) / (2 * F2) -
        atom.g_I * (Scattering._muN_JT / Scattering._muB_JT) * (F2 - J2 + I2) / (2 * F2)
end

@testset "Low-field (Zeeman) limit: linear g_F·μ_B·B·m_F" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)

    # Small field: 1 mG (well below HFS mixing scale for Eu: A ~ 20 MHz,
    # μ_B B ~ 1.4 × 10⁻³ MHz at 1 mG)
    B = 1e-7          # Tesla
    H = single_atom_hamiltonian(basis, B)
    evs = eigen(Hermitian(H))

    # For each F, extract the 2F+1 lowest-eigenvector components and
    # verify the slope vs m_F matches g_F μ_B B.
    # Strategy: diagonalize at two small fields and check that the
    # per-state slope matches g_F μ_B m_F for the corresponding |F, m⟩.
    B1 = 1e-7; B2 = 2e-7
    H1 = single_atom_hamiltonian(basis, B1)
    H2 = single_atom_hamiltonian(basis, B2)

    E1 = sort(eigen(Hermitian(H1)).values)
    E2 = sort(eigen(Hermitian(H2)).values)
    slopes = (E2 .- E1) ./ (B2 - B1)        # dE/dB at zero field

    # Expected slopes: g_F μ_B m_F for each (F, m_F), sorted by E(F, m_F)≈ E_hfs(F)
    expected = Float64[]
    for F in 1:6
        tF = 2F
        E_hfs_F = Scattering.hfs_energy(atom, tF)
        gF = g_F_theory(atom, tF)
        for mF in -F:F
            # dE/dB = g_F · μ_B[J/T] · m_F (in E_h / T units)
            dEdB = gF * Scattering._muB_JT * mF / Scattering._Eh_J
            push!(expected, dEdB)
        end
    end
    # Sort expected alongside E_hfs for ordering. Multiple m_F at fixed F
    # are degenerate at B=0 but ordering of the degenerate manifold after
    # linearization should be by increasing dE/dB.
    # Sort both by corresponding energies at the slightly larger field.
    order_theory = sortperm([Scattering.hfs_energy(atom, 2F) +
                              g_F_theory(atom, 2F) * Scattering._muB_JT * mF /
                              Scattering._Eh_J * B2
                              for F in 1:6 for mF in -F:F])
    expected_sorted = expected[order_theory]

    @test slopes ≈ expected_sorted rtol = 1e-4
end

@testset "High-field (Paschen-Back) limit" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)

    # Strong field: 100 T — far above HFS (~20 MHz = 1.5 mT equivalent) so
    # m_J, m_I are good. Eigenvalues should equal
    #   E = A · m_J · m_I + g_J μ_B B m_J − g_I μ_N B m_I
    # for all 48 (m_J, m_I) pairs.
    B = 100.0
    H = single_atom_hamiltonian(basis, B)
    numerical = sort(eigen(Hermitian(H)).values)

    E_muB_B = Scattering._muB_JT * B / Scattering._Eh_J
    E_muN_B = Scattering._muN_JT * B / Scattering._Eh_J

    theoretical = Float64[]
    for tmJ in -atom.two_J:2:atom.two_J
        mJ = tmJ / 2
        for tmI in -atom.two_I:2:atom.two_I
            mI = tmI / 2
            # Pure A I·J with B_hfs = 0 term: A m_J m_I is the diagonal
            # (off-diagonal I·J raises/lowers broken at high B).
            # We keep full HFS here by using the actual A, B_hfs constants;
            # the diagonal-in-(m_J, m_I) approximation is first-order and
            # should hold at rtol ~ A/(μ_B B) ~ 10⁻⁵ for B = 100 T.
            E = atom.A_hfs * mJ * mI +
                atom.g_J * E_muB_B * mJ - atom.g_I * E_muN_B * mI
            push!(theoretical, E)
        end
    end
    sort!(theoretical)
    @test numerical ≈ theoretical rtol = 1e-4
end

@testset "Zero field: H = H_hfs" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    H0 = single_atom_hamiltonian(basis, 0.0)
    Hhfs = Matrix(hfs_hamiltonian(basis))
    @test H0 ≈ Hhfs atol = 1e-18
end
