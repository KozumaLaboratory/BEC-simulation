#!/usr/bin/env python3
"""Plot the full_bdg LHY UV convergence.

The pre-2026-07-27 subtraction folded eps_k into the per-branch asymptote and
then subtracted eps_k a second time, leaving the integrand at -eps_k/2 and the
"energy" diverging as k_max^5. The current trace-based counterterms converge to
the closed form.

    python3 scripts/plot_lhy_full_bdg_uv.py lhy_uv.csv docs/figs/lhy_full_bdg_uv_convergence.png
"""
import csv
import sys
from collections import defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

COLORS = {"F=1 polar": "#2f6f9f", "F=6 polar": "#b5622a", "F=6 FM": "#3f7a4d"}


def main(src, dst):
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
    ax.annotate(r"$\propto k_{\max}^{5}$", xy=(k0 * 0.5, y0 * 0.5 ** 5 * 2.6),
                color="#777777", fontsize=12)

    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel(r"momentum cutoff  $k_{\max}$   [$\sqrt{2m\omega_{\rm ref}/\hbar}$]")
    ax.set_ylabel(r"$|\varepsilon_{\rm LHY}^{\rm BdG}|\ /\ \varepsilon_{\rm LHY}^{\rm closed}$")
    ax.set_title("full_bdg spinor LHY: UV subtraction before and after the fix\n"
                 r"dashed = pre-fix (divergent, sign-flipped) · solid = trace counterterms",
                 fontsize=11, loc="left")
    ax.grid(alpha=0.22, which="both", lw=0.5)
    ax.set_ylim(1e-1, 3e7)
    ax.legend(frameon=False, loc="upper left", title="mean-field ansatz")
    fig.tight_layout()
    fig.savefig(dst, dpi=150, bbox_inches="tight")
    print(f"wrote {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
