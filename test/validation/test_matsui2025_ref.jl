# `refs/matsui2025.toml` + `ref` + `Claim` — the quote boundary.
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.5.
#
# THE PROPERTY THIS FILE GATES. A published target must be MEASURED off a
# committed fixture by the SAME metric applied to our runs, never hand-typed —
# otherwise the reference file is one more place a number can drift from the
# paper, which is the disease rather than the cure.
#
# So the gate is deliberately NOT "the TOML says X". Three arms:
#
#   1. Every `measured` row's value equals what the metric produces off the
#      committed fixture TODAY. `ref_measure` ignores the stored value entirely,
#      so this compares a MEASUREMENT with the file.
#   2. Literals PINNED HERE, independent of the TOML, asserted against both the
#      fresh measurement and the stored value. Arm 1 alone would stay green if
#      someone edited `value` and `window` consistently; a gate that reads the
#      TOML and checks the TOML proves nothing.
#   3. Canaries: the window is load-bearing (moving one edge moves the width by
#      more than the tolerance), the fixture bytes are load-bearing, and every
#      refusal in `ref` and in `Claim`'s constructor actually fires.
#
# Arm 2's numbers were measured off the fixture at `c16bfc44` and are the same
# four `test/validation/test_matsui_fig4_dip.jl` has pinned since `7629cd86`,
# plus the two window-restricted widths §0.7 of the parameter contract
# arbitrates on. They are duplicated here on purpose: that file gates the metric
# against the fixture, this one gates the reference file against both.

using Test
using SpinorBEC
using TOML

# The raw stored number, straight out of the file. Arm 1 needs this and NOT
# `ref(...).value`: on a measured row `ref` returns the FRESH MEASUREMENT (it
# overwrites `value` with it after cross-checking), so `ref_measure(q) ≈
# ref(q).value` compares a measurement with itself and is tautological. Measured,
# not reasoned: neutering `ref`'s own cross-check and perturbing a stored value
# by 0.1 left that form of arm 1 fully green.
stored_value(source::Symbol, quantity::Symbol) =
    Float64(TOML.parsefile(ref_source_path(source))["quantity"][String(quantity)]["value"])

# --- arm 2: the pins. Literals, in this file, read from nothing. -------------
#
# `atol = 1e-3` is a QUOTING tolerance, not a physics one: it says these are the
# right numbers to four decimal places, which is how they appear in
# `parameter_contract_with_Ueda.md` §0.5 and §0.7. The file-vs-measurement
# agreement is checked far tighter inside `ref` (1e-9 / 1e-12).
const PIN_TOL = 1e-3

const PINS = Dict{Symbol, Float64}(
    # Their simulation, full published window.
    :dip_centre_sim_nT => -2.5495,
    :dip_width_sim_nT => 15.0224,
    # Their experiment, full published window.
    :dip_centre_exp_nT => -3.2048,
    :dip_width_exp_nT => 14.5414,
    # Both curves restricted to OUR scan's window. These are the two numbers the
    # comparison actually used, and they are 2.0 and 1.7 nT away from the
    # full-window widths above — which is why a row without its window is not a
    # target. 12.8383 is the design document's `dip_width_nT = 12.84`.
    :dip_width_sim_scanwindow_nT => 13.0734,
    :dip_width_exp_scanwindow_nT => 12.8383,
    # The depths, from the same two calls.
    :dip_minimum_sim_atoms => 12287.1975,
    :dip_minimum_exp_atoms => 8817.4605,
)

# Pinned separately because it is the argument, not the value: this is what the
# width would be if the left window edge fell one sample differently, and the
# gap between it and `dip_width_sim_scanwindow_nT` is the reason
# `quotable_digits = 2` on those rows.
const PIN_WIDTH_SIM_W125_9 = 12.7524

# Non-measured rows are literals in the reference file by nature — there is no
# fixture to measure `time.f90:1692` against. What CAN be gated is that the file
# still says what it said when the loci were read, so a silent edit is visible.
const PINS_NOT_MEASURED = Dict{Symbol, Float64}(
    :zeeman_q_Hz => 1.0,
    :c1_over_c0 => 1 / 36,
    :a_contact_bohr => 110.0,
    :g_F => 1.1628,
    :mass_kg => 2.50741e-25,
    :omega_x_Hz => 110.0,
    :omega_z_Hz => 130.0,
    :length_unit_ratio => sqrt(2),
    :b_field_initial_mG => 10.4,
    :b_field_final_nT => 2.6,
    :b_field_tau_us => 50.0,
    :grid_points => 128.0,
    :dx_aHO => 0.4,
    :pad_factor => 2.0,
    :time_step_trap_units => 1e-3,
    :L3_loss => 0.0,
    :seed_amplitude => 0.0,
    :N_atoms => 50000.0,
    :hold_ms => 5.0,
)

