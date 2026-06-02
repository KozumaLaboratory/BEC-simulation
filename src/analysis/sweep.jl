# Sweep result contract + dominant-m + reference colormap LUTs.
#
# This file is the *data side* of the sweep-view system. It defines:
#
#   * `SweepResult{T}` — the tidy carrier (axes + observables + per-cell data
#     + meta). Single source of truth that both the dashboard `to_viewspec`
#     pipeline and Makie `plot_sweep` consume.
#   * `SweepAxis{T}` / `SweepObservable` — declared structure of the sweep.
#     Notably `m` is NOT a sweep axis; it lives inside a `spectrum`-kind
#     observable's `index` slot. `view_shape` dispatch is keyed on
#     `count(length(a.values) > 1 for a in axes)` and putting `m` in `axes`
#     would silently break it.
#   * `dominant_m_with_margin` — margin-based dominant-m extraction. NOT a
#     purity threshold (which fails on 2-state 50-50 because `max >= 0.5`
#     always — see `docs/architecture/sweep_view.md` for the failure mode).
#   * Minimal reference colormap LUTs (cmocean `balance` for signed,
#     viridis for positive). These are computed once and frozen so future
#     versions can `colormap_version: "1.0"` for reproducibility gates.
#
# The viewspec resolver (`to_viewspec(::SweepResult; defaults)`) is
# scheduled separately and reads this module's outputs; it is NOT here.

using JSON

export SweepAxis,
    SweepObservable,
    SweepResult,
    dominant_m_with_margin,
    sweep_balance_lut,
    sweep_viridis_lut,
    resolve_signed_cell_hex,
    resolve_positive_cell_hex,
    write_golden_per_cell_table

# --- Contract types ----------------------------------------------------

"""
    SweepAxis{T}(name, unit, scale, values)

A single swept control parameter. `scale ∈ (:linear, :log)` drives both
the plot axis and the colorbar tick layout. `m` (spinor component index)
is NOT a SweepAxis — it lives inside a spectrum-kind observable.
"""
struct SweepAxis{T}
    name::Symbol
    unit::String
    scale::Symbol
    values::Vector{T}

    function SweepAxis{T}(name::Symbol, unit::String, scale::Symbol,
        values::Vector{T}) where {T}
        scale in (:linear, :log) || throw(ArgumentError(
            "SweepAxis scale must be :linear or :log, got :$scale"))
        new{T}(name, unit, scale, values)
    end
end
SweepAxis(name::Symbol, unit::String, scale::Symbol, values::AbstractVector) =
    SweepAxis{eltype(values)}(name, unit, scale, collect(values))

"""
    SweepObservable(key, label; kind, scale, role, center, oracle, index)

A measured quantity at each cell. `kind` drives the colormap, `role`
drives masking / VSUP, `center`/`oracle` drive reference lines, `index`
is set for `kind=:spectrum` (e.g. `index=:m` for per-m populations).
"""
Base.@kwdef struct SweepObservable
    key::Symbol
    label::String = String(key)
    kind::Symbol                  # :signed | :positive | :wide | :categorical | :spectrum
    scale::Symbol = :linear       # :linear | :log
    role::Symbol = :data          # :data | :quality | :mask
    center::Union{Nothing, Float64} = nothing
    oracle::Union{Nothing, Float64} = nothing
    oracle_label::Union{Nothing, String} = nothing
    index::Union{Nothing, Symbol} = nothing
end

"""
    SweepResult(axes, observables, data; meta=Dict())

Tidy carrier: `data` is a `Vector{Dict{Symbol,Any}}` of cell records.
Each dict has one entry per axis name (the swept coordinate values) and
one per observable key (a scalar for kind ∈ (signed, positive, wide,
categorical), a `Vector{Float64}` for kind=spectrum). Vector-of-Dict
chosen over DataFrame to keep the analysis module dependency-free.
"""
struct SweepResult
    axes::Vector{SweepAxis}
    observables::Vector{SweepObservable}
    data::Vector{Dict{Symbol, Any}}
    meta::Dict{Symbol, Any}

    function SweepResult(axes::Vector{<:SweepAxis},
        observables::Vector{SweepObservable},
        data::Vector{Dict{Symbol, Any}};
        meta::Dict{Symbol, Any}=Dict{Symbol, Any}())
        axes_cv = SweepAxis[a for a in axes]
        new(axes_cv, observables, data, meta)
    end
