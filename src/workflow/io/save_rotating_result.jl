"""
Canonical save layout for `kind: rotating_basis` (Option γ) dynamics
results.

Writes to `<run_dir>/result.jld2` in the streamed snapshot layout that
the dashboard's `dynamics/psi_snapshots_streamed/...` reader path
expects, plus a `point_001.jld2` symlink so the run shows up in the
dashboard's run list.

The canonical layout:
    psi                                          # GS / first snapshot (4D)
    dynamics/times                               # Vector{Float64}
    dynamics/norms                               # Vector{Float64}
    dynamics/Lz                                  # Vector{Float64}
    dynamics/Fz                                  # Vector{Float64}
    dynamics/Fx, dynamics/Fy                     # optional Vector{Float64}
    dynamics/per_m_history                       # Matrix (D × T)
    dynamics/component_populations               # Matrix (T × D), normalised
    dynamics/psi_snapshots_streamed/n_snapshots
    dynamics/psi_snapshots_streamed/spatial_shape
    dynamics/psi_snapshots_streamed/n_components
    dynamics/psi_snapshots_streamed/frame_00001  # ComplexF32 4D
    dynamics/psi_snapshots_streamed/frame_00002
    ...
    dynamics/integrator_meta/dt_used             # ε / dt / Larmor info
    dynamics/integrator_meta/integrator
    dynamics/integrator_meta/epsilon_target
    dynamics/integrator_meta/p_zeeman
    dynamics/integrator_meta/F_atom
    dynamics/integrator_meta/larmor_phase_per_step

Use this from any per-run launcher that consumes the `:rotating_basis_dynamics`
Dict produced by `run_config`. The legacy
`launch_thesis_run.jl` / `launch_phi_omega_run.jl` saved a Vector of
4D arrays at the top level; that layout still works in the dashboard
via the legacy fallback, but new code should write canonical here.
"""
function save_rotating_basis_result!(
    run_dir::String, result::AbstractDict;
    snapshot_precision::Symbol=:f32,
)
    haskey(result, :rotating_basis_dynamics) || throw(
        ArgumentError(
            "save_rotating_basis_result!: result has no :rotating_basis_dynamics key " *
            "(was the pipeline using `kind: rotating_basis`?)"),
    )
    dyn = result[:rotating_basis_dynamics]::AbstractDict

    isdir(run_dir) || mkpath(run_dir)
    out_path = joinpath(run_dir, "result.jld2")

    snaps = get(dyn, :psi_snapshots, Any[])
    n_snaps = length(snaps)
    pm_hist = get(dyn, :per_m_history, Any[])
    pm_mat = isempty(pm_hist) ? zeros(Float64, 0, 0) : hcat(pm_hist...)

    # Convert snapshot precision once up front.
    snap_eltype = snapshot_precision === :f64 ? ComplexF64 : ComplexF32

    JLD2.jldopen(out_path, "w") do f
        # GS (or first snapshot) for the dashboard's volume renderer entry point.
        if n_snaps >= 1
            f["psi"] = Array{ComplexF64}(snaps[1])
        end

        f["dynamics/times"] = collect(Float64, dyn[:times])
        f["dynamics/norms"] = collect(Float64, dyn[:norms])
        f["dynamics/Lz"] = collect(Float64, dyn[:Lz])
        f["dynamics/Fz"] = collect(Float64, dyn[:Fz])
        haskey(dyn, :Fx) && (f["dynamics/Fx"] = collect(Float64, dyn[:Fx]))
        haskey(dyn, :Fy) && (f["dynamics/Fy"] = collect(Float64, dyn[:Fy]))
        if !isempty(pm_mat)
            f["dynamics/per_m_history"] = pm_mat
        end

        # Per-frame populations (rows = time, cols = m component) for the
        # dashboard's spinor-population time-series tab.
        if n_snaps >= 1
            psi1 = snaps[1]
            D = size(psi1)[end]
            ndim = ndims(psi1) - 1
            n_pts = ntuple(d -> size(psi1, d), ndim)
            pops = zeros(Float64, n_snaps, D)
            for (s, psi) in enumerate(snaps)
                total = sum(abs2, psi)
                for c in 1:D
                    idx = ntuple(d -> d <= ndim ? Colon() : c, ndim + 1)
                    pops[s, c] = sum(abs2, view(psi, idx...)) / max(total, 1e-30)
                end
            end
            f["dynamics/component_populations"] = pops

            # Streamed snapshot layout (one HDF5 dataset per frame).
            f["dynamics/psi_snapshots_streamed/n_snapshots"] = n_snaps
            f["dynamics/psi_snapshots_streamed/spatial_shape"] = collect(Int, n_pts)
            f["dynamics/psi_snapshots_streamed/n_components"] = D
            for (s, psi) in enumerate(snaps)
                key = "dynamics/psi_snapshots_streamed/frame_" *
                      lpad(string(s), 5, '0')
                f[key] = Array{snap_eltype}(psi)
            end
        end

        # Integrator metadata (added 2026-04-28 audit) — preserved if present.
        for (src_key, dst_key) in (
            (:dt_used, "dt_used"),
            (:integrator, "integrator"),
            (:epsilon_target, "epsilon_target"),
            (:p_zeeman, "p_zeeman"),
            (:F_atom, "F_atom"),
            (:larmor_phase_per_step, "larmor_phase_per_step"),
            (:theta_const, "theta_const"),
            (:phi_omega, "phi_omega"),
        )
            haskey(dyn, src_key) && (f["dynamics/integrator_meta/" * dst_key] = dyn[src_key])
        end
    end

    # Dashboard's run-list filter requires a `point_NNN.jld2` file. Symlink
    # to the canonical result so we don't duplicate the multi-GB snapshot data.
    point_link = joinpath(run_dir, "point_001.jld2")
    islink(point_link) && rm(point_link)
    isfile(point_link) && rm(point_link)
    symlink("result.jld2", point_link)

    out_path
end
