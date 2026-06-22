# --- Combined linear-F spin step (Magnus midpoint) ---
#
# Merges all linear-in-F operators (Zeeman transverse, c1·⟨F⟩, DDI mean-field)
# into a single per-voxel rotation:
#
#     ψ → exp(-i dt n_tot(r) · F̂) ψ
#     n_tot(r) = (B_x, B_y, 0) + c₁ ⟨F⟩(r) + Φ_DDI(r)
#
# The linear z-Zeeman (-p F_z) and quadratic Zeeman (q F_z²) STAY IN
# `_dispatch_diagonal_step!` because they are diagonal in the m basis
# and the diagonal step handles them as O(N·D) m-dependent phases.
#
# # Why this works (despite [SM, DDI] ≠ 0)
#
# Sequential `SM(dt/2) DDI(dt) SM(dt/2)` produces an O(dt³)·[SM,[SM,DDI]]
# error because the operators are applied serially with non-trivial
# commutator. A single `exp(-i dt (n_SM + n_DDI)·F̂)` has NO such error
# — the matrix exponential handles all internal commutators exactly.
# What remains is only the time-evolution error from freezing
# n(r, t) at one time point during dt; Strang midpoint evaluation
# (sandwiched between V_diag halves) preserves global O(dt²) accuracy.
#
# # Caveat (read before enabling for non-Eu atoms)
#
# This is only correct when the contact interaction is well-approximated
# by `c0 (scalar density)` + `c1 (rank-1 spin)` channels. For F ≥ 2
# atoms with non-negligible higher-rank coupling (c2 singlet_pair, c4/c6
# tensor channels), those terms are NOT representable as `n·F̂` and must
# be applied separately. The function asserts c2 = 0 and tensor_cache
# === nothing at entry; explicitly opt out for c2/tensor systems.
#
# For ¹⁵¹Eu (⁸S₇/₂ orbital symmetry), c2..c6 are anomalously small and
# this approximation is well-justified — it is the standard treatment
# for that species.

export split_step_combined!

"""
    _apply_combined_spin_step!(ws, dt, t; imaginary_time=false)

Compute n_tot(r) = transverse Zeeman + c₁ ⟨F⟩(r) + Φ_DDI(r), then apply
the single rotation `exp(-i dt n_tot · F̂)` to ψ in place.

Reuses `ws.ddi_bufs.Fx_r/Fy_r/Fz_r` for spin density and
`ws.ddi_bufs.Phi_x/Phi_y/Phi_z` for the combined effective field.
Requires `ws.ddi_bufs` to exist (i.e. `enable_ddi=true` at workspace
construction) — that's where the buffers live.
"""
function _apply_combined_spin_step!(
    ws::Workspace{N}, dt::Float64, t::Float64;
    imaginary_time::Bool=false,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N}
    sm = ws.spin_matrices
    psi = ws.state.psi
    # Mean field (spin density Φ_DDI, c₁⟨F⟩) is computed from `psi_mf` when
    # supplied (the Picard-midpoint state), else from the running ψ. The
    # rotation is always applied to `psi`. Mirrors the sequential path's
    # psi_mf contract so split_step_combined! can be midpoint-symmetrised.
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    bufs = ws.ddi_bufs
    n_comp = sm.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = n_comp

    c1 = ws.interactions[1]

    # Compute spin density into bufs.{Fx_r, Fy_r, Fz_r}, then if DDI is
    # active fold it through the FFT convolution to produce the dipolar
    # field in bufs.{Phi_x, Phi_y, Phi_z}. When DDI is off we still need
    # the spin density (for c1 ⟨F⟩) but the convolution is skipped and
    # Phi_* is treated as zero.
    ddi_active = ws.ddi !== nothing && is_active(ws.ddi.C_dd)
    if ddi_active
        _compute_and_convolve_ddi!(psi_mf_eff, sm, ws.ddi, bufs, Val(D), N, n_pts)
    else
        _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r,
            psi_mf_eff, sm, Val(D), N, n_pts)
        fill!(bufs.Phi_x, 0.0)
        fill!(bufs.Phi_y, 0.0)
        fill!(bufs.Phi_z, 0.0)
    end

    # Linear transverse Zeeman: H = -(bx F_x + by F_y) per user-spec
    # `b_block_builders.jl:27` (H_Zeeman = -g_F·μ_B·B·F). Optionally
    # rotate into the spin-rotating frame so a resonant drive becomes
    # static there.
    zee = zeeman_at(ws.zeeman, t)
    # Defect-8 fix (2026-06-06): transverse_b must read the ORIGINAL
    # ws.zeeman — zeeman_at collapses TimeDependentZeeman to a
    # diagonal-only ZeemanParams (drops bx/by), so the old
    # `transverse_b(zee, t)` was identically (0, 0) and this entire
    # transverse branch was structurally dead.
    bx_lab, by_lab = transverse_b(ws.zeeman, t)
    omega_R = ws.sim_params.spin_rotating_frame_omega
    bx, by = if is_active(omega_R, ROTATION_TOL)
        cs = cos(omega_R * t)
        sn = sin(omega_R * t)
        (bx_lab * cs + by_lab * sn, -bx_lab * sn + by_lab * cs)
    else
        (bx_lab, by_lab)
    end

    # Combine into Phi (already holds Φ_DDI for the ddi_active case).
    # The linear z-Zeeman -p F_z is NOT here — it sits in V_diag where
    # its m-diagonal action is computed as a per-component phase.
    # Broadcast (not a manual loop) so this works on GPU arrays too.
    # 2026-06-04 sign fix: subtract `bx, by` to match user-spec
    # `H_Zeeman = -(g_F μ_B B · F)`. `_apply_ddi_rotation!` applies
    # `exp(-i·dt·(phi·F̂))` which has H = +phi·F̂; user's +Bx must enter
    # as -bx in phi so the resulting H is -bx·F_x. Pre-fix used `.+ bx`
    # which silently inverted Bx, By sign. See
    # `mistake_transverse_zeeman_sign_inversion_2026_06_04`.
    bufs.Phi_x .+= c1 .* bufs.Fx_r .- bx
    bufs.Phi_y .+= c1 .* bufs.Fy_r .- by
    bufs.Phi_z .+= c1 .* bufs.Fz_r

    # If everything is zero (no SM, no DDI, no transverse), skip.
    something_active = is_active(c1) || ddi_active || is_active(abs(bx) + abs(by))
    something_active || return nothing

    # Single Euler rotation per voxel (batched gemm + cis recurrence on
    # CPU; fused (N,D) broadcast on GPU). We dispatch through the generic
    # `_apply_ddi_rotation!` so the right backend path is picked
    # automatically — same operator exp(-i dt φ(r)·F̂) either way.
    _apply_ddi_rotation!(
        psi, bufs.Phi_x, bufs.Phi_y, bufs.Phi_z, sm, dt, N;
        imaginary_time=imaginary_time,
    )
    nothing
