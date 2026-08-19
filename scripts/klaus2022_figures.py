#!/usr/bin/env python3
"""Figures for the Klaus et al. 2022 type-C reproduction.

    python3 scripts/klaus2022_figures.py

Reads `docs/validation/klaus2022_results.json` (written by
`scripts/klaus2022_reproduce.jl`) and writes PNGs to
`docs/validation/figures/`.

Simulation output is drawn as a smooth line with no markers; published values
are drawn as explicit reference lines and labelled with their source figure,
so nothing on these plots can be mistaken for a measurement we made.
"""
import json
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RESULTS = os.path.join(ROOT, "docs", "validation", "klaus2022_results.json")
OUT = os.path.join(ROOT, "docs", "validation", "figures")


def main():
    with open(RESULTS) as f:
        res = json.load(f)
    os.makedirs(OUT, exist_ok=True)

    if "ar-ramp" in res:
        r = res["ar-ramp"]
        om, ar = r["omega"], r["aspect_ratio"]
        # Klaus probe "a full period at the final rotation frequency" to remove
        # the drive-frequency breathing. Same here: running mean over one
        # rotation period at Omega = omega_perp.
        t = r["times"]
        w = max(3, int(round((2 * 3.141592653589793) / (t[1] - t[0]))))
        sm = [sum(ar[max(0, i - w // 2):min(len(ar), i + w // 2 + 1)])
              / len(ar[max(0, i - w // 2):min(len(ar), i + w // 2 + 1)])
              for i in range(len(ar))]
        i_pk = max(range(len(sm)), key=lambda k: sm[k])

        fig, ax = plt.subplots(figsize=(6.4, 4.2))
        ax.plot(om, ar, lw=0.7, color="#a0aec0", label="raw (drive-frequency breathing)")
        ax.plot(om, sm, lw=1.8, color="#2b6cb0",
                label="scalar eGPE, 1 s ramp, period-averaged")
        ax.axvline(r["published"]["omega_c_over_perp"], color="#c53030", ls="--",
                   lw=1.2, label=r"Klaus Fig. 1c  $\Omega_c=0.74\,\omega_\perp$")
        ax.axvline(om[i_pk], color="#2b6cb0", ls=":", lw=1.4,
                   label=r"this work, AR maximum  $%.3f\,\omega_\perp$" % om[i_pk])
        ax.axhline(r["published"]["ar_magnetostricted"], color="#718096", ls="-.",
                   lw=1.0, label="Klaus Methods A.4  AR = 1.03 (NOT reproduced)")
        ax.set_xlabel(r"$\Omega/\omega_\perp$")
        ax.set_ylabel("in-plane aspect ratio")
        ax.set_title(r"Magnetostirring: cloud AR vs stirring frequency")
        ax.legend(fontsize=8, loc="upper left")
        fig.tight_layout()
        fig.savefig(os.path.join(OUT, "klaus2022_ar_ramp.png"), dpi=160)
        plt.close(fig)

    if "stripes" in res and "control" in res:
        s, c = res["stripes"], res["control"]
        fig, axes = plt.subplots(2, 1, figsize=(6.0, 6.2), sharex=True)
        # The two arms share their seed and their protocol until the theta ramp,
        # so they trace the SAME curve up to t_ramp — a paired comparison. Shade
        # the ramp window and draw the control on top only where it diverges.
        t_ramp = 0.6 * 2 * 3.141592653589793 * 50.0
        axes[0].axvspan(t_ramp, max(c["times"]), color="#fefcbf", alpha=0.7,
                        zorder=0, label=r"$\theta$ spiralled $35^\circ\to0^\circ$")
        axes[1].axvspan(t_ramp, max(c["times"]), color="#fefcbf", alpha=0.7, zorder=0)
        axes[0].plot(c["times"], c["axis_order_t"], lw=1.4, color="#dd6b20",
                     label=r"$\theta\to 0^\circ$ control")
        axes[0].plot(s["times"], s["axis_order_t"], lw=1.4, color="#2b6cb0",
                     label=r"$\theta=35^\circ$ (identical until the ramp)")
        axes[0].axhline(s["axis_order_null"], color="#4a5568", ls=":", lw=1.2,
                        label=r"isotropic null $1/\sqrt{N}$")
        axes[0].axhline(s["axis_order_baseline"], color="#805ad5", ls="--", lw=1.0,
                        label="vortex-free $t=0$ frame (elongated cloud)")
        axes[0].set_ylabel(r"axis order  $|\sum w e^{2i\varphi}|/\sum w$")
        axes[0].legend(fontsize=7, loc="upper right", ncol=1)
        axes[1].plot(c["times"], c["misalign_deg_t"], lw=1.0, color="#dd6b20")
        axes[1].plot(s["times"], s["misalign_deg_t"], lw=1.4, color="#2b6cb0")
        axes[1].axhline(s["accept"]["stripe_axis_tol_deg"], color="#4a5568",
                        ls="--", lw=1.0, label="accept threshold")
        axes[1].axhline(-s["accept"]["stripe_axis_tol_deg"], color="#4a5568",
                        ls="--", lw=1.0)
        axes[1].set_ylabel("stripe axis $-$ B-field axis (deg)")
        axes[1].set_xlabel(r"time $(1/\omega_\mathrm{ref})$")
        axes[1].legend(fontsize=8)
        fig.suptitle("Vortex stripes and the $\\theta\\to0$ negative control")
        fig.tight_layout()
        fig.savefig(os.path.join(OUT, "klaus2022_stripes.png"), dpi=160)
        plt.close(fig)

    print("wrote figures to", OUT)


if __name__ == "__main__":
    main()