const FIXDIR = joinpath(@__DIR__, "..", "fixtures", "matsui2025")
const REFPATH = ref_source_path(:matsui2025)

# Break-and-restore, for the canaries. Byte-identity on the way back is verified
# by the caller, not assumed: a canary that corrupts a committed fixture and
# restores it approximately is worse than no canary.
#
# This does mutate a COMMITTED file for ~1 ms at a time, and the runner takes
# files in parallel across independent processes, so it is only safe while this
# file is the only test that reads `refs/`. That is asserted below rather than
# hoped for — `ref` is one of the six names a researcher types, so a second
# reader is a matter of time, and the day it appears these canaries need a copy
# rather than the original.
function with_broken(f, path::AbstractString, mangle)
    original = read(path)
    try
        write(path, mangle(String(copy(original))))
        f()
    finally
        write(path, original)
    end
    read(path) == original ||
        error("canary failed to restore $path byte-for-byte")
    nothing
end

@testset "refs/matsui2025.toml" begin
    @testset "arm 1 — every measured row re-measures off the committed fixture" begin
        rows = [ref(:matsui2025, q) for q in ref_quantities(:matsui2025)]
        measured = filter(r -> r.provenance === :measured, rows)
        # Not a magic number: it is every measured row there is, so adding one
        # cannot escape this loop, and deleting one is visible.
        @test length(measured) == 8

        for r in measured
            # THE assertion of this file. `ref_measure` re-runs the row's recipe
            # against the committed fixture and never looks at the stored value;
            # `stored_value` reads the file and never runs anything. Neither side
            # can launder the other.
            @test ref_measure(:matsui2025, r.quantity) ≈
                stored_value(:matsui2025, r.quantity) atol = 1e-9 rtol = 1e-12
            # A measured row is a recipe, and every part of it must be present.
            @test r.metric === :resonance_dip
            @test r.metric_field in (:center, :width, :minimum)
            @test r.endpoint_baseline === true
            @test !isempty(r.window_from)
            @test !isempty(r.units)
        end
    end

    @testset "arm 2 — pinned literals, independent of the file" begin
        for (q, pin) in PINS
            # The fresh measurement matches the pin …
            @test ref_measure(:matsui2025, q) ≈ pin atol = PIN_TOL
            # … the number in the file matches it independently …
            @test stored_value(:matsui2025, q) ≈ pin atol = PIN_TOL
            # … and so does what `ref` hands to a `Claim`.
            @test ref(:matsui2025, q).value ≈ pin atol = PIN_TOL
        end

        # And the arbitration is data, not prose: the two window-restricted
        # widths decide the Fig. 4B comparison, the experimental CENTRE does not
        # (the caption admits a 10 nT axis offset, 3x the centre itself). Since
        # W5 `arbitrates` is DERIVED from `disqualified_by`; the derivation and
        # the closed vocabulary behind it are gated by
        # `test/validation/test_arbitrates_is_derived.jl`.
        @test ref(:matsui2025, :dip_width_exp_scanwindow_nT).arbitrates
        @test ref(:matsui2025, :dip_width_sim_scanwindow_nT).arbitrates
        @test ref(:matsui2025, :dip_centre_sim_nT).arbitrates
        @test !ref(:matsui2025, :dip_centre_exp_nT).arbitrates
        @test !ref(:matsui2025, :dip_width_exp_nT).arbitrates
        @test !ref(:matsui2025, :dip_width_sim_nT).arbitrates
    end

    @testset "the window is part of the metric, not a detail" begin
        centre_full = ref(:matsui2025, :dip_centre_sim_nT)
        width_full = ref(:matsui2025, :dip_width_sim_nT)
        width_scan = ref(:matsui2025, :dip_width_sim_scanwindow_nT)

        @test centre_full.window === nothing            # "full"
        @test width_scan.window == (-13.0, 9.0)

        # The centre is a parabolic vertex through three samples, so it is
        # window-INVARIANT; the width is a half-depth crossing against a
        # per-side ENDPOINT baseline, so it is window-DEFINED. Same curve, same
        # metric, same call — 1.95 nT apart.
        @test ref(:matsui2025, :dip_centre_sim_nT).value ≈ centre_full.value atol = 1e-12
        @test abs(width_full.value - width_scan.value) > 1.5
        @test width_scan.quotable_digits == 2
        @test width_full.quotable_digits == 3
    end

    @testset "every row carries its argument" begin
        for q in ref_quantities(:matsui2025)
            r = ref(:matsui2025, q)
            @test r.provenance in REF_PROVENANCES
            @test !isempty(r.units)
            @test !isempty(r.locus)
            @test !isempty(r.note)
            if r.provenance === :reconstructed
                # The whole point of the category: a value the shipped source
                # does NOT contain owes the alternative it was chosen over and
                # what choosing wrong costs.
                @test r.alternative !== nothing
                @test r.cost !== nothing
                @test !isempty(r.cost_units)
                @test !isempty(r.alternative_locus)
                @test r.cost_kind in (:analytic, :measured, :unpriced)
            end
            # Half a cost is an argument that was started and abandoned.
            @test (r.cost === nothing) == (r.alternative === nothing)
            @test (r.cost === nothing) == isempty(r.cost_units)
            @test (r.cost === nothing) == (r.cost_kind === :none)
        end

        # Set equality, not a count: the three provenances partition the file,
        # and a fourth spelling would have to be added here to pass.
        byprov = Dict(p => Symbol[] for p in REF_PROVENANCES)
        for q in ref_quantities(:matsui2025)
            push!(byprov[ref(:matsui2025, q).provenance], q)
        end
        @test Set(vcat(values(byprov)...)) == Set(ref_quantities(:matsui2025))
        @test Set(byprov[:reconstructed]) == Set([:N_atoms, :hold_ms])
        @test length(byprov[:measured]) == 8
        @test length(byprov[:read_off]) == 17
        @test length(ref_quantities(:matsui2025)) == 27
    end

    @testset "non-measured rows still say what they said" begin
        for (q, pin) in PINS_NOT_MEASURED
            r = ref(:matsui2025, q)
            @test r.value ≈ pin rtol = 1e-9
            @test r.provenance !== :measured
        end
        # The two reconstructions' costs, re-derived rather than restated.
        # `N_atoms`: the shipped 3.5e4 against the published 5.0e4 is 10/7 in
        # c_0 + 36 c_1, NOT the factor 2 that the "34 % in peak density" figure
        # (2^(-3/5)) belongs to — that is the SEPARATE `cc0_eff` item, which
        # contract §0.3.5 proves the polarised ground state is degenerate in.
        @test ref(:matsui2025, :N_atoms).cost ≈ 50000 / 35000 rtol = 1e-9
        @test ref(:matsui2025, :N_atoms).cost_kind === :measured
        # `zeeman_q_Hz`: 1 Hz of q moves the m=-6 -> -5 spacing by 11q = 11 Hz
        # (E_m = -p m + q m^2), and p/h = g_F mu_B/h = 16.275 Hz/nT.
        eu = SpinorBEC.ATOM_REGISTRY[:Eu151]
        p_per_nT = eu.g_F * SpinorBEC.Units.BOHR_MAGNETON / (2π * SpinorBEC.Units.HBAR) * 1e-9
        @test ref(:matsui2025, :zeeman_q_Hz).cost ≈ 11 / p_per_nT rtol = 1e-4
        @test ref(:matsui2025, :zeeman_q_Hz).cost_units == "nT of dip centre"
    end

    @testset "the returned row has ONE shape" begin
        # A `NamedTuple` carries its field types per instance, so this is not
        # free: rows differ in whether `alternative`, `window` and the metric
        # fields are present, and without an explicit type they would be a dozen
        # different types and nothing downstream could dispatch on them.
        ts = unique(typeof(ref(:matsui2025, q)) for q in ref_quantities(:matsui2025))
        @test length(ts) == 1
        @test only(ts) === RefRow
    end

    @testset "ref fails loudly, and by name" begin
        # The case the design asks about explicitly. Never `nothing`, never a
        # default — a `nothing` here surfaces downstream as Claim's "a :C claim
        # needs a registered literature target", a true message about the wrong
        # file.
        e = try
            ref(:matsui2025, :dip_width_nT)
            nothing
        catch err
            err
        end
        @test e isa ArgumentError
        @test occursin("dip_width_nT", e.msg)          # names the thing asked for
        @test occursin("dip_width_exp_scanwindow_nT", e.msg)   # and what exists

        e2 = try
            ref(:no_such_paper_2099, :anything)
            nothing
        catch err
            err
        end
        @test e2 isa ArgumentError
        @test occursin("no_such_paper_2099", e2.msg)
        @test occursin("matsui2025", e2.msg)

        # A non-measured row has no recipe, and asking for one is an error
        # rather than a silently-returned stored value.
        @test_throws ArgumentError ref_measure(:matsui2025, :N_atoms)
    end

    # --- arm 3: canaries. Break the source, run, confirm RED, restore. -------

    @testset "tripwire — this is the only test that reads refs/" begin
        # The canaries below mutate the committed TOML in place. Under
        # `SPINORBEC_TEST_WORKERS=auto` each file runs in its own process off a
        # shared queue, so a second reader could observe the broken state. When
        # this goes red, move the canaries onto a copy.
        me = relpath(@__FILE__, joinpath(dirname(dirname(@__DIR__)), "test"))
        readers = String[]
        for (root, _, files) in walkdir(joinpath(dirname(dirname(@__DIR__)), "test")),
            f in files

            (startswith(f, "test_") && endswith(f, ".jl")) || continue
            rel = relpath(joinpath(root, f), joinpath(dirname(dirname(@__DIR__)), "test"))
            rel == me && continue
            occursin(r"\bref\(:|ref_measure\(|ref_source_path\(|ref_quantities\(",
                read(joinpath(root, f), String)) && push!(readers, rel)
        end
        @test isempty(readers)
    end

    @testset "canary — a wrong stored value is refused, not returned" begin
        with_broken(
            REFPATH, s -> replace(s, "value = 12.838286496502" => "value = 12.848286496502")
        ) do
            e = try
                ref(:matsui2025, :dip_width_exp_scanwindow_nT)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("measuring it off the committed fixture", e.msg)
        end
        # …and it is green again immediately afterwards, so the canary tested
        # the gate and not the restore.
        @test ref(:matsui2025, :dip_width_exp_scanwindow_nT).value ≈ 12.8383 atol = PIN_TOL
    end

    @testset "canary — the window is load-bearing" begin
        # Moving the left edge by one of their samples (-13 -> -12.5) is worth
        # 0.32 nT, which is 320x the file-vs-measurement tolerance and 1.3x the
        # +8.8 % excess the width is used to arbitrate. If `window` were ever
        # defaulted or dropped, this is the size of the error it would cause.
        with_broken(
            REFPATH,
            s -> replace(s,
                "window = [-13.0, 9.0]\nwindow_from = \"our scan: runs/matsui_fig4b/fig4b_scan_n32.yaml, 45 fields from -13 to +9 nT at 0.5 nT\"\ndisqualified_by = []\nquotable_digits = 2\nnote = \"\"\"\nTheir simulation restricted" => "window = [-12.5, 9.0]\nwindow_from = \"our scan: runs/matsui_fig4b/fig4b_scan_n32.yaml, 45 fields from -13 to +9 nT at 0.5 nT\"\ndisqualified_by = []\nquotable_digits = 2\nnote = \"\"\"\nTheir simulation restricted",
            ),
        ) do
            # The stored value no longer matches, so `ref` refuses …
            @test_throws ArgumentError ref(:matsui2025, :dip_width_sim_scanwindow_nT)
            # … and what the changed window actually measures is the OTHER
            # published number, which is the point: both are correct
            # measurements of different things.
            @test ref_measure(:matsui2025, :dip_width_sim_scanwindow_nT) ≈
                PIN_WIDTH_SIM_W125_9 atol = PIN_TOL
        end
        @test ref(:matsui2025, :dip_width_sim_scanwindow_nT).value ≈ 13.0734 atol = PIN_TOL
    end

    @testset "canary — the fixture bytes are load-bearing" begin
        # "Measured off the COMMITTED fixture" is only checkable if the bytes
        # are checked. Change one digit of the declared hash and every measured
        # row that reads that file must refuse.
        with_broken(
            REFPATH,
            s -> replace(s,
                "5cd28028a215024ee7785ce07c1cff5bab0894ec9d6d076f2e958611e8df4d41" => "5cd28028a215024ee7785ce07c1cff5bab0894ec9d6d076f2e958611e8df4d42",
            ),
        ) do
            e = try
                ref(:matsui2025, :dip_centre_sim_nT)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("sha256", e.msg)
        end
        @test ref(:matsui2025, :dip_centre_sim_nT).value ≈ -2.5495 atol = PIN_TOL
    end

    @testset "canary — the schema is closed in both directions" begin
        # An unknown key is an error, not something quietly ignored: the 45-key
        # `metadata:` block that nothing reads is what this layer removes, and
        # permitting unknown keys here would re-open it one level down.
        with_broken(
            REFPATH,
            s -> replace(s,
                "[quantity.zeeman_q_Hz]\nprovenance = \"read_off\"" => "[quantity.zeeman_q_Hz]\nvibes = \"good\"\nprovenance = \"read_off\"",
            ),
        ) do
            e = try
                ref(:matsui2025, :zeeman_q_Hz)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("vibes", e.msg)
        end

        # A reconstruction without its cost is refused BY NAME. This is the gate
        # that makes "a value without its argument" unrepresentable rather than
        # merely discouraged.
        with_broken(
            REFPATH, s -> replace(s,
                "cost = 1.428571428571\ncost_units" => "cost_units")
        ) do
            e = try
                ref(:matsui2025, :N_atoms)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("\"cost\"", e.msg)
            @test occursin("without its argument", e.msg)
        end

        # …and STRIPPING THE WHOLE COST GROUP is refused too, which is the arm
        # that is specific to `:reconstructed`. Removing one key leaves the
        # others behind, and the others alone are enough to demand the rest —
        # so the one-key version above would stay green even with the
        # reconstruction clause deleted from `ref`. Measured: it did.
        with_broken(
            REFPATH,
            s -> replace(s,
                """alternative = 35000.0
    alternative_locus = "time.f90:1667 — what setup_parameters actually ships"
    cost = 1.428571428571
    cost_units = "x in c_0 + 36 c_1 (4687.266258 at 5.0e4 against 3281.086380 at 3.5e4)"
    cost_kind = "measured"
    """ => ""),
        ) do
            e = try
                ref(:matsui2025, :N_atoms)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("without its argument", e.msg)
        end
        @test ref(:matsui2025, :N_atoms).cost !== nothing
    end
