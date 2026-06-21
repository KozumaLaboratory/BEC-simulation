# Sweep result contract: the tidy carrier + declared structure.
#
# `SweepResult{T}` is the single source of truth that both the dashboard
# `to_viewspec` pipeline and Makie `plot_sweep` consume. `SweepAxis` /
# `SweepObservable` declare the sweep's structure; `ModelSpec` /
# `Hypothesis` carry the theoretical apparatus.
#
# Notably `m` is NOT a sweep axis; it lives inside a `spectrum`-kind
# observable's `index` slot. `view_shape` dispatch is keyed on
# `count(length(a.values) > 1 for a in axes)` and putting `m` in `axes`
# would silently break it.

export SweepAxis,
    SweepObservable,
    SweepResult,
    ModelSpec,
    Hypothesis,
    dominant_m_with_margin

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
