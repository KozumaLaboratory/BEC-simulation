# docs FIG-LHY-UV: ε_LHY from the general-spinor BdG zero-point integral as a
# function of the momentum cutoff, for the pre-2026-07-27 UV subtraction and
# the current one, against the closed forms. Output target (unchanged from the
# script pair this absorbed): docs/figs/lhy_full_bdg_uv_convergence.png.

# The pre-fix subtraction, verbatim in structure: the per-branch asymptote
# `mu_b` was built INCLUDING ek and then ek was subtracted again, and the
# branch was labelled by the dominant component of the eigenvector.
function _lhy_uv_prefix_subtraction(spinor, n0, F, ip, k_max, n_k)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, ip, ZeemanParams())
    mu = real(dot(spinor, (Diagonal(zee) .+ n0 .* h_mf) * spinor))
    k_values = collect(range(1e-6, k_max; length=n_k))
    dk = k_values[2] - k_values[1]
    E = 0.0
    for k in k_values
        ek = k^2 / 2
        L = 2n0 .* h_mf
        for i in 1:D
            L[i, i] += ek - mu + zee[i]
        end
        M_sc = n0 .* M_anom
        H = zeros(ComplexF64, 2D, 2D)
        H[1:D, 1:D] .= L
        H[1:D, (D + 1):(2D)] .= M_sc
        H[(D + 1):(2D), 1:D] .= .-conj.(M_sc)
        H[(D + 1):(2D), (D + 1):(2D)] .= .-conj.(L)
        ef = eigen(H)
        zpe = 0.0
        for (eb, ev) in enumerate(ef.values)
            omega = real(ev)
            omega > 1e-10 || continue
            c_star = argmax(abs2.(view(ef.vectors, 1:D, eb)))
            mu_b = ek + n0 * real(h_mf[c_star, c_star]) - mu + zee[c_star]
            zpe += 0.5 * (omega - ek - mu_b + mu_b^2 / (2.0 * max(ek, 1e-30)))
        end
        E += k^2 * zpe * dk / (2.0 * π^2)
    end
    E
end

const _LHY_UV_CASES = (
    (label="F=1 polar", F=1, c0=10.0, c1=0.5,
        spinor=ComplexF64[0, 1, 0], ansatz=:polar),
    (label="F=6 polar", F=6, c0=10.0, c1=0.1,
        spinor=ComplexF64[c == 7 ? 1.0 : 0.0 for c in 1:13], ansatz=:polar),
    (label="F=6 FM", F=6, c0=10.0, c1=-0.1,
        spinor=ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:13], ansatz=:fm),
)

function build_docs_lhy_uv(io::IO, paper::AbstractString, fig::AbstractString)
    kmaxes = round.(exp.(range(log(4.0), log(120.0); length=28)); digits=4)

    buf = IOBuffer()
    println(buf, "case,k_max,eps_prefix,eps_fixed,eps_closed")
    for c in _LHY_UV_CASES
        ip = InteractionParams(Dict(0 => c.c0, 1 => c.c1))
        g = _c0c1_to_gS(c.F, c.c0, c.c1)
        closed = if c.ansatz === :polar
            lhy_energy_polar(1.0, build_polar_lhy_coefs(c.F, g))
        else
            lhy_energy_fm(1.0, build_fm_lhy_coefs(c.F, g))
        end
        for km in kmaxes
            nk = max(200, round(Int, 12 * km))
            pre = _lhy_uv_prefix_subtraction(c.spinor, 1.0, c.F, ip, km, nk)
            fix = _lhy_bdg_energy_density(c.spinor, 1.0, c.F, ip,
                ZeemanParams(), 0.0, km, min(nk, 400), 1)
            println(buf, "$(c.label),$km,$pre,$fix,$closed")
        end
        println(io, "done: $(c.label)  closed=$closed")
    end

    py = """
#!/usr/bin/env python3
\"\"\"Plot the full_bdg LHY UV convergence.

The pre-2026-07-27 subtraction folded eps_k into the per-branch asymptote and
then subtracted eps_k a second time, leaving the integrand at -eps_k/2 and the
"energy" diverging as k_max^5. The current trace-based counterterms converge to
the closed form.

Reads the sibling CSV, writes the sibling .png (the docs/figs/ target).
\"\"\"
import csv
from collections import defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

COLORS = {"F=1 polar": "#2f6f9f", "F=6 polar": "#b5622a", "F=6 FM": "#3f7a4d"}

src = __file__.replace(".py", ".csv")
dst = __file__.replace(".py", ".png")

rows = defaultdict(list)
with open(src) as fh:
    for r in csv.DictReader(fh):
        rows[r["case"]].append(
            (float(r["k_max"]), float(r["eps_prefix"]),
             float(r["eps_fixed"]), float(r["eps_closed"]))
        )

fig, ax = plt.subplots(figsize=(8.2, 5.4))

# Normalised by the closed form: the three ansatze have nearly degenerate
# absolute values (17.11 / 17.78 / 5.60) and would overlap unreadably.
# On this axis "correct" is the line at 1.
ax.axhline(1.0, color="#22303c", lw=1.4, zorder=1)
ax.annotate("closed form", xy=(0.985, 1.0), xycoords=("axes fraction", "data"),
            ha="right", va="bottom", fontsize=10, color="#22303c")

for case, data in rows.items():
    data.sort()
    km = [d[0] for d in data]
    closed = data[0][3]
    pre = [abs(d[1]) / closed for d in data]
    fix = [abs(d[2]) / closed for d in data]
    c = COLORS.get(case, "#666666")
    ax.plot(km, pre, color=c, lw=1.7, ls="--", alpha=0.85, zorder=2)
    ax.plot(km, fix, color=c, lw=2.4, label=case, zorder=3)

# k_max^5 guide, anchored on the F=1 curve's far end.
ref = sorted(rows["F=1 polar"])
k0, y0 = ref[-1][0], abs(ref[-1][1]) / ref[0][3]
guide_k = [k0 * 0.35, k0]
ax.plot(guide_k, [y0 * (k / k0) ** 5 for k in guide_k],
        color="#999999", lw=1.0, ls="-")
ax.annotate(r"\$\\propto k_{\\max}^{5}\$", xy=(k0 * 0.5, y0 * 0.5 ** 5 * 2.6),
            color="#777777", fontsize=12)

ax.set_xscale("log")
ax.set_yscale("log")
ax.set_xlabel(r"momentum cutoff  \$k_{\\max}\$   [\$\\sqrt{2m\\omega_{\\rm ref}/\\hbar}\$]")
ax.set_ylabel(r"\$|\\varepsilon_{\\rm LHY}^{\\rm BdG}|\\ /\\ \\varepsilon_{\\rm LHY}^{\\rm closed}\$")
ax.set_title("full_bdg spinor LHY: UV subtraction before and after the fix\\n"
             r"dashed = pre-fix (divergent, sign-flipped) · solid = trace counterterms",
             fontsize=11, loc="left")
ax.grid(alpha=0.22, which="both", lw=0.5)
ax.set_ylim(1e-1, 3e7)
ax.legend(frameon=False, loc="upper left", title="mean-field ansatz")
fig.tight_layout()
fig.savefig(dst, dpi=150, bbox_inches="tight")
print(f"wrote {dst}")
"""
    _emit_csv_py(io, paper, fig, String(take!(buf)), py;
        basename="lhy_full_bdg_uv_convergence")
end
