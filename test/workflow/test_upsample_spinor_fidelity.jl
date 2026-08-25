# `upsample_spinor` — the property cross-resolution SEEDING rests on (#55).
#
# #55's wall-clock argument is "converge once at low resolution and seed up", and
# its correctness argument is one sentence: spectral interpolation "preserves
# phase / winding / orientation — unlike real-space trilinear, which smears the
# phase". Norm preservation was already gated (`test_seed_from.jl`); the phase
# claim was not gated anywhere, and it is the half that decides whether the seed
# is the same STATE or merely the same mass.
#
# It matters more here than in a scalar code. A spin-F magnetic vortex carries
# component windings `v_m = -m`, i.e. up to ∓6 for ¹⁵¹Eu, and a prolongation that
# quietly dropped the winding of the minority components would hand the fine-grid
# solver a topologically different seed — which converges, cheaply, to the wrong
# branch. That failure has no error message.
#
# The NEGATIVE control is the point of the file: `_trilinear_upsample`, the
# density-only helper the issue warns against, is run on the same field and must
# FAIL to be a valid prolongation. A fidelity test whose comparison method cannot
# fail is the degenerate-knob trap.

using Test
using SpinorBEC

# A charge-ℓ vortex in component `c` of an F=1 spinor, on a cubic grid.
function _vortex_spinor(n::Int, box::Float64, ell::Int; D::Int=3, c::Int=2)
    g = make_grid(GridConfig((n, n, n), (box, box, box)))
    psi = zeros(ComplexF64, n, n, n, D)
    for k in 1:n, j in 1:n, i in 1:n
        x, y, z = g.x[1][i], g.x[2][j], g.x[3][k]
        r = hypot(x, y)
        env = exp(-(x^2 + y^2 + z^2) / (2 * (box / 5)^2))
        # r^|ℓ| kills the core so the field is smooth, and cis(ℓθ) carries the
        # winding. Band-limited on this grid by the Gaussian envelope, which is
        # the condition under which spectral interpolation is EXACT rather than
        # merely good.
        psi[i, j, k, c] = env * r^abs(ell) * cis(ell * atan(y, x))
    end
    (psi, g)
end

@testset "upsample_spinor fidelity — what seeding up depends on (#55)" begin
    n, M, box = 16, 32, 10.0
    R = 2.0                      # loop radius, inside the envelope

    @testset "winding survives the prolongation, at ℓ = 1 and ℓ = 3" begin
        for ell in (1, 3)
            psi, g = _vortex_spinor(n, box, ell)
            up = upsample_spinor(psi, M)
            gM = make_grid(GridConfig((M, M, M), (box, box, box)))

            w_lo = component_phase_winding(psi, g, 2; radius=R)
            w_hi = component_phase_winding(up, gM, 2; radius=R)
            # `converged=false` means the loop was under-sampled and `winding`
            # must not be read — assert it before reading it.
            @test w_lo.converged
            @test w_hi.converged
            @test w_lo.winding == ell
            @test w_hi.winding == ell
        end
    end

    @testset "a global phase and an orientation are carried, not scrambled" begin
        # The broken-symmetry ORIENTATION is what a warm start is for: seeding a
        # fine solve from a converged coarse state is only cheaper if the state it
        # lands in is the same one.
        psi, g = _vortex_spinor(n, box, 1)
        # Put a distinct constant phase on a second component. Spectral
        # interpolation is linear and per-component, so the RATIO between the two
        # components must be untouched everywhere the amplitude is resolvable.
        psi[:, :, :, 3] .= 0.35 .* cis(0.7) .* psi[:, :, :, 2]
        up = upsample_spinor(psi, M)

        mask = abs.(up[:, :, :, 2]) .> 0.05 * maximum(abs, up[:, :, :, 2])
        @test any(mask)
        ratio = up[:, :, :, 3][mask] ./ up[:, :, :, 2][mask]
        @test maximum(abs.(ratio .- 0.35 * cis(0.7))) < 1e-8
    end

    @testset "the coarse samples are REPRODUCED, not approximated" begin
        # Spectral zero-pad at an integer refinement factor is an interpolation:
        # every original grid point must come back exactly (to round-off), which
        # is a much sharper statement than "the fields look alike" and is what
        # makes the prolongation composable with a short polish.
        psi, _ = _vortex_spinor(n, box, 1)
        up = upsample_spinor(psi, M)
        s = M ÷ n
        # Same-box refinement by s: `x_i` of the coarse grid sits at index
        # `s*(i-1)+1` of the fine grid when both are built the same way.
        sub = up[1:s:end, 1:s:end, 1:s:end, :]
        @test size(sub) == size(psi)
        # `upsample_spinor` renormalises to the SOURCE norm, and for an exact
        # interpolation that factor is 1 to round-off — so this also pins that
        # the renormalisation is not silently rescaling a good interpolation.
        scale = sqrt((sum(abs2, psi) / n^3) / (sum(abs2, up) / M^3))
        @test abs(scale - 1) < 1e-10
        @test maximum(abs.(sub .- psi)) < 1e-10 * maximum(abs, psi)
    end

    @testset "NEGATIVE CONTROL: trilinear on the same field is not a prolongation" begin
        # `_trilinear_upsample` is real-valued and density-only, which is exactly
        # why the issue says not to use it for ψ. Applied to |ψ| it cannot carry a
        # phase at all — so a winding read off it is 0 where the spectral path
        # returns 1, and the comparison in the testsets above is therefore capable
        # of failing.
        psi, _ = _vortex_spinor(n, box, 1)
        dens = Array{Float64, 3}(abs.(psi[:, :, :, 2]))
        tri = SpinorBEC.Dashboard._trilinear_upsample(dens, M)
        @test size(tri) == (M, M, M)
        # A real field has no phase to preserve. Stated as an assertion so that if
        # someone ever routes ψ through this helper, this file says why not.
        @test eltype(tri) <: Real
        gM = make_grid(GridConfig((M, M, M), (box, box, box)))
        as_spinor = zeros(ComplexF64, M, M, M, 3)
        as_spinor[:, :, :, 2] .= tri
        w = component_phase_winding(as_spinor, gM, 2; radius=R)
        @test w.winding == 0            # the winding is gone
    end

    @testset "the refusals are loud, and the limits are named" begin
        psi, _ = _vortex_spinor(n, box, 1)
        @test_throws ErrorException upsample_spinor(psi, n)          # M must exceed n
        @test_throws ErrorException upsample_spinor(psi, 15)         # odd M
        # KNOWN-LIMIT, pinned rather than described: `upsample_spinor` is cubic-3D
        # only, so a 1D or 2D run cannot seed up at all and a non-cubic box cannot
        # either. Both fail loudly today; this asserts they keep failing loudly
        # rather than silently interpolating one axis.
        @test_throws MethodError upsample_spinor(zeros(ComplexF64, n, n, 3), M)
        @test_throws ErrorException upsample_spinor(
            zeros(ComplexF64, n, n, 2 * n, 3), M)
    end
end
