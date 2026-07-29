using SpinorBEC, LinearAlgebra, Printf
# Uniform-system BdG magnon dispersion for the m=-6 Eu state, to test theoretically
# whether the DDI red-shifts the spin gap and whether it is k-direction (shape) dependent.
F = 6; D = 2F + 1
spinor = zeros(ComplexF64, D); spinor[D] = 1.0 + 0im     # c=D -> m=-6 (stretched, down)
inter = InteractionParams(Dict(0 => 2343.5, 1 => 65.1))  # Eu: c0=2344, c1=65.1 (=1/36)
cdd = 211.0

# magnon gap = smallest positive real eigenvalue that is NOT the ~0 phonon, at small k
function magnon_gap(res)
    # use the 2nd k point (small but nonzero) to avoid the exact-0 degeneracy
    ik = 2
    ev = sort(real.(res.omega[:, ik]))
    pos = ev[ev .> 1e-6]
    isempty(pos) && return (NaN, res.max_growth_rate)
    (pos[1], res.max_growth_rate)      # lowest gapped positive branch
end

println("Finding the p sign that makes m=-6 the stable ground state (max_growth≈0)...")
for psign in (0.385, -0.385)
    zee = ZeemanParams(psign, 0.0)
    r = bogoliubov_spectrum(; spinor, n0=0.008, F, interactions=inter, zeeman=zee,
                            c_dd=0.0, k_max=2.0, n_k=40, k_direction=(0.,0.,1.))
    g, grow = magnon_gap(r)
    @printf("  p=%+.3f : magnon gap(k→0, no DDI)=%.4f  max_growth=%.2e  %s\n",
            psign, g, grow, grow < 1e-6 ? "STABLE" : "UNSTABLE")
end

# pick the stable p (determined above; we print both and use the stable one below)
p_use = 0.385
zee = ZeemanParams(p_use, 0.0)
omega_L = abs(p_use)     # bare Larmor gap (internal ω_ref units)
TUNIT_MS = 1000/691.15
top(g) = isnan(g) ? "NaN" : @sprintf("%.1f ms", 2π/g*TUNIT_MS)

println("\n=== magnon gap vs DDI and k-direction (n0=0.008) ===")
println(" k_dir        no-DDI gap        with-DDI gap       DDI shift    -> period(with DDI)")
for (name, kdir) in [("z (∥M)", (0.,0.,1.)), ("x (⊥M)", (1.,0.,0.)), ("xy diag", (1.,1.,0.))]
    r0 = bogoliubov_spectrum(; spinor, n0=0.008, F, interactions=inter, zeeman=zee,
                             c_dd=0.0, k_max=2.0, n_k=40, k_direction=kdir)
    rd = bogoliubov_spectrum(; spinor, n0=0.008, F, interactions=inter, zeeman=zee,
                             c_dd=cdd, k_max=2.0, n_k=40, k_direction=kdir)
    g0,_ = magnon_gap(r0); gd, grow = magnon_gap(rd)
    @printf(" %-9s   %.4f            %.4f          %+.4f (%+.0f%%)   %s  %s\n",
            name, g0, gd, gd-g0, 100*(gd-g0)/g0, top(gd), grow>1e-6 ? "[UNSTABLE]" : "")
end
@printf("\n bare Larmor gap = %.4f  (period %.1f ms)\n", omega_L, 2π/omega_L*TUNIT_MS)

println("\n=== DDI shift vs density n0 (k_dir = z ∥M) ===")
for n0 in [0.004, 0.008, 0.016]
    r0 = bogoliubov_spectrum(; spinor, n0, F, interactions=inter, zeeman=zee, c_dd=0.0, k_max=2.0, n_k=40, k_direction=(0.,0.,1.))
    rd = bogoliubov_spectrum(; spinor, n0, F, interactions=inter, zeeman=zee, c_dd=cdd, k_max=2.0, n_k=40, k_direction=(0.,0.,1.))
    g0,_ = magnon_gap(r0); gd,_ = magnon_gap(rd)
    @printf("  n0=%.3f : no-DDI=%.4f  DDI=%.4f  shift=%+.0f%%  period=%s\n",
            n0, g0, gd, 100*(gd-g0)/g0, top(gd))
end
