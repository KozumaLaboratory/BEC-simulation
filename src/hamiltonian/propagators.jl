function prepare_kinetic_phase(
    grid::Grid{N, T},
    dt::Float64;
    imaginary_time::Bool=false,
    dtype::Union{Nothing, Type{<:AbstractFloat}}=nothing,
) where {N, T <: AbstractFloat}
    U = dtype === nothing ? T : dtype
    half = U(0.5)
    dt_u = U(dt)
    if imaginary_time
        Complex{U}.(@. exp(-half * grid.k_squared * dt_u))
    else
        Complex{U}.(@. cis(-half * grid.k_squared * dt_u))
    end
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
    zee_shift = imaginary_time ? minimum(zeeman_diag) : 0.0
    for c in 1:n_components
        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        if imaginary_time
            if c_lhy == 0.0
                @. psi_view *= exp(
                    -(V_trap + (zeeman_diag[c] - zee_shift) + c0 * density_buf) * dt_frac
                )
            else
                @. psi_view *= exp(
                    -(
                        V_trap +
                        (zeeman_diag[c] - zee_shift) +
                        c0 * density_buf +
                        c_lhy * density_buf * sqrt(density_buf)
                    ) * dt_frac,
                )
            end
        else
            if c_lhy == 0.0
                @. psi_view *= cis(-(V_trap + zeeman_diag[c] + c0 * density_buf) * dt_frac)
            else
                @. psi_view *= cis(
                    -(
                        V_trap +
                        zeeman_diag[c] +
                        c0 * density_buf +
                        c_lhy * density_buf * sqrt(density_buf)
                    ) * dt_frac,
                )
            end
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
@inline _lhy_V(n::AbstractFloat, l::ScalarLHY) = l.c_lhy * n * sqrt(n)
@inline function _lhy_V(n::AbstractFloat, l::Quasi2DLHY)
    n < 1e-30 && return zero(n)
    l.c_lhy_2d * n * (2.0 * (log(n * l.a_2d_sq) + l.log_const) + 1.0)
end
@inline function _lhy_V(n::AbstractFloat, l::SpinorLHYTable)
    _interpolate_1d(l.densities, l.potential_values, Float64(n))
end
@inline _lhy_V(n::AbstractFloat, c_lhy::AbstractFloat) = c_lhy * n * sqrt(n)