end

# Half-potential step using the combined spin operator. Order pattern:
#
#     diag(dt/4) → Combined(dt/2) → diag(dt/4)
#
# vs the standard `_half_potential_step!`:
#
#     diag(dt/4) → SM(dt/4) → DDI(dt/2) → SM(dt/4) → diag(dt/4)
#
# 6 spin rotations / split_step → 2 (one per half-potential step). The
# midpoint of the dt/2 interval falls between the two diag(dt/4) calls,
# which is where we evaluate ⟨F⟩ and Φ_DDI — preserves Strang's O(dt²).
function _half_potential_step_combined!(
    ws::Workspace{N}, dt_half::Float64, n_comp::Int, ndim::Int, imaginary_time::Bool;
    t_eval::Float64=ws.state.t, t_start::Float64=NaN,
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N}
    # Caveat enforcement: combined step is c0+c1+DDI only.
    _assert_combined_step_compatible(ws)

    ip = if ws.time_dep_interactions !== nothing
        td_ip = interactions_at(ws.time_dep_interactions, t_eval)
        merged = Dict{Int, Float64}(k => v for (k, v) in ws.interactions.c
                                               if k >= 2)
        merged[0] = td_ip[0]
        merged[1] = td_ip[1]
        InteractionParams(merged; c_lhy=ws.interactions.c_lhy)
    else
        ws.interactions
    end

    zeeman_diag = if !isnan(t_start) && _has_time_dependence(ws.zeeman)
        zee_fwd = zeeman_at(ws.zeeman, t_start + dt_half / 4)
        zeeman_diagonal(zee_fwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    else
        zee = zeeman_at(ws.zeeman, t_eval)
        zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    end

    _apply_mg_to_V!(ws, t_eval)
    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_half / 2, imaginary_time, ip; psi_mf)
    _remove_mg_from_V!(ws, t_eval)

    # ψ is now at the midpoint of the dt_half interval — evaluate
    # n_tot(r) here for Magnus midpoint accuracy (or use the frozen
    # `psi_mf` midpoint when the predictor-corrector wrapper supplies it).
    _apply_combined_spin_step!(ws, dt_half, t_eval; imaginary_time, psi_mf)

    _apply_mg_to_V!(ws, t_eval)
    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_half / 2, imaginary_time, ip; psi_mf)
    _remove_mg_from_V!(ws, t_eval)
    nothing
end

