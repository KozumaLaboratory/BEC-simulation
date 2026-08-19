# Dynamic structure factor S(k, ω) of a trapped spinor condensate, by real-time
# impulse response — the Bragg-spectroscopy predictor.
#
# WHY REAL TIME AND NOT LINEAR RESPONSE FROM THE BdG EIGENBASIS. #339 asks for
# ONE of the two paths, with the reason written down. This is the reason:
#
#   1. The BdG route needs the eigenbasis to be COMPLETE in ω at fixed k, not
#      just the lowest modes. A Bragg peak at momentum k sits on the stiff
#      density branch, `ω ≈ √(εk(εk+2c₀n))`, which at Eu production
#      (`c₀n ≈ 2343`) is far above anything an iterative low-mode solver
#      certifies. `trapped_bdg_frequencies` reaches the SOFT end and says so;
#      building S(k,ω) from it would silently truncate the spectral weight.
#      The complete eigenbasis is the dense path, and dense is `dim_cap = 4000`
#      against `2·32³·13 = 851,968` — the same wall that made this instrument
#      missing in the first place.
#   2. Real time needs no new operator, no eigensolver and no convergence
#      certificate: one unitary kick, then the ALREADY-GATED propagator. The
#      13-component 3D texture is handled because `split_step!` handles it.
#   3. It is the observable the experiment measures. A Bragg pulse imprints a
#      phase grating and the density response is read out; this computes exactly
#      that, so a disagreement with the lab is a physics disagreement rather
#      than a difference of definitions.
#
# The cost is spectral resolution instead of eigenvalue precision: the peak can
# only be located to `Δω = 2π/T`, so `omega_resolution` is returned and any
# quoted peak must carry it. That is the honest trade, and it is the reason the
# eigen path is kept for the soft end (where `Δω` would need an impractical `T`)
# and this one for the Bragg window.
#
# METHOD. The impulse (δ-pulse) limit of a Bragg lattice: `V(r,t) =
# amplitude·cos(k·r)·O·δ(t)` integrates to the unitary `exp(−i·amplitude·
# cos(k·r)·O)`, applied once at t=0. Evolving under the UNPERTURBED Hamiltonian
# and Fourier-transforming `δn_k(t) = ∫n(r,t)e^{−ik·r}` then gives peaks at the
# excitation frequencies with the dynamic structure factor as their weight —
# every ω in one run, instead of one continuous-drive run per ω.
#
# `O = 1` probes the density channel; `O = F_z` the longitudinal spin channel
# (both diagonal, so the kick stays a per-voxel phase). A spin roton lives in
# the second one, and the static `S(k)` that `_analyze_bragg_spectroscopy`
# returns is this quantity integrated over ω — which is why it cannot see a
# roton.

export bragg_response

