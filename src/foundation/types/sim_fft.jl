# --- Simulation params, mutable state, FFT plans ---
#
# `SimParams` packages the top-level dt/n_steps/save_every plus the two
# rotating-frame angular velocities. `SimState{N,A,B,T}` is the one
# mutable state container the solver mutates each step (ψ, fft buffer,
# spin-rotation scratch, t, step). FFT/rFFT plan structs and the
# Coriolis / batched-kinetic / absorbing-boundary auxiliaries live
# here too; they're pure-data caches the workspace constructor builds
# once.

# --- Simulation Parameters ---

struct SimParams
    dt::Float64
    n_steps::Int
    imaginary_time::Bool
    normalize_every::Int
    save_every::Int
    rotating_frame_omega::Float64
    # Spin rotating-frame rotation rate (around z, dimensionless ω_ref units).
    # When ≠ 0, the simulator evolves ψ_rot = exp(+i ω_R F_z t) ψ_lab under
    # H_rot = U H_lab U† + ω_R F_z. The fast linear Zeeman -p F_z is cancelled
    # by choosing ω_R = p; transverse Bx,By rotate into the RF coords,
    # becoming static if their drive frequency matches ω_R.
    # Caveats: requires secular DDI (Q_zz only) for correctness; transverse
    # F_x,F_y observables in the lab frame need post-hoc U† transformation.
    spin_rotating_frame_omega::Float64
end

SimParams(dt, n_steps, imaginary_time, normalize_every, save_every) = SimParams(
    dt, n_steps, imaginary_time, normalize_every, save_every, 0.0, 0.0
)

SimParams(dt, n_steps, imaginary_time, normalize_every, save_every, rotating_frame_omega) = SimParams(
    dt, n_steps, imaginary_time, normalize_every, save_every,
    rotating_frame_omega, 0.0)

function SimParams(;
    dt::Float64,
    n_steps::Int,
    imaginary_time::Bool=false,
    normalize_every::Int=imaginary_time ? 1 : 0,
    save_every::Int=max(1, n_steps ÷ 100),
    rotating_frame_omega::Float64=0.0,
    spin_rotating_frame_omega::Float64=0.0,
)
    dt > 0 || throw(ArgumentError("dt must be positive"))
    n_steps > 0 || throw(ArgumentError("n_steps must be positive"))
    SimParams(
        dt,
        n_steps,
        imaginary_time,
        normalize_every,
        save_every,
        rotating_frame_omega,
        spin_rotating_frame_omega,
    )
end

# --- Simulation State (mutable) ---

mutable struct SimState{N, A <: AbstractArray, B <: AbstractArray, T <: AbstractFloat}
    psi::A              # wavefunction: spatial dims... × n_components (eltype Complex{T})
    fft_buf::B          # spatial-only buffer for FFT (same device + eltype as psi)
    psi_scratch::A      # full-size scratch (same shape as psi); avoids per-call
    # similar(psi) in apply_uniform_spin_rotation! and other
    # whole-ψ broadcast ops on the spin axis. Reusable across
    # any operator that does ψ_new = R · ψ in place.
    t::Float64
    step::Int
end

# Convenience: T is always real(eltype(psi)). Use this so callers don't
# need to specify T manually.
SimState{N, A, B}(psi::A, fft_buf::B, psi_scratch::A, t, step) where {N, A, B} = SimState{
    N, A, B, real(eltype(A))
}(
    psi, fft_buf, psi_scratch, t, step
)

# --- FFT Plans ---

struct FFTPlans{P, IP}
    forward::P
    inverse::IP
end

# --- rFFT Plans (for DDI on real-valued spin density) ---

struct RFFTPlans{N, RP, IRP}
    forward::RP
    inverse::IRP
    rk_shape::NTuple{N, Int}
end

# --- Batched Kinetic Cache ---

struct BatchedKineticCache{P, IP, KP <: AbstractArray}
    forward::P
    inverse::IP
    kinetic_phase_bc::KP
end

# --- Coriolis Cache (in-place FFT plans for 3-shear decomposition) ---

struct CoriolisCache{P1, IP1, P2, IP2}
    fwd_dim1::P1
    inv_dim1::IP1
    fwd_dim2::P2
    inv_dim2::IP2
end

# --- Absorbing Boundary ---

struct AbsorbingBoundary
    strength::Float64
    width::Float64
    power::Int
end

AbsorbingBoundary(; strength::Float64, width::Float64, power::Int=2) = AbsorbingBoundary(
    strength, width, power
)
