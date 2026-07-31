# test/hamiltonian/test_spin_chain_decline_reasons.jl
#
# `_spin_chain_reason` is the ONE list of what the fused V half-step would
# otherwise silently drop, and its own docstring says so: "If you add an operator
# to the outer chain, or a term to the diagonal step, add it here — otherwise the
# fused path would silently drop it."
#
# `test/oracles/test_spin_chain_fusion_parity.jl` claims to pin "one arm per
# entry". It does not, and could not tell you: removing the Raman entry from the
# list — so the fusion swallows a Raman substep that sits between the two
# rotations — escaped that file entirely (mutation harness, 2026-07-31). The same
# shape as the `ddi_padded` entry that had no arm.
#
# Two gates here, both CPU and both cheap, because the claim is about the DECLINE
# LOGIC and needs no stepping at all:
#
#   1. a real arm: a Raman-carrying workspace must decline the fusion;
#   2. a completeness meta-gate: every `return "…"` reason in the function is
#      named somewhere under test/, so a new entry cannot be added unarmed.
#
# (2) is what makes this durable. It cannot check that an arm is CORRECT, but it
# makes an unarmed entry impossible to add silently, which is the failure mode
# this list has had twice.

using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _spin_chain_reason, SPIN_CHAIN_FUSION_ENABLED

