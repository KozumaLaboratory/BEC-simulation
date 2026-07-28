# Walking the saved dynamics snapshots, once.
#
# Two movie analyzers need the same traversal — streamed scratch JLD2 (the
# preferred source for long runs) or the legacy in-memory `psi_snapshots`,
# optionally across every preceding dynamics phase with the phase time offsets
# accumulated. Restating that in each analyzer is how the two would come to
# disagree about which frames exist or what time a frame is at.

"""
    _each_dynamics_snapshot(f, pipeline_results, multi_step, who) -> Int

Call `f(psi_frame, t, phase_idx)` for every saved dynamics snapshot, in order,
and return how many there were.

`t` is measured from the start of the FIRST phase: each phase contributes its
own `times`, offset by the span of the phases before it. `who` only names the
caller in the error messages.
"""
function _each_dynamics_snapshot(f, pipeline_results, multi_step::Bool, who::AbstractString)
    history = get(pipeline_results, :dynamics_history, nothing)
    sources = if multi_step
        history === nothing && throw(ArgumentError(
            "$who multi_step=true requires preceding dynamics steps"))
        collect(history)
    else
        dynres = get(pipeline_results, :dynamics_result, nothing)
        dynres === nothing && throw(ArgumentError(
            "$who requires a preceding dynamics step with save_every > 0"))
        [(
            dynamics_result=dynres,
            snapshot_tmp_path=get(pipeline_results, :snapshot_tmp_path, nothing),
            save_psi_snapshots=get(pipeline_results, :save_psi_snapshots, false),
            snapshot_count=get(pipeline_results, :snapshot_count, 0),
        )]
    end

    n_seen = 0
    t_offset = 0.0
    for (phase_idx, src) in enumerate(sources)
        dr = src.dynamics_result
        dr === nothing && continue
        tmp = src.snapshot_tmp_path
        times = dr.times
        if src.save_psi_snapshots && tmp !== nothing && isfile(tmp)
            jldopen(tmp, "r") do jh
                n_snaps = Int(jh["n_snapshots"])
                for i in 1:min(length(times), n_snaps)
                    n_seen += 1
                    f(jh["frame_" * lpad(string(i), 5, '0')], times[i] + t_offset, phase_idx)
                end
            end
        elseif hasproperty(dr, :psi_snapshots)
            for (i, psi_s) in enumerate(dr.psi_snapshots)
                n_seen += 1
                f(psi_s, times[i] + t_offset, phase_idx)
            end
        end
        t_offset += isempty(times) ? 0.0 : times[end] - times[1]
    end
    n_seen
end

"""
    _n_dynamics_phases(pipeline_results, multi_step) -> Int
"""
function _n_dynamics_phases(pipeline_results, multi_step::Bool)
    multi_step || return 1
    history = get(pipeline_results, :dynamics_history, nothing)
    history === nothing ? 0 : length(collect(history))
end