"""
    bragg_response(ws, ψ0; k_vec, t_total, amplitude=1e-3, channel=:density, …)
        → NamedTuple

Dynamic structure factor of a trapped spinor condensate from a real-time
impulse response. `ws` must be a REAL-time workspace (`imaginary_time=false`);
its `dt` and Hamiltonian are used as-is, and `ws.state` is overwritten.

`k_vec` is the Bragg momentum (internal units, length `ndims`); on a periodic
box only the grid's own k-modes are commensurate — pass a multiple of `2π/L`
per axis or the response leaks across bins. `channel` is `:density` (kick
operator `1`) or `:spin_z` (kick operator `F_z`).

Returns `omega` (0 … Nyquist), `S_density` and `S_spin` (|FT|² of `δn_k(t)` and
`δF_{z,k}(t)`), the raw time series `t`, `n_k`, `fz_k`, the refined peak
locations `peak_omega_density` / `peak_omega_spin` with their weights, and:

- `omega_resolution = 2π/T` — **the width of one bin. A peak may not be quoted
  tighter than this** without saying that a parabolic sub-bin refinement was
  used (it is, and the refinement is ~0.1 bin only when the peak is isolated).
  With the default Hann window the effective main lobe is ~2 bins.
- `nyquist_omega = π/(dt·sample_every)` — spectral weight above it is aliased
  DOWN into the window, so a `peak_omega` near it is not to be trusted.
- `norm_drift`, `energy_drift` — propagator hygiene over the run. A response
  spectrum from a run with visible drift is measuring the integrator.
- `amplitude`, `channel`, `k_vec`, `lhy_active` — provenance. **Linearity is not
  checked here**: run twice at `amplitude` and `2·amplitude` and confirm the
  peak is unmoved and the weight scales by 4 (|FT|²). Without that control a
  "spectrum" may be a nonlinear artefact of too hard a kick.

The kick is unitary, so the norm is conserved exactly by construction and
`norm_drift` measures the propagator alone.
"""
function bragg_response(
    ws, ψ0;
    k_vec, t_total::Real, amplitude::Real=1e-3, channel::Symbol=:density,
    sample_every::Int=1, window::Symbol=:hann,
)
    channel in (:density, :spin_z) || throw(ArgumentError(
        "bragg_response: channel must be :density or :spin_z, got :$channel"))
    ws.sim_params.imaginary_time && throw(
        ArgumentError(
            "bragg_response: needs a real-time workspace (imaginary_time=false); " *
            "an imaginary-time step is not a time evolution and its 'spectrum' is meaningless",
        ),
    )
    dt = ws.sim_params.dt
    dt > 0 || throw(ArgumentError("bragg_response: dt must be > 0"))
    sample_every >= 1 || throw(ArgumentError("bragg_response: sample_every must be ≥ 1"))
    ndim = ndims(ws.grid.k_squared)
    length(k_vec) == ndim || throw(
        DimensionMismatch(
            "bragg_response: k_vec has length $(length(k_vec)), grid is $(ndim)D"),
    )

    n_pts = ntuple(d -> size(ψ0, d), ndim)
    sys = ws.spin_matrices.system
    D = sys.n_components
    mvals = Float64.(sys.m_values)          # c=1 ↦ m=F, c=D ↦ m=−F
    dV = cell_volume(ws.grid)

    # cos(k·r) and e^{−ik·r} on the grid, built once.
    kr = zeros(Float64, n_pts)
    for d in 1:ndim
        shp = ntuple(i -> i == d ? n_pts[d] : 1, ndim)
        kr .+= k_vec[d] .* reshape(ws.grid.x[d], shp)
    end
    kick = cos.(kr)
    probe = cis.(-kr)

    # Unitary impulse. Both kick operators are diagonal, so this is a per-voxel
    # phase: exp(−i·A·cos(k·r)·m) with m = 1 (density) or m = m_values[c] (spin_z).
    ψ = copy(ψ0)
    for c in 1:D
        w = channel === :density ? 1.0 : mvals[c]
        w == 0.0 && continue
        idx = _component_slice(ndim, n_pts, c)
        view(ψ, idx...) .*= cis.(-amplitude .* w .* kick)
    end

    copyto!(ws.state.psi, ψ)
    ws.state.t = 0.0
    n_steps = max(round(Int, t_total / dt), 2 * sample_every)
    norm0 = real(sum(abs2, ws.state.psi)) * dV
    e0 = total_energy(ws)

    ts = Float64[]
    nk = ComplexF64[]
    fzk = ComplexF64[]
    function _sample!()
        push!(ts, ws.state.t)
        acc_n = zero(ComplexF64)
        acc_f = zero(ComplexF64)
        for c in 1:D
            # Fused: no |ψ_c|² temporary. The sampler runs once per step, and at
            # 32³ × 13 a materialised density slice is 0.26 MB — 10⁴ steps × 13
            # components of that is GC traffic measured in tens of GB.
            # `mapreduce` over two arrays also stays GPU-legal (no scalar
            # indexing), which a `zip` generator would not.
            s = mapreduce((x, p) -> abs2(x) * p, +,
                view(ws.state.psi, _component_slice(ndim, n_pts, c)...), probe)
            acc_n += s
            acc_f += mvals[c] * s
        end
        push!(nk, acc_n * dV)
        push!(fzk, acc_f * dV)
    end
    _sample!()
    for step in 1:n_steps
        split_step!(ws)
        step % sample_every == 0 && _sample!()
    end

    norm_drift = abs(real(sum(abs2, ws.state.psi)) * dV - norm0) / max(norm0, 1e-30)
    e1 = total_energy(ws)
    energy_drift = abs(e1 - e0) / max(abs(e0), 1e-30)

    dt_s = dt * sample_every
    om, S_n = _response_spectrum(nk, dt_s, window)
    _, S_f = _response_spectrum(fzk, dt_s, window)
    pk_n, w_n = _refine_peak(om, S_n)
    pk_f, w_f = _refine_peak(om, S_f)

    (;
        omega=om, S_density=S_n, S_spin=S_f,
        t=ts, n_k=nk, fz_k=fzk,
        peak_omega_density=pk_n, peak_weight_density=w_n,
        peak_omega_spin=pk_f, peak_weight_spin=w_f,
        peak_contrast_density=_peak_contrast(S_n), peak_contrast_spin=_peak_contrast(S_f),
        omega_resolution=2π / (length(ts) * dt_s),
        nyquist_omega=π / dt_s,
        norm_drift, energy_drift,
        amplitude=Float64(amplitude), channel, k_vec=collect(Float64, k_vec),
        lhy_active=_lhy_is_active(ws.lhy), n_samples=length(ts),
    )