function _diagonal_step_svec!(
    ::Val{N},
    psi::Array,
    V_trap,
    zeeman_diag::SVector{D, Float64},
    c0,
    c_lhy,
    dt_frac,
    density_buf,
    imaginary_time,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))

    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi[I, c])
        end
        density_buf[I] = s
    end

    if imaginary_time
        zee_shift = minimum(zeeman_diag)
        zee_dt = SVector{D, Float64}(ntuple(c -> (zeeman_diag[c] - zee_shift) * dt_frac, Val(D)))
        zee_exp = SVector{D, Float64}(ntuple(c -> exp(-zee_dt[c]), Val(D)))
        @inbounds for I in CartesianIndices(n_pts)
            n = density_buf[I]
            V_int = c0 * n + _lhy_V(n, c_lhy)
            exp_base = exp(-(V_trap[I] + V_int) * dt_frac)
            for c in 1:D
                psi[I, c] *= exp_base * zee_exp[c]
            end
        end
    else
        zee_dt = SVector{D, Float64}(ntuple(c -> zeeman_diag[c] * dt_frac, Val(D)))
        zee_cis = SVector{D, ComplexF64}(ntuple(c -> cis(-zee_dt[c]), Val(D)))
        @inbounds for I in CartesianIndices(n_pts)
            n = density_buf[I]
            V_int = c0 * n + _lhy_V(n, c_lhy)
            cis_base = cis(-(V_trap[I] + V_int) * dt_frac)
            for c in 1:D
                psi[I, c] *= cis_base * zee_cis[c]
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
    imaginary_time,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    idx1 = _component_slice(N, n_pts, 1)
    density_buf .= abs2.(view(psi, idx1...))
    for c in 2:D
        idx = _component_slice(N, n_pts, c)
        density_buf .+= abs2.(view(psi, idx...))
    end
    # Match scalar eltype to array eltype so F32 arrays stay F32 in @.
    RT = eltype(V_trap)
    dt_t = RT(dt_frac)
    c0_t = RT(c0)
    _has_lhy = c_lhy isa AbstractLHY || (c_lhy isa Float64 && c_lhy != 0.0)
    c_lhy_val_t = RT(c_lhy isa Float64 ? c_lhy : (c_lhy isa ScalarLHY ? c_lhy.c_lhy : 0.0))
    zee_shift = RT(minimum(zeeman_diag))
    for c in 1:D
        idx = _component_slice(N, n_pts, c)
        psi_c = view(psi, idx...)
        zee_c = RT(zeeman_diag[c])
        if imaginary_time
            zee_rel = zee_c - zee_shift
            if !_has_lhy
                @. psi_c *= exp(-(V_trap + zee_rel + c0_t * density_buf) * dt_t)
            else
                @. psi_c *= exp(
                    -(
                        V_trap + zee_rel + c0_t * density_buf +
                        c_lhy_val_t * density_buf * sqrt(density_buf)
                    ) * dt_t,
                )
            end
        else
            if !_has_lhy
                @. psi_c *= cis(-(V_trap + zee_c + c0_t * density_buf) * dt_t)
            else
                @. psi_c *= cis(
                    -(
                        V_trap + zee_c + c0_t * density_buf +
                        c_lhy_val_t * density_buf * sqrt(density_buf)
                    ) * dt_t,
                )
            end
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
    ls_profile,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))

    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:D
            s += abs2(psi[I, c])
        end
        density_buf[I] = s
    end

    if imaginary_time
        zee_shift = minimum(zeeman_diag)
        @inbounds for I in CartesianIndices(n_pts)
            n = density_buf[I]
            V_int = c0 * n + _lhy_V(n, c_lhy)
            exp_base = exp(-(V_trap[I] + V_int) * dt_frac)
            intensity = ls_profile[I]
            for c in 1:D
                psi[I, c] *=
                    exp_base *
                    exp(-((zeeman_diag[c] - zee_shift) + ls_amp[c] * intensity) * dt_frac)
            end
        end
    else
        @inbounds for I in CartesianIndices(n_pts)
            n = density_buf[I]
            V_int = c0 * n + _lhy_V(n, c_lhy)
            cis_base = cis(-(V_trap[I] + V_int) * dt_frac)
            intensity = ls_profile[I]
            for c in 1:D
                psi[I, c] *= cis_base * cis(-(zeeman_diag[c] + ls_amp[c] * intensity) * dt_frac)
            end
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
    ls_profile,
) where {N, D}
    n_pts = ntuple(d -> size(psi, d), Val(N))
    idx1 = _component_slice(N, n_pts, 1)
    density_buf .= abs2.(view(psi, idx1...))
    for c in 2:D
        idx = _component_slice(N, n_pts, c)
        density_buf .+= abs2.(view(psi, idx...))
    end
    RT = eltype(V_trap)
    dt_t = RT(dt_frac)
    c0_t = RT(c0)
    _has_lhy = c_lhy isa AbstractLHY || (c_lhy isa Float64 && c_lhy != 0.0)
    c_lhy_val_t = RT(c_lhy isa Float64 ? c_lhy : (c_lhy isa ScalarLHY ? c_lhy.c_lhy : 0.0))
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
                        c_lhy_val_t * density_buf * sqrt(density_buf)
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
                        c_lhy_val_t * density_buf * sqrt(density_buf)
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
    inv = plan_ifft!(plan_buf, dims; kw...)
    kp_bc = reshape(kinetic_phase, size(kinetic_phase)..., 1)
    BatchedKineticCache(fwd, inv, kp_bc)
end

function apply_kinetic_step_batched!(psi, cache::BatchedKineticCache)
    cache.forward * psi
    psi .*= cache.kinetic_phase_bc
    cache.inverse * psi
    nothing
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

function _update_batched_kinetic_phase!(cache::BatchedKineticCache, k_squared, dt)
    kp = cache.kinetic_phase_bc
    ndim = ndims(kp) - 1
    n_pts = ntuple(d -> size(kp, d), ndim)
    RT = eltype(k_squared)
    half = RT(0.5)
    dt_t = RT(dt)
    if kp isa Array
        @inbounds for I in CartesianIndices(n_pts)
            kp[I, 1] = cis(-half * k_squared[I] * dt_t)
        end
    else
        kp_view = selectdim(kp, ndim + 1, 1)
        kp_view .= cis.(-half .* k_squared .* dt_t)
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
    @inbounds for I in CartesianIndices(n_pts)
        s = 0.0
        for c in 1:n_components
            s += abs2(psi[I, c])
        end
        buf[I] = s
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
