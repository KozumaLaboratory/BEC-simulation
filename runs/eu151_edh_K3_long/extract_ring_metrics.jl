# Extract azimuthally-averaged radial density profiles from result.jld2
# and compute per-frame ring metrics for the Matsui F1 central falsifier.
#
# For each saved frame i and component c in CHANNELS = (1, 2, 3, 4, 13):
#   1. Sum |psi[i,j,k,c]|^2 over z (cylindrical axis) -> 2D density n_2d(i,j).
#   2. Azimuthally bin (i,j) by r_ij = sqrt(x_i^2 + y_j^2) into n_radial_bins
#      bins of width dr = dx = box / n. Result: radial_profile[c, frame, bin].
#   3. Compute r=0-depth (peak off-axis vs r=0 bin density), FWHM annulus
#      aspect ratio (r_outer / r_inner at half off-axis-peak), and the
#      strict-AND ring criterion (depth > 20% AND aspect > 1.5).
#
# Outputs:
#   - spatial_profiles.csv (501 frames x 5 components = 2505 rows)
#   - ring_summary.json    (aggregate verdict + max-stats + bands)
#
# Grid convention (src/foundation/grid.jl):
#   x[i] = (i - (n+1)/2) * dx,  dx = box / n.  For n=32, box=20 -> dx=0.625.
#   Center of box is between indices 16 and 17.
#
# Time conversion: t_ms = t_dimless * 1000 / omega_ref, omega_ref = 691.15 rad/s.

using SpinorBEC   # loads CodecZstd compressor in correct world age
using JLD2
using CodecZstd
using Printf
using Statistics
using JSON

const RUN_DIR = @__DIR__
const RESULT = joinpath(RUN_DIR, "result.jld2")
const CSV_OUT = joinpath(RUN_DIR, "spatial_profiles.csv")
const JSON_OUT = joinpath(RUN_DIR, "ring_summary.json")

# Physical constants from config.yaml
const OMEGA_REF_HZ = 691.15           # rad/s, = 2*pi*110 Hz
const BOX = 20.0                       # a_ho
const NX = 32
const DX = BOX / NX                    # 0.625 a_ho
const N_RADIAL_BINS = 16
const CHANNELS = (1, 2, 3, 4, 13)      # m = +6, +5, +4, +3, -6

# F1 falsifier bands (from director.md turn_108 + state.json lines 1673-1677)
const TAU_EDH_EXP_MS = 5.0
const F1_BAND_CORROBORATE_MS = (0.5 * TAU_EDH_EXP_MS, 2.0 * TAU_EDH_EXP_MS)   # [2.5, 10.0]
const F1_BAND_INCONCLUSIVE_MS = (0.2 * TAU_EDH_EXP_MS, 5.0 * TAU_EDH_EXP_MS)  # [1.0, 25.0]
const F1_BAND_REFUTE_THRESHOLD_MS = 10.0 * TAU_EDH_EXP_MS                    # 50.0

# Ring detection thresholds
const RING_DEPTH_PCT_THRESHOLD = 20.0
const RING_ASPECT_THRESHOLD = 1.5

t_dimless_to_ms(t) = t * 1000.0 / OMEGA_REF_HZ
c_to_m(c::Int) = 7 - c                 # c=1 -> m=+6, c=13 -> m=-6

# Cell-center coordinates following src/foundation/grid.jl
function axis_coords(n::Int, dx::Float64)
    [(i - (n + 1) / 2) * dx for i in 1:n]
end

# Compute radial profile for one (psi, c). psi is (nx, ny, nz, nc) ComplexF32.
function azimuthal_radial_profile(psi::AbstractArray{ComplexF32, 4},
                                  c::Int,
                                  x_coords::Vector{Float64},
                                  dr::Float64,
                                  n_bins::Int)
    nx, ny, nz, _ = size(psi)
    sum_per_bin = zeros(Float64, n_bins)
    count_per_bin = zeros(Int, n_bins)
    @inbounds for j in 1:ny, i in 1:nx
        r = sqrt(x_coords[i]^2 + x_coords[j]^2)
        bin = clamp(floor(Int, r / dr) + 1, 1, n_bins)
        s = 0.0
        for k in 1:nz
            s += abs2(psi[i, j, k, c])
        end
        n_2d_ij = s * dr            # dz = dr (isotropic grid spacing)
        sum_per_bin[bin] += n_2d_ij
        count_per_bin[bin] += 1
    end
    profile = zeros(Float64, n_bins)
    @inbounds for b in 1:n_bins
        profile[b] = count_per_bin[b] > 0 ? sum_per_bin[b] / count_per_bin[b] : 0.0
    end
    profile
