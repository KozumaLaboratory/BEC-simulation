using Test
using SpinorBEC
using SpinorBEC: resolve_gs, gs_model, gs_physics_kwargs, model_physics_kwargs,
    GSResolved, GroundStateStep, parse_pipeline, _run_yaml_prepare,
    restore_dealias_refs!, DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF, evaluate_potential,
    with, linear_p, quadratic_q, transverse_b

# `model_physics_kwargs` agrees with `gs_physics_kwargs` over the WHOLE corpus.
#
# WHY THIS EXISTS ALONGSIDE test_realise_matches_resolver.jl
#
# That file builds a real Workspace and compares it, which is the strongest check
# available — and costs FFT plans and an LHY table per config, so it runs over
# three. Three of 414 is the honest coverage of the realisation layer's agreement,
# and saying so was the last open item on the layer.
#
# This file closes it by dropping the Workspace: it compares the two BUNDLES, so
# it is cheap enough for every config whose ground-state step resolves to a Model.
# The two are complementary — depth on three, breadth on all of them.
#
# MEASURED BEFORE IT WAS GATED, which is why it is worth having: the first run
# reported four disagreement classes, and ALL FOUR were defects in the scan
# rather than in the layer. Counts are per (config, field), over the 414 compared:
#
#   57  lhy n_max     model=NaN, resolver=NaN — `NaN ≈ NaN` is false
#   39  lhy n_atoms   model=50000, resolver=1 — the #174 shape, and INERT:
#                     make_workspace guards `_build_spinor_lhy` on
#                     `spinor_lhy === nothing`, so `lhy_opts` is not read at all
#   16  pad_factor    DDI-off configs; `DDISpec` normalises to (1,1,1) at c_dd=0
#   16  trunc_radius  same 16, same reason
#
# The `n_atoms` one is the instructive one: it is exactly the signature of the
# most expensive LHY defect this repo has had, over configs where the field is
# never consulted. A scan that reports an inert field alarms about nothing and
# buries whatever is real.
#
# So the comparison is restricted to fields that are READ in the configuration
# being compared, and each restriction cites what does the reading. And because
# three exclusions can silence a real disagreement just as easily as a false one,
# there is a NEGATIVE CONTROL: a perturbed model must be detected, per class.

const _CWR_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const _CWR_RUNS = joinpath(_CWR_ROOT, "runs")

_cwr_files() = sort!(
    String[
        joinpath(r, f) for (r, _, fs) in walkdir(_CWR_RUNS)
        for f in fs if endswith(f, ".yaml") || endswith(f, ".yml")
    ],
)

"NaN-aware equality. Two NaNs agree about the sentinel; `≈` says they do not."
_cwr_same(a, b) = (a isa Real && b isa Real && isnan(a) && isnan(b)) || a ≈ b || a == b

"""Fields of the two bundles that disagree, as `(name, model, resolver)`.

Only fields READ in this configuration are compared — see the header for the four
inert-field false positives that taught the distinction."""
function _cwr_diffs(r::GSResolved, m)
    out = Tuple{String, Any, Any}[]
    kr = gs_physics_kwargs(r)
    km = model_physics_kwargs(m, r.grid)
    add(name, a, b) = _cwr_same(a, b) || push!(out, (name, a, b))

    for (k, v) in r.interactions.c
        if !haskey(km.interactions.c, k)
            push!(out, ("c[$k] missing", nothing, v))
        else
            add("c[$k]", km.interactions.c[k], v)
        end
    end
    for k in keys(km.interactions.c)
        haskey(r.interactions.c, k) ||
            push!(out, ("c[$k] extra", km.interactions.c[k], nothing))
    end
    add("c_lhy", km.interactions.c_lhy, r.interactions.c_lhy)

    add("p", linear_p(km.zeeman), linear_p(r.zeeman))
    add("q", quadratic_q(km.zeeman), quadratic_q(r.zeeman))
    bxm, bym = transverse_b(km.zeeman, 0.0)
    bxr, byr = transverse_b(r.zeeman, 0.0)
    add("bx", bxm, bxr)
    add("by", bym, byr)

    # The potential is compared EVALUATED: a one-term `CompositePotential` is a
    # different object from the bare term and the same function of position, and
    # position is what the propagator reads.
    Vm = Array(evaluate_potential(km.potential, r.grid))
    Vr = Array(evaluate_potential(r.potential, r.grid))
    Vm ≈ Vr || push!(out, ("V_trap", maximum(abs, Vm .- Vr), 0.0))

    add("enable_ddi", km.enable_ddi, kr.enable_ddi)
    # Kernel-shaping knobs only when there IS a kernel: `make_ddi_params` is not
    # called at all with `enable_ddi=false`, and `DDISpec` normalises its fields
    # to the inactive values at `c_dd = 0` while the resolver keeps what the YAML
    # said.
    if kr.enable_ddi
        add("c_dd", km.c_dd, kr.c_dd)
        add("secular_ddi", km.secular_ddi, kr.secular_ddi)
        add("quasi_2d_ddi", km.quasi_2d_ddi, kr.quasi_2d_ddi)
        add("l_z_ddi", km.l_z_ddi, kr.l_z_ddi)
        add("ddi_padding", km.ddi_padding, kr.ddi_padding)
        pfr = if kr.ddi_pad_factor isa Real
            ntuple(_ -> Float64(kr.ddi_pad_factor), r.ndim)
        else
            kr.ddi_pad_factor
        end
        all(km.ddi_pad_factor .≈ pfr) ||
            push!(out, ("pad_factor", km.ddi_pad_factor, pfr))
        add("trunc_radius", km.ddi_trunc_radius, kr.ddi_trunc_radius)
    end

    km.spinor_lhy === kr.spinor_lhy ||
        push!(out, ("spinor_lhy", km.spinor_lhy, kr.spinor_lhy))
    # `lhy_opts` is read only inside `_build_spinor_lhy`, which
    # `make_workspace.jl` guards on `spinor_lhy === nothing || === :none`.
    if kr.spinor_lhy !== nothing && kr.spinor_lhy !== :none
        add("lhy n_atoms", km.lhy_opts.n_atoms, kr.lhy_opts.n_atoms)
        add("lhy n_max", km.lhy_opts.n_max, kr.lhy_opts.n_max)
        add("lhy n_points", km.lhy_opts.n_points, kr.lhy_opts.n_points)
        add("lhy n_bins", km.lhy_opts.n_bins, kr.lhy_opts.n_bins)
    end
    out
