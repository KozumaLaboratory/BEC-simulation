module SpinorBECVTKExt

# WriteVTK is now an opt-in weak dep. The two ParaView-export entry
# points (`export_vtk`, `export_vtk_series`) are declared as empty
# generic functions in src/workflow/io/vtk_export.jl; this extension
# supplies their methods. Users who don't `using WriteVTK` never pay
# the load cost.

using SpinorBEC
using SpinorBEC: Workspace, Grid, AtomSpecies, SimulationResult,
    make_fft_plans, spin_matrices, total_density, probability_current,
    spin_density_vector, superfluid_velocity, superfluid_vorticity,
    component_density
using FFTW: ESTIMATE
using WriteVTK

include("vtk_export.jl")

end # module
