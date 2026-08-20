# Where do 36 GB come from? Three cluster runs were killed with exit 137 and
# maxrss 36.6 GB while the field itself is 6 MB, and all three passed a 5% smoke.
# So it is per-call allocation in the control loop, not the field.
#
# The suspect: the callback runs mu_from_total_lda every 25 steps, that bisects with
# up to 80 iterations, and each iteration builds classical_field_equilibrium and
# incoherent_lda from scratch on an nr-point radial grid. Measure the allocation per
# call rather than reason about it.
using SpinorBEC, Printf
T, c0, eps_cut = 5.0, 0.02, 20.0
mu_from_total_lda(2e4; T, c0, eps_cut)            # warm up
@printf("%-42s %12s %10s\n", "call", "bytes", "MB")
for (name, f) in (
    ("classical_field_equilibrium (nr=400)",
        () -> classical_field_equilibrium(; T, mu=5.0, c0, n_T=3.0, nr=400)),
    ("incoherent_lda (nr=400)",
        () -> incoherent_lda(; T, mu=5.0, c0, eps_cut, nr=400)),
    ("mu_from_total_lda (one solve)",
        () -> mu_from_total_lda(2e4; T, c0, eps_cut)),
)
    b = @allocated f()
    @printf("%-42s %12d %10.3f\n", name, b, b / 2^20)
end
n_cb = 50_000 ÷ 25
b = @allocated mu_from_total_lda(2e4; T, c0, eps_cut)
@printf("\nper callback %.3f MB x %d callbacks = %.1f GB\n",
    b / 2^20, n_cb, b * n_cb / 2^30)
