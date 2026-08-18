# --- Checkpoint: keyed JLD2-backed result store with fork (branch / refine) ---
#
# General-purpose primitive: any deterministic (or expensive)
# computation can be checkpointed under a key, with `get_or_compute!`
# returning the cached value if it exists. `fork!` is the universal
# "load + transform + save" operation:
#
#   - `fork!(cp, parent, child, transform)` with `child ≠ parent`
#     → branch (git checkout -b — both coexist; child metadata
#       records the parent for ancestry walking)
#   - `fork!(cp, key, key, transform)` with same key
#     → in-place refinement (extend / continue / update)
#
# Use directly for:
#
#   - ITP / LBFGS convergence resumed across kill/restart cycles
#     (`fork!(cp, "psi_500", "psi_500", extend_lbfgs)`)
#   - "What if" parameter branches from a warm state
#     (`fork!(cp, "psi_500", "psi_500_c1pos", continue_with_c1=+0.3)`)
#   - Multi-stage pipelines (each stage forks the previous)
#   - Bayesian opt / active-learning iteration trees
#   - Trajectory ensembles (each (seed, params) is a key)

export Checkpoint, get_or_compute!, fork!, has_checkpoint,
    load_checkpoint, save_checkpoint!, list_keys, parent_of, ancestry

using JLD2

"""
    Checkpoint(cache_dir)

A JLD2-backed keyed result store. Each key maps to one file
`<cache_dir>/<sanitised(key)>.jld2`. Three primitive operations:

  - `get_or_compute!(cp, key, compute)` — memoise expensive work
    keyed by `key`. Returns cached if present.
  - `fork!(cp, source_key, target_key, transform; predicate)` —
    `(load source, transform, save target)`. If `target == source`,
    advances the checkpoint in place; otherwise branches off with
    parent metadata.
  - `load_checkpoint(cp, key)` / `save_checkpoint!(cp, key, result)`
    — raw access.

Keys can be `String`, `Symbol`, `NamedTuple`, or any value with a
unique `string(key)` representation. Filename sanitisation strips
characters outside `[A-Za-z0-9_.\\-]` to keep paths portable.

# Examples

```julia
cp = Checkpoint("runs/my_experiment")

# Memoise an expensive computation
result = get_or_compute!(cp, "phi_table_F6", () -> compute_phi_table(6))

# Iterative in-place refinement (advance the same checkpoint)
fork!(cp, "psi_at_B100", "psi_at_B100",
    prev -> extend_lbfgs(prev.psi, n=10_000);
    predicate = r -> r.grad_norm < 1e-5)

# Branch off into "what if" alternatives
fork!(cp, "psi_at_step_1000", "psi_c1_pos",
    s -> continue_itp(s; c1=+0.3))
fork!(cp, "psi_at_step_1000", "psi_c1_neg",
    s -> continue_itp(s; c1=-0.3))

ancestry(cp, "psi_c1_pos")  # ["psi_at_step_1000", "psi_c1_pos"]
```
"""
struct Checkpoint
    cache_dir::String
end

"""
Resolve the JLD2 path for a key. Sanitised to keep filenames portable.
"""
function key_to_path(cp::Checkpoint, key)
    raw = string(key)
    safe = replace(raw, r"[^A-Za-z0-9_.\-]+" => "_")
    joinpath(cp.cache_dir, safe * ".jld2")
end

"""
    has_checkpoint(cp, key) → Bool

True iff the key has a saved result.
"""
has_checkpoint(cp::Checkpoint, key) = isfile(key_to_path(cp, key))

"""
    load_checkpoint(cp, key) → Union{Nothing, Any}

Return the saved result, or `nothing` if the key is not in the store.
"""
function load_checkpoint(cp::Checkpoint, key)
    path = key_to_path(cp, key)
    isfile(path) || return nothing
    return JLD2.load(path, "result")
end

"""
    save_checkpoint!(cp, key, result; metadata=nothing) → result

Persist `result` under `key`. Optional `metadata` is saved alongside
(`JLD2.load(path, "metadata")`). Overwrites any existing checkpoint
at `key`.

# Portability note for wavefunctions

`result` is serialised by JLD2 verbatim. Plain CPU arrays (Array,
SVector, NamedTuple of scalars) round-trip cleanly with no special
handling. **CuArray fields ALSO save** (CUDA.jl provides the
serialiser) but the loaded value reconstructs ON the GPU at load
time, which:

  - requires CUDA at load (fails on CPU-only restart),
  - allocates GPU memory immediately (fails if GPU is busy),
  - is tied to the specific device (non-portable across hosts).

For checkpoint files that should survive process / host changes,
convert wavefunctions to CPU arrays before saving:

```julia
result = (; psi=Array(ws.state.psi), E=ws.energy, ...)
save_checkpoint!(cp, key, result)
```

This is the convention used by the archived `sprint5_M1_*.jl` drivers.
"""
function save_checkpoint!(cp::Checkpoint, key, result; metadata=nothing)
    mkpath(cp.cache_dir)
    path = key_to_path(cp, key)
    JLD2.jldsave(path; result=result, metadata=metadata, key=key)
    return result
