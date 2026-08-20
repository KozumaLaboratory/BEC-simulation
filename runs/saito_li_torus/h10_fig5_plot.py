#!/usr/bin/env python3
"""Fig. 5 analogue: the 1D supersolid line profile, one curve per seed.

Reads the CSV that `h10_fig5_emit.jl` writes from each `fig5_*.jld2`. The
point of plotting the PROFILE rather than trusting the peak counter is that
"12 interior peaks" over a 16 a_ho box would be a 1.04 um period, tighter
than one droplet diameter — a number that has to be looked at before it can
be believed.

  python3 runs/saito_li_torus/h10_fig5_plot.py
"""
import pathlib
import re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = pathlib.Path(__file__).parent / "out"


def main():
    files = sorted(OUT.glob("fig5_*_line.csv"))
    if not files:
        print(f"no fig5_*_line.csv in {OUT} — run h10_fig5_emit.jl first")
        return
    fig, ax = plt.subplots(2, 1, figsize=(9.0, 6.4), sharex=True)
    best = None
    for f in files:
        hdr = f.read_text().splitlines()[0]
        d = np.genfromtxt(f, delimiter=",", names=True, skip_header=1)
        tag = f.stem.replace("fig5_", "").replace("_line", "")
        m = re.search(r"E=([-0-9.eE+]+)", hdr)
        E = float(m.group(1)) if m else np.nan
        ax[0].plot(d["x_um"], d["line"], lw=1.5, label=tag)
        if best is None or (np.isfinite(E) and E < best[0]):
            best = (E, tag, d)
    ax[0].set_ylabel(r"$\int\!\rho\,dy\,dz$   [arb.]")
    ax[0].set_title("Li–Saito Fig. 5:  density along x,  F=1, N=4×10⁵, "
                    "ε_dd=1.4, surfboard trap")
    ax[0].legend(frameon=False, fontsize=8, ncol=3)
    ax[0].grid(alpha=0.25)

    if best is not None:
        _, tag, d = best
        ax[1].plot(d["x_um"], d["line"], lw=1.8, color="tab:red",
                   label=f"lowest energy: {tag}")
        ax[1].fill_between(d["x_um"], 0, d["line"], color="tab:red", alpha=0.15)
        ax[1].legend(frameon=False)
    ax[1].set_xlabel("x  [µm]")
    ax[1].set_ylabel(r"$\int\!\rho\,dy\,dz$   [arb.]")
    ax[1].grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(OUT / "fig5_supersolid.png", dpi=160)
    print("  wrote fig5_supersolid.png")


if __name__ == "__main__":
    main()
