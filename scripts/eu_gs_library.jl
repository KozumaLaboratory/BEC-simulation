# Reusable ground-state library over a pinned Eu B-scan output dir.
#
# Every `frame_NNN/psi.jld2` produced by eu_bscan_pinned_continuation.jl is a
# self-describing converged GS ψ(B). This module turns that directory into a
# physics-keyed, discoverable dataset so the states SEED finer runs / dynamics /
# analysis instead of being recomputed. Works on both the current-schema files
# and older ones (missing keys default gracefully).
#
# Usage:
#   using SpinorBEC
#   include("scripts/eu_gs_library.jl")
#   lib = gs_library("figs/eu_bscan_pin_tight")        # table + writes library.csv
#   e   = load_gs("figs/eu_bscan_pin_tight"; B_uG=50)  # nearest-B: e.psi, e.meta
#   # seed a run/dynamics from it:
#   find_ground_state_lbfgs(; grid=g, atom=a, ..., psi_init=e.psi)   # same grid
#   # or upsample first if the target grid differs (scripts/upsample_spinor.jl).
#
# `load_state(e.meta.path)` also works directly on new-schema files.

using JLD2: jldopen
using DelimitedFiles: writedlm
using Printf

_g(f, k, d) = haskey(f, k) ? f[k] : d
_scalar(x) = x isa Tuple ? x[1] : x

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
            (; B_uG=_g(f, "B_uG", NaN),
               grid=_scalar(f["grid_n_points"]), box=_scalar(f["grid_box_size"]),
               pin_bx=_g(f, "pin_bx", NaN),
               c0=_g(f, "c0", NaN), c1=_g(f, "c1", NaN), c_dd=_g(f, "c_dd", NaN),
               E_total=_g(f, "E_total", NaN), grad_norm=_g(f, "grad_norm", NaN),
               converged=_g(f, "converged", -1), last_step=_g(f, "last_step", -1),
               path=pf)
        end
        push!(rows, row)
    end
    sort!(rows; by=r -> r.B_uG)
    if write_csv && !isempty(rows)
        open(joinpath(dir, "library.csv"), "w") do io
            ks = collect(keys(rows[1]))
            writedlm(io, reshape(String.(ks), 1, :))
            for r in rows
                writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
            end
        end
    end
    rows
end

"""
    load_gs(dir; B_uG, grid=nothing) -> (; psi, meta)

Load the converged GS ψ nearest `B_uG` (optionally constrained to a `grid`).
`psi` is a host `Array{ComplexF64}` ready to pass as `psi_init=`; `meta` is the
library row (B_uG, grid, box, pin_bx, c0/c1/c_dd, E_total, grad_norm, …).
"""
function load_gs(dir::AbstractString; B_uG::Real, grid::Union{Nothing, Int}=nothing)
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
    load_lib(; κ, B_uG, branch="dn", grid=32, lib="figs/eu_gs_library") -> (; psi, meta)

Load a converged GS ψ from the MERGED library (built by scripts/eu_merge_library.jl)
by physics key: nearest `B_uG` within the requested `(grid, κ, branch)`. This is the
canonical way to reuse a state going forward — seed a run/dynamics/analysis with
`psi_init=load_lib(; κ=1.8, B_uG=61).psi` instead of reaching into scattered dirs.
`load_state(meta.path)` also works directly (files are load_state-schema).
"""
function load_lib(; κ::Real, B_uG::Real, branch::AbstractString="dn",
                  grid::Int=32, lib::AbstractString="figs/eu_gs_library")
    csv = joinpath(lib, "library.csv")
    isfile(csv) || error("no merged library at $csv — run scripts/eu_merge_library.jl")
    hdr = split(readline(csv), '\t')
    col = Dict(h => i for (i, h) in enumerate(hdr))
    cand = NamedTuple[]
    for ln in readlines(csv)[2:end]
        c = split(ln, '\t'); isempty(c[1]) && continue
        (parse(Int, c[col["grid"]]) == grid &&
         abs(parse(Float64, c[col["κ"]]) - κ) < 1e-3 &&
         c[col["branch"]] == branch) || continue
        push!(cand, (; B=parse(Float64, c[col["B"]]), path=String(c[col["path"]]),
                       E=parse(Float64, c[col["E"]]), grad=parse(Float64, c[col["grad_norm"]])))
    end
    isempty(cand) && error("no library state for grid=$grid κ=$κ branch=$branch")
    r = cand[argmin(abs.(getfield.(cand, :B) .- B_uG))]
    psi = jldopen(r.path, "r") do f; Array{ComplexF64}(f["psi"]); end
    (; psi, meta=r)
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
        get!(data, "t", 0.0); get!(data, "step", 0)
        get!(data, "zeeman_q", 0.0); get!(data, "dt", 0.002)
        get!(data, "imaginary_time", true); get!(data, "c_lhy", 0.0)
        get!(data, "c_dict",
            Dict{Int, Float64}(0 => get(data, "c0", NaN), 1 => get(data, "c1", NaN)))
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

# CLI: `julia --project=. scripts/eu_gs_library.jl figs/eu_bscan_pin_tight`
if abspath(PROGRAM_FILE) == @__FILE__
    dir = length(ARGS) ≥ 1 ? ARGS[1] : "figs/eu_bscan_pin_tight"
    lib = gs_library(dir)
    @printf("indexed %d GS states → %s/library.csv\n", length(lib), dir)
    for r in lib
        @printf("  B=%6.2f µG  grid=%d  E=%.5f  |∇E|=%.2e  conv=%s\n",
            r.B_uG, r.grid, r.E_total, r.grad_norm, string(r.converged))
    end
end