end

# Per-frame ring metrics from a radial profile.
function ring_metrics(profile::Vector{Float64}, dr::Float64)
    n0 = profile[1]
    rest = @view profile[2:end]
    n_max_off_axis = maximum(rest)
    k_max = argmax(rest) + 1                  # absolute index into profile
    depth_pct = n_max_off_axis > 0 ?
                100.0 * (n_max_off_axis - n0) / n_max_off_axis : 0.0

    # FWHM annulus: smallest and largest r where profile >= 0.5 * n_max_off_axis.
    # Search across full radial range (bin 1 = r=0).
    half = 0.5 * n_max_off_axis
    inner_bin = 0
    outer_bin = 0
    if n_max_off_axis > 0
        for b in 1:length(profile)
            if profile[b] >= half
                inner_bin == 0 && (inner_bin = b)
                outer_bin = b
            end
        end
    end
    # Bin-center radial coordinate: r(b) = (b - 0.5) * dr
    r_inner = inner_bin > 0 ? (inner_bin - 0.5) * dr : NaN
    r_outer = outer_bin > 0 ? (outer_bin - 0.5) * dr : NaN
    aspect = if !isnan(r_inner) && !isnan(r_outer) && r_inner > 0
        r_outer / r_inner
    else
        1.0
    end

    ring_present = (depth_pct > RING_DEPTH_PCT_THRESHOLD) &&
                   (aspect > RING_ASPECT_THRESHOLD)
    (; n0, n_max_off_axis, depth_pct, r_inner, r_outer, aspect, ring_present)
end

