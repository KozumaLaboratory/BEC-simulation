# --- Orszag 2/3-rule pseudospectral dealiasing ---
#
# The bilinear spin density F_α(r) = ψ†(r) F̂_α ψ(r), used by both
# `apply_spin_mixing_step!` (c₁·⟨F⟩·F̂) and the DDI step (Φ_α =
# c_dd·Q_αβ⊛F_β), has 2× the Fourier bandwidth of ψ. Sampled on the
# same N-point grid as ψ, the high-k modes (k_Nyq, 2k_Nyq) fold back
# via periodic-boundary aliasing.
#
# Diagnosis (2026-05-22, runs/verification_suite L4 Eu Hamiltonian-only):
# energy_final at grids 32, 48, 64, 96, 128 = 54.9, 54.9, 265.7, 272.7,
# 321.7 (96→128 = +18 %, NOT converged). L5 operator-RHS probes
# (commit AE-PENDING) confirmed _compute_spin_density!, Q tensor, and
# convolution machinery are all exact to machine precision — the
# divergence is pure sampling-Nyquist.
#
# Standard pseudospectral fix: apply Orszag's 2/3-rule k-space filter
# to ψ before each Strang substep, keeping only modes with
# |k_d_idx| ≤ n_d/3 per axis. The bilinear then has effective bandwidth
# (4/3)·k_Nyq_d, and aliased modes fall in the (2/3, 1)·k_Nyq_d band
# which has been pre-zeroed.
#
# Activation: `SpinorBEC.DEALIAS_2_3_ENABLED[] = true` before running
# dynamics. Off by default for backward compatibility; once the L4
# grid-convergence regression is in place this will graduate to a
# Workspace field + YAML knob.

export apply_orszag_2_3_filter!

"""
Global toggle for Orszag 2/3-rule dealiasing in `split_step!` and
`split_step_midpoint!`. Set to `true` before running Eu DDI dynamics
that need clean grid convergence (L4 verification suite, production
Eu EdH); leave `false` for legacy bit-exact behaviour.
"""
const DEALIAS_2_3_ENABLED = Ref(false)

# Per-grid-shape mask cache. Stored as plain Float64 arrays so they
# broadcast onto the Complex FFT output without type promotion.
const _ORSZAG_MASK_CACHE = Dict{Tuple, Any}()

"""
    _get_orszag_mask(n_pts::NTuple{N,Int}) -> Array{Float64,N}

Return a cached real-valued mask of shape `n_pts`. Value 1.0 at modes
that should be KEPT, 0.0 at modes that should be zeroed. Per axis the
cutoff is `n_d ÷ 3`: any axis index with `min(i-1, n-i+1) > n_d ÷ 3`
zeros the full slab along that axis.
"""
function _get_orszag_mask(n_pts::NTuple{N, Int}) where {N}
    haskey(_ORSZAG_MASK_CACHE, n_pts) && return _ORSZAG_MASK_CACHE[n_pts]::Array{Float64, N}
    mask = ones(Float64, n_pts)
    for d in 1:N
        n = n_pts[d]
        cutoff = n ÷ 3
        for i in 1:n
            k_abs_idx = min(i - 1, n - (i - 1))
            if k_abs_idx > cutoff
                idx_tuple = ntuple(N) do dd
                    dd == d ? (i:i) : (1:n_pts[dd])
                end
                @views mask[idx_tuple...] .= 0.0
            end
        end
    end
    _ORSZAG_MASK_CACHE[n_pts] = mask
    mask
end