# Midpoint (Picard predictor-corrector) wrapper for the combined half-V,
# analogous to `_half_potential_step_midpoint!`. Freezes the mean field at the
# half-step temporal midpoint for ALL substeps (diag c₀ density + combined
# DDI/c₁⟨F⟩), restoring the same 2nd-order Mz-conserving accuracy the
# sequential `split_step!` gets — the plain combined step's single Magnus
# midpoint leaks Mz under stiff DDI. n_picard=1 suffices (matches split_step!).
function _half_potential_step_combined_midpoint!(
    ws::Workspace{N}, dt_half::Float64, n_comp::Int, ndim::Int, imaginary_time::Bool;
    t_eval::Float64=ws.state.t, t_start::Float64=NaN, n_picard::Int=1,
) where {N}
    psi_orig = ws.state.psi
    psi_mid_prev, psi_mid_curr = _get_midpoint_scratch(psi_orig)

    copyto!(psi_mid_curr, psi_orig)
    ws.state.psi = psi_mid_curr
    try
        _half_potential_step_combined!(ws, dt_half / 2, n_comp, ndim, imaginary_time;
            t_eval, t_start, psi_mf=psi_orig)
    finally
        ws.state.psi = psi_orig
    end
    for _ in 2:n_picard
        copyto!(psi_mid_prev, psi_mid_curr)
        copyto!(psi_mid_curr, psi_orig)
        ws.state.psi = psi_mid_curr
        try
            _half_potential_step_combined!(ws, dt_half / 2, n_comp, ndim, imaginary_time;
                t_eval, t_start, psi_mf=psi_mid_prev)
        finally
            ws.state.psi = psi_orig
        end
    end
    _half_potential_step_combined!(ws, dt_half, n_comp, ndim, imaginary_time;
        t_eval, t_start, psi_mf=psi_mid_curr)
    nothing
end

# Dispatcher: midpoint when RT + DDI active (and the toggle is on), matching
# `_half_potential!` for the sequential path so both production propagators
# get the same 2nd-order mean-field treatment.
@inline function _half_potential_combined!(
    ws::Workspace{N}, dt_half::Float64, n_comp::Int, ndim::Int, imaginary_time::Bool;
    t_eval::Float64=ws.state.t, t_start::Float64=NaN,
) where {N}
    if MEANFIELD_MIDPOINT_ENABLED[] && ws.ddi !== nothing && !imaginary_time
        _half_potential_step_combined_midpoint!(ws, dt_half, n_comp, ndim, imaginary_time;
            t_eval, t_start, n_picard=1)
    else
        _half_potential_step_combined!(ws, dt_half, n_comp, ndim, imaginary_time;
            t_eval, t_start)
    end
end

# Pre-flight check: combined step is only valid when contact interaction
# is well-approximated by c0+c1 (rank-0 + rank-1) and there are no
# higher-rank tensor channels active. Throws ArgumentError otherwise.
function _assert_combined_step_compatible(ws::Workspace)
    c2 = get_cn(ws.interactions, 2)
    abs(c2) < 1e-30 || throw(
        ArgumentError(
            "split_step_combined! requires c2 = 0 (S=0 singlet-pair channel). Got c2=$c2. " *
            "Use the standard split_step! for systems with non-zero c2."),
    )
    ws.tensor_cache === nothing || throw(
        ArgumentError(
            "split_step_combined! incompatible with tensor_cache (higher-rank " *
            "spin tensor channels c4/c6/...). Use standard split_step! or " *
            "construct workspace without scattering-lengths channel coupling."),
    )
    ws.raman === nothing || throw(
        ArgumentError(
            "split_step_combined! does not yet support Raman coupling. " *
            "Use standard split_step!."),
    )
    is_uniform(ws.zeeman) || throw(
        ArgumentError(
            "split_step_combined! does not support a spatial Zeeman field B(r,t). " *
            "Use the standard split_step!."),
    )
    ws.light_shift === nothing || throw(
        ArgumentError(
            "split_step_combined! does not yet support light_shift. " *
            "Use standard split_step!."),
    )
    ws.ddi_bufs !== nothing || throw(
        ArgumentError(
            "split_step_combined! requires DDI buffers (the spin density " *
            "and Φ buffers live there). Construct workspace with enable_ddi=true."),
    )
    # The combined path always runs the UNPADDED _compute_and_convolve_ddi!
    # (combined_spin_step.jl:67-69); silently ignoring a configured padded
    # context would give the caller unpadded physics behind a padded
    # request. Refuse loudly rather than mislead (App. A defect-9 audit).
    ws.ddi_padded === nothing || throw(
        ArgumentError(
            "split_step_combined! does not support zero-padded DDI " *
            "(ddi_padding=true). The combined step uses the unpadded " *
            "convolution; use the standard split_step! for padded DDI."),
    )
    nothing
end

