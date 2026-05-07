# --- Dashboard compute kernels: density, phase, vorticity, atlas ---
#
# Pure compute helpers used by /api/density*, /api/phase*, /api/vorticity*,
# /api/vector3d*, /api/density3d_atlas. All take ψ + grid metadata and
# return packed Float32 binaries; no JLD2 / HTTP I/O. Extracted from
# dashboard.jl 2026-05-01.

function _trilinear_upsample(data::Array{Float64, 3}, target_n::Int)
    nx, ny, nz = size(data)
    out = Array{Float64, 3}(undef, target_n, target_n, target_n)
    @inbounds for iz in 1:target_n
        fz = 1.0 + (iz - 1) * (nz - 1) / (target_n - 1)
        z0 = clamp(floor(Int, fz), 1, nz - 1)
        z1 = z0 + 1
        wz = fz - z0
        for iy in 1:target_n
            fy = 1.0 + (iy - 1) * (ny - 1) / (target_n - 1)
            y0 = clamp(floor(Int, fy), 1, ny - 1)
            y1 = y0 + 1
            wy = fy - y0
            for ix in 1:target_n
                fx = 1.0 + (ix - 1) * (nx - 1) / (target_n - 1)
                x0 = clamp(floor(Int, fx), 1, nx - 1)
                x1 = x0 + 1
                wx = fx - x0
                c000 = data[x0, y0, z0];
                c100 = data[x1, y0, z0]
                c010 = data[x0, y1, z0];
                c110 = data[x1, y1, z0]
                c001 = data[x0, y0, z1];
                c101 = data[x1, y0, z1]
                c011 = data[x0, y1, z1];
                c111 = data[x1, y1, z1]
                c00 = c000 * (1 - wx) + c100 * wx
                c01 = c001 * (1 - wx) + c101 * wx
                c10 = c010 * (1 - wx) + c110 * wx
                c11 = c011 * (1 - wx) + c111 * wx
                c0 = c00 * (1 - wy) + c10 * wy
                c1 = c01 * (1 - wy) + c11 * wy
                out[ix, iy, iz] = c0 * (1 - wz) + c1 * wz
            end
        end
    end
    out
end

"""
Compute 3D density for each m-component.
Uses trilinear interpolation to produce smooth output at `target_n` resolution.
Top `max_components` by population are included, plus total.
"""
function _compute_3d_densities(jld2_path::String; target_n::Int=0, max_components::Int=0)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
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
                "population" => pops[ci] / max(total_pop, 1e-300),
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
function _read_box_size(jld2_path::String)
    # Embedded dataset (preferred)
    try
        d = _with_jld_handle(jld2_path) do f
            haskey(f, "grid_box_size") ? f["grid_box_size"] : nothing
        end
        if d !== nothing
            return d isa Vector ? Float64.(d) : Float64[Float64(d)]
        end
    catch
        # fall through
    end
    # Sibling config.yaml fallback
    config_path = joinpath(dirname(jld2_path), "config.yaml")
    isfile(config_path) || return nothing
    try
        data = YAML.load_file(config_path)
        pipe = get(data, "pipeline", [])
        isempty(pipe) && return nothing
        gs = first(values(pipe[1]))
        g = get(gs, "grid", nothing)
        g === nothing && return nothing
        box_raw = g isa Dict ? get(g, "box", get(g, "box_size", nothing)) : nothing
        box_raw === nothing && return nothing
        box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    catch
        nothing
    end
end

"""
    RunMetadata(box_size, n_points, atom_name, omega_ref, n_atoms)

Run-level geometry + physics constants extracted once and reused across
endpoint handlers. Resolved by `load_run_metadata(jld2_path)` which tries
the embedded JLD2 datasets first and falls back to the sibling
config.yaml. All fields except `box_size` may be `nothing` when the
source file doesn't carry the data (older runs / GS-only files).
"""
struct RunMetadata
    box_size::NTuple{3, Float64}
    n_points::Union{Nothing, NTuple{3, Int}}
    atom_name::Union{Nothing, String}
    omega_ref::Union{Nothing, Float64}
    n_atoms::Union{Nothing, Int}
end

function load_run_metadata(jld2_path::String)
    box_vec = _read_box_size(jld2_path)
    if box_vec === nothing || length(box_vec) < 3
        throw(
            ArgumentError(
                "Cannot resolve box_size for $(jld2_path): missing " *
                "`grid_box_size` in the JLD2 file and no usable grid.box " *
                "in config.yaml.",
            ),
        )
    end
    box = NTuple{3, Float64}((Float64(box_vec[1]), Float64(box_vec[2]), Float64(box_vec[3])))

    n_points = try
        n_vec = _with_jld_handle(jld2_path) do f
            haskey(f, "grid_n_points") ? f["grid_n_points"] : nothing
        end
        if n_vec === nothing
            nothing
        else
            NTuple{3, Int}((Int(n_vec[1]), Int(n_vec[2]), Int(n_vec[3])))
        end
    catch
        nothing
    end

    atom_name, omega_ref, n_atoms = _read_run_physics(jld2_path)
    RunMetadata(box, n_points, atom_name, omega_ref, n_atoms)