end

# |FT|² of a mean-subtracted, windowed time series, on the non-negative ω half.
# The mean subtraction removes the STATIC structure factor: for a trapped cloud
# `n_k` at the probe momentum is dominated by the equilibrium profile, which is
# a DC peak orders of magnitude above the response and would otherwise leak
# across the whole window.
function _response_spectrum(series::Vector{ComplexF64}, dt_s::Real, window::Symbol)
    n = length(series)
    y = series .- (sum(series) / n)
    if window === :hann
        for j in 1:n
            y[j] *= 0.5 * (1 - cos(2π * (j - 1) / n))
        end
    elseif window !== :none
        throw(ArgumentError("bragg_response: window must be :hann or :none"))
    end
    Y = fft(y)
    half = n ÷ 2 + 1
    ω = [2π * (j - 1) / (n * dt_s) for j in 1:half]
    ω, abs2.(@view Y[1:half])
end

# Peak / median weight: "is there a line here at all". A channel the kick does
# not couple to returns a spectrum that is numerically zero, and
# `_refine_peak` on it reports the argmax of roundoff — a confident ω with a
# 1e-27 weight. The contrast is what separates that from a real line, and 0/0 is
# reported as 0.0 (no line) rather than propagating a NaN into a verdict.
function _peak_contrast(S::Vector{Float64})
    length(S) >= 4 || return 0.0
    body = sort(S[2:end])                 # median, not mean: the line itself
    n = length(body)                      # inflates a mean baseline
    med = isodd(n) ? body[(n + 1) ÷ 2] : (body[n ÷ 2] + body[n ÷ 2 + 1]) / 2
    med > 0 && isfinite(med) ? body[end] / med : 0.0
end

# Parabolic sub-bin refinement of the largest non-DC peak. Returns
# (ω_peak, weight); (NaN, 0.0) when the spectrum has no interior maximum.
function _refine_peak(ω::Vector{Float64}, S::Vector{Float64})
    length(S) >= 4 || return (NaN, 0.0)
    j = argmax(@view S[2:end]) + 1
    (j == 2 || j == length(S)) && return (ω[j], S[j])
    y0, ym, yp = S[j], S[j - 1], S[j + 1]
    den = ym - 2y0 + yp
    δ = abs(den) > 1e-30 ? 0.5 * (ym - yp) / den : 0.0
    (ω[j] + clamp(δ, -1.0, 1.0) * (ω[2] - ω[1]), y0)
end
