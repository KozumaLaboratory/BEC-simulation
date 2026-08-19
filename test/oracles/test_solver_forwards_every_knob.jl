using Test
using FFTW
using SpinorBEC
using SpinorBEC: _MAKE_WORKSPACE_KWARGS, InteractionParams, LHYTableOpts

# A physics kwarg a solver ACCEPTS must reach the workspace it builds.
#
# WHY THIS GATE EXISTS
#
# `find_ground_state_lbfgs` has accepted `rotating_frame_omega` since 2026-06-02
# and the ground-state pipeline step did not forward it, so one config solved in
# the rotating frame under `method: itp` and in the lab frame under
# `method: lbfgs` — same file, two Hamiltonians, no warning. Fixed 2026-08-19.
#
# The general shape is "a knob is in the signature and inert in the body", and it
# is invisible to every test that does not vary that knob. There are 21 physics
# kwargs; `find_ground_state` accepts 15 and `find_ground_state_lbfgs` 13, and
# nothing checked that any of them arrives.
#
# HOW IT IS MEASURED, AND WHY NOT BY READING THE SOURCE
#
# Behaviourally: build twice, once at the default and once perturbed, and require
# the RESULTING WORKSPACE to differ. A source scan for "does the body mention
# this name" was written first and reported "accepts 0 physics kwargs" for two of
# the four entry points, because it was a regex re-implementation of Julia's
# signature grammar — the trap CLAUDE.md's "Measuring" section names. Reflection
# (`Base.kwarg_decl`) answers what is ACCEPTED; only running the thing answers
# what ARRIVES.
#
# The perturbation table below is a table of INPUTS, not of expected outputs. It
# says "here is a value that must make a difference"; it does not say which field
# changes, so it cannot rot into agreeing with a wrong implementation. What each
# entry must supply is a value distinguishable from the default AND a fixture in
# which the machinery it drives is switched on — `ddi_pad_factor` cannot matter
# with the DDI off, and a gate that perturbed it there would be a degenerate knob.

const _FWD_GRID = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))

"`make_workspace` kwargs that are RUNTIME rather than physics — where it runs and
what it starts from, not what the Hamiltonian is. Excluded from the coverage
partition below for that reason."
const _FWD_RUNTIME = Set([:grid, :sim_params, :psi_init, :backend, :fft_flags,
    :dtype, :atom, :interactions])

"Base kwargs: DDI and a tabulated-capable LHY are ON, so the knobs that shape
them are live. Anything a perturbation needs switched on belongs here."
_fwd_base() = (
    grid=_FWD_GRID,
    atom=Na23,
    interactions=InteractionParams(Dict(0 => 1.0, 1 => -0.05)),
    zeeman=ZeemanParams(0.3, 0.05),
    potential=HarmonicTrap((1.0, 1.0, 1.0)),
    enable_ddi=true,
    c_dd=0.2,
    n_steps=1,
    tol=1e-3,
    fft_flags=FFTW.ESTIMATE,
    verbose=false,
)

# (kwarg, perturbed value). Each must be a value the DEFAULT is not, AND one this
# 3-D fixture admits.
#
# `quasi_2d_ddi` is deliberately ABSENT: `make_ddi_params` refuses it on a 3-D
# grid ("quasi_2d DDI requires a 2D grid (N=2), got N=3"), so exercising it needs
# a second fixture. Listed here as an acknowledged hole rather than left to look
# like coverage — the same disclosure rule `test_path_coverage.jl` follows.
const _FWD_PERTURBATIONS = [
    # Perturbed DOWNWARD from the fixture's `true`: turning the DDI off must
    # change the workspace (`ws.ddi` goes to `nothing`). Found by the coverage
    # partition below, which reported it in neither list on the first run.
    (:enable_ddi, false),
    (:secular_ddi, true),
    (:ddi_padding, true),
    (:zeeman, ZeemanParams(1.7, 0.4)),
    (:potential, HarmonicTrap((2.3, 1.1, 0.7))),
    (:c_dd, 0.9),
    (:interactions, InteractionParams(Dict(0 => 4.0, 1 => 0.3))),
    (:rotating_frame_omega, 0.35),
]

"Physics kwargs this file does NOT exercise, with why. Asserted non-empty-for-a-
reason below so the list cannot quietly become the whole set."
const _FWD_NOT_EXERCISED = Dict(
    :quasi_2d_ddi => "needs a 2-D grid fixture; make_ddi_params refuses it at N=3",
    :quasi_2d => "the contact quasi-2D reduction, same 2-D fixture requirement",
    :l_z => "only meaningful with quasi_2d",
    :l_z_ddi => "only meaningful with quasi_2d_ddi",
    :ddi_pad_factor => "shapes the padded kernel; ddi_padding=true is the arm tested",
    :ddi_trunc_radius => "shapes the truncated kernel; not varied here",
    :spinor_lhy => "gated by test_lhy_table_path_coverage.jl, which varies the kind",
    :lhy_opts => "same",
    :light_shift => "needs an eta/profile fixture",
    :raman => "not accepted by either ground-state solver",
    :loss => "not accepted by either ground-state solver",
    :magnetic_gradient => "not accepted by either ground-state solver",
    :absorbing_boundary => "not accepted by either ground-state solver",
    :spatial_zeeman => "not accepted by either ground-state solver",
    :time_dep_interactions => "not accepted by either ground-state solver",
)

