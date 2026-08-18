# Reusable ground-state library over pinned Eu B-scan output dirs.
#
# Every `frame_NNN/psi.jld2` written by a pinned continuation scan is a
# self-describing converged GS ψ(B). `gs_library` turns such a directory into
# a physics-keyed, discoverable dataset; `merge_gs_library` consolidates every
# scattered scan dir into ONE deduplicated library keyed by (grid, κ, B_uG,
# branch), so states SEED finer runs / dynamics / analysis instead of being
# recomputed. Works on both the current-schema files and older ones (missing
# keys default gracefully).
#
#   lib = gs_library("figs/eu_bscan_pin_tight")        # table + writes library.csv
#   e   = load_gs("figs/eu_bscan_pin_tight"; B_uG=50)  # nearest-B: e.psi, e.meta
#   e   = load_gs(; κ=1.8, B_uG=61)                    # from the MERGED library
#   find_ground_state_lbfgs(; grid=g, atom=a, ..., psi_init=e.psi)  # same grid
#   # or upsample first if the target grid differs — `upsample_spinor` in
#   # `src/workflow/initialization/upsample.jl`, or `seed_from: {upsample: true}`
#   # in YAML.
#
# `load_state(e.meta.path)` also works directly on new-schema files.

using JLD2: jldopen
using Printf: @sprintf

export gs_library,
    load_gs, merge_gs_library, make_load_state_compatible,
    assert_seed_epoch, seed_meta

const DEFAULT_GS_LIBRARY = "figs/eu_gs_library"

_gslib_get(f, k, d) = haskey(f, k) ? f[k] : d
_gslib_scalar(x) = x isa Tuple ? x[1] : x

# Tab-separated row writer (library.csv is TSV; `load_gs` splits on '\t').
_gslib_writerow(io, cells) = println(io, join(string.(cells), '\t'))

"""
    gs_library(dir; write_csv=true) -> Vector{NamedTuple}

Scan `dir/frame_*/psi.jld2`, return one metadata row per converged GS sorted by
B_uG, and (default) write `dir/library.csv` as the human/tooling-readable index.
"""
function gs_library(dir::AbstractString; write_csv::Bool=true)
    dirs = filter(isdir, readdir(dir; join=true))
    rows = NamedTuple[]
    for d in dirs
        pf = joinpath(d, "psi.jld2")
        isfile(pf) || continue
        row = jldopen(pf, "r") do f
            (; B_uG=_gslib_get(f, "B_uG", NaN),
                grid=_gslib_scalar(f["grid_n_points"]),
                box=_gslib_scalar(f["grid_box_size"]),
                pin_bx=_gslib_get(f, "pin_bx", NaN),
                c0=_gslib_get(f, "c0", NaN), c1=_gslib_get(f, "c1", NaN),
                c_dd=_gslib_get(f, "c_dd", NaN),
                E_total=_gslib_get(f, "E_total", NaN),
                grad_norm=_gslib_get(f, "grad_norm", NaN),
                converged=_gslib_get(f, "converged", -1),
                last_step=_gslib_get(f, "last_step", -1),
                path=pf)
        end
        push!(rows, row)
    end
    sort!(rows; by=r -> r.B_uG)
    if write_csv && !isempty(rows)
        open(joinpath(dir, "library.csv"), "w") do io
            ks = collect(keys(rows[1]))
            _gslib_writerow(io, String.(ks))
            for r in rows
                _gslib_writerow(io, Any[getfield(r, k) for k in ks])
            end
        end
    end
    rows
end

"""
    load_gs(dir; B_uG, grid=nothing) -> (; psi, meta)

Load the converged GS ψ nearest `B_uG` from a scan dir (optionally constrained
to a `grid`). `psi` is a host `Array{ComplexF64}` ready to pass as `psi_init=`;
`meta` is the library row (B_uG, grid, box, pin_bx, c0/c1/c_dd, E_total,
grad_norm, …).
"""
function load_gs(dir::AbstractString; B_uG::Real,
    grid::Union{Nothing, Int}=nothing)
    rows = gs_library(dir; write_csv=false)
    grid !== nothing && (rows = filter(r -> r.grid == grid, rows))
    isempty(rows) && error("no GS in $dir matching grid=$grid")
    r = rows[argmin(abs.(getfield.(rows, :B_uG) .- B_uG))]
    psi = jldopen(r.path, "r") do f
        Array{ComplexF64}(f["psi"])
    end
    (; psi, meta=r)
end

