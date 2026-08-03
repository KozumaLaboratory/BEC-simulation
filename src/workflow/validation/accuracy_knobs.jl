# --- Which settings trade accuracy, and what is the most accurate one? ---
#
# This project predicts things nobody has measured. Validation type C — agreement
# with published experiment — is unavailable for exactly the results it exists
# for, so the whole weight of a novel prediction rests on the numerics being
# right. Under that standard an approximation nobody has measured is not a
# performance trade-off; it is a threat to the claim.
#
# The practical consequence is that "re-run this with every approximation at its
# most accurate setting" must be a cheap, routine step, and that requires knowing
# WHAT the approximations are. Before this file there was no list: they were
# spread across module-level `Ref`s, `make_workspace` kwargs and YAML keys, and
# about half of them could not be reached from a config at all.
#
# TWO THINGS THIS DELIBERATELY DOES NOT DO.
#
# 1. It is NOT "disable the fast paths". Several fast paths are the ACCURATE
#    direction, and switching them off makes the answer worse: turning off
#    `DEALIAS_2_3_ENABLED` aliases high-k content back into low k rather than
#    removing it; turning off `ddi_padding` re-admits the 2-5 % periodic-image
#    error the padding was added to remove; lowering `ddi_pad_factor` is worse
#    still. So "most accurate" is a per-knob fact a human recorded, not something
#    inferable from "off".
#
# 2. It does NOT claim completeness. Nothing here can detect an approximation
#    someone adds without registering it. `with_reference_accuracy` flips the
#    GLOBAL knobs only; the per-run ones have to be set in the config, and
#    `accuracy_report()` prints them precisely so that nobody mistakes the switch
#    for having covered everything.
#
# What IS gated (test/workflow/validation/test_accuracy_knobs.jl): every
# registered global knob is actually restored after the block, and its reference
# value actually differs from its default — a knob whose "reference" equals its
# default is either mis-recorded or not a knob.

export AccuracyKnob, ACCURACY_KNOBS, with_reference_accuracy, accuracy_report,
    dominated_knobs

"""
    AccuracyKnob

One setting that trades accuracy for speed (or for convenience).

`scope` is `:global` for a module-level `Ref` this file can flip, or `:per_run`
for a `make_workspace` kwarg / YAML key it cannot — the caller must put those in
the config, and the distinction is recorded rather than papered over.

`reference` is the most accurate setting and `default` what ships.

`ladder` is the measured alternatives: entries `(value, rel_error, rel_cost)`
where BOTH numbers come from a measurement, `rel_error` on the quantity the knob
controls and `rel_cost` as a multiple of a production step. A speed profile is
SOLVED from these against a stated error budget rather than hand-picked —
`accuracy_profile_for_budget` — so no one gets to decide that a trade is
acceptable, including me. The first version of this file had a single `fast`
field that I populated with `ddi_pad_factor = 1.5`, and that value violates the
criterion in `error_budget.jl`'s own header: its 1.9e-2 residual is 4.4× the
4.3e-3 the production setting already carries. A budget rule rejects it
automatically; a hand-picked field did not.

`note` says what the gap costs and where that was measured, so the number is
never the only justification.

`getter`/`setter` rather than `get`/`set!`: a keyword argument cannot be called
`set!`, because `set!=nothing` parses as `set != nothing`.
"""
struct AccuracyKnob
    name::Symbol
    scope::Symbol
    reference::Any
    default::Any
    note::String
    accepted_error::Float64          # the error the DEFAULT setting already carries
    ladder::Vector{NamedTuple{(:value, :rel_error, :rel_cost), Tuple{Any, Float64, Float64}}}
    getter::Union{Nothing, Function}
    setter::Union{Nothing, Function}
    # Measured cost of the APPROXIMATE direction relative to `reference`, or NaN
    # when nobody has measured it. `< 1` means the approximation is faster and the
    # knob is a real trade; `>= 1` means it gives accuracy away and buys nothing,
    # which is not a trade at all — see `dominated_knobs`.
    approx_rel_cost::Float64
