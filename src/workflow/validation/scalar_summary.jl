# --- run_scalar_summary: byte-identical scalar projection of a RunResult ---
#
# The catalog/index navigates thousands of runs by querying small per-run
# scalars, NOT by opening jld2 (slow) or traversing folders. This file
# produces that projection: a sparse bag of recipe-cross observables
# derived from the SAME persisted representation a backfill would read
# (`open_result(jld2) → RunResult`). So a run's freshly-emitted summary
# (write-time) and a later backfilled one read the same bytes and agree —
# no drift between the two call sites.
#
# Defensive by construction. Ground-state runs have no dynamics (the
# drift accessors throw); legacy jld2 layouts drift across months of dev;
# truncated/corrupt files exist. Every field is best-effort and failures
# land in `extraction_error` rather than throwing, so one bad run never
# stops a 262-run backfill. Truth stays in the jld2 — summary.json is a
# regenerable projection; bump RUN_SUMMARY_EXTRACTOR_VERSION and re-emit
# to fix any drift.

import JSON

export run_scalar_summary, write_run_summary,
    RUN_SUMMARY_FILENAME, RUN_SUMMARY_EXTRACTOR_VERSION

const RUN_SUMMARY_FILENAME = "summary.json"
# Bump when extraction logic changes so stale summaries (older extractor)
# can be targeted for re-backfill via `_extractor_version`.
const RUN_SUMMARY_EXTRACTOR_VERSION = "2"  # v2: + rotation-invariant mF

# Run `f()`; on exception record "field: reason" in `errs` and return
# `missing`. A `nothing` / non-finite result is treated as legitimately
# absent (missing, no error) so "absent" and "errored" stay distinct.
function _try_field(errs::Vector{String}, field::AbstractString, f)
    try
        v = f()
        v === nothing && return missing
        (v isa Real && !isfinite(v)) && return missing
        v
    catch e
        push!(errs, "$field: $(sprint(showerror, e))")
        missing
    end
end

"""
    run_scalar_summary(r::RunResult) -> Dict{String, Any}

Sparse bag of recipe-cross scalars derived from the persisted
wavefunction + metadata. Never throws. Keys appear only when extractable:

  ndim, F, n_points          — structural facets (grid / atom)
  energy, converged          — ground-state metadata / e_decomp / dynamics
  norm, Mz                   — computed from psi (deterministic)
  populations                — per-component |c_m|² fractions (Vector)
  norm_rel_drift,
  energy_rel_drift, Fz_drift — dynamics runs only

Always includes `extraction_error` (Vector{String}, empty when clean), so
extraction failure is a first-class, queryable facet rather than a silent
gap.
"""
function run_scalar_summary(r::RunResult)
    errs = String[]
    bag = Dict{String, Any}()

    # Structural facets — from the typed struct, cheap.
    bag["ndim"] = _try_field(errs, "ndim", () -> ndims(r.psi) - 1)
    bag["F"] = _try_field(errs, "F", () -> r.atom.F)
    bag["n_points"] = _try_field(errs, "n_points", () -> collect(Int, r.grid.config.n_points))

    # Persisted scalars: ground-state path writes energy/converged into
    # metadata; fall back to the e_decomp total or the dynamics terminal.
    bag["energy"] = _try_field(errs, "energy", () -> begin
        e = get(r.metadata, "energy", nothing)
        if e isa Real && isfinite(e)
            Float64(e)
        elseif haskey(r.e_decomp, "total")
            r.e_decomp["total"]
        else
            r.energy   # dynamics terminal; throws if no dynamics → missing
        end
    end)
    bag["converged"] = _try_field(
        errs, "converged", () -> begin
            c = get(r.metadata, "converged", nothing)
            c === nothing ? missing : Bool(c)
        end
    )

    # Derived from psi — deterministic, identical for new vs backfilled.
    bag["norm"] = _try_field(errs, "norm", () -> Float64(sum(abs2, r.psi)))
    bag["Mz"] = _try_field(errs, "Mz",
        () -> magnetization(r.psi, r.grid, SpinSystem(r.atom.F)))
    bag["populations"] = _try_field(errs, "populations", () -> begin
        Nm = spin_populations(r.psi)
        tot = sum(Nm)
        tot > 0 ? Nm ./ tot : Nm
    end)
    # Rotation-invariant order parameter mF = |⟨F⟩|/F of the peak-density (bulk)
    # spinor. Unlike Mz (=⟨F_z⟩), this stays correct when the FM state lies in the
    # xy-plane (B=0 DDI soft manifold) — the FM↔polar order variable. Carrying it
    # here lets a phase scan read the order parameter straight from summary.json,
    # never loading the heavy psi (Stage 1 / "graphs are the deliverable").
    bag["mF"] = _try_field(
        errs,
        "mF",
        () -> begin
            F = r.atom.F
            D = 2F + 1
            sdim = ndims(r.psi)
            dens = dropdims(sum(abs2, r.psi; dims=sdim); dims=sdim)
            z = ComplexF64[r.psi[argmax(dens), c] for c in 1:D]
            nz = norm(z)
            nz > 0 || return missing
            z ./= nz
            sm = spin_matrices(F)
            sqrt(
                real(dot(z, sm.Fx * z))^2 + real(dot(z, sm.Fy * z))^2 +
                real(dot(z, sm.Fz * z))^2,
            ) / F
        end,
    )

    # Dynamics-only drift metrics (getproperty throws without a series).
    if r.dynamics !== nothing
        bag["norm_rel_drift"] = _try_field(errs, "norm_rel_drift", () -> r.norm_rel_drift)
        bag["energy_rel_drift"] = _try_field(errs, "energy_rel_drift", () -> r.energy_rel_drift)
        bag["Fz_drift"] = _try_field(errs, "Fz_drift", () -> r.Fz_drift)
    end

    # Drop missing so the bag stays sparse; extraction_error explains gaps.
    for k in collect(keys(bag))
        bag[k] === missing && delete!(bag, k)
    end
    bag["extraction_error"] = errs
    return bag
