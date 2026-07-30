#!/usr/bin/env python3
"""K3 × LHY 2×4 factorial — peak growth ratio and atom retention.

    python scripts/eu_k3_lhy_factorial_figure.py \
        runs/eu_k3_lhy_control/factorial_2x4.json [out.png]

Panels follow `docs/manuscript/four_figure_spec_2026_05_26.md`:
  (a) peak growth ratio  max(peak)/peak(0)
  (b) atom retention     N(T)/N(0)
both over {K3=0, K3=200} × {off, scalar, polar_contact, icosa}.

The point of the figure CHANGED when the factorial was re-measured (PR #197).
It used to show the two spinor closed forms arresting where `off` and `scalar`
did not, which read as "arrest is closure-dependent". That separation was the
30000x LHY overstrength of #158. With all eight cells re-run at one revision the
four LHY settings collapse onto ONE classification per K3 row, so the honest
reading is the opposite: within each K3 row the LHY model does not change the
outcome. The classification is printed on each bar so that collapse is visible
rather than asserted.

There was no committed generator for the original PNG — this is a rewrite, which
is also why the figure is reproducible now.
"""
import json
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

src = sys.argv[1] if len(sys.argv) > 1 else "runs/eu_k3_lhy_control/factorial_2x4.json"
out = sys.argv[2] if len(sys.argv) > 2 else "docs/validation/figures/fig4_lhy_model_interference.png"

rows = json.load(open(src))["rows"]
MODELS = ["off", "scalar", "polar_contact", "full_bdg"]
K3S = [0, 200]
# `icosa` was dropped, not renamed: `IcosahedralLHY` returns NaN at c1 < 0 (the
# sign these configs use) since 2026-07-30, so those rows were measured in a
# regime current main refuses. `full_bdg` is the general-spinor path and is valid
# there.
LBL = {"off": "no LHY", "scalar": "scalar", "polar_contact": "polar\ncontact",
       "full_bdg": "full BdG"}
# Categorical, colour-blind-safe; `off` deliberately grey — it is the control.
COL = {0: "#4C72B0", 200: "#C44E52"}

def cell(k3, model):
    for r in rows:
        if r["K3"] == k3 and r["LHY"] == model:
            return r
    raise KeyError(f"missing cell K3={k3} LHY={model}")

fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.2))
x = np.arange(len(MODELS))
w = 0.38

for ax, key, ylab, title in (
    (axes[0], "ratio", r"peak growth  $\max_t n_{\max}(t)\,/\,n_{\max}(0)$",
     "(a) peak growth"),
    (axes[1], "N_final_ratio", r"atom retention  $N(T)/N(0)$",
     "(b) atom retention"),
):
    for i, k3 in enumerate(K3S):
        vals = [cell(k3, m)[key] for m in MODELS]
        pos = x + (i - 0.5) * w
        ax.bar(pos, vals, w, color=COL[k3], label=f"$K_3$ = {k3}", zorder=3)
        # The classification is the claim; put it on the bar rather than in prose.
        for p, v, m in zip(pos, vals, MODELS):
            cls = cell(k3, m)["classification"].replace("_", "\n")
            ax.text(p, v, cls, ha="center", va="bottom", fontsize=6.2,
                    color="0.25", linespacing=0.95)
    ax.set_xticks(x)
    ax.set_xticklabels([LBL[m] for m in MODELS], fontsize=9)
    ax.set_xlabel("LHY model")
    ax.set_ylabel(ylab, fontsize=9)
    ax.set_title(title, fontsize=10, loc="left")
    ax.grid(axis="y", alpha=0.25, zorder=0)
    ax.set_axisbelow(True)
    ax.margins(y=0.30)   # headroom for the on-bar classification labels

# The 0.5 line goes in the LEGEND, not on the canvas. Every in-axes position
# for its label collided with either the K3=0 bars (which reach 1.0) or the
# on-bar classification text, and those labels are the point of the figure.
line = axes[1].axhline(0.5, color="0.4", ls="--", lw=0.9, zorder=2)
line.set_label(r"$N(T)/N(0)=0.5$: sacrificial / stable")

# One shared legend under the panels — inside either axes it lands on the on-bar
# classification labels.
h0, l0 = axes[0].get_legend_handles_labels()
fig.legend(h0 + [line], l0 + [line.get_label()], frameon=False, fontsize=9,
           ncol=3, loc="lower center", bbox_to_anchor=(0.5, -0.01))

fig.suptitle("Within each $K_3$ row the LHY model does not change the outcome",
             fontsize=10.5, y=0.99)
fig.tight_layout(rect=(0, 0.06, 1, 0.94))
fig.savefig(out, dpi=200)
print(f"wrote {out}")
for k3 in K3S:
    for m in MODELS:
        c = cell(k3, m)
        print(f"  K3={k3:<4} {m:<14} {c['classification']:<19} "
              f"ratio={c['ratio']:.4f}  N(T)/N(0)={c['N_final_ratio']:.4f}")