end

"""`(resolved, model)` for one config, or `nothing` if it does not get that far.

Restores the dealias `Ref`s: `_run_yaml_prepare` leaves them set, and a reader
that does not restore rewrites the `GridSpec` of every config resolved after it
(arm 3 of `test_corpus_resolves.jl`)."""
function _cwr_resolve(path::String)
    was_en, was_kc = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
    try
        data = _run_yaml_prepare(path, false, false)
        cfg = parse_pipeline(Dict{Any, Any}(data))
        gs = nothing
        for s in cfg.steps
            s isa GroundStateStep && (gs=s; break)
        end
        gs === nothing && return nothing
        r = resolve_gs(gs.params, nothing, nothing, nothing; verbose=false)::GSResolved
        m = try
            gs_model(r)
        catch
            # No Model is expected for part of the corpus and is
            # `test_corpus_resolves.jl`'s business, not this file's.
            nothing
        end
        m === nothing ? nothing : (r, m)
    catch
        nothing
    finally
        restore_dealias_refs!(was_en, was_kc)
    end
end

@testset "realisation agrees with the resolver over the whole corpus" begin
    compared = 0
    disagreeing = Tuple{String, Vector}[]
    probe = nothing

    for p in _cwr_files()
        rm_ = _cwr_resolve(p)
        rm_ === nothing && continue
        r, m = rm_
        compared += 1
        d = _cwr_diffs(r, m)
        isempty(d) || push!(disagreeing, (relpath(p, _CWR_ROOT), d))
        # Keep the first config with DDI and LHY both active, so every class has
        # something for the negative control to perturb.
        if probe === nothing && r.enable_ddi && r.spinor_lhy !== nothing &&
            r.spinor_lhy !== :none
            probe = (r, m)
        end
    end

    @testset "the scan compared a real population" begin
        # Without this, "0 disagreements" and "compared nothing" print the same.
        @test compared > 300
    end

    @testset "no config disagrees" begin
        for (f, d) in first(disagreeing, 20)
            @info "realisation disagrees with the resolver" config = f fields = d
        end
        @test isempty(disagreeing)
    end

    @testset "negative control: a perturbed model IS detected, per class" begin
        # THE assertion that makes the clean result mean something. Four
        # exclusions above say "this field is not read here"; if one of them were
        # too wide it would silence a real disagreement, and only a planted one
        # can tell.
        @test probe !== nothing
        if probe !== nothing
            r, m = probe
            for (label, m2) in [
                ("zeeman p", with(m; zeeman=with(m.zeeman; p=m.zeeman.p + 1.0))),
                ("interactions c1",
                    with(m; interactions=with(m.interactions; c1=m.interactions.c1 + 1.0))),
                ("ddi c_dd", with(m; ddi=with(m.ddi; c_dd=m.ddi.c_dd * 2 + 1))),
                ("ddi secular", with(m; ddi=with(m.ddi; secular=(!m.ddi.secular)))),
            ]
                @testset "$label" begin
                    d = _cwr_diffs(r, m2)
                    isempty(d) &&
                        @info "BLIND: the comparison cannot see this class" class = label
                    @test !isempty(d)
                end
            end
        end
    end
end