end

function AccuracyKnob(name::Symbol, scope::Symbol, reference, default, note::String;
    accepted_error=NaN,
    ladder=NamedTuple{(:value, :rel_error, :rel_cost),
        Tuple{Any, Float64, Float64}}[], getter=nothing, setter=nothing,
    approx_rel_cost=NaN)
    scope in (:global, :per_run) ||
        throw(ArgumentError("scope must be :global or :per_run, got :$scope"))
    scope === :global && (getter === nothing || setter === nothing) &&
        throw(ArgumentError("a :global knob needs both `getter` and `setter`"))
    AccuracyKnob(name, scope, reference, default, note, Float64(accepted_error),
        ladder, getter, setter, Float64(approx_rel_cost))
end

"""
    dominated_knobs() -> Vector{AccuracyKnob}

Knobs whose APPROXIMATE setting gives accuracy away and is not measurably faster.

Such a setting is not a trade — it is strictly worse on both axes, and there is no
budget under which anyone should pick it. The rule is the user's, and it is sharp:
*if a setting is less accurate and not faster, it should not be on offer.*

Deleting them is not always possible (`secular_ddi` is required by the
rotating-frame path, so it stays as a PHYSICS choice), so this is the next best
thing: naming them, mechanically, so no report or profile can present one as a
performance option. `accuracy_profile_for_budget` already cannot select one — the
budget picks the cheapest ADMISSIBLE rung, and a dominated setting is never
cheaper — but that only holds where a ladder exists, and most knobs have none.

`approx_rel_cost` is NaN until someone measures it, and an unmeasured knob is not
reported here: "nobody has measured it" is a different statement from "it buys
nothing", and conflating them would let this list grow by neglect.
"""
dominated_knobs() = filter(k -> isfinite(k.approx_rel_cost) &&
            k.approx_rel_cost >= 0.98, ACCURACY_KNOBS)