end

@testset "Claim — the A/B/C taxonomy" begin
    # A minimal but REAL Stage: the design's `Claim` embeds `Stage`, so the
    # constructor gates below have to be exercised against the real type.
    m = Model(; grid=GridSpec(; ndim=1, n_points=(16,), box=(8.0,)),
        atom=SpinorBEC.ATOM_REGISTRY[:Na23],
        interactions=InteractionSpec(; n_atoms=1000, omega_ref=100.0, c0=10.0, c1=0.1),
        ddi=DDISpec(; c_dd=1.0))
    s = stage(:relax; model=m, method=:itp, dt=0.01, n_steps=10)
    # The control is the PHYSICS switched off — c_dd = 0 — not a tolerance
    # loosened. A control differing only in its numerics tests the plumbing, and
    # a bit-identical A/B has been read as physics in this repository before.
    ctrl = stage(:relax; model=with(m; ddi=DDISpec()), method=:itp, dt=0.01, n_steps=10)
    @test ctrl.model != s.model
    tgt = ref(:matsui2025, :dip_width_exp_scanwindow_nT)

    @testset "one assertion per refusal" begin
        # 1. the taxonomy is closed
        @test_throws ArgumentError Claim("x", :D, Stage[s], ctrl, tgt)
        # 2. a :B claim needs a control that trips it
        @test_throws ArgumentError Claim("x", :B, Stage[s], nothing, nothing)
        # 2'. and so does a :C claim
        @test_throws ArgumentError Claim("x", :C, Stage[s], nothing, tgt)
        # 3. a :C claim needs a registered literature target
        @test_throws ArgumentError Claim("x", :C, Stage[s], ctrl, nothing)
    end

    @testset "and what it admits" begin
        # :A needs neither: GPU == CPU has no literature and no control beyond
        # the equality itself.
        a = Claim("GPU energy_decomposition equals CPU per term", :A, Stage[s], nothing,
            nothing)
        @test a.kind === :A
        @test a.control === nothing && a.target === nothing

        c = Claim("statement", :C, Stage[s], ctrl, tgt)
        @test c.target.quantity === :dip_width_exp_scanwindow_nT
        @test c.target.value ≈ 12.8383 atol = 1e-3
        # `ref` returns a `RefRow`, which IS the `NamedTuple` the design types
        # `target` as — so the window and the metric survive the boundary. If
        # only `value` crossed it, a comparison could not measure our run the
        # same way, which is the whole reason the type exists.
        @test c.target isa NamedTuple
        @test c.target.window == (-13.0, 9.0)
        @test c.target.metric === :resonance_dip

        # Structural equality, like `Stage` and `Model`: two claims built from
        # the same declaration are the same claim.
        @test Claim("statement", :C, Stage[s], ctrl, tgt) == c
        @test hash(Claim("statement", :C, Stage[s], ctrl, tgt)) == hash(c)
        @test Claim("other", :C, Stage[s], ctrl, tgt) != c

        # The keyword form.
        @test claim("statement"; kind=:C, evidence=[s], control=ctrl, target=tgt) == c
    end

    # DOCUMENTED HOLE, PINNED RATHER THAN CLOSED. The design specifies eight
    # lines and `Claim` is those eight lines; this is what they do not cover.
    # Recorded as an executable statement instead of prose so that closing it is
    # a decision someone makes with the gap in front of them — and so that
    # closing it turns this red rather than passing silently.
    @testset "[HOLE] empty evidence constructs" begin
        vacuous = Claim("a claim with no computation behind it", :C, Stage[], ctrl, tgt)
        @test isempty(vacuous.evidence)
        # The control is also not required to DIFFER from the evidence, so an
        # arm that must fail may be an arm that must pass.
        @test Claim("x", :B, Stage[s], s, nothing).control == s
    end