end

"""Tuple `(atom_name, omega_ref, n_atoms)` from JLD2 first then YAML."""
function _read_run_physics(jld2_path::String)
    # JLD2 may carry these inside `units/` group or `env/`
    try
        out = _with_jld_handle(jld2_path) do f
            atom = haskey(f, "units/atom") ? String(f["units/atom"]) : nothing
            omega = if haskey(f, "units/omega_ref_rad_s")
                Float64(f["units/omega_ref_rad_s"])
            else
                nothing
            end
            n = haskey(f, "units/N_atoms") ? Int(f["units/N_atoms"]) : nothing
            (atom, omega, n)
        end
        return out
    catch
        # fall through
    end
    # YAML fallback
    config_path = joinpath(dirname(jld2_path), "config.yaml")
    isfile(config_path) || return (nothing, nothing, nothing)
    try
        data = YAML.load_file(config_path)
        pipe = get(data, "pipeline", [])
        isempty(pipe) && return (nothing, nothing, nothing)
        gs = first(values(pipe[1]))
        atom = haskey(gs, "atom") ? String(gs["atom"]) : nothing
        inter = get(gs, "interactions", Dict())
        omega = inter isa Dict && haskey(inter, "omega_ref") ? Float64(inter["omega_ref"]) : nothing
        n = inter isa Dict && haskey(inter, "N_atoms") ? Int(inter["N_atoms"]) : nothing
        (atom, omega, n)
    catch
        (nothing, nothing, nothing)
    end
end

"""
Compute column densities (integrated along `axis`) for each m-component.
Returns Dict with m_values, densities (list of 2D arrays), grid info.
"""
function _compute_column_densities(jld2_path::String, axis::Int=3)
    d = JLD2.load(jld2_path)
    psi = d["psi"]
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
function _compute_column_density_binary(
    psi, n_comp, ndim, n_pts, F, axis::Int, jld2_path::String
)
    ndim >= 2 || throw(ArgumentError("Column density binary requires 2D or 3D data"))
    axis = clamp(axis, 1, ndim)
    box = _read_box_size(jld2_path)

    remaining = [i for i in 1:ndim if i != axis]
    out_shape = ntuple(i -> n_pts[remaining[i]], length(remaining))
    nx = out_shape[1]
    ny = length(out_shape) >= 2 ? out_shape[2] : 1
    plane_n = nx * ny

    densities = Vector{Float32}(undef, n_comp * plane_n)
    total = zeros(Float32, plane_n)
    @inbounds for c in 1:n_comp
        idx = _component_slice(ndim, n_pts, c)
        comp = abs2.(view(psi, idx...))
        col = vec(dropdims(sum(comp; dims=axis); dims=axis))
        off = (c - 1) * plane_n
        for i in 1:plane_n
            v = Float32(col[i])
            densities[off + i] = v
            total[i] += v
        end
    end

    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            length(remaining) >= 2 ? -box[remaining[2]]/2 : 0.0f0,
            length(remaining) >= 2 ? box[remaining[2]]/2 : 0.0f0]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    buf = IOBuffer(; sizehint=24 + 16 + n_comp*4 + plane_n*4 + n_comp*plane_n*4)
    write(buf, Int32(ndim), Int32(axis), Int32(nx), Int32(ny),
        Int32(n_comp), Int32(F))
    write(buf, ax_ranges)
    write(buf, m_values)
    write(buf, total)
    write(buf, densities)
    take!(buf)
end

