# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---
#
# `_run_itp_loop!` — the inner imaginary-time propagation loop used by the
# fixed-dt and adaptive entry points. Extracted from ground_state.jl
# 2026-05-01.

# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---

function _run_itp_loop!(
    ws, n_steps, tol, on_step, target_magnetization;
    start_step::Int=0,
    # Checkpoint observation sinks — both fire at `sp.save_every` cadence
    # (the unified observation cadence) and on terminal state. Pass any
    # subset:
    #   `checkpoint_dir` — legacy single-file `itp_checkpoint.jld2`
    #   `checkpoint`     — Checkpoint primitive (fork!/ancestry-enabled)
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint::Union{Nothing, Checkpoint}=nothing,
    checkpoint_key::String="itp_state",
    verbose::Bool=true,
)
    sp = ws.sim_params
    n_comp = ws.spin_matrices.system.n_components
    F = ws.atom.F
    N_dim = length(ws.grid.config.n_points)
    use_constrained = target_magnetization !== nothing

    E_prev = total_energy(ws)
    converged = false
    psi_prev = copy(ws.state.psi)
    final_dE = NaN
    final_dpsi = NaN
    last_step = start_step
    t_start = time()

    if checkpoint_dir !== nothing
        mkpath(checkpoint_dir)
    end

    interrupted = false
    gpu = _is_gpu(ws.state.psi)
    dt = ws.sim_params.dt
    n_comp_ws = n_comp
    bk = ws.batched_kinetic
    omega = ws.sim_params.rotating_frame_omega
    cc = ws.coriolis_cache
    it = true  # imaginary time

    # ITP Strang split. V(dt/2) = outer_fwd(dt/4) DDI(dt/2) outer_bwd(dt/4).
    # A full step is V(dt/2) K(dt) V(dt/2), and across adjacent steps the
    # trailing V(dt/2) of step n and the leading V(dt/2) of step n+1 sit
    # back-to-back between K-steps.
    #
    # The previous merged-leapfrog form replaced those two V(dt/2) blocks
    # with a single `outer_fwd(dt/2) DDI(dt/2) outer_bwd(dt/2)`. That
    # collapsed outer to dt total (correct) but DDI to dt/2 total (wrong —
    # Strang requires dt). Empirically the converged ground state shifted
    # by ~7% in energy and ψ became visibly different when `save_every`
    # was changed from 1 → 100; with c_dd = 0 the same comparison was at
    # numerical-noise level. Bug-4 (2026-05-02) — confirmed by direct
    # comparison test in `test/test_itp_ddi_strang_save_every.jl`.
    #
    # Two consecutive `_ddi_step!(ws, dt/2, …)` calls are NOT equivalent
    # to a single `_ddi_step!(ws, dt, …)`: `_compute_and_convolve_ddi!`
    # rebuilds φ_{x,y,z} from the current ψ each call, so substepping is
    # the more accurate scheme. Each individual call still uses dt/2 in
    # its `exp(-2F·θ)` shift, so the comment about overflow still holds —
    # we never call DDI at full dt.
    #
    # Optional Orszag 2/3 dealias filter on ψ at ITP entry — needed when
    # we want grid-convergent GS for the downstream dynamics (else the
    # ITP-converged GS contains grid-dependent high-k content that survives
    # to the dynamics phase and propagates a residual cross-grid disagreement
    # even after the dynamics filter is applied; see L4 cross-grid probe
    # 2026-05-24).
    if DEALIAS_2_3_ENABLED[]
        apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp_ws, N_dim)
    end

    # Open: V(dt/2)
    _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
    _ddi_step!(ws, dt / 2, N_dim, it)
    _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)

    try
        for step in (start_step + 1):n_steps
            on_step !== nothing && on_step(ws, step, n_steps)

            if DEALIAS_2_3_ENABLED[]
                apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp_ws, N_dim)
            end

            # Kinetic step K(dt)
            apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws)
            apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
            apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws)

            # Close: V(dt/2). On non-checkpoint steps the loop's reopen
            # block at the end appends another V(dt/2), so DDI gets the
            # full dt per step from the V(dt/2)+V(dt/2) pair.
            _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
            _ddi_step!(ws, dt / 2, N_dim, it)
            _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)

            ws.state.step += 1
            if ws.sim_params.normalize_every > 0 &&
                ws.state.step % ws.sim_params.normalize_every == 0
                _normalize_psi!(ws.state.psi, ws.grid, n_comp_ws, N_dim)
            end

            # NaN check: only first 10 steps (forces GPU sync)
            if step <= (start_step + 10)
                if any(isnan, ws.state.psi)
                    throw(
                        ArgumentError(
                            "NaN detected in ITP at step $step. " *
                            "Likely DDI or interaction overflow. Reduce dt.",
                        ),
                    )
                end
                _check_itp_overflow(ws, step)
            end
            if use_constrained
                _normalize_psi_constrained!(
                    ws.state.psi,
                    ws.grid,
                    n_comp,
                    N_dim,
                    target_magnetization,
                    F,
                )
            end
            last_step = step

            # Observation cadence is unified: both checkpoint paths and
            # the log/convergence-check below fire at `sp.save_every`.
            # No separate `checkpoint_every` knob — one observation knob
            # controls all sinks (sink-pluggable observation, 2026-06-04).
            obs_now = sp.save_every > 0 && step % sp.save_every == 0
            if obs_now && checkpoint_dir !== nothing
                _save_itp_checkpoint(
                    checkpoint_dir, ws, step, n_steps, E_prev, final_dE, final_dpsi, converged, tol
                )
            end
            if obs_now && checkpoint !== nothing
                save_checkpoint!(checkpoint, checkpoint_key,
                    (;
                        psi=_to_host(ws.state.psi),
                        step=step, n_steps=n_steps,
                        E=total_energy(ws), dE=final_dE, dpsi=final_dpsi,
                        converged=converged, dt=ws.sim_params.dt, tol=tol,
                        atom_name=ws.atom.name,
                    ); metadata=(; saved_at=time(),))
            end

            if step % sp.save_every == 0
                E = total_energy(ws)
                # Relative energy-change convergence: scale-invariant so a
                # single `tol` works across systems whose E spans orders of
                # magnitude. Falls back to the absolute change when E ≈ 0.
                dE_abs = abs(E - E_prev)
                dE = abs(E) > 0 ? dE_abs / abs(E) : dE_abs
                psi_max = maximum(abs, ws.state.psi)
                dpsi = if psi_max > 0
                    # Fuse subtraction + abs into map-reduce (avoids temp array alloc)
                    psi_prev .= ws.state.psi .- psi_prev  # reuse psi_prev as diff buffer
                    maximum(abs, psi_prev) / psi_max
                else
                    0.0
                end
                copyto!(psi_prev, ws.state.psi)
                final_dE = dE
                final_dpsi = dpsi

                if verbose
                    elapsed = time() - t_start
                    frac = step / n_steps
                    eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                    println(
                        "  ITP $(step)/$(n_steps) | E=$(round(E; sigdigits=8)) dE/|E|=$(round(dE; sigdigits=3)) " *
                        "dpsi=$(round(dpsi; sigdigits=3)) | $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                    )
                    flush(stdout)
                end

                if dE < tol
                    converged = true
                    break
                end
                E_prev = E
            end

            # Reopen V(dt/2) for the next K-step (skipped after the
            # final step or once converged — no further K to chain into).
            if !converged && step < n_steps
                _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)
            end
        end
    catch e
        if e isa InterruptException
            interrupted = true
            if verbose
                println("\n  ITP interrupted at step $last_step/$n_steps")
                flush(stdout)
            end
        else
            rethrow(e)
        end
    end

    if interrupted && checkpoint_dir !== nothing
        _save_itp_checkpoint(
            checkpoint_dir,
            ws,
            last_step,
            n_steps,
            total_energy(ws),
            final_dE,
            final_dpsi,
            converged,
            tol,
        )
        if verbose
            println("  Checkpoint saved to $checkpoint_dir/itp_checkpoint.jld2")
            flush(stdout)
        end
    end
    # Interrupt path for keyed-store checkpoint: save the final state too
    # so kill-then-resume + branching from the actual interruption point
    # work without losing the trailing partial step.
    if interrupted && checkpoint !== nothing
        save_checkpoint!(checkpoint, checkpoint_key,
            (;
                psi=_to_host(ws.state.psi),
                step=last_step, n_steps=n_steps,
                E=total_energy(ws), dE=final_dE, dpsi=final_dpsi,
                converged=converged, dt=ws.sim_params.dt, tol=tol,
                atom_name=ws.atom.name,
            ); metadata=(; saved_at=time(), interrupted=true))
        if verbose
            println("  Keyed checkpoint saved to $(checkpoint.cache_dir)/<$checkpoint_key>")
            flush(stdout)
        end
    end

    # Guaranteed final-state save: any simulation that finishes (normal
    # completion OR early convergence break) ALWAYS saves its terminal
    # psi to the keyed store when `checkpoint` is provided. Without this,
    # users had to align `checkpoint_every` with `n_steps` or risk
    # losing the actual end state. Now: pass `checkpoint=cp` and the
    # last state is always reachable via load_checkpoint(cp, key).
    if !interrupted && checkpoint !== nothing
        save_checkpoint!(checkpoint, checkpoint_key,
            (;
                psi=_to_host(ws.state.psi),
                step=last_step, n_steps=n_steps,
                E=total_energy(ws), dE=final_dE, dpsi=final_dpsi,
                converged=converged, dt=ws.sim_params.dt, tol=tol,
                atom_name=ws.atom.name,
            ); metadata=(; saved_at=time(), final=true))
    end

    (
        workspace=ws,
        converged=converged,
        energy=total_energy(ws),
        dE=final_dE,
        dpsi=final_dpsi,
        interrupted=interrupted,
        last_step=last_step,
    )
end
