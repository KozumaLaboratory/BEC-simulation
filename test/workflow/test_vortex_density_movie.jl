# The movie analyzer: does the vortex detection actually find a vortex, and does
# the archive hold what the renderer reads?
#
# The detection is validated against `f(r)·exp(i·l·φ)`, where the answer is known
# by construction. A defect finder that is only ever run on simulation output
# cannot be distinguished from one that reports plaquette noise — which is what
# a coarse grid gives you, and what the smoke run of this analyzer produced.

using Test
using JSON
using JLD2
using SpinorBEC
using SpinorBEC: _plaquette_vortices, _analyze_vortex_density_movie,
    _each_dynamics_snapshot

const F_M = 1
const D_M = 3

# f(r) e^{i l φ} on an (n × n) grid, core at the centre of a plaquette so the
# defect is not sitting exactly on a sample point.
function _charge_l_field(n::Int, l::Int)
    xs = range(-3.0, 3.0; length=n)
    off = (xs[2] - xs[1]) / 2
    z = Matrix{ComplexF64}(undef, n, n)
    for j in 1:n, i in 1:n
        x, y = xs[i] + off, xs[j] + off
        r = hypot(x, y)
        z[i, j] = r * exp(-r^2 / 2) * cis(l * atan(y, x))
    end
    z
end

@testset "vortex_density_movie" begin
    @testset "a singly-charged winding is one plaquette, with the right sign" begin
        for l in (1, -1)
            z = _charge_l_field(64, l)
            xs, ys, qs = _plaquette_vortices(angle.(z), abs2.(z), 0.0)
            @test length(qs) == 1
            @test sum(qs) == l
            # ...and it is at the core, not somewhere in the tail.
            @test hypot(xs[1] - 32.5, ys[1] - 32.5) < 2.0
        end
    end

    @testset "a doubly-charged winding SPLITS — count and net differ" begin
        # A plaquette carries at most ±1: the 4-point circulation is a sum of
        # four phase differences each taken into (-π, π], so |dp| cannot reach
        # 4π. An l=2 core therefore appears as TWO adjacent singly-charged
        # plaquettes, not one doubly-charged defect.
        #
        # This is why the analyzer reports the COUNT and the NET separately and
        # the movie plots both. Reading the count as "number of vortices" is
        # wrong for |l| >= 2, and reading a net of 0 as "no vortices" is wrong
        # whenever pairs are present.
        z = _charge_l_field(64, 2)
        xs, ys, qs = _plaquette_vortices(angle.(z), abs2.(z), 0.0)
        @test sum(qs) == 2              # the winding is conserved
        @test length(qs) == 2           # ...but split across plaquettes
        @test all(==(1), qs)
        @test all(hypot.(xs .- 32.5, ys .- 32.5) .< 2.0)   # both at the core
    end

    @testset "a vortex-free state reports nothing" begin
        n = 48
        xs = range(-3.0, 3.0; length=n)
        z = [exp(-(xs[i]^2 + xs[j]^2) / 2) * cis(0.3 * xs[i]) for i in 1:n, j in 1:n]
        _, _, qs = _plaquette_vortices(angle.(z), abs2.(z), 0.0)
        @test isempty(qs)
    end

    @testset "the density threshold is per-slice, not global" begin
        # A component holding 0.1% of the atoms still has its own peak, and its
        # defects are still its defects. Scaling the whole slice must not change
        # what is detected — a threshold read against a global peak would erase
        # the minority component entirely.
        z = _charge_l_field(64, 1)
        a = _plaquette_vortices(angle.(z), abs2.(z), 0.1)
        b = _plaquette_vortices(angle.(z), abs2.(z) .* 1e-3, 0.1)
        @test a[3] == b[3]
    end

    @testset "archive and manifest carry what the renderer reads" begin
        n = 12
        nz = 8
        grid = make_grid(GridConfig{3}((n, n, nz), (6.0, 6.0, 4.0)))
        atom = SpinorBEC.ATOM_REGISTRY[:Na23]
        # Three synthetic snapshots, each with a charge-1 winding in the
        # populated component, fed through the in-memory snapshot path.
        snaps = map(1:3) do _
            psi = zeros(ComplexF64, n, n, nz, D_M)
            plane = _charge_l_field(n, 1)
            for k in 1:nz
                psi[:, :, k, 1] .= plane .* exp(-((k - nz / 2) / 3)^2)
            end
            psi
        end
        dynres = (times=[0.0, 0.1, 0.2], psi_snapshots=snaps)
        results = Dict{Symbol, Any}(:dynamics_result => dynres)

        out = mktempdir()
        res = _analyze_vortex_density_movie(snaps[end], grid, atom,
            Dict{String, Any}("output_dir" => out, "axis" => 3, "threshold" => 0.0),
            nothing, results)

        @test res.n_frames == 3
        @test res.component == 1
        @test all(==(1), res.vortex_counts)
        @test all(==(1), res.net_charges)

        man = JSON.parsefile(joinpath(out, "manifest.json"))
        @test man["n_frames"] == 3
        @test man["times"] ≈ [0.0, 0.1, 0.2]
        @test length(man["extent"]) == 2

        jldopen(joinpath(out, "frames.jld2"), "r") do fh
            @test size(fh["n_col_00001"]) == (n, n)
            @test size(fh["phase_00001"]) == (n, n)
            @test length(fh["vortex_q_00002"]) == 1
            # Float32 on disk: these are pictures, not the state.
            @test eltype(fh["n_col_00001"]) == Float32
        end
    end

    @testset "no dynamics step is an error, not an empty movie" begin
        @test_throws ArgumentError _each_dynamics_snapshot(
            (_...) -> nothing, Dict{Symbol, Any}(), false, "test")
    end
end
