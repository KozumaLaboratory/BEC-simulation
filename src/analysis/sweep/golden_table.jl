# Golden per-cell table emitter + VSUP alpha-fade quality resolution.
#
# `write_golden_per_cell_table` materialises the resolved per-cell table for
# golden gating (raw value + fill hex + dominant-m decision gap). `compute_quality_alpha`
# is the alpha-fade subset of VSUP, shared with `to_viewspec` so the dashboard and
# the golden gate agree on opacity.

export write_golden_per_cell_table,
    compute_quality_alpha

# --- Golden per-cell table --------------------------------------------

"""
    write_golden_per_cell_table(out_path, result::SweepResult;
        signed_clip=Dict(), positive_clip=Dict(),
        spectrum_margin=0.1, F=6,
        quality_threshold=1e-5,
        quality_dynamic_range_decades=4.0)

Materialise the resolved per-cell table for golden gating. Each row
carries the raw value, the resolved fill hex, and (for spectrum
observables) the dominant-m + decision-margin gap.

  * `signed_clip` — dict observable_key => (vmin, vmax). Default is
    `(-F, +F)` for signed observables (fixed physical bound, comparable
    across runs); override via the YAML defaults layer when contrast
    tuning is needed.
  * `positive_clip` — dict observable_key => (vmin, vmax). No default;
    if absent, computed from converged-only data on the fly with robust
    quantile (5th, 95th percentile).
  * `spectrum_margin` — passed through to `dominant_m_with_margin`.
  * `quality_threshold` / `quality_dynamic_range_decades` — VSUP alpha
    fade parameters for the `role=:quality` observable. Match the
    defaults used in `to_viewspec` so the dashboard and golden gate
    agree on opacity.

Schema v1.1 emits `quality_alpha::Float64 ∈ [0, 1]` as a SEPARATE field
from `<key>_fill_hex` so renderers compose value + uncertainty at paint
time (Vega-Lite `fillOpacity`, Makie `RGBA`), and the gate diffs them
independently. The cheap `masked::Bool` (derived from the conv flag)
is retained as a legacy field — old gates that only test convergence
keep working without re-keying.
"""
function write_golden_per_cell_table(out_path::String, result::SweepResult;
    signed_clip::Dict=Dict(),
    positive_clip::Dict=Dict(),
    spectrum_margin::Real=0.1,
    F::Int=6,
    quality_threshold::Real=1e-5,
    quality_dynamic_range_decades::Real=4.0)
    axes_block = Dict{String, Any}()
    for ax in result.axes
        axes_block[String(ax.name)] = Dict(
            "scale" => String(ax.scale),
            "unit" => ax.unit,
            "values" => ax.values,
        )
    end

    observables_block = Dict{String, Any}()
    for obs in result.observables
        b = Dict{String, Any}(
            "kind" => String(obs.kind),
            "scale" => String(obs.scale),
            "role" => String(obs.role),
            "label" => obs.label,
            "colormap_version" => SWEEP_COLORMAP_VERSION,
        )
        obs.center !== nothing && (b["center"] = obs.center)
        obs.index !== nothing && (b["index"] = String(obs.index))
        # Resolve clip + colormap_name
        if obs.kind === :signed
            vmin, vmax = get(signed_clip, obs.key, (-Float64(F), Float64(F)))
            b["vmin"] = vmin
            b["vmax"] = vmax
            b["colormap"] = "cmocean.balance"
        elseif obs.kind === :positive || obs.kind === :wide
            if haskey(positive_clip, obs.key)
                vmin, vmax = positive_clip[obs.key]
            else
                # Robust quantile from converged-only
                conv_col = get(result.meta, :conv_column, nothing)
                vals = Float64[]
                for r in result.data
                    if conv_col === nothing || (haskey(r, conv_col) && Bool(r[conv_col]))
                        v = get(r, obs.key, NaN)
                        v isa Real && isfinite(v) && push!(vals, float(v))
                    end
                end
                if isempty(vals)
                    vmin, vmax = 0.0, 1.0
                else
                    sort!(vals)
                    p05 = vals[max(1, ceil(Int, 0.05 * length(vals)))]
                    p95 = vals[min(length(vals), ceil(Int, 0.95 * length(vals)))]
                    vmin, vmax = float(p05), float(p95)
                    vmax > vmin || (vmax = vmin + 1.0)
                end
            end
            b["vmin"] = vmin
            b["vmax"] = vmax
            b["colormap"] = "viridis"
        elseif obs.kind === :spectrum
            b["margin"] = spectrum_margin
            b["mixed_hex"] = "#9aa0a6"
        end
        observables_block[String(obs.key)] = b
    end

    quality_obs = let qs = filter(o -> o.role === :quality, result.observables)
        isempty(qs) ? nothing : first(qs)
    end

    cells = Vector{Dict{String, Any}}()
    for row in result.data
        cell = Dict{String, Any}()
        for ax in result.axes
            cell[String(ax.name)] = row[ax.name]
        end
        # Single per-cell quality_alpha (one float in [0, 1]) computed
        # from the role=:quality observable, if any. Kept separate from
        # `<key>_fill_hex` so paint-time composition is the same on every
        # renderer. Convention: lower quality value = better (the canonical
        # case is `‖∇E‖`); fidelity-style "higher = better" observables
        # would need a SweepObservable field extension before they fit.
        if quality_obs !== nothing
            qv = get(row, quality_obs.key, NaN)
            cell["quality_alpha"] = compute_quality_alpha(
                qv isa Real ? float(qv) : NaN;
                threshold=quality_threshold,
                dynamic_range_decades=quality_dynamic_range_decades,
                good_low=true,
            )
        else
            cell["quality_alpha"] = 1.0
        end
        for obs in result.observables
            v = row[obs.key]
            if obs.kind === :signed
                cell[String(obs.key)] = v
                cell[string(obs.key, "_fill_hex")] = resolve_signed_cell_hex(
                    v, observables_block[String(obs.key)]["vmin"],
                    observables_block[String(obs.key)]["vmax"])
            elseif obs.kind === :positive || obs.kind === :wide
                cell[String(obs.key)] = v
                cell[string(obs.key, "_fill_hex")] = resolve_positive_cell_hex(
                    v, observables_block[String(obs.key)]["vmin"],
                    observables_block[String(obs.key)]["vmax"];
                    scale=obs.scale)
            elseif obs.kind === :spectrum
                # v is a Vector{Float64}; need the m_values from the obs index
                m_vals = collect(F:-1:(-F))
                dom = dominant_m_with_margin(v, m_vals; margin=spectrum_margin)
                top_perm = sortperm(v; rev=true)
                gap = length(v) >= 2 ?
                      (v[top_perm[1]] - v[top_perm[2]]) : v[top_perm[1]]
                cell[string(obs.key, "_dominant_m")] = dom === :mixed ?
                                                       "mixed" : dom
                cell[string(obs.key, "_decision_gap")] = gap
            elseif obs.kind === :categorical
                cell[String(obs.key)] = v
            end
        end
        # masked column today is a bool, derived from conv flag if any.
        # Tomorrow's VSUP schema adds a separate `quality_alpha::Float64`
        # field — fill_hex above is NOT pre-composited with quality.
        conv_col = get(result.meta, :conv_column, nothing)
        if conv_col !== nothing && haskey(row, conv_col)
            cell["masked"] = !Bool(row[conv_col])
        end
        push!(cells, cell)
    end

    bag = Dict{String, Any}(
        "schema_version" => "1.1",
        "schema_note" =>
            "v1.1: each cell carries `quality_alpha::Float64 ∈ [0,1]` as " *
            "a separate field (NOT pre-composited into <key>_fill_hex). " *
            "`masked::Bool` retained as a legacy convenience derived " *
            "from the conv flag.",
        "colormap_version" => SWEEP_COLORMAP_VERSION,
        "F" => F,
        "quality_observable" => quality_obs === nothing ? nothing :
                                String(quality_obs.key),
        "quality_threshold" => float(quality_threshold),
        "quality_dynamic_range_decades" => float(quality_dynamic_range_decades),
        "axes" => axes_block,
        "observables" => observables_block,
        "cells" => cells,
        # Skip `:narrative` here — the Hypothesis struct holds closures
        # (model_fn, collapse_var_fn) which JSON can't serialise. The
        # viewspec builder takes care of emitting a printable hypothesis
        # block (`spec._meta.narrative.hypothesis` = labels only).
        "meta" => Dict(String(k) => v for (k, v) in result.meta
                                          if k !== :narrative),
    )

    mkpath(dirname(out_path))
    open(out_path, "w") do io
        JSON.print(io, bag)
    end
    return out_path
