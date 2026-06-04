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
#   * `to_viewspec(::SweepResult; ...)` — the dispatcher resolver. Picks
#     view_shape, resolves per-cell fill/quality_alpha/edges, emits a
#     Vega-Lite spec (Dict; serialise with JSON.print). Renderers paint
#     the spec, they do not decide.
#   * `compute_quality_alpha(role_quality_value, threshold, dynamic_range)` —
#     VSUP-lite: alpha-fade from a quality-role observable. Full VSUP
#     tree quantization is a follow-up; alpha-fade composes correctly
#     with Vega's opacity encoding today.

using JSON

export SweepAxis,
    SweepObservable,
    SweepResult,
    ModelSpec,
    Hypothesis,
    dominant_m_with_margin,
    sweep_balance_lut,
    sweep_viridis_lut,
    resolve_signed_cell_hex,
    resolve_positive_cell_hex,
    write_golden_per_cell_table,
    to_viewspec,
    write_viewspec,
    compute_quality_alpha

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
    SweepObservable(key, label; kind, scale, role, center, index)

A measured quantity at each cell. INTRINSIC fields only: what the
quantity *is*, not what a particular sweep *predicts* for it.

  * `kind` drives the colormap, `role` drives masking / VSUP,
    `center` drives diverging-palette centring,
  * `index` is set for `kind=:spectrum` (e.g. `index=:m` for per-m
    populations).

Hypothesis-relative properties (oracle, predicted curve, regime label)
live on the [`Hypothesis`](@ref) block — the same observable can carry
different theoretical expectations in different sweeps.
"""
Base.@kwdef struct SweepObservable
    key::Symbol
    label::String = String(key)
    kind::Symbol                  # :signed | :positive | :wide | :categorical | :spectrum
    scale::Symbol = :linear       # :linear | :log
    role::Symbol = :data          # :data | :quality | :mask
    center::Union{Nothing, Float64} = nothing
    index::Union{Nothing, Symbol} = nothing
end

# --- Hypothesis / model contract ---------------------------------------

"""
    ModelSpec(; fn, label, collapse_var_fn=nothing, collapse_var_label=nothing)

Theoretical prediction for one observable under one hypothesis.

  * `fn::Function` — `(axes::NamedTuple) -> predicted_value`. Pure
    function of the axis NamedTuple; closures over global constants are
    fine.
  * `label::String` — display label for the prediction (e.g.
    `"F·Ω·ℏω_ref / (g_F μ_B B)"`).
  * `collapse_var_fn::Union{Nothing, Function}` — optional dimensionless
    collapse variable `(axes::NamedTuple) -> x`. Used by `:collapse`
    relation. Distinct from `fn`: `fn` predicts the observable, `collapse_var_fn`
    declares "this is the dimensionless group I claim governs the data".
    When both are set, theory in collapse coords is parametric: for each
    sampled (B, Ω), plot `(collapse_var_fn(axes), fn(axes))`. If `fn`
    factors through `collapse_var_fn`, the curve is sharp; if not, it
    forms a band (diagnostic of wrong-variable choice).
  * `collapse_var_label::Union{Nothing, String}` — display label for the
    collapse variable (x-axis of the collapse plot).
"""
Base.@kwdef struct ModelSpec
    fn::Function
    label::String
    collapse_var_fn::Union{Nothing, Function} = nothing
    collapse_var_label::Union{Nothing, String} = nothing
end

"""
    Hypothesis(; question, relation, primary_obs, models, params=Dict())

The sweep's question + theoretical apparatus. Replaces the old
`narrative.expected` block; sits as `meta[:hypothesis]` on the
[`SweepResult`](@ref).

  * `question::String` — natural-language statement, rendered as the
    headline subtitle ("Q: Does ⟨F_z⟩ → 0.24 at high B?").
  * `relation::Symbol` — which inference instrument the dispatcher
    should build as the primary view. One of:
    - `:asymptote`  — line plot vs axis, horizontal limit rule.
    - `:collapse`   — scatter on dimensionless x, theory envelope.
    - `:residual`   — `observed - predicted` heatmap or line.
    - `:scaling`    — log-log of |observed| or |residual| vs axis.
    - `:correlation`— scatter `primary_obs` vs `params[:obs_y]`.
  * `primary_obs::Symbol` — which observable's prediction is being
    tested. Drives the headline panel.
  * `models::Dict{Symbol, ModelSpec}` — one ModelSpec per observable key
    that has a theoretical prediction in this hypothesis. Missing entries
    are fine (e.g. only `models[primary_obs]` is set).
  * `params::Dict{Symbol, Any}` — relation-specific knobs:
    - `:asymptote` reads `params[:axis]` (defaults to first swept axis),
      `params[:reference]` (NamedTuple for oracle eval; defaults to
      data-extremum cell).
    - `:correlation` reads `params[:obs_y]` (required).
    - `:scaling` reads `params[:exponent]` (predicted slope) and
      `params[:base_axis]` (which axis is the log-log x).
"""
Base.@kwdef struct Hypothesis
    question::String = ""
    relation::Symbol                  # :asymptote | :collapse | :residual | :scaling | :correlation
    primary_obs::Symbol
    models::Dict{Symbol, ModelSpec} = Dict{Symbol, ModelSpec}()
    params::Dict{Symbol, Any} = Dict{Symbol, Any}()
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

# Serialise a LUT as a hex-string vector so Vega-Lite can drive its own
# `scale.range`. This is the single point where the dispatcher hands the
# LUT to the renderer; the renderer does only the value→colour lookup
# (mechanical), not the LUT choice (dispatcher decision).
function _lut_hex_array(lut::Vector{NTuple{3, UInt8}})
    return [
        string("#",
            lpad(string(r; base=16), 2, '0'),
            lpad(string(g; base=16), 2, '0'),
            lpad(string(b; base=16), 2, '0'))
        for (r, g, b) in lut
    ]
end

# Diverging blue→grey→red palette for dominant-m in [-F, +F]. Physical
# meaning: -F (full m_- pin) at deep blue, m=0 (zero magnetization) at
# off-white, +F (full m_+ pin) at deep red. "mixed" sits in neutral grey
# so it reads as "no decision" rather than "extreme".
function _dominant_m_palette(F::Int)
    n = 2F + 1
    out = Vector{String}(undef, n)
    for (i, m) in enumerate(F:-1:-F)
        t = (Float64(m) + F) / (2F)  # m=+F → t=1, m=-F → t=0
        r = round(Int, 60 * (1 - t) + 165 * t)
        g = round(Int, 8 * (1 - t) + 45 * t)
        b = round(Int, 20 * (1 - t) + 47 * t)
        # Brighten toward the middle so m=0 isn't lost
        u = 1 - abs(t - 0.5) * 2  # peaks at t=0.5
        r = clamp(round(Int, r * (1 - 0.55u) + 235 * 0.55u), 0, 255)
        g = clamp(round(Int, g * (1 - 0.55u) + 235 * 0.55u), 0, 255)
        b = clamp(round(Int, b * (1 - 0.55u) + 230 * 0.55u), 0, 255)
        out[i] = string("#", lpad(string(r; base=16), 2, '0'),
            lpad(string(g; base=16), 2, '0'),
            lpad(string(b; base=16), 2, '0'))
    end
    return out
end

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

# --- Cell edges (axis-aware) ------------------------------------------

# Compute (lo, hi) edges per axis value. For log scale, B=0 is mapped to
# a sentinel one decade below the first positive value (Vega can't take
# log(0)); this is reflected in the axis ticks below. For linear scale,
# edges are arithmetic midpoints between adjacent values.
function _cell_edges(values::Vector{<:Real}, scale::Symbol)
    n = length(values)
    n >= 1 || return Float64[], Float64[]
    if scale === :linear
        if n == 1
            δ = abs(values[1]) > 0 ? abs(values[1]) * 0.1 : 0.5
            return [values[1] - δ], [values[1] + δ]
        end
        edges = Vector{Float64}(undef, n + 1)
        edges[1] = values[1] - (values[2] - values[1]) / 2
        edges[end] = values[end] + (values[end] - values[end - 1]) / 2
        for i in 2:n
            edges[i] = (values[i - 1] + values[i]) / 2
        end
        return edges[1:n], edges[2:(n + 1)]
    elseif scale === :log
        # Find sentinel for v == 0
        positives = filter(v -> v > 0, values)
        sentinel = isempty(positives) ? 1e-2 : minimum(positives) / 10
        # Substitute sentinel for any 0 values, retain order
        coords = [v > 0 ? float(v) : sentinel for v in values]
        # Compute log-space midpoints
        edges = Vector{Float64}(undef, n + 1)
        edges[1] = exp10(log10(coords[1]) - (log10(coords[2]) - log10(coords[1])) / 2)
        edges[end] = exp10(log10(coords[end]) +
                           (log10(coords[end]) - log10(coords[end - 1])) / 2)
        for i in 2:n
            edges[i] = exp10((log10(coords[i - 1]) + log10(coords[i])) / 2)
        end
        return edges[1:n], edges[2:(n + 1)]
    else
        throw(ArgumentError("Unknown scale :$scale"))
    end
end

# --- to_viewspec ------------------------------------------------------

"""
    to_viewspec(result::SweepResult;
        signed_clip = Dict(), positive_clip = Dict(),
        spectrum_margin = 0.1, F = 6,
        quality_threshold = 1e-5,
        quality_dynamic_range_decades = 4.0,
        include_observables = nothing) → Dict