end

"""
    write_run_summary(run_dir, jld2_path; source="backfill") -> String

Emit `<run_dir>/summary.json`: `run_scalar_summary(open_result(jld2))`
plus a best-effort collapse class from the streamed snapshots, stamped
with extractor version / source / time. Called at write-time
(`source="finish_hook"`) and at backfill (`source="backfill"`); both read
the same persisted jld2 so the two summaries are identical.

Never throws on extraction problems — a failed open or a corrupt frame is
recorded in `extraction_error` and a (partial) summary is still written,
so a single bad run can't stall a bulk backfill.
"""
function write_run_summary(run_dir::AbstractString, jld2_path::AbstractString;
    source::AbstractString="backfill")
    errs = String[]
    r = _try_field(errs, "open_result", () -> open_result(jld2_path))
    bag = r === missing ? Dict{String, Any}() : run_scalar_summary(r)

    # Collapse class needs the streamed peak-density trajectory, which the
    # RunResult abstraction drops — read it from the same jld2 (still
    # drift-free). N(T)/N(0) ratio from the dynamics norms when available.
    collapse = _try_field(
        errs,
        "collapsed",
        () -> begin
            peaks = peak_density_trajectory(jld2_path)
            isempty(peaks) && return missing
            nratio = if (r !== missing && r.dynamics !== nothing &&
                         !isempty(r.dynamics.norms))
                (r.dynamics.norms[end] / max(r.dynamics.norms[1], 1e-30))
            else
                1.0
            end
            String(classify_collapse(peaks, nratio))
        end,
    )
    collapse !== missing && (bag["collapsed"] = collapse)

    # Merge writer-level errors with run_scalar_summary's own list.
    bag["extraction_error"] = vcat(get(bag, "extraction_error", String[]), errs)
    bag["_extractor_version"] = RUN_SUMMARY_EXTRACTOR_VERSION
    bag["_source"] = String(source)
    bag["_extracted_at"] = string(now())

    isdir(run_dir) || mkpath(run_dir)
    path = joinpath(run_dir, RUN_SUMMARY_FILENAME)
    open(path, "w") do io
        JSON.print(io, bag, 2)
    end
    return path
end
