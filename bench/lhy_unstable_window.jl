# WHERE the Eu F=6 dipolar spinor instability lives in k, and how big the
# resulting ambiguity in ε_LHY actually is.
#
# `full_bdg` warns that ε_LHY is scheme-dependent whenever any Bogoliubov branch
# has Im ω ≠ 0. That warning is a yes/no, and issue #337 turns on a HOW MUCH.
# The warning also names the mechanism precisely — "the zero-point sum drops the
# complex branches while the counterterms still subtract all D of them" — so the
# ambiguity is not a matter of taste about Re ω. It is a MISMATCH between how
# many branches are summed and how many are counter-subtracted, and it can be
# measured by repairing the mismatch:
#
#   S1  what full_bdg does: Σ over positive-symplectic-norm branches, minus the
#       full counterterms D·ε_k + tr C − ‖B‖²/2ε_k.
#   S3  counterterm-consistent: the same sum, with the counterterms scaled to
#       the number of branches actually kept (D_kept/D).
#
# S3 ≡ S1 identically wherever the spectrum is real (D_kept = D), so "no gap"
# and "no instability" cannot be confused: the c_dd = 0 rows are the negative
# control that the comparison CAN return zero.
#
# A first attempt used "keep Re ω of the complex branches" as the second scheme.
# That was wrong twice over — it returned a 144 % gap on a row with zero
# unstable directions (it was picking up ENERGETICALLY unstable branches, a
# different thing), and it returned exactly zero on the unstable polar rows
# (the complex pairs there are purely imaginary, so their Re ω is 0 and both
# conventions agree on them). Neither number was about the ambiguity.
#
#   julia --project=. bench/lhy_unstable_window.jl [c1_ratio] [n_dir]

using Printf
using LinearAlgebra: eigvals, eigen, Hermitian, norm
using SpinorBEC
using SpinorBEC: _bdg_contact_matrices, _lhy_bdg_stiffness,
    fibonacci_sphere_directions, spin_matrices, _gauss_legendre

include(joinpath(@__DIR__, "eu151_params.jl"))

const C1_RATIO = length(ARGS) >= 1 ? parse(Float64, ARGS[1]) : 1 / 36
const N_DIR = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 32
const F = 6
const D = 2F + 1
const N_PEAK = 3.7e-3
const L_BOX = 12.0             # the campaign's transverse box, in a_ho
const ZEE0 = ZeemanParams(0.0, 0.0)

polar_spinor() = (z = zeros(ComplexF64, D); z[F + 1] = 1.0; z)
fm_spinor() = (z = zeros(ComplexF64, D); z[1] = 1.0; z)

"""One k-node: (Σ Re ω over positive-norm branches, n_kept, max Im ω, min Re ω).

`n_kept` is what makes the counterterm mismatch measurable, and `min Re ω` tells
DYNAMICAL instability (Im ω > 0) apart from ENERGETIC instability (a positive-
norm branch with ω < 0). They are different statements about the mean field and
only the first one makes ε_LHY ambiguous."""
function branch_stats(C, B, ek::Float64)
    A = copy(C)
    @inbounds for i in 1:D
        A[i, i] += ek
    end
    H = zeros(ComplexF64, 2D, 2D)
    H[1:D, 1:D] .= A
    H[1:D, (D + 1):(2D)] .= B
    H[(D + 1):(2D), 1:D] .= .-conj.(B)
    H[(D + 1):(2D), (D + 1):(2D)] .= .-conj.(A)
    ef = eigen(H)
    # RELATIVE tolerances. A non-Hermitian 2D×2D eigensolve leaves round-off
    # imaginary parts that grow with |λ| ~ k²/2, so an absolute `imag > 0` test
    # reports every direction unstable out to the cutoff — it did, at k = 19 k_s,
    # and that is the scan reporting its own noise floor as physics. The same
    # scale sets the symplectic-norm test: a complex quadruplet has norm ≈ 0 and
    # must not be counted as kept on the strength of its round-off sign.
    scale = maximum(abs ∘ real, ef.values)
    tol_im = 1e-8 * max(scale, 1.0)
    s = 0.0
    kept = 0
    growth = 0.0
    min_om = Inf
    @inbounds for j in 1:(2D)
        v = view(ef.vectors, :, j)
        nj = sum(abs2, view(v, 1:D)) - sum(abs2, view(v, (D + 1):(2D)))
        if nj > 1e-8
            s += real(ef.values[j])
            kept += 1
            min_om = min(min_om, real(ef.values[j]))
        end
        im = imag(ef.values[j])
        im > tol_im && (growth = max(growth, im))
    end
    (s, kept, growth, isfinite(min_om) ? min_om : 0.0)
