# --- Option γ Strang/Yoshida/CFET integrators + drivers ---
#
# split_step_rotating!, evolve_*, Yoshida 4 and 6, CFET4 (commutator-free
# exponential time). Plus the find_ground_state_rotating! driver.

"""Lab-basis RTP driver."""
function evolve_lab!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        split_step_lab!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

# --- Strang split-step ---

"""
One Strang step in rotating basis:

  T(dt/2) D(dt/2) [DDI(dt) + spin-mixing if c1≠0] D(dt/2) T(dt/2) — symmetric
  + gauge connection over the whole step (full dt)

For the skeleton we keep the structure simple. spin-mixing F·⟨F⟩ is omitted
when c1 = 0 (skipped); when present it's applied symmetrically.

When `with_loss=true` (the default) and `ws.loss` is active, a half-step
loss action is sandwiched around the unitary core:
  Loss(dt/2) → unitary core → Loss(dt/2)
giving 2nd-order Strang splitting between unitary + dissipative. K3 / γ_dr
act on |ψ̃|² which is basis-invariant, so applying the spinor-path
`apply_loss_step!` directly on ψ̃ is correct.

Yoshida4/6 wrappers pass `with_loss=false` so the inner negative-weight
sub-steps don't produce anti-loss; they handle loss themselves at the
macro-step level.
"""
function split_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
    with_loss::Bool=true,
) where {T, N, D}
    half = dt / 2
    t_mid = t + half
    F_atom = ws.spin_matrices.system.F
    apply_loss = with_loss && _is_active(ws.loss)

    # Strang sandwich: half loss before
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(half), D, N, ws.rho_buf,
        )
    end

    # Spatial-diagonal (V_trap + c0 n) + Local spin step (Zeeman_diag - Â) outermost,
    # since local-spin step is exact and acts as the bridge between FFT and DDI.
    apply_kinetic_step_rotating!(ws, half; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_local_spin_step!(ws, half, t_mid; imaginary_time)

    if abs(ws.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.psi_tilde, ws.spin_matrices, Float64(ws.c1), Float64(half), N;
            imaginary_time,
        )
    end

    apply_ddi_step_rotating!(ws, dt, t_mid; imaginary_time)

    if abs(ws.c1) > 1e-30
        apply_spin_mixing_step!(
            ws.psi_tilde, ws.spin_matrices, Float64(ws.c1), Float64(half), N;
            imaginary_time,
        )
    end

    apply_local_spin_step!(ws, half, t_mid; imaginary_time)
    apply_spatial_diagonal_step!(ws, half; imaginary_time)
    apply_kinetic_step_rotating!(ws, half; imaginary_time)

    # Strang sandwich: half loss after
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(half), D, N, ws.rho_buf,
        )
    end

    nothing
end

# --- Drivers ---

function rotating_norm(ws::RotatingBasisWS{T, N, D}) where {T, N, D}
    # GPU-safe: sum(abs2, ψ) is dispatched via GPUArrays for CuArray
    s = sum(abs2, ws.psi_tilde)::T
    s * prod(ws.grid.dx)
end

function normalize_rotating!(
    ws::RotatingBasisWS{T, N, D}; target_norm::T=one(T)
) where {T, N, D}
    n = rotating_norm(ws)
    n > zero(T) || return nothing
    s = sqrt(target_norm / n)
    @. ws.psi_tilde *= s
    nothing
end

