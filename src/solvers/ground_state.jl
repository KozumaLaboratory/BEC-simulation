export find_ground_state

const _ITP_EXPONENT_LIMIT = 50.0
const _ITP_DDI_WARN_EXPONENT = 20.0

function _check_itp_overflow(ws, step::Int)
    if any(isnan, ws.state.psi)
        throw(
            ArgumentError(
                "NaN detected in ITP at step $step. " *
                "Likely DDI potential overflow. Reduce dt.",
            ),
        )
    end
    ws.ddi === nothing && return nothing
    bufs = ws.ddi_bufs
    phi_max = max(maximum(abs, bufs.Phi_x), maximum(abs, bufs.Phi_y), maximum(abs, bufs.Phi_z))
    dt = ws.sim_params.dt
    exponent = phi_max * dt / 2
    if exponent > _ITP_EXPONENT_LIMIT
        throw(
            ArgumentError(
                "DDI potential overflow in ITP at step $step: " *
                "max|Φ|=$(round(phi_max, sigdigits=3)), " *
                "exponent=$(round(exponent, digits=1)) > $_ITP_EXPONENT_LIMIT. " *
                "Reduce dt (current=$dt).",
            ),
        )
    end
    nothing
end

function _validate_itp_zeeman(zeeman::ZeemanParams, F, dt)
    sys = SpinSystem(F)
    max_zee = maximum(abs, zeeman_energies(zeeman, sys))
    max_exponent = max_zee * dt / 4
    if max_exponent > _ITP_EXPONENT_LIMIT
        throw(
            ArgumentError(
                "Zeeman p=$(zeeman.p) with F=$F and dt=$dt causes overflow in imaginary time " *
                "(exponent=$(round(max_exponent, digits=1)) > $_ITP_EXPONENT_LIMIT). " *
                "Reduce p or dt. For ferromagnetic ground state, p=10 suffices.",
            ),
        )
    end
end

_validate_itp_zeeman(::TimeDependentZeeman, F, dt) = nothing

function _validate_itp_interactions(
    interactions::InteractionParams,
    F,
    dt;
    psi=nothing,
    c_dd::Float64=0.0,
)
    n_peak = if psi !== nothing
        ndim = ndims(psi) - 1
        Float64(maximum(total_density(psi, ndim)))
    else
        1.0
    end

    max_c = max(abs(interactions.c0), abs(interactions.c1))
    if max_c > 1e-30
        max_exponent = max_c * n_peak * dt / 4
        if max_exponent > _ITP_EXPONENT_LIMIT
            throw(
                ArgumentError(
                    "Spin interaction c0=$(interactions.c0), c1=$(interactions.c1) with " *
                    "n_peak≈$(round(n_peak, sigdigits=3)) and dt=$dt " *
                    "may cause overflow in imaginary time (estimated exponent=$(round(max_exponent, digits=1)) " *
                    "> $_ITP_EXPONENT_LIMIT). Reduce c0/c1 magnitude or dt.",
                ),
            )
        end
    end

    if c_dd > 0
        ddi_exponent = c_dd * F * n_peak * dt / 2
        if ddi_exponent > _ITP_EXPONENT_LIMIT
            throw(
                ArgumentError(
                    "DDI c_dd=$c_dd with F=$F, n_peak≈$(round(n_peak, sigdigits=3)) and dt=$dt " *
                    "may cause overflow in imaginary time (estimated exponent=$(round(ddi_exponent, digits=1)) " *
                    "> $_ITP_EXPONENT_LIMIT). Reduce c_dd or dt.",
                ),
            )
        end
    end
end

