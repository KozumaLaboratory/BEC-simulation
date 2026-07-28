# Meta-gate: every LHY *mode* is exercised on all THREE faces.
#
# Why this file exists. Between 2026-07-27 and 2026-07-28, one term — LHY —
# produced three defects that failed in three different directions:
#
#   propagator   DROPPED it       (broadcast path summarised every table as one
#                                  coefficient ⇒ c=0; PR #125). The GPU always
#                                  takes that path, so 12 configs ran with no
#                                  LHY while `_has_lhy` said true.
#   energy       INFLATED it 2.5× (reduced `n·V(n)` instead of `∫₀ⁿ V dn'`;
#                                  every table has ε ∝ n^(5/2), for which
#                                  n·V = (5/2)ε).
#   gradient     ZEROED it        (read `ws.interactions.c_lhy` only, so every
#                                  table gave |grad| = 0 exactly; PR #132).
#
# Each was invisible to the others' tests. The per-term oracle suite covers
# registry `HamTerm`s, and `LHYTerm` is ONE term with ten interchangeable
# tables behind it — so "LHYTerm is gated" was true and meant almost nothing.
# The individual mode tests helped, but each carried a HAND-WRITTEN mode list,
# which is the same disease one level up: a mode added tomorrow is silently
# uncovered on every face at once.
#
# So this gate is driven by `LHY_SCHEMA["kind"].enum` itself. Adding a kind to
# the schema without adding a fixture here turns this red — the same mechanism
# `oracles/test_path_coverage.jl` uses for config-path coverage.
#
# What each face is checked against:
#
#   propagator  fused ::Array kernel == generic broadcast path, and the step
#               actually MOVES ψ (a silent c=0 passes a self-comparison, so
#               "agrees with itself" is not enough).
#   energy      dE/dn == V to finite-difference precision. This is the
#               statement `n·V` violated by exactly 5/2.
#   gradient    δE/δψ̄ == FD of the energy face, and non-zero.
#
# Fixtures are built from the public `compute_spinor_lhy_*` constructors rather
# than `_build_spinor_lhy`, so this gate does not move when the builder's
# signature does.

using Test
using LinearAlgebra: norm
using StaticArrays: SVector
using SpinorBEC
using SpinorBEC: _lhy_V, _lhy_is_active, _lhy_energy, _grad_lhy!,
    _diagonal_step_svec!, _c0c1_to_gS, total_density, delta_polar,
    LHY_SCHEMA, _lhy_needs_spin

const _FF = 6
const _DD = 13
const _NMAX = 200.0
const _NPTS = 400

_g() = _c0c1_to_gS(_FF, 10.0, 0.1)          # c1 > 0 ⇒ polar-stable
_gfm() = _c0c1_to_gS(_FF, 10.0, -0.02)      # c1 < 0 ⇒ FM-stable

# A textured state, for the one mode that reads the local spinor.
#
# m=+F mixed with m=0, NOT with m=+F-1. Adjacent components stay spin-coherent:
# at F=6 a (m=6, m=5) mixture holds |⟨F⟩|/F ≈ 0.92 across the whole cloud, which
# `compute_spatial_lhy` correctly reports as "no texture" (one occupied bin,
# spread 0) and returns `nothing` for. Mixing in m=0 sweeps p over 0…1, which is
# the axis the table is built against.
function _textured(n=6)
    psi = zeros(ComplexF64, n, n, n, _DD)
    for I in CartesianIndices((n, n, n))
        t = (I[1] - 1) / (n - 1)
        psi[I, 1] = sqrt(1 - t)                 # m = +F
        psi[I, _FF + 1] = sqrt(t)               # m =  0
    end
    psi .* 0.9
end

# One fixture per YAML `lhy.kind`. `"none"` is the off switch, not a mode.
#
# `"spatial"` is present but currently unused: it lands with the YAML-wiring PR,
# and carrying the fixture ahead of the enum lets the two merge in either order
# without a red build. Extra fixtures are therefore NOT asserted stale here —
# the schema's own staleness check lives in `test_path_coverage.jl`.
const _MODE_FIXTURES = Dict{String, Function}(
    "scalar" => () -> ScalarLHY(0.5),
    "quasi_2d" => () -> compute_lhy_2d_params(10.0, 0.3),
    "polar_two_channel" =>
        () -> compute_spinor_lhy_polar_two_channel(;
            F=2, c0=10.0, c1=0.1, n_max=_NMAX, n_points=_NPTS),
    "full_bdg" =>
        () -> begin
            z = zeros(ComplexF64, 13)
            z[7] = 1.0                              # m=0: the polar spinor at F=6
            compute_spinor_lhy_table(; spinor=z, F=_FF,
                interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)),
                n_max=_NMAX, n_points=_NPTS)
        end,
    "polar_contact" =>
        () -> compute_spinor_lhy_polar_contact(;
            F=_FF, g_dict=_g(), n_max=_NMAX, n_points=_NPTS),
    "polar_dipolar" =>
        () -> compute_spinor_lhy_polar_dipolar(;
            F=_FF, g_dict=_g(), eps_tilde_dd=0.15, n_max=_NMAX, n_points=_NPTS),
    "fm_contact" =>
        () -> compute_spinor_lhy_fm_contact(;
            F=_FF, g_dict=_gfm(), n_max=_NMAX, n_points=_NPTS),
    "fm_dipolar" =>
        () -> compute_spinor_lhy_fm_dipolar(;
            F=_FF, g_dict=_gfm(), eps_dd=0.15, n_max=_NMAX, n_points=_NPTS),
    "icosahedral" =>
        () -> compute_spinor_lhy_icosahedral(;
            F=_FF, g_dict=_g(), n_max=_NMAX, n_points=_NPTS),
    "spatial" =>
        () -> compute_spatial_lhy(; psi_init=_textured(), F=_FF,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.02)), n_bins=6),
)

