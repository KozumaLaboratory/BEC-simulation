# Spectral (Fourier zero-pad) upsampling of a spinor to a finer grid.
#
# A converged low-resolution ψ is an excellent seed for a higher-resolution
# solve: spectral interpolation is exact for a band-limited ψ and is linear, so
# it preserves phase / winding / the broken-symmetry orientation — unlike
# real-space trilinear, which smears the phase. A short polish from the upsampled
# seed then replaces an expensive ITP + L-BFGS-from-scratch at the fine grid.
#
# The box (physical size) is held FIXED; only the point count grows. Each spinor
# component is upsampled independently and the whole ψ is renormalised to the
# source norm (∑|ψ|² dV is box-invariant under same-box refinement).

export upsample_spinor

# 3D spectral zero-pad of one scalar field: n³ → M³ (n, M even, M > n).
function _upsample3(field::AbstractArray{ComplexF64, 3}, M::Int)
    n = size(field, 1)
    Fk = fftshift(fft(field))                       # centered spectrum, n³
    pad = (M - n) ÷ 2
    G = zeros(ComplexF64, M, M, M)
    G[(pad + 1):(pad + n), (pad + 1):(pad + n), (pad + 1):(pad + n)] .= Fk
    # ifft normalises by M³ while fft summed over n³ ⇒ rescale by (M/n)³ to keep
    # continuum function values (interpolation, not energy).
    ifft(ifftshift(G)) .* (M / n)^3
end

"""
    upsample_spinor(psi, M) -> Array{ComplexF64,4}

Spectrally upsample the cubic spinor field `psi` (`[x,y,z,m]`, side `n`) to side
`M` (`M > n`, both even). Same physical box; each `m`-component is zero-padded in
k-space and the result is renormalised to the source norm. Phase and winding are
preserved (the interpolation is linear).
"""
function upsample_spinor(psi::AbstractArray{<:Complex, 4}, M::Int)
    n = size(psi, 1)
    size(psi, 2) == n == size(psi, 3) || error("upsample_spinor expects a cubic grid")
    (iseven(n) && iseven(M)) || error("upsample_spinor assumes even n and M (got $n→$M)")
    M > n || error("M=$M must exceed source side n=$n")
    D = size(psi, 4)
    up = Array{ComplexF64}(undef, M, M, M, D)
    for c in 1:D
        up[:, :, :, c] = _upsample3(Array{ComplexF64}(psi[:, :, :, c]), M)
    end
    # ∑|ψ|² dV is box-invariant; the prod(box) factors cancel in the ratio.
    up .*= sqrt((sum(abs2, psi) / n^3) / (sum(abs2, up) / M^3))
    up
end
