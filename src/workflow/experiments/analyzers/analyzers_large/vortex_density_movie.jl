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
# (archived viz_dynamics_movie.py) is deliberately outside Julia — matplotlib
# writes the mp4, and re-rendering must not mean re-running the physics.

"""
    _analyze_vortex_density_movie(psi, grid, atom, params, ws_prev, pipeline_results)

Per-snapshot density / spin / phase / vortex fields for a dynamics movie.

Two defect traces, deliberately separate:

- **`mvortex_*` / `mass_vortex_counts` — the vortices.** Circulation of the
  TOTAL mass current, gated on the TOTAL density. Invariant under a uniform
  spin rotation, so population moving between components contributes nothing.
- `vortex_*` / `vortex_counts` — per-component phase winding. A spin-texture
  diagnostic, NOT a vortex count; it fires on the amplitude zeros a component
  develops while its population is rotated away.

Params:
- `axis` (3): line-of-sight axis for the column integrals, and the normal of
  the analysed mid-plane.
- `component`: spinor component for the SECONDARY phase trace. Default is the
  most populated component of the FIRST frame, held fixed for the whole movie —
  following the population would silently change what the phase panel means
  partway through. The mass-current trace does not depend on it.
- `threshold` (0.1): detection floor. For the mass current it is a fraction of
  the TOTAL mid-plane density peak, required at all four plaquette corners; for
  the per-component trace it is a fraction of that component's own peak (a
  global floor there would erase minority components and report a spurious
  zero).
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
    # Physical spacing of the two in-plane axes, for the mass current.
    plane = [d for d in 1:ndim if d != axis]
    spacing = ntuple(k -> grid.config.box_size[plane[k]] / n_pts[plane[k]], 2)

    frame_times = Float64[]
    frame_phases = Int[]
    mass_counts = Int[]
    mass_counts_strict = Int[]
    mass_charges = Int[]
    quantisation_error = Float64[]
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

            # SIDE view: column along the first in-plane axis, so the axis the
            # DDI elongates is on screen. The top view integrates ALONG that
            # axis and is a circular blob however prolate the cloud is —
            # measured z/x = 1.42 on the Eu ground state, invisible there.
            out["n_side_" * key] = Float32.(
                dropdims(sum(n_total; dims=plane[1]); dims=plane[1]))
            # Mid-plane TOTAL density: a vortex core is a hole in THIS, not in
            # one component's slice.
            out["n_mid_" * key] = Float32.(selectdim(n_total, axis, mid))

            # THE vortex trace: circulation of the total mass current.
            n_mid = selectdim(n_total, axis, mid)
            psi_mid = selectdim(frame, axis, mid)
            mx, my, mq, mw, worst = _mass_current_vortices(psi_mid, n_mid,
                spacing[1], spacing[2], threshold)
            out["mvortex_x_" * key] = mx
            out["mvortex_y_" * key] = my
            out["mvortex_q_" * key] = mq
            out["mvortex_w_" * key] = mw

            # Secondary: per-component phase winding. Kept because it is a real
            # spin-texture diagnostic, labelled separately because it is NOT
            # the vortex count.
            vx, vy, vq = _plaquette_vortices(phase2d, dens2d, threshold)
            out["vortex_x_" * key] = vx
            out["vortex_y_" * key] = vy
            out["vortex_q_" * key] = vq

            push!(frame_times, t)
            push!(frame_phases, phase_idx)
            push!(mass_counts, length(mq))
            push!(mass_charges, isempty(mq) ? 0 : sum(mq))
            # The defensible number: circulations actually close to an integer.
            push!(mass_counts_strict,
                count(k -> abs(mw[k] - mq[k]) < 0.25, eachindex(mq)))
            push!(quantisation_error, worst)
            push!(vortex_counts, length(vq))
            push!(net_charges, isempty(vq) ? 0 : sum(vq))
        end
        out["n_frames"] = idx
        out["axis"] = axis
        out["component"] = component
        out["mid_index"] = mid
    end

    manifest = Dict{String, Any}(
        "n_frames" => idx,
        "axis" => axis,
        "component" => component,
        "mid_index" => mid,
        "times" => frame_times,
        "phase_indices" => frame_phases,
        "n_phases" => _n_dynamics_phases(pipeline_results, multi_step),
        # The vortex trace: total mass-current circulation.
        "mass_vortex_counts" => mass_counts,
        "mass_vortex_counts_strict" => mass_counts_strict,
        "mass_net_charges" => mass_charges,
        "quantisation_error" => quantisation_error,
        # Secondary: per-component phase winding. NOT a vortex count.
        "vortex_counts" => vortex_counts,
        "net_charges" => net_charges,
        "plane_axes" => plane,
        "spacing" => [spacing[1], spacing[2]],
        "extent" => [grid.config.box_size[plane[1]], grid.config.box_size[plane[2]]],
        # (in-plane axis 2, view axis) — the side view's own extent, which is
        # NOT square once the cloud is elongated along the view axis.
        "side_extent" => [grid.config.box_size[plane[2]], grid.config.box_size[axis]],
        "archive" => basename(archive_path),
    )
    open(manifest_path, "w") do io
        JSON.print(io, manifest)
    end

    (output_dir=output_dir, n_frames=idx, archive_path=archive_path,
        manifest_path=manifest_path, component=component,
        mass_vortex_counts=mass_counts, mass_vortex_counts_strict=mass_counts_strict,
        mass_net_charges=mass_charges,
        quantisation_error=quantisation_error,
        vortex_counts=vortex_counts, net_charges=net_charges)
end

# --- the total-density statement: circulation of the mass current ------------
#
# A superfluid vortex is quantised circulation of the TOTAL flow. The
# per-component phase winding further down is a different object, and during
# spin dynamics it is mostly not vortices: while a spin rotation empties one
# component, that component's amplitude passes through zeros and its phase winds
# around them with no superfluid flow anywhere. Measured on the rotating-field
# stir run, that mechanism produced ~130 "vortices" within t = 0.02 of the field
# turning on, out of a ground state with exactly zero at every threshold — and
# it was dt-independent, so it was not numerical noise either. It was the wrong
# quantity.
#
#   j = Σ_c Im(conj(ψ_c) ∇ψ_c),   v = j / n_total
#
# uses every component and is invariant under a spatially uniform spin rotation,
# so population moving between components contributes exactly nothing. The
# circulation ∮v·dl around a plaquette is 2π× an integer for a mass vortex and 0
# for a coreless / spin texture, which is the distinction that was missing.
#
# Gated on the TOTAL density at all four corners — that is what "total-density
# based" buys: the gate no longer depends on which component is being tracked.
"""
    _mass_current_vortices(psi_slice, n_tot, dx, dy, threshold)
        -> (xs, ys, qs, ws, worst_frac)

