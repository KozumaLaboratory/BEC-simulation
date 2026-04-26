"""
Per-m vortex-line extraction for 3D spinor wavefunctions.

A quantum vortex is a phase singularity: the phase arg(ψ_m) winds by
±2π around a small closed loop threading the vortex core. Numerically
this is detected on each 2×2 xy-plaquette of the grid by summing the
principal-value phase differences around the plaquette — any plaquette
with total winding ±2π has a vortex line piercing it.

This implementation scans xy-plaquettes at every z-slab (so the detector
is tuned for near-z-axis lines, which covers the typical EdH / FL
geometry). Plaquette pierce points are then stitched across z by
greedy nearest-neighbour matching into polylines.
"""

@inline _wrap_phase(x) = x - 2π * round(x / (2π))

"""
    extract_vortex_lines_per_m(psi, grid; min_density_frac=0.0) -> Dict

For each spinor component m, return a vector of polylines
(Vector{NTuple{3,Float32}}) tracing phase singularities of ψ_m along
the z-axis. Keys are strings like "+5" or "-3" for the m value.

`min_density_frac` (0..1) suppresses singularities in regions where the
per-component density drops below this fraction of the GLOBAL |ψ|² peak.
0 keeps everything.
"""
function extract_vortex_lines_per_m(
    psi::AbstractArray{<:Complex, 4},
    grid::Grid{3};
    min_density_frac::Real=0.0,
)
    n_comp = size(psi, 4)
    F = div(n_comp - 1, 2)
    m_values = [F - (c - 1) for c in 1:n_comp]

    n_peak = 0.0
    @inbounds for i in eachindex(view(psi,:,:,:,1))
        s = 0.0
        for c in 1:n_comp
            s += abs2(psi[i + (c - 1) * length(view(psi,:,:,:,1))])
        end
        s > n_peak && (n_peak = s)
    end
    cutoff = Float64(min_density_frac) * n_peak

    out = Dict{String, Any}()
    for c in 1:n_comp
        m = m_values[c]
        psi_m = view(psi,:,:,:,c)
        lines = _extract_z_vortex_lines(psi_m, grid; density_cutoff=cutoff)
        isempty(lines) && continue
        out[string(m > 0 ? "+$m" : m)] = lines
    end
    out
end

"""
Find near-z-axis vortex lines in a single scalar complex field by
winding detection on xy-plaquettes and greedy z-stitching.
"""
function _extract_z_vortex_lines(
    psi_m::AbstractArray{<:Complex, 3},
    grid::Grid{3};
    density_cutoff::Float64=0.0,
)
    nx, ny, nz = size(psi_m)
    xs = grid.x[1];
    ys = grid.x[2];
    zs = grid.x[3]

    # Per-slab pierce points: Vector of (x, y, charge).
    slabs = Vector{Vector{Tuple{Float32, Float32, Int}}}(undef, nz)
    @inbounds for iz in 1:nz
        pts = Tuple{Float32, Float32, Int}[]
        for iy in 1:(ny - 1), ix in 1:(nx - 1)
            # Skip plaquettes in vacuum where phase is meaningless.
            if density_cutoff > 0
                a = abs2(psi_m[ix, iy, iz])
                b = abs2(psi_m[ix + 1, iy, iz])
                c = abs2(psi_m[ix + 1, iy + 1, iz])
                d = abs2(psi_m[ix, iy + 1, iz])
                (a + b + c + d) < 4 * density_cutoff && continue
            end
            φ00 = angle(psi_m[ix, iy, iz])
            φ10 = angle(psi_m[ix + 1, iy, iz])
            φ11 = angle(psi_m[ix + 1, iy + 1, iz])
            φ01 = angle(psi_m[ix, iy + 1, iz])
            Δ =
                _wrap_phase(φ10 - φ00) +
                _wrap_phase(φ11 - φ10) +
                _wrap_phase(φ01 - φ11) +
                _wrap_phase(φ00 - φ01)
            charge = round(Int, Δ / (2π))
            charge == 0 && continue
            x = 0.5f0 * (Float32(xs[ix]) + Float32(xs[ix + 1]))
            y = 0.5f0 * (Float32(ys[iy]) + Float32(ys[iy + 1]))
            push!(pts, (x, y, charge))
        end
        slabs[iz] = pts
    end

    # Stitch. Threshold = 3 grid cells in xy.
    threshold = Float32(3 * max(grid.dx[1], grid.dx[2]))
    claimed = [fill(false, length(s)) for s in slabs]
    lines = Vector{NamedTuple{(:charge, :points), Tuple{Int, Vector{NTuple{3, Float32}}}}}()

    @inbounds for iz_start in 1:nz
        for i in eachindex(slabs[iz_start])
            claimed[iz_start][i] && continue
            x0, y0, q0 = slabs[iz_start][i]
            claimed[iz_start][i] = true
            pts = NTuple{3, Float32}[(x0, y0, Float32(zs[iz_start]))]
            cur_x, cur_y = x0, y0

            for iz_next in (iz_start + 1):nz
                best = 0
                best_d = threshold
                for j in eachindex(slabs[iz_next])
                    claimed[iz_next][j] && continue
                    px, py, qj = slabs[iz_next][j]
                    qj == q0 || continue
                    d = sqrt((px - cur_x)^2 + (py - cur_y)^2)
                    if d < best_d
                        best_d = d
                        best = j
                    end
                end
                best == 0 && break
                claimed[iz_next][best] = true
                px, py, _ = slabs[iz_next][best]
                push!(pts, (px, py, Float32(zs[iz_next])))
                cur_x, cur_y = px, py
            end

            length(pts) >= 2 && push!(lines, (charge=q0, points=pts))
        end
    end

    lines
end