"""
    split_step_combined!(ws::Workspace) → nothing

Optimized split step that merges all linear-in-F̂ operators (transverse
Zeeman, c₁ spin-mixing, DDI mean-field) into a single per-voxel
rotation per half-potential step. Compared with `split_step!`:

* 6 spin rotations / step → 2 — the dominant cost saving (each rotation
  is the batched 5-stage Euler decomposition at full ψ-array size).
* Same Strang O(dt²) global accuracy. When DDI is active (and
  `MEANFIELD_MIDPOINT_ENABLED[]`) the mean field is frozen at the
  implicit-midpoint via a Picard predictor-corrector (`_half_potential_
  step_combined_midpoint!`, n_picard=1) — the same treatment `split_step!`
  uses — which conserves M_z under stiff DDI (the plain single Magnus
  midpoint leaks it). The two splittings then agree to O(dt³).
* Converges to the same continuum limit as `split_step!`.

# Why no `:yoshida6` composition kwarg

Yoshida's order-N construction is derived for **separable autonomous**
Hamiltonians H = T(p) + V(q) [Yoshida 1990, Phys. Lett. A 150, 262].
Self-consistent mean-field problems (this combined V evaluates `Φ_DDI`
and `c₁⟨F⟩` from ψ, making H non-autonomous through ψ) are outside
that derivation's scope. Empirically in `test_integrator_order_meanfield`
we observe Y6 dropping to order ≈ 1 once any mean-field channel is
active; for general nonlinear Schrödinger settings Choi & Vaníček
[arXiv:2006.16902, 2020] document explicit splitting losing to
first-order accuracy and propose implicit-midpoint compositions as
the fix. The per-half-step predictor-corrector that fix needs IS now
applied here for DDI (`_half_potential_step_combined_midpoint!`,
n_picard=1) — it doubles the per-half-V cost (predictor + corrector) but
restores M_z conservation; the combined path is still cheaper than the
sequential midpoint (2 fused rotations vs 6 per V). A full Yoshida-N
composition on this nonlinear V remains out of scope (use
`run_simulation_yoshida!` for high-order on the sequential path).

The codebase's Y6 weights (`_COMP_YOSHIDA_S6` in
`split_step_composers.jl`) are Yoshida 1990 Solution A: bs =
(w₃, w₂, w₁, w₀, w₁, w₂, w₃) with w₀ ≈ +1.315 (positive, middle) and
w₁ ≈ −1.178 (negative, at positions 3 and 5). Numerical magnitudes
match the published Solution A; the convention here labels them so
that w₁ is the negative one, whereas Yoshida's original paper labels
them in the opposite order (same algorithm either way).

# Restrictions

Asserted at the first call:
* `c2 = 0` (no rank-2 nematic / singlet-pair channel)
* `tensor_cache === nothing` (no rank-4/6 tensor channels)
* `raman === nothing`, `light_shift === nothing`
* `enable_ddi=true` at workspace construction (uses ddi_bufs as scratch)

For ¹⁵¹Eu the c2..c6 channels are anomalously small (⁸S₇/₂ orbital
symmetry), so the c0+c1+DDI approximation is well-justified.

# Use

```julia
ws = make_workspace(...; enable_ddi=true, c_dd=100.0)
for step in 1:n_steps
    split_step_combined!(ws)
end
```

Drop-in replacement for `split_step!` for compatible workspaces.
"""
function split_step_combined!(ws::Workspace{N}) where {N}
    dt = ws.sim_params.dt
    it = ws.sim_params.imaginary_time
    n_comp = ws.spin_matrices.system.n_components
    t = ws.state.t

    # Outer Strang: V(dt/2) [Cor T Cor] V(dt/2) — same shape as the
    # standard split_step!. We tried T(dt/2) V(dt) T(dt/2) which gives
    # one fewer Combined call (~30% faster) but bigger leading-order
    # error coefficient because [V_diag, Combined] (which contains
    # q F_z² × (n·F) in Klaus regime) is then NOT cancelled by an inner
    # Strang — measured ~30× larger per-step diff vs the standard
    # scheme. Stay with V T V to keep error within the same regime as
    # the existing production runs.
    _assert_combined_step_compatible(ws)

    t_eval_1 = it ? 0.0 : t + dt / 4
    t_eval_2 = it ? 0.0 : t + 3dt / 4

    _half_potential_combined!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_1, t_start=it ? NaN : t
    )

    omega = ws.sim_params.rotating_frame_omega
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws)
    apply_step!(KineticTerm(), ws.state.psi, 0.0, false, ws)
    apply_step!(CoriolisTerm(omega), ws.state.psi, dt / 2, it, ws)

    _half_potential_combined!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_2, t_start=it ? NaN : t + dt / 2
    )

    it || apply_rt_dissipation!(ws, dt, n_comp, N)

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1
    if it && ws.sim_params.normalize_every > 0 &&
        ws.state.step % ws.sim_params.normalize_every == 0
        _normalize_psi!(ws.state.psi, ws.grid, n_comp, N)
    end
    nothing
end