Loop centres whose mass-current circulation is a nonzero multiple of 2π.

`qs` is the rounded winding and `ws` the RAW `Γ/2π` behind it, kept so that how
strictly "quantised" is defined stays a question the reader can re-ask without
re-running the physics. `worst_frac` is the largest `|w − q|` among the reported
centres — the circulation of a discretised mass current is only approximately
quantised, so this is the diagnostic's own error bar and is reported rather than
assumed small. Measured: 0.018 on an exact f(r)e^{iφ} vortex, but ~0.49 on the
post-stir Eu state, i.e. that state's flow is disordered, not a clean vortex
lattice. A count quoted without this number is not a measurement.
"""
function _mass_current_vortices(psi_slice, n_tot::AbstractMatrix,
    dx::Float64, dy::Float64, threshold::Float64; loop_radius::Int=2)
    nx, ny, D = size(psi_slice)
    xs, ys, qs, raw = Float32[], Float32[], Int32[], Float32[]
    worst = 0.0
    nmax = maximum(n_tot)
    (nmax <= 0 || nx < 5 || ny < 5) && return (xs, ys, qs, raw, worst)
    cut = threshold * nmax

    vx = zeros(Float64, nx, ny)
    vy = zeros(Float64, nx, ny)
    @inbounds for j in 2:(ny - 1), i in 2:(nx - 1)
        n = n_tot[i, j]
        n < 1e-30 && continue
        jx = 0.0
        jy = 0.0
        for c in 1:D
            z = conj(psi_slice[i, j, c])
            jx += imag(z * (psi_slice[i + 1, j, c] - psi_slice[i - 1, j, c])) / (2dx)
            jy += imag(z * (psi_slice[i, j + 1, c] - psi_slice[i, j - 1, c])) / (2dy)
        end
        vx[i, j] = jx / n
        vy[i, j] = jy / n
    end

    # The loop is R cells across, NOT one plaquette. v ~ 1/r at a core, so a
    # single-plaquette circulation is hopelessly under-resolved — measured on an
    # exact f(r)e^{iφ} vortex it returns w = 0.238 instead of 1. The same field
    # on a square loop of half-width R gives
    #
    #     R = 2 → 0.982    R = 3 → 0.990    R = 5 → 0.994    R = 8 → 0.995
    #
    # so R = 2 is where this becomes a measurement rather than a guess. (The
    # first version of this function used one plaquette and failed its own
    # positive control, which is why the control exists.)
    R = max(2, loop_radius)
    (nx < 2R + 3 || ny < 2R + 3) && return (xs, ys, qs, raw, worst)

    # "Is this point inside the cloud?" — on a NEIGHBOURHOOD, not at the point.
    # A core is precisely where the density vanishes, so a pointwise gate
    # rejects every vortex it is meant to find.
    in_cloud = falses(nx, ny)
    @inbounds for j in 1:ny, i in 1:nx
        m = 0.0
        for jj in max(1, j - R):min(ny, j + R), ii in max(1, i - R):min(nx, i + R)
            m = max(m, n_tot[ii, jj])
        end
        in_cloud[i, j] = m >= cut
    end

    w = zeros(Float64, nx, ny)
    @inbounds for j in (1 + R):(ny - R), i in (1 + R):(nx - R)
        in_cloud[i, j] || continue
        circ = 0.0
        for k in (-R):(R - 1)
            circ += vx[i + k, j - R] * dx          # bottom, +x
            circ += vy[i + R, j + k] * dy          # right,  +y
            circ -= vx[i - k, j + R] * dx          # top,    -x
            circ -= vy[i - R, j - k] * dy          # left,   -y
        end
        w[i, j] = circ / (2π)
    end

    # One core, one report: keep a candidate only if it dominates its own loop
    # neighbourhood. Without this a single vortex is reported by every
    # overlapping loop that encloses it.
    @inbounds for j in (1 + R):(ny - R), i in (1 + R):(nx - R)
        wij = w[i, j]
        abs(wij) < 0.5 && continue
        dominant = true
        for jj in (j - R):(j + R), ii in (i - R):(i + R)
            (ii == i && jj == j) && continue
            if abs(w[ii, jj]) > abs(wij) ||
                (abs(w[ii, jj]) == abs(wij) && (jj, ii) < (j, i))
                dominant = false
                break
            end
        end
        dominant || continue
        q = round(Int, wij)
        q == 0 && continue
        push!(xs, Float32(i))
        push!(ys, Float32(j))
        push!(qs, Int32(q))
        push!(raw, Float32(wij))
        worst = max(worst, abs(wij - q))
    end
    (xs, ys, qs, raw, worst)
end

# Plaquette winding on one 2D slice. Same 4-point circulation `vortex_detect`
# uses; kept here rather than called through it because that analyzer takes a
# full spinor and returns a summary, and this needs raw positions per frame.
#
# Retained as a SECONDARY trace: it is a real spin-texture diagnostic, it is
# just not the vortex count. `thresh` is relative to THIS slice's own peak.
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