function find_ground_state(;
    grid,
    atom,
    interactions,
    zeeman=ZeemanParams(),
    potential=NoPotential(),
    dt=0.001,
    n_steps=10000,
    tol=1e-10,
    initial_state=:polar,
    init_state_params::Dict{Symbol, Float64}=Dict{Symbol, Float64}(),
    psi_init=nothing,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    secular_ddi::Bool=false,
    adaptive_dt::Bool=false,
    dt_max::Float64=10.0 * dt,
    fft_flags=FFTW.MEASURE,
    target_magnetization::Union{Nothing, Float64}=nothing,
    rotating_frame_omega::Float64=0.0,
    target_Jz::Union{Nothing, Float64}=nothing,
    Jz_tol::Float64=0.01,
    Jz_max_iter::Int=20,
    Jz_omega_range::Tuple{Float64, Float64}=(-5.0, 5.0),
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::AbstractBackend=CPUBackend(),
    on_step::Union{Nothing, Function}=nothing,  # (ws, step, n_steps) → update ws params
    checkpoint_dir::Union{Nothing, String}=nothing,
    checkpoint_every::Int=0,
    _start_step::Int=0,        # internal: for resume
    _checkpoint_dir::Union{Nothing, String}=nothing,  # internal alias
    _checkpoint_every::Int=0,   # internal alias
    light_shift::Union{Nothing, LightShift}=nothing,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
    spinor_lhy::Union{Nothing, Symbol}=nothing,
    method::Symbol=:strang,
    verbose::Bool=_default_solver_verbose(),
)
    method === :strang || throw(
        ArgumentError(
            "find_ground_state currently supports method=:strang only " *
            "(got :$method). The :sc4 path was disabled pending verified " *
            "complex-coefficient symmetric-conjugate weights — see " *
            "src/solvers/embedded_adaptive.jl for the design note."),
    )

    psi0 = if psi_init === nothing
        sys = SpinSystem(atom.F)
        init_kwargs = pairs(init_state_params)
        init_psi(grid, sys; state=initial_state, dtype=dtype, init_kwargs...)
    else
        copy(psi_init)
    end

    # F32 unit roundoff is ~1.2e-7, so requesting tol=1e-10 will never converge.
    # Cap at 1e-6 and warn, so users get a sensible default when they flip dtype
    # without rethinking tolerances.
    T_effective = dtype === nothing ? eltype(grid.x[1]) : dtype
    if T_effective === Float32 && tol < 1.0e-6
        @warn "Relaxing ITP tol $tol → 1e-6 for Float32 (unit roundoff ~1.2e-7)." maxlog=1
        tol = 1.0e-6
    end

    if target_Jz !== nothing
        N_dim = length(grid.config.n_points)
        N_dim >= 2 || throw(
            ArgumentError(
                "target_Jz requires N ≥ 2 (need orbital angular momentum). Got N=$N_dim."
            ),
        )
        return _find_ground_state_Jz(;
            grid,
            atom,
            interactions,
            zeeman,
            potential,
            dt,
            n_steps,
            tol,
            initial_state,
            psi_init=psi0,
            enable_ddi,
            c_dd,
            secular_ddi,
            adaptive_dt,
            dt_max,
            fft_flags,
            target_magnetization,
            target_Jz,
            Jz_tol,
            Jz_max_iter,
            Jz_omega_range,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
        )
    end

    _validate_itp_zeeman(zeeman, atom.F, dt)
    effective_c_dd = (enable_ddi && !isnan(c_dd)) ? c_dd : 0.0
    _validate_itp_interactions(interactions, atom.F, dt; psi=psi0, c_dd=effective_c_dd)

    if adaptive_dt
        return _find_ground_state_adaptive(;
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
            secular_ddi,
            dt_max,
            fft_flags,
            rotating_frame_omega,
            quasi_2d_ddi,
            l_z_ddi,
            quasi_2d,
            l_z,
            backend,
            light_shift,
            verbose,
        )
    end

    use_constrained = target_magnetization !== nothing
    norm_every = use_constrained ? 0 : 1
    sp = SimParams(;
        dt,
        n_steps,
        imaginary_time=true,
        normalize_every=norm_every,
        save_every=max(1, n_steps ÷ 100),
        rotating_frame_omega,
    )
    ws = make_workspace(;
        grid,
        atom,
        interactions,
        zeeman,
        potential,
        sim_params=sp,
        psi_init=psi0,
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
        dtype=dtype,
        spinor_lhy,
    )

    n_comp = ws.spin_matrices.system.n_components
    N_dim = length(grid.config.n_points)

    if use_constrained
        _normalize_psi_constrained!(
            ws.state.psi,
            ws.grid,
            n_comp,
            N_dim,
            target_magnetization,
            atom.F,
        )
    end

    ckpt_dir = checkpoint_dir !== nothing ? checkpoint_dir : _checkpoint_dir
    ckpt_every = checkpoint_every > 0 ? checkpoint_every : _checkpoint_every

    _run_itp_loop!(ws, n_steps, tol, on_step, target_magnetization;
        start_step=_start_step,
        checkpoint_dir=ckpt_dir,
        checkpoint_every=ckpt_every,
        verbose=verbose,
    )
end
