# --- Workspace factory: make_workspace + _rebuild_workspace ---
#
# Assembles a ready-to-run Workspace{...23 type params...} from grid + atom
# + interactions + zeeman + potential + sim_params. Includes the LHY
# dispatch (two_channel / full_bdg / scalar fallback) and DDI buffer
# allocation. The companion `_rebuild_workspace` lets callers swap one
# field (e.g. dt) without re-allocating the whole struct.

export make_workspace, LHYTableOpts

# Kwarg names accepted by `make_workspace`. Grouped semantically for
# documentation and for the kwarg-coverage regression test
# (`test_make_workspace_kwarg_coverage`). When you add a new kwarg to
# `make_workspace`, add it here too; the test fails otherwise.
const _MAKE_WORKSPACE_KWARGS = (
    # Required physics core
    :grid, :atom, :interactions, :sim_params,
    # Optional physics terms
    :zeeman, :potential, :raman, :loss, :light_shift,
    :magnetic_gradient, :spatial_zeeman, :time_dep_interactions, :absorbing_boundary,
    # DDI bundle
    :enable_ddi, :c_dd, :secular_ddi, :quasi_2d_ddi, :l_z_ddi, :ddi_padding,
    :ddi_trunc_radius, :ddi_pad_factor,
    # Quasi-2D bundle
    :quasi_2d, :l_z,
    # LHY dispatch
    :spinor_lhy, :lhy_opts,
    # Runtime / backend
    :backend, :fft_flags, :dtype, :psi_init,
)

"""
    LHYTableOpts(; n_max=NaN, n_points=200, n_bins=12)

Table-resolution knobs for the spinor LHY builders, carried as ONE concrete
struct rather than three loose kwargs — `make_workspace` is the inference hot
path, and every widened kwarg there is paid for in `Workspace` specialisation.

- `n_max` — top of the density grid. `NaN` (default) means `3 × max|ψ_init|²`.
- `n_points` — density nodes, for the `n`-tabulated modes.
- `n_bins` — polarisation bins, for `:spatial` only (one BdG solve per occupied
  bin, so it is a cost knob, not a resolution knob in the same sense).

`lhy: {n_max, n_points}` has been in `LHY_SCHEMA` since the C6 block landed but
was read by nothing: `_resolve_lhy_block!` normalised only `kind` and `c_lhy`,
and `_build_spinor_lhy` hard-coded `n_max=_lhy_n_max(psi_init)` while letting
`n_points` fall to each builder's own default. A user writing `n_points: 4000`
got 200 and no warning. This struct is what carries them.
"""
struct LHYTableOpts
    n_max::Float64
    n_points::Int
    n_bins::Int
    n_atoms::Int
end
LHYTableOpts(; n_max::Float64=NaN, n_points::Int=200, n_bins::Int=12,
    n_atoms::Int=1) = LHYTableOpts(n_max, n_points, n_bins, n_atoms)

