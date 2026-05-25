# --- sweep_runs / compare_runs operations ---
#
# Constructors that lift multiple/paired RunResults into RunSweep /
# RunComparison. The path-based form `sweep_runs(::Vector{String})`
# is the lightweight Phase-2 surface — it composes opens with a
# parametric label. A YAML-driven `sweep_runs(yaml; vary)` that
# *runs* the pipeline N times is Phase-3 work (depends on
# run_yaml + override machinery; deferred to keep this commit
# narrow).

export sweep_runs, compare_runs

"""
    sweep_runs(paths::AbstractVector{<:AbstractString}; vary::Pair{Symbol,<:Vector}) -> RunSweep

Open each jld2 in `paths` and wrap into a `RunSweep` with the supplied
`varying` axis. Lengths must match; the i-th path corresponds to the
i-th varying value.

```julia
sweep = sweep_runs(["runs/L4_32/point_001.jld2",
                    "runs/L4_48/point_001.jld2",
                    "runs/L4_64/point_001.jld2"];
                   vary = :grid => [32, 48, 64])
sweep.runs[1].Fz_drift
```
"""
function sweep_runs(
    paths::AbstractVector{<:AbstractString};
    vary::Pair{Symbol, <:AbstractVector},
)
    length(paths) == length(vary.second) || throw(
        ArgumentError(
            "sweep_runs: paths length $(length(paths)) ≠ varying values length $(length(vary.second))"
        ),
    )
    runs = RunResult[open_result(String(p)) for p in paths]
    RunSweep(runs, Pair(vary.first, collect(Any, vary.second)))
end

"""
    compare_runs(a::RunResult, b::RunResult; label_a="A", label_b="B") -> RunComparison

Pair two RunResults for A/B diff. Labels distinguish sides in
downstream `check(::OperatorRHSSpec, ::RunComparison)` verdicts.

```julia
c = compare_runs(open_result("ours.jld2"), open_result("theirs.jld2");
                 label_a="ours", label_b="theirs")
```
"""
compare_runs(a::RunResult, b::RunResult; label_a="A", label_b="B") = RunComparison(
    a, b; label_a, label_b
)
