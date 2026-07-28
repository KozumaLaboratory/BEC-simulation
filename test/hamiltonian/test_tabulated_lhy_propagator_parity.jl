# Gate: the tabulated LHY must survive every propagator path.
#
# There are three. The fused `::Array` kernel evaluates `_lhy_V` per voxel; the
# generic broadcast method materialises it; the GPU kernel accepts only the
# scalar forms and sends everything else to the generic one. They must agree.
#
# They did not. The generic path summarised the LHY as a single coefficient,
#
#     c_lhy_val_t = c_lhy isa Float64 ? c_lhy :
#                   (c_lhy isa ScalarLHY ? c_lhy.c_lhy : 0.0)
#
# so every `TabulatedLHY` collapsed to `0.0` while `_has_lhy` still read `true`
# — the branch ran with the LHY silently removed. Measured: `PolarContactLHY`
# differed from the fused kernel by 5.7 in ψ after ONE step, with
# `V_LHY(n=1) = 50.5` simply absent.
#
# Because the GPU falls back to that path, every GPU run using polar_contact /
# fm_contact / icosahedral / polar_dipolar / fm_dipolar / polar_two_channel /
# full_bdg was running with NO LHY and reporting nothing. The existing per-term
# GPU/CPU parity oracle missed it: it never tried a tabulated LHY.
#
# This file is CPU-only so it gates in the default tiers; the GPU leg lives in
# test/gpu/ where a device is available.

using Test
using LinearAlgebra
using StaticArrays
using SpinorBEC
using SpinorBEC: _diagonal_step_svec!, _diagonal_step_with_ls!, _lhy_V, _lhy_is_active,
    _lhy_potential_field, _c0c1_to_gS, compute_spatial_lhy

const _F = 6
const _D = 13

# A cloud whose polarisation runs 1 (centre) → 0 (edge), so `compute_spatial_lhy`
# has a spread to tabulate against and does not abstain.
function _textured_state(n::Int=6)
    psi = zeros(ComplexF64, n, n, n, _D)
    c = (n + 1) / 2
    for i in 1:n, j in 1:n, k in 1:n
        r = clamp(sqrt((i - c)^2 + (j - c)^2 + (k - c)^2) / (n / 2), 0.0, 1.0)
        a = exp(-2r^2)
        psi[i, j, k, 1] = a * (1 - r)
        psi[i, j, k, _F + 1] = a * r
    end
    psi
end

function _lhy_zoo()
    g = _c0c1_to_gS(_F, 10.0, 0.1)
    gfm = _c0c1_to_gS(_F, 10.0, -0.02)
    (
        "NoLHY" => NoLHY(),
        "ScalarLHY" => ScalarLHY(0.5),
        "PolarContactLHY" => compute_spinor_lhy_polar_contact(;
            F=_F, g_dict=g, n_max=200.0, n_points=200),
        "FMContactLHY" => compute_spinor_lhy_fm_contact(;
            F=_F, g_dict=gfm, n_max=200.0, n_points=200),
        "IcosahedralLHY" => compute_spinor_lhy_icosahedral(;
            F=_F, g_dict=g, n_max=200.0, n_points=200),
        "PolarTwoChannelLHY" => compute_spinor_lhy_polar_two_channel(;
            F=_F, c0=10.0, c1=0.1, n_max=200.0, n_points=200),
    )
end

