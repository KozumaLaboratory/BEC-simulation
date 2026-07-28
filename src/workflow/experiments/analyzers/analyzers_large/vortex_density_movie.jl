# Per-frame fields for watching an excitation develop: where the vortices are,
# what the density is doing, and what the spin is doing, at every saved
# snapshot.
#
# `column_density_movie` writes the column density alone, which cannot show a
# vortex: a vortex is a phase defect, and integrating along the line of sight
# is exactly what washes out the core. So this writes the mid-plane phase and
# the plaquette-detected defects alongside the density, and the spin columns
# that say whether a density hole is a vortex or a domain.
#
# Everything is streamed frame-by-frame into one JLD2 archive. The renderer
# (scripts/viz_dynamics_movie.py) is deliberately outside Julia — matplotlib
# writes the mp4, and re-rendering must not mean re-running the physics.

"""
    _analyze_vortex_density_movie(psi, grid, atom, params, ws_prev, pipeline_results)

Per-snapshot density / spin / phase / vortex fields for a dynamics movie.

Params:
- `axis` (3): line-of-sight axis for the column integrals.
- `component`: spinor component whose phase carries the vortices. Default is
  the most populated component of the FIRST frame, held fixed for the whole
  movie — following the population would silently change what the phase panel
  means partway through.
- `threshold` (0.1): plaquette detection floor, relative to that component's
  own peak IN THAT FRAME. Per-component by construction: a global density
  threshold erases minority components and reports a spurious zero.
- `output_dir` ("movie"), `multi_step` (false).

Writes `<output_dir>/frames.jld2` + `manifest.json`.
"""
function _analyze_vortex_density_movie(psi, grid, atom, params, ws_prev,
    pipeline_results=Dict{Symbol, Any}())
    ndim = length(grid.config.n_points)
    ndim == 3 || throw(ArgumentError(
        "vortex_density_movie currently supports 3D only (got $(ndim)D)"))
    axis = Int(get(params, "axis", 3))
    threshold = Float64(get(params, "threshold", 0.1))
    output_dir = String(get(params, "output_dir", "movie"))
    multi_step = Bool(get(params, "multi_step", false))
    mkpath(output_dir)

    n_pts = grid.config.n_points
    D = 2 * atom.F + 1
    sm = spin_matrices(atom.F)
    # Mid-plane along the view axis — where a vortex line crossing the cloud
    # centre shows its core.
    mid = n_pts[axis] ÷ 2 + 1
    component = haskey(params, "component") ? Int(params["component"]) : 0

    archive_path = joinpath(output_dir, "frames.jld2")
    manifest_path = joinpath(output_dir, "manifest.json")
    frame_times = Float64[]
    frame_phases = Int[]
    vortex_counts = Int[]
    net_charges = Int[]
    idx = 0

    jldopen(archive_path, "w") do out
        _each_dynamics_snapshot(pipeline_results, multi_step,
            "vortex_density_movie") do frame, t, phase_idx
            idx += 1
            if component == 0
                pops = [sum(abs2, view(frame, _component_slice(ndim, n_pts, c)...))
                        for c in 1:D]
                component = argmax(pops)
            end

            n_total = total_density(frame, ndim)
            fx, fy, fz = spin_density_vector(frame, sm, ndim)

            key = lpad(string(idx), 5, '0')
            out["n_col_" * key] = Float32.(dropdims(sum(n_total; dims=axis); dims=axis))
            out["fz_col_" * key] = Float32.(dropdims(sum(fz; dims=axis); dims=axis))
            out["fperp_col_" * key] = Float32.(
                dropdims(sum(sqrt.(fx .^ 2 .+ fy .^ 2); dims=axis); dims=axis))

            psi_c = view(frame, _component_slice(ndim, n_pts, component)...)
            slice_c = selectdim(psi_c, axis, mid)
            phase2d = angle.(slice_c)
            dens2d = abs2.(slice_c)
            out["phase_" * key] = Float32.(phase2d)
            out["dens_mid_" * key] = Float32.(dens2d)

            vx, vy, vq = _plaquette_vortices(phase2d, dens2d, threshold)
            out["vortex_x_" * key] = vx
            out["vortex_y_" * key] = vy
            out["vortex_q_" * key] = vq

            push!(frame_times, t)
            push!(frame_phases, phase_idx)
            push!(vortex_counts, length(vq))
            push!(net_charges, isempty(vq) ? 0 : sum(vq))
        end
        out["n_frames"] = idx
        out["axis"] = axis
        out["component"] = component
        out["mid_index"] = mid
    end

    # Physical axes for the two in-plane directions, so the renderer never has
    # to guess the aspect ratio.
    plane = [d for d in 1:ndim if d != axis]
    manifest = Dict{String, Any}(
        "n_frames" => idx,
        "axis" => axis,
        "component" => component,
        "mid_index" => mid,
        "times" => frame_times,
        "phase_indices" => frame_phases,
        "n_phases" => _n_dynamics_phases(pipeline_results, multi_step),
        "vortex_counts" => vortex_counts,
        "net_charges" => net_charges,
        "plane_axes" => plane,
        "extent" => [grid.config.box_size[plane[1]], grid.config.box_size[plane[2]]],
        "archive" => basename(archive_path),
    )
    open(manifest_path, "w") do io
        JSON.print(io, manifest)
    end

    (output_dir=output_dir, n_frames=idx, archive_path=archive_path,
        manifest_path=manifest_path, component=component,
        vortex_counts=vortex_counts, net_charges=net_charges)
end

# Plaquette winding on one 2D slice. Same 4-point circulation `vortex_detect`
# uses; kept here rather than called through it because that analyzer takes a
# full spinor and returns a summary, and this needs raw positions per frame.
#
# `thresh` is relative to THIS slice's own peak, so a component that empties
# out mid-movie stops reporting defects instead of reporting noise.
function _plaquette_vortices(phase2d::AbstractMatrix, dens2d::AbstractMatrix,
    threshold::Float64)
    nx, ny = size(phase2d)
    xs, ys, qs = Float32[], Float32[], Int32[]
    dmax = maximum(dens2d)
    dmax <= 0 && return (xs, ys, qs)
    cut = threshold * dmax
    @inbounds for j in 1:(ny - 1), i in 1:(nx - 1)
        dens2d[i, j] < cut && continue
        dp =
            _phase_diff(phase2d[i + 1, j], phase2d[i, j]) +
            _phase_diff(phase2d[i + 1, j + 1], phase2d[i + 1, j]) +
            _phase_diff(phase2d[i, j + 1], phase2d[i + 1, j + 1]) +
            _phase_diff(phase2d[i, j], phase2d[i, j + 1])
        if abs(dp) > π
            push!(xs, Float32(i) + 0.5f0)
            push!(ys, Float32(j) + 0.5f0)
            push!(qs, Int32(round(dp / (2π))))
        end
    end
    (xs, ys, qs)
end