"""
Bulk column-density atlas: every snap of a run packed into one panel-major
binary so the dashboard can fetch the whole scrub timeline in a single
HTTP request. Layout:

    Char header (4):  "DATL"
    Int32 header (7): n_snaps, ndim, axis, nx, ny, n_comp, F
    Float32 axis_ranges (4):  x_min, x_max, y_min, y_max
    Int32 m_values (n_comp)
    Float32 total_atlas:        n_snaps × nx × ny  (Total channel)
    Float32 component_atlases:  n_comp × n_snaps × nx × ny  (per-m channels)

The panel-major layout means the frontend can take per-channel
Float32Array views directly off the response ArrayBuffer — no
deinterleaving, no per-frame parsing.

Reuses the per-frame `density_bin` cache: if the prepack warmer has
already populated frames, the atlas just shuffles bytes; otherwise it
computes the missing frames in passing and back-fills the cache so a
subsequent per-frame request still hits.
"""
function _compute_column_density_atlas_binary(
    fpath::String, axis::Int, n_snaps::Int, psi_cache::Dict{String, Any}
)
    n_snaps > 0 || throw(ArgumentError("n_snaps must be positive"))
    # Load snap=1 to learn the shape; subsequent snaps reuse the same
    # geometry (the simulator never resizes the grid mid-dynamics).
    first_tup = _load_psi_cached(fpath, psi_cache, 1)
    psi1, n_comp, ndim, n_pts, F = first_tup
    ndim >= 2 || throw(ArgumentError("Atlas requires 2D or 3D data"))
    axis_clamped = clamp(axis, 1, ndim)

    # Geometry & axis ranges, derived from snap=1 with the same logic as
    # _compute_column_density_binary.
    box = _read_box_size(fpath)
    remaining = [i for i in 1:ndim if i != axis_clamped]
    nx = n_pts[remaining[1]]
    ny = length(remaining) >= 2 ? n_pts[remaining[2]] : 1
    plane_n = nx * ny
    plane_bytes = plane_n * 4
    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            length(remaining) >= 2 ? -box[remaining[2]]/2 : 0.0f0,
            length(remaining) >= 2 ? box[remaining[2]]/2 : 0.0f0]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    # Pre-allocate panel-major output buffer.
    header_size = 4 + 28 + 16 + n_comp * 4
    panel_atlas_bytes = n_snaps * plane_bytes
    total_size = header_size + (1 + n_comp) * panel_atlas_bytes
    out = Vector{UInt8}(undef, total_size)

    # Write header.
    out[1] = UInt8('D');
    out[2] = UInt8('A');
    out[3] = UInt8('T');
    out[4] = UInt8('L')
    hdr_int = reinterpret(Int32, view(out, 5:32))
    hdr_int[1] = Int32(n_snaps)
    hdr_int[2] = Int32(ndim)
    hdr_int[3] = Int32(axis_clamped)
    hdr_int[4] = Int32(nx)
    hdr_int[5] = Int32(ny)
    hdr_int[6] = Int32(n_comp)
    hdr_int[7] = Int32(F)
    rng_off = 33
    rng_view = reinterpret(Float32, view(out, rng_off:(rng_off + 15)))
    @inbounds for i in 1:4
        rng_view[i] = ax_ranges[i]
    end
    mv_off = rng_off + 16
    mv_view = reinterpret(Int32, view(out, mv_off:(mv_off + n_comp * 4 - 1)))
    @inbounds for i in 1:n_comp
        mv_view[i] = m_values[i]
    end

    # Per-snap data: pull each frame from the cache (or compute + cache it),
    # then route bytes into the panel-major output regions.
    total_atlas_off = header_size + 1
    frame_header_bytes = 24 + 16 + n_comp * 4  # matches per-frame binary layout
    @inbounds for snap in 1:n_snaps
        cache_key = "density_bin:$(fpath)#snap=$(snap)#axis=$(axis_clamped)"
        per_frame = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]::Vector{UInt8}
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_column_density_binary(
                _load_psi_cached(fpath, psi_cache, snap)..., axis_clamped, fpath
            )
            psi_cache[cache_key] = v
            v
        end
        # Source layout: header (frame_header_bytes) | total | densities × n_comp
        src_total_off = frame_header_bytes + 1
        dst_total_off = total_atlas_off + (snap - 1) * plane_bytes
        copyto!(out, dst_total_off, per_frame, src_total_off, plane_bytes)
        for c in 1:n_comp
            src_off = frame_header_bytes + plane_bytes + (c - 1) * plane_bytes + 1
            dst_off =
                total_atlas_off + panel_atlas_bytes +
                (c - 1) * panel_atlas_bytes + (snap - 1) * plane_bytes
            copyto!(out, dst_off, per_frame, src_off, plane_bytes)
        end
    end
    out
end