"""
    ACCURACY_KNOBS

Every setting known to trade accuracy. Adding an approximation means adding an
entry — see the header for why this list cannot be derived.
"""
const ACCURACY_KNOBS = AccuracyKnob[
    AccuracyKnob(:spin_taylor, :global, false, true,
        "Taylor-Horner spin rotation instead of the exact Euler 5-stage. \
Truncated series, per-voxel degree. Measured at Eu F=6 32³ dt=0.002: 2.4e-13 \
against a splitting error of 7.6e-3, i.e. 3e-11 of it — but measured on ENERGY \
only. Gated by test_taylor_tolerance_criterion.jl, which therefore licenses an \
energy claim and not a phase-classification one.";
        getter=() -> SPIN_TAYLOR_ENABLED[], setter=v -> (SPIN_TAYLOR_ENABLED[] = v)),
    AccuracyKnob(:spin_taylor_tol, :global, 1.0e-15, 1.0e-15,
        "Backward-error target for the Taylor degree. It BINDS at production \
angles: measured R_max = 1.3e-3…5.4e-2 for Eu F=6 (theta_max = |c1*dt|*fmax*F), \
where 1e-13 and 1e-15 give degrees 4 vs 5 through 8 vs 9. This entry used to say \
'INERT at production angles: the degree is floored at 2 and at R ~ 1e-5 the \
schedule returns 2' — the 1e-5 was three orders low, and the degree returns 2 \
only for R below ~3e-8. It shipped at 1e-13 with 1e-15 as the 'reference'; the \
tighter value is now the default, which costs one Horner degree and buys two \
decades of backward error. Changing the degree is not the same as changing the \
observable: the rotation stays ~1e-8 relative, four orders inside the splitting \
error, so this is a real control on the COST and a negligible one on the ANSWER.";
        getter=() -> SPIN_TAYLOR_TOL[], setter=v -> (SPIN_TAYLOR_TOL[] = v)),
    AccuracyKnob(:dealias_2_3, :global, true, false,
        "Orszag 2/3 filter on ψ and on the bilinear DDI field. NOTE the \
direction: ON is the accurate setting. OFF does not remove the above-cut \
content, it ALIASES it back into low k, where it is invisible in the norm and \
contaminates the answer.";
        getter=() -> DEALIAS_2_3_ENABLED[], setter=v -> (DEALIAS_2_3_ENABLED[] = v)),
    AccuracyKnob(:ddi_pad_factor, :per_run, 3.0, 2.0,
        "Zero-pad multiple for the open-boundary DDI convolution. Measured \
(bench/ddi_pad_factor_accuracy.jl, H100, Eu151, referenced to pad 3): relative \
Φ error 4.3e-3 at pad 2, 1.9e-2 at 1.5, 1.3e-1 unpadded, at 3.4×/8×/1× the FFT \
volume. Lowering it was measured and REJECTED for production — the residual at \
1.5 is the size of the error padding exists to remove — but it is the one knob \
whose speed AND error are both measured. Cost is GRID-DEPENDENT — pad 1.5 is \
1.10× at 32³ and 1.28× at 64³ — which is on its own a reason a single 'fast \
value' is the wrong shape.";
        accepted_error=4.3e-3,
        ladder=[(value=3.0, rel_error=1.0e-3, rel_cost=1.507),
            (value=2.0, rel_error=4.3e-3, rel_cost=1.0),
            (value=1.5, rel_error=1.9e-2, rel_cost=0.906),
            (value=1.0, rel_error=1.3e-1, rel_cost=0.75)]),
    AccuracyKnob(:ddi_padding, :per_run, true, true,
        "Open-boundary (zero-padded) DDI convolution. ON is accurate; OFF is the \
bare periodic kernel, 2-5 % dipolar field error flat in resolution (9c117c05)."),
    AccuracyKnob(:secular_ddi, :per_run, false, false,
        "Larmor-averaged DDI, dropping the off-diagonal components. A physics \
approximation valid when ω_L ≫ c_dd⟨n⟩; make_workspace advises when that holds. \
Required (ArgumentError) when spin_rotating_frame_omega ≠ 0, so this knob cannot \
be removed without removing the rotating-basis path. Buys NO speed — measured \
0.986× at 32³, i.e. noise, because Q_xx = Q_yy = −Q_zz/2 keeps the kernel a \
3-component convolution with all 6 FFTs. Choose it for the physics or not at all.";
        approx_rel_cost=0.986),
    AccuracyKnob(:spinor_lhy, :per_run, :full_bdg, :none,
        "LHY functional. The closed forms assume a fixed ansatz — \
polar_two_channel is ~1 % off at F=2 and 30-70 % off at F=6. full_bdg is the \
general-spinor path, gated to ~1e-4 against the closed forms in their own \
regimes. The '~100× dearer' this note used to carry is FALSE per step: measured \
0.997× against 0.987× for polar_contact at 32³, i.e. both are free, and the \
difference is a ONE-TIME table build (0.41-0.71 s vs 0.05 s). So the closed forms \
buy no per-step speed and the reason to prefer one is its ansatz matching the \
state — or, at Eu, that full_bdg has no dynamically stable mean field to \
linearise around at all (see check_accuracy_preconditions)."),
    AccuracyKnob(:spatial_lhy, :per_run, true, false,
        "Whether ε_LHY tracks the local polarisation. Without it one spinor is \
used for the whole cloud: ~5 % on converged weak-field Eu textures with a SIGN \
that flips along a B-scan. SpatialLHY cuts that to 0.8 % and removes the flip, \
at 1.8× in the diagonal step; its own residual is measurable via \
spatial_lhy_residual and should be quoted with any result using it."),
    AccuracyKnob(:dtype, :per_run, Float64, Float64,
        "Mixed precision. `f32` (rotating_basis only) halves ψ traffic; scalar \
locks stay F64. Not used by default."),
    AccuracyKnob(:temperature_ratio, :per_run, 0.0, 0.0,
        "Both the ground-state and dynamics `temperature_ratio` drive a \
HEURISTIC symmetry-breaking kick (η = √((T/T_c)³/4)), not a thermal Wigner \
sample. For a real thermal initial state use the SGPE callback."),
]

