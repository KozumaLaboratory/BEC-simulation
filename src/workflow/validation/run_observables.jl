# --- Snapshot-trajectory observables + collapse classifier ---
#
# Primitives for the post-run analysis path that the deleted
# scripts/validation/*_summary.jl files used to provide:
#   * locate the runs/<base>_<hash>/ output dir for a given YAML
#   * iterate streamed psi snapshots across multi-stage dynamics
#   * peak density / spin-population trajectories
#   * 5-category collapse classifier
#
# Everything here is REPL-callable. The old summary scripts now reduce
# to a few lines of REPL composition.

using JLD2
using ..SpinorBEC: total_density

export find_run_dir, psi_snapshots,
    peak_density_trajectory, spin_populations, spin_populations_trajectory,
    classify_collapse

"""
    find_run_dir(yaml_path; runs_root=nothing) -> Union{String, Nothing}

For a YAML produced by `sweep(...)` (or any older generator), locate the
matching `runs/<base>_<hash>/` output directory. Selects the most
recent matching dir whose mtime exceeds the YAML's — so stale runs from
sibling factorials with the same basename don't masquerade as the result.

`runs_root` defaults to the directory two levels above the YAML
(`runs/<batch>/foo.yaml` → `runs/`).
"""
function find_run_dir(yaml_path::AbstractString; runs_root::Union{Nothing, AbstractString}=nothing)
    runs_root === nothing && (runs_root = dirname(dirname(yaml_path)))
    isdir(runs_root) || return nothing
    base = splitext(basename(yaml_path))[1]
    ymtime = mtime(yaml_path)
    re = Regex("^" * base * "_[0-9a-f]+\$")
    candidates = String[]
    for d in readdir(runs_root; join=true)
        isdir(d) || continue
        occursin(re, basename(d)) || continue
        isfile(joinpath(d, "result.jld2")) || continue
        mtime(d) > ymtime || continue
        push!(candidates, d)
    end
    isempty(candidates) && return nothing
    sort!(candidates; by=d -> mtime(d))
    last(candidates)
end

"""
    spin_populations(psi) -> Vector{Float64}

Sum `|psi|^2` over space per spin component. Works for any psi whose
last dimension is the spin index (typical layouts are `psi[x,y,c]` or
`psi[x,y,z,c]`). Returns a length-`size(psi, ndims(psi))` Float64 vector.
"""
function spin_populations(psi::AbstractArray{<:Complex})
    D = size(psi, ndims(psi))
    Nm = zeros(Float64, D)
    for c in 1:D
        Nm[c] = Float64(sum(abs2, selectdim(psi, ndims(psi), c)))
    end
    Nm
end

"""
    psi_snapshots(jld2_path; group_prefix="dynamics") -> Vector

Read every streamed psi snapshot from `jld2_path`. Handles single-stage
output (`dynamics/psi_snapshots_streamed`) and multi-stage protocols
(`dynamics/...` + `dynamics_2/...` + ...). Returns the snapshots in
group-name order then frame order.

The caller is responsible for matching `times` arrays if needed — they
live under `<group>/times` in the same file.
"""
function psi_snapshots(jld2_path::AbstractString; group_prefix::AbstractString="dynamics")
    jldopen(jld2_path, "r") do f
        groups = String[]
        for k in keys(f)
            startswith(k, group_prefix) || continue
            haskey(f[k], "psi_snapshots_streamed") || continue
            push!(groups, "$k/psi_snapshots_streamed")
        end
        sort!(groups)
        out = Any[]
        for g_path in groups
            g = f[g_path]
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            for fr in frames
                push!(out, g[fr])
            end
        end
        out
    end
end

"""
    peak_density_trajectory(jld2_path; group_prefix="dynamics") -> Vector{Float64}

Per-frame `maximum(total_density(psi))` over the streamed snapshots.
"""
function peak_density_trajectory(
    jld2_path::AbstractString; group_prefix::AbstractString="dynamics"
)
    [
        Float64(maximum(total_density(psi, ndims(psi) - 1)))
        for psi in psi_snapshots(jld2_path; group_prefix)
    ]
end

"""
    spin_populations_trajectory(jld2_path; group_prefix="dynamics") -> Vector{Vector{Float64}}

Per-frame spin-population vector. Each element is a length-D vector
(D = `size(psi, ndims(psi))`).
"""
function spin_populations_trajectory(
    jld2_path::AbstractString; group_prefix::AbstractString="dynamics"
)
    [spin_populations(psi) for psi in psi_snapshots(jld2_path; group_prefix)]
end

"""
    classify_collapse(peaks, N_final_ratio) -> Symbol

5-category collapse classifier — the convention used across the old
eu_k3_sweep / eu_k3_arrest / eu_k3_lhy summary scripts.

  :collapse           — peak doubled AND still growing at the final frame
  :delay              — peak doubled but crested + dropped before end
  :marginal_arrest    — never doubled, peak still growing
  :sacrificial_arrest — never doubled, crested + dropped, N(T)/N(0) < 0.5
  :stable_arrest      — never doubled, crested + dropped, N(T)/N(0) ≥ 0.5
"""
function classify_collapse(peaks::AbstractVector{<:Real}, N_final_ratio::Real)
    isempty(peaks) && throw(ArgumentError("classify_collapse: empty peaks"))
    peak0 = peaks[1]
    idx_max = argmax(peaks)
    idx_2x = findfirst(p -> p > 2 * peak0, peaks)
    peak_growing_at_end = idx_max == length(peaks)
    if idx_2x !== nothing
        return peak_growing_at_end ? :collapse : :delay
    end
    peak_growing_at_end && return :marginal_arrest
    N_final_ratio < 0.5 ? :sacrificial_arrest : :stable_arrest
end
