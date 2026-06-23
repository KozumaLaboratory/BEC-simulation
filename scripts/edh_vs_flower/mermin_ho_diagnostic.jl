# scripts/edh_vs_flower/mermin_ho_diagnostic.jl
# ============================================================================
# Post-hoc Mermin–Ho / EdH-vs-Flower diagnostic from streamed full-ψ frames.
#
# Reads the full 13-component ψ snapshots saved by the pipeline
# (`<stage>/psi_snapshots_streamed/frame_NNNNN`, written when a dynamics stage
# has `save: {psi: true}`), rebuilds a minimal Grid + FFT plans + spin
# matrices, and for every frame computes — using ONLY audited analysis
# routines (src/analysis/{currents,vorticity,topology}.jl) — the diagnostics
# derived in docs/research_notes/edh_vs_flower_theory.md:
#
#   ε_z(r,t) = (∇×v_s)_z − F·Ω_z        Mermin–Ho residual (internal units)
#   Ω_z(r,t)                             Berry curvature (texture solid-angle)
#   ω_z(r,t) = (∇×v_s)_z                 superfluid vorticity
#   |j|(r,t)                             mass-current magnitude
#   Q_sk(t)  = ∫_midplane Ω_z dA / 4π    skyrmion charge (z-midplane)
#   Q_3D(t)  = ∫ monopole-charge density hedgehog charge
#   ⟨F⟩(t)   = (⟨Fx⟩,⟨Fy⟩,⟨Fz⟩)         spin precession (volume-integrated)
#   n_max(t), N(t), max|j|(t), max|ε|(t), density-weighted mean|ε|(t)
#
# Saves z-midplane 2-D maps per frame + scalar time-series to an HDF5 file
# (HDF5.jl so Python/h5py can read it; the INPUT is JLD2).
#
# Usage:
#   julia --project=. scripts/edh_vs_flower/mermin_ho_diagnostic.jl \
#       <result.jld2> <out_analysis.h5> [--F 6] [--n 64] [--box 20] \
#       [--cutoff 1e-10] [--dump]
#
#   --dump : print the JLD2 group tree and exit (structure discovery aid).
#
# Both EdH and Flower runs are processed by invoking this script on each
# run's result.jld2 separately; the figure script overlays the two outputs.
# ============================================================================

using SpinorBEC
using SpinorBEC: GridConfig, make_grid, make_fft_plans, SpinSystem, spin_matrices,
                 superfluid_velocity, superfluid_vorticity, berry_curvature,
                 probability_current, spin_density_vector, monopole_charge_3d,
                 total_monopole_charge, cell_volume
using JLD2, LinearAlgebra, FFTW, Printf
# Output is written with JLD2 (a project dep; HDF5.jl is NOT a dep on main).
# JLD2 files of plain numeric arrays are readable by Python h5py — the figure
# script reads them directly (with the usual column-major axis reversal).

# ── JLD2 tree walking: find every psi_snapshots_streamed group ──────────────
# Returns Vector of (group_path, sorted_frame_keys). Robust to multi-stage
# pipelines where each dynamics phase has its own group (dynamics, dynamics_2…).
function find_snapshot_groups(f)
    found = Tuple{String, Vector{String}}[]
    # Recurse strictly through JLD2 groups (scalar/array leaves are skipped).
    # Frames live at `<stage>/psi_snapshots_streamed/frame_NNNNN`; multi-stage
    # pipelines concatenate phases into one `dynamics` group, but deeper layouts
    # (dynamics/phase_N/…) are handled by the recursion.
    function walk(grp::JLD2.Group, path)
        ks = collect(keys(grp))
        if "psi_snapshots_streamed" in ks
            g = grp["psi_snapshots_streamed"]
            if g isa JLD2.Group
                frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
                !isempty(frames) && push!(found, (path * "/psi_snapshots_streamed", frames))
            end
        end
        for k in ks
            k == "psi_snapshots_streamed" && continue
            child = try grp[k] catch; nothing end
            child isa JLD2.Group && walk(child, isempty(path) ? k : path * "/" * k)
        end
    end
    for k in collect(keys(f))
        child = try f[k] catch; nothing end
        child isa JLD2.Group && walk(child, k)
    end
    found
end

# read a sibling `times` vector for a snapshot group, with the
# nframes+1 → drop-first convention used in experiment_observables.jl.
function stage_times(f, group_path, nframes)
    stage = replace(group_path, "/psi_snapshots_streamed" => "")
    for key in (stage * "/times", "dynamics/times", "times")
        if haskey(f, key)
            ts = Vector{Float64}(f[key])
            length(ts) == nframes + 1 && return ts[2:end]
            length(ts) == nframes && return ts
            length(ts) >= nframes && return ts[1:nframes]
        end
    end
    return collect(0.0:Float64(nframes - 1))   # fallback: frame index
end

