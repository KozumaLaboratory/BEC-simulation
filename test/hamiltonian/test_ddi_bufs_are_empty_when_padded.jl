using Test
using SpinorBEC

# Under `ddi_padding`, a gradient call leaves `ws.ddi_bufs` at zero. Anything
# that reads those buffers afterwards is reading zeros, not a field.
#
# MEASURED 2026-08-07 at 8³, D=3, c_dd=1.0:
#
#     ddi_padding=false   max|ddi_bufs.Phi_x| after apply_operator! = 4.8e-3
#     ddi_padding=true    max|ddi_bufs.Phi_x| after apply_operator! = 0.0 exactly
#                         max|grad| = 3.9e-4 in BOTH cases
#
# The padded path writes `ddi_padded.*_pad` and never touches `ddi_bufs`, and
# `DDI_PADDED_DEFAULT = true`, so this is the default for every `run_yaml`.
#
# Two readers were relying on those buffers:
#   * `_check_itp_overflow` (`solvers/ground_state.jl`) takes `phi_max` from
#     them, so the ITP DDI-overflow guard was identically 0 — it could not fire
#     for the configuration that uses padding.
#   * `ext/SpinorBECCUDAExt/gpu_energy.jl` computed `E_ddi` from them.
# Both now branch on `ws.ddi_padded`.
#
# SCOPE, stated deliberately. This gate asserts the BOUNDARY — which buffers are
# filled — because that is what reproduced cleanly on CPU with no GPU. It does
# NOT assert a downstream energy magnitude: the review that surfaced this quoted
# specific values for an anisotropic fixture, and on the same shape here
# `Σ Φ·F · dV` came back at 1e-19 (numerically zero) with `max|Φ| = 4.8e-3` and
# `max|F| = 2.2e-2` — so the inner product cancels for a uniform spin direction
# and those numbers did not reproduce. Asserting a magnitude I could not
# reproduce would be pinning someone else's measurement.

function ddi_ws(padded)
    g = make_grid(GridConfig{3}((8, 8, 8), (6.0, 6.0, 6.0)))
    make_workspace(; grid=g, atom=resolve_atom(:Na23),
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.03)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        enable_ddi=true, c_dd=1.0, ddi_padding=padded,
        sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1))
end

"Anisotropic envelope — a spherically symmetric one is degenerate for DDI."
function aniso(g, D)
    n = size(g.x[1], 1)
    psi = zeros(ComplexF64, n, n, n, D)
    for k in 1:n, j in 1:n, i in 1:n
        x, y, z = g.x[1][i], g.x[2][j], g.x[3][k]
        a = exp(-(x^2 + y^2 + 0.15z^2) / 4)
        psi[i, j, k, 1] = 0.8a
        psi[i, j, k, 2] = 0.5a
        psi[i, j, k, 3] = 0.3a
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(g))
end

@testset "padded DDI leaves ws.ddi_bufs empty" begin
    results = Dict{Bool, NamedTuple}()
    for padded in (false, true)
        ws = ddi_ws(padded)
        psi = aniso(ws.grid, size(ws.state.psi, 4))
        copyto!(ws.state.psi, psi)
        out = similar(psi)
        fill!(out, 0)
        SpinorBEC.apply_operator!(out, SpinorBEC.DDITerm(), ws, psi)
        b = ws.ddi_bufs
        results[padded] = (
            phi=b === nothing ? 0.0 : maximum(abs, b.Phi_x),
            grad=maximum(abs, out),
        )
    end

    # CALIBRATION. If the fixture produced no DDI at all, both branches would
    # read zero and the assertion below would pass for the wrong reason. The
    # GRADIENT must be nonzero on both — that is what proves the term is active.
    @testset "the term is active on both branches" begin
        @test results[false].grad > 1e-6
        @test results[true].grad > 1e-6
        @test isapprox(results[false].grad, results[true].grad; rtol=0.2)
    end

    @testset "unpadded fills ddi_bufs; padded does not" begin
        @test results[false].phi > 1e-6
        @test results[true].phi == 0.0
    end

    # The two readers must branch. Checked on CODE lines only: a first version
    # searched the raw text and passed on the dated COMMENT that explains the
    # branch — a search matching the prose that describes the thing rather than
    # the thing, for the fourth time today. Its canary showed it: reverting the
    # guard left the test green.
    @testset "both readers branch on ddi_padded" begin
        codeonly(path) = join([l for l in eachline(path)
                                     if !startswith(strip(l), "#")], "\n")

        gs = codeonly(joinpath(@__DIR__, "..", "..", "src", "solvers",
            "ground_state.jl"))
        i = findfirst("phi_max", gs)
        @test i !== nothing
        near = gs[max(1, first(i) - 700):min(lastindex(gs), first(i) + 700)]
        @test occursin("ddi_padded", near)
        @test occursin("Phi_x_pad", near)

        gpu = codeonly(joinpath(@__DIR__, "..", "..", "ext", "SpinorBECCUDAExt",
            "gpu_energy.jl"))
        j = findfirst("E_ddi", gpu)
        @test j !== nothing
        blk = gpu[first(j):min(lastindex(gpu), first(j) + 1600)]
        @test occursin("ddi_padded", blk)
        @test occursin("Phi_x_pad", blk)
    end
end
