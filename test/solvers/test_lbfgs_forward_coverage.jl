using Test
using SpinorBEC
using SpinorBEC: _LBFGS_FORWARD_KWARGS, find_ground_state_lbfgs

# `find_ground_state(method=:lbfgs)` is a hand-written forward into
# `find_ground_state_lbfgs`. A kwarg added to the callee and forgotten here is
# silently dropped — the caller sees no error, the solver just runs without it.
#
# This gate existed before, caught `rotating_frame_omega` (pre-2026-06-02), and
# was then DELETED in an orphan sweep as "pure-introspection dispatch-coverage
# micro guards — plumbing, not physics". With it gone, #179 added `spinor_lhy`
# and `lhy_opts` to `find_ground_state_lbfgs` and nothing noticed that this
# dispatcher still dropped both, so `find_ground_state(method=:lbfgs,
# spinor_lhy=:polar_contact)` ran with no tabulated LHY at all.
#
# So: a dropped kwarg IS physics when it is a Hamiltonian term. Restored, and
# strengthened — the old version compared the signature against the
# hand-maintained `_LBFGS_FORWARD_KWARGS` tuple only, which cannot tell whether
# the tuple matches the CALL. Updating the list and forgetting the call would
# have passed. Now both directions are checked against the source.

@testset "find_ground_state(method=:lbfgs) forwards every LBFGS kwarg" begin
    kw_names = Base.kwarg_decl(first(methods(find_ground_state_lbfgs)))
    lbfgs_kwargs = Set(k for k in kw_names if !endswith(string(k), "..."))
    forwarded = Set(_LBFGS_FORWARD_KWARGS)
    @test !isempty(lbfgs_kwargs)
    @test !isempty(forwarded)

    # Kwargs that exist only on the L-BFGS path, with no Strang counterpart for
    # the dispatcher to supply. Each is listed by name so adding a new one is a
    # deliberate act, not an accident.
    lbfgs_exclusive = Set([
        :ws_init,                     # warm-start workspace; Strang builds its own
        :lbfgs_history,               # L-BFGS curvature memory
        :m_lbfgs,                     # history depth
        :pin, :epsilon_ramp,          # ε-continuation, L-BFGS-only entry
        :precond_alpha_v, :precond_alpha_k,   # Sobolev preconditioner knobs
        :newton_polish, :newton_max_outer, :newton_max_cg, :newton_eps,
        # eigenvector-residual final polish inside the driver (see the
        # `if residual_polish` block); a convergence stage, no Strang counterpart
        :residual_polish, :residual_hvp_order,
        # floor detection for the Armijo backtracking loop — ITP has no line
        # search, so there is nothing to forward it to
        :stop_at_floor,
        # element type of the L-BFGS s/y curvature history; ITP keeps no history
        :history_precision,
    ])

    not_forwarded = setdiff(lbfgs_kwargs, forwarded, lbfgs_exclusive)
    if !isempty(not_forwarded)
        @info """`find_ground_state(method=:lbfgs)` does NOT forward these. If the \
kwarg affects the Hamiltonian, the solver silently runs without it — add it to \
both `_LBFGS_FORWARD_KWARGS` and the forward block, or declare it \
L-BFGS-exclusive here.""" not_forwarded
    end
    @test isempty(not_forwarded)

    # Reverse: the list must not advertise a kwarg L-BFGS no longer accepts
    # (catches renames and removals).
    stale = setdiff(forwarded, lbfgs_kwargs)
    if !isempty(stale)
        @info "`_LBFGS_FORWARD_KWARGS` names kwargs `find_ground_state_lbfgs` does not accept" stale
    end
    @test isempty(stale)

    # The list is documentation; the call is what runs. Assert they agree, by
    # reading the actual forward block out of the source. Without this, keeping
    # the tuple in sync while forgetting the call still passes.
    src = abspath(joinpath(@__DIR__, "..", "..", "src", "solvers", "ground_state.jl"))
    isfile(src) || (src = abspath(joinpath(@__DIR__, "..", "src", "solvers", "ground_state.jl")))
    @test isfile(src)
    code = read(src, String)
    i = findfirst("return find_ground_state_lbfgs(;", code)
    @test i !== nothing
    j = findnext(")", code, last(i))
    call = code[first(i):(j === nothing ? lastindex(code) : last(j))]

    absent_from_call = [k for k in _LBFGS_FORWARD_KWARGS
                              if !occursin(Regex("\\b$(k)\\b"), call)]
    if !isempty(absent_from_call)
        @info """`_LBFGS_FORWARD_KWARGS` lists kwargs the actual forward block does \
not pass. The list is not the contract — the call is.""" absent_from_call
    end
    @test isempty(absent_from_call)
end
