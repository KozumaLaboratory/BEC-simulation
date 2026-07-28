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

export apply_orszag_2_3_filter!, safe_k_cut_boundary, dt_max_for_k_cut

"""
    safe_k_cut_boundary(n_grid::Int, box_L::Float64) -> Float64

The maximum `DEALIAS_K_CUTOFF` value (in physical k units) for which
the F filter fully suppresses bilinear aliasing on an `n_grid`-point
axis of length `box_L`.

Derivation: a bilinear F mode at original per-axis `|k_d|` in
`(k_Nyq, 2K)` folds via FFT wraparound to `|k_d|` in `(2·k_Nyq - 2K, k_Nyq)`.
The F filter at cutoff `K` zeros only folded modes with `|k_d| > K`.
Modes with original `K_alias > 2·k_Nyq - K` fold to `|k_d| < K` and
escape the filter. For zero escape we need `2K ≤ 2·k_Nyq - K`, i.e.
`K ≤ 2·k_Nyq/3`.

At larger `K`, the ΔF_z answer becomes non-monotonic in K (alias
contamination), so the diagnostic / production rule is:
`DEALIAS_K_CUTOFF[] ≤ safe_k_cut_boundary(N, L)`.

Examples (box L=12):
- N=64  → safe cutoff ≤ 11.17  (default n÷3·dk = 11.0 is just inside)
- N=96  → safe cutoff ≤ 16.76  (default n÷3·dk = 16.76 is at boundary)
- N=128 → safe cutoff ≤ 22.34
- N=192 → safe cutoff ≤ 33.51
"""
safe_k_cut_boundary(n_grid::Int, box_L::Float64) = 2 * (π * n_grid / box_L) / 3

"""
    dt_max_for_k_cut(k_cut::Float64; safety::Float64=10.0) -> Float64

Maximum `dt` for the Strang split-step propagator at a given `k_cut`,
above which the dt²·k_cut² truncation error contaminates the dynamics.

Derivation: the leading Strang commutator error is
  E_step ~ (dt³/24) · ([V,[V,K]] + 2[K,[V,K]]) ψ
At plane wave ψ_k = e^{ikx}, [K,[V,K]] ψ_k ~ k²·V_pre · ψ_k, giving
local error ~ dt³·k². Over T steps, global error ~ T·dt²·k². For the
Eu Hamiltonian-only dynamics (T=6.28, c_dd≈121) the empirical pre-factor
is ~5, so the heuristic safe bound is `dt·k_cut ≲ 1/safety` with
`safety=10` (~10% accuracy) by default.

L4 verification empirical data:

| dt    | k_cut | dt·k_cut | ΔF_z observed | grid-converged? |
|-------|-------|---------:|--------------:|:----------------|
| 0.01  | 11    |    0.110 | 0.008857      | yes (5 digit)   |
| 0.005 | 16    |    0.080 | 0.008856      | yes (5 digit)   |
| 0.01  | 16    |    0.160 | 0.00761       | NO (15% off)    |
| 0.01  | 20    |    0.200 | 0.00553       | NO              |

The product `dt·k_cut` should stay below ~0.1 for the dynamics to
clear Strang error at this DDI strength.

Examples (safety=10 default):
- `dt_max_for_k_cut(11.0)` ≈ 0.00909  (use dt ≤ 0.009 for k_cut=11)
- `dt_max_for_k_cut(16.0)` ≈ 0.00625  (use dt ≤ 0.006 for k_cut=16)
- `dt_max_for_k_cut(20.0)` ≈ 0.00500  (use dt ≤ 0.005 for k_cut=20)
- `dt_max_for_k_cut(16.0; safety=100)` ≈ 0.000625  (1% accuracy)
"""
dt_max_for_k_cut(k_cut::Float64; safety::Float64=10.0) = 1.0 / (safety * k_cut)