"""
    with_reference_accuracy(f)

Run `f()` with every `:global` accuracy knob at its reference value, restoring
all of them afterwards (including on exception).

This covers the global knobs ONLY. The `:per_run` entries live in the config and
must be set there; `accuracy_report()` lists them with their reference values so
the gap is visible rather than assumed away.

**[KNOWN-GAP] Around `run_yaml`, this can produce the degeneracy it exists to
detect.** Both remaining `:global` knobs fail to reach the artifact id, for two
different reasons:

  * `:spin_taylor` is in no `Stage` at all — measured `:blind` by
    `test/model/test_ambient_refs_vs_artifact_id.jl`;
  * `:dealias_2_3` IS in the id (via `GridSpec`), but `_run_yaml_prepare` applies
    the config's own top-level `dealias:` block AFTER the reference flip
    (`run_registry.jl:273`), overwriting it. 75 committed configs carry that
    block, 71 of them with `enabled: true`.

So a reference-accuracy run of such a config resolves to the SAME id as the
production run and can be served the production artifact — the instrument built
to detect a degenerate measurement producing one. Measured, with a positive
control isolating the block as the cause (byte-identical config either way, one
line added):

    no `dealias:` block         plain 11e53da610dc4b84  ref 235481a1f7f86e4e  MOVED
    `dealias: {enabled: false}` plain 11e53da610dc4b84  ref 11e53da610dc4b84  SAME

Until the dealias pair stops being ambient (cutover step 4 has not landed that
half), use `with_reference_accuracy` around DIRECT solver calls, or compare the
two runs' outputs rather than trusting that two ids differ. Pinned by
`test/workflow/validation/test_accuracy_knobs.jl` so the fix is a visible diff.
"""
function with_reference_accuracy(f)
    globals = filter(k -> k.scope === :global, ACCURACY_KNOBS)
    saved = [k.getter() for k in globals]
    try
        for k in globals
            k.setter(k.reference)
        end
        f()
    finally
        for (k, v) in zip(globals, saved)
            k.setter(v)
        end
    end
end

"""
    accuracy_report(; io = stdout)

Print every accuracy knob: scope, current value (globals only), default,
reference, and what the gap costs. Ends with the `:per_run` entries a caller has
to set themselves, because a reference run that silently skipped them is worse
than no reference run.
"""
function accuracy_report(; io::IO=stdout)
    println(io, "Accuracy knobs — reference = most accurate setting, NOT 'fast paths off'")
    println(io, "="^78)
    for k in ACCURACY_KNOBS
        cur = k.scope === :global ? repr(k.getter()) : "(per-run)"
        println(io, "  $(k.name)  [$(k.scope)]")
        println(
            io,
            "      current $(cur)   default $(repr(k.default))   " *
            "reference $(repr(k.reference))",
        )
        for line in _wrap(k.note, 68)
            println(io, "      $line")
        end
    end
    per_run = filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
    println(io, "\n`with_reference_accuracy` does NOT set these — put them in the config:")
    for k in per_run
        println(io, "    $(k.name) = $(repr(k.reference))")
    end
    dom = dominated_knobs()
    if !isempty(dom)
        println(io, "\nNOT A TRADE — less accurate and not measurably faster:")
        for k in dom
            @printf(io, "    %-18s approximate setting costs %.3f× (≥ 1 means it buys nothing)\n",
                k.name, k.approx_rel_cost)
        end
        println(io, "  Never select one of these for performance. Where a knob is kept for")
        println(io, "  another reason — secular_ddi is required by the rotating-frame path —")
        println(io, "  it is a PHYSICS choice and the speed argument for it does not exist.")
    end
    nothing
end

function _wrap(s::AbstractString, width::Int)
    out = String[]
    line = ""
    for w in split(s)
        if isempty(line)
            line = w
        elseif length(line) + 1 + length(w) <= width
            line *= " " * w
        else
            push!(out, line)
            line = w
        end
    end
    isempty(line) || push!(out, line)
    out
end
