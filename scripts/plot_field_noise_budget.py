#!/usr/bin/env python3
"""Plot a B_z ramp through the weak-field Eu window under the shielded budget.

    python3 scripts/plot_field_noise_budget.py noise_budget.csv docs/figs/field_noise_vs_weak_field_scale.png
"""
import csv
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Feature scale from the 2026-07-15 convergence-gated re-analysis of the
# weak-field Eu ground state (kappa-dependent order; B_eq = 61.9 uG at
# kappa = 1.8, <F_perp> drop near 40-42 uG). Used here only to set the
# vertical scale the field error has to be read against.
FEATURE_LO, FEATURE_HI = 40.0, 62.0

OFFSET_COLORS = ["#b5622a", "#7a5a9b", "#3f7a4d"]
OFFSET_LABELS = ["\u221210 µG", "0", "+10 µG"]


def main(src, dst):
    with open(src) as fh:
        rows = list(csv.DictReader(fh))
    t = [float(r["t_s"]) * 1e3 for r in rows]                 # ms
    ug = lambda key: [float(r[key]) * 1e6 for r in rows]      # Gauss -> uG
    offs = [k for k in rows[0] if k.startswith("B_off")]

    fig, ax = plt.subplots(figsize=(8.8, 5.3))

    ax.axhspan(FEATURE_LO, FEATURE_HI, color="#6b8fb5", alpha=0.13, lw=0)
    ax.annotate("weak-field feature window\n(⟨F⊥⟩ drop → first-order jump)",
                xy=(0.015, 0.955), xycoords="axes fraction",
                ha="left", va="top", fontsize=9.5, color="#41618a")

    clean = ug("B_clean_G")
    for i, key in enumerate(offs):
        ax.plot(t, ug(key), color=OFFSET_COLORS[i % len(OFFSET_COLORS)], lw=1.5,
                alpha=0.9, label=f"static residual {OFFSET_LABELS[i]}")
    ax.plot(t, clean, color="#22303c", lw=2.6, label="intended ramp")

    ax.set_xlabel("time  [ms]")
    ax.set_ylabel(r"$B_z$   [µG]")
    ax.set_xlim(t[0], t[-1])
    ax.set_ylim(10, 85)
    ax.set_title("Permalloy shield + AC degauss: the limit is a rigid offset, "
                 "not jitter\n"
                 "AC residual < 0.5 µG rms · static residual ≈ 10 µG",
                 fontsize=11, loc="left")
    ax.grid(alpha=0.22, lw=0.5)
    ax.legend(frameon=False, loc="lower left", fontsize=9)

    ax.annotate("curves are PARALLEL, not fuzzy: a hysteresis loop keeps its\n"
                "width and only the absolute jump field shifts. So the residual\n"
                "is a scan axis, not a noise term",
                xy=(0.985, 0.955), xycoords="axes fraction",
                ha="right", va="top", fontsize=9.5, color="#4a4a4a")

    fig.tight_layout()
    fig.savefig(dst, dpi=150, bbox_inches="tight")
    print(f"wrote {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
