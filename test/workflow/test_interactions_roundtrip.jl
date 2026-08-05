# Gate: a result file carries the couplings the run actually used.
#
# Result files recorded their OUTPUTS — energy decomposition, dynamics series —
# but not the INPUTS that produced them. `open_result` filled the gap with
# `compute_interaction_params(atom; N_atoms)`, which returns SI couplings
# (c₀ ≈ 1e-46) where the run used dimensionless ones, and did so silently.
#
# Rebuilding a workspace from a stored 2026-05 Eu LHY run that way gave a
# recomputed E_LHY of 1e-121 against a stored 1301. That reads as a
# catastrophic physics failure; it was missing metadata. A post-hoc audit of a
# run was simply not possible, which is how three LHY defects went unnoticed in
# stored artifacts.
#
# Two halves, both gated here: the writer persists the couplings, and the
# fallback — when an OLD file has none — now says so out loud.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: _save_interactions_metadata!, _extract_interactions

const _F = 2
const _D = 5

function _ws_with(; c_lhy=0.0, kind=nothing, extra=Dict{Int, Float64}())
    grid = make_grid(GridConfig((8, 8, 8), (10.0, 10.0, 10.0)))
    c = merge(Dict(0 => 12.5, 1 => -0.375), extra)
    inter = InteractionParams(c; c_lhy=c_lhy)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true)
    atom = AtomSpecies("t", 1.0, _F, 100.0, 95.0, 1.0)
    make_workspace(; grid, atom, interactions=inter, sim_params=sp, spinor_lhy=kind)
end

# `open_result` reads a flat Dict keyed by JLD2 path; mirror that here so the
# test exercises the real extractor rather than a reimplementation of it.
function _roundtrip(ws)
    mktempdir() do dir
        p = joinpath(dir, "r.jld2")
        jldopen(p, "w") do f
            _save_interactions_metadata!(f, ws)
        end
        data = jldopen(p, "r") do f
            Dict{String, Any}(k => f[k] for k in keys(f))
        end
        (data, _extract_interactions(data, ws.atom))
    end
end

@testset "result files carry the couplings the run used" begin
    @testset "c0 / c1 / c_lhy round-trip exactly" begin
        ws = _ws_with(; c_lhy=0.875)
        data, ip = _roundtrip(ws)
        @test ip[0] == 12.5
        @test ip[1] == -0.375
        @test ip.c_lhy == 0.875
        # ...and the values came from the file, not from a lucky fallback.
        @test haskey(data, "interactions_c0")
        @test data["interactions_c0"] == 12.5
    end

    @testset "tensor channels are recorded as g_S, under their own key" begin
        # `make_workspace` moves everything above c1 into `tensor_cache`, and
        # what it holds are g_S PAIR-CHANNEL couplings, not c_k tensor ones:
        # c₂ = 0.25 is stored as g₂ = −0.1178. They therefore get a separate
        # key — writing them into `interactions_c_high_rank` would relabel
        # g_S as c_k and rebuild a different Hamiltonian that looks healthy.
        ws = _ws_with(; extra=Dict(2 => 0.25, 4 => -0.125))
        @test ws.tensor_cache !== nothing
        @test ws.interactions[2] == 0.0          # the reason a separate key is needed
        data, ip = _roundtrip(ws)
        g = Dict(data["tensor_g_channels"])
        @test haskey(g, 2) && haskey(g, 4)
        @test g[2] != 0.25                       # g_S, not c_k -- not interchangeable
        @test ip[2] == 0.0                       # and NOT smuggled in as c2
    end

    @testset "the LHY kind is recorded, not just c_lhy" begin
        # A spinor LHY table cannot be reconstructed from `c_lhy` — it is 0.0
        # for every tabulated mode. Without the kind, re-verification silently
        # rebuilds with NO LHY, which is exactly the shape of the #125 defect.
        ws = _ws_with(; kind=:polar_contact)
        data, _ = _roundtrip(ws)
        @test data["lhy_kind"] == "PolarContactLHY"
        @test ws.interactions.c_lhy == 0.0      # the point: c_lhy alone says nothing

        plain = _ws_with()
        d2, _ = _roundtrip(plain)
        @test d2["lhy_kind"] == "none"
    end

    @testset "an old file with no interactions_* WARNS" begin
        # The failure that made this necessary was silent. A guess presented as
        # the run's couplings is worse than an error, so the fallback must be
        # audible; `@test_logs` fails if the warning stops being emitted.
        atom = AtomSpecies("t", 1.0, _F, 100.0, 95.0, 1.0)
        old = Dict{String, Any}("units/N_atoms" => 1000,
            "units/omega_ref_rad_s" => 628.3)
        ip = @test_logs (:warn,) match_mode = :any _extract_interactions(old, atom)
        # And it really is a different number — this is the 1e-46-vs-10 gap.
        @test ip[0] != 12.5

        # No units either: the defaults (N_atoms=1, omega_ref=1) still send it
        # down the guess branch, so what matters is that it stays audible.
        empty_ip = @test_logs (:warn,) match_mode = :any _extract_interactions(
            Dict{String, Any}(), atom)
        @test empty_ip[0] != 12.5
    end

    @testset "a file WITH interactions_* stays silent" begin
        # The warning must not fire on healthy files, or it trains you to
        # ignore it.
        ws = _ws_with(; c_lhy=0.5)
        mktempdir() do dir
            p = joinpath(dir, "r.jld2")
            jldopen(p, "w") do f
                _save_interactions_metadata!(f, ws)
            end
            data = jldopen(p, "r") do f
                Dict{String, Any}(k => f[k] for k in keys(f))
            end
            @test_logs _extract_interactions(data, ws.atom)
        end
    end
end