function make_workspace(;
    grid::Grid{N, T},
    atom::AtomSpecies,
    interactions::InteractionParams,
    zeeman::Union{ZeemanParams, TimeDependentZeeman, ZeemanField}=ZeemanParams(),
    potential::AbstractPotential=NoPotential(),
    sim_params::SimParams,
    psi_init::Union{Nothing, AbstractArray{<:Complex}}=nothing,
    enable_ddi::Bool=false,
    c_dd::Float64=NaN,
    secular_ddi::Bool=false,
    raman::Union{Nothing, RamanCoupling{N}, TimeDependentRaman{N}}=nothing,
    loss::Union{Nothing, LossParams}=nothing,
    fft_flags=FFTW.MEASURE,
    # Deliberately OFF here while the YAML/DSL surface defaults them ON
    # (`DDI_PADDED_DEFAULT` / `DDI_TRUNC_RADIUS_DEFAULT` in
    # schema/parsing_blocks.jl). This is the library primitive — every knob is
    # explicit, and flipping it would silently change every direct-call test and
    # A/B fixture. Callers building a workspace by hand for production physics
    # want `ddi_padding=true, ddi_trunc_radius=-1.0`: without them the bare
    # periodic kernel carries a 2-5% dipolar field error that is flat in
    # resolution (scripts/ddi_cutoff_geometry_jz_probe.jl).
    ddi_padding::Bool=false,
    ddi_trunc_radius::Float64=NaN,
    ddi_pad_factor::Union{Real, NTuple{N, Real}}=2,
    quasi_2d_ddi::Bool=false,
    l_z_ddi::Float64=0.0,
    quasi_2d::Bool=false,
    l_z::Float64=0.0,
    backend::Union{Nothing, AbstractBackend}=nothing,
    spinor_lhy::Union{Nothing, Symbol}=nothing,
    lhy_opts::LHYTableOpts=LHYTableOpts(),
    absorbing_boundary::Union{Nothing, AbsorbingBoundary}=nothing,
    light_shift::Union{Nothing, LightShift}=nothing,
    time_dep_interactions::Union{Nothing, TimeDependentInteractions}=nothing,
    magnetic_gradient::Union{Nothing, MagneticGradient, TimeDependentMagneticGradient}=nothing,
    spatial_zeeman::Union{Nothing, SpatialZeemanField}=nothing,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    U === T || throw(
        ArgumentError(
            "dtype=$U disagrees with grid eltype=$T. Build the grid with `make_grid(cfg; dtype=$U)` first."
        ),
    )
    backend = _resolve_backend(backend, grid)
    # Fold the legacy zeeman / spatial_zeeman inputs into the one unified field.
    zfield = _to_zeeman_field(zeeman, spatial_zeeman)
    if !is_uniform(zfield)
        backend isa CPUBackend || throw(
            ArgumentError(
                "a spatial Zeeman field B(r,t) has a CPU-only per-voxel propagator; " *
                "run on a CPU backend"),
        )
        is_active(sim_params.spin_rotating_frame_omega, ROTATION_TOL) && throw(
            ArgumentError(
                "a spatial Zeeman field is not supported together with a spin-rotating " *
                "frame (spin_rotating_frame_omega ≠ 0) in v1"),
        )
    end
    if quasi_2d
        N == 2 || throw(ArgumentError("quasi_2d requires 2D grid, got $(N)D"))
        l_z > 0 || throw(ArgumentError("quasi_2d requires l_z > 0"))
    end

    effective_interactions =
        quasi_2d ? scale_interactions_quasi_2d(interactions, l_z) : interactions

    if quasi_2d && enable_ddi
        quasi_2d_ddi = true
        l_z_ddi == 0.0 && (l_z_ddi = l_z)
    end

    sys = SpinSystem(atom.F)
    sm = spin_matrices(atom.F)

    # The spinor dimension is set by the ATOM's F; a psi_init with the wrong
    # component count (or spatial shape) otherwise segfaults later in the
    # diagonal / spin steps reading past the array. Fail loudly here instead.
    if psi_init !== nothing
        ndims(psi_init) == N + 1 || throw(
            ArgumentError(
                "psi_init has $(ndims(psi_init)) dims; expected $(N + 1) " *
                "($(N) spatial + 1 spin) for this grid"),
        )
        size(psi_init, N + 1) == sys.n_components || throw(
            ArgumentError(
                "psi_init has $(size(psi_init, N + 1)) spin components but atom " *
                "$(atom.name) (F=$(atom.F)) needs $(sys.n_components); pass a state " *
                "matching the atom's F"),
        )
        ntuple(d -> size(psi_init, d), N) == grid.config.n_points || throw(
            ArgumentError(
                "psi_init spatial size $(ntuple(d -> size(psi_init, d), N)) ≠ grid " *
                "$(grid.config.n_points)"),
        )
    end

    psi = if psi_init === nothing
        init_psi(grid, sys; dtype=U)
    else
        eltype(psi_init) === Complex{U} ? copy(psi_init) : Complex{U}.(psi_init)
    end
    psi = _to_device(backend, psi)

    fft_buf = _zeros(backend, Complex{U}, grid.config.n_points...)
    # Scratch buffer with same shape + device + eltype as psi — used by
    # apply_uniform_spin_rotation! and any other whole-ψ broadcast op that
    # would otherwise allocate similar(psi) per call.
    psi_scratch = similar(psi)
    state = SimState{N, typeof(psi), typeof(fft_buf)}(psi, fft_buf, psi_scratch, 0.0, 0)

    plans = make_fft_plans(grid.config.n_points, backend; flags=fft_flags, dtype=U)
    kinetic_phase = _to_device(
        backend,
        prepare_kinetic_phase(
            grid,
            sim_params.dt;
            imaginary_time=sim_params.imaginary_time,
            dtype=U,
        ),
    )
    V = evaluate_potential(potential, grid)

    omega = sim_params.rotating_frame_omega
    if is_active(omega, ROTATION_TOL) && N >= 2
        # Rotating-frame Hamiltonian: H_rot = H_lab − Ω L_z. Completing
        # the square in (p − mΩ×r) gives the centrifugal term
        # −(1/2)Ω²r_⊥² **subtracted** from the trap (so the effective
        # transverse confinement is ω_eff² = ω_⊥² − Ω², deconfining at
        # the centrifugal limit Ω → ω_⊥). The previous `V[I] +=` form
        # had the wrong sign and over-confined any rotating-frame ITP /
        # RTP, biasing FL / cyclic / vortex-lattice scans where Ω
        # approaches a non-trivial fraction of ω_⊥. Fixed 2026-04-27
        # after code review caught it. (Dy Innsbruck 2022 lab-frame magnetostir
        # runs with rotating_frame_omega = 0 are unaffected.)
        omega_sq_half = U(0.5 * omega^2)
        @inbounds for I in CartesianIndices(grid.config.n_points)
            r_perp_sq = grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2
            V[I] -= omega_sq_half * r_perp_sq
        end
    end
    V = _to_device(backend, V)

    effective_zeeman = if is_active(omega, ROTATION_TOL)
        _shift_zeeman_for_rotating_frame(zfield, omega)
    else
        zfield
    end

    # Resolve the DDI spherical-truncation radius (Ronen cutoff).
    #   NaN  ⇒ off (bare periodic kernel; backward-compatible default).
    #   > 0  ⇒ explicit physical radius (used as-is for both paths).
    #   ≤ 0  ⇒ auto, geometry-dependent:
    #     · un-padded (Tier A): half the smallest box extent — the largest R
    #       that avoids wrap-around in the periodic (un-padded) convolution.
    #     · padded (Tier B): the box diagonal, capped per axis at
    #       (pad_factor_d − 1)·L_d — the largest R the zero-pad can hold
    #       without wrap-around (validated: exceeding it re-introduces images).
    box = ntuple(d -> grid.config.n_points[d] * grid.dx[d], N)
    # A negative scalar is the `pad_factor: auto` sentinel — size the padding so
    # the cutoff can reach `max(box)` instead of being capped by the short axis.
    pf_t = if ddi_pad_factor isa Real && ddi_pad_factor < 0
        auto_ddi_pad_factor(box)
    elseif ddi_pad_factor isa Real
        ntuple(_ -> Float64(ddi_pad_factor), N)
    else
        ntuple(d -> Float64(ddi_pad_factor[d]), N)
    end
    ddi_trunc = if isnan(ddi_trunc_radius)
        nothing
    elseif ddi_trunc_radius <= 0.0
        auto_ddi_trunc_radius(box)
    else
        ddi_trunc_radius
    end
    ddi_trunc_pad = if isnan(ddi_trunc_radius)
        nothing
    elseif ddi_trunc_radius <= 0.0
        auto_ddi_trunc_radius(box, pf_t)
    else
        ddi_trunc_radius
    end

    ddi = if enable_ddi
        if isnan(c_dd) && atom.mu_mag > 0.0
            throw(
                ArgumentError(
                    "enable_ddi=true for dipolar atom $(atom.name) but c_dd not specified. " *
                    "compute_c_dd(atom) returns SI units which are incompatible with dimensionless grids. " *
                    "Pass c_dd in dimensionless units: c_dd = N × μ₀μ² / (ℏω × a_ho³). " *
                    "See compute_c_dd_dimless().",
                ),
            )
        end
        c_dd_val = isnan(c_dd) ? compute_c_dd(atom) : c_dd

        # Spin rotating-frame correctness guard: the rotating-basis frame is
        # built around z, so off-diagonal DDI components rotate at ω_R and
        # average to zero only in the secular limit. With a non-zero
        # spin_rotating_frame_omega and full (non-secular) DDI, the chosen
        # propagator silently violates rotating-frame consistency.
        if is_active(sim_params.spin_rotating_frame_omega, ROTATION_TOL) && !secular_ddi
            throw(
                ArgumentError(
                    "spin_rotating_frame_omega = $(sim_params.spin_rotating_frame_omega) ≠ 0 " *
                    "with non-secular DDI: the rotating frame relies on Larmor-averaging " *
                    "off-diagonal DDI components. Pass `secular_ddi=true` to make_workspace, " *
                    "or set spin_rotating_frame_omega=0 to use the lab-frame full DDI.",
                ),
            )
        end

        # Larmor regime advisory: when ω_L (= p_zeeman, dimensionless) ≫
        # c_dd × n_peak, the Larmor cycle averages off-diagonal DDI to zero,
        # and the secular kernel is the appropriate choice. Most Eu151
        # experiments live deep in this regime (ω_L ~ kHz, c_dd × n ~ Hz).
        # Only @info, not error: the user may intentionally want the full
        # kernel to study transverse Larmor-coherent dynamics.
        p_now = linear_p(zfield)   # uniform arm → bz; spatial arm → 0 (advisory only)
        if !secular_ddi && is_active(p_now, ROTATION_TOL) && is_active(c_dd_val)
            n_peak_est =
                sum(abs2, _to_host(psi)) / cell_volume(grid) /
                max(1, prod(grid.config.n_points))  # rough mean → upper bound on n_peak
            larmor_ratio = abs(p_now) / max(c_dd_val * n_peak_est, 1e-30)
            if larmor_ratio > 100.0
                @info "DDI Larmor regime: ω_L / (c_dd · ⟨n⟩) ≈ $(round(larmor_ratio; sigdigits=3)). " *
                    "Consider `secular_ddi=true` (faster + more physical for ω_L ≫ c_dd·n)."
            end
        end

        ddi_params_cpu = make_ddi_params(
            grid,
            atom;
            c_dd=c_dd_val,
            secular=secular_ddi,
            quasi_2d=quasi_2d_ddi,
            l_z=l_z_ddi,
            trunc_radius=ddi_trunc,
            dtype=U,
        )
        _ddi_params_to_device(ddi_params_cpu, backend)
    else
        nothing
    end

    ddi_bufs = if ddi !== nothing
        make_ddi_buffers(grid.config.n_points, backend; flags=fft_flags, dtype=U)
    else
        nothing
    end

    density_buf = _zeros(backend, U, grid.config.n_points...)

    # `ddi_pad` reuses the already-resolved `ddi.C_dd` (so the un-padded and
    # padded DDI agree on coupling), and only fires when both `ddi_padding`
    # is requested *and* a DDI workspace exists.
    ddi_pad = if (ddi_padding && ddi !== nothing)
        make_ddi_padded(
            grid,
            atom;
            c_dd=ddi.C_dd,
            fft_flags,
            secular=secular_ddi,
            quasi_2d=quasi_2d_ddi,
            l_z=l_z_ddi,
            trunc_radius=ddi_trunc_pad,
            # `pf_t`, not the raw kwarg: the `auto` sentinel is negative and
            # `_padded_grid_size` rejects anything below 1.
            pad_factor=pf_t,
            backend,
            dtype=U,
        )
    else
        nothing
    end

    batched_kinetic = _make_batched_kinetic_cache(psi, kinetic_phase, N, backend; flags=fft_flags)

    F = atom.F
    # Tensor interaction path activation: InteractionParams.c is a
    # Dict{Int,Float64} keyed by rank n. Only even-rank k ∈ {4, 6, ..., 2F}
    # triggers the full tensor_cache, because the 6j transform
    # (_dict_to_delta_gS) maps even-rank c_k to channel g_S.
    #
    # Lower-rank terms are handled by dedicated steps:
    #   k=0 (c₀): diagonal step    k=1 (c₁): spin_mixing step
    #   k=2 (c₂): singlet_pair step (S=0 pair channel)
    #   k=3: rejected (odd rank; InteractionParams constructor catches this)
    #
    # Kawaguchi-Ueda c₃ Σ_M|A₂M|² is a S=2 pair-channel coupling, NOT a
    # rank-3 tensor — use _make_tensor_cache_from_channels(F, g_S) for it.
    has_higher_rank = any(
        k -> iseven(k) && k >= 4 && k <= 2F &&
             is_active(get(effective_interactions.c, k, 0.0)),
        keys(effective_interactions.c),
    )

    tensor_cache, ws_interactions = if has_higher_rank
        g_delta = _dict_to_delta_gS(F, effective_interactions.c)
        tc = _make_tensor_cache_from_channels(F, g_delta)
        tc,
        InteractionParams(
            Dict(0 => effective_interactions[0],
                1 => effective_interactions[1]);
            c_lhy=effective_interactions.c_lhy,
        )
    else
        tc = make_tensor_interaction_cache(F, effective_interactions)
        if tc !== nothing &&
            (is_active(effective_interactions[0]) ||
            is_active(effective_interactions[1]))
            throw(
                ArgumentError(
                    "tensor_cache active with non-zero c0=$(effective_interactions[0]), c1=$(effective_interactions[1]). " *
                    "When tensor_cache handles all channels, set c0=c1=0 in InteractionParams " *
                    "to avoid double-counting (diagonal step still uses c0, tensor step includes c0+c1).",
                ),
            )
        end
        tc, effective_interactions
    end

    coriolis_cache = if sim_params.rotating_frame_omega != 0.0 && N >= 2
        _make_coriolis_cache(psi, backend; flags=fft_flags)
    else
        nothing
    end

    lhy_attempt =
        if spinor_lhy === nothing || spinor_lhy === :none
            nothing
        else
            _build_spinor_lhy(Val(spinor_lhy), atom, ws_interactions, psi_init,
                c_dd, enable_ddi, lhy_opts)
        end

    # Silent-zero defense (2026-05-26): when the user explicitly requested
    # a non-scalar spinor LHY mode and the builder returned `nothing`, the
    # historical fall-through hid the failure — the run would produce
    # results as if LHY were off, but with the user thinking it was on.
    # `:scalar` / `:quasi_2d` legitimately fall through to the
    # `c_lhy` branch below; everything else must build.
    if spinor_lhy !== nothing && spinor_lhy !== :none &&
        spinor_lhy !== :scalar && spinor_lhy !== :quasi_2d &&
        lhy_attempt === nothing
        throw(
            ArgumentError(
                "spinor_lhy=:$(spinor_lhy) requested but the LHY builder " *
                "returned `nothing`. Either the kind is unimplemented " *
                "(no `_build_spinor_lhy(::Val{:$(spinor_lhy)}, ...)` method) " *
                "or the builder bailed out (check F vs kind restrictions, " *
                "e.g. `:icosahedral` is F=6 only, `:polar_two_channel` is F≤2). " *
                "Refusing silent-zero: dynamics with this LHY block would " *
                "have run as if LHY were off."),
        )
    end

    lhy = if lhy_attempt !== nothing
        lhy_attempt
    elseif quasi_2d && is_active(ws_interactions.c_lhy)
        compute_lhy_2d_params(ws_interactions[0], l_z)
    elseif is_active(ws_interactions.c_lhy)
        ScalarLHY(ws_interactions.c_lhy)
    else
        nothing
    end

    abs_mask = if absorbing_boundary !== nothing
        compute_absorbing_mask(grid, absorbing_boundary, sim_params.dt, backend; dtype=U)
    else
        nothing
    end

    # Ensure LightShift.profile lives on the same device as the workspace
    # arrays. User-constructed `LightShift(host_profile, ...)` would otherwise
    # leave a `Vector{Float64}` host array inside a CuArray broadcast
    # (`_diagonal_step_with_ls!` at propagators.jl:385/396) and the GPU kernel
    # compilation fails with KernelError: passing non-bitstype argument.
    # The `make_light_shift_*` constructors already do this transfer; this
    # catches direct `LightShift(...)` invocations.
    light_shift_resolved = if light_shift !== nothing && !(backend isa CPUBackend)
        LightShift(
            _to_device(backend, light_shift.profile),
            light_shift.eigvals,
            light_shift.U,
            light_shift.is_diagonal,
        )
    else
        light_shift
    end

    Workspace(
        state,
        plans,
        kinetic_phase,
        V,
        density_buf,
        sm,
        grid,
        atom,
        ws_interactions,
        effective_zeeman,
        potential,
        sim_params,
        ddi,
        ddi_bufs,
        raman,
        loss,
        ddi_pad,
        batched_kinetic,
        tensor_cache,
        coriolis_cache,
        backend,
        lhy,
        abs_mask,
        light_shift_resolved,
        time_dep_interactions,
        magnetic_gradient,
    )
end

"""
    _rebuild_workspace(ws; field=value, ...)

Create a new Workspace by copying all fields from `ws`, overriding specified fields.
Avoids fragile positional constructor calls when Workspace gains new fields.
"""
function _rebuild_workspace(ws::Workspace; kwargs...)
    names = fieldnames(Workspace)
    override = Dict{Symbol, Any}(kwargs)
    args = [haskey(override, n) ? override[n] : getfield(ws, n) for n in names]
    Workspace(args...)
end

# Rotating-frame Zeeman absorbs the Barnett −Ω·F_z into an effective linear
# coefficient. With Zeeman convention H_Zee = −p·F_z, the rotating-frame
# Hamiltonian H_rot = H_lab − Ω(L_z + F_z) corresponds to
#   effective_p = z.p + Ω      (so that −effective_p·F_z = −z.p·F_z − Ω·F_z)
# i.e. the user passes the *lab-frame* p (z.p = p_lab) and the workspace
# adds the Barnett term automatically.
#
# (Pre-2026-06-02 the sign was `z.p − omega`, which silently *cancelled*
# the Barnett term instead of installing it. Caught by sprint5_M1_barnett_test
# at B = 0 — Barnett response only appeared when the script over-corrected
# with `p_input = p_lab + 2Ω`. See `mistake_frame_transformation_half_term_silent_cancellation`.)
_shift_zeeman_for_rotating_frame(z::ZeemanParams, omega::Float64) = ZeemanParams(z.p + omega, z.q)

# Use the concrete `ShiftedWaveform{typeof(z.p_wf)}` rather than wrapping
# in `FunctionWaveform(t -> ...)`. Each closure-based call leaked a fresh
# anonymous-function type into the per-step `evaluate` dispatch table;
# `ShiftedWaveform` keeps that static. (The narrowed concrete-type
# annotation also lets the optimiser specialise `evaluate(p_wf, t)` —
# see CLAUDE.md "Type stability boundaries".)
function _shift_zeeman_for_rotating_frame(z::TimeDependentZeeman, omega::Float64)
    TimeDependentZeeman(ShiftedWaveform(z.p_wf, -omega), z.q_wf, z.bx_wf, z.by_wf)
end

# Barnett shift on the unified uniform arm: effective bz(t) = bz(t) + Ω. Shift
# the static baseline when bz has no waveform, else the bz waveform (mirrors the
# ZeemanParams / TimeDependentZeeman variants above). Spatial arms + rotating
# frame are rejected upstream, so only the uniform arm needs this.
function _shift_zeeman_for_rotating_frame(f::ZeemanField{Nothing}, omega::Float64)
    sc, wf = f.scalars, f.waveforms
    if wf[3] === nothing
        ZeemanField{Nothing}((sc[1], sc[2], sc[3] + omega, sc[4]), nothing, wf)
    else
        ZeemanField{Nothing}(
            sc, nothing, (wf[1], wf[2], ShiftedWaveform(wf[3], -omega), wf[4]))
    end
end

# --- input → unified ZeemanField converter ---------------------------------
#
# make_workspace accepts the legacy `zeeman` (ZeemanParams / TimeDependentZeeman)
# and `spatial_zeeman` (SpatialZeemanField) inputs, or a ZeemanField directly,
# and folds them into the ONE field the Workspace stores. v1 forbids a uniform
# `zeeman` and a `spatial_zeeman` at once (a uniform offset on a gradient is
# expressible via `quadrupole_field(bias=…)`).
_uniform_zeeman_field(z::ZeemanParams) = ZeemanField{Nothing}(
    (0.0, 0.0, z.p, z.q), nothing, (nothing, nothing, nothing, nothing))
_uniform_zeeman_field(z::TimeDependentZeeman) = ZeemanField{Nothing}(
    (0.0, 0.0, 0.0, 0.0), nothing, (z.bx_wf, z.by_wf, z.p_wf, z.q_wf))

function _spatial_zeeman_field_unify(s::SpatialZeemanField)
    profiles = (s.bx, s.by, s.bz, s.q)
    ZeemanField{typeof(profiles)}(
        (0.0, 0.0, 0.0, 0.0), profiles, (nothing, nothing, nothing, nothing))
end

_is_zero_uniform_zeeman(z::ZeemanParams) = z.p == 0.0 && z.q == 0.0
_is_zero_uniform_zeeman(::TimeDependentZeeman) = false

function _to_zeeman_field(zeeman, spatial_zeeman)
    if spatial_zeeman !== nothing
        _is_zero_uniform_zeeman(zeeman) || throw(
            ArgumentError(
                "uniform `zeeman` and `spatial_zeeman` cannot both be set (v1); " *
                "put a uniform offset into the spatial field, e.g. quadrupole_field(bias=…)."),
        )
        return _spatial_zeeman_field_unify(spatial_zeeman)
    end
    _uniform_zeeman_field(zeeman)
end
# A ZeemanField passed directly (e.g. spatiotemporal_zeeman_field) is used as-is.
function _to_zeeman_field(zeeman::ZeemanField, spatial_zeeman)
    spatial_zeeman === nothing || throw(ArgumentError(
        "pass either a ZeemanField `zeeman` or a `spatial_zeeman`, not both."))
    zeeman
end

# ---------------------------------------------------------------------------
# LHY table builders (Val-dispatched; replaces a 7-way elseif chain that
# duplicated n_max + g_dict construction across every branch).
#
# `_build_spinor_lhy(::Val{:mode}, atom, ws_interactions, psi_init, c_dd,
# enable_ddi)` returns an LHY table for mode `:mode`, or the fallthrough
# `_build_spinor_lhy(::Val, ...)` returns `nothing` (caller falls through to
# the quasi-2D / scalar LHY branches in make_workspace).
# ---------------------------------------------------------------------------

@inline function _lhy_n_max(psi_init)
    psi_init === nothing && return 100.0
    maximum(sum(abs2, psi_init; dims=ndims(psi_init))) * 3.0
end

# An explicit `lhy.n_max` always wins; NaN (the default) means "derive it".
_lhy_n_max(psi_init, opts::LHYTableOpts) =
    isnan(opts.n_max) ? _lhy_n_max(psi_init) : opts.n_max

_lhy_g_dict(atom::AtomSpecies, ws::InteractionParams) = c_to_g(atom.F, ws)

"""
    _lhy_texture_spread(psi_init, F) -> (spread, peak_f, mean_f)

How far the state is from having ONE spinor. Returns the `n^(5/2)`-weighted
spread of `|⟨F⟩|/F` over the cloud (the weight `ε_LHY ∝ n^(5/2)` actually
carries), plus the value at the density peak and the weighted mean.

Every spinor LHY table in this file is built for a single spinor and then
applied at every voxel: `:full_bdg` takes the peak spinor, and the closed forms
assume their own fixed ansatz outright. That is exact when the state is uniform
and an approximation when it is not.

Only the SHAPE of the local spinor matters, not its direction. Measured at F=6:
rotating the spinor leaves ε_LHY invariant to machine precision for contact
(it is an SO(3) scalar) and to 0.25% with the DDI at ε_dd ~ 0.05 — so a pure
direction texture (flower, spin vortex, skyrmion; all `|⟨F⟩|/F` = 1 everywhere)
costs nothing. Varying the MAGNITUDE costs ~20% between `|⟨F⟩|/F` = 1 and 0.
"""
_lhy_texture_spread(::Nothing, ::Int) = (0.0, 1.0, 1.0)

# `Val(N)` comes from the ARRAY'S type parameter, never from `ndims(x)` —
# CLAUDE.md "Type stability boundaries". Taking `N = ndims(psi_init) - 1` as a
# runtime Int made `ntuple(..., N)` uninferrable and the whole function
# returned `Tuple{Any,Any,Any}`, inside `make_workspace`, which is precisely
# the path that documentation warns turns into a multi-minute JIT hang.
function _lhy_texture_spread(psi_init::AbstractArray{<:Complex, M}, F::Int) where {M}
    N = M - 1
    D = size(psi_init, M)
    D == 2F + 1 || return (0.0, 1.0, 1.0)
    n_pts = ntuple(d -> size(psi_init, d), Val(N))

    # SUBSAMPLED on a stride. This is a threshold decision on a smooth field,
    # not a physical observable, and `make_workspace` runs per scan point —
    # CLAUDE.md calls it the hot path for every pipeline step. Full-grid cost
    # was 26% of a 64³ workspace build and 69% of a 32³ one, to answer a
    # yes/no question. The stride targets ~8000 samples, which holds the guard
    # under ~1% while leaving the verdict unchanged on the converged
    # weak-field Eu states it was calibrated on (spread 0.921 either way).
    #
    # `spin_density_vector` is the O(D) ladder form (F± tridiagonal, Fz
    # diagonal), threaded and already gated. Restating it as explicit 13×13
    # matrix-vector products cost 0.31 s and 695 MB at 96³.
    stride = max(1, floor(Int, (prod(n_pts) / 8000)^(1 / N)))
    # `spin_matrices(F)` is `SpinMatrices{D}` with D only known at runtime,
    # so the call's return type has to be narrowed at this boundary.
    fx, fy, fz = spin_density_vector(psi_init, spin_matrices(F), N)::NTuple{3, Array{Float64, N}}
    sampled = CartesianIndices(ntuple(d -> 1:stride:n_pts[d], N))

    nmax = 0.0
    @inbounds for I in sampled
        nsum = 0.0
        for c in 1:D
            nsum += abs2(psi_init[I, c])
        end
        nmax = max(nmax, nsum)
    end
    nmax <= 0 && return (0.0, 1.0, 1.0)
    cut = 1e-6 * nmax

    wsum = 0.0
    mean_f = 0.0
    peak_f = 1.0
    lo, hi = Inf, -Inf
    @inbounds for I in sampled
        nsum = 0.0
        for c in 1:D
            nsum += abs2(psi_init[I, c])
        end
        nsum < cut && continue
        # fx/fy/fz are DENSITY-weighted (⟨ψ|F|ψ⟩, not normalised), so dividing
        # by the local density gives the per-spinor |⟨F⟩| the LHY table cares
        # about — see CLAUDE.md, |F/n|² is a density-weighted average.
        f = sqrt(fx[I]^2 + fy[I]^2 + fz[I]^2) / (nsum * F)
        w = nsum^2.5
        wsum += w
        mean_f += w * f
        lo = min(lo, f)
        hi = max(hi, f)
        nsum == nmax && (peak_f = f)
    end
    wsum <= 0 && return (0.0, 1.0, 1.0)
    (hi - lo, peak_f, mean_f / wsum)
end

# Above this spread in |⟨F⟩|/F the single-spinor table is worth flagging.
# Measured on converged weak-field Eu ground states (pinned B-scan,
# figs/eu_bscan_pin_tight): spread 0.0 gives 0.00% error, 0.375 gives -1.5%,
# 0.89 gives -4.5%, 0.90 gives +4.9% — and the sign FLIPS across the scan, so
# it does not cancel in a B-comparison. 0.3 is where it leaves the noise.
const _LHY_TEXTURE_WARN = 0.3

function _warn_lhy_texture(mode::Symbol, psi_init, F::Int)
    spread, peak_f, mean_f = _lhy_texture_spread(psi_init, F)
    spread <= _LHY_TEXTURE_WARN && return nothing
    what = if mode === :full_bdg
        "built from the peak-density spinor (|⟨F⟩|/F ≈ $(round(peak_f; digits=2)))"
    else
        "built for the fixed :$mode ansatz"
    end
    @warn "LHY table is $what and then applied at every voxel, but this state " *
        "is textured in |⟨F⟩|/F: spread ≈ $(round(spread; digits=2)) across the " *
        "cloud, n^(5/2)-weighted mean ≈ $(round(mean_f; digits=2)) (sampled on " *
        "a stride, so indicative not exact). Measured on " *
        "converged weak-field Eu ground states that costs up to ~5% in ε_LHY, " *
        "with a sign that flips along a B-scan (so it does not cancel in a " *
        "comparison). Direction textures are free — only the magnitude of " *
        "⟨F⟩ matters. Treat LHY here as good to ~5%, or keep the state " *
        "uniform." maxlog=1
    nothing
end

# Catch-all: unknown / unsupported mode → nothing (caller falls through).
_build_spinor_lhy(::Val, atom, ws, psi_init, c_dd, enable_ddi, opts) = nothing

# Spatially-varying: `e₁(p)` tabulated from the ACTUAL local spinors of
# `psi_init`, one BdG solve per occupied `|⟨F⟩|/F` bin. Alone among the modes it
# is not built for a single spinor, so it is the ANSWER to `_warn_lhy_texture`
# rather than a caller of it.
#
# `compute_spatial_lhy` returns `nothing` when the cloud is uniform enough that
# a single-spinor table is already right (spread < `min_spread`). The correct
# response is NOT "no LHY" — that would hit the silent-zero throw — but the
# single-spinor table itself, which in that regime is exact. So fall back to
# `:full_bdg`, the general-spinor engine, built from the same peak spinor.
#
# Same for `psi_init === nothing`: there is no texture to read, so there is
# nothing for this mode to do that `:full_bdg` does not already do.
#
# Expect `full_bdg`'s "mean field is dynamically unstable" warning here on real
# textures, and do NOT read it as a defect: a bin's representative spinor is a
# local spinor lifted out of the cloud, and away from a locally-uniform region
# that is not a solution of the UNIFORM mean-field problem at its own density.
# Instability is then a statement about that fictitious uniform system, not
# about the state. It is `maxlog`-bounded, so it fires once per session.
function _build_spinor_lhy(::Val{:spatial}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _full_bdg() = _build_spinor_lhy(Val(:full_bdg), atom, ws, psi_init, c_dd,
        enable_ddi, opts)
    psi_init === nothing && return _full_bdg()
    tbl = compute_spatial_lhy(;
        psi_init, F=atom.F, interactions=ws,
        c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
        n_bins=opts.n_bins, n_atoms=opts.n_atoms)
    tbl === nothing ? _full_bdg() : tbl
end

function _build_spinor_lhy(::Val{:polar_two_channel}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:polar_two_channel, psi_init, atom.F)
    compute_spinor_lhy_polar_two_channel(;
        F=atom.F, c0=ws[0], c1=ws[1],
        c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
        n_max=_lhy_n_max(psi_init, opts), n_points=opts.n_points, n_atoms=opts.n_atoms)
end

function _build_spinor_lhy(::Val{:full_bdg}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:full_bdg, psi_init, atom.F)
    spinor_init = psi_init !== nothing ? _extract_spinor(psi_init) : _default_spinor(atom.F)
    compute_spinor_lhy_table(;
        spinor=spinor_init, F=atom.F, interactions=ws,
        c_dd=enable_ddi && !isnan(c_dd) ? c_dd : 0.0,
        n_max=_lhy_n_max(psi_init, opts), n_points=opts.n_points, n_atoms=opts.n_atoms)
end

# F-generic polar contact LHY (paper #1, contact-only). ~1000× faster than
# :full_bdg. Restricted to polar spinors (ζ_α = δ_{α,0}); for post-quench /
# mixed states fall back to :full_bdg.
function _build_spinor_lhy(::Val{:polar_contact}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:polar_contact, psi_init, atom.F)
    compute_spinor_lhy_polar_contact(;
        F=atom.F, g_dict=_lhy_g_dict(atom, ws), n_max=_lhy_n_max(psi_init, opts),
        n_points=opts.n_points, n_atoms=opts.n_atoms)
end

# FM-phase contact LHY (paper #2 contact-only piece). Single-mode collapse at
# m=+F: ε = (8/15π²)(g_{2F}n)^(5/2). For uniform g_S this matches scalar
# Lima-Pelster; for realistic per-S a_S it differs.
function _build_spinor_lhy(::Val{:fm_contact}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:fm_contact, psi_init, atom.F)
    compute_spinor_lhy_fm_contact(;
        F=atom.F, g_dict=_lhy_g_dict(atom, ws), n_max=_lhy_n_max(psi_init, opts),
        n_points=opts.n_points, n_atoms=opts.n_atoms)
end

# Stage C scalar reduction: FM single-mode contact LHY × Lima-Pelster Q_5(eps_dd).
# Workspace `c_dd` is the spin-Hamiltonian coupling mu0*(gF*muB)^2. For a
# fully polarized m=+F scalar reduction, the spin operators supply F^2. Since
# the DDI kernel uses Q = cos^2(theta) - 1/3 while Lima-Pelster uses
# 1 + eps_dd*(3cos^2(theta)-1), convert with eps_dd = c_dd*F^2/(3*g_2F).
# Direct callers that already have scalar eps_dd should use
# `compute_spinor_lhy_fm_dipolar(; eps_dd)`.
function _build_spinor_lhy(::Val{:fm_dipolar}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:fm_dipolar, psi_init, atom.F)
    g_dict = _lhy_g_dict(atom, ws)
    c_dd_eff = enable_ddi && !isnan(c_dd) ? c_dd : 0.0
    g_2F = get(g_dict, 2 * atom.F, 0.0)
    eps_dd = abs(g_2F) > 1e-12 ? abs(c_dd_eff) * atom.F^2 / (3.0 * abs(g_2F)) : 0.0
    compute_spinor_lhy_fm_dipolar(;
        F=atom.F, g_dict=g_dict, eps_dd=eps_dd, n_max=_lhy_n_max(psi_init, opts),
        n_points=opts.n_points, n_atoms=opts.n_atoms)
end

# F-generic polar contact + DDI LHY (paper #1 with dipolar extension).
# ε̃ = |c_dd| / |δ_1|; for finer control call
# `compute_spinor_lhy_polar_dipolar(; eps_tilde_dd, ...)` directly.
# Resolve the `backend` kwarg of `make_workspace`. Explicit `::AbstractBackend`
# is honoured verbatim (override always wins). `nothing` triggers auto-pick
# based on `cuda_functional()` (set by SpinorBECCUDAExt at __init__) and the
# grid's largest spatial dimension. Threshold: 3D + n_max ≥ 24 picks
# `CUDABackend()`, else `CPUBackend()`. Matches the empirical perf table
# in `recommend_backend_dtype` (16³ < 15% GPU advantage, kernel-launch
# overhead and CPU L2/L3 locality dominate; 24³+ favors GPU 3-30×). 1D
# and 2D grids stay on CPU because the per-voxel parallelism is too low
# for kernel-launch overhead to amortize and several analyzer paths
# don't have a GPU specialization. Set the env var
# `SPINORBEC_NO_AUTO_BACKEND=1` to force CPU regardless of grid size
# (test isolation, debugging GPU-vs-CPU divergences, or when the GPU
# is reserved for another process).
@inline function _resolve_backend(backend, grid::Grid{N}) where {N}
    backend isa AbstractBackend && return backend
    haskey(ENV, "SPINORBEC_NO_AUTO_BACKEND") && return CPUBackend()
    n_max = maximum(grid.config.n_points)
    if N == 3 && cuda_functional() && n_max >= 24
        return CUDABackend()
    end
    return CPUBackend()
end

function _build_spinor_lhy(::Val{:polar_dipolar}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:polar_dipolar, psi_init, atom.F)
    g_dict = _lhy_g_dict(atom, ws)
    c_dd_eff = enable_ddi && !isnan(c_dd) ? c_dd : 0.0
    delta_1 = delta_polar(atom.F, 1, g_dict)
    eps_tilde_dd = abs(delta_1) > 1e-12 ? abs(c_dd_eff) / abs(delta_1) : 0.0
    compute_spinor_lhy_polar_dipolar(;
        F=atom.F, g_dict=g_dict, eps_tilde_dd=eps_tilde_dd,
        n_max=_lhy_n_max(psi_init, opts), n_points=opts.n_points, n_atoms=opts.n_atoms)
end

# F=6 I_h closed form (Stage D). Universal `c_0^(5/2) + 3|λ_spin|^(5/2)` with
# stiffness coefficients depending only on g_0, g_6, g_10, g_12 (g_2, g_4, g_8
# cancel by I_h harmonic decomposition). Restricted to F=6 — caller must
# arrange the I_h ground state independently.
#
# NOT GENERALIZABLE: `:icosahedral` spinor_lhy dispatches the F=6 I_h closed form only.
# Reason: math
# Why: this branch wraps `compute_spinor_lhy_icosahedral` whose stiffness
#   coefficients (g_2, g_4, g_8 cancel) are specific to F=6 I_h. F=10/12 I_h
#   states share the point group but have different closed forms — dispatch
#   them through their own builder, not this branch.
# See: src/hamiltonian/terms/lhy/icosahedral.jl
function _build_spinor_lhy(::Val{:icosahedral}, atom, ws, psi_init, c_dd, enable_ddi, opts)
    _warn_lhy_texture(:icosahedral, psi_init, atom.F)
    atom.F == 6 || throw(ArgumentError(
        ":icosahedral spinor_lhy is F=6 only (got F=$(atom.F))"))
    compute_spinor_lhy_icosahedral(;
        F=atom.F, g_dict=_lhy_g_dict(atom, ws), n_max=_lhy_n_max(psi_init, opts),
        n_points=opts.n_points, n_atoms=opts.n_atoms)
end
