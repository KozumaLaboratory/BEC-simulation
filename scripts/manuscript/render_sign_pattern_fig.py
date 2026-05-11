#!/usr/bin/env python3
"""Render paper3 FIG-6: Sign Pattern Anomalous Identity visualization.

Source: docs/manuscript/figures_data/sign_pattern_table.csv
Output: docs/manuscript/papers/paper3_universal_theorem/figures/paper3_FIG-6.pdf
        (+ .png for previews)

Visualizes for each paper3 polyhedral case (F=3, 4, 6, 8, 10):
  - X_S^{anom} (anomalous channel-S overlap) with sign-color coding
  - X_S^{HF} (Hartree-Fock contribution) as comparison
  - β_S^{c0} (selection rule signature) bars
  - paper3 stated β_S^{λ_spin} signs as annotation

The figure demonstrates that sign(β_S^{λ_spin}) = sign(X_S^{anom}) for
F=4/6/8/10 (A_1 cases), with the F=3 A_2 case showing one-step offset.

Run: python3 scripts/manuscript/render_sign_pattern_fig.py
"""

import csv
import os
import sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")  # no display
import matplotlib.pyplot as plt
import numpy as np

CSV_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "docs/manuscript/figures_data/sign_pattern_table.csv",
)
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "docs/manuscript/papers/paper3_universal_theorem/figures",
)
os.makedirs(OUT_DIR, exist_ok=True)


def load_data(path):
    rows_by_F = defaultdict(list)
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            F = int(row["F"])
            rows_by_F[F].append({
                "S": int(row["S"]),
                "beta_S_c0": float(row["beta_S_c0"]),
                "X_S_HF": float(row["X_S_HF"]),
                "X_S_anom": float(row["X_S_anom"]),
                "phase": row["phase"],
                "irrep": row["group_irrep"],
                "paper3_sign": row["paper3_sign_beta_lambda"],
                "match": row["match"],
            })
    return rows_by_F


def plot_sign_pattern(data, out_path_base):
    F_list = sorted(data.keys())
    n_cases = len(F_list)
    fig, axes = plt.subplots(n_cases, 1, figsize=(11, 2.2 * n_cases),
                              sharey=False)
    if n_cases == 1:
        axes = [axes]

    for ax, F in zip(axes, F_list):
        rows = data[F]
        S_vals = [r["S"] for r in rows]
        X_anom = [r["X_S_anom"] for r in rows]
        X_HF = [r["X_S_HF"] for r in rows]

        # Color: red for negative, blue for positive, gray for zero
        colors = []
        for x in X_anom:
            if x < -1e-10:
                colors.append("#d62728")  # red
            elif x > 1e-10:
                colors.append("#1f77b4")  # blue
            else:
                colors.append("#888888")  # gray

        x_pos = np.arange(len(S_vals))
        bar_width = 0.4

        bars_anom = ax.bar(x_pos - bar_width / 2, X_anom, bar_width,
                            color=colors, label=r"$X_S^{\mathrm{anom}}$ (sign $\equiv$ sign $\beta_S^{\lambda}$)")
        bars_hf = ax.bar(x_pos + bar_width / 2, X_HF, bar_width,
                         color="#888", alpha=0.4, label=r"$X_S^{\mathrm{HF}}$ (positive)")

        ax.axhline(0, color="black", linewidth=0.5)
        ax.set_xticks(x_pos)
        ax.set_xticklabels([str(s) for s in S_vals])
        ax.set_xlabel("Scattering channel S")
        ax.set_ylabel(r"$X_S^{(\cdot)}$")
        phase = rows[0]["phase"]
        irrep = rows[0]["irrep"]
        title = f"F = {F} ({phase}, {irrep})"
        ax.set_title(title, loc="left", fontsize=10, fontweight="bold")
        ax.grid(axis="y", linestyle="--", alpha=0.3)

        # Add paper3 sign annotations above bars
        ymax = max(max(X_HF), max(abs(x) for x in X_anom))
        for xpos_i, S_i, x_anom_i, row in zip(x_pos, S_vals, X_anom, rows):
            sign_pred = "+" if x_anom_i > 1e-10 else "−" if x_anom_i < -1e-10 else "0"
            paper3_sign = row["paper3_sign"]
            match_color = "green" if row["match"].startswith("yes") else \
                          ("orange" if row["match"].startswith("no") else "gray")
            label = f"pred:{sign_pred}\npp3:{paper3_sign}"
            if row["match"].startswith("no"):
                label += "\n(offset)"
            ax.text(xpos_i - bar_width / 2, ymax * 1.05,
                    label, fontsize=7, ha="center", va="bottom",
                    color=match_color)

        # Mark sign change between consecutive S
        prev_sign = None
        for S_i, x_anom_i in zip(S_vals, X_anom):
            cur_sign = "+" if x_anom_i > 1e-10 else "−" if x_anom_i < -1e-10 else None
            if cur_sign and prev_sign and cur_sign != prev_sign:
                # find x position
                idx = S_vals.index(S_i)
                ax.axvline(idx - 0.5, color="green", linestyle=":", linewidth=2,
                           alpha=0.6, label=f"S_bd = {S_vals[idx-1]} → {S_i}" if "S_bd" not in [l.get_label() for l in ax.lines] else "")
            if cur_sign is not None:
                prev_sign = cur_sign

        ax.legend(loc="upper left", fontsize=8)

    fig.suptitle(
        r"Sign Pattern Anomalous Identity: sign $\beta_S^{\lambda_{\rm spin}}$ "
        r"$\equiv$ sign $X_S^{\rm anom}$ for polyhedral inert states",
        fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.97])

    out_pdf = out_path_base + ".pdf"
    out_png = out_path_base + ".png"
    fig.savefig(out_pdf, dpi=150, bbox_inches="tight")
    fig.savefig(out_png, dpi=150, bbox_inches="tight")
    plt.close(fig)
    return out_pdf, out_png


def main():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: CSV not found at {CSV_PATH}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading data from {CSV_PATH}")
    data = load_data(CSV_PATH)
    print(f"Loaded {sum(len(v) for v in data.values())} rows across {len(data)} F values")

    out_base = os.path.join(OUT_DIR, "paper3_FIG-6")
    print(f"Rendering to {out_base}.pdf / .png")
    pdf_path, png_path = plot_sign_pattern(data, out_base)

    print(f"✓ Rendered: {pdf_path}")
    print(f"✓ Rendered: {png_path}")
    print()
    print("FIG-6 caption draft:")
    print("  Sign Pattern Anomalous Identity for paper3 polyhedral inert states.")
    print("  For each F=3,4,6,8,10, X_S^{anom} (left bars, red=negative, blue=positive)")
    print("  matches the sign of β_S^{λ_spin} from paper3 closed forms (pp3 annotation,")
    print("  green=match, orange=offset). Sign change locations marked with dotted")
    print("  green lines. F=3 A_2 shows one-step offset (A_2 sign convention).")
    print("  X_S^{HF} (right bars) is always positive (HF contribution).")


if __name__ == "__main__":
    main()
