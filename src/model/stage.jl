# --- Stage: one computation, declared in full ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.2.
#
# `Model` says what the physics IS. `Stage` says what is being computed from it,
# how, on what, and from which predecessor. The split is the reason a `Model`
# can be identical across a CPU audit and a GPU production run while the two
# artifacts stay distinct: everything that changes the numbers without changing
# the physics lives here.
#
# `Stage` is deliberately NOT a `ModelValue`. `params::NamedTuple` carries its
# field types per instance, so it cannot satisfy the shape gate's leaf rule, and
# admitting it would quietly widen an invariant that `Model` actually holds.

export Stage, stage, STAGE_KINDS

"What a stage does. Closed: the three verbs the design names, and no others."
const STAGE_KINDS = (:relax, :evolve, :measure)

"""
    Stage(kind, model, method, from, params, backend)
    stage(kind; model, method, from=nothing, backend=:cpu, params...)

One computation over one `Model`.

| field | meaning |
|---|---|
| `kind` | `:relax` (find a state) / `:evolve` (propagate one) / `:measure` (read one) |
| `model` | the resolved physics |
| `method` | which algorithm — `:itp`, `:lbfgs`, `:strang`, `:bdg`, … |
| `from` | the predecessor whose output seeds this one; `nothing` = from scratch |
| `params` | the numerics: `dt`, `n_steps`, `tol`, `save_every`, `seed`, … |
| `backend` | `:cpu` or `:gpu` |

`params` is where the numerics become part of the identity **by construction**
rather than by a rule someone has to remember to follow — `artifact_id` hashes
the whole struct, so there is no selection step in which a save cadence or a
tolerance can be left out.

`method` is deliberately unvalidated. A closed list here would be a second
declaration of which solvers exist, drifting against the real dispatch in
`solvers/`; `kind` is closed because its three values are the design's own
taxonomy and nothing else dispatches on them.

`backend` is checked by calling `_resolve_backend` (`foundation/backend.jl:98`)
and discarding the result, so the admissible set is declared exactly once. It
matters: `:cuda` looks admissible, and that function throws on it.
"""
struct Stage
    kind::Symbol
    model::Model
    method::Symbol
    from::Union{Nothing, Stage}
    params::NamedTuple
    backend::Symbol

    function Stage(kind::Symbol, model::Model, method::Symbol,
        from::Union{Nothing, Stage}, params::NamedTuple, backend::Symbol)
        kind in STAGE_KINDS ||
            throw(ArgumentError("stage kind must be one of $STAGE_KINDS; got :$kind"))
        method === Symbol("") &&
            throw(ArgumentError("stage method must be named; got an empty symbol"))
        _resolve_backend(backend)
        new(kind, model, method, from, params, backend)
    end
end

stage(kind::Symbol; model::Model, method::Symbol, from::Union{Nothing, Stage}=nothing,
    backend::Symbol=:cpu, params...) = Stage(
    kind, model, method, from, NamedTuple(params), backend)

# Same reason `ModelValue` needs them: `params` and `model` reach `Vector`
# fields, so the default `==` is `===`, i.e. object identity, and two stages
# parsed from the same declaration would compare unequal. `_speceq`/`_spechash`
# recurse structurally and already handle the `nothing` arm of `from`.
Base.:(==)(a::Stage, b::Stage) = _speceq(a, b)
Base.hash(s::Stage, h::UInt) = _spechash(s, h)
