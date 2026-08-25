# --- ObservableDefinition: what was measured, stated before the number exists ---
#
# The half of `reanalyze` (#483) that a caller writes down FIRST. Split out of
# `reanalysis.jl` when the entry point grew its multi-observable form, because
# these are the definitions and that file is the reader.
#
# The three required fields are the ledger's own (`window`, `reduction`,
# `boundary` in `docs/campaign/claims.toml`), validated against the ledger's own
# sets, so a result transcribes into a `[[claim]]` row without anyone re-deciding
# what the window was.

export ObservableDefinition, hold_window_frames

"""
    REANALYSIS_WINDOWS

The windows a re-analysis may take a reduction over. A named set, because the
window is part of the measurement and "the whole trajectory" is a CHOICE that
has already been wrong once at production scale.

  `:all`         — every frame. Legal, and the default nowhere: at 10.4 nT four
                   arms differing only in the hold returned peak `P_adj` equal to
                   five decimals, because the maximum sat in the pre-hold
                   transient (argmax frame 29, hold from frame 32).
  `:last`        — the last `n` frames, `n` from `window_frames`. What "inside the
                   hold" means when the hold is the final step.
  `:first`       — the first `n` frames.
  `:range`       — an explicit `window_frames = lo:hi`.
  `:predicate`   — frames where `window_predicate(i, aux)` holds. For a window
                   defined by a physical condition rather than a frame count
                   (`klaus2022_reanalyse.jl` needs "frames where θ has reached 0").
"""
const REANALYSIS_WINDOWS = (:all, :last, :first, :range, :predicate)

"""
    REANALYSIS_REDUCTIONS

How a windowed series collapses to one number. `:max` / `:min` / `:mean` /
`:final` / `:first` / `:argmax` / `:argmin` / `:sum`.

`:max` and `:final` fail DIFFERENTLY — a peak is contaminated by a transient
that a mean only dilutes and a final sample ignores — which is why
`klaus_weff_extract.jl` keeps three readings and refuses an ordering they
disagree on. `reanalyze` computes all of them (`readings`) and reports the one
asked for, so that refusal is available without a second pass.

There is deliberately no `:rms`: it is `sqrt` of the `:mean` of a squared series,
and a caller wanting one passes the squared series (`klaus2022_reanalyse.jl`
does, for its misalignment angle). A reduction that can be composed out of the
set does not join the set.
"""
const REANALYSIS_REDUCTIONS = (:max, :min, :mean, :final, :first, :argmax, :argmin, :sum)

"""
    ObservableDefinition(name; window, reduction, boundary, window_frames,
                         window_predicate, series)

What was measured, stated before the number exists.

The three required fields are the ledger's (`window`, `reduction`, `boundary` in
`docs/campaign/claims.toml`), spelled the same way and validated against the same
sets, so a `Reanalysis` can be transcribed into a `[[claim]]` row without anyone
re-deciding what the window was. `boundary` must be one of
[`CLAIM_BOUNDARY_RULES`](@ref) — and `:unchecked` is a legal answer that reads as
"nobody looked", which is the whole point of it being a field.

`boundary = "reject"` is enforced, not recorded: an argmax landing on the edge of
its window is returned as a `boundary_hit` with the value withheld, because a
truncated maximum is not a peak.

`series` names which extracted series this observable reduces, and is REQUIRED in
the multi-observable form of [`reanalyze`](@ref) — several observables over one
read of a file have to say which one each of them is about.
"""
struct ObservableDefinition
    name::String
    window::Symbol
    reduction::Symbol
    boundary::String
    window_frames::Union{Nothing, Int, UnitRange{Int}}
    window_predicate::Union{Nothing, Function}
    series_key::Union{Nothing, String}

    function ObservableDefinition(name::AbstractString;
        window::Symbol,
        reduction::Symbol,
        boundary::AbstractString,
        window_frames::Union{Nothing, Int, UnitRange{Int}}=nothing,
        window_predicate::Union{Nothing, Function}=nothing,
        series::Union{Nothing, AbstractString}=nothing,
    )
        isempty(strip(name)) && throw(
            ArgumentError(
                "ObservableDefinition: `name` is what the number will be called in a " *
                "document; an unnamed observable cannot be quoted"),
        )
        window in REANALYSIS_WINDOWS || throw(
            ArgumentError(
                "ObservableDefinition: window `$window` not one of $REANALYSIS_WINDOWS"),
        )
        reduction in REANALYSIS_REDUCTIONS || throw(
            ArgumentError(
                "ObservableDefinition: reduction `$reduction` not one of $REANALYSIS_REDUCTIONS"
            ),
        )
        boundary in CLAIM_BOUNDARY_RULES || throw(
            ArgumentError(
                "ObservableDefinition: boundary `$boundary` not one of " *
                "$CLAIM_BOUNDARY_RULES. These are the ledger's own values " *
                "(`CLAIM_BOUNDARY_RULES`); `unchecked` is legal and means nobody " *
                "looked, which must not be able to read as `reject`"),
        )
        if window in (:last, :first)
            window_frames isa Int && window_frames > 0 || throw(
                ArgumentError(
                    "ObservableDefinition: window `$window` needs `window_frames::Int > 0` " *
                    "(got $(repr(window_frames)))"),
            )
        elseif window === :range
            window_frames isa UnitRange{Int} && !isempty(window_frames) || throw(
                ArgumentError(
                    "ObservableDefinition: window `:range` needs a non-empty " *
                    "`window_frames::UnitRange{Int}` (got $(repr(window_frames)))"),
            )
        elseif window === :predicate
            window_predicate === nothing && throw(
                ArgumentError(
                    "ObservableDefinition: window `:predicate` needs `window_predicate`"),
            )
        end
        new(String(name), window, reduction, String(boundary),
            window_frames, window_predicate,
            series === nothing ? nothing : String(series))
    end