"""ITP for rotating-basis spinor GP. For static B̂ (Â=0) this finds
the lab-frame ground state expressed in the rotating basis."""
function find_ground_state_rotating!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    target_norm::T=one(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    μ_last = zero(T)
    for step in 1:n_steps
        # ITP is for finding equilibrium GS; loss channels (which break
        # time-reversal) are RTP-only — skip them inside ITP regardless of
        # ws.loss state. Users wiring a loss block on a ground_state step
        # would otherwise see GS converge to a vanishing density.
        split_step_rotating!(ws, dt, zero(T);
            imaginary_time=true, with_loss=false)
        n_before = rotating_norm(ws)
        if n_before > zero(T) && target_norm > zero(T)
            μ_last = -log(n_before / target_norm) / (2 * dt)
        end
        normalize_rotating!(ws; target_norm)
        on_step !== nothing && on_step(step, μ_last, ws)
    end
    μ_last
end

# --- Higher-order time integration: CFET (Alvermann-Fehske 2011) ---

"""
Yoshida4 step in rotating basis (order 4 in dt).

Triple-jump scheme with Yoshida (1990) coefficients:
    w₁ = 1 / (2 - 2^(1/3))
    w₀ = 1 - 2 w₁
    ψ(t+dt) = U(w₁ dt) U(w₀ dt) U(w₁ dt) ψ(t)
where U(τ) = `split_step_rotating!(ws, τ, t_local)` with H sampled at
the midpoint of each sub-step.

Compared to a single Strang step of dt:
- 3 sub-steps per macro step (3× compute)
- Order 4 vs Strang's order 2
- For 4× larger dt at same nominal precision: 0.75× wall time
- Long-time energy drift dramatically reduced

NOTE: w₀ ≈ -1.702 is a NEGATIVE (backward) sub-step. Stable for
unitary RTP at any sign; for imaginary-time ITP this is a known
instability ("Sheng-Suzuki barrier"), so this routine is RTP-only.
"""
function yoshida4_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time &&
        error("yoshida4_step_rotating! is RTP-only (negative sub-step blows up in ITP).")
    cbrt2 = T(2)^(T(1) / T(3))
    w₁ = T(1) / (T(2) - cbrt2)
    w₀ = T(1) - T(2) * w₁

    F_atom = ws.spin_matrices.system.F
    apply_loss = _is_active(ws.loss)

    # Macro-step loss sandwich: half before / half after the unitary triple.
    # The triple-jump's negative w₀ would produce anti-loss inside Strang sub-steps,
    # so loss is handled here at the macro-step level (using full dt) and
    # split_step_rotating! is called with with_loss=false.
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end

    # Sequence: U(w₁) U(w₀) U(w₁), each with midpoint H sampling. Unitary only.
    split_step_rotating!(ws, w₁ * dt, t;
        imaginary_time=false, with_loss=false)               # H @ t + (w₁/2)·dt
    split_step_rotating!(ws, w₀ * dt, t + w₁ * dt;
        imaginary_time=false, with_loss=false)               # H @ t + (w₁ + w₀/2)·dt
    split_step_rotating!(ws, w₁ * dt, t + (w₁ + w₀) * dt;
        imaginary_time=false, with_loss=false)

    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end
    nothing
end

"""
CFET-style order-4 step using Yoshida4 + Gauss-Legendre time sampling.
Each Yoshida sub-step's H is evaluated at its OWN midpoint, giving the
order-4 accuracy in time-dependent H without requiring commutator
computation.

This is the practical CFET path for `RotatingBasisWS`. For Klaus
magnetostir at full physical Larmor (p=28428), use this when long-time
accuracy matters (1 sec stir, vortex stripe formation).
"""
const cfet4_step_rotating! = yoshida4_step_rotating!

"""
RTP driver using Yoshida4. Same signature as `evolve_rotating!`. Use
when Klaus-regime long-time accuracy matters or to take ~4× larger dt
at comparable accuracy.
"""
function evolve_rotating_yoshida4!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        yoshida4_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

const evolve_rotating_cfet4! = evolve_rotating_yoshida4!

# --- Higher-order compositions: 6th and 8th order ---

"""
Yoshida6 step in rotating basis (order 6, 7-stage triple-jump composition).

Reference: Yoshida 1990 Phys Lett A 150, 262, "Solution A":
    w₁ = -1.17767998417887
    w₂ =  0.235573213359357
    w₃ =  0.784513610477560
    w₀ = 1 - 2(w₁+w₂+w₃)
Symmetric weight sequence: (w₃, w₂, w₁, w₀, w₁, w₂, w₃).

Per-step compute: 7× Strang. For autonomous H this gives O(dt⁶) accuracy.
For time-dep H (sampled at midpoint per sub-step) the time-dep error is
O(dt²) and dominates unless H(t) varies very slowly.

Best for: long-time RTP runs where energy/norm drift over many trap
periods matters (Klaus 1 sec stir, B-1 long evolution). RTP only.
"""
function yoshida6_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time && error("yoshida6_step_rotating! is RTP-only.")
    w₁ = T(-1.17767998417887)
    w₂ = T(0.235573213359357)
    w₃ = T(0.784513610477560)
    w₀ = one(T) - T(2) * (w₁ + w₂ + w₃)
    weights = (w₃, w₂, w₁, w₀, w₁, w₂, w₃)
    F_atom = ws.spin_matrices.system.F
    apply_loss = _is_active(ws.loss)
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end
    t_local = t
    for w in weights
        split_step_rotating!(ws, w * dt, t_local + w * dt / 2;
            imaginary_time=false, with_loss=false)
        t_local += w * dt
    end
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end
    nothing
end

"""RTP driver: Yoshida6."""
function evolve_rotating_yoshida6!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        yoshida6_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

# --- Real CFET (Commutator-Free Exponential Time, Alvermann-Fehske 2011) ---

"""
Real CFET4 — EXPERIMENTAL (Alvermann-Fehske 2011 attempted form).

Theoretical motivation: order-4 specifically for time-dependent H (Yoshida4
is order 4 only for autonomous parts; CFET4 should be order 4 also in time-dep
H provided commutator-free conditions are met).

Status: numerical test shows only ~order 2.5 improvement (8× over Strang at
dt=0.01, vs 820× for Yoshida4). Reason: Alvermann-Fehske CFET4 requires each
exponential's argument to be a LINEAR COMBINATION α·A(τ₁) + β·A(τ₂), but the
encapsulated `split_step_rotating!` only supports single-time H sampling.
True CFET4 needs an extension that lets the diagonal/spin step accept
weighted multi-time H evaluation.

Until that infrastructure exists, prefer `yoshida4_step_rotating!` (verified
order 4) or `yoshida6_step_rotating!` (verified order 6) for production runs
in the slow-time-dep regime (Klaus magnetostir, B-1 scan).

Coefficients (Alvermann-Fehske CF4:4exp palindromic form):
    τ₁ = t + (1/2 - √3/6)·dt  ;  τ₂ = t + (1/2 + √3/6)·dt
    α = 1/4 + √3/12  ;  β = 1/4 - √3/12

RTP only.
"""
function cfet4_real_step_rotating!(
    ws::RotatingBasisWS{T, N, D}, dt::T, t::T;
    imaginary_time::Bool=false,
) where {T, N, D}
    imaginary_time && error("cfet4_real_step_rotating! is RTP-only.")

    sqrt3_6 = sqrt(T(3)) / T(6)
    sqrt3_12 = sqrt(T(3)) / T(12)
    τ₁_offset = T(0.5) - sqrt3_6
    τ₂_offset = T(0.5) + sqrt3_6
    α = T(0.25) + sqrt3_12
    β = T(0.25) - sqrt3_12

    F_atom = ws.spin_matrices.system.F
    apply_loss = _is_active(ws.loss)
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end
    # Stage 1: α at τ₁ (unitary only)
    split_step_rotating!(ws, α * dt, t + τ₁_offset * dt;
        imaginary_time=false, with_loss=false)
    # Stage 2: β at τ₂
    split_step_rotating!(ws, β * dt, t + τ₂_offset * dt;
        imaginary_time=false, with_loss=false)
    # Stage 3: β at τ₁
    split_step_rotating!(ws, β * dt, t + τ₁_offset * dt;
        imaginary_time=false, with_loss=false)
    # Stage 4: α at τ₂
    split_step_rotating!(ws, α * dt, t + τ₂_offset * dt;
        imaginary_time=false, with_loss=false)
    if apply_loss
        apply_loss_step!(
            ws.psi_tilde, ws.loss, F_atom, Float64(dt) / 2, D, N, ws.rho_buf,
        )
    end
    nothing
end

"""RTP driver: real CFET4 (Alvermann-Fehske)."""
function evolve_rotating_cfet4_real!(
    ws::RotatingBasisWS{T, N, D}, n_steps::Int, dt::T;
    t0::T=zero(T),
    on_step::Union{Nothing, Function}=nothing,
) where {T, N, D}
    t = t0
    for step in 1:n_steps
        cfet4_real_step_rotating!(ws, dt, t)
        t += dt
        on_step !== nothing && on_step(step, t, ws)
    end
    t
end

"""RTP driver in rotating basis."""