@testset "spin-chain fusion decline reasons" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    atom = Rb87
    inter = InteractionParams(Dict(0 => 20.0, 1 => -0.4))
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)

    # `merge` rather than `kw...` after the defaults: a case needs to OVERRIDE
    # `enable_ddi` / `zeeman` / `atom`, and a splatted duplicate of an explicitly
    # listed keyword is not something to rely on.
    _base = (; grid, atom, interactions=inter, zeeman=ZeemanParams(0.3, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=true, c_dd=1.0, fft_flags=FFTW.ESTIMATE)
    _ws(; kw...) = make_workspace(; merge(_base, NamedTuple(kw))...)

    # `:spatial` tabulates ε_LHY against p = |⟨F⟩|/F, and `compute_spatial_lhy`
    # returns `nothing` — falling back to `full_bdg`, a DIFFERENT decline reason —
    # when p has no spread to tabulate against. A flat seed silently armed the
    # wrong branch here on the first run, so the seed ramps from polar to fully
    # polarised across x.
    function _polarisation_ramp()
        n = (8, 8, 8)
        psi = zeros(ComplexF64, n..., 3)
        for I in CartesianIndices(n)
            x = grid.x[1][I[1]]
            f = clamp((x + 3.0) / 6.0, 0.0, 1.0)
            a = exp(-x^2 / 8)
            psi[I, 1] = a * sqrt(f)
            psi[I, 2] = a * sqrt(1 - f)
        end
        psi
    end

    @testset "Raman between the rotations declines the fusion" begin
        ws = _ws(; raman=RamanCoupling{3}(0.5, 0.0, (0.0, 0.0, 0.0)))
        @test ws.raman !== nothing
        psi_mf = copy(ws.state.psi)          # frozen mean field: not the reason
        reason = _spin_chain_reason(ws, ws.interactions, psi_mf)
        @test reason !== nothing
        @test occursin("Raman sits between", reason)

        # Positive control: the SAME workspace without Raman must NOT decline,
        # otherwise the row above passes for an unrelated reason.
        ws0 = _ws()
        @test ws0.raman === nothing
        @test _spin_chain_reason(ws0, ws0.interactions, copy(ws0.state.psi)) === nothing
    end

    # ---- the backlog, armed ------------------------------------------------
    # Each row builds a workspace whose ONLY departure from the baseline above
    # is the condition named, and asserts the fusion declines for that reason.
    # The baseline returns `nothing`, so a row that names reason k has already
    # passed reasons 1…k−1 — the message identifies which branch fired, which
    # is the whole point of testing the decline LOGIC rather than the step.
    @testset "arm: $name" for (name, expect, build) in [
        ("no DDI", "no DDI substep",
            () -> (_ws(; enable_ddi=false), inter)),
        ("c₁ = 0", "c₁ = 0,",
            () -> let ip0 = InteractionParams(Dict(0 => 20.0, 1 => 0.0))
                (_ws(; interactions=ip0), ip0)
            end),
        # Tensor needs a rank-4 channel, so 2F ≥ 4: Rb87 (F=1) cannot express it.
        # c₀ = c₁ = 0 in the WORKSPACE keeps `make_workspace`'s "tensor_cache
        # active with non-zero c0/c1" advisory quiet; the c₁-carrying `ip` is
        # passed separately, exactly as the time-dependent-interaction caller
        # does, so the c₁ = 0 branch is passed and the tensor branch is reached.
        ("tensor channels", "tensor channels sit",
            () -> (
                _ws(; atom=Cr52,
                    interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0, 4 => 0.05))),
                inter)),
        ("light shift", "light shift sits",
            () -> (
                _ws(;
                    light_shift=LightShift(
                        ones(8, 8, 8), [0.2, -0.1, 0.4],
                        Matrix{ComplexF64}(I, 3, 3), true),
                ), inter)),
        # `:spatial` tabulates ε_LHY against |⟨F⟩|/F, so the LHY diagonal phase
        # needs the spin density — a substep, not a closed-form phase.
        ("spatial LHY", "a spatial-LHY spin",
            () -> (_ws(; spinor_lhy=:spatial, psi_init=_polarisation_ramp()), inter)),
        # A B(r) represented per-voxel is non-uniform even when the values are
        # constant; here it genuinely varies so the row is not a technicality.
        ("spatial Zeeman", "a spatial Zeeman",
            () -> (
                _ws(; zeeman=ZeemanParams(),
                    spatial_zeeman=spatial_zeeman_field(
                        grid; bz=(x, y, z) -> 0.3 + 0.01x)), inter)),
        # Uniform field WITH a transverse component: passes the is_uniform gate
        # above and must still decline, because the transverse rotation sits
        # between the two spin-mixing rotations.
        ("transverse Zeeman", "a transverse Zeeman",
            () -> (
                _ws(;
                    zeeman=SpinorBEC.ZeemanField{Nothing}(
                        (0.1, 0.0, 0.3, 0.0), nothing,
                        (nothing, nothing, nothing, nothing)),
                ), inter)),
        ("magnetic gradient", "a magnetic gradient",
            () -> (_ws(; magnetic_gradient=MagneticGradient{3}(0.1, 1, 1.0)), inter)),
        # c₂ is the singlet-pair substep, which sits between the rotations for
        # the same reason the tensor channels do.
        ("c₂ ≠ 0", "c₂ ≠ 0",
            () -> (_ws(), InteractionParams(Dict(0 => 20.0, 1 => -0.4, 2 => 0.1)))),
        # A tabulated LHY is a lookup, not the closed-form `V + c₀n + c·n^{3/2}`
        # phase the fused kernel carries.
        ("tabulated LHY", "a tabulated LHY",
            () -> (_ws(; spinor_lhy=:polar_contact), inter)),
    ]
        ws, ip = build()
        reason = _spin_chain_reason(ws, ip, copy(ws.state.psi))
        @test reason !== nothing
        @test occursin(expect, reason)
    end

    @testset "arm: the mean field is not frozen" begin
        # The one reason that is about the CALLER rather than the workspace:
        # without a frozen mean field there is no midpoint predictor-corrector
        # to fuse against. `psi_mf === nothing` is how the caller says so.
        ws = _ws()
        @test occursin("the mean field is not frozen",
            _spin_chain_reason(ws, inter, nothing))
        @test _spin_chain_reason(ws, inter, copy(ws.state.psi)) === nothing
    end

    @testset "arm: global toggles" begin
        ws = _ws()
        psi_mf = copy(ws.state.psi)
        @test _spin_chain_reason(ws, inter, psi_mf) === nothing   # positive control

        old = SPIN_CHAIN_FUSION_ENABLED[]
        try
            SPIN_CHAIN_FUSION_ENABLED[] = false
            @test occursin("SPIN_CHAIN_FUSION_ENABLED[] is off",
                _spin_chain_reason(ws, inter, psi_mf))
        finally
            SPIN_CHAIN_FUSION_ENABLED[] = old
        end

        old_da = SpinorBEC.DEALIAS_2_3_ENABLED[]
        try
            SpinorBEC.DEALIAS_2_3_ENABLED[] = true
            @test occursin("the Orszag F-filter", _spin_chain_reason(ws, inter, psi_mf))
        finally
            SpinorBEC.DEALIAS_2_3_ENABLED[] = old_da
        end

        # Both restored, or every later test in this process inherits the flag.
        @test SPIN_CHAIN_FUSION_ENABLED[] == old
        @test SpinorBEC.DEALIAS_2_3_ENABLED[] == old_da
        @test _spin_chain_reason(ws, inter, psi_mf) === nothing
    end

    @testset "no DDI buffers is unreachable, and stays that way" begin
        # `make_workspace` builds `ddi_bufs` in exactly the `ddi !== nothing`
        # branch, so "no DDI buffers" is shadowed by "no DDI substep to fuse
        # with" and cannot be armed through the builder. That is not a reason to
        # leave the claim unstated: what actually holds is the INVARIANT that the
        # two fields appear and disappear together. If someone makes the buffers
        # optional (a memory-saving path, say), this row goes red and the reason
        # becomes reachable — which is when it needs a real arm.
        for kw in ((;), (; enable_ddi=false))
            ws = _ws(; kw...)
            @test (ws.ddi === nothing) == (ws.ddi_bufs === nothing)
        end
    end

    @testset "every decline reason is named by some test" begin
        # Read the function's own text and pull out its `return "…"` strings.
        src = read(
            joinpath(dirname(pathof(SpinorBEC)), "hamiltonian", "integrator",
                "spin_chain.jl"), String)
        body = match(r"function _spin_chain_reason\(.*?\n(?:.*?\n)*?^end"m, src)
        @test body !== nothing
        reasons = [m.captures[1] for m in eachmatch(r"return \"([^\"]+)\"", body.match)]
        # The list is long on purpose; if it ever shrinks to nothing this gate is
        # vacuous, so assert it is populated.
        @test length(reasons) >= 10

        # A reason is "armed" if a distinctive phrase from it appears anywhere in
        # test/. Matching on the message rather than on behaviour is deliberate
        # here: this gate is about the LIST and the tests drifting apart, not
        # about any one arm being right.
        # THE BACKLOG BLOCK BELOW IS EXCLUDED, and only it. The allowlist quotes
        # every unarmed reason verbatim, so scanning it would report all of them
        # as armed — the gate would read its own allowlist as evidence and pass
        # vacuously. (It did, on the first run.) Excluding the whole FILE was the
        # first fix and was wrong in the other direction: the arms above live
        # here too, and would not have counted.
        testdir = joinpath(@__DIR__, "..")
        self = abspath(@__FILE__)
        _strip_backlog(txt) = replace(
            txt, r"BACKLOG-BEGIN.*?BACKLOG-END"s => "")
        # `test/mutation/` IS EXCLUDED. It is a catalogue of DEFECTS, and a
        # mutant that inserts a new decline reason carries that reason verbatim
        # in its replacement text. Scanning it lets a mutant arm ITSELF: the
        # `spin_chain_unlisted_new_reason` mutant — whose whole purpose is to
        # check that an unlisted entry reddens this gate — escaped on TSUBAME
        # for exactly that reason (2026-07-31). Quoting a string is not arming
        # it.
        alltests = join(
            [
                let p = joinpath(r, f), t = read(p, String)
                    abspath(p) == self ? _strip_backlog(t) : t
                end
                for (r, _, fs) in walkdir(testdir) for f in fs
                # `normpath` is load-bearing: walkdir yields the root it was
                # given, so the raw path reads `…/test/hamiltonian/../mutation/…`
                # and an `occursin("test/mutation", …)` on it never matches. The
                # first version of this exclusion did exactly that, and the
                # mutant kept escaping — which is how it was found.
                if endswith(f, ".jl") &&
                !occursin(
                    joinpath("test", "mutation"), normpath(abspath(joinpath(r, f))))
            ], "\n")
        unarmed = String[]
        for reason in reasons
            # First few words are enough to be distinctive and survive rewording
            # of the tail; an exact-message match would be a pin.
            key = join(split(reason)[1:min(3, end)], " ")
            occursin(key, alltests) || push!(unarmed, reason)
        end
        # The BACKLOG, declared rather than hidden. Eleven of the list's entries
        # had no arm anywhere under test/ when this gate was written — the
        # docstring's "one arm per entry" was aspirational. Closing them means
        # building a workspace that triggers each and asserting the fusion
        # declines; that is real work and is not done here.
        #
        # What this gate buys today: a NEW entry cannot be added unarmed, because
        # it would not be in this list and the test goes red. Delete a line from
        # here as its arm lands.
        # BACKLOG-BEGIN
        # EMPTY, as of 2026-07-31 — every reason in the list is now named by a
        # test. It is kept because the mechanism, not the contents, is the point:
        # a new entry lands in `newly_unarmed` and this gate goes red until it is
        # either armed or listed here with a reason.
        known_unarmed = Set{String}()
        # BACKLOG-END
        newly_unarmed = setdiff(Set(unarmed), known_unarmed)
        @test isempty(newly_unarmed)
        isempty(newly_unarmed) ||
            @info "NEW decline reason with no arm under test/" newly_unarmed
        # And the backlog may not silently grow stale either: a reason that gets
        # armed must be removed from the list above, or this gate slowly becomes
        # a rubber stamp.
        stale = setdiff(known_unarmed, Set(unarmed))
        @test isempty(stale)
        isempty(stale) || @info "these now HAVE arms — drop them from known_unarmed" stale
    end
end
