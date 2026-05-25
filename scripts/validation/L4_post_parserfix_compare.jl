# Compare L4_eu_matsui_hamiltonian_only_* results across the
# pre/post parser-fix Bz-ramp transition.
#
# Pre-fix (commit < e8584f4): Bz: {from: 0.01, to: 2.6e-5, duration: 0.0}
#   silently ramped linearly from 0.01 G to 2.6e-5 G over the full
#   dynamics window (6.28 ω_ref⁻¹). EdH transfer was suppressed
#   because Bz remained finite enough to constrain spin polarization.
#
# Post-fix (commit e8584f4+): same YAML now produces an instantaneous
#   quench Bz → 2.6e-5 G at t=0+, then constant. EdH dynamics runs
#   under the weak-field Hamiltonian for the whole window.
#
# This script:
#   * lists pre-fix vs post-fix run directories
#   * extracts ΔFz, ΔE, norm drift, simulation t-range
#   * tabulates side-by-side
#
# Output: prints a markdown-style table to stdout.

using CodecZstd
using JLD2
using Printf

struct L4Stats
    label::String
    n_grid::Int
    pre_post::Symbol         # :pre or :post
    found::Bool
    t_end::Float64
    n_frames::Int
    norm_drift::Float64
    E_initial::Float64
    E_drift::Float64
    Fz_initial::Float64
    Fz_final::Float64
end

function pickup_runs(prefix::String)
    candidates = filter(d -> startswith(d, prefix * "_"), readdir("runs"))
    sort!(candidates; by=d -> stat(joinpath("runs", d)).mtime)
    runs = []
    for c in candidates
        full = joinpath("runs", c)
        pf = joinpath(full, "point_001.jld2")
        isfile(pf) || continue
        push!(runs, (full, stat(full).mtime))
    end
    runs
end

function load_stats(label::String, n_grid::Int, dir::String, pre_post::Symbol)
    pf = joinpath(dir, "point_001.jld2")
    isfile(pf) || return L4Stats(label, n_grid, pre_post, false, NaN, 0, NaN, NaN, NaN, NaN, NaN)
    d = JLD2.load(pf)
    haskey(d, "dynamics/times") || return L4Stats(label, n_grid, pre_post, false, NaN, 0, NaN, NaN, NaN, NaN, NaN)
    times = d["dynamics/times"]
    norms = d["dynamics/norms"]
    energies = d["dynamics/energies"]
    Fz = d["dynamics/Fz"]
    n = length(times)
    L4Stats(
        label, n_grid, pre_post, true,
        times[end], n,
        maximum(abs.(norms .- norms[1])),
        energies[1], maximum(abs.(energies .- energies[1])),
        Fz[1], Fz[end],
    )
end

# Pre-fix runs are from before commit e8584f4 (today < ~21:18).
# Post-fix runs are from this session, after ~21:42 (when L4_32 was
# re-launched). Use mtime cutoff.
const POST_FIX_CUTOFF = stat("scripts/validation/L4_post_parserfix_compare.jl").mtime - 7200  # 2h grace

function classify_runs(prefix::String, n_grid::Int, label::String)
    runs = pickup_runs(prefix)
    stats = L4Stats[]
    for (dir, mtime) in runs
        pp = mtime >= POST_FIX_CUTOFF ? :post : :pre
        push!(stats, load_stats(label, n_grid, dir, pp))
    end
    stats
end

println("L4 EdH config re-run audit — parser-fix transition (commit e8584f4)")
println("=" ^ 80)

all_stats = L4Stats[]
for (prefix, grid) in [
    ("L4_eu_matsui_hamiltonian_only_32",  32),
    ("L4_eu_matsui_hamiltonian_only_48",  48),
    ("L4_eu_matsui_hamiltonian_only_64",  64),
    ("L4_eu_matsui_hamiltonian_only_96",  96),
    ("L4_eu_matsui_hamiltonian_only_128", 128),
    ("L4det_eu_matsui_hamiltonian_only_32",  32),
    ("L4det_eu_matsui_hamiltonian_only_48",  48),
    ("L4det_eu_matsui_hamiltonian_only_64",  64),
    ("L4det_eu_matsui_hamiltonian_only_96",  96),
]
    append!(all_stats, classify_runs(prefix, grid, prefix))
end

@printf("\n%-50s | %5s | %4s | %4s | %10s | %12s | %12s | %12s\n",
        "config", "grid", "vers", "n", "norm Δ", "E init", "|ΔE|", "Fz: init→end")
println("-"^140)
for s in all_stats
    s.found || continue
    @printf("%-50s | %5d | %4s | %4d | %.2e | %+12.4e | %.4e | %+.4f → %+.4f\n",
            s.label, s.n_grid, s.pre_post == :pre ? "PRE" : "POST", s.n_frames,
            s.norm_drift, s.E_initial, s.E_drift, s.Fz_initial, s.Fz_final)
end

# Highlight the parser-fix impact
println("\nParser-fix impact (POST-fix EdH transfer is unlocked):")
for prefix in ["L4_eu_matsui_hamiltonian_only_32", "L4_eu_matsui_hamiltonian_only_48",
                "L4_eu_matsui_hamiltonian_only_64", "L4_eu_matsui_hamiltonian_only_96",
                "L4_eu_matsui_hamiltonian_only_128"]
    runs = filter(s -> s.found && s.label == prefix, all_stats)
    pres = filter(s -> s.pre_post == :pre, runs)
    posts = filter(s -> s.pre_post == :post, runs)
    if !isempty(pres) && !isempty(posts)
        pre = last(pres)
        post = last(posts)
        @printf("  %s:\n", prefix)
        @printf("    pre  ΔFz = %+.4f (Bz ramp artefact)\n", pre.Fz_final - pre.Fz_initial)
        @printf("    post ΔFz = %+.4f (true quench EdH transfer)\n", post.Fz_final - post.Fz_initial)
    end
end