end

# --- Dominant-m via decision margin -----------------------------------

"""
    dominant_m_with_margin(populations, m_values; margin=0.1) -> Symbol | Int

Return the dominant `m` from a populations vector, but commit to `:mixed`
when the top-1 / top-2 gap is below `margin`. Margin-based avoids the
50-50 snap-and-flip failure that an absolute purity threshold has (a
2-state populations vector always has `max(populations) >= 0.5`, so an
absolute `purity < 0.5` threshold never triggers and the cell flips
between m_argmax and the other state with infinitesimal noise).

Default `margin = 0.1` means the top component must lead the next by
10 percentage points to be called dominant. 50-50 → gap 0 → `:mixed`;
49-51 → gap 0.02 → `:mixed`; 70-15-15 → gap 0.55 → dominant.
"""
function dominant_m_with_margin(populations::AbstractVector{<:Real},
    m_values::AbstractVector;
    margin::Real=0.1)
    length(populations) == length(m_values) || throw(DimensionMismatch(
        "populations and m_values must be the same length"))
    isempty(populations) && return :mixed
    perm = sortperm(populations; rev=true)
    top1 = populations[perm[1]]
    top2 = length(populations) >= 2 ? populations[perm[2]] : 0.0
    gap = top1 - top2
    return gap < margin ? :mixed : m_values[perm[1]]
end

# --- Reference colormap LUTs (frozen for reproducibility) -------------

"""
    sweep_balance_lut(n=256) -> Vector{NTuple{3, UInt8}}

cmocean `balance` LUT, sampled at `n` points. Perceptually uniform
diverging (deep blue → off-white → deep red), suitable for signed
observables centred at 0 with symmetric clip.

Values are an inline 11-stop sampling of the published cmocean balance
(Crameri & Hartley 2020). For renderer comparison gates the
`colormap_version` field in the golden table pins this exact LUT.
"""
function sweep_balance_lut(n::Int=256)
    stops = [
        (0.0, (24, 28, 67)),
        (0.1, (33, 60, 109)),
        (0.2, (42, 93, 152)),
        (0.3, (75, 126, 174)),
        (0.4, (140, 168, 198)),
        (0.5, (235, 235, 230)),
        (0.6, (210, 154, 142)),
        (0.7, (192, 96, 85)),
        (0.8, (165, 45, 47)),
        (0.9, (113, 19, 33)),
        (1.0, (60, 8, 20)),
    ]
    _interp_lut(stops, n)
end

"""
    sweep_viridis_lut(n=256) -> Vector{NTuple{3, UInt8}}

Viridis LUT (deep purple → teal → bright yellow), sampled at `n` points.
Perceptually uniform monotonic; suitable for positive / monotone
observables (E, f_max, ‖∇E‖ with `scale=:log`).
"""
function sweep_viridis_lut(n::Int=256)
    stops = [
        (0.0, (68, 1, 84)),
        (0.1, (72, 35, 116)),
        (0.2, (64, 67, 135)),
        (0.3, (52, 94, 141)),
        (0.4, (41, 121, 142)),
        (0.5, (32, 144, 140)),
        (0.6, (34, 167, 132)),
        (0.7, (68, 190, 112)),
        (0.8, (121, 209, 81)),
        (0.9, (189, 222, 38)),
        (1.0, (253, 231, 36)),
    ]
    _interp_lut(stops, n)
end

function _interp_lut(stops, n::Int)
    out = Vector{NTuple{3, UInt8}}(undef, n)
    for i in 1:n
        t = (i - 1) / (n - 1)
        # find bracketing stops
        idx = findlast(s -> first(s) <= t, stops)
        idx === nothing && (idx = 1)
        idx == length(stops) && (idx = length(stops) - 1)
        s0, c0 = stops[idx]
        s1, c1 = stops[idx + 1]
        u = (t - s0) / max(s1 - s0, eps())
        r = clamp(round(Int, c0[1] * (1 - u) + c1[1] * u), 0, 255)
        g = clamp(round(Int, c0[2] * (1 - u) + c1[2] * u), 0, 255)
        b = clamp(round(Int, c0[3] * (1 - u) + c1[3] * u), 0, 255)
        out[i] = (UInt8(r), UInt8(g), UInt8(b))
    end
    return out
