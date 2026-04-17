using Test
using Scattering
using LinearAlgebra

@testset "F ↔ (m_J, m_I) basis transformation" begin
    atom = Eu151()
    basis = build_single_atom_basis(atom)
    U = basis_transform_F_to_JI(basis)
    n = length(basis)

    # Unitarity
    @test U' * U ≈ I(n) atol = 1e-12
    @test U * U' ≈ I(n) atol = 1e-12

    # Transforming H_hfs to uncoupled basis and back must preserve energies
    Hhfs_F = Matrix(hfs_hamiltonian(basis))          # diagonal in F
    Hhfs_JI = U' * Hhfs_F * U                          # uncoupled: generally dense
    Hhfs_back = U * Hhfs_JI * U'
    @test Hhfs_back ≈ Hhfs_F atol = 1e-12

    # In the uncoupled basis, H_hfs = A I·J (+ quadrupole). For a pure
    # magnetic-dipole HFS (B_hfs = 0), eigenvalues in uncoupled basis still
    # equal those in F basis (same operator, different representation).
    ev_F = sort(diag(Hhfs_F))
    ev_JI = sort(real.(eigen(Hermitian(Hhfs_JI)).values))
    @test ev_F ≈ ev_JI atol = 1e-10
end
