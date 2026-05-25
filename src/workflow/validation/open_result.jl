# --- open_result(path) → RunResult ---
#
# Loads a JLD2 run artifact and assembles a RunResult. Supports the
# multiple jld2 formats produced by SpinorBEC's various write paths:
#
#   * `point_001.jld2` — standard YAML pipeline output: top-level
#     `psi`, `grid_n_points`, `grid_box_size`, `energy`, `converged`;
#     `dynamics/*` block when a dynamics step ran;
#     `analyze/energy_decomposition/*` when that analyzer ran;
#     `units/*` + `env/*` metadata.
#
#   * `operator_rhs.jld2` — Level-10 hpsi_export output: same as
#     above plus `Hpsi`, `interactions_c0/c1/c_lhy/c_high_rank`,
#     `ddi_c_dd`, `dealias_*`, `conventions`.
#
#   * `result.jld2` — stripped streamlined view (no per-term energy);
#     loadable but `e_decomp` will be empty.
#
# Missing fields degrade gracefully: e_decomp and metadata default to
# empty Dicts; interactions reconstructed from saved `interactions_*`
# keys when present, otherwise from `units/atom` + `units/N_atoms` +
# `units/omega_ref_rad_s` via `compute_interaction_params`.

export open_result

"""
    open_result(path::String) -> RunResult

Load a JLD2 artifact (point_001.jld2 / operator_rhs.jld2 / result.jld2)
into a `RunResult` typed view. Throws `ArgumentError` if the file
doesn't contain a recognisable wavefunction layout.

```julia
r = open_result("runs/eu_ham_only_24_nonsec_<hash>/point_001.jld2")
size(r.psi)         # (24, 24, 24, 13)
r.atom.name         # "Eu151"
r.dynamics.times    # Vector{Float64}
```
"""
function open_result(path::AbstractString)
    isfile(path) || throw(ArgumentError("open_result: file not found: $path"))

    data = JLD2.load(path)

    psi = _extract_psi(data, path)
    hpsi = _extract_hpsi(data, psi)
    grid = _extract_grid(data, psi)
    atom = _extract_atom(data, psi)
    interactions = _extract_interactions(data, atom)
    dynamics = _extract_dynamics(data)
    e_decomp = _extract_e_decomp(data)
    metadata = _extract_metadata(data)

    RunResult(
        path, psi, grid, atom, interactions;
        hpsi, dynamics, e_decomp, metadata,
    )
end

function _extract_hpsi(data::Dict, psi::AbstractArray)
    haskey(data, "Hpsi") || return nothing
    raw = data["Hpsi"]
    raw isa AbstractArray || return nothing
    size(raw) == size(psi) || return nothing
    convert(Array{ComplexF64, ndims(raw)}, raw)
end

function _extract_psi(data::Dict, path::AbstractString)
    haskey(data, "psi") ||
        throw(ArgumentError("open_result: no `psi` key in $path"))
    psi_raw = data["psi"]
    psi_raw isa AbstractArray ||
        throw(ArgumentError("open_result: `psi` is not an array (got $(typeof(psi_raw)))"))
    convert(Array{ComplexF64, ndims(psi_raw)}, psi_raw)
end

function _extract_grid(data::Dict, psi::AbstractArray)
    n_pts_v = get(data, "grid_n_points", nothing)
    box_v = get(data, "grid_box_size", nothing)
    if n_pts_v === nothing || box_v === nothing
        # Fallback: derive n_pts from psi shape, box from defaults.
        spatial = size(psi)[1:(ndims(psi) - 1)]
        n_pts_v = collect(Int, spatial)
        box_v = fill(10.0, length(spatial))
    end
    n_pts = Tuple(Int.(n_pts_v))
    box = Tuple(Float64.(box_v))
    make_grid(GridConfig(n_pts, box))
end

