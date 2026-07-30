# --- Named accuracy profiles: reference / production / fast ---
#
# Two settings a config author should be able to ask for by name — "as accurate
# as this code gets" and "as fast as measurement licenses" — without having to
# know which knobs exist, which direction each one points, or what each costs.
#
# The profiles are DERIVED from `ACCURACY_KNOBS`, not written out beside it. That
# is the part that makes them hard to get wrong: adding an approximation to the
# registry makes it appear in all three profiles at once, so a new knob cannot be
# silently absent from `:reference`, and `:fast` cannot contain a knob whose trade
# nobody measured because it is built from the registry's `fast` field, which is
# `nothing` unless a measurement exists.
#
#   :reference   every knob at its most accurate setting
#   :production  the shipped defaults
#   :fast        production, except where a MEASURED faster setting exists
#
# THREE THINGS THAT STILL NEED A HUMAN.
#
# 1. `:fast` is not "fast mode". Today exactly one knob has a measured trade
#    (`ddi_pad_factor` 2 → 1.5: 1.28× on a 64³ RTP step, Φ error 4.3e-3 → 1.9e-2),
#    and that residual is the size of the error padding was added to remove. So
#    `:fast` is a REQUEST for a documented trade, not a free win, and
#    `accuracy_profile_report(:fast)` prints what is being traded.
#
# 2. A profile sets `:per_run` knobs. The `:global` ones are `Ref`s; use
#    `with_reference_accuracy` for those. `accuracy_profile_report` says so rather
#    than letting the name imply full coverage.
#
# 3. `:reference` has a PRECONDITION the value alone cannot express, and it is
#    the one that cost a day: `spinor_lhy = :full_bdg` tabulates ε_LHY from the
#    peak-density spinor of the state the workspace is built with. Handed a raw
#    seed, it tabulates from an unrelaxed, dynamically-unstable configuration —
#    measured max Im ω = 1020 on a `:flower` seed at Eu F=6 32³ — and `FullBdGLHY`
#    itself says ε_LHY is scheme-dependent there. `check_accuracy_preconditions`
#    refuses that combination for `:reference` instead of leaving it to a runtime
#    warning nobody reads.

export ACCURACY_PROFILE_NAMES,
    accuracy_profile, accuracy_profile_report,
    check_accuracy_preconditions

const ACCURACY_PROFILE_NAMES = (:reference, :production, :fast)

"""
    accuracy_profile(name) -> NamedTuple

The `:per_run` settings for a named profile, keyed by knob name — pass them to
`make_workspace` or write them into a spec. Derived from [`ACCURACY_KNOBS`], so
every registered knob is present by construction.

```julia
p = accuracy_profile(:reference)
ws = make_workspace(; grid, atom, interactions, sim_params, psi_init,
                    enable_ddi=true, c_dd,
                    ddi_padding=p.ddi_padding, ddi_pad_factor=p.ddi_pad_factor,
                    secular_ddi=p.secular_ddi, spinor_lhy=p.spinor_lhy)
```
"""
function accuracy_profile(name::Symbol)
    name in ACCURACY_PROFILE_NAMES || throw(
        ArgumentError(
            "unknown accuracy profile :$name; expected one of $ACCURACY_PROFILE_NAMES"),
    )
    per_run = filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
    vals = map(per_run) do k
        if name === :reference
            k.reference
        elseif name === :production
            k.default
        else
            (k.fast === nothing ? k.default : k.fast)
        end
    end
    NamedTuple{Tuple(k.name for k in per_run)}(Tuple(vals))
end

"""
    accuracy_profile_report(name; io = stdout)

Print what a profile sets, what it differs from production on, and what that
difference costs — plus the two things it does not cover (`:global` knobs and the
`:reference` precondition).
"""
function accuracy_profile_report(name::Symbol; io::IO=stdout)
    p = accuracy_profile(name)
    prod = accuracy_profile(:production)
    println(io, "accuracy profile :$name  (per-run knobs only)")
    println(io, "="^78)
    for k in filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
        v = getfield(p, k.name)
        mark = isequal(v, getfield(prod, k.name)) ? " " : "*"
        println(io, "  $mark $(k.name) = $(repr(v))")
    end
    changed = [
        k for k in filter(k -> k.scope === :per_run, ACCURACY_KNOBS)
        if !isequal(getfield(p, k.name), getfield(prod, k.name))
    ]
    if isempty(changed)
        println(io, "\n  (identical to :production)")
    else
        println(io, "\n  * differs from :production — what each trade costs:")
        for k in changed
            println(
                io, "    $(k.name): $(repr(getfield(prod, k.name))) → $(repr(getfield(p, k.name)))"
            )
            for line in _wrap(k.note, 66)
                println(io, "        $line")
            end
        end
    end
    println(
        io,
        """

NOT set by this profile:
  * the :global knobs ($(join((string(k.name) for k in ACCURACY_KNOBS if k.scope === :global), ", "))).
    Use `with_reference_accuracy(f)` for those.
  * the :reference precondition — call `check_accuracy_preconditions` before
    trusting a reference run. `spinor_lhy = :full_bdg` tabulates from the state
    the workspace is BUILT with, so a raw seed tabulates from an unrelaxed,
    dynamically-unstable configuration where ε_LHY is scheme-dependent.""",
    )
    nothing
end

"""
    check_accuracy_preconditions(name; relaxed_initial_state::Bool) -> CheckResult

Whether a profile's assumptions hold for how it is about to be used.

`:reference` requires `spinor_lhy = :full_bdg`, and that tabulates ε_LHY from the
peak-density spinor of the state the workspace is built with. If that state is a
raw seed rather than a relaxed one, the table comes from a dynamically-unstable
configuration and ε_LHY is scheme-dependent — so the run has no well-defined
ground state to converge to, which is not a tolerance that can be tightened.
Measured: max Im ω = 1020 from a `:flower` seed at Eu F=6, 32³, and the reference
arm's ITP sat at dE ≈ 1e-2 against a 1e-9 target
(`bench/phase_gap_error_budget.jl`).

Returns `:fail` rather than throwing, so a caller can report it alongside other
checks; `passed(r)` is the green/not-green question.
"""
function check_accuracy_preconditions(name::Symbol; relaxed_initial_state::Bool)
    p = accuracy_profile(name)
    needs_relaxed = hasproperty(p, :spinor_lhy) && p.spinor_lhy === :full_bdg
    details = Pair{Symbol, Any}[
        :profile => (got=name,),
        :spinor_lhy => (got=hasproperty(p, :spinor_lhy) ? p.spinor_lhy : nothing,
            needs_relaxed_initial_state=needs_relaxed),
        :relaxed_initial_state => (got=relaxed_initial_state,),
    ]
    if needs_relaxed && !relaxed_initial_state
        return CheckResult(:fail, details,
            ":$name uses spinor_lhy = :full_bdg, which tabulates ε_LHY from the " *
            "peak-density spinor of the state the workspace is built with. The " *
            "initial state is not relaxed, so the table would come from a " *
            "dynamically-unstable configuration where ε_LHY is scheme-dependent " *
            "(measured max Im ω = 1020 on a raw seed at Eu F=6 32³). Relax first " *
            "with lhy = none or a closed form, then rebuild the workspace from " *
            "that ψ and re-converge.")
    end
    CheckResult(:pass, details, ":$name preconditions hold")
end
