export prepare_kinetic_phase, apply_kinetic_step!, apply_kinetic_step_batched!
export apply_diagonal_potential_step!

function prepare_kinetic_phase(
    grid::Grid{N, T},
    dt::Float64;
    imaginary_time::Bool=false,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    half = U(0.5)
    dt_u = U(dt)
    itv = Val(imaginary_time)
    Complex{U}.(@. wick_phase(-half * grid.k_squared * dt_u, itv))
end

function apply_kinetic_step!(
    psi::AbstractArray{<:Complex},
    fft_buf::AbstractArray{<:Complex},
    kinetic_phase::AbstractArray{<:Number},
    plans::FFTPlans,
    n_components::Int,
    ndim::Int,
)
    n_pts = ntuple(d -> size(psi, d), ndim)

    for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)

        fft_buf .= psi_view
        plans.forward * fft_buf
        fft_buf .*= kinetic_phase
        plans.inverse * fft_buf
        psi_view .= fft_buf
    end
    nothing
end

function apply_diagonal_potential_step!(
    psi::AbstractArray{<:Complex},
    V_trap::AbstractArray{<:AbstractFloat},
    zeeman_diag,
    c0::Float64,
    dt_frac::Float64,
    n_components::Int,
    ndim::Int,
    density_buf::AbstractArray{<:AbstractFloat};
    imaginary_time::Bool=false,
    c_lhy::Float64=0.0,
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    _total_density!(density_buf, psi, n_components, ndim, n_pts)
    # NOT GENERALIZABLE: ITP-only shift `zee_shift = min(zeeman_diag)` prevents exp overflow.
    # Reason: math, performance
    # Why: imaginary-time propagator is exp(-(E_m - μ_ref) dt); without subtracting
    #   min(E_m) the largest-|E_m| component grows like exp(50) ~ 1e21 per step
    #   and overflows F64 in ~10 steps for typical p (linear Zeeman). The shift is
    #   a constant rephasing that cancels across components, does NOT bias ψ.
    #   Skipped in real-time (cis is bounded).
    # See: src/solvers/ground_state.jl `_ITP_EXPONENT_LIMIT` guard
    zee_shift = imaginary_time ? minimum(zeeman_diag) : 0.0
    # ONE statement of the diagonal Hamiltonian, not four. Until 2026-08-19 this
    # loop carried the full expression in each of {imaginary, real} × {LHY off,
    # LHY on}, so the most-executed term in the simulator was written out four
    # times with nothing checking that the copies agreed. `zee_shift` is 0.0 in
    # real time, which is what lets the Wick branch collapse; adding `c_lhy` to
    # the sum when it is zero is a no-op, so the LHY branch collapses too — and
    # the `c_lhy == 0.0` arm survives only to skip the `sqrt` broadcast.
    itv = Val(imaginary_time)
    for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        zee_rel = zeeman_diag[c] - zee_shift
        if c_lhy == 0.0
            @. psi_view *= wick_phase(
                -(V_trap + zee_rel + c0 * density_buf) * dt_frac, itv)
        else
            @. psi_view *= wick_phase(
                -(
                    V_trap +
                    zee_rel +
                    c0 * density_buf +
                    c_lhy * density_buf * sqrt(density_buf)
                ) * dt_frac, itv)
        end
    end
    nothing
end

function apply_diagonal_potential_step!(
    psi::AbstractArray{<:Complex},
    V_trap::AbstractArray{<:AbstractFloat},
    zeeman_diag::SVector{D, Float64},
    c0::Float64,
    dt_frac::Float64,
    n_components::Int,
    ndim::Int,
    density_buf::AbstractArray{<:AbstractFloat};
    imaginary_time::Bool=false,
    c_lhy::Float64=0.0,
) where {D}
    _diagonal_step_svec!(
        Val(ndim),
        psi,
        V_trap,
        zeeman_diag,
        c0,
        c_lhy,
        dt_frac,
        density_buf,
        imaginary_time,
    )
end

@inline function _interpolate_1d(xs::Vector{Float64}, ys::Vector{Float64}, x0::Float64)
    n = length(xs)
    n < 1 && return 0.0
    x0 <= xs[1] && return ys[1]
    x0 >= xs[n] && return ys[n]
    i = searchsortedlast(xs, x0)
    i >= n && return ys[n]
    t = (x0 - xs[i]) / (xs[i + 1] - xs[i])
    ys[i] + t * (ys[i + 1] - ys[i])
end

@inline _lhy_V(::AbstractFloat, ::Nothing) = 0.0
@inline _lhy_V(::AbstractFloat, ::NoLHY) = 0.0
@inline _lhy_V(n::AbstractFloat, l::ScalarLHY) = l.c_lhy * n * sqrt(n)
@inline function _lhy_V(n::AbstractFloat, l::Quasi2DLHY)
    n < COUPLING_TOL && return zero(n)
    l.c_lhy_2d * n * (2.0 * (log(n * l.a_2d_sq) + l.log_const) + 1.0)
end
# Shared eval for all table-based modes (TabulatedLHY subtypes).
@inline function _lhy_V(n::AbstractFloat, l::TabulatedLHY)
    _interpolate_1d(l.densities, l.potential_values, Float64(n))
end
# Float64 fallback — used when callers pass a raw c_lhy scalar instead of
# an AbstractLHY. Dropped in C2 once all callers route through types.
@inline _lhy_V(n::AbstractFloat, c_lhy::AbstractFloat) = c_lhy * n * sqrt(n)

"""
    _lhy_is_active(c_lhy) -> Bool

Whether this LHY contributes at all. `NoLHY` and a zero scalar do not; a table
does — and a table cannot be summarised by one coefficient, which is the
distinction the broadcast propagator below used to lose.
"""
@inline _lhy_is_active(::Nothing) = false
@inline _lhy_is_active(::NoLHY) = false
@inline _lhy_is_active(c::Float64) = c != 0.0
@inline _lhy_is_active(l::ScalarLHY) = l.c_lhy != 0.0
@inline _lhy_is_active(::AbstractLHY) = true

"""
    _lhy_potential_field(lhy, density_buf, ::Type{RT}) -> array

`V_LHY(r)` materialised for the broadcast (non-fused) propagator path.

The fused `::Array` kernel calls `_lhy_V` per voxel inside its own loop; this
path is broadcast-based and needs the same quantity as an array. Both route
through `_lhy_V`, so the two cannot disagree about what the LHY is — which they
did before, this path having assumed every LHY has the scalar shape `c·n^(3/2)`.

`RT` keeps F32 grids in F32.
"""
function _lhy_potential_field(lhy, density_buf, ::Type{RT}) where {RT}
    out = similar(density_buf)
    out .= RT.(_lhy_V.(Float64.(density_buf), Ref(lhy)))
    out
end

# --- spatially-varying LHY ---------------------------------------------------
#
# `SpatialLHY` needs the local POLARISATION as well as the local density, so it
# gets its own two-argument form. `_lhy_needs_spin` is the trait that tells the
# diagonal step whether to bother computing ⟨F⟩ — everything else answers
# `false`, so the compiler deletes that arithmetic for them entirely and no
# existing propagator gets slower.
@inline _lhy_needs_spin(::Any) = false
@inline _lhy_needs_spin(::SpatialLHY) = true

# (F, F₊ ladder coefficients) for the spin-aware path; `(0, ())` when unused, so
# the tuple is a compile-time constant and costs nothing for other LHY types.
@inline _lhy_spin_consts(::Any, ::Val{D}) where {D} = (0, ntuple(_ -> 0.0, Val(D)))
@inline _lhy_spin_consts(l::SpatialLHY, ::Val{D}) where {D} =
    (l.F, ntuple(c -> l.fp_coeffs[c], Val(D)))

"""
    _lhy_V(n, p, lhy)

`V_LHY = ∂ε/∂n` at local density `n` and local polarisation `p = |⟨F⟩|/F`.

For `SpatialLHY` this is `(5/2) n^(3/2) e₁(p)` — the exact `n^(5/2)` scaling of
ε_LHY at degenerate Zeeman, with the spinor dependence carried by the
interpolated `e₁`. Every other LHY ignores `p`, which is what lets the same
call site serve both.
"""
@inline _lhy_V(n::AbstractFloat, ::AbstractFloat, l) = _lhy_V(n, l)
@inline function _lhy_V(n::AbstractFloat, p::AbstractFloat, l::SpatialLHY)
    n < COUPLING_TOL && return zero(Float64)
    e1 = _interpolate_1d(l.polarisations, l.e1_values, clamp(Float64(p), 0.0, 1.0))
    2.5 * e1 * Float64(n) * sqrt(Float64(n))
end

"""
    _lhy_de1_dp(l::SpatialLHY, p) -> de₁/dp

Slope of the SAME piecewise-linear `e₁(p)` interpolant `_lhy_V` above evaluates,
so the two cannot describe different tables. Zero outside the tabulated range,
matching the flat extrapolation of the interpolant.

`ε_LHY = n^(5/2) e₁(p)` depends on ψ through `p` as well as through `n`, so this
is the second half of `δε/δψ̄` — see `_grad_lhy!`, which is the only caller and
where the measured size of the piece is recorded.
"""
@inline function _lhy_de1_dp(l::SpatialLHY, p::Float64)
    xs, ys = l.polarisations, l.e1_values
    n = length(xs)
    (n < 2 || p <= xs[1] || p >= xs[n]) && return 0.0
    i = searchsortedlast(xs, p)
    i >= n && return 0.0
    @inbounds (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
end

"""
    _local_polarisation(Pmf, i, n_local, F, fp_coeffs, ::Val{D})

`|⟨F⟩|/F` for the spinor at voxel index `i`, from the SAME component reads the
density loop already performs. Uses the O(D) ladder form (F₊ tridiagonal, Fz
diagonal) rather than 13×13 matrix products.

`i` is left untyped so the one body serves both index conventions in use: a flat
index into a reshaped `Ns × D` array, and a `CartesianIndex` for the kernels
that walk the grid directly. `Pmf[i, c]` is the same expression either way, and
the formula stays declared once.
"""
@inline function _local_polarisation(Pmf, i, n_local::Float64, F::Int,
    fp_coeffs, ::Val{D}) where {D}
    n_local < COUPLING_TOL && return 0.0
    @inbounds begin
        fz = 0.0
        for c in 1:D
            fz += (F - (c - 1)) * abs2(Pmf[i, c])
        end
        fre = 0.0
        fim = 0.0
        for c in 2:D
            pr = conj(Pmf[i, c - 1]) * Pmf[i, c]
            fre += fp_coeffs[c] * real(pr)
            fim += fp_coeffs[c] * imag(pr)
        end
    end
    sqrt(fre * fre + fim * fim + fz * fz) / (n_local * F)
end

"""
    _polarisation_field(::Val{N}, psi_mf, density_buf, lhy, ::Val{D}) -> array

`|⟨F⟩|/F` as a FIELD, for the broadcast (non-fused) propagator path.

The counterpart of `_local_polarisation`, which scalar-indexes and therefore
cannot run on a device array. Built by accumulating over the same component
views the density sum uses, so it stays a pure broadcast.
"""
function _polarisation_field(::Val{N}, psi_mf, density_buf, lhy, ::Val{D}) where {N, D}
    n_pts = ntuple(d -> size(psi_mf, d), Val(N))
    F, fp = _lhy_spin_consts(lhy, Val(D))
    RT = eltype(density_buf)
    fz = similar(density_buf)
    fre = similar(density_buf)
    fim = similar(density_buf)
    v1 = view(psi_mf, _component_slice(N, n_pts, 1)...)
    fz .= RT(F) .* abs2.(v1)
    fill!(fre, zero(RT))
    fill!(fim, zero(RT))
    for c in 2:D
        vc = view(psi_mf, _component_slice(N, n_pts, c)...)
        vp = view(psi_mf, _component_slice(N, n_pts, c - 1)...)
        fz .+= RT(F - (c - 1)) .* abs2.(vc)
        fre .+= RT(fp[c]) .* real.(conj.(vp) .* vc)
        fim .+= RT(fp[c]) .* imag.(conj.(vp) .* vc)
    end
    out = similar(density_buf)
    out .= ifelse.(
        density_buf .< RT(COUPLING_TOL),
        zero(RT),
        sqrt.(fre .* fre .+ fim .* fim .+ fz .* fz) ./ (density_buf .* RT(F)),
    )
    out
end

# Spin-aware overload: `SpatialLHY` needs the local polarisation as well, and
# the broadcast path would otherwise have no method at all for it. Same
# `_lhy_V` the fused kernel calls, so the two paths still cannot disagree.
function _lhy_potential_field(lhy, density_buf, p_buf, ::Type{RT}) where {RT}
    out = similar(density_buf)
    out .= RT.(_lhy_V.(Float64.(density_buf), Float64.(p_buf), Ref(lhy)))
    out
end

# One place decides how V_LHY becomes a field, so the two broadcast call sites
# (with and without a light shift) cannot drift apart. `_lhy_needs_spin` is a
# compile-time trait, so the polarisation branch is deleted for every LHY that
# does not need it.
function _lhy_field_for_broadcast(
    ::Val{N}, lhy, psi_mf, density_buf, ::Type{RT}, ::Val{D}
) where {N, RT, D}
    _lhy_needs_spin(lhy) || return _lhy_potential_field(lhy, density_buf, RT)
    p_buf = _polarisation_field(Val(N), psi_mf, density_buf, lhy, Val(D))
    _lhy_potential_field(lhy, density_buf, p_buf, RT)
end

function _diagonal_step_svec!(
    ::Val{N},
    psi::Array,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy,
    dt_frac,
    density_buf,
    imaginary_time;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, D}
    # Splitting the imaginary_time branches into two methods is not just
    # cosmetic: keeping both branches inside one function makes Julia
    # construct the ntuple-closure objects of *both* paths every call
    # (~42 allocs / 1184 B per call at D=13, even when only one branch
    # runs). Routing through a Bool dispatch makes each leaf method see
    # only its own closures, dropping the path to 0 allocs.
    # Track A1: `psi_mf` (when supplied) supplies the density used for
    # the c0|ψ|² + c_lhy contact terms; the phase factor still multiplies
    # `psi`. The leaf-method split for closure-allocation hygiene is
    # preserved.
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    if imaginary_time
        _diagonal_step_svec_imag!(
            Val(N), psi, psi_mf_eff, V_trap, zeeman_diag, c0, c_lhy, dt_frac, density_buf
        )
    else
        _diagonal_step_svec_real!(
            Val(N), psi, psi_mf_eff, V_trap, zeeman_diag, c0, c_lhy, dt_frac, density_buf
        )
    end
end

function _diagonal_step_svec_real!(
    ::Val{N}, psi::Array, psi_mf::AbstractArray, V_trap, zeeman_diag::SVector{D, Float64},
    c0, c_lhy, dt_frac, density_buf,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Ns = prod(n_pts)
    zee_dt = SVector{D, Float64}(ntuple(c -> zeeman_diag[c] * dt_frac, Val(D)))
    zee_cis = SVector{D, ComplexF64}(ntuple(c -> cis(-zee_dt[c]), Val(D)))
    P = reshape(psi, Ns, D)
    Pmf = reshape(psi_mf, Ns, D)
    need_spin = _lhy_needs_spin(c_lhy)
    F_spin, fp_c = _lhy_spin_consts(c_lhy, Val(D))
    Vt = reshape(V_trap, Ns)
    db = reshape(density_buf, Ns)
    _voxel_loop!(Ns) do i
        @inbounds begin
            s = 0.0
            for c in 1:D
                s += abs2(Pmf[i, c])
            end
            db[i] = s
            # `need_spin` is a compile-time constant (see `_lhy_needs_spin`), so
            # this branch and the ⟨F⟩ arithmetic vanish for every LHY except
            # SpatialLHY — the existing propagators pay nothing.
            p_loc = need_spin ?
                    _local_polarisation(Pmf, i, s, F_spin, fp_c, Val(D)) : 0.0
            V_int = c0 * s + _lhy_V(s, p_loc, c_lhy)
            cis_base = cis(-(Vt[i] + V_int) * dt_frac)
            for c in 1:D
                P[i, c] *= cis_base * zee_cis[c]
            end
        end
    end
    nothing
end

function _diagonal_step_svec_imag!(
    ::Val{N}, psi::Array, psi_mf::AbstractArray, V_trap, zeeman_diag::SVector{D, Float64},
    c0, c_lhy, dt_frac, density_buf,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    Ns = prod(n_pts)
    zee_shift = minimum(zeeman_diag)
    zee_dt = SVector{D, Float64}(ntuple(c -> (zeeman_diag[c] - zee_shift) * dt_frac, Val(D)))
    zee_exp = SVector{D, Float64}(ntuple(c -> exp(-zee_dt[c]), Val(D)))
    P = reshape(psi, Ns, D)
    Pmf = reshape(psi_mf, Ns, D)
    need_spin = _lhy_needs_spin(c_lhy)
    F_spin, fp_c = _lhy_spin_consts(c_lhy, Val(D))
    Vt = reshape(V_trap, Ns)
    db = reshape(density_buf, Ns)
    _voxel_loop!(Ns) do i
        @inbounds begin
            s = 0.0
            for c in 1:D
                s += abs2(Pmf[i, c])
            end
            db[i] = s
            p_loc = need_spin ?
                    _local_polarisation(Pmf, i, s, F_spin, fp_c, Val(D)) : 0.0
            V_int = c0 * s + _lhy_V(s, p_loc, c_lhy)
            exp_base = exp(-(Vt[i] + V_int) * dt_frac)
            for c in 1:D
                P[i, c] *= exp_base * zee_exp[c]
            end
        end
    end
    nothing
end

function _diagonal_step_svec!(
    ::Val{N},
    psi::AbstractArray,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy,
    dt_frac,
    density_buf,
    imaginary_time;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    idx1 = _component_slice(N, n_pts, 1)
    density_buf .= abs2.(view(psi_mf_eff, idx1...))
    for c in 2:D
        idx = _component_slice(N, n_pts, c)
        density_buf .+= abs2.(view(psi_mf_eff, idx...))
    end
    # Match scalar eltype to array eltype so F32 arrays stay F32 in @.
    RT = eltype(V_trap)
    dt_t = RT(dt_frac)
    c0_t = RT(c0)
    # V_LHY as a FIELD, not a coefficient. The previous form collapsed the LHY
    # to a single `c_lhy` scalar and used `c·n^(3/2)`, which is only the shape
    # of `ScalarLHY`: every TabulatedLHY fell to `c = 0.0` while `_has_lhy`
    # still read `true`, so the branch ran with the LHY silently removed.
    # `PolarContactLHY` on this path differed from the fused `::Array` kernel by
    # 5.7 in ψ after one step, with V_LHY(n=1) = 50.5 simply missing.
    #
    # This path is what a `CuArray` falls back to — the GPU kernel's `c_lhy`
    # bound admits only Nothing / NoLHY / Float64 / ScalarLHY — so every GPU run
    # using `polar_contact`, `fm_contact`, `icosahedral`, `polar_dipolar`,
    # `fm_dipolar`, `polar_two_channel` or `full_bdg` was running with NO LHY.
    _has_lhy = _lhy_is_active(c_lhy)
    lhy_buf = if _has_lhy
        _lhy_field_for_broadcast(Val(N), c_lhy, psi_mf_eff, density_buf, RT, Val(D))
    else
        density_buf
    end
    # Conditional, so that `zee_c - zee_shift` is the exponent on BOTH branches
    # and the Wick split has nothing left to duplicate. Real time subtracts
    # zero, exactly.
    zee_shift = imaginary_time ? RT(minimum(zeeman_diag)) : zero(RT)
    itv = Val(imaginary_time)
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        zee_rel = RT(zeeman_diag[c]) - zee_shift
        if !_has_lhy
            @. psi_c *= wick_phase(-(V_trap + zee_rel + c0_t * density_buf) * dt_t, itv)
        else
            @. psi_c *= wick_phase(
                -(V_trap + zee_rel + c0_t * density_buf + lhy_buf) * dt_t, itv)
        end
    end
    nothing
end

function _diagonal_step_with_ls!(
    ::Val{N},
    psi::Array,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy,
    dt_frac,
    density_buf,
    imaginary_time,
    ls_amp::SVector{D, Float64},
    ls_profile;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    need_spin = _lhy_needs_spin(c_lhy)
    F_spin, fp_c = _lhy_spin_consts(c_lhy, Val(D))

    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi_mf_eff[I, c])
        end
        density_buf[I] = s
    end

    # Function barrier on `Val(imaginary_time)`: the voxel loop below is scalar,
    # so the Wick branch must be resolved BEFORE it is entered, not per voxel.
    # That is also what removes the second copy of the exponent — the two arms
    # of this function were identical apart from `exp`/`cis` and the ITP shift,
    # which is zero in real time anyway.
    zee_shift = imaginary_time ? minimum(zeeman_diag) : 0.0
    _diagonal_step_with_ls_kernel!(
        psi, V_trap, zeeman_diag, c0, c_lhy, dt_frac, density_buf,
        ls_amp, ls_profile, psi_mf_eff, n_pts, need_spin, F_spin, fp_c,
        zee_shift, Val(D), Val(imaginary_time))
    nothing
end

@noinline function _diagonal_step_with_ls_kernel!(
    psi, V_trap, zeeman_diag, c0, c_lhy, dt_frac, density_buf,
    ls_amp, ls_profile, psi_mf_eff, n_pts, need_spin, F_spin, fp_c,
    zee_shift, ::Val{D}, itv::Val{IT},
) where {D, IT}
    @inbounds for I in CartesianIndices(n_pts)
        n = density_buf[I]
        p_loc = need_spin ?
                _local_polarisation(psi_mf_eff, I, n, F_spin, fp_c, Val(D)) : 0.0
        V_int = c0 * n + _lhy_V(n, p_loc, c_lhy)
        base = wick_phase(-(V_trap[I] + V_int) * dt_frac, itv)
        intensity = ls_profile[I]
        for c in 1:D
            psi[I, c] *=
                base * wick_phase(
                    -((zeeman_diag[c] - zee_shift) + ls_amp[c] * intensity) * dt_frac, itv)
        end
    end
    nothing
end

function _diagonal_step_with_ls!(
    ::Val{N},
    psi::AbstractArray,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy,
    dt_frac,
    density_buf,
    imaginary_time,
    ls_amp::SVector{D, Float64},
    ls_profile;
    psi_mf::Union{Nothing, AbstractArray}=nothing,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    psi_mf_eff = psi_mf === nothing ? psi : psi_mf
    idx1 = _component_slice(N, n_pts, 1)
    density_buf .= abs2.(view(psi_mf_eff, idx1...))
    for c in 2:D
        idx = _component_slice(N, n_pts, c)
        density_buf .+= abs2.(view(psi_mf_eff, idx...))
    end
    RT = eltype(V_trap)
    dt_t = RT(dt_frac)
    c0_t = RT(c0)
    # Same V_LHY-as-a-field fix as the plain diagonal step above.
    _has_lhy = _lhy_is_active(c_lhy)
    lhy_buf = if _has_lhy
        _lhy_field_for_broadcast(Val(N), c_lhy, psi_mf_eff, density_buf, RT, Val(D))
    else
        density_buf
    end
    zee_shift = RT(minimum(zeeman_diag))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        zee_c = RT(zeeman_diag[c])
        ls_c = RT(ls_amp[c])
        if imaginary_time
            zee_rel = zee_c - zee_shift
            if !_has_lhy
                @. psi_c *= exp(-(V_trap + zee_rel + ls_c * ls_profile + c0_t * density_buf) * dt_t)
            else
                @. psi_c *= exp(
                    -(
                        V_trap + zee_rel + ls_c * ls_profile + c0_t * density_buf +
                        lhy_buf
                    ) * dt_t,
                )
            end
        else
            if !_has_lhy
                @. psi_c *= cis(-(V_trap + zee_c + ls_c * ls_profile + c0_t * density_buf) * dt_t)
            else
                @. psi_c *= cis(
                    -(
                        V_trap + zee_c + ls_c * ls_profile + c0_t * density_buf +
                        lhy_buf
                    ) * dt_t,
                )
            end
        end
    end
    nothing
end

function _make_batched_kinetic_cache(
    psi, kinetic_phase, ndim, backend::AbstractBackend=CPUBackend(); flags=FFTW.MEASURE
)
    plan_buf = _similar(backend, psi)
    dims = ntuple(identity, ndim)
    kw = _fft_kwargs(backend, flags)
    fwd = plan_fft!(plan_buf, dims; kw...)
    # Unnormalised backward transform: the 1/prod(n) normalisation is folded
    # into kinetic_phase_bc (below + _update_batched_kinetic_phase!), so the
    # in-place phase multiply absorbs it and we drop cuFFT's separate scaling
    # kernel. bfft(phase/N · fft(ψ)) ≡ ifft(phase · fft(ψ)) by linearity.
    inv = plan_bfft!(plan_buf, dims; kw...)
    inv_npts = one(real(eltype(kinetic_phase))) / prod(size(kinetic_phase))
    kp_bc = reshape(kinetic_phase .* inv_npts, size(kinetic_phase)..., 1)
    BatchedKineticCache(fwd, inv, kp_bc)
end

"""
    batched_kspace_filter!(v, ws, filt_bc) → v

In-place spectral filter over the SPATIAL dims of a full spinor array:
`v ← F⁻¹(filt(k)·F(v))`, applied to all `D` components at once through the
batched FFT plan pair in `ws.batched_kinetic`.

Replaces the `copy slice → fft → scale → ifft → copy slice back` loop that
four call sites had each grown independently (the Sobolev preconditioner and
its forward metric, the combined `P_V^½ P_K P_V^½` preconditioner, and the
LBFGS gradient's kinetic face). That form paid `2·D` slice copies and `2·D`
single-transform plan calls per application; this one copies nothing and
calls each plan once.

`filt_bc` must be shaped `(n_pts..., 1)` (trailing singleton broadcasts over
the spin components) and must carry the `1/prod(n_pts)` normalisation, since
the batched inverse plan is the UNNORMALISED `bfft` — see
`_make_batched_kinetic_cache`.
"""
function batched_kspace_filter!(v, ws, filt_bc)
    bk = ws.batched_kinetic
    bk.forward * v
    v .*= filt_bc
    bk.inverse * v
    return v
end

"""
    cached_kspace_filter(k2, category, param, f) → filt_bc

`(n_pts..., 1)`-shaped spectral filter `f(k²)` with the inverse-FFT
normalisation folded in, cached in the scratch registry under `category` and
rebuilt only when `param` (whatever `f` closes over) changes.

Keyed on the IDENTITY of `k2`, not its size: two grids of the same shape but
different box lengths have the same-sized, differently-valued `k²`, and a
size-keyed cache would hand the second grid the first grid's filter. Keeping
`k2` in the key also pins it against GC, so no later array can reuse its
address and inherit its entry.
"""
function cached_kspace_filter(k2, category::Symbol, param, f::F) where {F}
    st = scratch_get!(category, k2) do
        (arr=similar(k2, size(k2)..., 1), param=Ref{Any}(nothing))
    end
    if st.param[] != param
        RT = real(eltype(k2))
        inv_n = one(RT) / prod(size(k2))
        st.arr .= inv_n .* f.(reshape(k2, size(k2)..., 1))
        st.param[] = param
    end
    return st.arr
end

function _make_coriolis_cache(psi, backend::AbstractBackend=CPUBackend(); flags=FFTW.MEASURE)
    plan_buf = _similar(backend, psi)
    kw = _fft_kwargs(backend, flags)
    fwd1 = plan_fft!(plan_buf, 1; kw...)
    inv1 = plan_ifft!(plan_buf, 1; kw...)
    fwd2 = plan_fft!(plan_buf, 2; kw...)
    inv2 = plan_ifft!(plan_buf, 2; kw...)
    CoriolisCache(fwd1, inv1, fwd2, inv2)
end

function _update_batched_kinetic_phase!(
    cache::BatchedKineticCache, k_squared, dt, imaginary_time::Bool
)
    kp = cache.kinetic_phase_bc
    ndim = ndims(kp) - 1
    n_pts = ntuple(d -> size(kp, d), ndim)
    RT = eltype(k_squared)
    half = RT(0.5)
    dt_t = RT(dt)
    # 1/prod(n) folded in so apply_kinetic_step_batched! can use the unnormalised
    # bfft plan and skip cuFFT's separate scaling kernel (see _make_batched_kinetic_cache).
    inv_npts = one(RT) / prod(n_pts)
    # Imaginary time: exp(-½k²dt) (decaying); real time: cis(-½k²dt) (phase).
    # The earlier always-cis form silently turned the kinetic substep into a
    # real-time rotation during ITP (e.g. split_step_midpoint! used for an
    # imaginary-time ground state), so the high-k modes did not decay.
    if kp isa Array
        @inbounds for I in CartesianIndices(n_pts)
            arg = -half * k_squared[I] * dt_t
            kp[I, 1] = complex(wick_phase(arg, imaginary_time)) * inv_npts
        end
    else
        # GPU: `k_squared` is a host Array — broadcasting it into a device
        # kernel is illegal (non-bitstype). Move it to a device array that
        # matches `kp` first, then build the phase on-device.
        #
        # CACHED. This used to `similar` + `copyto!` on EVERY call, re-uploading
        # an immutable array: 16.0 MiB per call at 128³ Float64, and this
        # function runs once per step under `split_step_midpoint!` and
        # `rk4ip_step!`, three times per step under the Yoshida cores, and twice
        # per step in the Richardson adaptive loop. `_to_device_cached`'s own
        # docstring (`foundation/backend.jl`) names this exact k² re-upload as
        # the defect it was written to remove — on the OPERATOR face, which was
        # fixed; the propagator face was not.
        #
        # Keyed on `(device array type, RT, k_squared)` and NOT on size: two
        # grids of equal shape and different box size share a shape and differ
        # in k², which is the trap `cached_kspace_filter` above documents.
        # Holding `k_squared` in the key also pins it against GC, so no later
        # array can reuse its address and inherit the entry.
        k_sq_dev = scratch_get!(:kinetic_phase_k2, (typeof(kp), RT, k_squared)) do
            d = similar(kp, RT, size(k_squared))
            copyto!(d, k_squared)
            d
        end
        kp_view = selectdim(kp, ndim + 1, 1)
        let itv = Val(imaginary_time)
            kp_view .= wick_phase.(-half .* k_sq_dev .* dt_t, itv) .* inv_npts
        end
    end
    nothing
end

function _total_density!(
    buf::AbstractArray{<:AbstractFloat},
    psi::AbstractArray{<:Complex},
    n_components::Int,
    ndim::Int,
    n_pts,
)
    # Broadcast form: GPU-safe. The earlier scalar-getindex loop tripped
    # GPUArraysCore's `assertscalar` check when psi was a CuArray (e.g.
    # apply_loss_step! → _total_density! during a `loss:` dynamics block).
    idx1 = _component_slice(ndim, n_pts, 1)
    buf .= abs2.(view(psi, idx1...))
    for c in 2:n_components
        idx = _component_slice(ndim, n_pts, c)
        buf .+= abs2.(view(psi, idx...))
    end
    buf
end

function _total_density(psi::AbstractArray{<:Complex}, n_components::Int, ndim::Int, n_pts)
    idx1 = _component_slice(ndim, n_pts, 1)
    n = abs2.(view(psi, idx1...))
    for c in 2:n_components
        idx = _component_slice(ndim, n_pts, c)
        n .+= abs2.(view(psi, idx...))
    end
    n
end
