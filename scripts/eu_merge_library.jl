# Consolidate every scattered Eu B-scan output dir into ONE deduplicated,
# physics-keyed library. Each frame_*/psi.jld2 is a self-describing converged GS;
# the reusable atom is keyed by (grid, κ, B_uG, branch). When the same key was
# computed multiple times (bequ/rc first attempts vs the final beq run), the
# BEST-CONVERGED (min grad_norm) wins — superseded attempts drop out automatically.
#
# NON-DESTRUCTIVE: winners are HARD-LINKED into the library (same filesystem, zero
# extra bytes), so the source dirs can later be reaped without losing data.
#
#   julia --project=. scripts/eu_merge_library.jl [figs] [figs/eu_gs_library]
#
# κ + branch are parsed from the source dir name (not stored in the jld2):
#   *_dn_*, *down*, *beqd*      -> branch "dn" (m=−F anchor)
#   *_up_*, *upsweep*, *bequ*, *rc_up*, *flower* -> branch "up"
#   _k<κ>                       -> κ (default 1.1818 = the original Eu trap)

using JLD2: jldopen
using DelimitedFiles: writedlm
using Printf

_g(f, k, d) = haskey(f, k) ? f[k] : d
_scalar(x) = x isa Tuple ? x[1] : x

const SRC  = length(ARGS) >= 1 ? ARGS[1] : "figs"
const DEST = length(ARGS) >= 2 ? ARGS[2] : "figs/eu_gs_library"

function parse_kappa(name)
    m = match(r"_k([0-9]+\.?[0-9]*)", name)
    m === nothing ? 1.1818 : parse(Float64, m.captures[1])
end
function parse_branch(name)
    n = lowercase(name)
    (occursin("_dn", n) || occursin("down", n) || occursin("beqd", n)) && return "dn"
    (occursin("_up", n) || occursin("upsweep", n) || occursin("bequ", n) ||
     occursin("rc_up", n) || occursin("flower", n)) && return "up"
    return "dn"  # m_plus_F-style default
end

# collect every psi.jld2 under SRC/<sweep>/frame_*/ (skip the library itself)
rows = NamedTuple[]
for sweep in readdir(SRC; join=true)
    isdir(sweep) || continue
    basename(sweep) == basename(DEST) && continue
    startswith(basename(sweep), "eu_gs_library") && continue
    κ = parse_kappa(basename(sweep)); br = parse_branch(basename(sweep))
    for d in readdir(sweep; join=true)
        pf = joinpath(d, "psi.jld2"); isfile(pf) || continue
        r = jldopen(pf, "r") do f
            (; grid=_scalar(_g(f, "grid_n_points", -1)),
               B=round(_g(f, "B_uG", NaN); digits=1),
               E=_g(f, "E_total", NaN), g=_g(f, "grad_norm", NaN),
               conv=_g(f, "converged", -1), pin=_g(f, "pin_bx", NaN))
        end
        isnan(r.B) && continue
        push!(rows, (; κ, br, r.grid, r.B, r.E, r.g, r.conv, r.pin,
                       src=basename(sweep), path=pf))
    end
end

# dedup by (grid, κ, B, branch): keep min grad_norm
function dedup(rows)
    best = Dict{Tuple{Int,Float64,Float64,String}, NamedTuple}()
    ndup = 0
    for r in rows
        k = (r.grid, r.κ, r.B, r.br)
        if !haskey(best, k) || (r.g < best[k].g)
            haskey(best, k) && (ndup += 1)
            best[k] = r
        else
            ndup += 1
        end
    end
    best, ndup
end
best, ndup = dedup(rows)

# hard-link winners into DEST/g<grid>/k<κ>/B<B>_<br>.jld2
mkpath(DEST)
manifest = NamedTuple[]
for (k, r) in best
    grid, κ, B, br = k
    sub = joinpath(DEST, @sprintf("g%d", grid), @sprintf("k%s", κ))
    mkpath(sub)
    dst = joinpath(sub, @sprintf("B%03d_%s.jld2", round(Int, B), br))
    isfile(dst) && rm(dst)
    try
        hardlink(r.path, dst)
    catch
        cp(r.path, dst; force=true)  # cross-device fallback
    end
    push!(manifest, (; grid, κ, B, branch=br, E=r.E, grad_norm=r.g,
                       converged=r.conv, pin=r.pin, src=r.src, path=dst))
end
sort!(manifest; by=r -> (r.grid, r.κ, r.B, r.branch))

open(joinpath(DEST, "library.csv"), "w") do io
    ks = [:grid, :κ, :B, :branch, :E, :grad_norm, :converged, :pin, :src, :path]
    writedlm(io, reshape(String.(ks), 1, :))
    for r in manifest
        writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
    end
end

@printf("scanned %d states, %d unique (grid,κ,B,branch), %d redundant dropped\n",
    length(rows), length(best), ndup)
@printf("library → %s/library.csv  (%d entries, hard-linked)\n", DEST, length(manifest))
# per-grid summary
grids = sort(unique(r.grid for r in manifest))
for g in grids
    gs = [r for r in manifest if r.grid == g]
    ks = sort(unique(r.κ for r in gs))
    @printf("  g%d: %d states, κ=%s\n", g, length(gs), join(ks, ","))
end
