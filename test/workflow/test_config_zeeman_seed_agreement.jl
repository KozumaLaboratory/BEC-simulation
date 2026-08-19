# Committed configs must agree with the Zeeman sign convention.
#
# The convention (CLAUDE.md, `Units.bfield_to_p`): H = -p·F_z + q·F_z² with
# p ≡ -g_F μ_B B, so physically H = +(g_F μ_B B·F). For g_F > 0 (Eu, Cr, He*)
# a POSITIVE B_z makes m = -F the lowest state.
#
# Measured 2026-07-29 on a 16³ Eu ground state, DDI off, spin-coherent seed so
# every m is free to win:
#
#     Bz = -0.01 Gauss  ->  <F_z> = +6.0
#     Bz = +0.01 Gauss  ->  <F_z> = -6.0
#
# A config that pins `initial_state: m_minus_F` under a NEGATIVE B_z is asking
# ITP to hold the state the field disfavours. Nothing errors — the run completes
# and produces a plausible-looking result for the opposite polarisation. The
# `runs/matsui_baseline/` set drifted this way (the sign predates the 2026-06-10
# B→p fix and its comment still claimed the old convention), which is what this
# gate exists to stop recurring.
#
# Scope: configs that pin a fully-stretched seed AND set a non-zero Zeeman
# coefficient. Everything else is a legitimate choice and not this test's business.
#
# WIDENED 2026-08-19 (#343). The original gate read exactly two spellings —
# `initial_state: m_{minus,plus}_F` and `B: {Bz: …}` — and the rotation-assisted EdH quench series
# uses NEITHER: `runs/eu151_klaus_phi_phys/config.yaml` says `init_m_idx: 1`
# with `B: {p: 26700.0}`, behind a `use:` mixin that hides the atom from a raw
# YAML read. Three independent reasons for one config to be invisible to its own
# convention gate. The widening covers all three:
#
#   * `init_m_idx` — 1 is m=+F, D=2F+1 is m=-F, so it is a stretched seed under
#     another name. Anything between is not stretched and stays out of scope.
#   * `B: {p: …}` — p is already the operator coefficient, so its sign maps to
#     the ground state DIRECTLY (p > 0 ⇒ m=+F lowest) and therefore in the
#     OPPOSITE direction to Bz. That inversion is the trap; encoding it here is
#     the point.
#   * mixins — expanded with the schema's own `apply_templates_and_mixins!`
#     rather than a second reading of the grammar.
#
# The sign itself is NOT restated here: Bz→p goes through `Units.bfield_to_p_gauss`,
# the one line that computes it. A gate carrying its own copy of the convention
# is the defect it is trying to catch.
#
# The scan is three-valued. `:agree` / `:disagree` / `:unresolved` — the last for
# configs whose atom (hence g_F, hence D) cannot be resolved from the file. A
# config the gate cannot read has not passed it, and the count is printed rather
# than folded into either other bucket.

using SpinorBEC
using Test
using YAML

const _STRETCHED = ("m_minus_F", "m_plus_F")

"""
    _expand(data) -> Dict

Expand `template:` / `mixins:` with the schema's OWN expander, so a `use:` line
does not hide the atom from this gate. Only a per-config failure is tolerated
(a fragment that is not a standalone config); that the function is REACHABLE is
asserted by a canary below, because the first version of this file caught an
`UndefVarError` here — the expander is not exported — and every mixin config
silently read as "atom unresolvable".
"""
function _expand(data)
    try
        SpinorBEC.apply_templates_and_mixins!(Dict{Any, Any}(data))
    catch e
        e isa UndefVarError && rethrow()
        data
    end
end

"""Extract Gauss from `"0.01 Gauss"` / `0.01` / a `{from: …}` ramp; else `nothing`."""
function _bz_value(B)
    B isa AbstractDict || return nothing
    bz = get(B, "Bz", nothing)
    bz === nothing && return nothing
    bz isa Number && return Float64(bz)
    bz isa AbstractString && return tryparse(Float64, first(split(strip(bz))))
    # ramp form {from: ..., to: ...} — the GS value is `from`
    if bz isa AbstractDict && haskey(bz, "from")
        f = bz["from"]
        f isa Number && return Float64(f)
        f isa AbstractString && return tryparse(Float64, first(split(strip(f))))
    end
    return nothing
end

"""Direct `B: {p: …}` in internal units; `nothing` if the block does not use it."""
function _p_value(B)
    B isa AbstractDict || return nothing
    p = get(B, "p", nothing)
    p isa Number ? Float64(p) : nothing
end

"""`AtomSpecies` named by the (mixin-expanded) ground_state step, or `nothing`."""
function _atom_of(gs)
    a = get(gs, "atom", nothing)
    a isa AbstractString || return nothing
    get(ATOM_REGISTRY, Symbol(a), nothing)
end

