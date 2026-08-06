# Is |int psi|^2/V a valid condensate-number estimator for a TRAPPED cloud?
#
# It is exact for a uniform field on a box: psi = sqrt(n) gives |int psi|^2/V = nV = N.
# A trapped condensate is not uniform, and a single-k-mode estimator already
# understated N_0 by 22x once in this branch. So check it against a state whose N is
# known by construction rather than guessing which way it fails.
using SpinorBEC, Printf
n, box, c0, mu = 44, 10.0, 0.02, 21.0
grid = make_grid(GridConfig((n, n, n), (box, box, box)))
dV = cell_volume(grid)
V = prod(grid.config.box_size)

# Thomas-Fermi condensate at this mu: n(r) = (mu - V_trap)/c0 where positive.
psi = zeros(ComplexF64, n, n, n)
for I in CartesianIndices((n, n, n))
    x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
    Vt = 0.5 * (x^2 + y^2 + z^2)
    d = (mu - Vt) / c0
    psi[I] = d > 0 ? sqrt(d) : 0.0
end
N_true = real(sum(abs2, psi)) * dV
N_k0 = abs2(sum(psi)) * dV^2 / V
# Overlap with the TF mode itself — the estimator that should be used.
phi = psi ./ sqrt(real(sum(abs2, psi)) * dV)
N_proj = abs2(sum(conj.(phi) .* psi) * dV)
@printf("TF condensate at mu=%.1f, c0=%.3f, box=%.1f, %d^3\n", mu, c0, box, n)
@printf("  N (by construction)      = %.6g\n", N_true)
@printf("  |int psi|^2/V  (k=0)     = %.6g   ratio %.4f\n", N_k0, N_k0 / N_true)
@printf("  |<phi_TF|psi>|^2 (proj)  = %.6g   ratio %.4f\n", N_proj, N_proj / N_true)
# and a uniform field, where k=0 IS exact — the positive control for the estimator
psi2 = fill(ComplexF64(sqrt(100.0)), n, n, n)
@printf("\nuniform control: N=%.6g  k=0 gives %.6g  ratio %.4f\n",
    real(sum(abs2, psi2)) * dV, abs2(sum(psi2)) * dV^2 / V,
    abs2(sum(psi2)) * dV^2 / V / (real(sum(abs2, psi2)) * dV))
