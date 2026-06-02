using Test
using SpinorBEC
using SpinorBEC: _LBFGS_FORWARD_KWARGS, find_ground_state_lbfgs

# Pre-2026-06-02 `find_ground_state(method=:lbfgs)` did not forward the
# `rotating_frame_omega` kwarg to `find_ground_state_lbfgs`. The bug
# evaded both unit tests and reviewers because the dispatcher's forward
# list and the LBFGS signature were maintained by hand in two places.
# This test fails if a kwarg appears on `find_ground_state_lbfgs` that
# the dispatcher does not forward — i.e. it pins the kwarg-coverage
# invariant of the dispatcher.
@testset "find_ground_state(method=:lbfgs) forwards every LBFGS kwarg" begin
    # Inspect `find_ground_state_lbfgs`'s kwargs via Julia's `kwarg_decl`.
    m = first(methods(find_ground_state_lbfgs))
    kw_names = Base.kwarg_decl(m)
    # `kwarg_decl` may include `kwargs...`-style trailing splat names with
    # a trailing `...`. We compare against the leading-name form.
    lbfgs_kwargs = Set(k for k in kw_names if !endswith(string(k), "..."))

    forwarded = Set(_LBFGS_FORWARD_KWARGS)

    # `ws_init` is an LBFGS-only kwarg (no Strang counterpart) — the
    # dispatcher correctly does NOT forward it. Allow this single
    # exception by name.
    lbfgs_exclusive = Set([:ws_init])

    missing_from_dispatcher = setdiff(lbfgs_kwargs, forwarded, lbfgs_exclusive)
    @test isempty(missing_from_dispatcher)
    if !isempty(missing_from_dispatcher)
        @info "LBFGS kwargs that `find_ground_state(method=:lbfgs)` does NOT forward" missing_from_dispatcher
    end

    # Reverse check: the dispatcher should not advertise forwarding a
    # kwarg that LBFGS no longer accepts (guard against rename / removal).
    stale_in_dispatcher = setdiff(forwarded, lbfgs_kwargs)
    @test isempty(stale_in_dispatcher)
end