"""
    _seed_of(gs, atom) -> :plus_F | :minus_F | nothing | :unresolved

Which stretched state the config prepares. `:unresolved` means the config pins a
seed by INDEX but the atom — and therefore D = 2F+1 — is not resolvable, so
whether index k is the m=-F end cannot be decided. That is not the same as "no
stretched seed", and must not be reported as one.
"""
function _seed_of(gs, atom)
    s = get(gs, "initial_state", nothing)
    if s isa AbstractString && s in _STRETCHED
        return s == "m_minus_F" ? :minus_F : :plus_F
    end
    idx = get(gs, "init_m_idx", nothing)
    idx isa Integer || return nothing
    # c=1 is m=+F for every F (CLAUDE.md layout: `c=1 → m=F`), so index 1 needs
    # no atom. Only the m=-F end does, since that is D = 2F+1.
    idx == 1 && return :plus_F
    atom === nothing && return :unresolved
    idx == 2 * atom.F + 1 && return :minus_F
    return nothing              # interior m: not a stretched seed
end

"""
    _m_lowest(gs, atom) -> :plus_F | :minus_F | nothing | :unresolved

Which stretched state the linear Zeeman term makes lowest. `H = -p·F_z`, so
`p > 0` ⇒ m=+F. Bz is converted through `Units.bfield_to_p_gauss` so the sign
is not restated here. `nothing` = no (or zero) Zeeman coefficient in this step.
"""
function _m_lowest(gs, atom)
    p_direct = _p_value(get(gs, "B", nothing))
    if p_direct !== nothing
        p_direct == 0.0 && return nothing
        return p_direct > 0 ? :plus_F : :minus_F
    end
    bz = _bz_value(get(gs, "B", nothing))
    (bz === nothing || bz == 0.0) && return nothing
    atom === nothing && return :unresolved      # g_F sign unknown ⇒ p sign unknown
    p = Units.bfield_to_p_gauss(bz, atom.g_F, 1.0)
    p == 0.0 && return nothing
    p > 0 ? :plus_F : :minus_F
end

"""
Configs may DECLARE that the seed opposes the field on purpose:

    # anti-aligned-seed: <reason>

Measured 2026-08-19 (#343): the Einstein-de Haas cascade only exists when
the prepared stretched state is the Zeeman-HIGHEST one — rotation contrast
+16.5 % anti-aligned against −0.45 % aligned — which is the standard EdH
configuration (Kawaguchi-Saito-Ueda PRL 96, 080405). So "seed opposes field" is
sometimes the whole point, and a gate that cannot express that either goes
permanently yellow or gets deleted. Declared configs are counted separately;
undeclared ones keep being reported.
"""
const _ANTIALIGNED = r"^#\s*anti-aligned-seed:\s*\S"m

function _scan_configs(root)
    disagree = String[]        # seed and field disagree, undeclared
    declared = String[]        # disagree, but the file says so and why
    unresolved = String[]      # gate could not decide — neither pass nor fail
    n_checked = 0
    for (dir, _, files) in walkdir(root)
        for f in files
            endswith(f, ".yaml") || continue
            path = joinpath(dir, f)
            raw = read(path, String)
            anti = occursin(_ANTIALIGNED, raw)
            data = try
                YAML.load_file(path)
            catch
                continue          # templates / fragments that are not standalone
            end
            (data isa AbstractDict && get(data, "pipeline", nothing) isa AbstractVector) ||
                continue
            data = _expand(data)
            for step in data["pipeline"]
                step isa AbstractDict && haskey(step, "ground_state") || continue
                gs = step["ground_state"]
                gs isa AbstractDict || continue
                atom = _atom_of(gs)
                seed = _seed_of(gs, atom)
                seed === nothing && continue
                lowest = _m_lowest(gs, atom)
                lowest === nothing && continue
                if seed === :unresolved || lowest === :unresolved
                    push!(
                        unresolved,
                        "$path: seed=$(seed) field=$(lowest) " *
                        "(atom not resolvable from the file)",
                    )
                    continue
                end
                n_checked += 1
                seed === lowest && continue
                msg =
                    "$path: seed prepares m=$(seed === :minus_F ? "-F" : "+F") " *
                    "but the field makes m=$(lowest === :minus_F ? "-F" : "+F") lowest"
                push!(anti ? declared : disagree, msg)
            end
        end
    end
    (; disagree, declared, unresolved, n_checked)
end

