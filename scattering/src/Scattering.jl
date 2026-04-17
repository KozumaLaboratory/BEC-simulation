"""
    Scattering

Coupled-channel scattering calculations for spinor BECs.

Phase 1 scope: single- and two-atom basis infrastructure, hyperfine +
Zeeman Hamiltonians, channel enumeration with identical-boson symmetrization.
Radial propagation and S-matrix extraction are Phase 2.

All internal quantities are in Hartree atomic units (a_0, E_h, m_e).
Half-integer angular momenta are represented by their 2j values
(e.g. J = 7/2 → 2J = 7).
"""
module Scattering

using LinearAlgebra

include("units.jl")
include("wigner.jl")
include("atom.jl")
include("single_atom.jl")
include("basis_transform.jl")
include("two_atom_basis.jl")
include("channels.jl")
include("potentials.jl")
include("two_atom_transform.jl")
include("coupling_matrix.jl")
include("ddi.jl")
include("mw_floquet.jl")
include("propagator.jl")
include("eueu_stretched.jl")
include("pole_finder.jl")

export
    # units
    AtomicUnits, hz_to_au, mhz_to_au, tesla_to_au, amu_to_au, bohr_to_m,
    cm1_to_au, au_to_cm1,
    # wigner
    wigner_3j_2j, wigner_6j_2j, wigner_9j_2j, clebsch_gordan_2j,
    # atom
    AtomParams, Eu151,
    # single atom
    SingleAtomBasis, build_single_atom_basis, hfs_hamiltonian,
    zeeman_hamiltonian, single_atom_hamiltonian,
    Jplus_matrix, Iplus_matrix, Jz_matrix, Iz_matrix,
    basis_transform_F_to_JI,
    # microwave Floquet
    MWTone, MWField,
    mw_sigma_plus, mw_sigma_minus, mw_pi,
    floquet_hamiltonian, floquet_basis_labels,
    FloquetBasisLabel, DressedState,
    floquet_dressed_states, dressed_energies,
    # channels
    ScatteringChannel, enumerate_channels, threshold_energy,
    # two-atom basis
    TwoAtomHyperfineState, TwoAtomMolecularState,
    # two-atom transform
    TwoAtomHyperfineProduct, TwoAtomMolecularProduct,
    build_two_atom_hyperfine_basis, build_two_atom_molecular_basis,
    hyperfine_to_molecular_transform,
    # potentials
    EuEuPotentialParams, EuEuExchangeParams,
    eueu_septet_params, eueu_exchange_params,
    V_septet, J_exchange, V_spin,
    # coupling matrix
    spin_projector_matrices, coupling_matrix,
    channel_thresholds, centrifugal_vector,
    # DDI
    ddi_prefactor, ddi_angular_matrix, ddi_matrix,
    # propagator
    numerov, scattering_length_from_u, zero_energy_scattering_length,
    square_well_scattering_length,
    numerov_multichannel, make_channel_M,
    kmatrix_swave, smatrix_from_kmatrix,
    # Eu+Eu stretched
    eueu_stretched_swave_length, scan_eueu_septet_rescale,
    # pole finder
    PoleBracket, bracket_poles, bisect_pole, find_poles,
    reduced_mass

end # module