end

# --- Quality alpha (VSUP-lite) ----------------------------------------

"""
    compute_quality_alpha(quality_value; threshold, dynamic_range_decades=4.0,
                          good_low=true) → Float64

Map a `role=:quality` observable (e.g. `‖∇E‖`) to an opacity in [0, 1]
for VSUP-style composition. The fill_hex resolved from the value is
**unchanged**; the renderer multiplies opacity at paint time.

  * `threshold` — the value below (if `good_low=true`) or above which the
    cell is fully opaque (e.g. `‖∇E‖ < tol = 1e-5` → α = 1).
  * `dynamic_range_decades` — log10 dynamic range over which alpha fades
    from 1 → 0. With 4 decades, `‖∇E‖ = 10⁴·tol` lands at α = 0.

This is the alpha-fade subset of VSUP (Correll, Moritz & Heer 2018);
the full tree quantization (uncertainty-driven binning of the LUT) is
scheduled separately. Alpha-fade composes correctly through Vega-Lite
opacity encoding and Makie's `color = RGBA(...)` channels.

NaN quality → α = 0 (fully transparent so the missing-data sentinel is
visible).
"""
function compute_quality_alpha(quality_value::Real;
    threshold::Real, dynamic_range_decades::Real=4.0, good_low::Bool=true)
    isnan(quality_value) && return 0.0
    if good_low
        # Smaller is better (e.g. ‖∇E‖); cells with q ≤ threshold get α=1.
        q = max(quality_value, eps())
        t = max(threshold, eps())
        x = (log10(q) - log10(t)) / dynamic_range_decades
        return clamp(1.0 - x, 0.0, 1.0)
    else
        q = max(quality_value, eps())
        t = max(threshold, eps())
        x = (log10(t) - log10(q)) / dynamic_range_decades
        return clamp(1.0 - x, 0.0, 1.0)
    end
end
