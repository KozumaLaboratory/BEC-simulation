using Test
using SpinorBEC
using JSON
using SpinorBEC: _build_live_callback, is_divergent_status, divergence_thresholds

# Does what the run WRITES reach what the reaper READS?
#
# This is the one question neither existing suite asks. `test_autopilot.jl:74-80`
# drives `is_divergent_status` with dicts it builds itself —
# `Dict("norm_drift" => 0.5)` — so it tests the predicate against its own
# vocabulary and passes whether or not any producer ever emits that key.
#
# It did not. Measured 2026-08-04, before the fix:
#
#     writer (`pipeline_callbacks.jl`)  step, t, energy, norm, populations, updated_ms
#     reader (`autopilot/monitor.jl`)   norm_drift, classify, fz_jump
#     intersection                      EMPTY
#
# and every one of the reader's three lookups defaults to a HEALTHY value when
# the key is absent (`0.0`, `nothing`, `0.0`). So `is_divergent_status` returned
# `false` for every monitored run in the project's history, however far it had
# diverged — and CLAUDE.md lists the divergence kill as a standing autopilot
# guarantee ("reap loop watches `_live_status.json`, cancels divergent runs,
# classifies `:killed_data`"). A diverging run was filed `:done`, credited to its
# recipe's trust store, and counted as a non-kill by the circuit breakers.
#
# A gate that constructs its input from the thing under test cannot see this.
# This file runs the REAL callback, reads the file it ACTUALLY wrote, and hands
# that to the REAL predicate. Nothing in between is synthetic.

# 8^3, no solver: the callback is invoked directly with a workspace and a psi.
# The defect is about JSON keys, not about physics, and it reproduces at any size.
function probe_ws(; n=(8, 8, 8))
    grid = make_grid(GridConfig{3}(n, (6.0, 6.0, 6.0)))
    atom = resolve_atom(:Na23)
    make_workspace(; grid, atom,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.03)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1))
end

"Run the real callback `n` times, scaling psi by `scale` before the last call."
function emit(dir, ws; every=1, scale=1.0, calls=2)
    path = joinpath(dir, "_live_status.json")
    cb = _build_live_callback(Dict("every" => every), path)
    @assert cb !== nothing
    psi0 = copy(Array(ws.state.psi))
    for k in 1:calls
        if k == calls && scale != 1.0
            ws.state.psi .= psi0 .* scale
        end
        cb(ws, k * every, Float64[], Float64[])
    end
    JSON.parsefile(path)
end

@testset "what the run writes reaches what the reaper reads" begin
    ws = probe_ws()

    @testset "the writer emits every key the detector reads" begin
        st = mktempdir(d -> emit(d, probe_ws()))
        # Named individually so a future omission says WHICH key went missing
        # rather than failing as one opaque set comparison.
        @test haskey(st, "norm_drift")
        @test haskey(st, "fz_jump")
        # `classify` is deliberately absent — `is_divergent_status` skips a
        # `nothing` classification, and inventing one here would be a second
        # classifier competing with `analysis/phases/`. Asserted so that its
        # absence is a decision on record rather than another empty intersection.
        @test !haskey(st, "classify")
    end

    @testset "a healthy run is not killed" begin
        st = mktempdir(d -> emit(d, probe_ws()))
        @test !is_divergent_status(st)
    end

    # THE ARM THE PROJECT DID NOT HAVE. A run that blows up must be seen as
    # divergent BY THE PREDICATE, THROUGH THE FILE. Both halves matter: reading
    # the dict the callback returned in memory would not catch a JSON round-trip
    # that drops or renames a key.
    @testset "a blown-up run IS killed, through the file" begin
        thr = divergence_thresholds()
        st = mktempdir(d -> emit(d, probe_ws(); scale=1.0e3))
        @test st["norm_drift"] > thr.norm_drift
        @test is_divergent_status(st)
    end

    # POSITIVE CONTROL ON THE THRESHOLD. If `norm_drift` were emitted but always
    # zero — the shape a careless fix would produce — the arm above would fail,
    # but an arm asserting only `haskey` would not. Pin that the quantity
    # actually tracks the state.
    @testset "norm_drift tracks the state rather than being a constant" begin
        quiet = mktempdir(d -> emit(d, probe_ws()))
        loud = mktempdir(d -> emit(d, probe_ws(); scale=2.0))
        @test quiet["norm_drift"] < 1.0e-12
        @test loud["norm_drift"] > 1.0
        @test loud["norm_drift"] != quiet["norm_drift"]
    end

    # And the same for fz_jump, which is a DIFFERENCE and so has its own way of
    # being trivially zero: a first call has no predecessor.
    @testset "fz_jump is zero on the first sample and measured after" begin
        mktempdir() do d
            path = joinpath(d, "_live_status.json")
            cb = _build_live_callback(Dict("every" => 1), path)
            w = probe_ws()
            cb(w, 1, Float64[], Float64[])
            first_sample = JSON.parsefile(path)
            @test first_sample["fz_jump"] == 0.0     # no predecessor to differ from

            # Move population between components, which is what <F_z> measures.
            #
            # ADD, do not scale. The seed puts its population in one component,
            # and `pops` is normalised by the total — so multiplying an EMPTY
            # component by any factor leaves every population exactly where it
            # was and `fz_jump` stays 0. The first version of this arm did that
            # and failed, which is the same degenerate-knob trap recorded in
            # [[mistake_null_from_a_degenerate_knob]]: a perturbation the
            # observable cannot see is not a perturbation.
            psi = w.state.psi
            D = size(psi, ndims(psi))
            @test D >= 3
            fz_before = JSON.parsefile(path)
            amp = maximum(abs.(Array(psi)))
            psi[:, :, :, 1] .+= amp
            cb(w, 2, Float64[], Float64[])
            second = JSON.parsefile(path)
            # the populations really moved, or the assertion below is vacuous
            @test second["populations"] != fz_before["populations"]
            @test second["fz_jump"] > 0.0
        end
    end
end