@testset "committed configs agree with the Zeeman sign convention" begin
    root = joinpath(@__DIR__, "..", "..", "runs")
    @test isdir(root)
    r = _scan_configs(root)

    # If this is zero the gate is vacuous and something changed upstream.
    @test r.n_checked > 0

    # Canary: the gate must be able to SEE a disagreement. Reproduce the exact
    # shape bce2068f repaired (m_minus_F under a negative Bz) on a synthetic
    # config, and require the scan's own predicate to flag it. Without this a
    # green below is indistinguishable from a predicate that matches nothing.
    let atom = ATOM_REGISTRY[:Eu151]
        bad = Dict{Any, Any}("atom" => "Eu151",
            "initial_state" => "m_minus_F",
            "B" => Dict{Any, Any}("Bz" => "-0.01 Gauss"))
        @test _seed_of(bad, atom) === :minus_F
        @test _m_lowest(bad, atom) === :plus_F      # ⇒ would be reported
        good = Dict{Any, Any}("atom" => "Eu151",
            "initial_state" => "m_minus_F",
            "B" => Dict{Any, Any}("Bz" => "0.01 Gauss"))
        @test _m_lowest(good, atom) === :minus_F
        # …and the direct-p spelling, whose sign runs the OTHER way.
        pos_p = Dict{Any, Any}("atom" => "Eu151", "init_m_idx" => 1,
            "B" => Dict{Any, Any}("p" => 26700.0))
        @test _seed_of(pos_p, atom) === :plus_F
        @test _m_lowest(pos_p, atom) === :plus_F
        @test _seed_of(Dict{Any, Any}("atom" => "Eu151", "init_m_idx" => 13), atom) ===
            :minus_F
    end

    # Canary: the mixin expander must be REACHABLE. It is not exported, and the
    # first version of this gate caught the resulting `UndefVarError` per config,
    # so every `use:`-mixin config read as "atom unresolvable" — a silent
    # coverage hole dressed as a three-valued answer. Prove the expansion works
    # on the very config (#343 §2) that motivated the widening.
    let p = joinpath(root, "eu151_klaus_phi_phys", "config.yaml")
        if isfile(p)
            gs = _expand(YAML.load_file(p))["pipeline"][1]["ground_state"]
            @test haskey(gs, "atom")                        # came from the mixin
            atom = _atom_of(gs)
            @test atom !== nothing
            # `H = -p·F_z` with p > 0 puts m=+F at the BOTTOM of the ladder, so
            # the ANTI-ALIGNED seed here is m=-F — `init_m_idx: 13`, retargeted
            # 2026-08-19 from the schema default of 1. #343 §2 read this config
            # as "the only Eu arc on the opposite side"; it was not — comparing m
            # labels across two field parameterisations is what made it look that
            # way — and it was on the wrong side for a different reason.
            @test _m_lowest(gs, atom) === :plus_F     # p > 0 ⇒ m=+F is lowest
            @test _seed_of(gs, atom) === :minus_F     # …so m=-F is the highest
            # Deliberate, and it must SAY so, or the gate is right to flag it.
            @test occursin(_ANTIALIGNED, read(p, String))
        end
    end

    # A declared anti-aligned seed is a physics choice, not a defect: the EdH
    # cascade only runs from the Zeeman-HIGHEST state (#343 §3.6). The predicate
    # must actually distinguish declared from undeclared, or the escape hatch
    # silently swallows real drift.
    let tmp = mktempdir()
        body = """
        pipeline:
          - ground_state:
              atom: Eu151
              initial_state: m_plus_F
              B: {Bz: "0.01 Gauss"}
        """
        write(joinpath(tmp, "undeclared.yaml"), body)
        write(joinpath(tmp, "declared.yaml"),
            "# anti-aligned-seed: EdH cascade needs the Zeeman-highest state\n" * body)
        s = _scan_configs(tmp)
        @test length(s.disagree) == 1 && occursin("undeclared.yaml", only(s.disagree))
        @test length(s.declared) == 1 && occursin("declared.yaml", only(s.declared))
    end

    # `m_minus_F` is unambiguous and is a hard gate: the config states the seed
    # it wants, and only a POSITIVE B_z makes that seed the ground state.
    minus = filter(d -> occursin("prepares m=-F", d), r.disagree)
    for d in minus
        @info "Zeeman/seed disagreement (seed m=-F)" config = d
    end
    @test isempty(minus)

    # `m_plus_F` is NOT gated, deliberately, and this is not a silent cap.
    #
    # A config pinning m=+F under a positive B_z is inconsistent the same way,
    # but the repair is ambiguous: flipping the FIELD negative and flipping the
    # SEED to m_minus_F both produce a consistent config, and they are physical
    # mirror images rather than the same state. Which one the author meant is
    # not recoverable from the file. So these are reported loudly and left for a
    # decision instead of being rewritten on a guess.
    #
    # 2026-08-19: and a third reading exists, which is why deleting these is
    # wrong — the seed may oppose the field ON PURPOSE. That is the standard
    # Einstein-de Haas preparation and the only regime in which the
    # rotation enhancement exists at all (#343 §3.6). Such a config should carry
    # `# anti-aligned-seed: <reason>` and lands in `declared` instead.
    plus = filter(d -> occursin("prepares m=+F", d), r.disagree)
    if !isempty(plus)
        @warn "m_plus_F configs disagree with the Zeeman convention and do NOT " *
            "declare it; either it is drift (flip field vs flip seed — see this " *
            "test's comment) or it is a deliberate anti-aligned EdH preparation, " *
            "in which case add `# anti-aligned-seed: <reason>`" count = length(plus)
        for d in plus
            @info "Zeeman/seed disagreement (seed m=+F, UNRESOLVED)" config = d
        end
    end
    if !isempty(r.declared)
        @info "configs declaring a deliberate anti-aligned seed" count = length(r.declared)
    end

    # Configs the gate could not decide are surfaced, never counted as passes.
    if !isempty(r.unresolved)
        @warn "configs whose Zeeman/seed agreement could not be decided" count = length(
            r.unresolved
        ) sample = first(r.unresolved, min(5, length(r.unresolved)))
    end
end
