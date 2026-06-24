# Spectral (Fourier) upsampling of a saved spinor ground state to a finer grid.
#
# A converged low-res ψ is an excellent seed for a higher-res solve: interpolate
# it to the fine grid, then a SHORT polish replaces the expensive ITP + bulk
# LBFGS-from-scratch. Spectral (k-space zero-pad) interpolation is exact for a
# band-limited ψ and preserves phase / winding / the broken-symmetry orientation
# (it is linear) — unlike real-space trilinear which smears the phase.
#
# Box is held FIXED (same physical size); only n_pts grows. Each spinor
# component is upsampled independently; the whole ψ is renormalised to the
# original norm afterwards.
#
# Env: US_IN=figs/truegs_conv/truegs_state.jld2  US_M=128  US_OUT=<auto>
#   julia --project=. scripts/upsample_spinor.jl

using SpinorBEC: load_state
using FFTW: fft, ifft, fftshift, ifftshift
using JLD2: jldsave
using Printf

const IN = get(ENV, "US_IN", "figs/truegs_conv/truegs_state.jld2")
const M  = parse(Int, get(ENV, "US_M", "128"))
const OUT = get(ENV, "US_OUT", replace(IN, ".jld2" => "_up$(M).jld2"))

st = load_state(IN)
psi = Array{ComplexF64}(st.psi)               # (nx,ny,nz,D)
n = size(psi, 1)
@assert size(psi, 1) == size(psi, 2) == size(psi, 3) "expect cubic grid"
D = size(psi, 4)
iseven(n) && iseven(M) || error("this routine assumes even n and M (got $n→$M)")
M > n || error("US_M=$M must exceed source grid n=$n")

# 3D spectral zero-pad of one scalar field n³ → M³.
function upsample3(field::Array{ComplexF64,3}, M::Int)
    n = size(field, 1)
    F = fftshift(fft(field))                   # centered spectrum, size n³
    pad = (M - n) ÷ 2
    G = zeros(ComplexF64, M, M, M)
    G[pad+1:pad+n, pad+1:pad+n, pad+1:pad+n] .= F
    # ifft normalises by M³; fft was over n³ ⇒ rescale by (M/n)³ to keep the
    # continuum function values (interpolation, not energy).
    ifft(ifftshift(G)) .* (M / n)^3
end

up = Array{ComplexF64}(undef, M, M, M, D)
for c in 1:D
    up[:, :, :, c] = upsample3(Array{ComplexF64}(psi[:, :, :, c]), M)
end

# renormalise to the source norm (∑|ψ|² dV invariant under same-box refinement).
box = st.grid_box_size
dV_src = prod(box) / n^3
dV_dst = prod(box) / M^3
norm_src = sum(abs2, psi) * dV_src
norm_dst = sum(abs2, up) * dV_dst
up .*= sqrt(norm_src / norm_dst)

@printf("upsample %s : %d³ → %d³  D=%d\n", IN, n, M, D)
@printf("  norm src=%.6f  pre-renorm dst=%.6f  → renormalised\n", norm_src, norm_dst)
@printf("  max|ψ| src=%.4e dst=%.4e\n", maximum(abs, psi), maximum(abs, up))

jldsave(OUT;
    psi=up, t=0.0, step=0,
    grid_n_points=(M, M, M), grid_box_size=box,
    atom_name=st.atom_name, c0=st.c0, c1=st.c1, c_dd=st.c_dd,
    zeeman_p=st.zeeman_p, zeeman_q=st.zeeman_q)
@printf("→ %s\n", OUT)
