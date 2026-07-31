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
using SpinorBEC
using SpinorBEC: _spin_chain_reason, SPIN_CHAIN_FUSION_ENABLED

@testset "spin-chain fusion decline reasons" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    atom = Rb87
    inter = InteractionParams(Dict(0 => 20.0, 1 => -0.4))
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)

    _ws(; kw...) = make_workspace(;
        grid, atom, interactions=inter, zeeman=ZeemanParams(0.3, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=true, c_dd=1.0, fft_flags=FFTW.ESTIMATE, kw...)

    @testset "Raman between the rotations declines the fusion" begin
        ws = _ws(; raman=RamanCoupling{3}(0.5, 0.0, (0.0, 0.0, 0.0)))
        @test ws.raman !== nothing
        psi_mf = copy(ws.state.psi)          # frozen mean field: not the reason
        reason = _spin_chain_reason(ws, ws.interactions, psi_mf)
        @test reason !== nothing
        @test occursin("Raman", reason)

        # Positive control: the SAME workspace without Raman must NOT decline,
        # otherwise the row above passes for an unrelated reason.
        ws0 = _ws()
        @test ws0.raman === nothing
        @test _spin_chain_reason(ws0, ws0.interactions, copy(ws0.state.psi)) === nothing
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
        # THIS FILE IS EXCLUDED. The backlog below quotes every unarmed reason
        # verbatim, so scanning it would report all of them as armed — the gate
        # would read its own allowlist as evidence and pass vacuously. (It did,
        # on the first run.)
        testdir = joinpath(@__DIR__, "..")
        self = abspath(@__FILE__)
        alltests = join(
            [
                read(joinpath(r, f), String)
                for (r, _, fs) in walkdir(testdir) for f in fs
                if endswith(f, ".jl") && abspath(joinpath(r, f)) != self
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
        known_unarmed = Set([
            "SPIN_CHAIN_FUSION_ENABLED[] is off",
            "no DDI substep to fuse with",
            "no DDI buffers",
            "c₁ = 0, so there is no spin-mixing rotation to fuse",
            "tensor channels sit between them",
            "light shift sits between them",
            "a spatial-LHY spin substep sits between them",
            "a spatial Zeeman substep sits between them",
            "a transverse Zeeman substep sits between them",
            "the Orszag F-filter reshapes ⟨F⟩ for DDI but not for spin-mixing",
            "a magnetic gradient mutates V around the diagonal step",
        ])
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