"""
    load_gs(; κ, B_uG, branch="dn", grid=32, lib=DEFAULT_GS_LIBRARY) -> (; psi, meta)

Load a converged GS ψ from the MERGED library (built by `merge_gs_library`) by
physics key: nearest `B_uG` within the requested `(grid, κ, branch)`. This is
the canonical way to reuse a state — seed a run/dynamics/analysis with
`psi_init=load_gs(; κ=1.8, B_uG=61).psi` instead of reaching into scattered
dirs. `load_state(meta.path)` also works directly (files are
load_state-schema).
"""
function load_gs(; κ::Real, B_uG::Real, branch::AbstractString="dn",
    grid::Int=32, lib::AbstractString=DEFAULT_GS_LIBRARY)
    csv = joinpath(lib, "library.csv")
    isfile(csv) || error("no merged library at $csv — run merge_gs_library()")
    hdr = split(readline(csv), '\t')
    col = Dict(h => i for (i, h) in enumerate(hdr))
    cand = NamedTuple[]
    for ln in readlines(csv)[2:end]
        c = split(ln, '\t')
        isempty(c[1]) && continue
        (
            parse(Int, c[col["grid"]]) == grid &&
            abs(parse(Float64, c[col["κ"]]) - κ) < 1e-3 &&
            c[col["branch"]] == branch
        ) || continue
        push!(cand,
            (; B=parse(Float64, c[col["B"]]), path=String(c[col["path"]]),
                E=parse(Float64, c[col["E"]]),
                grad=parse(Float64, c[col["grad_norm"]])))
    end
    isempty(cand) && error("no library state for grid=$grid κ=$κ branch=$branch")
    r = cand[argmin(abs.(getfield.(cand, :B) .- B_uG))]
    psi = jldopen(r.path, "r") do f
        Array{ComplexF64}(f["psi"])
    end
    (; psi, meta=r)
end

# κ + branch are parsed from the source dir name (not stored in the jld2):
#   *_dn_*, *down*, *beqd*      -> branch "dn" (m=−F anchor)
#   *_up_*, *upsweep*, *bequ*, *rc_up*, *flower* -> branch "up"
#   _k<κ>                       -> κ (default 1.1818 = the original Eu trap)
function _gslib_parse_kappa(name)
    m = match(r"_k([0-9]+\.?[0-9]*)", name)
    m === nothing ? 1.1818 : parse(Float64, m.captures[1])
end

function _gslib_parse_branch(name)
    n = lowercase(name)
    (occursin("_dn", n) || occursin("down", n) || occursin("beqd", n)) &&
        return "dn"
    (
        occursin("_up", n) || occursin("upsweep", n) || occursin("bequ", n) ||
        occursin("rc_up", n) || occursin("flower", n)
    ) && return "up"
    return "dn"  # m_plus_F-style default
end

# dedup by (grid, κ, B, branch): keep min grad_norm
function _gslib_dedup(rows)
    best = Dict{Tuple{Int, Float64, Float64, String}, NamedTuple}()
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

"""
    merge_gs_library(src="figs", dest=DEFAULT_GS_LIBRARY; io=stdout) -> Vector{NamedTuple}

Consolidate every scattered Eu B-scan output dir under `src` into ONE
deduplicated, physics-keyed library at `dest`. Each `frame_*/psi.jld2` is a
self-describing converged GS; the reusable atom is keyed by (grid, κ, B_uG,
branch). When the same key was computed multiple times, the BEST-CONVERGED
(min grad_norm) wins — superseded attempts drop out automatically.

NON-DESTRUCTIVE: winners are HARD-LINKED into the library (same filesystem,
zero extra bytes), so the source dirs can later be reaped without losing data.
Returns the manifest and writes `dest/library.csv`.
"""
function merge_gs_library(src::AbstractString="figs",
    dest::AbstractString=DEFAULT_GS_LIBRARY; io::IO=stdout)
    # collect every psi.jld2 under src/<sweep>/frame_*/ (skip the library itself)
    rows = NamedTuple[]
    for sweep in readdir(src; join=true)
        isdir(sweep) || continue
        basename(sweep) == basename(dest) && continue
        startswith(basename(sweep), "eu_gs_library") && continue
        κ = _gslib_parse_kappa(basename(sweep))
        br = _gslib_parse_branch(basename(sweep))
        for d in readdir(sweep; join=true)
            pf = joinpath(d, "psi.jld2")
            isfile(pf) || continue
            r = jldopen(pf, "r") do f
                (; grid=_gslib_scalar(_gslib_get(f, "grid_n_points", -1)),
                    B=round(_gslib_get(f, "B_uG", NaN); digits=1),
                    E=_gslib_get(f, "E_total", NaN),
                    g=_gslib_get(f, "grad_norm", NaN),
                    conv=_gslib_get(f, "converged", -1),
                    pin=_gslib_get(f, "pin_bx", NaN))
            end
            isnan(r.B) && continue
            push!(
                rows, (; κ, br, r.grid, r.B, r.E, r.g, r.conv, r.pin,
                    src=basename(sweep), path=pf)
            )
        end
    end
    best, ndup = _gslib_dedup(rows)

    # hard-link winners into dest/g<grid>/k<κ>/B<B>_<br>.jld2
    mkpath(dest)
    manifest = NamedTuple[]
    for (k, r) in best
        grid, κ, B, br = k
        sub = joinpath(dest, @sprintf("g%d", grid), @sprintf("k%s", κ))
        mkpath(sub)
        dst = joinpath(sub, @sprintf("B%03d_%s.jld2", round(Int, B), br))
        isfile(dst) && rm(dst)
        try
            hardlink(r.path, dst)
        catch
            cp(r.path, dst; force=true)  # cross-device fallback
        end
        push!(
            manifest,
            (; grid, κ, B, branch=br, E=r.E, grad_norm=r.g,
                converged=r.conv, pin=r.pin, src=r.src, path=dst),
        )
    end
    sort!(manifest; by=r -> (r.grid, r.κ, r.B, r.branch))

    open(joinpath(dest, "library.csv"), "w") do f
        ks = [:grid, :κ, :B, :branch, :E, :grad_norm, :converged, :pin,
            :src, :path]
        _gslib_writerow(f, String.(ks))
        for r in manifest
            _gslib_writerow(f, Any[getfield(r, k) for k in ks])
        end
    end

    println(io,
        "scanned $(length(rows)) states, $(length(best)) unique " *
        "(grid,κ,B,branch), $ndup redundant dropped")
    println(io,
        "library → $dest/library.csv  ($(length(manifest)) entries, " *
        "hard-linked)")
    for g in sort(unique(r.grid for r in manifest))
        gs = [r for r in manifest if r.grid == g]
        ks = sort(unique(r.κ for r in gs))
        println(io, "  g$g: $(length(gs)) states, κ=$(join(ks, ","))")
    end
    manifest
