# RK4IP must actually be 4th order — measured, with the DDI on AND off.
#
# The DDI-off control is not optional. Composition integrators on this same path
# hit nominal order without the DDI and collapse to ~1 with it (PR #46), because
# the mean field breaks the base step's time symmetry. A test that only checks
# the DDI-on case cannot tell "the method is 4th order" from "the whole harness
# is broken", and a test that only checks DDI-off would have passed for the
# broken Yoshida.
#
# Order is measured by Richardson: step the same initial state to a fixed T with
# dt and dt/2, against a reference at dt/8, and read the slope.

using Test
using SpinorBEC
using LinearAlgebra

const _RK_N = 8
const _RK_L = 6.0
const _RK_T = 0.05

function _rk_workspace(; enable_ddi::Bool, dt::Float64)
    grid = make_grid(GridConfig((_RK_N, _RK_N, _RK_N), (_RK_L, _RK_L, _RK_L)))
    atom = Eu151
    # Deliberately strong couplings on a small grid: the point is to excite the
    # nonlinearity, not to be physical.
    interactions = InteractionParams(Dict(0 => 40.0, 1 => 3.0))
    sp = SimParams(; dt=dt, n_steps=max(1, round(Int, _RK_T / dt)), save_every=10^9)
    kw = (; grid, atom, interactions,
        zeeman=ZeemanParams(0.7, 0.05),
        potential=HarmonicTrap((1.0, 1.0, 1.2)),
        sim_params=sp, backend=CPUBackend())
    if enable_ddi
        make_workspace(; kw..., enable_ddi=true, c_dd=8.0, secular_ddi=false)
    else
        make_workspace(; kw...)
    end
end

"A spin-textured, non-stationary start so every term is exercised."
function _rk_psi0(ws)
    sys = ws.spin_matrices.system
    psi = init_psi(ws.grid, sys; state=:spin_coherent, init_theta=0.7, init_phi=0.3)
    ComplexF64.(psi)
end

function _evolve(psi0; enable_ddi, dt)
    ws = _rk_workspace(; enable_ddi=enable_ddi, dt=dt)
    copyto!(ws.state.psi, psi0)
    ws.state.t = 0.0
    for _ in 1:(ws.sim_params.n_steps)
        rk4ip_step!(ws)
    end
    Array(ws.state.psi)
end

function _order(; enable_ddi::Bool)
    ws0 = _rk_workspace(; enable_ddi=enable_ddi, dt=_RK_T / 8)
    psi0 = _rk_psi0(ws0)
    ref = _evolve(psi0; enable_ddi=enable_ddi, dt=_RK_T / 128)
    e_coarse = norm(_evolve(psi0; enable_ddi=enable_ddi, dt=_RK_T / 8) .- ref)
    e_fine = norm(_evolve(psi0; enable_ddi=enable_ddi, dt=_RK_T / 16) .- ref)
    (log2(e_coarse / e_fine), e_coarse, e_fine)
end

@testset "RK4IP convergence order" begin
    @testset "DDI OFF — the control that a broken composition also passes" begin
        p, ec, ef = _order(; enable_ddi=false)
        @test ef < ec                       # refining must help at all
        @test p > 3.6
        @test p < 4.4
    end

    @testset "DDI ON — where composition schemes collapse to ~1" begin
        p, ec, ef = _order(; enable_ddi=true)
        @test ef < ec
        # PR #46: plain Yoshida-4 measures ~1.0 here and merged-V caps at ~2.5.
        # Anything below 3.5 means the mean field is being handled in a way that
        # destroys the order, which is the whole reason this file exists.
        @test p > 3.6
        @test p < 4.4
    end

    # RK4IP's failure mode is a wall, not a slope: it holds ~1e-1 relative error
    # and then returns 1e40. A unitary split-step forgives an over-large dt and
    # this does not, so it must compose with the existing controller rather than
    # need a parallel one. The `dt` keyword is the whole interface.
    @testset "drives the existing adaptive controller" begin
        ws = _rk_workspace(; enable_ddi=true, dt=_RK_T / 16)
        copyto!(ws.state.psi, _rk_psi0(ws))
        ws.state.t = 0.0

        # A deliberately over-large starting dt, past where the fixed-step probe
        # measures divergence. The controller must pull it back rather than
        # integrate the blow-up.
        st = AdaptiveDtState(_RK_T / 2)
        t_end = _RK_T
        n = 0
        while ws.state.t < t_end - 1e-12 && n < 500
            st.dt = min(st.dt, t_end - ws.state.t)
            # `step!=rk4ip_step!` without the spaces lexes as `step != ...`.
            adaptive_step!(ws, st; tol_abs=1e-10, tol_rel=1e-8, p=4, (step!)=(rk4ip_step!))
            n += 1
        end

        @test ws.state.t ≈ t_end atol = 1e-9
        @test all(isfinite, ws.state.psi)               # the wall was not walked into
        @test st.n_accept > 0
        @test st.dt < _RK_T / 2                          # it shrank from the bad guess

        # And the result is actually accurate — an adaptive loop that accepts
        # everything would also satisfy every assertion above.
        ref = _evolve(_rk_psi0(ws); enable_ddi=true, dt=_RK_T / 128)
        @test norm(Array(ws.state.psi) .- ref) / norm(ref) < 1e-5
    end

    @testset "refuses imaginary time rather than silently doing the wrong thing" begin
        grid = make_grid(GridConfig((_RK_N, _RK_N, _RK_N), (_RK_L, _RK_L, _RK_L)))
        ws = make_workspace(; grid, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 1.0)),
            sim_params=SimParams(; dt=1e-3, n_steps=1, imaginary_time=true),
            backend=CPUBackend())
        @test_throws ArgumentError rk4ip_step!(ws)
    end
end
