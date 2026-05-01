# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---
#
# `_run_itp_loop!` — the inner imaginary-time propagation loop used by the
# fixed-dt and adaptive entry points. Extracted from ground_state.jl
# 2026-05-01.

# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---

function _run_itp_loop!(
    ws, n_steps, tol, on_step, target_magnetization;
    start_step::Int=0,
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
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

    # ITP leapfrog: merge outer V substeps (diag+SM+nematic+tensor+raman)
    # between adjacent steps. DDI stays at dt/2 (ITP real exponentials
    # would overflow if doubled).
    #
    # Standard split_step V(dt/2):
    #   outer_fwd(dt/4) → DDI(dt/2) → outer_bwd(dt/4)
    #
    # Leapfrog merges boundary outer_bwd(dt/4) + outer_fwd(dt/4) = outer(dt/2).
    #
    # Open: outer_fwd(dt/4) DDI(dt/2) outer_bwd(dt/4)
    _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
    _ddi_step!(ws, dt / 2, N_dim, it)
    _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)

    try
        for step in (start_step + 1):n_steps
            on_step !== nothing && on_step(ws, step, n_steps)

            # Kinetic step K(dt)
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, cc)
            apply_kinetic_step_batched!(ws.state.psi, bk)
            _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, cc)

            is_check = step % sp.save_every == 0
            is_last = step == n_steps
            need_split = is_check || is_last

            if need_split
                # Close: outer_fwd(dt/4) DDI(dt/2) outer_bwd(dt/4)
                _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)
            else
                # Merged boundary: outer(dt/2) then DDI(dt/2) then outer(dt/2)
                # bwd(dt/4)+fwd(dt/4) = single pass at dt/2
                _outer_potential_fwd!(ws, dt / 2, n_comp_ws, N_dim, it)
                _ddi_step!(ws, dt / 2, N_dim, it)
                _outer_potential_bwd!(ws, dt / 2, n_comp_ws, N_dim, it)
            end

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

            if checkpoint_dir !== nothing && checkpoint_every > 0 && step % checkpoint_every == 0
                _save_itp_checkpoint(
                    checkpoint_dir, ws, step, n_steps, E_prev, final_dE, final_dpsi, converged, tol
                )
            end

            if step % sp.save_every == 0
                E = total_energy(ws)
                dE = abs(E - E_prev)
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
                        "  ITP $(step)/$(n_steps) | E=$(round(E; sigdigits=8)) dE=$(round(dE; sigdigits=3)) " *
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

            # Reopen leapfrog after split point
            if need_split && !converged && step < n_steps
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