"""
    apply_orszag_2_3_filter!(psi, fft_plans, n_components, ndim)

Apply the Orszag 2/3-rule k-space filter to `psi` in place. Per axis,
zeros all Fourier modes with `|k_idx| > n_d ÷ 3`. Cost per call:
`n_components` forward + `n_components` inverse N-grid in-place FFTs.

Effect on physics: ψ is bandlimited to (2/3) k_Nyq per axis. Bilinear
F_α has bandwidth (4/3) k_Nyq; aliased modes (k_Nyq, 4/3·k_Nyq) fold
into (2/3, 1)·k_Nyq which is zeroed in ψ already.

Side effects: small atom-number drift (high-k content of ψ is dropped
each call). For a ψ already concentrated below 2/3·k_Nyq (the usual
case for harmonic-trap GS), drift is negligible.
"""
function apply_orszag_2_3_filter!(
    psi::AbstractArray{<:Complex},
    fft_plans::FFTPlans,
    n_components::Int,
    ndim::Int,
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    mask = _get_orszag_mask(n_pts)
    # Match the device of `psi` (CPU Array → CPU mask; CuArray → device mask).
    # The mask is per-grid-shape cached; we promote to device via similar+copy.
    mask_dev = _to_psi_device(psi, mask)
    scratch = similar(psi, n_pts)
    for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        @views scratch .= psi[idx...]
        fft_plans.forward * scratch
        scratch .*= mask_dev
        fft_plans.inverse * scratch
        @views psi[idx...] .= scratch
    end
    nothing
end

# --- Full-2/3 rule companion: F filter on the bilinear spin density ---
#
# ψ-only filter at (2/3)·k_Nyq leaves bilinear F with bandwidth (4/3)·k_Nyq;
# the residual aliasing in (1, 4/3)·k_Nyq folds into (−1/3, 0)·k_Nyq and
# contaminates low-k F. Filtering F at (2/3)·k_Nyq AFTER the bilinear
# completes the standard pseudospectral 2/3 rule.
#
# F_pad shape: 2N-extended (for non-periodic convolution wraparound
# protection in DDI). The bilinear is computed in the first n_pts entries;
# the rest is zero (the convolution-pad). We filter only the first n_pts
# on the N-grid via a cached complex N-grid FFT-plans + scratch buffer,
# then write back the real part. The convolution-pad stays zero.

const _ORSZAG_F_FILTER_RESOURCES = Dict{Tuple, Any}()

function _get_orszag_F_filter_resources(F_pad_template::AbstractArray{T, N},
    n_pts::NTuple{N, Int}) where {T <: Real, N}
    key = (typeof(F_pad_template), n_pts)
    cached = get(_ORSZAG_F_FILTER_RESOURCES, key, nothing)
    cached !== nothing && return cached::Tuple{AbstractArray, FFTPlans}
    buf = similar(F_pad_template, Complex{T}, n_pts...)
    fwd = plan_fft!(buf)
    inv = plan_ifft!(buf)
    plans = FFTPlans(fwd, inv)
    result = (buf, plans)
    _ORSZAG_F_FILTER_RESOURCES[key] = result
    result
end

"""
    apply_orszag_2_3_F_filter!(F_pad, n_pts) -> nothing

Apply the Orszag 2/3-rule k-space filter to the first `n_pts` entries
of the bilinear spin-density buffer `F_pad`. The remainder (the
convolution zero-pad) is untouched. Uses a cached complex N-grid
FFT-plans + scratch buffer keyed by `(typeof(F_pad), n_pts)`.

Call once per spin component (Fx, Fy, Fz) after the bilinear
`_compute_spin_density!` and before the rfft convolution.
"""
function apply_orszag_2_3_F_filter!(
    F_pad::AbstractArray{T, N}, n_pts::NTuple{N, Int}
) where {T <: Real, N}
    buf, plans = _get_orszag_F_filter_resources(F_pad, n_pts)
    mask = _get_orszag_mask(n_pts)
    mask_dev = _to_psi_device(buf, mask)
    idx = ntuple(d -> 1:n_pts[d], N)
    @views buf .= F_pad[idx...]
    plans.forward * buf
    buf .*= mask_dev
    plans.inverse * buf
    @views F_pad[idx...] .= real.(buf)
    nothing
end

# Cache the device-resident mask per (psi-eltype, n_pts) so we copy host→device once.
const _ORSZAG_MASK_DEV_CACHE = Dict{Tuple, Any}()

"""
    _to_psi_device(psi, mask_host) -> mask_device

Return a mask array on the same device as `psi`. For CPU `psi` returns
the host mask unchanged; for CuArray `psi` returns a cached CuArray
copy. Cached per (eltype, shape) so each grid pays the host→device
copy only once.
"""
function _to_psi_device(psi::AbstractArray, mask_host::Array{Float64})
    key = (typeof(psi), size(mask_host))
    haskey(_ORSZAG_MASK_DEV_CACHE, key) && return _ORSZAG_MASK_DEV_CACHE[key]
    mask_dev = similar(psi, Float64, size(mask_host))
    copyto!(mask_dev, mask_host)
    _ORSZAG_MASK_DEV_CACHE[key] = mask_dev
    mask_dev
end
