# `WriteVTK` is a weak dep loaded via ext/SpinorBECVTKExt. Real method
# bodies live there; here we only declare the public entry points so
# `export` and method-resolution succeed without WriteVTK in the user's
# environment.

export export_vtk, export_vtk_series

"""
    export_vtk(psi, grid; output, fields, atom) -> String
    export_vtk(ws::Workspace; kwargs...)        -> String

Export 3D wavefunction data to VTK ImageData (.vti) format for ParaView
visualisation. Available fields: `:density`, `:current`, `:spin_density`,
`:velocity`, `:vorticity`, `:component_densities`.

Requires `using WriteVTK` to load the ext that supplies methods.
"""
function export_vtk end

"""
    export_vtk_series(result, grid; output_dir, fields, atom, stride) -> String

Export time series from `SimulationResult` as `.pvd` collection +
per-frame `.vti` files. Requires `using WriteVTK`.
"""
function export_vtk_series end