end

"""
    get_or_compute!(cp, key, compute; force=false, metadata=nothing) → result

If `key` is in the store and `force` is false, return the cached
result. Otherwise call `compute()`, save under `key`, and return.

Use for memoisation where the cached value is correct iff `key`
uniquely identifies the inputs.
"""
function get_or_compute!(cp::Checkpoint, key, compute;
    force::Bool=false, metadata=nothing)
    if !force
        cached = load_checkpoint(cp, key)
        cached === nothing || return cached
    end
    result = compute()
    save_checkpoint!(cp, key, result; metadata=metadata)
    return result
end

"""
    fork!(cp, source_key, target_key, transform; predicate=nothing, metadata=nothing) → result

Universal "load + transform + save" operation:

  - `target_key == source_key` → in-place refinement. The
    checkpoint advances. No parent metadata is recorded (the key's
    history isn't a branch, it's a continuation).
  - `target_key != source_key` → branch (like `git checkout -b`).
    Both keys coexist. The child's metadata records
    `parent_key=string(source_key)` so `ancestry(cp, target_key)`
    walks back to the root.

If `predicate` is supplied and `predicate(source) === true`, the
transform is skipped and the source is returned unchanged. Useful
for "extend until converged" patterns where already-good cells
should not be re-extended.

When branching (target ≠ source), throws `ArgumentError` if the
target key already exists — use `save_checkpoint!` directly to
overwrite a sibling branch on purpose. When refining in place
(target == source), the existing checkpoint IS overwritten —
that's the point of in-place advancement.
"""
function fork!(cp::Checkpoint, source_key, target_key, transform;
    predicate::Union{Nothing, Function}=nothing,
    metadata=nothing)
    source = load_checkpoint(cp, source_key)
    source === nothing &&
        throw(ArgumentError("fork!: no checkpoint at source_key=$(source_key)"))

    if predicate !== nothing && predicate(source)
        return source
    end

    same_key = string(target_key) == string(source_key)
    if !same_key && has_checkpoint(cp, target_key)
        throw(
            ArgumentError(
                "fork!: target_key=$(target_key) already exists. " *
                "Use save_checkpoint! to overwrite a sibling branch explicitly.",
            ),
        )
    end

    transformed = transform(source)

    final_meta = if same_key
        # In-place advancement: no parent metadata. Caller's metadata only.
        metadata
    else
        # Branch: record parent_key in metadata for ancestry walking.
        parent_entry = (parent_key=string(source_key),)
        if metadata === nothing
            parent_entry
        elseif metadata isa NamedTuple
            merge(parent_entry, metadata)
        elseif metadata isa AbstractDict
            out = Dict{Symbol, Any}(:parent_key => string(source_key))
            for (k, v) in metadata
                out[Symbol(k)] = v
            end
            NamedTuple(out)
        else
            (parent_entry..., user=metadata)
        end
    end

    save_checkpoint!(cp, target_key, transformed; metadata=final_meta)
    return transformed
end

"""
    list_keys(cp) → Vector{String}

Return the (filename-sanitised) keys present in the store. Order is
filesystem-dependent.
"""
function list_keys(cp::Checkpoint)
    isdir(cp.cache_dir) || return String[]
    files = filter(f -> endswith(f, ".jld2"), readdir(cp.cache_dir))
    return [splitext(f)[1] for f in files]
end

"""
    parent_of(cp, key) → Union{Nothing, String}

Return the parent key stored in `key`'s fork metadata, or `nothing`
if the checkpoint has no parent (root, or saved without fork! /
branched-then-in-place-advanced).
"""
function parent_of(cp::Checkpoint, key)
    path = key_to_path(cp, key)
    isfile(path) || return nothing
    meta = try
        JLD2.load(path, "metadata")
    catch
        return nothing
    end
    meta === nothing && return nothing
    if meta isa NamedTuple && haskey(meta, :parent_key)
        return String(meta.parent_key)
    elseif meta isa AbstractDict && haskey(meta, :parent_key)
        return String(meta[:parent_key])
    end
    return nothing
end

"""
    ancestry(cp, key) → Vector{String}

Walk parent_key metadata from `key` back to the root. Returns the
chain `root → … → key`. Useful for tracing where a branched
checkpoint came from.
"""
function ancestry(cp::Checkpoint, key)
    chain = [string(key)]
    cur = string(key)
    seen = Set{String}(chain)
    while true
        p = parent_of(cp, cur)
        p === nothing && break
        p in seen && break  # cycle guard
        push!(chain, p)
        push!(seen, p)
        cur = p
    end
    return reverse(chain)
end