end

"""
    hold_window_frames(hold_duration; dt, save_every) -> Int

How many saved frames the final hold occupies: `floor(hold_duration / (dt *
save_every))`, at least 1.

ONE STATEMENT OF A DERIVATION THAT IS SILENT WHEN WRONG. Three drivers computed
this inline, from three copies of the same expression, over three suites' own
constants — and `lt64_endpoint_verdict.jl` records what that costs: its first run
used `save_every = 100` where the suite saves every 1000, got a 200-frame window
over a 20-frame array, and every "hold peak" it printed was a whole-trajectory
argmax. Nothing errored. It was caught because one of the three arm groups had a
recorded number to disagree with.

`dt` and `save_every` are REQUIRED keywords with no defaults. A default here is
the same defect one level up: it would let a caller inherit another suite's
cadence without writing it down. The counterpart guard is in the window itself —
a `:last` window longer than the series is refused rather than clamped.
"""
function hold_window_frames(hold_duration::Real; dt::Real, save_every::Integer)
    (dt > 0 && save_every > 0 && hold_duration > 0) || throw(
        ArgumentError(
            "hold_window_frames: needs hold_duration, dt, save_every all > 0 " *
            "(got $hold_duration, $dt, $save_every)"),
    )
    max(1, Int(floor(hold_duration / (dt * save_every))))
end

# The frame range a window selects out of a series of length `n`.
function _window_range(obs::ObservableDefinition, n::Int, aux)
    n > 0 || throw(ArgumentError("reanalyze: empty series for `$(obs.name)`"))
    if obs.window === :all
        return 1:n
    elseif obs.window in (:last, :first)
        # REFUSED, NOT CLAMPED. `max(1, n - w + 1)` silently turns an over-long
        # hold window into the whole trajectory, which is the defect
        # `lt64_endpoint_verdict.jl` records having shipped once: a 200-frame
        # window over a 20-frame array printed the pre-hold transient as the hold
        # peak, and only one of three arm groups had a stored number to catch it.
        obs.window_frames <= n || throw(
            ArgumentError(
                "reanalyze: window `$(obs.window) $(obs.window_frames)` does not fit " *
                "a series of length $n for `$(obs.name)`. Clamping it would silently " *
                "widen the window to the whole trajectory and report a different " *
                "observable under the declared name. Either this arm is short — say " *
                "so — or the frame count is wrong: check `hold_window_frames`'s " *
                "`dt` and `save_every` against THIS suite's config"),
        )
        return obs.window === :last ? ((n - obs.window_frames + 1):n) : (1:(obs.window_frames))
    elseif obs.window === :range
        lo, hi = first(obs.window_frames), last(obs.window_frames)
        (lo >= 1 && hi <= n) || throw(
            ArgumentError(
                "reanalyze: window $(obs.window_frames) does not fit a series of " *
                "length $n. A window silently clipped to the data is how a reduction " *
                "starts reporting a different observable than the one declared"),
        )
        return lo:hi
    else
        keep = [i for i in 1:n if obs.window_predicate(i, aux) === true]
        isempty(keep) && throw(
            ArgumentError(
                "reanalyze: window predicate selected no frames out of $n for " *
                "`$(obs.name)`. An empty window is a failed selection, not a missing " *
                "value — a NaN here would be quoted as a measurement"),
        )
        keep == collect(first(keep):last(keep)) || throw(
            ArgumentError(
                "reanalyze: window predicate selected a non-contiguous set of frames " *
                "($(length(keep)) frames spanning $(first(keep)):$(last(keep))). " *
                "A reduction over a gapped window is not the observable its name says"),
        )
        return first(keep):last(keep)
    end
end

# All reductions over one window, in one pass. Cheap, and having them all is what
# makes "the ordering does not survive the definition" a checkable statement
# instead of a suspicion.
function _readings(series::AbstractVector{<:Real}, rng::UnitRange{Int})
    w = @view series[rng]
    imax = argmax(w)
    imin = argmin(w)
    (max=Float64(w[imax]), min=Float64(w[imin]),
        mean=Float64(sum(w) / length(w)), sum=Float64(sum(w)),
        final=Float64(w[end]), first=Float64(w[1]),
        argmax=Float64(first(rng) - 1 + imax),
        argmin=Float64(first(rng) - 1 + imin),
        n=length(w), from=first(rng), to=last(rng))
end

_pick(r::NamedTuple, reduction::Symbol) = getproperty(r, reduction)

# Did the argmax (or argmin) land on an edge of the window? Only meaningful for
# the extremum reductions — a mean has no argmax to truncate.
function _boundary_hit(obs::ObservableDefinition, r::NamedTuple, n_series::Int)
    k = if obs.reduction in (:max, :argmax)
        Int(r.argmax)
    elseif obs.reduction in (:min, :argmin)
        Int(r.argmin)
    else
        return false
    end
    # An edge of the WINDOW is only a truncation when there is data beyond it.
    # The last frame of the whole run is the end of the experiment, not a cut —
    # otherwise every `:final`-shaped peak would be flagged and the rule would be
    # the too-strict kind that gets switched off.
    (k == r.from && r.from > 1) || (k == r.to && r.to < n_series)
end