end

@testset "Matsui Fig. 4B as a Claim — as far as the tree allows" begin
    # WHAT IS REAL TODAY, and what is not.
    #
    # The type-C claim Fig. 4B is — "our simulated dip width reproduces theirs"
    # — needs 45 `:evolve` cells over a 5 ms hold plus a `c_dd = 0` control.
    # ZERO of those 46 stages are constructible: `gs_stage`
    # (`run_step_ground_state.jl:310`) is the only `Stage` producer in `src/`,
    # and `:evolve` appears there only as a member of `STAGE_KINDS`.
    # `run_step_dynamics.jl` declares none — the same blocker two committed
    # tests in `test/model/` already name.
    #
    # So this file does NOT construct a green type-C Fig. 4B claim. Offering the
    # ground-state stage as evidence for a dip-width claim would be restating a
    # different observable, which is the failure mode the control field exists
    # to name. What it does instead: (a) assert the TARGET is real and available
    # now, (b) build the type-A claim the resolved config genuinely supports,
    # and (c) leave a tripwire that fires the day an `:evolve` producer appears.

    @testset "the target is available and arbitrating" begin
        t = ref(:matsui2025, :dip_width_exp_scanwindow_nT)
        @test t.provenance === :measured
        @test t.arbitrates
        @test t.window == (-13.0, 9.0)
        # An axis offset shifts a dip, it does not stretch one — which is why
        # the width arbitrates and the experimental centre does not.
        @test !ref(:matsui2025, :dip_centre_exp_nT).arbitrates
    end

    @testset "tripwire — no :evolve Stage producer exists yet" begin
        # When this goes red, the Fig. 4B type-C claim above becomes
        # constructible and should be built here rather than described.
        src = joinpath(dirname(dirname(@__DIR__)), "src")
        producers = String[]
        for (root, _, files) in walkdir(src), f in files
            endswith(f, ".jl") || continue
            p = joinpath(root, f)
            occursin(r"Stage\(\s*:evolve|stage\(\s*:evolve", read(p, String)) &&
                push!(producers, relpath(p, src))
        end
        @test isempty(producers)
    end

    # The claim the tree DOES support: that the production config resolves to
    # the parameters this repository registered for the paper. Type A — it is a
    # statement about our own code reading its own inputs, not about physics and
    # not about their data — so it needs no control and no target, and the
    # constructor agrees.
    @testset "type-A: the config carries the registered parameters" begin
        cfg = joinpath(dirname(dirname(@__DIR__)), "runs", "matsui_fig4b",
            "fig4b_scan_n32.yaml")
        @test isfile(cfg)
        m = yaml_to_model(cfg)
        gs = stage(:relax; model=m, method=:itp, dt=0.005, n_steps=20_000)

        c = claim(
            "runs/matsui_fig4b/fig4b_scan_n32.yaml resolves to the Matsui et al. " *
            "parameters registered in refs/matsui2025.toml";
            kind=:A, evidence=[gs])
        @test c.kind === :A
        @test length(c.evidence) == 1
        @test c.evidence[1].kind === :relax
        # A real stage, so it has a real id.
        @test length(artifact_id(gs)) == 16

        # And the claim is TRUE, checked against the reference file rather than
        # against a comment in the config's header. This is the loop the whole
        # exercise closes: the reconstruction that had to be inferred from their
        # published data is the number our config actually runs.
        @test m.interactions.n_atoms == Int(ref(:matsui2025, :N_atoms).value)
        @test m.interactions.omega_ref ≈ 2π * ref(:matsui2025, :omega_x_Hz).value rtol = 1e-6
        # c1/c0 = 1/36 is their `readme.txt` design rule, not a fit. Our
        # resolved pair reproduces it.
        @test m.interactions.c1 / m.interactions.c0 ≈
            ref(:matsui2025, :c1_over_c0).value rtol = 1e-6
        # …and the constraint that makes the polarised ground state degenerate
        # in that ratio (contract §0.3.5) holds on the resolved model.
        @test m.interactions.c0 + 36 * m.interactions.c1 ≈ 4687.266258 rtol = 1e-6
        @test m.atom.F == 6
    end
