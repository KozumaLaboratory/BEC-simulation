# Keep the two-loop recurrence on the device. cuBLAS dotc already supports a
# device result; reading that scalar on the host introduced 2m+1 synchronizations.
function SpinorBEC._lbfgs_direction(
    grad::CuArray{T}, s_hist::Vector{<:CuArray{T}}, y_hist::Vector{<:CuArray{T}},
    rho_hist::Vector{Float64}, dV::Float64,
) where {T <: Union{ComplexF32, ComplexF64}}
    q = SpinorBEC._lbfgs_scratch(grad).q
    copyto!(q, grad)
    qv = vec(q)
    n, m = length(q), length(rho_hist)
    scalars = SpinorBEC.scratch_get!(:lbfgs_device_scalars, (typeof(grad), m)) do
        (; alphas=[CUDA.zeros(Float64, 1) for _ in 1:m],
            dot_result=CUDA.zeros(T, 1), beta=CUDA.zeros(Float64, 1))
    end
    alphas, tmp, beta = scalars.alphas, scalars.dot_result, scalars.beta

    for i in m:-1:1
        CUDA.CUBLAS.dotc(n, vec(s_hist[i]), qv, tmp)
        alphas[i] .= rho_hist[i] .* real.(tmp) .* dV
        qv .-= alphas[i] .* vec(y_hist[i])
    end
    if m > 0
        CUDA.CUBLAS.dotc(n, vec(y_hist[end]), vec(y_hist[end]), tmp)
        beta .= (1.0 / (rho_hist[end] * dV)) ./ max.(real.(tmp), SpinorBEC.DENOM_FLOOR)
        qv .*= beta
    end
    for i in 1:m
        CUDA.CUBLAS.dotc(n, vec(y_hist[i]), qv, tmp)
        beta .= rho_hist[i] .* real.(tmp) .* dV
        qv .+= (alphas[i] .- beta) .* vec(s_hist[i])
    end
    qv .*= -1
    q
end