"""
Global toggle for Orszag 2/3-rule dealiasing in `split_step!` and
`split_step_midpoint!`. Set to `true` before running Eu DDI dynamics
that need clean grid convergence (L4 verification suite, production
Eu EdH); leave `false` for legacy bit-exact behaviour.
"""
const DEALIAS_2_3_ENABLED = Ref(false)

"""
Optional physical-k cutoff override. When `nothing` (default), the
filter uses the standard grid-dependent (n_d ÷ 3) cutoff per axis,
yielding a different effective bandwidth at each grid resolution.
When set to a positive Float64 `k_cut`, the filter zeros modes with
`|k_d| > k_cut` (in the same physical units as `grid.k`), making
all grids that contain `k_cut` within their Nyquist range agree on
the captured bandwidth. This is the grid-convergence diagnostic
mode: pick `k_cut` below the smallest grid's Nyquist so every grid
yields the same effective physics window.

Usage:
    SpinorBEC.DEALIAS_K_CUTOFF[] = 11.0   # on an L=12 box, the same
                                          # bandwidth as the N=64 default
    SpinorBEC.DEALIAS_K_CUTOFF[] = nothing  # back to (n_d ÷ 3) default

The cutoff is per-axis (|k_x| and |k_y| and |k_z| each ≤ k_cut),
matching the (n_d ÷ 3) default's per-axis structure. Being stated in
physical k, it is meaningful only against a box: the same number is a
different fraction of the band on a different `box_size`, so the box
travels to the mask builder from the `Grid` (ψ filter) and from
`DDIParams.box_size` (F filter) rather than being assumed.
"""
const DEALIAS_K_CUTOFF = Ref{Union{Nothing, Float64}}(nothing)

# Per-grid-shape mask cache. Stored as plain Float64 arrays so they
# broadcast onto the Complex FFT output without type promotion.
# Key includes the cutoff so toggling DEALIAS_K_CUTOFF rebuilds correctly.
const _ORSZAG_MASK_CACHE = Dict{Tuple, Any}()

"""
    _get_orszag_mask(n_pts::NTuple{N,Int}, box::NTuple{N,Float64}) -> Array{Float64,N}

Return a cached real-valued mask of shape `n_pts`. Value 1.0 at modes
that should be KEPT, 0.0 at modes that should be zeroed. Per axis the
cutoff is `n_d ÷ 3`: any axis index with `min(i-1, n-i+1) > n_d ÷ 3`
zeros the full slab along that axis.

`box` is the physical box length per axis. It is unused by the default
`n_d ÷ 3` rule (that cutoff lives in index space and is box-independent)
and load-bearing for the `DEALIAS_K_CUTOFF[]` override, which is stated
in physical k and therefore only means something against a box.
"""
function _get_orszag_mask(n_pts::NTuple{N, Int}, box::NTuple{N, Float64}) where {N}
    _get_orszag_mask(n_pts, DEALIAS_K_CUTOFF[], box)
end

function _get_orszag_mask(n_pts::NTuple{N, Int},
    k_cut_override::Union{Nothing, Float64},
    box::NTuple{N, Float64}) where {N}
    # The cache key includes k_cut_override and the box so the mask rebuilds
    # when DEALIAS_K_CUTOFF[] changes or the same grid shape is used on a
    # different box.
    key = (n_pts, k_cut_override, box)
    haskey(_ORSZAG_MASK_CACHE, key) && return _ORSZAG_MASK_CACHE[key]::Array{Float64, N}
    mask = ones(Float64, n_pts)
    if k_cut_override === nothing
        # Default: (n_d ÷ 3) per-axis cutoff in index space.
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
    else
        # Fixed physical-k cutoff: zero modes with |k_d| > k_cut_override,
        # where |k_d| is measured against the ACTUAL box length on that axis.
        for d in 1:N
            n = n_pts[d]
            dk = 2π / box[d]
            for i in 1:n
                k_idx = i - 1 <= n ÷ 2 ? (i - 1) : (i - 1 - n)
                k_val = abs(k_idx) * dk
                if k_val > k_cut_override
                    idx_tuple = ntuple(N) do dd
                        dd == d ? (i:i) : (1:n_pts[dd])
                    end
                    @views mask[idx_tuple...] .= 0.0
                end
            end
        end
    end
    _ORSZAG_MASK_CACHE[key] = mask
    mask
