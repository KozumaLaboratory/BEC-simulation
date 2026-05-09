# Dashboard binary packers (column density, atlas, density3d atlas, phase slice)

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
