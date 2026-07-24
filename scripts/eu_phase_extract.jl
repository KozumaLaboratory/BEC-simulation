# Extract a tidy phase-diagram table from a (c1 × Bz × κ) ground-state scan.
#
#   julia --project=. scripts/eu_phase_extract.jl <run_dir> [out.csv]
#
# For each (c1, Bz, κ) cell it pairs the two seeds (stretched / polar), takes
# the min-energy seed as the ground state, and emits one row with the phase
# label, order parameters, ⟨F_z⟩, energy gap between seeds (bistability
# proxy), and the energy decomposition. Missing/failed cells are skipped with
# a warning, never abort the table (matches `tabulate` discipline).

using JLD2, Printf, DelimitedFiles

const RUN = length(ARGS) >= 1 ? ARGS[1] : error("usage: eu_phase_extract.jl <run_dir> [out.csv]")
const OUT = length(ARGS) >= 2 ? ARGS[2] : joinpath(RUN, "phase_table.csv")

_gauss_to_uG(s) = 1e6 * parse(Float64, split(String(s))[1])   # "6.0e-5 Gauss" → µG

# c1 may be fixed in the base config (not a scan axis) — then it is absent from
# the saved override. Fall back to SPINORBEC_PHASE_C1 (e.g. the boundary scan's
# fixed physical value) so the table still carries a c1 column.
const _C1_DEFAULT = parse(Float64, get(ENV, "SPINORBEC_PHASE_C1", "NaN"))

function _cell_key(ov)
    c1r = get(ov, "pipeline.0.interactions.c1_ratio", missing)
    c1 = c1r === missing ? _C1_DEFAULT : Float64(c1r)
    bz = get(ov, "pipeline.0.B.Bz", missing)
    oz = get(ov, "pipeline.0.potential.omega.2", missing)
    (c1, _gauss_to_uG(bz), Float64(oz))
end

# analyze block: Vector of per-step Dicts (see pipeline_analyzers). Pull the
# named analyzer payloads defensively.
function _get_analyzer(analyze, name::String)
    analyze === nothing && return nothing
    for step in (analyze isa AbstractVector ? analyze : [analyze])
        step isa AbstractDict || continue
        haskey(step, name) && return step[name]
    end
    return nothing
end

function _load_seed(run, idx, seed)
    f = joinpath(run, @sprintf("point_%03d_%s.jld2", idx, seed))
    isfile(f) || return nothing
    # `analyze` is a JLD2 GROUP (flattened slash-keys); load it as a nested
    # Dict via the group path, not via whole-file load(f)["analyze"].
    an = try
        load(f, "analyze")
    catch
        nothing
    end
    (; energy=load(f, "energy"), mz=(try load(f, "mz_actual") catch; NaN end),
       override=load(f, "override"), analyze=an)
end

# discover how many scan points exist
pts = sort(unique(parse.(Int, [m.captures[1] for f in readdir(RUN)
    for m in (match(r"point_(\d+)_", f),) if m !== nothing])))
isempty(pts) && error("no point_*.jld2 in $RUN")

rows = Vector{Vector{Any}}()
header = ["c1_ratio", "B_uG", "kappa", "gs_seed", "E_gs", "E_gap_seeds",
          "Fz", "phase", "phase_distance", "spin_order", "nematic_order", "Q6", "q6_maj",
          "T2", "T4", "T6", "T12",
          "E_density_c0", "E_spin_c1", "E_ddi", "E_zeeman", "E_trap"]

for i in pts
    s = _load_seed(RUN, i, "stretched")
    p = _load_seed(RUN, i, "polar")
    (s === nothing && p === nothing) && (@warn "cell $i: no seeds"; continue)
    # min-energy seed wins
    gs, other = if s === nothing
        (p, nothing)
    elseif p === nothing
        (s, nothing)
    else
        s.energy <= p.energy ? (s, p) : (p, s)
    end
    gs_seed = gs === s ? "stretched" : "polar"
    gap = other === nothing ? NaN : abs(s.energy - p.energy)
    c1, buG, kap = _cell_key(gs.override)

    pc = _get_analyzer(gs.analyze, "phase_classify_distance")
    getp(k, d) = pc isa AbstractDict ? get(pc, k, d) : d
    phase = getp("phase", "?")
    pdist = getp("phase_distance", "?")
    spin_order = getp("spin_order", NaN)
    nematic = getp("nematic_order", NaN)
    Q6pc = getp("Q6", NaN)

    mp = _get_analyzer(gs.analyze, "multipole_order")
    spec = mp isa AbstractDict ? get(mp, "multipole_spectrum", Dict()) : Dict()
    getk(k) = get(spec, string(k), get(spec, k, NaN))

    mj = _get_analyzer(gs.analyze, "majorana_order")
    q6 = mj isa AbstractDict ? get(mj, "q6_avg", NaN) : NaN

    ed = _get_analyzer(gs.analyze, "energy_decomposition")
    getE(k) = ed isa AbstractDict ? get(ed, k, NaN) : NaN

    push!(rows, Any[c1, buG, kap, gs_seed, gs.energy, gap, gs.mz, phase, pdist,
        spin_order, nematic, Q6pc, q6,
        getk(2), getk(4), getk(6), getk(12),
        getE("density"), getE("spin"), getE("ddi"), getE("zeeman"), getE("trap")])
end

sort!(rows, by = r -> (r[1], r[3], r[2]))   # c1, κ, B
open(OUT, "w") do io
    writedlm(io, [permutedims(header); reduce(vcat, permutedims.(rows))], ',')
end
@info "wrote $(length(rows)) cells" OUT
# quick console preview: phase per (κ,B) at each c1
for c1 in sort(unique(r[1] for r in rows))
    println("\n=== c1_ratio = $c1 ===")
    ks = sort(unique(r[3] for r in rows if r[1]==c1))
    bs = sort(unique(r[2] for r in rows if r[1]==c1))
    @printf("%8s", "κ\\B(µG)"); for b in bs; @printf("%9.0f", b); end; println()
    for k in ks
        @printf("%8.2f", k)
        for b in bs
            r = findfirst(r -> r[1]==c1 && r[3]==k && r[2]==b, rows)
            @printf("%9s", r === nothing ? "-" : string(rows[r][8])[1:min(8,end)])
        end
        println()
    end
end