end

function direction_report(spinor, n0, ip, c_dd; n_scan::Int=400, n_quad::Int=160)
    h_c, M_c, zee, _ = _bdg_contact_matrices(spinor, F, ip, ZEE0)
    sm = c_dd != 0 ? spin_matrices(F) : nothing
    dirs = c_dd != 0 ? fibonacci_sphere_directions(N_DIR) : [(0.0, 0.0, 1.0)]

    map(dirs) do dir
        kh = collect(dir);
        kh ./= norm(kh)
        Cm, Bm, _ = _lhy_bdg_stiffness(h_c, M_c, zee, spinor, n0, F, c_dd, sm, kh)
        tr_C = real(sum(i -> Cm[i, i], 1:D))
        B_fro2 = real(sum(abs2, Bm))
        k_s = sqrt(2 * max(maximum(abs, eigvals(Hermitian(Cm))), 0.0))
        k_hi = 19.0 * k_s

        k_unst = 0.0
        n_energetic = 0
        min_kept = D
        for k in range(k_hi / n_scan, k_hi; length=n_scan)
            _, kept, g, mo = branch_stats(Cm, Bm, k * k / 2)
            g > 0 && (k_unst = k)
            mo < 0 && (n_energetic += 1)
            min_kept = min(min_kept, kept)
        end

        # ε under both conventions, on ONE quadrature so the gap is not a
        # comparison of two different integrals.
        nodes, w = _gauss_legendre(n_quad, 0.0, k_hi)
        s1 = 0.0
        s3 = 0.0
        ir_abs = 0.0
        tot_abs = 0.0
        for (k, wk) in zip(nodes, w)
            k <= 0 && continue
            ek = k * k / 2
            so, kept, _, _ = branch_stats(Cm, Bm, ek)
            f = kept / D
            v1 = wk * k * k * (so - D * ek - tr_C + B_fro2 / (2ek))
            v3 = wk * k * k * (so - f * (D * ek + tr_C - B_fro2 / (2ek)))
            s1 += v1
            s3 += v3
            tot_abs += abs(v1)
            k <= k_unst && (ir_abs += abs(v1))
        end
        (k_unst=k_unst, k_s=k_s, min_kept=min_kept, n_energetic=n_energetic,
            eps_S1=s1 / (4π^2), eps_S3=s3 / (4π^2),
            f_unst=tot_abs > 0 ? ir_abs / tot_abs : 0.0, dk=k_hi / n_scan)
    end
end

function summarise(label, spinor, c_dd)
    ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)
    rows = direction_report(spinor, N_PEAK, ip, c_dd)
    n = length(rows)
    e1 = sum(r -> r.eps_S1, rows) / n
    e3 = sum(r -> r.eps_S3, rows) / n
    @printf("  %-20s %7d/%-3d %6d/%-3d %8.3g %8.3g %7.3f %7.3f %10.4g %10.4g %9.3f\n",
        label, count(r -> r.k_unst > 0, rows), n,
        count(r -> r.n_energetic > 0, rows), n,
        maximum(r -> r.k_unst, rows), maximum(r -> r.k_s, rows),
        maximum(r -> r.k_unst / r.k_s, rows), maximum(r -> r.f_unst, rows),
        e1, e3, abs(e1) > 0 ? (e3 - e1) / abs(e1) : 0.0)
    (; k_unst=maximum(r -> r.k_unst, rows), k_s=maximum(r -> r.k_s, rows),
        min_kept=minimum(r -> r.min_kept, rows), eps_S1=e1, eps_S3=e3,
        gap=abs(e1) > 0 ? (e3 - e1) / abs(e1) : 0.0, dk=rows[1].dk,
        f_unst=maximum(r -> r.f_unst, rows))
