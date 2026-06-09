# Standalone probe: does the rfft(x) vs fft(y) Nyquist representative
# break x<->y symmetry of the DDI off-diagonal convolution?
#
# Production builds Q on the rfft half-grid:
#   axis 1 (x): rfftfreq  -> Nyquist stored as +n/2*dk  (POSITIVE)
#   axis 2 (y): fftfreq   -> Nyquist stored as -n/2*dk  (NEGATIVE)
#   axis 3 (z): fftfreq   -> Nyquist stored as -n/2*dk  (NEGATIVE)
# Q_xy ~ kx*ky/k2, Q_xz ~ kx*kz/k2, Q_yz ~ ky*kz/k2 are ODD in each axis.
# At a Nyquist plane the discrete mode folds +-k_Nyq onto one bin; the
# continuum value of an odd kernel there is 0, but production keeps the
# raw (signed) representative -> spurious, and the sign differs x vs y.

using FFTW, LinearAlgebra, Printf

n = 32
L = 12.0
dk = 2pi / L

kx = rfftfreq(n, n * dk)          # length n/2+1, Nyquist = +16dk
ky = fftfreq(n, n * dk)           # length n,     Nyquist = -16dk
kz = fftfreq(n, n * dk)
rk = (length(kx), n, n)
nyq = n ÷ 2 + 1                   # rfft Nyquist index on axis 1; fft Nyquist index = n/2+1 too

build_Q(mode::Symbol) = begin   # :raw | :kx_only (collaborator v2) | :all (symmetric)
    Qxy = zeros(rk); Qxz = zeros(rk); Qyz = zeros(rk)
    Qxx = zeros(rk); Qyy = zeros(rk); Qzz = zeros(rk)
    @inbounds for I in CartesianIndices(rk)
        kvx = kx[I[1]]; kvy = ky[I[2]]; kvz = kz[I[3]]
        k2 = kvx^2 + kvy^2 + kvz^2
        k2 == 0 && continue
        ik2 = 1 / k2
        Qxx[I] = kvx*kvx*ik2 - 1/3
        Qyy[I] = kvy*kvy*ik2 - 1/3
        Qzz[I] = kvz*kvz*ik2 - 1/3
        Qxy[I] = kvx*kvy*ik2
        Qxz[I] = kvx*kvz*ik2
        Qyz[I] = kvy*kvz*ik2
        xN = (I[1] == nyq); yN = (I[2] == nyq); zN = (I[3] == nyq)
        if mode === :kx_only           # collaborator's proposed v2: only kx=Nyquist
            xN && (Qxy[I] = 0.0)
            xN && (Qxz[I] = 0.0)
        elseif mode === :all           # symmetric: every odd axis at its Nyquist
            (xN || yN) && (Qxy[I] = 0.0)
            (xN || zN) && (Qxz[I] = 0.0)
            (yN || zN) && (Qyz[I] = 0.0)
        end
    end
    (; Qxx, Qyy, Qzz, Qxy, Qxz, Qyz)
end

# x<->y symmetric real test field with broadband (incl. Nyquist) content
g = randn(n, n, n)
fz = g .+ permutedims(g, (2, 1, 3))   # symmetric under swapping x and y
@assert maximum(abs, fz .- permutedims(fz, (2,1,3))) < 1e-12

mirror_xy(A) = permutedims(A, (2, 1, 3))

# DDI mean field from a z-polarized cloud: Phi_x = Qxz*fz_hat, Phi_y = Qyz*fz_hat
# x<->y symmetry demands Phi_y == mirror_xy(Phi_x).
conv(Q, fhat) = irfft(Q .* fhat, n)   # invert ALL dims (dim1 from length n)

report(tag, Q) = begin
    fzh = rfft(fz)
    Phi_x = conv(Q.Qxz, fzh)
    Phi_y = conv(Q.Qyz, fzh)
    Phi_z = conv(Q.Qzz, fzh)
    viol = norm(Phi_y .- mirror_xy(Phi_x)) / norm(Phi_x)
    zviol = norm(Phi_z .- mirror_xy(Phi_z)) / norm(Phi_z)
    @printf("[%-18s] xy-symmetry violation  Phi_x vs mirror(Phi_y): %.3e | Phi_z self: %.3e\n", tag, viol, zviol)
    # Nyquist-plane peek
    @printf("    Qxz at (kx=Nyq, kz=8dk): %+.4f   Qyz at (ky=Nyq, kz=8dk): %+.4f\n",
            Q.Qxz[nyq, 1, 9], Q.Qyz[1, nyq, 9])
end

println("n=$n, box=$L, dk=$(round(dk,digits=4)), Nyquist index=$nyq\n")
report("PRODUCTION raw",      build_Q(:raw))
report("collab kx-only v2",   build_Q(:kx_only))
report("symmetric all-Nyq",   build_Q(:all))
