# Low-level spinor / hermitian helpers.
# All inline, no exports — internal building blocks for the propagator
# and observable hot paths.

@inline function _component_slice(ndim::Int, n_pts::NTuple{N, Int}, c::Int) where {N}
    # Build a (Colon × N, c) tuple. Using `Colon()` instead of `1:n_pts[d]`
    # keeps the element types uniform (Colon, ..., Colon, Int) which is
    # concrete — `view(psi, slice...)` then infers to a concrete view type.
    # Earlier shape `(1:n_pts[d], ..., c)` mixed UnitRange + Int and yielded
    # Tuple{Vararg{...}}, forcing `view` to return ::Any in apply_loss_step!.
    ntuple(Val(N + 1)) do d
        d <= N ? Colon() : c
    end
end

# Column-integrate a field by summing out one axis, dropping it from the
# shape (3D → 2D, 2D → 1D). The shared primitive behind `column_density`,
# the TOF per-component projections, and `imaging_forward`.
@inline function _integrate_out_axis(field::AbstractArray, axis::Int)
    dropdims(sum(field; dims=axis); dims=axis)
end

@inline function _get_spinor(psi, I, n_comp)
    SVector{n_comp, ComplexF64}(ntuple(c -> psi[I, c], n_comp))
end

@inline function _get_spinor(psi, I, ::Val{D}) where {D}
    SVector{D, ComplexF64}(ntuple(c -> psi[I, c], Val(D)))
end

@inline function _set_spinor!(psi, I, spinor, n_comp)
    for c in 1:n_comp
        psi[I, c] = spinor[c]
    end
end

@inline function _set_spinor!(psi, I, spinor, ::Val{D}) where {D}
    for c in 1:D
        psi[I, c] = spinor[c]
    end
end

function _exp_i_hermitian(
    H::SMatrix{D, D, ComplexF64},
    dt::Float64,
    imaginary_time::Bool,
) where {D}
    eig = eigen(Hermitian(H))
    V = eig.vectors

    if imaginary_time
        expD = SVector{D, ComplexF64}(exp.(-eig.values .* dt))
    else
        expD = SVector{D, ComplexF64}(cis.(-eig.values .* dt))
    end

    V * Diagonal(expD) * V'
end

"""
Allocation-free matrix-vector product: result = V * x.
Uses ntuple to build SVector{D} without SMatrix temporaries.
Works with any AbstractMatrix (Matrix, Adjoint, SMatrix).
"""
@inline function _matvec(V::AbstractMatrix{ComplexF64}, x::SVector{D, ComplexF64}) where {D}
    SVector{D, ComplexF64}(
        ntuple(Val(D)) do i
            s = zero(ComplexF64)
            for j in 1:D
                @inbounds s += V[i, j] * x[j]
            end
            s
        end,
    )
end