function _extract_atom(data::Dict, psi::AbstractArray)
    name_str = get(data, "units/atom", get(data, "atom_name", ""))
    if !isempty(name_str)
        sym = Symbol(name_str)
        try
            return resolve_atom(sym)
        catch
            # Fall through to reconstruction from atom_* fields, or
            # minimal anonymous AtomSpecies.
        end
    end
    # Reconstruct from explicit atom_* fields if save_operator_rhs wrote
    # them (covers user-defined atoms that won't resolve via the registry).
    if haskey(data, "atom_F")
        return AtomSpecies(
            isempty(name_str) ? "unknown" : String(name_str),
            Float64(get(data, "atom_mass", 1.0e-26)),
            Int(data["atom_F"]),
            Float64(get(data, "atom_a_s", 0.0)),
            Float64(get(data, "atom_mu_mag", 0.0)),
            Float64(get(data, "atom_g_F", 0.0)),
        )
    end
    # Last-resort: construct minimal AtomSpecies from psi spinor dimension.
    F = (size(psi, ndims(psi)) - 1) ÷ 2
    AtomSpecies("unknown", 1.0e-26, F, 0.0, 0.0, 0.0)
end

function _extract_interactions(data::Dict, atom::AtomSpecies)
    # Preferred: explicit interactions_* keys (operator_rhs.jld2 / save_state).
    if haskey(data, "interactions_c0") || haskey(data, "c_dict")
        c_dict = Dict{Int, Float64}()
        if haskey(data, "c_dict") && data["c_dict"] isa Dict
            for (k, v) in data["c_dict"]
                c_dict[Int(k)] = Float64(v)
            end
        else
            haskey(data, "interactions_c0") && (c_dict[0] = Float64(data["interactions_c0"]))
            haskey(data, "interactions_c1") && (c_dict[1] = Float64(data["interactions_c1"]))
            # `interactions_c_high_rank` is a Pair{Int,Float64}[] or empty.
            if haskey(data, "interactions_c_high_rank")
                v = data["interactions_c_high_rank"]
                if v isa AbstractVector
                    for p in v
                        c_dict[Int(p.first)] = Float64(p.second)
                    end
                end
            end
        end
        c_lhy = Float64(get(data, "interactions_c_lhy", get(data, "c_lhy", 0.0)))
        return InteractionParams(c_dict; c_lhy)
    end

    # Fallback: derive from units/* metadata via compute_interaction_params.
    N_atoms = Int(get(data, "units/N_atoms", 1))
    omega_ref = Float64(get(data, "units/omega_ref_rad_s", 1.0))
    if N_atoms > 0 && omega_ref > 0
        try
            return compute_interaction_params(atom; N_atoms, dims=3)
        catch
            # silent: empty Dict is a safe default
        end
    end
    InteractionParams(Dict{Int, Float64}())
end

function _extract_dynamics(data::Dict)
    haskey(data, "dynamics/times") || return nothing
    times = data["dynamics/times"]
    norms = get(data, "dynamics/norms", fill(NaN, length(times)))
    energies = get(data, "dynamics/energies", fill(NaN, length(times)))
    Fz_raw = get(data, "dynamics/Fz",
        get(data, "dynamics/magnetizations", fill(NaN, length(times))))
    Lz_raw = get(data, "dynamics/Lz", nothing)
    DynamicsTimeSeries(times, norms, energies, Fz_raw; Lz=Lz_raw)
end

function _extract_e_decomp(data::Dict)
    out = Dict{String, Float64}()
    prefix = "analyze/energy_decomposition/"
    for (k, v) in data
        startswith(k, prefix) || continue
        v isa Number || continue
        out[k[(length(prefix) + 1):end]] = Float64(v)
    end
    # Fallback: top-level `E_decomp` Dict from operator_rhs.jld2.
    if isempty(out) && haskey(data, "E_decomp") && data["E_decomp"] isa Dict
        for (k, v) in data["E_decomp"]
            v isa Number && (out[String(k)] = Float64(v))
        end
    end
    out
end

function _extract_metadata(data::Dict)
    meta = Dict{String, Any}()
    for (k, v) in data
        # Capture env/* and units/* and top-level scalar/string fields.
        if startswith(k, "env/") || startswith(k, "units/")
            meta[k] = v
        elseif k in ("converged", "energy", "duration_seconds",
            "started_at", "finished_at", "run_name", "scan_index")
            meta[k] = v
        elseif k == "conventions"
            meta["conventions"] = v
        end
    end
    meta
end
