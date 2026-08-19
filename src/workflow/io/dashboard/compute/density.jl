# Dashboard density compute kernels (3D + column)

function _compute_3d_densities(jld2_path::String; target_n::Int=0, max_components::Int=0)
    d = JLD2.load(jld2_path)
    psi = haskey(d, "psi") ? d["psi"] : load_point_psi(jld2_path)  # light point → stage
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)

    ndim == 3 || throw(ArgumentError("3D density requires 3D data, got $(ndim)D"))

    all_densities = [
        Float64.(abs2.(view(psi, _component_slice(ndim, n_pts, c)...))) for c in 1:n_comp
    ]
    pops = [sum(dens) for dens in all_densities]
    total_pop = sum(pops)

    total_dens = sum(all_densities)

    sorted_idx = sortperm(pops; rev=true)
    n_keep = max_components > 0 ? min(max_components, n_comp) : n_comp
    top_idx = sorted_idx[1:n_keep]

    # Interpolate only if explicitly requested (target_n > 0)
    out_n = target_n > 0 ? min(target_n, maximum(n_pts) * 2) : 0
    need_interp = out_n > 0 && (out_n != n_pts[1] || out_n != n_pts[2] || out_n != n_pts[3])

    total_out = need_interp ? _trilinear_upsample(total_dens, out_n) : total_dens

    components = Dict{String, Any}[]
    for ci in top_idx
        dens = need_interp ? _trilinear_upsample(all_densities[ci], out_n) : all_densities[ci]
        push!(
            components,
            Dict{String, Any}(
                "m" => m_values[ci],
                "population" => pops[ci] / max(total_pop, UNDERFLOW_FLOOR),
                "density" => vec(dens),
            ),
        )
    end

    out_shape = need_interp ? (out_n, out_n, out_n) : n_pts

    Dict{String, Any}(
        "m_values" => [c["m"] for c in components],
        "total_density" => vec(total_out),
        "components" => components,
        "shape" => collect(out_shape),
        "original_shape" => collect(n_pts),
        "interpolated" => need_interp,
    )
end

"""
Resolve box_size for `jld2_path`. First tries the embedded
`grid_box_size` dataset (written by `_run_yaml_single`), then falls
back to parsing the sibling config.yaml's `pipeline[0].<step>.grid.box`.
Returns nothing if neither path produces a usable vector.

The JLD2-first lookup matters for configs that move `grid:` into a
`mixins:` block: the YAML fallback reads the raw YAML, so it never
sees the expanded grid.
"""

function _compute_column_densities(jld2_path::String, axis::Int=3)
    d = JLD2.load(jld2_path)
    psi = haskey(d, "psi") ? d["psi"] : load_point_psi(jld2_path)  # light point → stage
    n_comp = size(psi, ndims(psi))
    ndim = ndims(psi) - 1
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]
    n_pts = ntuple(i -> size(psi, i), ndim)
    box = _read_box_size(jld2_path)

    if ndim == 1
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        x_range = box !== nothing ? [-box[1]/2, box[1]/2] : [0, n_pts[1]-1]
        return Dict{String, Any}(
            "m_values" => m_values,
            "densities" => densities,
            "ndim" => 1,
            "shape" => [n_pts[1]],
            "axis" => 0,
            "box" => box,
            "x_range" => x_range,
        )
    end

    axis = clamp(axis, 1, ndim)
    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))

    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = dropdims(sum(comp; dims=axis); dims=axis)
        push!(densities, vec(col))
    end

    total = zeros(Float64, prod(out_shape))
    for dens in densities
        total .+= dens
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
        "densities" => densities,
        "total_density" => total,
        "ndim" => ndim,
        "shape" => collect(out_shape),
        "axis" => axis,
        "axis_labels" => ax_labels,
        "axis_ranges" => ax_ranges,
        "box" => box,
    )
end

"""Column densities from pre-loaded (cached) psi."""
function _compute_column_densities_from_cache(
    psi, n_comp, ndim, n_pts, F, axis::Int, jld2_path::String
)
    m_values = [F - (c - 1) for c in 1:n_comp]
    box = _read_box_size(jld2_path)

    if ndim == 1
        densities = [Float64[abs2(psi[i, c]) for i in 1:n_pts[1]] for c in 1:n_comp]
        x_range = box !== nothing ? [-box[1]/2, box[1]/2] : [0, n_pts[1]-1]
        return Dict{String, Any}(
            "m_values" => m_values, "densities" => densities,
            "ndim" => 1, "shape" => [n_pts[1]], "axis" => 0,
            "box" => box, "x_range" => x_range,
        )
    end

    axis = clamp(axis, 1, ndim)
    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))

    densities = Vector{Vector{Float64}}()
    for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = dropdims(sum(comp; dims=axis); dims=axis)
        push!(densities, vec(col))
    end

    total = zeros(Float64, prod(out_shape))
    for dens in densities
        total .+= dens
    end

    axis_names = ["x", "y", "z"]
    ax_labels = [axis_names[i] for i in remaining]
    ax_ranges = if box !== nothing && length(box) >= ndim
        [[-box[i]/2, box[i]/2] for i in remaining]
    else
        [[0, n_pts[i]-1] for i in remaining]
    end

    Dict{String, Any}(
        "m_values" => m_values, "densities" => densities,
        "total_density" => total, "ndim" => ndim,
        "shape" => collect(out_shape), "axis" => axis,
        "axis_labels" => ax_labels, "axis_ranges" => ax_ranges, "box" => box,
    )
end

"""
Per-component phase arg(ψ_m) at a single plane (index `slice_idx` along `axis`).
3D only. Also returns per-component |ψ_m|² at the same plane so the frontend
can mask phase at low density where the angle is ill-defined.
"""