function extract()
    println("[ring] reading $RESULT")
    t_start = time()
    x_coords = axis_coords(NX, DX)
    println("[ring] x_coords[1]=$(x_coords[1])  x_coords[16]=$(x_coords[16])  x_coords[17]=$(x_coords[17])  x_coords[end]=$(x_coords[end])")
    println("[ring] dr=$(DX) a_ho, n_bins=$(N_RADIAL_BINS), channels=$(CHANNELS)")

    # Track first ring per component
    rows = Vector{NTuple{12, Any}}()
    n_frames_processed = 0
    n_frames_unreadable = 0
    t_ring_first_ms = nothing
    c_ring_first = nothing
    max_depth = -Inf
    arg_max_depth = nothing
    max_aspect = -Inf
    arg_max_aspect = nothing

    jldopen(RESULT, "r") do f
        times = f["dynamics/times"]
        snap_grp = f["dynamics/psi_snapshots_streamed"]
        n_frames = length(times)
        println("[ring] $n_frames frames in dynamics/times")

        for i in 1:n_frames
            key = @sprintf("frame_%05d", i)
            if !haskey(snap_grp, key)
                n_frames_unreadable += 1
                for c in CHANNELS
                    push!(rows, (i, Float64(times[i]), t_dimless_to_ms(times[i]),
                                 c, c_to_m(c),
                                 NaN, NaN, false, NaN, NaN, NaN, NaN))
                end
                continue
            end
            psi = try
                snap_grp[key]
            catch err
                println("[ring] frame $i ($key) read error: $err")
                n_frames_unreadable += 1
                for c in CHANNELS
                    push!(rows, (i, Float64(times[i]), t_dimless_to_ms(times[i]),
                                 c, c_to_m(c),
                                 NaN, NaN, false, NaN, NaN, NaN, NaN))
                end
                continue
            end
            n_frames_processed += 1
            t_d = Float64(times[i])
            t_ms = t_dimless_to_ms(t_d)
            for c in CHANNELS
                profile = azimuthal_radial_profile(psi, c, x_coords, DX, N_RADIAL_BINS)
                m = ring_metrics(profile, DX)
                push!(rows, (i, t_d, t_ms, c, c_to_m(c),
                             m.depth_pct, m.aspect, m.ring_present,
                             m.n0, m.n_max_off_axis, m.r_inner, m.r_outer))
                if m.depth_pct > max_depth
                    max_depth = m.depth_pct
                    arg_max_depth = (i, t_ms, c, c_to_m(c))
                end
                if m.aspect > max_aspect
                    max_aspect = m.aspect
                    arg_max_aspect = (i, t_ms, c, c_to_m(c))
                end
                if m.ring_present && t_ring_first_ms === nothing
                    t_ring_first_ms = t_ms
                    c_ring_first = c
                end
            end
            if i % 50 == 0
                println("[ring]  frame $i / $n_frames t_ms=$(@sprintf("%.3f", t_ms))")
            end
        end
    end

    # Write CSV
    open(CSV_OUT, "w") do io
        println(io, "frame,t_dimless,t_ms,c,m,depth_pct,aspect,ring_present,n0,n_max_off_axis,r_inner,r_outer")
        for r in rows
            (frame, t_d, t_ms, c, m, depth_pct, aspect, ring_present, n0, nmax, ri, ro) = r
            println(io, join((
                string(frame),
                @sprintf("%.6e", t_d),
                @sprintf("%.6f", t_ms),
                string(c),
                string(m),
                isnan(depth_pct) ? "NaN" : @sprintf("%.4f", depth_pct),
                isnan(aspect) ? "NaN" : @sprintf("%.4f", aspect),
                ring_present ? "true" : "false",
                isnan(n0) ? "NaN" : @sprintf("%.6e", n0),
                isnan(nmax) ? "NaN" : @sprintf("%.6e", nmax),
                isnan(ri) ? "NaN" : @sprintf("%.4f", ri),
                isnan(ro) ? "NaN" : @sprintf("%.4f", ro),
            ), ","))
        end
    end
    println("[ring] wrote $CSV_OUT ($(length(rows)) rows)")

    # Build JSON summary
    in_corroborate = t_ring_first_ms === nothing ? nothing :
        (F1_BAND_CORROBORATE_MS[1] <= t_ring_first_ms <= F1_BAND_CORROBORATE_MS[2])
    in_inconclusive = t_ring_first_ms === nothing ? nothing :
        (F1_BAND_INCONCLUSIVE_MS[1] <= t_ring_first_ms <= F1_BAND_INCONCLUSIVE_MS[2])

    summary = Dict(
        "n_frames_total" => 501,
        "n_frames_processed" => n_frames_processed,
        "n_frames_unreadable" => n_frames_unreadable,
        "n_components_audited" => length(CHANNELS),
        "tau_edh_exp_ms" => TAU_EDH_EXP_MS,
        "f1_band_corroborate_ms" => collect(F1_BAND_CORROBORATE_MS),
        "f1_band_inconclusive_ms" => collect(F1_BAND_INCONCLUSIVE_MS),
        "f1_band_refute_threshold_ms" => F1_BAND_REFUTE_THRESHOLD_MS,
        "ring_present_any_frame_any_c" => (t_ring_first_ms !== nothing),
        "t_ring_first_ms" => t_ring_first_ms,
        "c_ring_first" => c_ring_first,
        "m_ring_first" => c_ring_first === nothing ? nothing : c_to_m(c_ring_first),
        "t_ring_first_in_corroborate_band" => in_corroborate,
        "t_ring_first_in_inconclusive_band" => in_inconclusive,
        "max_depth_pct_observed" => max_depth,
        "max_aspect_observed" => max_aspect,
        "arg_max_depth_pct" => arg_max_depth === nothing ? nothing : Dict(
            "frame" => arg_max_depth[1],
            "t_ms" => arg_max_depth[2],
            "c" => arg_max_depth[3],
            "m" => arg_max_depth[4],
        ),
        "arg_max_aspect" => arg_max_aspect === nothing ? nothing : Dict(
            "frame" => arg_max_aspect[1],
            "t_ms" => arg_max_aspect[2],
            "c" => arg_max_aspect[3],
            "m" => arg_max_aspect[4],
        ),
        "metadata" => Dict(
            "script_version" => 1,
            "jld2_path" => "runs/eu151_edh_K3_long/result.jld2",
            "n_radial_bins" => N_RADIAL_BINS,
            "dr_a_ho" => DX,
            "channels" => collect(CHANNELS),
            "ring_depth_pct_threshold" => RING_DEPTH_PCT_THRESHOLD,
            "ring_aspect_threshold" => RING_ASPECT_THRESHOLD,
            "omega_ref_rad_per_s" => OMEGA_REF_HZ,
        ),
    )

    open(JSON_OUT, "w") do io
        JSON.print(io, summary, 2)
    end
    elapsed = time() - t_start
    println("[ring] wrote $JSON_OUT")
    println("[ring] elapsed_sec=$(round(elapsed, digits=2))")
    println("[ring] ring_present_any_frame_any_c=$(t_ring_first_ms !== nothing)")
    println("[ring] t_ring_first_ms=$(t_ring_first_ms)")
    println("[ring] max_depth_pct_observed=$(max_depth) at $(arg_max_depth)")
    println("[ring] max_aspect_observed=$(max_aspect) at $(arg_max_aspect)")
end

extract()