# best-effort metadata read with CLI override
function read_meta(f)
    getk(keys_try, default) = begin
        for k in keys_try
            haskey(f, k) && return f[k]
        end
        default
    end
    n_pts = getk(["grid_n_points", "grid/n_points", "metadata/grid_n_points"], nothing)
    box   = getk(["grid_box_size", "grid/box_size", "metadata/grid_box_size"], nothing)
    Fval  = getk(["atom_F", "metadata/F", "F"], nothing)
    (n_pts, box, Fval)
end

# ── main diagnostic (callable from run_all.jl or the CLI wrapper) ───────────
function run_mermin_ho_diagnostic(RESULT_PATH::AbstractString, OUT_PATH::AbstractString;
        F_OVR::AbstractString="", N_OVR::AbstractString="",
        BOX_OVR::AbstractString="", CUTOFF::Float64=1e-10, DUMP::Bool=false)
jldopen(RESULT_PATH, "r") do f
    groups = find_snapshot_groups(f)

    if DUMP || isempty(groups)
        println("── JLD2 top-level keys of $RESULT_PATH ──")
        for k in sort(collect(keys(f)))
            println("  ", k)
        end
        println("── snapshot groups found ──")
        for (gp, fr) in groups
            println("  $gp  ($(length(fr)) frames)")
        end
        isempty(groups) && println("  (none — check save.psi=true and the group layout)")
        DUMP && return
        isempty(groups) && error("no psi_snapshots_streamed groups found")
    end

    # ---- resolve grid metadata (file → CLI override → first frame shape) ----
    n_meta, box_meta, F_meta = read_meta(f)
    # peek first frame to get spatial shape + D
    gp1, fr1 = groups[1]
    psi1 = f[gp1][fr1[1]]                       # (nx,ny,nz,D) ComplexF32
    spatial = size(psi1)[1:end-1]
    D = size(psi1)[end]
    Fval = !isempty(F_OVR) ? parse(Int, F_OVR) :
           (F_meta !== nothing ? Int(F_meta) : (D - 1) ÷ 2)
    n_pts = !isempty(N_OVR) ? ntuple(_ -> parse(Int, N_OVR), 3) : spatial
    boxL  = !isempty(BOX_OVR) ? parse(Float64, BOX_OVR) :
            (box_meta !== nothing ? Float64(box_meta[1]) : 20.0)
    box = ntuple(d -> boxL, length(spatial))

    @printf("[mh] result=%s\n[mh] frames=%d across %d stage(s)  grid=%s  D=%d  F=%d  box=%.3g\n",
        RESULT_PATH, sum(length(fr) for (_, fr) in groups), length(groups),
        string(spatial), D, Fval, boxL)

    # ---- rebuild minimal Grid + plans + spin matrices ----
    config = GridConfig(Tuple(spatial), box)
    grid   = make_grid(config)
    plans  = make_fft_plans(Tuple(spatial); flags=FFTW.ESTIMATE)
    sm     = spin_matrices(Fval)
    dV     = cell_volume(grid)
    zc     = spatial[3] ÷ 2 + 1                  # z-midplane index

    # ---- flatten frames across stages, with global time ----
    all_frames = Tuple{String, String, Float64}[]   # (group_path, frame_key, t)
    for (gp, fr) in groups
        ts = stage_times(f, gp, length(fr))
        for (i, fk) in enumerate(fr)
            push!(all_frames, (gp, fk, ts[i]))
        end
    end
    nf = length(all_frames)

    # ---- output buffers ----
    eps_mid   = zeros(Float32, nf, spatial[1], spatial[2])   # ε_z z-midplane
    berry_mid = zeros(Float32, nf, spatial[1], spatial[2])   # Ω_z z-midplane
    vort_mid  = zeros(Float32, nf, spatial[1], spatial[2])   # ω_z z-midplane
    jmag_mid  = zeros(Float32, nf, spatial[1], spatial[2])   # |j| z-midplane
    n_mid     = zeros(Float32, nf, spatial[1], spatial[2])   # density z-midplane
    fz_mid    = zeros(Float32, nf, spatial[1], spatial[2])   # ⟨Fz⟩ z-midplane

    t_arr      = zeros(Float64, nf)
    Q_sk       = zeros(Float64, nf)
    Q_3D       = zeros(Float64, nf)
    Fx_avg     = zeros(Float64, nf)
    Fy_avg     = zeros(Float64, nf)
    Fz_avg     = zeros(Float64, nf)
    n_max      = zeros(Float64, nf)
    N_tot      = zeros(Float64, nf)
    jmag_max   = zeros(Float64, nf)
    eps_absmax = zeros(Float64, nf)
    eps_wmean  = zeros(Float64, nf)              # density-weighted mean|ε_z|

    for (k, (gp, fk, t)) in enumerate(all_frames)
        psi = ComplexF64.(f[gp][fk])             # (nx,ny,nz,D), spinor last
        t_arr[k] = t

        # density + spin density
        fx, fy, fz = spin_density_vector(psi, sm, 3)
        dens = dropdims(sum(abs2, psi; dims=4); dims=4)   # (nx,ny,nz)

        # currents + Mermin–Ho both sides
        j   = probability_current(psi, grid, plans)
        ωz  = superfluid_vorticity(psi, grid, plans; density_cutoff=CUTOFF)[3]
        Ωz  = berry_curvature(psi, grid, plans, sm; density_cutoff=CUTOFF)[3]
        εz  = ωz .- Fval .* Ωz
        jmag = sqrt.(j[1].^2 .+ j[2].^2 .+ j[3].^2)

        # z-midplane maps
        eps_mid[k, :, :]   .= Float32.(@view εz[:, :, zc])
        berry_mid[k, :, :] .= Float32.(@view Ωz[:, :, zc])
        vort_mid[k, :, :]  .= Float32.(@view ωz[:, :, zc])
        jmag_mid[k, :, :]  .= Float32.(@view jmag[:, :, zc])
        n_mid[k, :, :]     .= Float32.(@view dens[:, :, zc])
        fz_mid[k, :, :]    .= Float32.(@view fz[:, :, zc])

        # skyrmion charge on the z-midplane: ∫ Ω_z dA / 4π
        dA = grid.dx[1] * grid.dx[2]
        Q_sk[k] = sum(@view Ωz[:, :, zc]) * dA / (4π)

        # hedgehog/monopole charge (3D, volume-integrated)
        qfield = monopole_charge_3d(psi, grid)
        Q_3D[k] = total_monopole_charge(qfield, grid)

        # volume-integrated spin (precession) + scalars
        Fx_avg[k] = sum(fx) * dV
        Fy_avg[k] = sum(fy) * dV
        Fz_avg[k] = sum(fz) * dV
        N_tot[k]    = sum(dens) * dV
        n_max[k]    = maximum(dens)
        jmag_max[k] = maximum(jmag)
        eps_absmax[k] = maximum(abs.(εz))
        wsum = sum(dens)
        eps_wmean[k] = wsum > 0 ? sum(abs.(εz) .* dens) / wsum : 0.0

        @printf("  frame %3d/%3d  t=%.4g  max|ε|=%.3e  wmean|ε|=%.3e  Q_sk=%+.3f  Q_3D=%+.3f  ⟨Fz⟩=%+.4g\n",
            k, nf, t, eps_absmax[k], eps_wmean[k], Q_sk[k], Q_3D[k], Fz_avg[k])
        flush(stdout)
    end

    # ---- write JLD2 output (h5py-readable) ----
    mkpath(dirname(abspath(OUT_PATH)))
    jldopen(OUT_PATH, "w") do o
        o["t"]          = t_arr
        o["F"]          = Fval
        o["box"]        = boxL
        o["z_mid_index"] = zc
        # 2-D midplane stacks (nf, nx, ny)
        o["eps_z_mid"]   = eps_mid
        o["berry_z_mid"] = berry_mid
        o["vort_z_mid"]  = vort_mid
        o["jmag_mid"]    = jmag_mid
        o["n_mid"]       = n_mid
        o["fz_mid"]      = fz_mid
        # scalar series
        o["Q_sk"]       = Q_sk
        o["Q_3D"]       = Q_3D
        o["Fx_avg"]     = Fx_avg
        o["Fy_avg"]     = Fy_avg
        o["Fz_avg"]     = Fz_avg
        o["n_max"]      = n_max
        o["N_tot"]      = N_tot
        o["jmag_max"]   = jmag_max
        o["eps_absmax"] = eps_absmax
        o["eps_wmean"]  = eps_wmean
    end
    @printf("[mh] wrote %s  (%d frames)\n", OUT_PATH, nf)
end  # jldopen
    return nothing
end  # run_mermin_ho_diagnostic

# ── CLI wrapper ─────────────────────────────────────────────────────────────
if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) >= 1 || error("usage: mermin_ho_diagnostic.jl <result.jld2> <out.h5> [--F 6] [--n N] [--box L] [--cutoff x] [--dump]")
    _result = ARGS[1]
    _out = (length(ARGS) >= 2 && !startswith(ARGS[2], "--")) ? ARGS[2] : "edh_diag.h5"
    _opt(flag, default) = begin
        i = findfirst(==(flag), ARGS)
        (i === nothing || i == length(ARGS)) ? default : ARGS[i + 1]
    end
    run_mermin_ho_diagnostic(_result, _out;
        F_OVR=_opt("--F", ""), N_OVR=_opt("--n", ""),
        BOX_OVR=_opt("--box", ""), CUTOFF=parse(Float64, _opt("--cutoff", "1e-10")),
        DUMP=("--dump" in ARGS))
end
