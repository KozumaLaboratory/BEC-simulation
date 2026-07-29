# Gate: the convolution zero-pad of `F_*_pad` stays zero without being re-zeroed.
#
# `_compute_and_convolve_ddi_padded!` used to open with `ctx.F*_pad .= 0`, three
# stores over the WHOLE padded volume (8× the physical one at pad_factor 2) on
# every call — twice per ITP step. Those zeros were already there: the only
# writes to F_*_pad are the `[1:n_pts...]` corner, which
# `_compute_spin_density!` assigns in full and `apply_orszag_2_3_F_filter!`
# leaves the remainder of by construction.
#
# Dropping the memset makes that an INVARIANT rather than a coincidence, so it
# needs a gate: any future write that reaches past the corner (a padded
# analyzer, a filter that forgets `n_pts`, a spin density that accumulates
# instead of assigns) turns the pad nonzero and silently changes Φ.
#
# The positive control below is what makes this an oracle and not a tautology:
# a dirtied pad DOES move Φ, so "pad is zero" is load-bearing.

using Test
using SpinorBEC
using SpinorBEC: _compute_and_convolve_ddi_padded!

@testset "padded DDI: convolution zero-pad stays zero" begin
    n = 8
    grid = make_grid(GridConfig((n, n, n), (8.0, 8.0, 8.0)))
    sp = SimParams(; dt=0.005, n_steps=1)

    # A spinor with all three of F_x, F_y, F_z nonzero, so every buffer is
    # exercised (a pure m=F state leaves F_x = F_y = 0 and the gate vacuous).
    D = 3
    psi0 = zeros(ComplexF64, n, n, n, D)
    for I in CartesianIndices((n, n, n))
        r2 = sum(grid.x[d][I[d]]^2 for d in 1:3)
        env = exp(-r2 / 4)
        psi0[I, 1] = env
        psi0[I, 2] = 0.7 * env * cis(0.3)
        psi0[I, 3] = 0.4 * env * cis(-1.1)
    end

    ws = make_workspace(;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 5.0, 1 => -0.2)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, psi_init=psi0,
        enable_ddi=true, c_dd=1.0, ddi_padding=true,
    )
    ctx = ws.ddi_padded
    @test ctx !== nothing

    corner = CartesianIndices(grid.config.n_points)
    pad_only(A) = [A[I] for I in CartesianIndices(size(A)) if !(I in corner)]

    for _ in 1:5
        split_step!(ws)
    end

    for (name, A) in (("Fx", ctx.Fx_pad), ("Fy", ctx.Fy_pad), ("Fz", ctx.Fz_pad))
        @test all(iszero, pad_only(A))  # exact zero, not a tolerance
    end

    # Positive control: the pad is not inert. Dirtying one voxel of it moves Φ,
    # so the assertion above is a real constraint on every writer of F_*_pad.
    @testset "dirtied pad changes Φ (the invariant is load-bearing)" begin
        sm = ws.spin_matrices
        n_pts = grid.config.n_points
        _compute_and_convolve_ddi_padded!(
            ws.state.psi, sm, ws.ddi, ctx, Val(D), 3, n_pts)
        phi_clean = copy(ctx.Phi_z_pad)

        dirty = CartesianIndex(ntuple(_ -> n + 1, 3))
        ctx.Fz_pad[dirty] = 1.0
        # Re-run WITHOUT the corner rewrite clearing it: the spin density only
        # assigns the corner, so the dirty voxel survives into the rfft.
        _compute_and_convolve_ddi_padded!(
            ws.state.psi, sm, ws.ddi, ctx, Val(D), 3, n_pts)
        @test !isapprox(ctx.Phi_z_pad, phi_clean; rtol=1e-12)
        ctx.Fz_pad[dirty] = 0.0
    end
end