@testset "Tabulated LHY survives every propagator path" begin
    n = 6
    psi0 = randn(ComplexF64, n, n, n, _D)
    zd = SVector{_D, Float64}(zeros(_D))

    @testset "fused ::Array kernel == generic broadcast path" begin
        # A `view` forces the generic `::AbstractArray` method — the same one a
        # CuArray lands on. This is the comparison that was missing.
        for (label, lhy) in _lhy_zoo(), it in (false, true)
            pa, ma = copy(psi0), copy(psi0)
            Va, da = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_svec!(Val(3), pa, Va, zd, 10.0, lhy, 0.001, da, it;
                psi_mf=ma)

            pb, mb = copy(psi0), copy(psi0)
            Vb, db = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_svec!(Val(3), view(pb, :, :, :, :), Vb, zd, 10.0, lhy,
                0.001, db, it; psi_mf=view(mb, :, :, :, :))

            @test maximum(abs.(pa .- pb)) < 1e-13
        end
    end

    @testset "SpatialLHY too — it is not a TabulatedLHY" begin
        # `SpatialLHY <: AbstractLHY` directly, so every method written for
        # `TabulatedLHY` misses it. It also reads the local polarisation, which
        # the broadcast path has to build as a field rather than per voxel, and
        # the light-shift step repeats the whole arrangement. Each of those is a
        # separate chance for the two statements of V_LHY to part ways.
        lhy = compute_spatial_lhy(; psi_init=_textured_state(), F=_F,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.02)), n_bins=8)
        @test lhy isa SpinorBEC.SpatialLHY
        @test SpinorBEC._lhy_needs_spin(lhy)

        ls_amp = SVector{_D, Float64}(range(-0.3, 0.3; length=_D))
        ls_prof = ones(n, n, n)

        for it in (false, true)
            pa, ma = copy(psi0), copy(psi0)
            Va, da = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_svec!(Val(3), pa, Va, zd, 10.0, lhy, 0.001, da, it;
                psi_mf=ma)

            pb, mb = copy(psi0), copy(psi0)
            Vb, db = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_svec!(Val(3), view(pb, :, :, :, :), Vb, zd, 10.0, lhy,
                0.001, db, it; psi_mf=view(mb, :, :, :, :))
            @test maximum(abs.(pa .- pb)) < 1e-13

            pc, mc = copy(psi0), copy(psi0)
            Vc, dc = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_with_ls!(Val(3), pc, Vc, zd, 10.0, lhy, 0.001, dc, it,
                ls_amp, ls_prof; psi_mf=mc)

            pd, md = copy(psi0), copy(psi0)
            Vd, dd = zeros(n, n, n), zeros(n, n, n)
            _diagonal_step_with_ls!(Val(3), view(pd, :, :, :, :), Vd, zd, 10.0,
                lhy, 0.001, dd, it, ls_amp, ls_prof;
                psi_mf=view(md, :, :, :, :))
            @test maximum(abs.(pc .- pd)) < 1e-13

            # Agreeing on nothing is how the original bug hid, so assert the
            # term is present at all — on BOTH paths.
            @test maximum(abs.(pa .- psi0)) > 1e-6
            @test maximum(abs.(pb .- psi0)) > 1e-6
        end
    end

    @testset "a tabulated LHY actually changes the state" begin
        # The old bug produced a result IDENTICAL to no-LHY, so "it ran" and
        # "the paths agree" would both have passed had they agreed on zero.
        # Pin that the LHY is present at all.
        tbl = compute_spinor_lhy_polar_contact(;
            F=_F, g_dict=_c0c1_to_gS(_F, 10.0, 0.1), n_max=200.0, n_points=200)
        @test _lhy_V(1.0, tbl) > 1.0
        for path in (identity, x -> view(x, :, :, :, :))
            p_no, m_no = copy(psi0), copy(psi0)
            _diagonal_step_svec!(Val(3), path(p_no), zeros(n, n, n), zd, 10.0,
                NoLHY(), 0.001, zeros(n, n, n), false; psi_mf=path(m_no))
            p_yes, m_yes = copy(psi0), copy(psi0)
            _diagonal_step_svec!(Val(3), path(p_yes), zeros(n, n, n), zd, 10.0,
                tbl, 0.001, zeros(n, n, n), false; psi_mf=path(m_yes))
            @test maximum(abs.(p_no .- p_yes)) > 1e-3
        end
    end

    @testset "_lhy_is_active agrees with what the propagators do" begin
        @test !_lhy_is_active(nothing)
        @test !_lhy_is_active(NoLHY())
        @test !_lhy_is_active(0.0)
        @test !_lhy_is_active(ScalarLHY(0.0))
        @test _lhy_is_active(1.5)
        @test _lhy_is_active(ScalarLHY(0.5))
        for (_, lhy) in _lhy_zoo()
            lhy isa NoLHY && continue
            @test _lhy_is_active(lhy)
        end
    end

    @testset "_lhy_potential_field == pointwise _lhy_V" begin
        # The materialised field and the per-voxel call must be the same
        # function, or the fused and broadcast kernels part ways again.
        dens = [0.0, 0.3, 1.0, 7.7, 55.0, 300.0]
        for (_, lhy) in _lhy_zoo()
            lhy isa NoLHY && continue
            got = _lhy_potential_field(lhy, dens, Float64)
            @test got ≈ [_lhy_V(d, lhy) for d in dens] rtol = 1e-14
        end
    end

    @testset "F32 grids stay F32" begin
        tbl = compute_spinor_lhy_polar_contact(;
            F=_F, g_dict=_c0c1_to_gS(_F, 10.0, 0.1), n_max=200.0, n_points=200)
        out = _lhy_potential_field(tbl, Float32[0.5, 2.0], Float32)
        @test eltype(out) == Float32
    end
end