end

# ---------------------------------------------------------------------------
# W5: `arbitrates` was hand-set by whoever could also see the result.
# ---------------------------------------------------------------------------
#
# The finding: this file marked some quantities `arbitrates = true`, and whoever
# set that flag could also see how our number compared. That is the approval-
# testing failure mode by another name — golden tests are documented to fail by
# BLESSING a wrong value.
#
# What the tree said before, checked rather than assumed:
#
#   * NOTHING in `src/` dispatched on it. The only `.arbitrates` outside the
#     decoder was a docstring example. `Claim`'s inner constructor required a
#     `target` for a `:C` claim and did NOT require it to arbitrate — so a
#     model-fidelity claim could be built against `dip_centre_exp_nT`, the row
#     whose own note says it "exists to be quotable and to be REFUSED as a
#     target".
#   * The blessing SHAPE was visible in the file: `dip_minimum_sim_atoms`, the
#     quantity we disagree with most (~20 % more atoms moved out of m = -6), is
#     the one flagged non-arbitrating. Its grounds are a real systematic — but
#     under a free `Bool`, "their counting systematic swamps it" and "we do not
#     like the number" were the same three characters.
#
# The decision: KEEP it, because it is the discriminator between "the target" and
# "not the target" and six configs under `runs/matsui_fig4b/` got that wrong —
# but make it two things it was not.
#
#   (a) LOAD-BEARING. `Claim` refuses a `:C` claim whose target does not
#       arbitrate. A flag nothing reads should be cut, not kept as documentation
#       with a Bool type.
#   (b) DERIVED, not declared. `arbitrates == isempty(disqualified_by)`, and
#       `disqualified_by` draws from a CLOSED vocabulary in which every entry is
#       a property of the reference — their axis, the window, the metric. There
#       is no longer a field to set while looking at our result.
#
# The eight pinned values are the regression that (b) reproduces exactly what the
# hand-set booleans said, and the positive control for the whole derivation: a
# rule tuned to produce a different answer fails there.
#
# It lives in THIS file and not its own because the arms below break the
# committed TOML in place, and the tripwire above is right that a second reader
# in a second worker process would race them.

