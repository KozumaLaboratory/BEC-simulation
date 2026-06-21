# Probe: does the cubic-grid DDI kernel break in-plane SO(2) rotational
# symmetry down to C4, and does a truncated (Vico-Greengard / Ronen)
# kernel remove it AT FIXED resolution?
#
# Hypothesis (B=0 xy-plane "x/y-axis pattern"): on a cubic grid the DDI
# kernel Q_ab(k) = k_a k_b/k^2 - d_ab/3 has a direction-dependent
# DISCONTINUITY at k=0 that the grid samples anisotropically. For a
# perfectly ISOTROPIC density n(r), the dipolar energy of an in-plane
# magnetization m_hat(phi) = (cos phi, sin phi, 0) must be INDEPENDENT
# of phi in the continuum. Any phi-dependence on the grid is spurious
# C4 anisotropy; its minima at phi = 0, pi/2 (the axes) are what pin the
# B=0 ground state to x/y.
#
# E(phi) ∝ sum_k |n_hat(k)|^2 * ( cos^2 Qxx + sin^2 Qyy + 2 cos sin Qxy )
#
# Truncated kernel: Q *= h(kR),  h(x) = 1 + 3cos(x)/x^2 - 3sin(x)/x^3
# (-> x^2/10 as x->0), R = L/2. h is C^inf (Paley-Wiener) so the k=0
# discontinuity is removed and the grid sampling error becomes spectral.

using FFTW, Printf

# Radial truncation factor with small-x series (catastrophic cancellation
# of 3cos/x^2 - 3sin/x^3 ~ 3/x^2 otherwise).
function h_trunc(x::Float64)
    x < 1e-2 && return x^2 / 10 - x^4 / 280 + x^6 / 15120
    1.0 + 3cos(x) / x^2 - 3sin(x) / x^3
end

# In-plane DDI energy of an isotropic density vs magnetization angle phi.
# Continuum + isotropic density => E(phi) = 0 for ALL phi (trace Q = 0 and
# angular average of Q vanishes). So ANY phi-variation is pure grid artifact.
# We normalize the spurious split by a fixed POSITIVE DDI energy scale
# Sref = sum_k w(k) * (1/3) (the typical |Q| weight) so bare/truncated and
# different n are comparable.
function inplane_anisotropy(n_pts::Int, L::Float64; truncate::Bool, R::Float64)
    dk = 2pi / L
    k = fftfreq(n_pts, n_pts * dk)
    # isotropic Gaussian density, width ~ L/8, centered (periodic-safe)
    x = range(-L / 2, L / 2 - L / n_pts; length=n_pts)
    sig = L / 8
    n = [exp(-(xi^2 + yi^2 + zi^2) / (2sig^2)) for xi in x, yi in x, zi in x]
    nhat = fft(n)
    w = abs2.(nhat)

    nphi = 73
    phis = range(0, pi / 2; length=nphi)
    E = zeros(nphi)
    Ez = 0.0
    Sref = 0.0
    @inbounds for I in CartesianIndices((n_pts, n_pts, n_pts))
        kx = k[I[1]]; ky = k[I[2]]; kz = k[I[3]]
        k2 = kx^2 + ky^2 + kz^2
        k2 == 0 && continue
        ik2 = 1 / k2
        fac = truncate ? h_trunc(sqrt(k2) * R) : 1.0
        Qxx = (kx * kx * ik2 - 1 / 3) * fac
        Qyy = (ky * ky * ik2 - 1 / 3) * fac
        Qzz = (kz * kz * ik2 - 1 / 3) * fac
        Qxy = (kx * ky * ik2) * fac
        wI = w[I]
        Ez += wI * Qzz
        Sref += wI / 3
        for (j, phi) in enumerate(phis)
            c = cos(phi); s = sin(phi)
            E[j] += wI * (c * c * Qxx + s * s * Qyy + 2 * c * s * Qxy)
        end
    end
    split = (E[1] - E[(nphi + 1) ÷ 2]) / Sref      # axis - diagonal, normalized
    rng = (maximum(E) - minimum(E)) / Sref         # full C4 amplitude, normalized
    (; split, rng, Ez_norm=Ez / Sref)
end

L = 12.0
println("Spurious in-plane C4 anisotropy of the DDI energy for an ISOTROPIC")
println("density (continuum value = 0 for every angle).  R = L/2 = $(L/2)")
println("split = [E(axis)-E(diag)] / Sref,   rng = [maxE-minE] / Sref\n")
@printf("%-5s | %-26s | %-26s | rng factor\n", "n", "BARE kernel", "TRUNCATED kernel")
@printf("%-5s | %-13s %-12s | %-13s %-12s |\n", "", "split", "rng", "split", "rng")
println("-"^76)
for n_pts in (24, 32, 48, 64, 96, 128)
    b = inplane_anisotropy(n_pts, L; truncate=false, R=L / 2)
    t = inplane_anisotropy(n_pts, L; truncate=true, R=L / 2)
    fac = abs(b.rng) / max(abs(t.rng), 1e-30)
    @printf("%-5d | %-+13.3e %-12.3e | %-+13.3e %-12.3e | %.0fx\n",
        n_pts, b.split, b.rng, t.split, t.rng, fac)
end
println("\nInterpretation:")
println(" * rng(BARE) >> rng(TRUNCATED) => cubic grid breaks SO(2)->C4; truncation fixes.")
println(" * split sign: negative => axis is LOWER energy => B=0 ground state pinned to x/y.")
println(" * BARE rng stays O(1) as n grows (true k=0 discontinuity, converges slowly);")
println("   TRUNCATED small at ALL n => fix works at FIXED 128^3.")