end

const SWEEP_COLORMAP_VERSION = "1.0"

# --- Resolve per-cell hex ---------------------------------------------

"""
    resolve_signed_cell_hex(value, vmin, vmax; lut=sweep_balance_lut())
        -> String

Return the per-cell fill hex for a signed observable. NaN → neutral
grey (#9aa0a6) so unresolved cells are visibly distinct from oracle
centre. Out-of-clip values saturate to the LUT endpoint, NOT extrapolate.
"""
function resolve_signed_cell_hex(value::Real, vmin::Real, vmax::Real;
    lut::Vector{NTuple{3, UInt8}}=sweep_balance_lut())
    isnan(value) && return "#9aa0a6"
    t = (value - vmin) / max(vmax - vmin, eps())
    t = clamp(t, 0.0, 1.0)
    idx = clamp(round(Int, t * (length(lut) - 1)) + 1, 1, length(lut))
    r, g, b = lut[idx]
    return string("#",
        lpad(string(r; base=16), 2, '0'),
        lpad(string(g; base=16), 2, '0'),
        lpad(string(b; base=16), 2, '0'))
end

"""
    resolve_positive_cell_hex(value, vmin, vmax; scale=:linear,
                              lut=sweep_viridis_lut()) -> String
"""
function resolve_positive_cell_hex(value::Real, vmin::Real, vmax::Real;
    scale::Symbol=:linear,
    lut::Vector{NTuple{3, UInt8}}=sweep_viridis_lut())
    isnan(value) && return "#9aa0a6"
    t = if scale === :log
        v = max(value, eps())
        vn = max(vmin, eps())
        vx = max(vmax, eps())
        (log10(v) - log10(vn)) / max(log10(vx) - log10(vn), eps())
    else
        (value - vmin) / max(vmax - vmin, eps())
    end
    t = clamp(t, 0.0, 1.0)
    idx = clamp(round(Int, t * (length(lut) - 1)) + 1, 1, length(lut))
    r, g, b = lut[idx]
    return string("#",
        lpad(string(r; base=16), 2, '0'),
        lpad(string(g; base=16), 2, '0'),
        lpad(string(b; base=16), 2, '0'))
end

# --- Golden per-cell table --------------------------------------------

"""
    write_golden_per_cell_table(out_path, result::SweepResult;
        signed_clip=Dict(), positive_clip=Dict(),
        spectrum_margin=0.1, F=6)

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

Schema includes `masked: bool` today; tomorrow's VSUP-aware schema will
add `quality_alpha: float` AS A SEPARATE FIELD (not merged into
fill_hex) so the renderer composes value + uncertainty at paint time,
and the gate diffs them independently.
"""
function write_golden_per_cell_table(out_path::String, result::SweepResult;
    signed_clip::Dict=Dict(),
    positive_clip::Dict=Dict(),
    spectrum_margin::Real=0.1,
    F::Int=6)
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
        obs.oracle !== nothing && (b["oracle"] = obs.oracle)
        obs.oracle_label !== nothing && (b["oracle_label"] = obs.oracle_label)
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

    cells = Vector{Dict{String, Any}}()
    for row in result.data
        cell = Dict{String, Any}()
        for ax in result.axes
            cell[String(ax.name)] = row[ax.name]
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
        "schema_version" => "1.0",
        "schema_note" =>
            "today's `masked` is bool; tomorrow's VSUP " *
            "schema adds `quality_alpha::Float64` as a " *
            "separate field (fill_hex unchanged)",
        "colormap_version" => SWEEP_COLORMAP_VERSION,
        "F" => F,
        "axes" => axes_block,
        "observables" => observables_block,
        "cells" => cells,
        "meta" => Dict(String(k) => v for (k, v) in result.meta),
    )

    mkpath(dirname(out_path))
    open(out_path, "w") do io
        JSON.print(io, bag)
    end
    return out_path
end
