# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---
#
# `_run_itp_loop!` — the inner imaginary-time propagation loop used by the
# fixed-dt and adaptive entry points. Extracted from ground_state.jl
# 2026-05-01.

# --- Trustworthiness of the ITP fixed point ------------------------------------
#
# Imaginary-time propagation finds the ground state only in the dt → 0 limit. At
# any finite dt the fixed point of the split-step map is displaced, and the
# displacement is O(dt^p) times commutators of the individual Hamiltonian terms —
# NOT of their sum. So when the answer is a small residual of large, nearly
# cancelling terms, the displacement can be a large fraction of the thing being
# minimised, and no amount of `dpsi → 0` reveals it: the map genuinely has that
# fixed point.
#
# Measured 2026-08-18 on a free-space dipolar droplet (`runs/yls_barnett_f6/`):
# contact +31340 against DDI −37608 for a net −6268. At dt = 2e-3 the ITP fixed
# point sat 26 % high in energy — ABOVE the energy of its own seed — and 44 % low
# in peak density, while reporting dpsi = 3e-6, and it was grid-independent to
# 0.4 % and box-independent to 2 %. Every convergence indicator except dt was
# clean, so a grid+box convergence scan *certifies* the wrong answer. L-BFGS on
# `energy_gradient!` gave the published value to 2.2 %. Starting ITP AT the L-BFGS
# stationary point, it drifts away with |dE|/t = 177 / 128 / 16.8 / 0.53 at
# dt = 4e-3 / 2e-3 / 5e-4 / 1.25e-4 — O(dt^≈2.5), i.e. a splitting artifact and not
# a propagator/energy mismatch.
#
# The diagnostic is therefore the CANCELLATION RATIO, not the absence of a trap:
#
#     R = |E_total| / Σ_terms |E_term|
#
# Calibrated on both sides of the known behaviour
# (`runs/yls_barnett_f6/g_calibrate_stiffness_ratio.jl`):
#
#   free-space droplets, where ITP is measurably wrong : R = 0.0038 … 0.0118
#   harmonic trap, where ITP and L-BFGS agree to ~1e-6 : R = 0.678 … 1.000
#
# — a 57× gap. `ITP_CANCELLATION_WARN` sits inside it with ≥4× margin on both
# sides. Gating on R rather than on `potential isa NoPotential` is deliberate: a
# dipolar droplet held in a trap is stiff too, and would be missed by a
# free-space test; conversely a trapped gas with strong DDI (R = 0.68) is fine and
# must not be warned about.
#
# This is an advisory, not an automatic switch — same precedent as the secular-DDI
# advisory in `make_workspace`. ITP in this regime is still the right tool if the
# caller converges dt; what must not happen is trusting it silently.
export itp_cancellation_ratio, ITP_CANCELLATION_WARN

const ITP_CANCELLATION_WARN = 0.05

"""
    itp_cancellation_ratio(ws) → Float64

`|E_total| / Σ_terms |E_term|` for the workspace's current state: how much of the
energy survives the cancellation between terms. Small means the ground-state
energy is a small difference of large numbers, where the finite-dt ITP fixed point
is displaced by an amount comparable to the residual itself.

Returns `NaN` when every term is zero (nothing to cancel).
"""
function itp_cancellation_ratio(ws)
    e = energy_decomposition(ws)
    s = 0.0
    for (k, v) in pairs(e)
        k === :total && continue      # the only aggregate field; the rest are disjoint
        v isa Number && (s += abs(Float64(v)))
    end
    s > 0 ? abs(Float64(e.total)) / s : NaN
end

# Kept out of the loop body (runs once per ITP call) and `@noinline` so no part of
# the NamedTuple iteration can widen inference on a Workspace path.
@noinline function _warn_if_itp_is_dt_limited(ws, dt, verbose::Bool)
    R = itp_cancellation_ratio(ws)
    (isnan(R) || R >= ITP_CANCELLATION_WARN) && return R
    @warn """
    ITP fixed point is likely displaced by dt in this regime.
    Cancellation ratio R = |E_total|/Σ|E_term| = $(round(R; sigdigits=3)) < \
    $(ITP_CANCELLATION_WARN): the energy being minimised is a small residual of \
    much larger terms, so the O(dt^p) splitting error can be a large fraction of \
    it — and `dpsi → 0` will NOT reveal that, nor will a grid or box convergence \
    scan (measured: grid-independent to 0.4 %, box-independent to 2 %, and 44 % \
    wrong in peak density). Either pass `method=:lbfgs`, which minimises the \
    energy gradient directly, or converge dt explicitly and quote the dt you \
    converged to. See the note above `ITP_CANCELLATION_WARN` in \
    src/solvers/ground_state/itp_loop.jl.""" dt R maxlog=1
    R