end

"""
    assert_seed_epoch(path, meta; c0, c1, c_dd, p, n_points, box)

Abort unless a library seed's stored parameters match the preset the caller
rebuilt. A silent mismatch puts one parameter epoch's state into another
epoch's Hamiltonian: the seed is then not stationary, and everything measured
afterwards is that transient rather than the ramp.
"""
function assert_seed_epoch(
    path::AbstractString, m::NamedTuple;
    c0::Real, c1::Real, c_dd::Real, p::Real,
    n_points::Tuple, box::Real,
)
    for (name, got, want, tol) in (
        ("c0", m.c0, c0, 1e-8),
        ("c1", m.c1, c1, 1e-8),
        ("c_dd", m.c_dd, c_dd, 1e-8),
        ("zeeman_p", m.p, p, 1e-6),
    )
        rel = abs(got - want) / max(abs(want), 1e-30)
        rel < tol || error("""
            seed/preset mismatch on $name: stored $got vs preset $want (rel $rel).
            The library state was computed with a different parameter epoch — fix
            the preset (n_atoms / box / ω_ref / trap ratios) before ramping.
            seed = $path""")
    end
    (m.n == n_points && all(≈(box), m.box)) ||
        error("seed grid $(m.n) box $(m.box) ≠ requested $n_points / $box\nseed = $path")
    nothing
end

"""Scalar metadata a library ψ file carries (schema written by the GS campaign)."""
seed_meta(path::AbstractString) = jldopen(path, "r") do f
    (; c0=f["c0"], c1=f["c1"], c_dd=f["c_dd"], p=f["zeeman_p"],
        pin=f["pin_bx"], box=f["grid_box_size"], n=f["grid_n_points"])
end

"""
    make_load_state_compatible(dir) -> Int

Upgrade older-schema `frame_*/psi.jld2` in-place (atomically) to the full
`load_state` schema by adding any missing keys (t, step, zeeman_q, c_dict from
c0/c1, c_lhy, dt, imaginary_time). Already-complete files are left untouched.
Returns the number rewritten. Run AFTER a scan finishes so `load_state(pf)` and
the whole make_workspace/dynamics/analysis pipeline consume the states directly.
"""
function make_load_state_compatible(dir::AbstractString)
    n = 0
    for d in filter(isdir, readdir(dir; join=true))
        pf = joinpath(d, "psi.jld2")
        isfile(pf) || continue
        data = jldopen(pf, "r") do f
            Dict(k => f[k] for k in keys(f))
        end
        haskey(data, "t") && haskey(data, "step") && continue   # already complete
        get!(data, "t", 0.0)
        get!(data, "step", 0)
        get!(data, "zeeman_q", 0.0)
        get!(data, "dt", 0.002)
        get!(data, "imaginary_time", true)
        get!(data, "c_lhy", 0.0)
        get!(data, "c_dict",
            Dict{Int, Float64}(0 => get(data, "c0", NaN),
                1 => get(data, "c1", NaN)))
        tmp = pf * ".tmp"
        jldopen(tmp, "w") do f
            for (k, v) in data
                f[k] = v
            end
        end
        mv(tmp, pf; force=true)
        n += 1
    end
    n
end
