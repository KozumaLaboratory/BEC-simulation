# Klaus 2022 GS shape diagnostic
# Run after klaus2022_full completes — inspects:
#   - GS column density (frame 1) shape: xy disk vs xz thin (pancake check)
#   - mid-Step-4 frames for rotation signature
#
# Reads:
#   - runs/klaus2022_full/frames/columns.jld2 (multi_step output, 219 frames)
#   - runs/klaus2022_full/point_001.jld2 (full ψ for xz reconstruction)
#
# Outputs metrics to stdout for human inspection.

using JLD2

const RUN_DIR = "runs/klaus2022_full"

function summarize_2d(arr::AbstractArray; label="")
    n_total = sum(arr)
    n_total <= 0 && return "  $label: empty"
    nx, ny = size(arr)
    cx, cy = (nx + 1) ÷ 2, (ny + 1) ÷ 2

    threshold = 0.05 * maximum(arr)
    extent_x = (count(c -> any(@view arr[:, c]) .> threshold) > 0) ?
        let cols = [c for c in 1:ny if any(arr[:, c] .> threshold)]
            (last(cols) - first(cols) + 1) / ny
        end : 0.0
    extent_y = let rows = [r for r in 1:nx if any(arr[r, :] .> threshold)]
        isempty(rows) ? 0.0 : (last(rows) - first(rows) + 1) / nx
    end

    edge_density_x = sum(arr[1, :]) + sum(arr[end, :])
    edge_density_y = sum(arr[:, 1]) + sum(arr[:, end])
    edge_frac = (edge_density_x + edge_density_y) / max(n_total, 1e-30)

    moment_x = sum((1:nx)' .* arr) / n_total - cx
    moment_y = sum((1:ny) .* arr) / n_total - cy
    var_x = sum(((1:nx) .- cx) .^ 2 .* sum(arr; dims=2)) / n_total
    var_y = sum(((1:ny) .- cy) .^ 2 .* sum(arr; dims=1)') / n_total
    aspect = sqrt(var_x / max(var_y, 1e-30))

    "  $label: peak=$(round(maximum(arr); sigdigits=3)) " *
    "extent_xy=$(round(extent_x; digits=2))×$(round(extent_y; digits=2)) " *
    "rms_aspect=$(round(aspect; digits=2)) " *
    "edge_frac=$(round(edge_frac * 100; digits=2))%" *
    " com=($(round(moment_x; digits=2)),$(round(moment_y; digits=2)))"
end

function inspect_columns(path)
    println("== column_density_movie output ($path) ==")
    f = jldopen(path, "r")
    n = Int(f["n_frames"])
    println("  n_frames = $n  axis = $(f["axis"])")

    # GS frame
    gs = f["frame_00001"]
    println("  GS (frame 1, t=0):")
    println(summarize_2d(gs; label="    xy column density"))

    # End of Step 2 (tilt done): around frame 32
    if n >= 32
        f32 = f["frame_00032"]
        println("  end of Step 2 tilt (frame 32, t≈6.28):")
        println(summarize_2d(f32; label="    xy column density"))
    end

    # End of Step 3 (chirp done): around frame 63
    if n >= 63
        f63 = f["frame_00063"]
        println("  end of Step 3 chirp (frame 63, t≈22):")
        println(summarize_2d(f63; label="    xy column density"))
    end

    # Mid Step 4 (steady stir): frame 100, 150, last
    for k in [100, 150, n]
        if 1 <= k <= n
            fk = f[lpad("frame_$(k)", 11, "0")]
            ks = lpad(string(k), 5, '0')
            fk = f["frame_$ks"]
            println("  Step 4 frame $k:")
            println(summarize_2d(fk; label="    xy column density"))
        end
    end
    close(f)
end

function inspect_xz_from_psi(path)
    println()
    println("== xz cross-section from full ψ ($path) ==")
    f = jldopen(path, "r")
    if !haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
        println("  no streamed psi snapshots")
        close(f)
        return
    end
    n = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
    n_pts = Int.(f["dynamics/psi_snapshots_streamed/spatial_shape"])
    D = Int(f["dynamics/psi_snapshots_streamed/n_components"])
    println("  n_streamed = $n   spatial = $n_pts   D = $D")

    psi1 = f["dynamics/psi_snapshots_streamed/frame_00001"]
    # ψ shape (nx, ny, nz, D); collapse y → xz density
    nx, ny, nz, _ = size(psi1)
    cy = (ny + 1) ÷ 2
    xz = zeros(Float32, nx, nz)
    for c in 1:D
        for ix in 1:nx, iz in 1:nz
            xz[ix, iz] += abs2(psi1[ix, cy, iz, c])
        end
    end
    println("  GS xz slice (y=center, summed over components):")
    println(summarize_2d(xz; label="    xz density"))
    nx_used = count(any(xz[r, :] .> 0.05 * maximum(xz)) for r in 1:nx)
    nz_used = count(any(xz[:, c] .> 0.05 * maximum(xz)) for c in 1:nz)
    println("    → x extent = $nx_used / $nx ($(round(nx_used/nx*100; digits=1))%)")
    println("    → z extent = $nz_used / $nz ($(round(nz_used/nz*100; digits=1))%)")
    println("    pancake check: x/z extent ratio = $(round(nx_used/max(nz_used,1); digits=2))")
    println("    expected ratio if pancake [1,1,2.6] in TF: ≈ 2.6 / (5.3/2.0) ≈ 1.0")
    println("    expected if isotropic [1,1,1]: ≈ 1.0 (spherical)")
    println("    expected for self-bound DDI droplet: x ≪ z (cigar) → < 1")
    close(f)
end

inspect_columns(joinpath(RUN_DIR, "frames", "columns.jld2"))
inspect_xz_from_psi(joinpath(RUN_DIR, "point_001.jld2"))
