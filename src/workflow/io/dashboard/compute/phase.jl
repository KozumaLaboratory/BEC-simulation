# Dashboard phase-slice compute kernel (cache-aware)

function _compute_phase_slice_from_cache(
    psi, n_comp, ndim, n_pts, F,
    axis::Int, slice_idx::Union{Nothing, Int},
    jld2_path::String,
)
    ndim == 3 || throw(ArgumentError("Phase slice requires 3D data, got $(ndim)D"))
    m_values = [F - (c - 1) for c in 1:n_comp]
    axis = clamp(axis, 1, ndim)
    k = slice_idx === nothing ? max(1, n_pts[axis] ÷ 2) : clamp(slice_idx, 1, n_pts[axis])

    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))
    box = _read_box_size(jld2_path)

    phases = Vector{Vector{Float64}}()
    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        comp_view = view(psi, _component_slice(ndim, n_pts, c)...)
        slice = selectdim(comp_view, axis, k)  # 2D complex
        push!(phases, vec(angle.(slice)))
        push!(densities, vec(abs2.(slice)))
    end

    axis_names = ["x", "y", "z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String, Any}(
        "m_values" => m_values,
        "phases" => phases,
        "densities" => densities,
        "ndim" => ndim,
        "axis" => axis,
        "slice_index" => k,
        "shape" => collect(out_shape),
        "axis_labels" => ax_labels,
        "axis_ranges" => ax_ranges,
        "box" => box,
    )
end

"""
Column density (axis-integrated) packed as Float32. Layout matches the
JSON endpoint field-for-field, just binary:

    Int32 header (6):  ndim, axis, nx, ny, n_comp, F
    Float32 axis_ranges (4):  x_min, x_max, y_min, y_max
    Int32 m_values (n_comp)
    Float32 total_density (nx*ny)
    Float32 densities (n_comp * nx * ny)   -- per-component, in m=+F → -F order

Total size for 64×64 × 13 components: 24 + 16 + 52 + 16384 + 213 KB ≈ 230 KB,
vs ~1.6 MB for the equivalent JSON.
"""
