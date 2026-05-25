# --- Top-level convenience layer ---
#
# 1-liner end-to-end flows that compose run_yaml + open_result + check
# + save_operator_rhs. These are the API anko hits from the REPL —
# no script files needed.

export audit, hand_off, diff_yamls

"""
    audit(yaml::AbstractString; spec=ConservationSpec(), verbose=true) -> CheckResult

End-to-end: run the YAML, open the produced `point_001.jld2`, apply
`spec`, return the verdict. Replaces the entire
`scripts/validation/eu_ham_only_*_analyze.jl` pattern with a single
function call.

```julia
res = audit("runs/eu_ham_only_conservation/eu_ham_only_24_nonsec.yaml";
            spec=ConservationSpec(norm_drift=1e-12, Jz_drift=5e-2))
res.pass            # Bool
res.summary         # human-readable summary
```
"""
function audit(
    yaml::AbstractString;
    spec=ConservationSpec(),
    verbose::Bool=true,
)
    run_dir = run_yaml(String(yaml); verbose)
    jld2 = joinpath(run_dir, "point_001.jld2")
    isfile(jld2) || throw(
        ArgumentError(
            "audit: $jld2 not produced by run_yaml (pipeline error? cached?)"),
    )
    r = open_result(jld2)
    check(spec, r)
end

"""
    hand_off(yaml::AbstractString; output_dir::AbstractString=dirname(yaml),
             verbose=true) -> NamedTuple

End-to-end Ueda-style operator-RHS hand-off. The YAML must contain an
`hpsi_export` analyzer so the pipeline produces both `point_001.jld2`
(used for our records) AND `operator_rhs.jld2` (used here).

Returns the `save_operator_rhs` artefact NamedTuple
`(jld2_path, manifest_path, sha256)`. Replaces the bulk of the old
`scripts/validation/export_operator_rhs.jl`.

```julia
art = hand_off("docs/validation/step6_ueda_reference_state/reference_state.yaml")
art.jld2_path
art.sha256
```
"""
function hand_off(
    yaml::AbstractString;
    output_dir::AbstractString=dirname(abspath(String(yaml))),
    verbose::Bool=true,
)
    yaml_str = String(yaml)
    out_dir = String(output_dir)
    # `hpsi_export` analyzer drops `operator_rhs.jld2` in the YAML's own
    # directory. We need it co-located for the loader; the user supplies
    # a separate output_dir for the canonical artefact + MANIFEST.
    yaml_dir = dirname(abspath(yaml_str))
    pre_existing = joinpath(yaml_dir, "operator_rhs.jld2")
    isfile(pre_existing) && rm(pre_existing)

    run_yaml(yaml_str; verbose)

    isfile(pre_existing) || throw(
        ArgumentError(
            "hand_off: $pre_existing not produced. YAML must include\n" *
            "    analyze:\n" *
            "      - hpsi_export: {path: \"operator_rhs.jld2\"}\n" *
            "as a pipeline step. See docs/validation/step6_ueda_reference_state/."),
    )

    r = open_result(pre_existing)
    save_operator_rhs(r, out_dir)
end

"""
    diff_yamls(yaml_a::AbstractString, yaml_b::AbstractString;
               spec=OperatorRHSSpec(), label_a="A", label_b="B",
               verbose=true) -> CheckResult

Run two YAMLs and bilaterally diff their results. Default spec is
`OperatorRHSSpec` (operator-RHS Level-10 comparison), but
`ConservationSpec` on `RunComparison` also works if you only want to
compare drift bounds.

Both YAMLs must include the `hpsi_export` analyzer for the default
OperatorRHSSpec to apply.
"""
function diff_yamls(
    yaml_a::AbstractString, yaml_b::AbstractString;
    spec=OperatorRHSSpec(),
    label_a::AbstractString="A",
    label_b::AbstractString="B",
    verbose::Bool=true,
)
    run_dir_a = run_yaml(String(yaml_a); verbose)
    run_dir_b = run_yaml(String(yaml_b); verbose)
    pick_jld2(d) =
        let p = joinpath(d, "operator_rhs.jld2")
            isfile(p) ? p : joinpath(d, "point_001.jld2")
        end
    ra = open_result(pick_jld2(run_dir_a))
    rb = open_result(pick_jld2(run_dir_b))
    check(spec, compare_runs(ra, rb; label_a, label_b))
end
