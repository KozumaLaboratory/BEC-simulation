using Test
using SpinorBEC
using SpinorBEC: find_ground_state_lbfgs, build_precond_sqrt_pv, combined_precondition!

# The combined preconditioner `P_C = P_V^½ P_K P_V^½` is implemented, correct,
# and OFF by default — because it was MEASURED and it lost: ~40× worse on the
# weak-field Eu+DDI soft manifold at 24³ (`d496dd71`, 2026-06-23). The reason is
# structural rather than a bad α: that ground state spontaneously breaks the
# exact axial U(1) `e^{-iθ(L_z+F_z)}`, so the minimum is a degenerate ORBIT with
# a Goldstone flat direction, and a DIAGONAL preconditioner cannot precondition
# a collective zero mode.
#
# This file exists because the last artifact carrying that finding did not
# survive. `bench/verify_precond_combined.jl` was added in the same commit,
# explicitly "so the next session does not re-derive it", and was deleted two
# days later by `40c329a5`, a sweep that dropped one-off campaign drivers. By
# shape it WAS a one-off driver; nothing in it said it was load-bearing. The
# finding then lived only in a commit message, and on 2026-08-02 a session found
# it by `git log -S` only after having decided to re-run the experiment.
#
# So this does not pin the 40× — a performance number is the wrong thing to
# assert in CI, and `P_C` may well be the right choice on a trapped, gapped
# problem, which is the regime it comes from (Antoine-Levitt-Tang,
# J. Comput. Phys. 343 (2017), arXiv:1611.02045). It pins the DEFAULT, so that
# turning it on is a deliberate act by someone who had to edit this file and
# read why.

@testset "the combined preconditioner is off by default" begin
    kwdefs = Base.kwarg_decl(first(methods(find_ground_state_lbfgs)))
    @test :precond_alpha_v in kwdefs      # the knob still exists under this name

    # Kwarg defaults are not introspectable from a `Method`, so the default is
    # pinned by its OBSERVABLE consequence below rather than by restating the
    # number here — a restated number passes against itself.
    grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
    common = (;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 5.0, 1 => -0.1)),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        initial_state=:polar, verbose=false, n_steps=12, tol=1.0e-8,
    )
    r_default = find_ground_state_lbfgs(; common...)
    r_off = find_ground_state_lbfgs(; common..., precond_alpha_v=-1.0)
    r_on = find_ground_state_lbfgs(; common..., precond_alpha_v=1.0)

    # The default behaves as `precond_alpha_v = -1.0`, bit for bit.
    @test r_default.energy == r_off.energy
    @test r_default.grad_norm == r_off.grad_norm

    # ...and switching it on is not a no-op, so the equality above is a
    # statement about the default and not about the knob being dead.
    @test r_on.energy != r_off.energy

    # The machinery itself still works — this file must not be read as
    # "P_C is broken". It is a valid symmetric preconditioner; it is the wrong
    # one for a problem whose minimum is an orbit.
    ws = r_off.workspace
    psi = ws.state.psi
    sqrt_pv = build_precond_sqrt_pv(ws, psi, 1.0)
    @test all(isfinite, Array(sqrt_pv))
    @test all(>(0), Array(sqrt_pv))
    v = copy(psi)
    combined_precondition!(v, ws, sqrt_pv, ws.grid.k_squared, 1.0)
    @test all(isfinite, Array(v))
    @test v != psi
end