end

# --- Core ITP loop (interrupt-safe, checkpoint-capable) ---

function _run_itp_loop!(
    ws, n_steps, tol, on_step, target_magnetization;
    tol_drho::Float64=0.0,   # 0.0 = ignore the drho gate; >0 = ALSO require drho < tol_drho
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

    # Fires once, on the seed, before any propagation: the caller needs to know
    # the answer will be dt-limited BEFORE spending the run, not after.
    _warn_if_itp_is_dt_limited(ws, sp.dt, verbose)

    E_prev = total_energy(ws)
    converged = false
    psi_prev = copy(ws.state.psi)
    final_dE = NaN
    final_drho = NaN
    final_dpsi = NaN
    last_step = start_step
    t_start = time_ns()

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
        apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp_ws, N_dim,
            ws.grid.config.box_size)
    end

    # Open: V(dt/2)
    _outer_potential_fwd!(ws, dt / 4, n_comp_ws, N_dim, it)
    _ddi_step!(ws, dt / 2, N_dim, it)
    _outer_potential_bwd!(ws, dt / 4, n_comp_ws, N_dim, it)

    try
        for step in (start_step + 1):n_steps
            on_step !== nothing && on_step(ws, step, n_steps)

            if DEALIAS_2_3_ENABLED[]
                apply_orszag_2_3_filter!(ws.state.psi, ws.fft_plans, n_comp_ws, N_dim,
                    ws.grid.config.box_size)
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
                dE = _relative_energy_change(E, E_prev)

                # drho = max_r |ρ(r,now) - ρ(r,prev)| / max_r ρ(r,now)
                # where ρ(r) = Σ_c |ψ_c(r)|² is the total density.
                # Gauge-invariant under U(1) global phase AND spin rotations
                # around z — eliminates the gauge-orbit drift that the
                # wavefunction-based dpsi confuses with non-convergence.
                # GPU-compatible: broadcasting + reductions only, no scalar
                # indexing on the device array.
                psi_now = ws.state.psi
                rho_now = dropdims(sum(abs2, psi_now; dims=N_dim+1); dims=N_dim+1)
                rho_prev_arr = dropdims(sum(abs2, psi_prev; dims=N_dim+1); dims=N_dim+1)
                rho_max = Float64(maximum(rho_now))
                drho_max = Float64(maximum(abs.(rho_now .- rho_prev_arr)))
                drho = rho_max > 0 ? drho_max / rho_max : 0.0

                # Also keep dpsi available for diagnostic logging; uses
                # psi_prev as scratch (destructive). Comes AFTER drho.
                psi_max = maximum(abs, psi_now)
                dpsi = if psi_max > 0
                    psi_prev .= psi_now .- psi_prev
                    maximum(abs, psi_prev) / psi_max
                else
                    0.0
                end
                copyto!(psi_prev, psi_now)
                final_dE = dE
                final_drho = drho
                final_dpsi = dpsi

                if verbose
                    elapsed = elapsed_s(t_start)
                    frac = step / n_steps
                    eta = frac > 0 ? elapsed / frac * (1 - frac) : NaN
                    println(
                        "  ITP $(step)/$(n_steps) | E=$(round(E; sigdigits=8)) dE/|E|=$(round(dE; sigdigits=3)) " *
                        "drho=$(round(drho; sigdigits=3)) dpsi=$(round(dpsi; sigdigits=3)) " *
                        "| $(round(elapsed; digits=1))s elapsed, ETA $(round(eta; digits=0))s",
                    )
                    flush(stdout)
                end

                # Convergence requires dE/|E| < tol; if tol_drho>0, ALSO
                # require the per-(save_every) DENSITY change to be below
                # the grid-error scale. ρ is U(1)/spin-rotation invariant,
                # so gauge-orbit drift in ψ does not affect drho.
                if dE < tol && (tol_drho <= 0.0 || drho < tol_drho)
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
