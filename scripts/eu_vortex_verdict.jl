# Per-cell, per-seed GS competition for the vortex-verification runs.
#   julia --project=. scripts/eu_vortex_verdict.jl <run_dir>
# Prints each cell's 4 seed energies (+conv) and the min-E winner.

using JLD2, Printf
run = ARGS[1]
seeds = ("vortex", "flower", "polar", "fm")
_ug(s) = 1e6 * parse(Float64, split(String(s))[1])
npt = length(unique(parse.(Int, [m.captures[1] for f in readdir(run)
    for m in (match(r"point_(\d+)_", f),) if m !== nothing])))
for i in 1:npt
    best = ("", 1e18)
    parts = String[]
    B = k = NaN
    for s in seeds
        f = joinpath(run, @sprintf("point_%03d_%s.jld2", i, s))
        isfile(f) || (push!(parts, @sprintf("%s=--", s)); continue)
        E = JLD2.load(f, "energy")
        cv = JLD2.load(f, "converged")
        ov = JLD2.load(f, "override")
        B = _ug(get(ov, "pipeline.0.B.Bz", "0 G"))
        k = Float64(get(ov, "pipeline.0.potential.omega.2", NaN))
        push!(parts, @sprintf("%s=%.4f%s", s, E, cv ? "✓" : "✗"))
        E < best[2] && (best = (s, E))
    end
    @printf("B=%.0fµG κ=%.1f | %s | GS=%s (ΔE to 2nd=%s)\n",
        B, k, join(parts, "  "), best[1], "see values")
end
