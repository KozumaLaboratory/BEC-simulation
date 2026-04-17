using Test
using Scattering

@testset "Scattering.jl Phase 1" begin
    include("test_wigner.jl")
    include("test_units.jl")
    include("test_atom.jl")
    include("test_basis.jl")
    include("test_breit_rabi.jl")
    include("test_channels.jl")
    include("test_potentials.jl")
    include("test_two_atom_transform.jl")
    include("test_coupling_matrix.jl")
    include("test_ddi.jl")
    include("test_mw_floquet.jl")
    include("test_pole_finder.jl")
    include("test_propagator.jl")
    include("test_multichannel.jl")
    include("test_eueu_stretched.jl")
end