"""A signature of the workspace's PHYSICS, as a comparable value.

Deliberately broad — the Hamiltonian's coefficient sources plus the DDI kernel —
so a knob that lands anywhere in the operator shows up without this file
knowing which field it lands in. A per-kwarg field table would be the rotting
kind of table."""
function _fwd_signature(ws)
    zd = SpinorBEC.zeeman_diagonal(SpinorBEC.zeeman_at(ws.zeeman, 0.0), ws.spin_matrices)
    (
        collect(zd),
        copy(Array(ws.potential_values)),
        sort(collect(ws.interactions.c)),
        ws.interactions.c_lhy,
        if ws.ddi === nothing
            nothing
        else
            (ws.ddi.C_dd,
                round.(Array(ws.ddi.Q_xz); digits=12), round.(Array(ws.ddi.Q_zz); digits=12))
        end,
        # `ddi_padded` is its OWN Workspace field, not a variant of `ddi`: the
        # zero-padded convolution carries a `DDIPaddedContext` with its own plans
        # and buffers. Omitting it made `ddi_padding=true` read as an inert knob
        # on the first run of this file — a false positive that would have been
        # reported as a defect in the solver. The signature has to reach every
        # field a knob can land in, and the padded context is a field.
        ws.ddi_padded === nothing,
        ws.sim_params.rotating_frame_omega,
        ws.sim_params.spin_rotating_frame_omega,
        ws.lhy === nothing,
    )
end

"Accepted kwargs of `f`, from Julia's own reflection."
function _fwd_accepted(f)
    s = Set{Symbol}()
    for m in methods(f), k in Base.kwarg_decl(m)
        endswith(String(k), "...") || push!(s, k)
    end
    s
end

@testset "a solver forwards every physics knob it accepts" begin
    @testset "reflection sees the signatures" begin
        # Positive/negative control on the measuring instrument itself.
        acc = _fwd_accepted(find_ground_state)
        @test :zeeman in acc
        @test :secular_ddi in acc
        @test !(:definitely_not_a_kwarg in acc)
        # No `kwargs...` sink: an unaccepted kwarg is a loud MethodError rather
        # than a silent drop, which is what makes "accepted" the right set to
        # iterate. If a sink is ever added this assertion is where to notice.
        @test !any(m -> any(k -> endswith(String(k), "..."), Base.kwarg_decl(m)),
            methods(find_ground_state))
    end

    @testset "the un-exercised list is a disclosure, not a bypass" begin
        # Every name in it must be a real make_workspace kwarg (so it cannot
        # excuse a typo) and carry a reason. And the union with what IS exercised
        # must cover every physics kwarg, so a NEW one is not silently in neither.
        phys = Set(k for k in _MAKE_WORKSPACE_KWARGS if !(k in _FWD_RUNTIME))
        exercised = Set(first.(_FWD_PERTURBATIONS))
        for (k, why) in _FWD_NOT_EXERCISED
            @test k in phys
            @test !isempty(strip(why))
        end
        uncovered = setdiff(phys, union(exercised, keys(_FWD_NOT_EXERCISED)))
        if !isempty(uncovered)
            @info "physics kwargs in neither the perturbation table nor the \
                   disclosure" kwargs = sort(collect(uncovered))
        end
        @test isempty(uncovered)
    end

    for (name, solver, extra) in [
        ("find_ground_state", find_ground_state, (; dt=0.005)),
        ("find_ground_state_lbfgs", find_ground_state_lbfgs, (;)),
    ]
        @testset "$name" begin
            acc = _fwd_accepted(solver)
            # Drop base kwargs this solver does not accept. `find_ground_state`
            # takes `fft_flags` and `find_ground_state_lbfgs` does not, and there
            # is no `kwargs...` sink, so passing it is a MethodError rather than
            # something to work around.
            base = NamedTuple(k => v for (k, v) in pairs(merge(_fwd_base(), extra))
                                         if k in acc)
            ref = _fwd_signature(solver(; base...).workspace)

            for (kw, val) in _FWD_PERTURBATIONS
                kw in acc || continue
                @testset "$kw arrives" begin
                    got = _fwd_signature(solver(; base..., kw => val).workspace)
                    if got == ref
                        @info "a knob this solver ACCEPTS changed nothing in the built \
                               workspace — it is inert, i.e. not forwarded" solver=name knob=kw
                    end
                    @test got != ref
                end
            end
        end
    end

    @testset "the signature can actually distinguish two workspaces" begin
        # Negative control for `_fwd_signature`: if it collapsed everything to a
        # constant, every assertion above would pass for the wrong reason. Two
        # deliberately different workspaces must compare unequal, and one built
        # twice from the same inputs must compare equal.
        b = merge(_fwd_base(), (; dt=0.005))
        a1 = _fwd_signature(find_ground_state(; b...).workspace)
        a2 = _fwd_signature(find_ground_state(; b...).workspace)
        a3 = _fwd_signature(
            find_ground_state(; b..., zeeman=ZeemanParams(9.1, 0.0)).workspace)
        @test a1 == a2
        @test a1 != a3
    end
end
