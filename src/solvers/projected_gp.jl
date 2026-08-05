# --- P4.4: Projected / truncated-Wigner momentum cutoff ---

export apply_projected_gp!, projected_gp_callback

# Projected GP (PGP) suppresses all Fourier modes above a cutoff `k_cut`
# after each split-step iteration. Used both as a numerical regulariser
# (removes high-k aliasing from nonlinear terms) and as a physical model
# of a coarse-grained "classical field" region separated from the thermal
# cloud.
#
# Usage:
#     apply_projected_gp!(ws, k_cut)
# Call this after each split_step! — or pass it as the `on_step` callback
# to `run_simulation!` / `find_ground_state`.

"""
    apply_projected_gp!(ws, k_cut; smooth=false) -> Float64

Zero out all Fourier components of ψ with |k| > k_cut. Works on GPU or CPU
via the existing FFT plans. `smooth=true` replaces the hard mask with a
cosine-tapered cutoff over [k_cut, 1.1·k_cut] for smoother artefacts.

Returns the weight the projector REMOVED, in atom-number units (`∫|ψ|²dV`),
accumulated in k-space while the transform is already in hand.

That is the definition of the quantity, and it is also the only way to measure
it accurately. Differencing `∫|ψ|²` across the call instead costs a
catastrophic cancellation between two nearly equal O(N) sums, and — since the
projector is an FFT round-trip rather than a literal no-op — leaves the
round-trip error, ~1e-15 relative, as the floor. Measured here the floor is the
residual amplitude in already-masked modes, ~1e-16 *squared*, so re-projecting
an already-projected field returns ~1e-30 rather than ~1e-15.
"""
function apply_projected_gp!(
    ws::Workspace{N}, k_cut::Real;
    smooth::Bool=false,
) where {N}
    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    plans = ws.fft_plans
    fft_buf = ws.state.fft_buf
    k_cut_sq = Float64(k_cut)^2

    # Build the mask once per call (on device matching ws.state.psi). `ws.grid.k_squared`
    # is a host Array even for a GPU workspace, so a bare broadcast against a CuArray
    # `fft_buf` fails (non-bitstype kernel arg); move it to the psi device first — the
    # same idiom as hessian.jl / newton_cg.jl. No-op on CPU.
    k_squared = _to_device(ws.backend, ws.grid.k_squared)
    T = real(eltype(psi))

    # Hoisted, and concrete. Assigning these inside the `if smooth` branches put
    # them in a `Core.Box`, and closing over `T` (a Type) is not isbits either —
    # both make the mapreduce closure a non-bitstype kernel argument on CUDA.
    k_cut_sq_t = T(k_cut_sq)
    k_taper_sq_t = smooth ? T((1.1 * k_cut)^2) : k_cut_sq_t
    zero_t = zero(k_cut_sq_t)
    one_t = one(k_cut_sq_t)
    half_t = T(0.5)
    pi_t = T(π)
    inv_span = smooth ? one_t / (k_taper_sq_t - k_cut_sq_t) : zero_t

    removed_k = 0.0
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        fft_buf .= psi_c
        plans.forward * fft_buf
        if smooth
            # Cosine-tapered high-pass suppression. Suppressed weight is
            # |f|²(1 − w²), with w the amplitude taper.
            removed_k += Float64(
                mapreduce(
                    (f, k2) -> begin
                        w = if k2 <= k_cut_sq_t
                            one_t
                        elseif k2 >= k_taper_sq_t
                            zero_t
                        else
                            half_t * (one_t + cos(pi_t * (k2 - k_cut_sq_t) * inv_span))
                        end
                        abs2(f) * (one_t - w * w)
                    end,
                    +, fft_buf, k_squared; init=zero_t,
                ),
            )
            @. fft_buf *= ifelse(
                k_squared <= k_cut_sq_t, one_t,
                ifelse(k_squared >= k_taper_sq_t, zero_t,
                    half_t * (one_t + cos(pi_t * (k_squared - k_cut_sq_t) * inv_span))),
            )
        else
            removed_k += Float64(
                mapreduce(
                    (f, k2) -> k2 <= k_cut_sq_t ? zero_t : abs2(f),
                    +, fft_buf, k_squared; init=zero_t,
                ),
            )
            @. fft_buf *= (k_squared <= k_cut_sq_t)
        end
        plans.inverse * fft_buf
        psi_c .= fft_buf
    end
    # Parseval: the forward plan is unnormalised, so sum|F|² = prod(n)·sum|ψ|².
    removed_k / prod(n_pts) * cell_volume(ws.grid)
end

"""
    projected_gp_callback(k_cut; smooth=false, every=1) -> Function

Construct an `on_step` callback for `run_simulation!` that projects every
`every` steps. Returns `(ws, step, n_steps) -> Nothing`.
"""
function projected_gp_callback(k_cut::Real; smooth::Bool=false, every::Int=1)
    # Accept SimulationCallbacks 4-arg `(ws, step, times, energies)` as well
    # as the older 3-arg `(ws, step, n_steps)` direct-callable convention.
    function (ws, step, args...)
        step % every == 0 && apply_projected_gp!(ws, k_cut; smooth)
        nothing
    end
end
