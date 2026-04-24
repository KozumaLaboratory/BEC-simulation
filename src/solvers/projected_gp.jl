# --- P4.4: Projected / truncated-Wigner momentum cutoff ---
#
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
    apply_projected_gp!(ws, k_cut; smooth=false) -> Nothing

Zero out all Fourier components of ψ with |k| > k_cut. Works on GPU or CPU
via the existing FFT plans. `smooth=true` replaces the hard mask with a
cosine-tapered cutoff over [k_cut, 1.1·k_cut] for smoother artefacts.
"""
function apply_projected_gp!(
    ws::Workspace{N}, k_cut::Real;
    smooth::Bool = false,
) where {N}
    psi = ws.state.psi
    D = ws.spin_matrices.system.n_components
    n_pts = ws.grid.config.n_points
    plans = ws.fft_plans
    fft_buf = ws.state.fft_buf
    k_cut_sq = Float64(k_cut)^2

    # Build the mask once per call (on device matching ws.state.psi).
    k_squared = ws.grid.k_squared
    T = real(eltype(psi))

    if smooth
        k_taper_sq = (1.1 * k_cut)^2
    end

    for c = 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        fft_buf .= psi_c
        plans.forward * fft_buf
        if smooth
            # Cosine-tapered high-pass suppression
            k_taper_sq_t = T(k_taper_sq)
            k_cut_sq_t = T(k_cut_sq)
            @. fft_buf *= ifelse(
                k_squared <= k_cut_sq_t, one(T),
                ifelse(k_squared >= k_taper_sq_t, zero(T),
                    T(0.5) * (one(T) + cos(T(π) * (k_squared - k_cut_sq_t) /
                                                   (k_taper_sq_t - k_cut_sq_t)))),
            )
        else
            k_cut_sq_t = T(k_cut_sq)
            @. fft_buf *= (k_squared <= k_cut_sq_t)
        end
        plans.inverse * fft_buf
        psi_c .= fft_buf
    end
    nothing
end

"""
    projected_gp_callback(k_cut; smooth=false, every=1) -> Function

Construct an `on_step` callback for `run_simulation!` that projects every
`every` steps. Returns `(ws, step, n_steps) -> Nothing`.
"""
function projected_gp_callback(k_cut::Real; smooth::Bool = false, every::Int = 1)
    function (ws, step, _)
        step % every == 0 && apply_projected_gp!(ws, k_cut; smooth)
        nothing
    end
end