end

"""
    apply_orszag_2_3_filter!(psi, fft_plans, n_components, ndim, box)

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
    box::NTuple{M, Float64},
) where {M}
    n_pts = ntuple(d -> size(psi, d), ndim)
    mask = _get_orszag_mask(n_pts, box)
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
    apply_orszag_2_3_F_filter!(F_pad, n_pts, box) -> nothing

Apply the Orszag 2/3-rule k-space filter to the first `n_pts` entries
of the bilinear spin-density buffer `F_pad`. The remainder (the
convolution zero-pad) is untouched. Uses a cached complex N-grid
FFT-plans + scratch buffer keyed by `(typeof(F_pad), n_pts)`.

Call once per spin component (Fx, Fy, Fz) after the bilinear
`_compute_spin_density!` and before the rfft convolution.
"""
function apply_orszag_2_3_F_filter!(
    F_pad::AbstractArray{T, N}, n_pts::NTuple{N, Int}, box::NTuple{N, Float64}
) where {T <: Real, N}
    _check_safe_k_cut(n_pts, box)
    buf, plans = _get_orszag_F_filter_resources(F_pad, n_pts)
    mask = _get_orszag_mask(n_pts, box)
    mask_dev = _to_psi_device(buf, mask)
    idx = ntuple(d -> 1:n_pts[d], N)
    @views buf .= F_pad[idx...]
    plans.forward * buf
    buf .*= mask_dev
    plans.inverse * buf
    @views F_pad[idx...] .= real.(buf)
    nothing
end

"""
Runtime check: if `DEALIAS_K_CUTOFF[]` exceeds the safe boundary
`2·k_Nyq/3` at the current grid, the F filter cannot fully suppress
bilinear aliasing — the result will be contaminated and (per L4
k-scan data) non-monotonic in `k_cut`. Emit a single `@warn` on first
violation so the user sees it without spam.

The binding axis is the one with the smallest `k_Nyq_d = π·n_d/L_d`,
which is a property of the RATIO `n_d/L_d` — not of `n_d` alone. A
long axis with many points can still be the loose one.
"""
function _check_safe_k_cut(n_pts::NTuple{N, Int}, box::NTuple{N, Float64}) where {N}
    k_cut = DEALIAS_K_CUTOFF[]
    k_cut === nothing && return nothing
    d_bind = argmin(ntuple(d -> n_pts[d] / box[d], N))
    k_safe = safe_k_cut_boundary(n_pts[d_bind], box[d_bind])
    if k_cut > k_safe + 1e-9
        @warn "DEALIAS_K_CUTOFF[] = $k_cut exceeds safe boundary $(round(k_safe; digits=4)) " *
            "(= 2·k_Nyq/3 on the binding axis $d_bind: n=$(n_pts[d_bind]), " *
            "L=$(box[d_bind])); F-filter cannot fully suppress bilinear aliasing — " *
            "answer will be contaminated. Reduce k_cut or use a larger grid." maxlog=1
    end
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
    # Key by objectid(mask_host) so swapping the host mask (e.g. when
    # DEALIAS_K_CUTOFF[] changes) invalidates the cached device copy.
    key = (typeof(psi), size(mask_host), objectid(mask_host))
    haskey(_ORSZAG_MASK_DEV_CACHE, key) && return _ORSZAG_MASK_DEV_CACHE[key]
    mask_dev = similar(psi, Float64, size(mask_host))
    copyto!(mask_dev, mask_host)
    _ORSZAG_MASK_DEV_CACHE[key] = mask_dev
    mask_dev
end
