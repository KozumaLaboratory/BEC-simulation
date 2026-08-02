# Two simulation loop variants:
#   _run_simulation_standard! — generic per-step split_step! call
#   _run_simulation_leapfrog! — merges adjacent V(dt/2) blocks between
#                                non-checkpoint steps for real-time dynamics

function _run_simulation_standard!(
    ws::Workspace{N},
    sp,
    sys,
    times,
    energies,
    norms,
    mags,
    snapshots,
    callbacks::SimulationCallbacks;
    stream_snapshots::Bool=false,
    stepper::S=(split_step!),
) where {N, S}
    t_start = time_ns()
    try
        for step in 1:(sp.n_steps)
            stepper(ws)

            if callbacks.on_step !== nothing
                callbacks.on_step(ws, step, times, energies)
            end

            if step % sp.save_every == 0
                _record_snapshot!(
                    times, energies, norms, mags, snapshots, ws, sys;
                    keep_psi=(!stream_snapshots),
                )

                elapsed = elapsed_s(t_start)
                frac = step / sp.n_steps
                eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                println(
                    "  step $(step)/$(sp.n_steps) | t=$(round(ws.state.t; sigdigits=6)) " *
                    "E=$(round(energies[end]; sigdigits=8)) | $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                )
                flush(stdout)
                ccall(:fflush, Cint, (Ptr{Cvoid},), C_NULL)

                if callbacks.on_snapshot !== nothing
                    psi_snap = stream_snapshots ? Array(ws.state.psi) : snapshots[end]
                    callbacks.on_snapshot(ws, step, psi_snap)
                end
            end
        end
    catch e
        if e isa InterruptException
            _record_snapshot!(
                times, energies, norms, mags, snapshots, ws, sys;
                keep_psi=(!stream_snapshots),
            )
            println(
                "\n  Simulation interrupted at step $(ws.state.step)/$(sp.n_steps), t=$(round(ws.state.t; sigdigits=6))"
            )
            println(
                "  Final snapshot saved. Use run_simulation_checkpointed! with resume=true to continue."
            )
            flush(stdout)
        else
            rethrow(e)
        end
    end
end

# Branch on a Bool, not on a function-valued local: the two half-V realizations
# have different types, so a `half_V! = cond ? a : b` local would make every
# call site a small-union dispatch inside the hot loop. Both arms here are
# concrete calls.
@inline function _rtp_half_V!(
    combined::Bool, ws::Workspace{N}, dt_half, n_comp, ndim;
    t_eval::Float64, t_start::Float64,
) where {N}
    if combined
        _half_potential_combined!(ws, dt_half, n_comp, ndim, false; t_eval, t_start)
    else
        _half_potential!(ws, dt_half, n_comp, ndim, false; t_eval, t_start)
    end
    nothing
end

"""
Leapfrog-fused simulation loop for real-time dynamics.

Merges adjacent half potential steps V(dt/2)+V(dt/2)=V(dt) between time steps.
Splits at snapshot save points to ensure saved states are proper Strang-split results.
Mathematically identical to standard loop — no accuracy change.

Also uses batched FFT for kinetic step (all components in one FFTW call).
"""
function _run_simulation_leapfrog!(
    ws::Workspace{N},
    sp,
    sys,
    times,
    energies,
    norms,
    mags,
    snapshots,
    callbacks::SimulationCallbacks;
    stream_snapshots::Bool=false,
) where {N}
    dt = sp.dt
    n_comp = sys.n_components
    bk = ws.batched_kinetic
    omega = sp.rotating_frame_omega
    cc = ws.coriolis_cache

    # Which V half-step realization this run uses. Decided ONCE here, not per
    # call, so a run cannot switch splittings halfway through (a t-dependent
    # `transverse_b` in `_rtp_use_combined_step` could otherwise flip it mid-run
    # and silently mix two integrators in one trajectory).
    #
    # Sequential  — diag · SM · DDI · SM · diag, 3 spin rotations per half-V.
    # Combined    — diag · exp(-i dt (c₁⟨F⟩ + Φ_DDI)·F̂) · diag, 1 rotation.
    #
    # Both are O(dt²) and converge to the same continuum limit; they differ at
    # O(dt³) because the combined form has no [SM,[SM,DDI]] commutator error.
    # See `combined_spin_step.jl` and `test_combined_spin_step.jl`.
    combined_V = _rtp_use_combined_step(ws)

    if DEALIAS_2_3_ENABLED[]
        apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp, N,
            ws.grid.config.box_size)
    end

    _rtp_half_V!(
        combined_V, ws, dt / 2, n_comp, N; t_eval=(ws.state.t + dt / 4), t_start=ws.state.t
    )

    try
        for step in 1:(sp.n_steps)
            if DEALIAS_2_3_ENABLED[]
                apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp, N,
                    ws.grid.config.box_size)
            end

            apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)
            apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
            apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, false, ws)

            is_save = (step % sp.save_every == 0)
            is_last = (step == sp.n_steps)

            t_now = ws.state.t

            # Close: V(dt/2). The previous merged branch
            # (`_half_potential_step!(ws, dt, …)` on non-checkpoint steps)
            # was *rate-correct* — _half_potential_step! scales DDI with
            # its parameter, so the merge applied DDI for dt total per
            # step. But it collapsed the two V(dt/2) blocks (end of step
            # n + start of step n+1) into a single DDI(dt) call instead
            # of two DDI(dt/2) substeps with φ_{x,y,z} re-evaluated
            # between them. Empirically this made the converged ψ
            # depend on `save_every` for stiff DDI (~30 % rel-Δψ between
            # save_every=1 and save_every=100 at Eu c_dd, c_dd-scaling
            # super-linear-then-saturating → substep accuracy, not a
            # rate bug).
            #
            # Bug-4 RTP analogue (2026-05-02). Same shape as the ITP
            # fix in itp_loop.jl: drop the merge, always do close +
            # reopen so DDI is substepped. Cost: 2× _half_potential_step!
            # calls per step instead of 1 in the previously-merged path.
            _rtp_half_V!(
                combined_V, ws, dt / 2, n_comp, N;
                t_eval=t_now + 3dt / 4, t_start=t_now + dt / 2,
            )

            apply_rt_dissipation!(ws, dt, n_comp, N)

            ws.state.t += dt
            ws.state.step += 1

            if callbacks.on_step !== nothing
                callbacks.on_step(ws, step, times, energies)
            end

            if is_save
                _record_snapshot!(
                    times, energies, norms, mags, snapshots, ws, sys;
                    keep_psi=(!stream_snapshots),
                )

                if callbacks.on_snapshot !== nothing
                    psi_snap = stream_snapshots ? Array(ws.state.psi) : snapshots[end]
                    callbacks.on_snapshot(ws, step, psi_snap)
                end
            end

            # Reopen V(dt/2) for the next K-step. Skipped on the final
            # step since there's no further K to chain into.
            if !is_last
                _rtp_half_V!(
                    combined_V, ws, dt / 2, n_comp, N;
                    t_eval=(ws.state.t + dt / 4), t_start=ws.state.t,
                )
            end
        end
    catch e
        if e isa InterruptException
            # Close the open half-step so psi is in a valid Strang-split state
            _rtp_half_V!(
                combined_V, ws, dt / 2, n_comp, N;
                t_eval=(ws.state.t + dt / 4), t_start=ws.state.t,
            )
            _record_snapshot!(
                times, energies, norms, mags, snapshots, ws, sys;
                keep_psi=(!stream_snapshots),
            )
            println(
                "\n  Simulation interrupted at step $(ws.state.step)/$(sp.n_steps), t=$(round(ws.state.t; sigdigits=6))"
            )
            println(
                "  Final snapshot saved. Use run_simulation_checkpointed! with resume=true to continue."
            )
            flush(stdout)
        else
            rethrow(e)
        end
    end
end
