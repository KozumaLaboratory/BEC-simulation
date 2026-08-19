# --- Topology / vortex / texture analyzers ---
#
# Defect-counting and topological-charge analyzers: orbital +
# magnetisation winding maps, the per-point winding-number field,
# 3D monopole-charge density, plaquette vortex detection, skyrmion-
# texture (charge + Berry curvature), and SO(3)-loop holonomy.

function _analyze_winding_map(psi, grid, atom, params, ws_prev)
    F = atom.F
    n_pts = grid.config.n_points
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    Lz_total = orbital_angular_momentum(psi, grid, plans)
    Mz = magnetization(psi, grid, SpinSystem(F))
    j = probability_current(psi, grid, plans)
    j_mag = sqrt.(sum(ji .^ 2 for ji in j))
    (Lz=Lz_total, Mz=Mz, Jz=Lz_total + Mz, max_current=maximum(j_mag))
end

function _analyze_skyrmion_density(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    n_pts = grid.config.n_points
    sm = spin_matrices(F)
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    if ndim == 2
        Q = spin_texture_charge(psi, grid, plans, sm)
        omega = berry_curvature(psi, grid, plans, sm)
        (charge=Q, berry_curvature=omega)
    elseif ndim == 3
        omega_x, omega_y, omega_z = berry_curvature(psi, grid, plans, sm)
        dV = cell_volume(grid)
        Q_xy = sum(omega_z) * dV / (4π)
        (charge_xy=Q_xy, berry_curvature=(omega_x, omega_y, omega_z))
    else
        (charge=0.0,)
    end
end

function _analyze_vortex_detect(psi, grid, atom, params, ws_prev)
    F = atom.F
    ndim = length(grid.config.n_points)
    n_pts = grid.config.n_points
    ndim >= 2 || throw(ArgumentError("vortex_detect requires N >= 2"))
    component = Int(get(params, "component", 1))
    threshold = Float64(get(params, "threshold", 0.1))
    idx = _component_slice(ndim, n_pts, component)
    psi_c = view(psi, idx...)
    n_c = abs2.(psi_c)
    n_max = maximum(n_c)
    phase_field = angle.(psi_c)
    thresh = threshold * n_max
    vortex_count = 0
    positions = Tuple[]
    if ndim == 2
        @inbounds for j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
            n_c[i, j] < thresh && continue
            dp =
                _phase_diff(phase_field[i + 1, j], phase_field[i, j]) +
                _phase_diff(phase_field[i + 1, j + 1], phase_field[i + 1, j]) +
                _phase_diff(phase_field[i, j + 1], phase_field[i + 1, j + 1]) +
                _phase_diff(phase_field[i, j], phase_field[i, j + 1])
            if abs(dp) > π
                vortex_count += 1
                push!(positions, (i, j, round(Int, dp / (2π))))
            end
        end
    else
        @inbounds for k in 1:n_pts[3], j in 2:(n_pts[2] - 1), i in 2:(n_pts[1] - 1)
            n_c[i, j, k] < thresh && continue
            dp =
                _phase_diff(phase_field[i + 1, j, k], phase_field[i, j, k]) +
                _phase_diff(phase_field[i + 1, j + 1, k], phase_field[i + 1, j, k]) +
                _phase_diff(phase_field[i, j + 1, k], phase_field[i + 1, j + 1, k]) +
                _phase_diff(phase_field[i, j, k], phase_field[i, j + 1, k])
            if abs(dp) > π
                vortex_count += 1
                push!(positions, (i, j, k, round(Int, dp / (2π))))
            end
        end
    end
    (vortex_count=vortex_count, positions=positions, component=component)
end

# Klaus-2022 residual-image analysis of the COLUMN DENSITY. Deliberately not
# `vortex_detect`: that one reads the phase and counts every circulation, which
# is a different observable from the published 𝒩ᵥ (a detector output on a
# blurred, noise-added image). Mixing them is a ≈3.7× error in the direction
# that flatters disagreement — Klaus Methods A.7 benchmarks it.
function _analyze_vortex_stripes(psi, grid, atom, params, ws_prev)
    n_pts = grid.config.n_points
    length(n_pts) == 3 || throw(ArgumentError("vortex_stripes requires a 3D grid"))
    # Column density along z, summed over whatever spinor components exist.
    col = zeros(Float64, n_pts[1], n_pts[2])
    dz = grid.dx[3]
    @inbounds for c in axes(psi, 4), k in 1:n_pts[3], j in 1:n_pts[2], i in 1:n_pts[1]
        col[i, j] += abs2(psi[i, j, k, c]) * dz
    end

    σ_px = Float64(get(params, "sigma_px", 5.0))
    res, mask = residual_image(col; sigma_px=σ_px,
        mask_threshold=Float64(get(params, "mask_threshold", 0.1)))
    holes = detect_density_holes(res, mask;
        contrast_threshold=Float64(get(params, "contrast_threshold", -0.11)),
        min_distance=Float64(get(params, "min_distance", 5.0)))

    kx, ky, mag = stripe_spectrum(res, grid.dx[1], grid.dx[2])
    k_lo = Float64(get(params, "k_lo", 0.0))
    k_hi = Float64(get(params, "k_hi", 0.0))
    (k_lo > 0 && k_hi > k_lo) || throw(
        ArgumentError(
            "vortex_stripes requires an explicit k_lo < k_hi annulus. An annulus " *
            "chosen after seeing the spectrum is not a measurement — put it in the " *
            "config before launch."),
    )
    m = stripe_metrics(kx, ky, mag; k_lo=k_lo, k_hi=k_hi,
        n_angle=Int(get(params, "n_angle", 180)))
    (
        n_holes=length(holes),
        hole_positions=holes,
        stripe_angle=m.angle,
        axis_order=m.axis_order,
        axis_order_null=m.axis_order_null,
        k_peak=m.k_peak,
        k_mode=m.k_mode,
        radial_prominence=m.radial_prominence,
        angular_profile=m.angular_profile,
        sigma_px=σ_px, k_lo=k_lo, k_hi=k_hi,
    )
end

function _analyze_non_abelian_homotopy(psi, grid, atom, params, ws_prev)
    ndim = length(grid.config.n_points)
    ndim >= 2 || throw(ArgumentError("non_abelian_homotopy requires N >= 2"))
    loop_pts_raw = get(params, "loop_pts", nothing)
    loop_pts_raw === nothing && throw(ArgumentError(
        "non_abelian_homotopy requires loop_pts: [[i,j(,k)], ...]"))
    loop_pts = if ndim == 2
        NTuple{2, Int}[(Int(p[1]), Int(p[2])) for p in loop_pts_raw]
    else
        NTuple{3, Int}[(Int(p[1]), Int(p[2]), Int(p[3])) for p in loop_pts_raw]
    end
    component = let v = get(params, "component", nothing)
        v === nothing ? nothing : Int(v)
    end
    holonomy = non_abelian_holonomy(psi, grid, loop_pts; component=component)
    winding = round(Int, angle(holonomy) / (2π))
    (holonomy=holonomy, phase=angle(holonomy),
        winding=winding, loop_length=length(loop_pts))
end

function _analyze_monopole_charge(psi, grid, atom, params, ws_prev)
    ndim = length(grid.config.n_points)
    ndim == 3 || throw(ArgumentError("monopole_charge requires 3D grid"))
    smooth = Bool(get(params, "smooth", false))
    q_field = monopole_charge_3d(psi, grid; smooth=smooth)
    total_charge = total_monopole_charge(q_field, grid)
    (monopole_charge_density=q_field,
        total_charge=total_charge,
        max_abs_density=maximum(abs, q_field))
end

function _analyze_winding_field(psi, grid, atom, params, ws_prev)
    ndim = length(grid.config.n_points)
    ndim >= 2 || throw(ArgumentError("winding_field requires N >= 2"))
    component = let v = get(params, "component", nothing)
        v === nothing ? nothing : Int(v)
    end
    threshold = Float64(get(params, "threshold", 1e-6))
    w = winding_number_field(psi, grid; component=component, threshold=threshold)
    (winding_field=w,
        total_winding=sum(w),
        max_abs_winding=maximum(abs, w))
end
