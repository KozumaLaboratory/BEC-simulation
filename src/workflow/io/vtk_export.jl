"""
    export_vtk(psi, grid; output, fields, atom) -> String

Export 3D wavefunction data to VTK ImageData (.vti) format for ParaView visualization.

Available fields: `:density`, `:current`, `:spin_density`, `:velocity`,
`:vorticity`, `:component_densities`.
"""
function export_vtk(
    psi::AbstractArray{<:Complex},
    grid::Grid{3};
    output::String = "bec",
    fields::Vector{Symbol} = [:density, :current, :spin_density, :velocity],
    atom::Union{Nothing,AtomSpecies} = nothing,
)
    n_pts = ntuple(d -> size(psi, d), 3)
    n_comp = size(psi, 4)
    F = atom !== nothing ? atom.F : div(n_comp - 1, 2)

    x_ranges = ntuple(d -> range(grid.x[d][1], grid.x[d][end]; length = n_pts[d]), 3)

    plans = nothing
    sm = nothing

    _ensure_plans() = plans === nothing ? (plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)) : plans
    _ensure_sm() = sm === nothing ? (sm = spin_matrices(F)) : sm

    paths = WriteVTK.vtk_grid(output, x_ranges...) do vtk
        for field in fields
            if field === :density
                vtk["density"] = total_density(psi, 3)
            elseif field === :current
                jx, jy, jz = probability_current(psi, grid, _ensure_plans())
                vtk["current"] = (jx, jy, jz)
            elseif field === :spin_density
                fx, fy, fz = spin_density_vector(psi, _ensure_sm(), 3)
                vtk["spin_density"] = (fx, fy, fz)
            elseif field === :velocity
                vx, vy, vz = superfluid_velocity(psi, grid, _ensure_plans())
                vtk["velocity"] = (vx, vy, vz)
            elseif field === :vorticity
                wx, wy, wz = superfluid_vorticity(psi, grid, _ensure_plans())
                vtk["vorticity"] = (wx, wy, wz)
            elseif field === :component_densities
                for c in 1:n_comp
                    m = F - (c - 1)
                    label = m >= 0 ? "n_p$m" : "n_m$(abs(m))"
                    vtk[label] = component_density(psi, 3, c)
                end
            else
                @warn "Unknown VTK field: $field"
            end
        end
    end

    first(paths)
end

"""
    export_vtk_series(result, grid; output_dir, fields, atom, stride) -> String

Export time series from SimulationResult as `.pvd` collection + per-frame `.vti` files.
"""
function export_vtk_series(
    result::SimulationResult,
    grid::Grid{3};
    output_dir::String = "vtk_output",
    fields::Vector{Symbol} = [:density, :current, :spin_density],
    atom::Union{Nothing,AtomSpecies} = nothing,
    stride::Int = 1,
)
    mkpath(output_dir)

    indices = 1:stride:length(result.psi_snapshots)
    n_pts = ntuple(d -> size(result.psi_snapshots[1], d), 3)
    n_comp = size(result.psi_snapshots[1], 4)
    F = atom !== nothing ? atom.F : div(n_comp - 1, 2)

    plans = nothing
    sm = nothing
    needs_plans = any(f -> f in (:current, :velocity, :vorticity), fields)
    needs_sm = :spin_density in fields

    if needs_plans
        plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
    end
    if needs_sm
        sm = spin_matrices(F)
    end

    x_ranges = ntuple(d -> range(grid.x[d][1], grid.x[d][end]; length = n_pts[d]), 3)

    pvd = WriteVTK.paraview_collection(joinpath(output_dir, "series"))
    try
        for (frame, idx) in enumerate(indices)
            psi = result.psi_snapshots[idx]
            t = result.times[idx]
            fname = joinpath(output_dir, "frame_$(lpad(frame, 4, '0'))")

            vti = WriteVTK.vtk_grid(fname, x_ranges...)
            for field in fields
                if field === :density
                    vti["density"] = total_density(psi, 3)
                elseif field === :current
                    jx, jy, jz = probability_current(psi, grid, plans)
                    vti["current"] = (jx, jy, jz)
                elseif field === :spin_density
                    fx, fy, fz = spin_density_vector(psi, sm, 3)
                    vti["spin_density"] = (fx, fy, fz)
                elseif field === :velocity
                    vx, vy, vz = superfluid_velocity(psi, grid, plans)
                    vti["velocity"] = (vx, vy, vz)
                elseif field === :vorticity
                    wx, wy, wz = superfluid_vorticity(psi, grid, plans)
                    vti["vorticity"] = (wx, wy, wz)
                elseif field === :component_densities
                    for c in 1:n_comp
                        m = F - (c - 1)
                        label = m >= 0 ? "n_p$m" : "n_m$(abs(m))"
                        vti[label] = component_density(psi, 3, c)
                    end
                end
            end
            pvd[t] = vti
        end
    finally
        vtk_save(pvd)
    end

    joinpath(output_dir, "series.pvd")
end

function export_vtk(ws::Workspace; kwargs...)
    export_vtk(Array(ws.state.psi), ws.grid; atom = ws.atom, kwargs...)
end
