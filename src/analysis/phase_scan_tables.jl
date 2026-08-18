# Tidy per-cell tables from a (c1 × Bz × κ) ground-state phase scan.
#
# `write_phase_table` pairs the two seeds (stretched / polar) per cell, takes
# the min-energy seed as the ground state, and emits one row with the phase
# label, order parameters, ⟨F_z⟩, seed energy gap (bistability proxy) and the
# energy decomposition. `write_phase_descriptors_table` emits the full
# rotation-invariant descriptor vector per min-E cell for UNSUPERVISED phase
# discovery — no candidate templates: σ_S spectrum, orbital L_z (vortex!),
# structure factors, flux-closure. Missing/failed cells are skipped with a
# warning, never abort the table (matches `tabulate` discipline).

using JLD2: JLD2
using Printf: @sprintf, @printf

export write_phase_table, write_phase_descriptors_table

_gauss_to_uG(s) = 1e6 * parse(Float64, split(String(s))[1])   # "6.0e-5 Gauss" → µG

# c1 may be fixed in the base config (not a scan axis) — then it is absent from
# the saved override. `c1_default` (e.g. the boundary scan's fixed physical
# value) keeps the table carrying a c1 column.
function _phase_cell_key(ov, c1_default)
    c1r = get(ov, "pipeline.0.interactions.c1_ratio", missing)
    c1 = c1r === missing ? c1_default : Float64(c1r)
    bz = get(ov, "pipeline.0.B.Bz", "0.0 Gauss")
    oz = get(ov, "pipeline.0.potential.omega.2", NaN)
    (c1, _gauss_to_uG(bz), Float64(oz))
end

# discover how many scan points exist
function _phase_scan_points(run)
    pts = sort(
        unique(
            parse.(
                Int,
                [
                    m.captures[1] for f in readdir(run)
                    for m in (match(r"point_(\d+)_", f),)
                    if m !== nothing
                ],
            ),
        ),
    )
    isempty(pts) && error("no point_*.jld2 in $run")
    pts
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
        JLD2.load(f, "analyze")
    catch
        nothing
    end
    (; energy=JLD2.load(f, "energy"),
        mz=(
            try
                JLD2.load(f, "mz_actual")
            catch
                NaN
            end
        ),
        override=JLD2.load(f, "override"), analyze=an)
end

"""
    write_phase_table(run_dir; out=joinpath(run_dir, "phase_table.csv"),
                      c1_default=NaN, io=stdout) -> String

Extract a tidy phase-diagram table from a (c1 × Bz × κ) ground-state scan and
write it as CSV. Prints a per-c1 (κ, B) phase-label preview to `io`. Returns
the output path.
"""
function write_phase_table(run_dir::AbstractString;
    out::AbstractString=joinpath(run_dir, "phase_table.csv"),
    c1_default::Float64=NaN, io::IO=stdout)
    pts = _phase_scan_points(run_dir)

    rows = Vector{Vector{Any}}()
    header = ["c1_ratio", "B_uG", "kappa", "gs_seed", "E_gs", "E_gap_seeds",
        "Fz", "phase", "phase_distance", "spin_order", "nematic_order",
        "Q6", "q6_maj", "T2", "T4", "T6", "T12",
        "E_density_c0", "E_spin_c1", "E_ddi", "E_zeeman", "E_trap"]

    for i in pts
        s = _load_seed(run_dir, i, "stretched")
        p = _load_seed(run_dir, i, "polar")
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
        c1, buG, kap = _phase_cell_key(gs.override, c1_default)

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

        push!(rows,
            Any[c1, buG, kap, gs_seed, gs.energy, gap, gs.mz, phase, pdist,
                spin_order, nematic, Q6pc, q6,
                getk(2), getk(4), getk(6), getk(12),
                getE("density"), getE("spin"), getE("ddi"), getE("zeeman"),
                getE("trap")])
    end

    sort!(rows; by=r -> (r[1], r[3], r[2]))   # c1, κ, B
    open(out, "w") do f
        println(f, join(header, ','))
        for r in rows
            println(f, join(r, ','))
        end
    end
    @info "wrote $(length(rows)) cells" out
    # quick console preview: phase per (κ,B) at each c1
    for c1 in sort(unique(r[1] for r in rows))
        println(io, "\n=== c1_ratio = $c1 ===")
        ks = sort(unique(r[3] for r in rows if r[1] == c1))
        bs = sort(unique(r[2] for r in rows if r[1] == c1))
        @printf(io, "%8s", "κ\\B(µG)")
        for b in bs
            @printf(io, "%9.0f", b)
        end
        println(io)
        for k in ks
            @printf(io, "%8.2f", k)
            for b in bs
                r = findfirst(r -> r[1] == c1 && r[3] == k && r[2] == b, rows)
                @printf(io, "%9s",
                    r === nothing ? "-" : string(rows[r][8])[1:min(8, end)])
            end
            println(io)
        end
    end
    out
end

"""
    write_phase_descriptors_table(run_dir;
        out=joinpath(run_dir, "descriptors.csv"), c1_default=NaN) -> String

Full rotation-invariant descriptor vector per (min-E) cell, for unsupervised
phase discovery. Captures what a scalar classifier misses: the σ_S spectrum,
orbital L_z, structure factors, flux-closure. Returns the output path.
"""
function write_phase_descriptors_table(run_dir::AbstractString;
    out::AbstractString=joinpath(run_dir, "descriptors.csv"),
    c1_default::Float64=NaN)
    pts = _phase_scan_points(run_dir)

    svals = 0:2:12
    open(out, "w") do io
        hdr = ["c1_ratio", "B_uG", "kappa", "gs_seed", "E_gs",
            ["sigma$S" for S in svals]...,
            "mF", "coh", "fluxclosure", "abschir", "absLz", "absFz", "Jz",
            "spin_mod", "kspin", "dens_mod", "kdens"]
        println(io, join(hdr, ","))
        for i in pts
            best = nothing
            for s in ("stretched", "polar")
                f = joinpath(run_dir, @sprintf("point_%03d_%s.jld2", i, s))
                isfile(f) || continue
                E = JLD2.load(f, "energy")
                (best === nothing || E < best.E) && (best = (; E, f, s))
            end
            best === nothing && continue
            psi = load_point_psi(best.f)   # light-point aware (gs_ref → stage)
            n = Int.(JLD2.load(best.f, "grid_n_points"))
            box = Float64.(JLD2.load(best.f, "grid_box_size"))
            ov = JLD2.load(best.f, "override")
            grid = make_grid(GridConfig(Tuple(n), Tuple(box)))
            fp = spinor_fingerprint(psi, grid, 6)
            c1, B, k = _phase_cell_key(ov, c1_default)
            fcl = isnan(fp.fluxclosure) ? -1.0 : fp.fluxclosure   # NaN (|F|≈0) → sentinel
            row = Any[c1, B, k, best.s, best.E,
                [fp.sigma[S] for S in svals]...,
                fp.mF, fp.coh, fcl, abs(fp.chirality), abs(fp.Lz), abs(fp.Fz),
                fp.Jz, fp.spin_mod, fp.kspin, fp.dens_mod, fp.kdens]
            println(io, join(row, ","))
        end
    end
    println("wrote ", out)
    out
end