end

println("="^124)
println("Eu-151 F=6 — the size of the ε_LHY scheme ambiguity.  c1_ratio = ",
    round(C1_RATIO; sigdigits=6), ",  n = ", N_PEAK, ",  n_dir = ", N_DIR)
println("S1 = full_bdg (all D counterterms).  S3 = counterterms scaled to the branches kept.")
println("S3 ≡ S1 wherever the spectrum is real, so the c_dd=0 rows are the negative control.")
println("="^124)
@printf("\n  %-20s %11s %10s %8s %8s %7s %7s %10s %10s %9s\n",
    "state / c_dd", "dyn.unst k̂", "energ. k̂", "k_unst", "k_s", "k_u/k_s",
    "f_unst", "ε S1", "ε S3", "gap")

res = Dict{String, Any}()
for (nm, sp) in (("FM (m=+F)", fm_spinor()), ("polar (m=0)", polar_spinor()))
    for (dl, cdd) in (("c_dd=0", 0.0), ("c_dd=Eu", EU_c_dd))
        res["$nm $dl"] = summarise("$nm  $dl", sp, cdd)
    end
end

# A gap measured at one coupling could be a coincidence, or the visible part of
# something that blows up. Sweeping c_dd from the stable side answers which: the
# gap must be exactly 0 where the spectrum is real and must grow CONTINUOUSLY
# from there. A jump would mean the two conventions are not two readings of one
# quantity.
println("\n[continuity] scheme gap vs dipolar strength — 0 at c_dd=0 by construction,")
println("so this is the shape of the ambiguity rather than a single number.")
@printf("\n  %-12s %10s %10s %10s %10s\n",
    "c_dd/c_dd_Eu", "FM k_unst", "FM gap", "pol k_unst", "pol gap")
for f in (0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0)
    ipf = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)
    rf = direction_report(fm_spinor(), N_PEAK, ipf, f * EU_c_dd)
    rp = direction_report(polar_spinor(), N_PEAK, ipf, f * EU_c_dd)
    gf = let e1 = sum(r -> r.eps_S1, rf) / length(rf), e3 = sum(r -> r.eps_S3, rf) / length(rf)
        (e3 - e1) / abs(e1)
    end
    gp = let e1 = sum(r -> r.eps_S1, rp) / length(rp), e3 = sum(r -> r.eps_S3, rp) / length(rp)
        (e3 - e1) / abs(e1)
    end
    @printf("  %-12.2f %10.4g %10.4f %10.4g %10.4f\n",
        f, maximum(r -> r.k_unst, rf), gf, maximum(r -> r.k_unst, rp), gp)
    flush(stdout)
end

println("\n  f_unst = share of |∫k²I dk| carried by k < k_unst.")
println("  min branches kept anywhere: FM ", res["FM (m=+F) c_dd=Eu"].min_kept, "/", D,
    ",  polar ", res["polar (m=0) c_dd=Eu"].min_kept, "/", D)
@printf("  k_box = 2π/L (L=%.1f a_ho) = %.4f  ⇒  k_unst/k_box = %.1f (FM), %.1f (polar)\n",
    L_BOX, 2π / L_BOX, res["FM (m=+F) c_dd=Eu"].k_unst / (2π / L_BOX),
    res["polar (m=0) c_dd=Eu"].k_unst / (2π / L_BOX))
println("\ndone.")
