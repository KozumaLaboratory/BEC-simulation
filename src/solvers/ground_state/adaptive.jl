# --- Adaptive-dt ITP: target-based dt control ---

"""
Adaptive dt ground state search.

Strategy: run check_every steps, then evaluate energy.
- Energy decreased → grow dt by 10% (capped at dt_max)
- Energy increased → revert psi, halve dt, retry
"""
function _find_ground_state_adaptive(;
    grid,
    atom,
    interactions,
    zeeman,
    potential,
    dt,
    n_steps,
    tol,
    psi0,
    enable_ddi,
    c_dd,
    secular_ddi=false,
    dt_max,
    fft_flags=FFTW.MEASURE,
    rotating_frame_omega::Float64=0.0,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
    light_shift=nothing,
    verbose::Bool=true,
)
    current_dt = dt
    check_every = max(1, n_steps ÷ 100)
    psi_current = copy(psi0)

    sp = SimParams(;
        dt=current_dt,
        n_steps=check_every,
        imaginary_time=true,
        normalize_every=1,
        save_every=check_every,
        rotating_frame_omega,
    )
    ws = make_workspace(;
        grid,
        atom,
        interactions,
        zeeman,
        potential,
        sim_params=sp,
        psi_init=psi_current,
        enable_ddi,
        c_dd,
        secular_ddi,
        fft_flags,
        quasi_2d_ddi,
        l_z_ddi,
        quasi_2d,
        l_z,
        backend,
        light_shift,
    )
    psi_backup = similar(ws.state.psi)
    E_prev = total_energy(ws)
    converged = false
    total_steps = 0

    final_dE = NaN
    final_dpsi = NaN
    t_start = time()

    while total_steps < n_steps
        copyto!(psi_backup, ws.state.psi)

        for i in 1:check_every
            split_step!(ws)
            if i == 1 && total_steps == 0
                _check_itp_overflow(ws, 1)
            end
            if any(isnan, ws.state.psi)
                copyto!(ws.state.psi, psi_backup)
                break
            end
        end
        total_steps += check_every

        E = total_energy(ws)

        if isnan(E) || E > E_prev
            copyto!(ws.state.psi, psi_backup)
            current_dt = max(current_dt * 0.5, 1e-8)
            ws = _rebuild_workspace_with_dt(ws, current_dt)
            if verbose
                println(
                    "  ITP adaptive: rejected at step $(total_steps)/$(n_steps), dt → $(current_dt)"
                )
                flush(stdout)
            end
        else
            dE = abs(E - E_prev)
            psi_max = maximum(abs, ws.state.psi)
            dpsi = psi_max > 0 ? maximum(abs, ws.state.psi .- psi_backup) / psi_max : 0.0
            final_dE = dE
            final_dpsi = dpsi

            if verbose
                elapsed = time() - t_start
                frac = total_steps / n_steps
                eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                println(
                    "  ITP $(total_steps)/$(n_steps) | E=$(round(E; sigdigits=8)) dE=$(round(dE; sigdigits=3)) " *
                    "dpsi=$(round(dpsi; sigdigits=3)) dt=$(round(current_dt; sigdigits=3)) | " *
                    "$(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                )
                flush(stdout)
            end

            # Convergence by dE only — dpsi can stay large with persistent
            # mass currents (DDI-driven vortex flow, FL texture, etc.)
            if dE < tol
                converged = true
                break
            end
            E_prev = E
            new_dt = min(current_dt * 1.1, dt_max)
            if new_dt != current_dt
                current_dt = new_dt
                ws = _rebuild_workspace_with_dt(ws, current_dt)
            end
        end
    end

    (
        workspace=ws,
        converged=converged,
        energy=total_energy(ws),
        dE=final_dE,
        dpsi=final_dpsi,
    )
end