"""
3D density atlas: every snap of one component packed into one binary so
the 3D viewer can load the whole scrub timeline in a single fetch.
Layout (single-component, panel-major over snap):

    Char header (4):  "D3AT"
    Int32 header (6): n_snaps, nx, ny, nz, n_comp, component
    Float32 atlas:    n_snaps × nx × ny × nz

Reuses the per-frame `density3d_bin` cache: pre-warmed frames just memcpy
into the atlas region; missing frames are computed in passing and
cached.
"""
function _compute_density3d_atlas_binary(
    fpath::String, component::Int, n_snaps::Int, psi_cache::Dict{String, Any}
)
    n_snaps > 0 || throw(ArgumentError("n_snaps must be positive"))
    first_tup = _load_psi_cached(fpath, psi_cache, 1)
    psi1, n_comp, ndim, n_pts, F = first_tup
    ndim == 3 || throw(ArgumentError("density3d atlas requires 3D data"))
    nx = n_pts[1];
    ny = n_pts[2];
    nz = n_pts[3]
    voxel_n = nx * ny * nz
    voxel_bytes = voxel_n * 4

    header_size = 4 + 6 * 4  # magic + 6 Int32
    total_size = header_size + n_snaps * voxel_bytes
    out = Vector{UInt8}(undef, total_size)

    out[1] = UInt8('D');
    out[2] = UInt8('3');
    out[3] = UInt8('A');
    out[4] = UInt8('T')
    hdr_int = reinterpret(Int32, view(out, 5:28))
    hdr_int[1] = Int32(n_snaps)
    hdr_int[2] = Int32(nx)
    hdr_int[3] = Int32(ny)
    hdr_int[4] = Int32(nz)
    hdr_int[5] = Int32(n_comp)
    hdr_int[6] = Int32(component)

    # Per-frame data: pull from cache or compute. The per-snap binary
    # has its own header which we strip when copying.
    frame_header_bytes = 24 + n_comp * 4  # density3d_bin: header (24) + populations (n_comp*4)
    @inbounds for snap in 1:n_snaps
        cache_key = "density3d_bin:$(fpath)#snap=$(snap)#comp=$(component)#bsz=false"
        per_frame = if haskey(psi_cache, cache_key)
            psi_cache[cache_key]::Vector{UInt8}
        else
            while length(psi_cache) >= PSI_CACHE_MAX_ENTRIES
                _evict_one!(psi_cache)
            end
            v = _compute_3d_density_binary(
                _load_psi_cached(fpath, psi_cache, snap)...; component=component
            )
            psi_cache[cache_key] = v
            v
        end
        src_off = frame_header_bytes + 1
        dst_off = header_size + (snap - 1) * voxel_bytes + 1
        copyto!(out, dst_off, per_frame, src_off, voxel_bytes)
    end
    out
end

"""
Phase slice packed as Float32. Layout:

    Int32 header (7):  ndim, axis, slice_idx, nx, ny, n_comp, F
    Float32 axis_ranges (4)
    Int32 m_values (n_comp)
    Float32 phases     (n_comp * nx * ny)   -- radians, [-π, π]
    Float32 densities  (n_comp * nx * ny)   -- |ψ_m|² for low-density masking
"""
function _compute_phase_slice_binary(
    psi, n_comp, ndim, n_pts, F,
    axis::Int, slice_idx::Union{Nothing, Int},
    jld2_path::String,
)
    ndim == 3 || throw(ArgumentError("Phase slice binary requires 3D data, got $(ndim)D"))
    axis = clamp(axis, 1, ndim)
    k = slice_idx === nothing ? max(1, n_pts[axis] ÷ 2) : clamp(slice_idx, 1, n_pts[axis])
    box = _read_box_size(jld2_path)

    remaining = [i for i in 1:ndim if i != axis]
    nx = n_pts[remaining[1]]
    ny = n_pts[remaining[2]]
    plane_n = nx * ny

    phases = Vector{Float32}(undef, n_comp * plane_n)
    densities = Vector{Float32}(undef, n_comp * plane_n)
    @inbounds for c in 1:n_comp
        comp_view = view(psi, _component_slice(ndim, n_pts, c)...)
        slice = selectdim(comp_view, axis, k)
        ph = vec(angle.(slice))
        de = vec(abs2.(slice))
        off = (c - 1) * plane_n
        for i in 1:plane_n
            phases[off + i] = Float32(ph[i])
            densities[off + i] = Float32(de[i])
        end
    end

    ax_ranges = if box !== nothing && length(box) >= ndim
        Float32[-box[remaining[1]] / 2, box[remaining[1]] / 2,
            -box[remaining[2]] / 2, box[remaining[2]] / 2]
    else
        Float32[0, nx - 1, 0, ny - 1]
    end
    m_values = Int32[F - (c - 1) for c in 1:n_comp]

    buf = IOBuffer(; sizehint=28 + 16 + n_comp*4 + 2*n_comp*plane_n*4)
    write(buf, Int32(ndim), Int32(axis), Int32(k), Int32(nx), Int32(ny),
        Int32(n_comp), Int32(F))
    write(buf, ax_ranges)
    write(buf, m_values)
    write(buf, phases)
    write(buf, densities)
    take!(buf)
end