Resolve a `SweepResult` into a Vega-Lite spec (returned as a `Dict` for
JSON serialisation). The dispatcher picks `view_shape` from
`count(length(a.values) > 1 for a in axes)`:

  * 1 axis: single line chart per observable (TODO; currently the 2D
    path is exercised — 1D returns an empty `vconcat` for safety).
  * 2 axes: heatmap (Vega-Lite `rect` mark with explicit `x/x2/y/y2`).
    Per-cell `fill` is the resolved hex, `opacity` is `quality_alpha`
    from any `role=:quality` observable. Reference lines (oracle) are
    `rule` marks.
  * 3+ axes: facet grid (TODO).

`include_observables` (default `nothing` = all `role != :data ?
included as facet : included as panel`) lets a caller restrict the
emitted panel set.
"""
function to_viewspec(result::SweepResult;
    signed_clip::Dict=Dict(),
    positive_clip::Dict=Dict(),
    spectrum_margin::Real=0.1,
    F::Int=6,
    quality_threshold::Real=1e-5,
    quality_dynamic_range_decades::Real=4.0,
    include_observables::Union{Nothing, Vector{Symbol}}=nothing)
    spec = Dict{String, Any}(
        "\$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "config" => Dict{String, Any}(
            "view" => Dict("strokeOpacity" => 0),
            "axis" => Dict("labelFont" => "IBM Plex Mono", "titleFont" => "IBM Plex Sans"),
            "background" => "#ffffff",
        ),
    )

    # Determine view shape
    swept_axes = filter(a -> length(a.values) > 1, result.axes)
    axes_dim = length(swept_axes)
    spec["_view_shape"] = if axes_dim == 1
        "line"
    elseif axes_dim == 2
        "heatmap"
    else
        "facet_grid"
    end

    # Hypothesis (opt-in). The contract that carries the sweep's
    # question + theoretical apparatus. Replaces the old `:expected`
    # dict — see the [`Hypothesis`](@ref) docstring. Accepts both a
    # `Hypothesis` struct and a Dict that decodes to one (for
    # back-compat with YAML-defined narratives).
    narrative = get(result.meta, :narrative, nothing)
    function _nget(d, sym, default=nothing)
        d isa AbstractDict || return default
        v = get(d, sym, get(d, String(sym), default))
        return v === nothing ? default : v
    end
    raw_hyp = _nget(narrative, :hypothesis)
    hypothesis = if raw_hyp isa Hypothesis
        raw_hyp
    elseif raw_hyp isa AbstractDict
        # Decode a Dict-form hypothesis. Caller may pass nested Dicts /
        # closures so we extract leniently.
        rel = let k = _nget(raw_hyp, :relation, :asymptote)
            k isa AbstractString ? Symbol(k) : k
        end
        pkey = let p = _nget(raw_hyp, :primary_obs)
            p isa AbstractString ? Symbol(p) : p
        end
        raw_models = _nget(raw_hyp, :models, Dict{Symbol, Any}())
        models = Dict{Symbol, ModelSpec}()
        if raw_models isa AbstractDict
            for (k, v) in raw_models
                ksym = k isa AbstractString ? Symbol(k) : k
                if v isa ModelSpec
                    models[ksym] = v
                elseif v isa AbstractDict
                    fn = _nget(v, :fn)
                    fn === nothing && continue
                    models[ksym] = ModelSpec(;
                        fn=fn,
                        label=string(_nget(v, :label, "")),
                        collapse_var_fn=_nget(v, :collapse_var_fn),
                        collapse_var_label=let l = _nget(v, :collapse_var_label)
                            l === nothing ? nothing : string(l)
                        end,
                    )
                end
            end
        end
        params = let p = _nget(raw_hyp, :params, Dict{Symbol, Any}())
            if p isa AbstractDict
                Dict{Symbol, Any}(
                    (k isa AbstractString ? Symbol(k) : k) => v for (k, v) in p)
            else
                Dict{Symbol, Any}()
            end
        end
        if pkey === nothing
            nothing
        else
            Hypothesis(;
                question=string(_nget(raw_hyp, :question, "")),
                relation=rel,
                primary_obs=pkey,
                models=models,
                params=params,
            )
        end
    else
        nothing
    end
    primary_key = hypothesis === nothing ? nothing : hypothesis.primary_obs
    relation = hypothesis === nothing ? :auto : hypothesis.relation

    conv_col_for_count = get(result.meta, :conv_column, nothing)
    n_total = length(result.data)
    n_converged = if conv_col_for_count !== nothing
        count(r -> haskey(r, conv_col_for_count) && Bool(r[conv_col_for_count]),
            result.data)
    else
        n_total
    end
    # Mode: failed / partial / complete. Convergence is a **mode**, not
    # a mark — when 0/N converged the primary physics plot is meaningless,
    # so we suppress it and the React side renders a diagnostic alert
    # instead. Mark choice and mode are orthogonal.
    mode = if conv_col_for_count === nothing
        :complete  # no conv tracking — assume all valid
    elseif n_converged == 0
        :failed
    elseif n_converged < n_total
        :partial
    else
        :complete
    end

    # Identify the quality role observable (≤1 supported today)
    qualities = filter(o -> o.role === :quality, result.observables)
    quality_obs = isempty(qualities) ? nothing : first(qualities)

    if axes_dim == 2
        # Two swept axes: per-observable heatmap, laid out as a 3-column
        # grid (vconcat of hconcats). Each panel carries its own colorbar
        # via `scale.range = LUT_hex`; unconverged cells get a × overlay
        # (binary "don't trust" signal independent of the continuous
        # ‖∇E‖ → α fade, which lives in tooltip only). Oracle target —
        # when set on an observable — rides in the panel subtitle so the
        # reader sees the expected value next to the rendered one.
        x_axis = swept_axes[2]  # second axis = x (Ω for M1)
        y_axis = swept_axes[1]  # first axis  = y (B for M1)
        x_lo, x_hi = _cell_edges(collect(Float64.(x_axis.values)), x_axis.scale)
        y_lo, y_hi = _cell_edges(collect(Float64.(y_axis.values)), y_axis.scale)

        balance_hex = _lut_hex_array(sweep_balance_lut())
        viridis_hex = _lut_hex_array(sweep_viridis_lut())
        conv_col = get(result.meta, :conv_column, nothing)

        # Resolve per-observable display defaults (vmin/vmax/colormap)
        obs_display = Dict{Symbol, Dict{String, Any}}()
        for obs in result.observables
            d = Dict{String, Any}()
            if obs.kind === :signed
                vmin, vmax = get(signed_clip, obs.key, (-Float64(F), Float64(F)))
                d["vmin"], d["vmax"] = vmin, vmax
                d["colormap"] = "cmocean.balance"
                d["range"] = balance_hex
            elseif obs.kind === :positive || obs.kind === :wide
                if haskey(positive_clip, obs.key)
                    vmin, vmax = positive_clip[obs.key]
                else
                    vals = Float64[]
                    for r in result.data
                        ok = conv_col === nothing ||
                             (haskey(r, conv_col) && Bool(r[conv_col]))
                        if ok
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
                d["vmin"], d["vmax"] = vmin, vmax
                d["colormap"] = obs.scale === :log ? "viridis (log)" : "viridis"
                d["range"] = viridis_hex
            end
            obs_display[obs.key] = d
        end

        # Shared cell-row index: (xv, yv) → row.
        row_at = Dict{Tuple{Any, Any}, Dict{Symbol, Any}}()
        for r in result.data
            row_at[(r[x_axis.name], r[y_axis.name])] = r
        end

        # Builder: produces the per-cell marks for one observable. Quality
        # alpha goes to the tooltip ONLY (the fill stays solid so VSUP
        # never hides the value); `masked` drives the × overlay.
        function _build_marks(obs_key::Symbol)
            marks = Vector{Dict{String, Any}}()
            for (j, yv) in enumerate(y_axis.values)
                for (i, xv) in enumerate(x_axis.values)
                    row = get(row_at, (xv, yv), nothing)
                    row === nothing && continue
                    v = get(row, obs_key, NaN)
                    qα = if quality_obs === nothing
                        1.0
                    else
                        qv = get(row, quality_obs.key, NaN)
                        compute_quality_alpha(qv isa Real ? float(qv) : NaN;
                            threshold=quality_threshold,
                            dynamic_range_decades=quality_dynamic_range_decades)
                    end
                    masked = conv_col !== nothing &&
                             haskey(row, conv_col) &&
                             !Bool(row[conv_col])
                    push!(
                        marks,
                        Dict{String, Any}(
                            "x" => x_lo[i], "x2" => x_hi[i],
                            "y" => y_lo[j], "y2" => y_hi[j],
                            "cx" => (x_lo[i] + x_hi[i]) / 2,
                            "cy" => (y_lo[j] + y_hi[j]) / 2,
                            "value" => v isa Real && isfinite(v) ? float(v) : nothing,
                            "alpha" => qα,
                            "masked" => masked,
                            String(x_axis.name) => float(xv),
                            String(y_axis.name) => float(yv),
                        ),
                    )
                end
            end
            return marks
        end

        # m_dist marks for the spectrum kind use a richer payload
        # (dominant_m + decision_gap) and skip the value/alpha fields.
        function _build_m_dist_marks(obs_key::Symbol)
            m_vals = collect(F:-1:(-F))
            marks = Vector{Dict{String, Any}}()
            for (j, yv) in enumerate(y_axis.values)
                for (i, xv) in enumerate(x_axis.values)
                    row = get(row_at, (xv, yv), nothing)
                    row === nothing && continue
                    spec_vec = get(row, obs_key, Float64[])
                    spec_vec isa AbstractVector || continue
                    isempty(spec_vec) && continue
                    dom = dominant_m_with_margin(spec_vec, m_vals;
                        margin=spectrum_margin)
                    perm = sortperm(spec_vec; rev=true)
                    gap = if length(spec_vec) >= 2
                        (spec_vec[perm[1]] - spec_vec[perm[2]])
                    else
                        spec_vec[perm[1]]
                    end
                    masked = conv_col !== nothing &&
                             haskey(row, conv_col) &&
                             !Bool(row[conv_col])
                    dom_label = dom === :mixed ? "mixed" : string(dom)
                    push!(
                        marks,
                        Dict{String, Any}(
                            "x" => x_lo[i], "x2" => x_hi[i],
                            "y" => y_lo[j], "y2" => y_hi[j],
                            "cx" => (x_lo[i] + x_hi[i]) / 2,
                            "cy" => (y_lo[j] + y_hi[j]) / 2,
                            "dominant_m" => dom_label,
                            "decision_gap" => gap,
                            "masked" => masked,
                            String(x_axis.name) => float(xv),
                            String(y_axis.name) => float(yv),
                        ),
                    )
                end
            end
            return marks
        end

        # Common axis encodings (used by every panel).
        x_enc = Dict("field" => "x", "type" => "quantitative",
            "title" => "$(x_axis.name) [$(x_axis.unit)]",
            "scale" => Dict("type" => String(x_axis.scale)))
        x2_enc = Dict("field" => "x2")
        y_enc = Dict("field" => "y", "type" => "quantitative",
            "title" => "$(y_axis.name) [$(y_axis.unit)]",
            "scale" => Dict("type" => String(y_axis.scale)))
        y2_enc = Dict("field" => "y2")

        # VSUP base layer: a neutral grey rect under every cell. The
        # colored layer above rides with `fillOpacity = α` so unconverged
        # cells fade toward this grey — the "color lies" failure mode is
        # killed at fill level, not just hidden behind a × glyph. (×
        # is too weak a signal against saturated red/blue; the eye reads
        # the strong color first.)
        vsup_grey = "#9aa0a6"
        base_layer(data_values) = Dict{String, Any}(
            "data" => Dict("values" => data_values),
            "mark" => Dict("type" => "rect"),
            "encoding" => Dict{String, Any}(
                "x" => x_enc, "x2" => x2_enc,
                "y" => y_enc, "y2" => y2_enc,
                "fill" => Dict("value" => vsup_grey),
            ),
        )

        # Hatch/× overlay: a single text mark at the cell center, shown
        # only when masked=true. Reuses the same data values as the
        # underlying rect so the overlay aligns pixel-perfect.
        hatch_layer(data_values) = Dict{String, Any}(
            "data" => Dict("values" => data_values),
            "transform" => [Dict("filter" => "datum.masked == true")],
            "mark" => Dict("type" => "text", "text" => "×",
                "fontSize" => 14, "fontWeight" => "bold",
                "color" => "#3a3a3a"),
            "encoding" => Dict(
                "x" => Dict("field" => "cx", "type" => "quantitative",
                    "scale" => Dict("type" => String(x_axis.scale))),
                "y" => Dict("field" => "cy", "type" => "quantitative",
                    "scale" => Dict("type" => String(y_axis.scale))),
            ),
        )

        # All data-role observables become uniform heatmap thumbnails
        # (220×170). The PRIMARY mark is built separately by
        # `_build_primary_mark` below based on `expected.kind` — heatmap
        # is no longer special-cased as primary; it's just one of the
        # auxiliary thumbnail shapes.
        panels = Vector{Dict{String, Any}}()
        function _push_signed_or_positive(obs)
            d = obs_display[obs.key]
            marks = _build_marks(obs.key)
            subtitle_lines = String[]
            # When the hypothesis carries a model for this observable,
            # surface the model label as a thumbnail subtitle. Replaces
            # the old per-obs oracle/oracle_label that was conceptually
            # mis-placed (hypothesis property, not observable property).
            if hypothesis !== nothing && haskey(hypothesis.models, obs.key)
                push!(subtitle_lines,
                    "model: $(hypothesis.models[obs.key].label)")
            end
            push!(subtitle_lines,
                "$(d["colormap"])  [$(round(d["vmin"]; digits=3)), $(round(d["vmax"]; digits=3))]")
            title_block = Dict{String, Any}(
                "text" => obs.label,
                "subtitle" => subtitle_lines,
                "subtitleFontSize" => 10,
                "subtitleColor" => "#5a6068",
            )
            rect_layer = Dict{String, Any}(
                "data" => Dict("values" => marks),
                "mark" => Dict("type" => "rect"),
                "encoding" => Dict{String, Any}(
                    "x" => x_enc, "x2" => x2_enc,
                    "y" => y_enc, "y2" => y2_enc,
                    "fill" => Dict(
                        "field" => "value",
                        "type" => "quantitative",
                        "scale" => Dict(
                            "domain" => [d["vmin"], d["vmax"]],
                            "range" => d["range"],
                            "clamp" => true,
                        ),
                        "legend" => Dict("title" => obs.label,
                            "orient" => "right", "format" => ".2f"),
                    ),
                    # VSUP continuous: fillOpacity = α (quality). Domain
                    # [0,1] mapped to range [0.10, 1.0] so unconverged
                    # cells fade toward the grey base; high-quality
                    # cells are saturated. The 0.10 floor (not 0) keeps
                    # a hint of colour even at α=0 so the cell remains
                    # a cell (not a hole), but the dominant signal is
                    # grey.
                    "fillOpacity" => Dict(
                        "field" => "alpha",
                        "type" => "quantitative",
                        "scale" => Dict("domain" => [0.0, 1.0],
                            "range" => [0.10, 1.0], "clamp" => true),
                        "legend" => nothing,
                    ),
                    "tooltip" => [
                        Dict("field" => String(x_axis.name),
                            "type" => "quantitative",
                            "title" => "$(x_axis.name) [$(x_axis.unit)]"),
                        Dict("field" => String(y_axis.name),
                            "type" => "quantitative",
                            "title" => "$(y_axis.name) [$(y_axis.unit)]"),
                        Dict("field" => "value", "type" => "quantitative",
                            "title" => obs.label, "format" => ".4f"),
                        Dict("field" => "alpha", "type" => "quantitative",
                            "title" => "VSUP α", "format" => ".2f"),
                        Dict("field" => "masked", "type" => "nominal",
                            "title" => "unconverged"),
                    ],
                ),
            )
            layers = Any[base_layer(marks), rect_layer, hatch_layer(marks)]
            push!(
                panels,
                Dict{String, Any}(
                    "title" => title_block,
                    "width" => 220, "height" => 170,
                    "layer" => layers,
                    "_meta" => Dict("observable" => String(obs.key),
                        "kind" => String(obs.kind),
                        "vmin" => d["vmin"], "vmax" => d["vmax"],
                        "colormap" => d["colormap"],
                        "model_label" =>
                            if (hypothesis !== nothing &&
                                haskey(hypothesis.models, obs.key))
                                hypothesis.models[obs.key].label
                            else
                                nothing
                            end),
                ),
            )
        end

        # Build the FAILED-MODE primary: a heatmap of the quality
        # observable (e.g. ‖∇E‖) across the swept axes. This is the
        # diagnostic the FailureAlert promises ("look at ‖∇E‖ trace") —
        # without it the alert is hollow. Physical observables are
        # suppressed in failed mode (they're garbage); the user reads
        # the optimiser-failure topology directly.
        function _build_quality_primary()
            quality_obs === nothing && return nothing
            qkey = quality_obs.key
            # Build per-cell marks for the quality observable. Quality
            # is the value here (not VSUP weight) — every cell paints.
            qmarks = Vector{Dict{String, Any}}()
            qvals = Float64[]
            for (j, yv) in enumerate(y_axis.values)
                for (i, xv) in enumerate(x_axis.values)
                    row = get(row_at, (xv, yv), nothing)
                    row === nothing && continue
                    qv = get(row, qkey, NaN)
                    qv isa Real && isfinite(qv) && push!(qvals, float(qv))
                    push!(
                        qmarks,
                        Dict{String, Any}(
                            "x" => x_lo[i], "x2" => x_hi[i],
                            "y" => y_lo[j], "y2" => y_hi[j],
                            "cx" => (x_lo[i] + x_hi[i]) / 2,
                            "cy" => (y_lo[j] + y_hi[j]) / 2,
                            "value" => qv isa Real && isfinite(qv) ? float(qv) : nothing,
                            String(x_axis.name) => float(xv),
                            String(y_axis.name) => float(yv),
                        ),
                    )
                end
            end
            isempty(qmarks) && return nothing
            qvmin, qvmax = if isempty(qvals)
                (1e-6, 1.0)
            else
                sort!(qvals)
                # Use full range; quality is the headline here, not a
                # robust quantile read.
                (max(qvals[1], 1e-12), max(qvals[end], 1e-11))
            end
            qscale_type = quality_obs.scale === :log ? "log" : "linear"
            qrect_layer = Dict{String, Any}(
                "data" => Dict("values" => qmarks),
                "mark" => Dict("type" => "rect"),
                "encoding" => Dict{String, Any}(
                    "x" => x_enc, "x2" => x2_enc,
                    "y" => y_enc, "y2" => y2_enc,
                    "fill" => Dict(
                        "field" => "value",
                        "type" => "quantitative",
                        "scale" => Dict(
                            "domain" => [qvmin, qvmax],
                            "range" => viridis_hex,
                            "type" => qscale_type,
                            "clamp" => true,
                        ),
                        "legend" => Dict("title" => quality_obs.label,
                            "orient" => "right",
                            "format" => quality_obs.scale === :log ? ".0e" : ".3f"),
                    ),
                    "tooltip" => [
                        Dict("field" => String(x_axis.name),
                            "type" => "quantitative",
                            "title" => "$(x_axis.name) [$(x_axis.unit)]"),
                        Dict("field" => String(y_axis.name),
                            "type" => "quantitative",
                            "title" => "$(y_axis.name) [$(y_axis.unit)]"),
                        Dict("field" => "value", "type" => "quantitative",
                            "title" => quality_obs.label,
                            "format" => quality_obs.scale === :log ? ".2e" : ".4f"),
                    ],
                ),
            )
            # Threshold rule: a 1px white outline on cells below the
            # convergence threshold so the (rare) "passed-tol" cells
            # stand out even though we're in failed/mode rollup.
            title_block = Dict{String, Any}(
                "text" => "$(quality_obs.label) at termination",
                "subtitle" => [
                    "Failed-mode diagnostic — physics observables suppressed",
                    "lower is better; threshold for converged: " *
                    (
                        if quality_obs.scale === :log
                            "$(round(quality_threshold; sigdigits=2))"
                        else
                            "$(round(quality_threshold; digits=4))"
                        end
                    ),
                ],
                "fontSize" => 17,
                "subtitleFontSize" => 11,
                "subtitleColor" => "#5a6068",
            )
            return Dict{String, Any}(
                "title" => title_block,
                "width" => 560, "height" => 360,
                "layer" => Any[qrect_layer],
                "_meta" => Dict("primary" => true,
                    "kind" => "quality_diagnostic",
                    "observable" => String(qkey)),
            )
        end

        # Helpers shared by relation builders.

        # Convert axis NamedTuple from a row for model_fn evaluation.
        # `NamedTuple{names}` needs an actual Tuple of Symbols, not a
        # Generator — collect both sides explicitly.
        _row_axes(row) =
            let
                names = Tuple(a.name for a in result.axes)
                vals = Tuple(float(row[a.name]) for a in result.axes)
                NamedTuple{names}(vals)
            end

        # Pick the SweepAxis named by `name_sym`, falling back to the
        # first swept axis.
        function _pick_axis(name_sym::Union{Nothing, Symbol})
            if name_sym !== nothing
                for a in result.axes
                    a.name === name_sym && return a
                end
            end
            isempty(swept_axes) ? nothing : swept_axes[1]
        end

        # The OTHER swept axis (used as colour/series in 1D primary
        # views over a 2D sweep).
        function _other_swept(ax_obj)
            for a in result.axes
                a.name === ax_obj.name && continue
                length(a.values) > 1 && return a
            end
            return nothing
        end

        # Quality-alpha for a cell (continuous VSUP).
        function _quality_alpha(row)
            quality_obs === nothing && return 1.0
            qv = get(row, quality_obs.key, NaN)
            compute_quality_alpha(qv isa Real ? float(qv) : NaN;
                threshold=quality_threshold,
                dynamic_range_decades=quality_dynamic_range_decades)
        end

        function _row_masked(row)
            conv_col_for_count !== nothing &&
                haskey(row, conv_col_for_count) &&
                !Bool(row[conv_col_for_count])
        end

        # Safe model evaluation (caught error → nothing).
        function _eval_model_safe(fn, axes_nt)
            try
                v = fn(axes_nt)
                v isa Real && isfinite(v) ? Float64(v) : nothing
            catch _err
                nothing
            end
        end

        # ----- Asymptote builder ------------------------------------
        function _build_asymptote_primary(primary_obs_obj)
            axis_sym = let a = get(hypothesis.params, :axis, nothing)
                a isa AbstractString ? Symbol(a) : a
            end
            ax_obj = _pick_axis(axis_sym)
            ax_obj === nothing && return nothing
            other_obj = _other_swept(ax_obj)

            # Limit value: prefer explicit `params[:limit]`, else
            # evaluate `models[primary_obs].fn` at the reference cell
            # (`params[:reference]` or the max-axis edge).
            limit_val = let l = get(hypothesis.params, :limit, nothing)
                l isa Real ? Float64(l) : nothing
            end
            if limit_val === nothing && haskey(hypothesis.models, primary_key)
                mdl = hypothesis.models[primary_key]
                ref = get(hypothesis.params, :reference, nothing)
                ref_nt = if ref isa AbstractDict
                    NamedTuple(
                        (Symbol(k) => float(v) for (k, v) in ref))
                else
                    # Default reference: max value on axis, mid value on other
                    rd = Dict{Symbol, Float64}(
                        ax_obj.name => maximum(ax_obj.values))
                    if other_obj !== nothing
                        rd[other_obj.name] = other_obj.values[max(1, length(other_obj.values) ÷ 2)]
                    end
                    NamedTuple((k => v for (k, v) in rd))
                end
                limit_val = _eval_model_safe(mdl.fn, ref_nt)
            end

            points = Vector{Dict{String, Any}}()
            for r in result.data
                haskey(r, ax_obj.name) || continue
                v = get(r, primary_key, NaN)
                v isa Real && isfinite(v) || continue
                other_val = if other_obj === nothing
                    "—"
                else
                    string(round(Float64(r[other_obj.name]); digits=3))
                end
                push!(
                    points,
                    Dict{String, Any}(
                        String(ax_obj.name) => float(r[ax_obj.name]),
                        "series" => other_val,
                        "value" => float(v),
                        "masked" => _row_masked(r),
                    ),
                )
            end

            line_layer = Dict{String, Any}(
                "data" => Dict("values" => points),
                "mark" => Dict("type" => "line",
                    "point" => Dict("filled" => true, "size" => 60),
                    "interpolate" => "monotone",
                    "strokeWidth" => 2.0),
                "encoding" => Dict{String, Any}(
                    "x" => Dict("field" => String(ax_obj.name),
                        "type" => "quantitative",
                        "title" => "$(ax_obj.name) [$(ax_obj.unit)]",
                        "scale" => Dict("type" => String(ax_obj.scale))),
                    "y" => Dict("field" => "value",
                        "type" => "quantitative",
                        "title" => primary_obs_obj.label),
                    "color" => Dict("field" => "series",
                        "type" => "ordinal",
                        "title" => if other_obj === nothing
                            ""
                        else
                            "$(other_obj.name) [$(other_obj.unit)]"
                        end),
                    "opacity" => Dict(
                        "condition" => Dict("test" => "datum.masked",
                            "value" => 0.25),
                        "value" => 1.0),
                    "tooltip" => [
                        Dict("field" => String(ax_obj.name),
                            "type" => "quantitative",
                            "title" => "$(ax_obj.name) [$(ax_obj.unit)]"),
                        Dict("field" => "series", "type" => "ordinal",
                            "title" => "series"),
                        Dict("field" => "value", "type" => "quantitative",
                            "title" => primary_obs_obj.label,
                            "format" => ".4f"),
                        Dict("field" => "masked", "type" => "nominal",
                            "title" => "unconverged"),
                    ],
                ),
            )

            layers = Any[line_layer]
            if limit_val !== nothing
                push!(
                    layers,
                    Dict{String, Any}(
                        "data" => Dict("values" => [Dict("limit" => limit_val)]),
                        "mark" => Dict("type" => "rule",
                            "strokeDash" => [6, 3], "color" => "#1a1a1a",
                            "strokeWidth" => 1.5),
                        "encoding" => Dict("y" => Dict(
                            "field" => "limit", "type" => "quantitative")),
                    ),
                )
                push!(
                    layers,
                    Dict{String, Any}(
                        "data" => Dict(
                            "values" => [
                                Dict(
                                    "limit" => limit_val,
                                    "label" => "limit = $(round(limit_val; digits=3))"),
                            ],
                        ),
                        "mark" => Dict("type" => "text",
                            "align" => "left", "baseline" => "bottom",
                            "dx" => 8, "dy" => -4,
                            "color" => "#1a1a1a", "fontSize" => 11,
                            "fontWeight" => "bold"),
                        "encoding" => Dict(
                            "y" => Dict("field" => "limit",
                                "type" => "quantitative"),
                            "text" => Dict("field" => "label"),
                        ),
                    ),
                )
            end

            mdl_label =
                haskey(hypothesis.models, primary_key) ?
                hypothesis.models[primary_key].label : ""
            return Dict{String, Any}(
                "title" => Dict{String, Any}(
                    "text" =>
                        "$(primary_obs_obj.label) vs $(ax_obj.name)" *
                        "  ·  asymptote test",
                    "subtitle" => [
                        if limit_val === nothing
                            "limit: unknown"
                        else
                            "predicted limit: $(round(limit_val; digits=3))" *
                            (isempty(mdl_label) ? "" : "  ·  $(mdl_label)")
                        end,
                        if other_obj === nothing
                            ""
                        else
                            "lines: one per $(other_obj.name) value " *
                            "($(length(other_obj.values)) total); " *
                            "ghosted points are unconverged"
                        end,
                    ],
                    "fontSize" => 18,
                    "subtitleFontSize" => 12,
                    "subtitleColor" => "#5a6068",
                ),
                "width" => 600, "height" => 380,
                "layer" => layers,
                "_meta" => Dict("primary" => true,
                    "kind" => "asymptote",
                    "axis" => String(ax_obj.name),
                    "limit" => limit_val,
                    "observable" => String(primary_key)),
            )
        end

        # ----- Collapse builder -------------------------------------
        # The right inference instrument when "is X the supporting
        # dimensionless variable" is itself the question. Plots:
        #   - data points: (x_collapse, observed) per cell, alpha = quality
        #   - theory envelope: dense (axes) grid → mapped through
        #     collapse_var (x) and model_fn (y), x-binned [min, max]
        #     area mark. Sharp band = model factors through x cleanly;
        #     wide band = wrong collapse_var (the inference target).
        function _build_collapse_primary(primary_obs_obj)
            mdl = get(hypothesis.models, primary_key, nothing)
            mdl === nothing && return nothing
            mdl.collapse_var_fn === nothing && return nothing

            # Data points
            data_pts = Vector{Dict{String, Any}}()
            x_data = Float64[]
            for r in result.data
                v = get(r, primary_key, NaN)
                v isa Real && isfinite(v) || continue
                axes_nt = _row_axes(r)
                xv = _eval_model_safe(mdl.collapse_var_fn, axes_nt)
                xv === nothing && continue
                push!(x_data, xv)
                push!(
                    data_pts,
                    Dict{String, Any}(
                        "x" => xv,
                        "value" => float(v),
                        "alpha" => _quality_alpha(r),
                        "masked" => _row_masked(r),
                        (String(a.name) => float(r[a.name]) for a in result.axes)...,
                    ),
                )
            end
            isempty(data_pts) && return nothing

            # Theory envelope: dense (axes) grid clipped to data range.
            # Sample 30 per swept axis (so ~900 points for 2D; cheap).
            n_dense = 30
            theory_samples = Vector{Tuple{Float64, Float64}}()
            for ax_a in result.axes
                length(ax_a.values) > 1 || continue
            end
            # Build grid by spanning each swept axis.
            axis_ranges = [
                let vmin = minimum(a.values), vmax = maximum(a.values)
                    a.name => (
                        if a.scale === :log
                            exp10.(range(log10(max(vmin, eps())),
                                log10(vmax); length=n_dense))
                        else
                            collect(range(vmin, vmax; length=n_dense))
                        end
                    )
                end for a in result.axes if length(a.values) > 1
            ]
            constant_axes = Dict{Symbol, Float64}(
                a.name => float(first(a.values))
                for a in result.axes if length(a.values) == 1
            )
            # Iterate the cartesian product manually (≤2 swept axes
            # supported here; collapse is 1D-target by construction).
            if length(axis_ranges) == 1
                a1, v1s = axis_ranges[1]
                for v1 in v1s
                    nt = NamedTuple((a1 => v1,
                        (k => v for (k, v) in constant_axes)...))
                    x = _eval_model_safe(mdl.collapse_var_fn, nt)
                    y = _eval_model_safe(mdl.fn, nt)
                    x !== nothing && y !== nothing &&
                        push!(theory_samples, (x, y))
                end
            elseif length(axis_ranges) >= 2
                a1, v1s = axis_ranges[1]
                a2, v2s = axis_ranges[2]
                for v1 in v1s, v2 in v2s
                    nt = NamedTuple((a1 => v1, a2 => v2,
                        (k => v for (k, v) in constant_axes)...))
                    x = _eval_model_safe(mdl.collapse_var_fn, nt)
                    y = _eval_model_safe(mdl.fn, nt)
                    x !== nothing && y !== nothing &&
                        push!(theory_samples, (x, y))
                end
            end
            isempty(theory_samples) && return nothing

            # Clip theory to data x-range (don't extrapolate beyond data).
            xmin_d = minimum(x_data)
            xmax_d = maximum(x_data)
            filter!(p -> xmin_d <= p[1] <= xmax_d, theory_samples)
            isempty(theory_samples) && return nothing

            # Bin in x; emit (x_mid, y_min, y_max) per bin as area mark.
            n_bins = 50
            sort!(theory_samples; by=first)
            xa = first.(theory_samples)
            xmin = xa[1]
            xmax = xa[end]
            envelope = Vector{Dict{String, Any}}()
            if xmax > xmin
                bin_width = (xmax - xmin) / n_bins
                bin_lo = xmin
                bin_idx = 1
                bin_ys = Float64[]
                bin_xs = Float64[]
                for (x, y) in theory_samples
                    while bin_idx <= n_bins && x > bin_lo + bin_width
                        if !isempty(bin_ys)
                            push!(
                                envelope,
                                Dict{String, Any}(
                                    "x_mid" => (bin_lo + bin_lo + bin_width) / 2,
                                    "y_min" => minimum(bin_ys),
                                    "y_max" => maximum(bin_ys),
                                ),
                            )
                        end
                        bin_lo += bin_width
                        bin_idx += 1
                        empty!(bin_ys);
                        empty!(bin_xs)
                    end
                    push!(bin_ys, y);
                    push!(bin_xs, x)
                end
                if !isempty(bin_ys)
                    push!(
                        envelope,
                        Dict{String, Any}(
                            "x_mid" => (bin_lo + bin_lo + bin_width) / 2,
                            "y_min" => minimum(bin_ys),
                            "y_max" => maximum(bin_ys),
                        ),
                    )
                end
            end

            envelope_layer = Dict{String, Any}(
                "data" => Dict("values" => envelope),
                "mark" => Dict("type" => "area",
                    "color" => "#7f8a99",
                    "opacity" => 0.35,
                    "interpolate" => "monotone"),
                "encoding" => Dict(
                    "x" => Dict("field" => "x_mid",
                        "type" => "quantitative",
                        "title" => if mdl.collapse_var_label !== nothing
                            mdl.collapse_var_label
                        else
                            "collapse variable x"
                        end),
                    "y" => Dict("field" => "y_min",
                        "type" => "quantitative",
                        "title" => primary_obs_obj.label),
                    "y2" => Dict("field" => "y_max"),
                ),
            )

            data_layer = Dict{String, Any}(
                "data" => Dict("values" => data_pts),
                "mark" => Dict("type" => "point",
                    "filled" => true, "size" => 90,
                    "stroke" => "#1a1a1a", "strokeWidth" => 0.6),
                "encoding" => Dict{String, Any}(
                    "x" => Dict("field" => "x", "type" => "quantitative",
                        "title" => if mdl.collapse_var_label !== nothing
                            mdl.collapse_var_label
                        else
                            "collapse variable x"
                        end),
                    "y" => Dict("field" => "value",
                        "type" => "quantitative",
                        "title" => primary_obs_obj.label),
                    "fillOpacity" => Dict("field" => "alpha",
                        "type" => "quantitative",
                        "scale" => Dict("domain" => [0.0, 1.0],
                            "range" => [0.15, 1.0]),
                        "legend" => nothing),
                    "tooltip" => vcat(
                        [
                            Dict("field" => "x", "type" => "quantitative",
                                "title" => "x_collapse", "format" => ".4g"),
                            Dict("field" => "value", "type" => "quantitative",
                                "title" => primary_obs_obj.label,
                                "format" => ".4f"),
                            Dict("field" => "alpha", "type" => "quantitative",
                                "title" => "VSUP α", "format" => ".2f"),
                            Dict("field" => "masked", "type" => "nominal",
                                "title" => "unconverged"),
                        ],
                        [
                            Dict("field" => String(a.name),
                                "type" => "quantitative",
                                "title" => "$(a.name) [$(a.unit)]") for a in result.axes
                        ]),
                ),
            )

            return Dict{String, Any}(
                "title" => Dict{String, Any}(
                    "text" => "$(primary_obs_obj.label) — collapse test",
                    "subtitle" => [
                        "x: $(mdl.collapse_var_label === nothing ? "" : mdl.collapse_var_label)",
                        "model: $(mdl.label)",
                        "envelope = theory band (model on dense $(length(result.axes))D grid, x-binned [min,max])",
                        "points = data (opacity = VSUP α, hover for (axes))",
                    ],
                    "fontSize" => 18,
                    "subtitleFontSize" => 11,
                    "subtitleColor" => "#5a6068",
                ),
                "width" => 600, "height" => 380,
                "layer" => Any[envelope_layer, data_layer],
                "_meta" => Dict("primary" => true,
                    "kind" => "collapse",
                    "observable" => String(primary_key),
                    "model_label" => mdl.label,
                    "collapse_var_label" => mdl.collapse_var_label,
                    "n_data" => length(data_pts),
                    "n_envelope_bins" => length(envelope)),
            )
        end

        # ----- Residual builder -------------------------------------
        # observed - predicted, signed. 2D → diverging heatmap centred
        # at 0; 1D → line plot vs the swept axis.
        function _build_residual_primary(primary_obs_obj)
            mdl = get(hypothesis.models, primary_key, nothing)
            mdl === nothing && return nothing
            pts = Vector{Dict{String, Any}}()
            rmax = 0.0
            for r in result.data
                v = get(r, primary_key, NaN)
                v isa Real && isfinite(v) || continue
                pred = _eval_model_safe(mdl.fn, _row_axes(r))
                pred === nothing && continue
                resid = float(v) - pred
                rmax = max(rmax, abs(resid))
                d = Dict{String, Any}(
                    "value" => resid,
                    "observed" => float(v),
                    "predicted" => pred,
                    "alpha" => _quality_alpha(r),
                    "masked" => _row_masked(r),
                )
                for a in result.axes
                    d[String(a.name)] = float(r[a.name])
                end
                push!(pts, d)
            end
            isempty(pts) && return nothing
            rmax = rmax > 0 ? rmax : 1.0

            if axes_dim >= 2
                # 2D residual heatmap centred at 0
                for (j, yv) in enumerate(y_axis.values)
                    for (i, xv) in enumerate(x_axis.values)
                        for d in pts
                            if d[String(x_axis.name)] == xv &&
                                d[String(y_axis.name)] == yv
                                d["x"] = x_lo[i];
                                d["x2"] = x_hi[i]
                                d["y"] = y_lo[j];
                                d["y2"] = y_hi[j]
                                d["cx"] = (x_lo[i] + x_hi[i]) / 2
                                d["cy"] = (y_lo[j] + y_hi[j]) / 2
                            end
                        end
                    end
                end
                heat_layer = Dict{String, Any}(
                    "data" => Dict("values" => pts),
                    "mark" => Dict("type" => "rect"),
                    "encoding" => Dict{String, Any}(
                        "x" => x_enc, "x2" => x2_enc,
                        "y" => y_enc, "y2" => y2_enc,
                        "fill" => Dict(
                            "field" => "value",
                            "type" => "quantitative",
                            "scale" => Dict("domain" => [-rmax, rmax],
                                "range" => balance_hex, "clamp" => true),
                            "legend" => Dict("title" => "residual",
                                "orient" => "right", "format" => ".3f"),
                        ),
                        "fillOpacity" => Dict("field" => "alpha",
                            "type" => "quantitative",
                            "scale" => Dict("domain" => [0.0, 1.0],
                                "range" => [0.10, 1.0]),
                            "legend" => nothing),
                        "tooltip" => [
                            Dict("field" => String(x_axis.name),
                                "type" => "quantitative",
                                "title" => "$(x_axis.name) [$(x_axis.unit)]"),
                            Dict("field" => String(y_axis.name),
                                "type" => "quantitative",
                                "title" => "$(y_axis.name) [$(y_axis.unit)]"),
                            Dict("field" => "observed", "type" => "quantitative",
                                "title" => "observed", "format" => ".4f"),
                            Dict("field" => "predicted", "type" => "quantitative",
                                "title" => "predicted", "format" => ".4f"),
                            Dict("field" => "value", "type" => "quantitative",
                                "title" => "residual", "format" => ".4f"),
                        ],
                    ),
                )
                return Dict{String, Any}(
                    "title" => Dict{String, Any}(
                        "text" => "$(primary_obs_obj.label) residual: observed − predicted",
                        "subtitle" => ["model: $(mdl.label)",
                            "diverging palette centred at 0 — red = model under, blue = over",
                        ],
                        "fontSize" => 18,
                        "subtitleFontSize" => 11,
                        "subtitleColor" => "#5a6068",
                    ),
                    "width" => 540, "height" => 360,
                    "layer" => Any[base_layer(pts), heat_layer, hatch_layer(pts)],
                    "_meta" => Dict("primary" => true,
                        "kind" => "residual",
                        "observable" => String(primary_key),
                        "model_label" => mdl.label,
                        "rmax" => rmax),
                )
            else
                ax_obj = swept_axes[1]
                line_layer = Dict{String, Any}(
                    "data" => Dict("values" => pts),
                    "mark" => Dict("type" => "line",
                        "point" => Dict("filled" => true, "size" => 60),
                        "interpolate" => "monotone"),
                    "encoding" => Dict{String, Any}(
                        "x" => Dict("field" => String(ax_obj.name),
                            "type" => "quantitative",
                            "title" => "$(ax_obj.name) [$(ax_obj.unit)]",
                            "scale" => Dict("type" => String(ax_obj.scale))),
                        "y" => Dict("field" => "value",
                            "type" => "quantitative",
                            "title" => "observed − predicted"),
                        "opacity" => Dict("condition" => Dict(
                                "test" => "datum.masked", "value" => 0.25),
                            "value" => 1.0),
                    ),
                )
                zero_rule = Dict{String, Any}(
                    "data" => Dict("values" => [Dict("z" => 0.0)]),
                    "mark" => Dict("type" => "rule", "strokeDash" => [4, 3],
                        "color" => "#1a1a1a"),
                    "encoding" => Dict("y" => Dict("field" => "z",
                        "type" => "quantitative")),
                )
                return Dict{String, Any}(
                    "title" => Dict{String, Any}(
                        "text" => "$(primary_obs_obj.label) residual vs $(ax_obj.name)",
                        "subtitle" => ["model: $(mdl.label)",
                            "y = observed − predicted; horizontal line = 0"],
                    ),
                    "width" => 600, "height" => 360,
                    "layer" => Any[zero_rule, line_layer],
                    "_meta" => Dict("primary" => true,
                        "kind" => "residual",
                        "observable" => String(primary_key),
                        "model_label" => mdl.label),
                )
            end
        end

        # ----- Scaling builder --------------------------------------
        # log-log of |observed| or |observed − predicted| vs an axis.
        # If params[:exponent] is set, draw a reference power-law slope.
        function _build_scaling_primary(primary_obs_obj)
            axis_sym = let a = get(hypothesis.params, :axis, nothing)
                a isa AbstractString ? Symbol(a) : a
            end
            ax_obj = _pick_axis(axis_sym)
            ax_obj === nothing && return nothing
            mode_scale = get(hypothesis.params, :scale_quantity, :residual)
            if mode_scale isa AbstractString
                mode_scale = Symbol(mode_scale)
            end
            mdl = get(hypothesis.models, primary_key, nothing)
            pts = Vector{Dict{String, Any}}()
            for r in result.data
                v = get(r, primary_key, NaN)
                v isa Real && isfinite(v) || continue
                axes_nt = _row_axes(r)
                xv = float(r[ax_obj.name])
                xv > 0 || continue
                y = if mode_scale === :residual && mdl !== nothing
                    pred = _eval_model_safe(mdl.fn, axes_nt)
                    pred === nothing ? nothing : abs(float(v) - pred)
                else
                    abs(float(v))
                end
                y === nothing && continue
                y > 0 || continue
                push!(
                    pts,
                    Dict{String, Any}(
                        String(ax_obj.name) => xv,
                        "value" => y,
                        "alpha" => _quality_alpha(r),
                        "masked" => _row_masked(r),
                    ),
                )
            end
            isempty(pts) && return nothing
            layers = Any[Dict{String, Any}(
                "data" => Dict("values" => pts),
                "mark" => Dict("type" => "point", "filled" => true,
                    "size" => 70),
                "encoding" => Dict{String, Any}(
                    "x" => Dict("field" => String(ax_obj.name),
                        "type" => "quantitative",
                        "scale" => Dict("type" => "log"),
                        "title" => "$(ax_obj.name) [$(ax_obj.unit)] (log)"),
                    "y" => Dict("field" => "value", "type" => "quantitative",
                        "scale" => Dict("type" => "log"),
                        "title" => if mode_scale === :residual
                            "|observed − predicted| (log)"
                        else
                            "|observed| (log)"
                        end),
                    "fillOpacity" => Dict("field" => "alpha",
                        "type" => "quantitative",
                        "scale" => Dict("domain" => [0.0, 1.0],
                            "range" => [0.15, 1.0]),
                        "legend" => nothing),
                ),
            )]
            exponent = get(hypothesis.params, :exponent, nothing)
            if exponent isa Real
                xs = sort([float(p[String(ax_obj.name)]) for p in pts])
                xmin, xmax = first(xs), last(xs)
                # Anchor: through median point of the data
                pmid = pts[length(pts) ÷ 2 + 1]
                xa = float(pmid[String(ax_obj.name)])
                ya = float(pmid["value"])
                trace = [
                    Dict{String, Any}(
                        String(ax_obj.name) => x,
                        "value" => ya * (x / xa) ^ Float64(exponent),
                    ) for x in [xmin, xmax]
                ]
                push!(
                    layers,
                    Dict{String, Any}(
                        "data" => Dict("values" => trace),
                        "mark" => Dict("type" => "line", "color" => "#1a1a1a",
                            "strokeDash" => [6, 3], "strokeWidth" => 1.5),
                        "encoding" => Dict(
                            "x" => Dict("field" => String(ax_obj.name),
                                "type" => "quantitative"),
                            "y" => Dict("field" => "value",
                                "type" => "quantitative"),
                        ),
                    ),
                )
            end
            return Dict{String, Any}(
                "title" => Dict{String, Any}(
                    "text" => "$(primary_obs_obj.label) scaling vs $(ax_obj.name)",
                    "subtitle" => [
                        if mode_scale === :residual
                            "y = |observed − predicted| (log)"
                        else
                            "y = |observed| (log)"
                        end,
                        if exponent isa Real
                            "reference slope = $(round(exponent; digits=2))"
                        else
                            "slope = data only (no theoretical exponent declared)"
                        end,
                    ],
                ),
                "width" => 600, "height" => 380,
                "layer" => layers,
                "_meta" => Dict("primary" => true, "kind" => "scaling",
                    "axis" => String(ax_obj.name),
                    "observable" => String(primary_key),
                    "exponent" => exponent),
            )
        end

        # ----- Correlation builder ----------------------------------
        # Scatter primary_obs vs params[:obs_y] across the sweep.
        function _build_correlation_primary(primary_obs_obj)
            ykey_raw = get(hypothesis.params, :obs_y, nothing)
            ykey = ykey_raw isa AbstractString ? Symbol(ykey_raw) : ykey_raw
            ykey isa Symbol || return nothing
            yobs = nothing
            for o in result.observables
                if o.key === ykey
                    yobs = o
                    break
                end
            end
            yobs === nothing && return nothing
            pts = Vector{Dict{String, Any}}()
            for r in result.data
                xv = get(r, primary_key, NaN)
                yv = get(r, ykey, NaN)
                (xv isa Real && isfinite(xv) && yv isa Real && isfinite(yv)) ||
                    continue
                push!(
                    pts,
                    Dict{String, Any}(
                        "x" => float(xv), "y" => float(yv),
                        "alpha" => _quality_alpha(r),
                        "masked" => _row_masked(r),
                    ),
                )
            end
            isempty(pts) && return nothing
            return Dict{String, Any}(
                "title" => Dict{String, Any}(
                    "text" => "$(primary_obs_obj.label) vs $(yobs.label)",
                    "subtitle" => ["per-cell scatter across sweep",
                        "opacity = VSUP α"],
                ),
                "width" => 540, "height" => 420,
                "layer" => Any[Dict{String, Any}(
                    "data" => Dict("values" => pts),
                    "mark" => Dict("type" => "point", "filled" => true,
                        "size" => 90),
                    "encoding" => Dict{String, Any}(
                        "x" => Dict("field" => "x", "type" => "quantitative",
                            "title" => primary_obs_obj.label),
                        "y" => Dict("field" => "y", "type" => "quantitative",
                            "title" => yobs.label),
                        "fillOpacity" => Dict("field" => "alpha",
                            "type" => "quantitative",
                            "scale" => Dict("domain" => [0.0, 1.0],
                                "range" => [0.15, 1.0]),
                            "legend" => nothing),
                    ),
                )],
                "_meta" => Dict("primary" => true, "kind" => "correlation",
                    "observable" => String(primary_key),
                    "obs_y" => String(ykey)),
            )
        end

        # Build the PRIMARY mark by dispatching on (mode, relation).
        function _build_primary_mark()
            if mode == :failed
                return _build_quality_primary()
            end
            hypothesis === nothing && return nothing
            primary_obs_obj = nothing
            for o in result.observables
                if o.key === primary_key
                    primary_obs_obj = o
                    break
                end
            end
            primary_obs_obj === nothing && return nothing
            if relation === :asymptote
                return _build_asymptote_primary(primary_obs_obj)
            elseif relation === :collapse
                return _build_collapse_primary(primary_obs_obj)
            elseif relation === :residual
                return _build_residual_primary(primary_obs_obj)
            elseif relation === :scaling
                return _build_scaling_primary(primary_obs_obj)
            elseif relation === :correlation
                return _build_correlation_primary(primary_obs_obj)
            else
                return nothing
            end
        end

        function _push_spectrum(obs)
            marks = _build_m_dist_marks(obs.key)
            isempty(marks) && return nothing
            domain = vcat([string(m) for m in F:-1:(-F)], ["mixed"])
            palette = vcat(_dominant_m_palette(F), ["#9aa0a6"])
            title_block = Dict{String, Any}(
                "text" => obs.label * "  (dominant m)",
                "subtitle" => ["categorical: -F → +F + mixed",
                    "decision gap ≥ $(round(spectrum_margin; digits=2)) to commit"],
                "subtitleFontSize" => 10,
                "subtitleColor" => "#5a6068",
            )
            rect_layer = Dict{String, Any}(
                "data" => Dict("values" => marks),
                "mark" => Dict("type" => "rect"),
                "encoding" => Dict{String, Any}(
                    "x" => x_enc, "x2" => x2_enc,
                    "y" => y_enc, "y2" => y2_enc,
                    "fill" => Dict(
                        "field" => "dominant_m",
                        "type" => "nominal",
                        "scale" => Dict("domain" => domain, "range" => palette),
                        "legend" => Dict("title" => "dominant m",
                            "orient" => "right"),
                    ),
                    # VSUP for the categorical panel: masked cells fade
                    # toward grey. Unconverged dominant-m is garbage
                    # (computed off the optimiser's last unconverged
                    # state) — don't paint it at full strength.
                    "fillOpacity" => Dict(
                        "condition" => Dict(
                            "test" => "datum.masked == true",
                            "value" => 0.15),
                        "value" => 1.0,
                    ),
                    "tooltip" => [
                        Dict("field" => String(x_axis.name),
                            "type" => "quantitative",
                            "title" => "$(x_axis.name) [$(x_axis.unit)]"),
                        Dict("field" => String(y_axis.name),
                            "type" => "quantitative",
                            "title" => "$(y_axis.name) [$(y_axis.unit)]"),
                        Dict("field" => "dominant_m", "type" => "nominal",
                            "title" => "dominant m"),
                        Dict("field" => "decision_gap",
                            "type" => "quantitative",
                            "title" => "gap (top1−top2)", "format" => ".3f"),
                        Dict("field" => "masked", "type" => "nominal",
                            "title" => "unconverged"),
                    ],
                ),
            )
            layers = Any[base_layer(marks), rect_layer, hatch_layer(marks)]
            push!(
                panels,
                Dict{String, Any}(
                    "title" => title_block,
                    "width" => 280, "height" => 240,
                    "layer" => layers,
                    "_meta" => Dict("observable" => String(obs.key),
                        "kind" => String(obs.kind),
                        "margin" => spectrum_margin),
                ),
            )
        end

        # In failed mode the FailureAlert says "do not read as physics".
        # Honour that literally: emit ZERO physics thumbnails and zero
        # m_dist (computed off garbage). The quality_obs primary above is
        # the only panel. In partial/complete modes, thumbnails ride.
        if mode != :failed
            for obs in result.observables
                obs.role === :quality && continue
                if include_observables !== nothing && !(obs.key in include_observables)
                    continue
                end
                if obs.kind === :signed || obs.kind === :positive || obs.kind === :wide
                    _push_signed_or_positive(obs)
                elseif obs.kind === :spectrum
                    _push_spectrum(obs)
                end
            end
        end

        # Layout: PRIMARY (problem-shape-driven mark, if mode allows) on
        # top, then thumbnails in a 4-col grid. When mode = :failed, the
        # primary is suppressed entirely — the React side mounts a big
        # diagnostic alert in its place. Thumbnails are always emitted so
        # the user can still drill in.
        rows = Dict{String, Any}[]
        primary_panel = _build_primary_mark()
        if primary_panel !== nothing
            push!(rows, primary_panel)
        end
        cols_thumb = 4
        i = 1
        while i <= length(panels)
            row_panels = panels[i:min(i + cols_thumb - 1, end)]
            push!(
                rows,
                if length(row_panels) == 1
                    row_panels[1]
                else
                    Dict{String, Any}("hconcat" => row_panels)
                end,
            )
            i += cols_thumb
        end
        spec["vconcat"] = rows
        spec["_panels_count"] = length(panels) +
                                (primary_panel === nothing ? 0 : 1)
        spec["_grid_cols"] = cols_thumb
    elseif axes_dim == 1
        spec["vconcat"] = Dict{String, Any}[]
        spec["_note"] = "1D line view not yet emitted; only 2D heatmap implemented"
    else
        spec["vconcat"] = Dict{String, Any}[]
        spec["_note"] = "$(axes_dim)D facet grid not yet emitted"
    end

    hypothesis_block = if hypothesis !== nothing
        Dict{String, Any}(
            "question" => hypothesis.question,
            "relation" => String(hypothesis.relation),
            "primary_obs" => String(hypothesis.primary_obs),
            "models" => Dict{String, Any}(
                String(k) => Dict{String, Any}(
                    "label" => m.label,
                    "has_collapse_var" => m.collapse_var_fn !== nothing,
                    "collapse_var_label" => m.collapse_var_label,
                ) for (k, m) in hypothesis.models
            ),
            "params" => Dict{String, Any}(
                String(k) => v isa Function ? "<function>" : v
                for (k, v) in hypothesis.params
            ),
        )
    else
        nothing
    end
    narrative_block = if narrative isa AbstractDict
        Dict{String, Any}(
            "title" => string(get(narrative, :title,
                get(narrative, "title", ""))),
            "question" => string(
                get(narrative, :question,
                    get(narrative, "question",
                        hypothesis === nothing ? "" : hypothesis.question)),
            ),
            "hypothesis" => hypothesis_block,
            "n_total" => n_total,
            "n_converged" => n_converged,
            "mode" => String(mode),
        )
    else
        Dict{String, Any}(
            "title" => "",
            "question" => hypothesis === nothing ? "" : hypothesis.question,
            "hypothesis" => hypothesis_block,
            "n_total" => n_total,
            "n_converged" => n_converged,
            "mode" => String(mode),
        )
    end

    spec["_meta"] = Dict{String, Any}(
        "schema_version" => "1.4",
        "colormap_version" => SWEEP_COLORMAP_VERSION,
        "narrative" => narrative_block,
        "mode" => String(mode),
        "F" => F,
        "axes" => [
            Dict("name" => String(a.name),
                "scale" => String(a.scale),
                "unit" => a.unit,
                "n_values" => length(a.values)) for a in result.axes
        ],
        "observables" => [
            Dict("key" => String(o.key),
                "kind" => String(o.kind),
                "role" => String(o.role)) for o in result.observables
        ],
        "quality_observable" => quality_obs === nothing ? nothing : String(quality_obs.key),
        # `:narrative` skipped: the printable form lives at
        # `_meta.narrative` (above); the raw Hypothesis carries closures
        # that JSON can't serialise.
        "run_meta" => Dict(String(k) => v for (k, v) in result.meta
                                              if k !== :narrative),
    )

    return spec
end

"""
    write_viewspec(out_path, result::SweepResult; kwargs...) → String

Resolve and serialise a viewspec to JSON at `out_path`. Convenience for
the `m1_sweep_viewspec_export.jl` script.
"""
function write_viewspec(out_path::String, result::SweepResult; kwargs...)
    spec = to_viewspec(result; kwargs...)
    mkpath(dirname(out_path))
    open(out_path, "w") do io
        JSON.print(io, spec)
    end
    return out_path
end