# δE/δψ̄ by central difference of the energy face, in both Wirtinger directions.
function _fd_grad(psi, lhy, npts, dV; h=1e-6)
    g = zeros(ComplexF64, size(psi))
    for I in CartesianIndices(size(psi))
        for (dz, w) in ((complex(h), 1.0 + 0im), (complex(0, h), 0.0 + 1.0im))
            p1 = copy(psi)
            p1[I] += dz
            p2 = copy(psi)
            p2[I] -= dz
            g[I] +=
                w * (_lhy_energy(p1, lhy, _DD, 3, npts, dV) -
                 _lhy_energy(p2, lhy, _DD, 3, npts, dV)) / (2h) / 2
        end
    end
    g
end

_ws(lhy) = (; interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)), lhy=lhy)

@testset "every LHY mode is gated on all three faces" begin
    kinds = [k for k in LHY_SCHEMA["kind"].enum if k != "none"]
    @test !isempty(kinds)

    @testset "A: every schema kind has a fixture" begin
        # The mechanism. A new `lhy.kind` cannot ship without being exercised
        # below, which is what the hand-written mode lists could not promise.
        for k in kinds
            @testset "$k" begin
                @test haskey(_MODE_FIXTURES, k)
            end
        end
    end

    n = 6
    npts = (n, n, n)
    dV = 1.0
    zd = SVector{_DD, Float64}(zeros(_DD))

    for k in kinds
        haskey(_MODE_FIXTURES, k) || continue
        @testset "$k" begin
            lhy = _MODE_FIXTURES[k]()
            @test lhy !== nothing
            @test _lhy_is_active(lhy)

            # ---- face 1: the propagator ----------------------------------
            # `quasi_2d` is a 2D model; its V is only defined against a 2D
            # cloud, so the 3D propagator comparison is skipped for it. Every
            # other kind goes through both paths.
            if k != "quasi_2d"
                psi0 = 0.6 .* randn(ComplexF64, n, n, n, _DD)
                for it in (false, true)
                    pa, ma = copy(psi0), copy(psi0)
                    _diagonal_step_svec!(Val(3), pa, zeros(n, n, n), zd, 10.0,
                        lhy, 0.001, zeros(n, n, n), it; psi_mf=ma)

                    # A `view` forces the generic ::AbstractArray method — the
                    # one every CuArray lands on, and the one that dropped the
                    # table entirely before #125.
                    pb, mb = copy(psi0), copy(psi0)
                    _diagonal_step_svec!(Val(3), view(pb, :, :, :, :),
                        zeros(n, n, n), zd, 10.0, lhy, 0.001, zeros(n, n, n), it;
                        psi_mf=view(mb, :, :, :, :))
                    @test maximum(abs.(pa .- pb)) < 1e-12

                    # ...and it must actually DO something. Two paths that both
                    # apply nothing agree perfectly, which is how the drop hid.
                    pz, mz = copy(psi0), copy(psi0)
                    _diagonal_step_svec!(Val(3), pz, zeros(n, n, n), zd, 10.0,
                        NoLHY(), 0.001, zeros(n, n, n), it; psi_mf=mz)
                    @test maximum(abs.(pa .- pz)) > 1e-9
                end
            end

            # ---- face 2: dE/dn == V --------------------------------------
            # The energy must be the INTEGRAL of the potential the propagator
            # applies. `n·V(n)` satisfies neither this nor anything else; it
            # was wrong by exactly 5/2 for every table with ε ∝ n^(5/2).
            let nd = k == "quasi_2d" ? 2 : 3
                pts = ntuple(_ -> n, nd)
                # A UNIFORM cloud, so one density is well defined and dE/dn is
                # the local V rather than a mixture across the profile.
                base = zeros(ComplexF64, pts..., _DD)
                sel = _lhy_needs_spin(lhy) ? 1 : (nd == 2 ? 1 : 7)
                amp = sqrt(20.0)
                selectdim(reshape(base, prod(pts), _DD), 2, sel) .= amp
                nloc = 20.0

                dn = 1e-4
                up, dn_ = copy(base), copy(base)
                up .*= sqrt((nloc + dn) / nloc)
                dn_ .*= sqrt((nloc - dn) / nloc)
                dEdn =
                    (
                        _lhy_energy(up, lhy, _DD, nd, pts, dV) -
                        _lhy_energy(dn_, lhy, _DD, nd, pts, dV)
                    ) /
                    (2 * dn * prod(pts) * dV)
                v = _lhy_needs_spin(lhy) ? _lhy_V(nloc, 1.0, lhy) : _lhy_V(nloc, lhy)
                @test abs(v) > 1e-12                       # not a trivial pass
                @test isapprox(dEdn, v; rtol=2e-4)
            end

            # ---- face 3: gradient == FD of the energy ---------------------
            if k != "quasi_2d"
                psi1 = 0.35 .* randn(ComplexF64, n, n, n, _DD)
                nden = total_density(psi1, 3)
                g = zeros(ComplexF64, size(psi1))
                _grad_lhy!(g, psi1, _ws(lhy), nden, npts, _DD, Val(3))
                @test norm(g) > 1e-6                       # not silently zero
                fd = _fd_grad(psi1, lhy, npts, dV)
                @test norm(g .- fd) / norm(fd) < 1e-5
            end
        end
    end
end