# What the hand-set booleans said, before the derivation replaced them. Pinned
# LITERALLY and not read back out of the TOML — a gate that reads its expectation
# from the file it is checking passes against any value.
const ARBITRATES_PINS = (
    :dip_centre_sim_nT => true,
    :dip_centre_exp_nT => false,
    :dip_width_sim_nT => false,
    :dip_width_exp_nT => false,
    :dip_width_sim_scanwindow_nT => true,
    :dip_width_exp_scanwindow_nT => true,
    :dip_minimum_sim_atoms => false,
    :dip_minimum_exp_atoms => false,
)

@testset "W5: `arbitrates` is derived from a closed, reference-side vocabulary" begin
    @testset "A: the derivation reproduces all eight hand-set values" begin
        for (q, expected) in ARBITRATES_PINS
            r = ref(:matsui2025, q)
            @test r.arbitrates === expected
            # …and it IS the derivation, not a second declaration that happens to
            # agree. Both directions, so neither is vacuous.
            @test r.arbitrates === isempty(r.disqualified_by)
        end
        # Both classes are populated: 3 arbitrating, 5 not. A derivation that
        # returned a constant would satisfy half the loop above.
        arb = [q for (q, _) in ARBITRATES_PINS if ref(:matsui2025, q).arbitrates]
        @test length(arb) == 3
        @test length(ARBITRATES_PINS) - length(arb) == 5
    end

    @testset "B: the disqualifiers are the ones the notes argue for" begin
        # Each row's reason is pinned by NAME, not merely by count: swapping
        # `axis_offset` for `window_not_covered` leaves `arbitrates` identical
        # and would otherwise pass arm A untouched.
        @test ref(:matsui2025, :dip_centre_exp_nT).disqualified_by == [:axis_offset]
        @test ref(:matsui2025, :dip_width_sim_nT).disqualified_by == [:window_not_covered]
        @test ref(:matsui2025, :dip_width_exp_nT).disqualified_by == [:window_not_covered]
        @test ref(:matsui2025, :dip_minimum_sim_atoms).disqualified_by ==
            [:absolute_population]
        @test ref(:matsui2025, :dip_minimum_exp_atoms).disqualified_by ==
            [:absolute_population]
        for q in (:dip_centre_sim_nT, :dip_width_sim_scanwindow_nT,
            :dip_width_exp_scanwindow_nT)
            @test isempty(ref(:matsui2025, q).disqualified_by)
        end

        # The centre is disqualified by the AXIS and not by the window, and the
        # full-window width by the WINDOW and not the axis. That asymmetry is the
        # physics of the two metrics — a shift moves a position and does not
        # stretch a width — and it is what makes the vocabulary say something.
        @test ref(:matsui2025, :dip_centre_exp_nT).window === nothing        # "full"
        @test :window_not_covered ∉ ref(:matsui2025, :dip_centre_exp_nT).disqualified_by
        @test :axis_offset ∉ ref(:matsui2025, :dip_width_exp_nT).disqualified_by
    end

    @testset "C: the vocabulary is CLOSED, and an unknown reason is an error" begin
        @test REF_DISQUALIFIERS ==
            (:axis_offset, :window_not_covered, :absolute_population)
        # A reason invented in the TOML is refused by name. Without this, the key
        # is the free `Bool` it replaced, wearing a list.
        with_broken(REFPATH,
            s -> replace(s,
                "disqualified_by = [\"axis_offset\"]" => "disqualified_by = [\"we_dont_like_it\"]",
                count=1)) do
            e = try
                ref(:matsui2025, :dip_centre_exp_nT)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("not a registered reason", e.msg)
            @test occursin("axis_offset", e.msg)
        end
        # Green again immediately, so the canary tested the gate and not the
        # restore.
        @test ref(:matsui2025, :dip_centre_exp_nT).disqualified_by == [:axis_offset]

        # A bare string is not a one-element list: `"axis_offset"` iterated as
        # characters would produce twelve nonsense reasons.
        with_broken(REFPATH,
            s -> replace(s,
                "disqualified_by = [\"axis_offset\"]" => "disqualified_by = \"axis_offset\"",
                count=1)) do
            e = try
                ref(:matsui2025, :dip_centre_exp_nT)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("must be a LIST", e.msg)
        end

        # And the key is REQUIRED on a measured row: dropping it must not silently
        # make the row arbitrate.
        with_broken(REFPATH,
            s -> replace(s, "disqualified_by = [\"absolute_population\"]\n" => "",
                count=1)) do
            e = try
                ref(:matsui2025, :dip_minimum_sim_atoms)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("disqualified_by", e.msg)
        end
    end

    @testset "D: `arbitrates` is not a key anyone can set" begin
        # The whole point: there is no longer a field to bless. `_closed` refuses
        # an unknown key, so re-adding the old spelling is an ERROR rather than a
        # second declaration that quietly out-votes the derivation.
        doc = TOML.parsefile(REFPATH)
        for (q, t) in doc["quantity"]
            @test !haskey(t, "arbitrates")
        end
        with_broken(REFPATH,
            s -> replace(s,
                "disqualified_by = [\"axis_offset\"]" => "disqualified_by = [\"axis_offset\"]\narbitrates = true",
                count=1)) do
            e = try
                ref(:matsui2025, :dip_centre_exp_nT)
                nothing
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("arbitrates", e.msg)
        end
    end

    @testset "E: the flag BITES — a :C claim needs an arbitrating target" begin
        # This is what makes the flag load-bearing rather than documentation with
        # a Bool type. Before it, `Claim` required a target and not an arbitrating
        # one, so the row that exists "to be REFUSED as a target" was accepted as
        # one.
        # A minimal but REAL Stage, same shape as `test_matsui2025_ref.jl`'s:
        # `Claim` embeds `Stage`, so the constructor gate has to be exercised
        # against the real type rather than a stand-in.
        m = Model(; grid=GridSpec(; ndim=1, n_points=(16,), box=(8.0,)),
            atom=SpinorBEC.ATOM_REGISTRY[:Na23],
            interactions=InteractionSpec(; n_atoms=1000, omega_ref=100.0, c0=10.0, c1=0.1),
            ddi=DDISpec(; c_dd=1.0))
        s = stage(:relax; model=m, method=:itp, dt=0.01, n_steps=10)
        # The control is the PHYSICS switched off — c_dd = 0 — not a tolerance
        # loosened.
        ctrl = stage(:relax; model=with(m; ddi=DDISpec()), method=:itp, dt=0.01, n_steps=10)

        good = ref(:matsui2025, :dip_width_exp_scanwindow_nT)
        bad = ref(:matsui2025, :dip_centre_exp_nT)
        # POSITIVE CONTROL: the arbitrating target still constructs, so a refusal
        # below is about the flag and not about the fixture being malformed.
        @test good.arbitrates
        c = claim("our Fig. 4B width reproduces theirs"; kind=:C, evidence=[s],
            control=ctrl, target=good)
        @test c.target.quantity === :dip_width_exp_scanwindow_nT

        @test !bad.arbitrates
        e = try
            claim("our centre agrees with experiment"; kind=:C, evidence=[s],
                control=ctrl, target=bad)
            nothing
        catch err
            err
        end
        @test e isa ArgumentError
        @test occursin("ARBITRATING target", e.msg)
        # The message names WHICH systematic, so the reader is sent to the axis
        # rather than left to guess.
        @test occursin("axis_offset", e.msg)

        # …and the refusal is specific to `:C`. An `:A` or `:B` claim is not a
        # statement about a published number and is unaffected.
        @test Claim("GPU == CPU", :A, Stage[s], nothing, nothing).kind === :A
        @test Claim("polar beats FM", :B, Stage[s], ctrl, nothing).kind === :B
        # A `:C` claim with no target at all is still refused for the old reason.
        e2 = try
            Claim("x", :C, Stage[s], ctrl, nothing)
            nothing
        catch err
            err
        end
        @test e2 isa ArgumentError
        @test occursin("registered literature target", e2.msg)
    end

    @testset "F: `RefRow` still has ONE shape" begin
        # `disqualified_by::Vector{Symbol}` and not a `Tuple`: a tuple's type
        # varies with its LENGTH, so a row with one reason and a row with none
        # would be different types and the shape could not be pinned.
        ts = unique(typeof(ref(:matsui2025, q)) for q in ref_quantities(:matsui2025))
        @test only(ts) === RefRow
        @test fieldtype(RefRow, :disqualified_by) === Vector{Symbol}
        @test fieldtype(RefRow, :arbitrates) === Bool
        # A non-measured row carries neither a recipe nor a disqualifier, and an
        # empty list there must NOT be read as "it arbitrates".
        r = ref(:matsui2025, :zeeman_q_Hz)
        @test r.provenance === :read_off
        @test isempty(r.disqualified_by)
        @test r.arbitrates === false
    end
end
