# Delivering an interrupt to a running solve, without a window.
#
# Four gates race a background `run_yaml` task: wait for it to reach a known
# point, then interrupt it and assert the run is NOT served from cache. Each of
# them used to ask `istaskdone` first and `schedule` second:
#
#     won_race = !istaskdone(task)
#     @test won_race
#     won_race && schedule(task, InterruptException(); error=true)
#
# That is check-then-act. The solve can finish between the two, and then
# `schedule` throws `ErrorException("schedule: Task not runnable")` from outside
# any `@test` — which aborts the whole FILE and takes the sibling gates with it.
# Observed twice under `SPINORBEC_TEST_WORKERS=auto`, most recently 1 run in 5.
# The guard was written precisely to stop that, and could not, because the
# predicate is not the act.
#
# `deliver_interrupt!` closes the window by making the delivery its own test:
# the only way to know a task was still runnable is to have scheduled it. A lost
# race becomes a clean `false` the caller turns into a named `@test` failure,
# never an error that hides its siblings.

"""
    deliver_interrupt!(task) -> Bool

Send `InterruptException` to `task`, returning whether it landed. `false` means
the task had already finished — the race was lost and the caller measured
nothing, which is a FAILURE, not an error. Any other `schedule` problem is
rethrown, so a real bug in the harness still names itself.
"""
function deliver_interrupt!(task::Task)
    try
        schedule(task, InterruptException(); error=true)
        true
    catch e
        # Julia raises a plain ErrorException with this message from `enq_work`.
        # Match on it rather than on the type, which is far too broad to swallow.
        e isa ErrorException && occursin("not runnable", e.msg) || rethrow()
        false
    end
end

"""
    warn_lost_race(won::Bool)

Emit the shared diagnosis for a lost interrupt race. Kept next to
[`deliver_interrupt!`](@ref) so the four call sites cannot drift in wording.
"""
function warn_lost_race(won::Bool)
    won || @warn "interrupt harness LOST THE RACE: the run finished before the " *
        "interrupt was delivered, so this gate measured nothing"
    won
end
