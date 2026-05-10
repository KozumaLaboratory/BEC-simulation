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
# atoms with non-negligible higher-rank coupling (c2 nematic, c4/c6
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
) where {N}
    sm = ws.spin_matrices
    psi = ws.state.psi
    bufs = ws.ddi_bufs
    n_comp = sm.system.n_components
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = n_comp

    c1 = ws.interactions.c1

    # Compute spin density into bufs.{Fx_r, Fy_r, Fz_r}, then if DDI is
    # active fold it through the FFT convolution to produce the dipolar
    # field in bufs.{Phi_x, Phi_y, Phi_z}. When DDI is off we still need
    # the spin density (for c1 ⟨F⟩) but the convolution is skipped and
    # Phi_* is treated as zero.
    ddi_active = ws.ddi !== nothing && abs(ws.ddi.C_dd) > 1e-30
    if ddi_active
        _compute_and_convolve_ddi!(psi, sm, ws.ddi, bufs, Val(D), N, n_pts)
    else
        _compute_spin_density!(bufs.Fx_r, bufs.Fy_r, bufs.Fz_r,
            psi, sm, Val(D), N, n_pts)
        fill!(bufs.Phi_x, 0.0)
        fill!(bufs.Phi_y, 0.0)
        fill!(bufs.Phi_z, 0.0)
    end

    # Linear transverse Zeeman: bx F_x + by F_y. Optionally rotate into
    # the spin-rotating frame so a resonant drive becomes static there.
    zee = zeeman_at(ws.zeeman, t)
    bx_lab, by_lab = transverse_b(zee, t)
    omega_R = ws.sim_params.spin_rotating_frame_omega
    bx, by = if abs(omega_R) > 1e-30
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
    bufs.Phi_x .+= c1 .* bufs.Fx_r .+ bx
    bufs.Phi_y .+= c1 .* bufs.Fy_r .+ by
    bufs.Phi_z .+= c1 .* bufs.Fz_r

    # If everything is zero (no SM, no DDI, no transverse), skip.
    something_active = abs(c1) > 1e-30 || ddi_active || (abs(bx) + abs(by) > 1e-30)
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
) where {N}
    # Caveat enforcement: combined step is c0+c1+DDI only.
    _assert_combined_step_compatible(ws)

    ip = if ws.time_dep_interactions !== nothing
        td_ip = interactions_at(ws.time_dep_interactions, t_eval)
        InteractionParams(td_ip.c0, td_ip.c1, ws.interactions.c_lhy, ws.interactions.c_extra)
    else
        ws.interactions
    end

    zeeman_diag = if !isnan(t_start) && ws.zeeman isa TimeDependentZeeman
        zee_fwd = zeeman_at(ws.zeeman, t_start + dt_half / 4)
        zeeman_diagonal(zee_fwd, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    else
        zee = zeeman_at(ws.zeeman, t_eval)
        zeeman_diagonal(zee, ws.spin_matrices, ws.sim_params.spin_rotating_frame_omega)
    end

    _apply_mg_to_V!(ws, t_eval)
    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_half / 2, imaginary_time, ip)
    _remove_mg_from_V!(ws, t_eval)

    # ψ is now at the midpoint of the dt_half interval — evaluate
    # n_tot(r) here for Magnus midpoint accuracy.
    _apply_combined_spin_step!(ws, dt_half, t_eval; imaginary_time)

    _apply_mg_to_V!(ws, t_eval)
    _dispatch_diagonal_step!(ws, Val(N), zeeman_diag, dt_half / 2, imaginary_time, ip)
    _remove_mg_from_V!(ws, t_eval)
    nothing
end

# Pre-flight check: combined step is only valid when contact interaction
# is well-approximated by c0+c1 (rank-0 + rank-1) and there are no
# higher-rank tensor channels active. Throws ArgumentError otherwise.
function _assert_combined_step_compatible(ws::Workspace)
    c2 = get_cn(ws.interactions, 2)
    abs(c2) < 1e-30 || throw(
        ArgumentError(
            "split_step_combined! requires c2 = 0 (rank-2 nematic). Got c2=$c2. " *
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
    nothing
end

"""
    split_step_combined!(ws::Workspace) → nothing

Optimized split step that merges all linear-in-F̂ operators (transverse
Zeeman, c₁ spin-mixing, DDI mean-field) into a single per-voxel
rotation per half-potential step. Compared with `split_step!`:

* 6 spin rotations / step → 2 — the dominant cost saving (each rotation
  is the batched 5-stage Euler decomposition at full ψ-array size).
* Same Strang O(dt²) global accuracy via Magnus midpoint evaluation
  inside each half-potential step.
* Bit-different from `split_step!` to O(dt²) (different splitting),
  but converges to the same continuum limit.

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
the fix. Implementing that here would mean a predictor-corrector
iteration on `Φ_DDI[ψ]` / `⟨F⟩[ψ]` per V substep, doubling per-V cost
and erasing most of the combined-vs-sequential saving. For now: stick
with Strang+combined (order 2, fast), or use `run_simulation_yoshida!`
with the sequential split_step path if you need a higher-order method
on a problem that's effectively autonomous (where Yoshida's assumptions
hold).

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

    _half_potential_step_combined!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_1, t_start=it ? NaN : t
    )

    omega = ws.sim_params.rotating_frame_omega
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, ws.coriolis_cache)
    apply_kinetic_step_batched!(ws.state.psi, ws.batched_kinetic)
    _apply_coriolis_step!(ws.state.psi, ws.grid, omega, dt / 2, it, ws.coriolis_cache)

    _half_potential_step_combined!(
        ws, dt / 2, n_comp, N, it; t_eval=t_eval_2, t_start=it ? NaN : t + dt / 2
    )

    if !it && ws.loss !== nothing
        apply_loss_step!(
            ws.state.psi, ws.loss, ws.spin_matrices.system.F,
            dt, n_comp, N, ws.density_buf,
        )
    end
    if !it && ws.absorbing_mask !== nothing
        apply_absorbing_boundary!(ws.state.psi, ws.absorbing_mask, n_comp, N)
    end

    ws.state.t += it ? 0.0 : dt
    ws.state.step += 1
    if it && ws.sim_params.normalize_every > 0 &&
        ws.state.step % ws.sim_params.normalize_every == 0
        _normalize_psi!(ws.state.psi, ws.grid, n_comp, N)
    end
    nothing
end
